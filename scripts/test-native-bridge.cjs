// Compiles the actual bridge. No HarmonyOS SDK, account or real TDLib is used.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const tempRoot = path.resolve(os.tmpdir());
const build = fs.mkdtempSync(path.join(tempRoot, 'telegram-native-bridge-'));
// One explicit constructor boundary injection, otherwise the production source
// is unchanged. Do not exhaust real OS threads to reproduce std::thread failure.
const original = fs.readFileSync(path.join(root, 'entry/src/main/cpp/tdlib_napi.cpp'), 'utf8');
const site = 'receive_thread = std::thread(';
if (original.split(site).length !== 2) throw new Error('Receive-thread injection site must be unique');
function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', timeout: 60000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error || result.signal || result.status !== 0) {
    throw new Error(`${command}: ${result.error ?? result.signal ?? `exit ${result.status}`}`);
  }
}
function variant(name, text, injected, expectFailure = false) {
  const source = path.join(build, `${name}.cpp`);
  const binary = path.join(build, `${name}${process.platform === 'win32' ? '.exe' : ''}`);
  fs.writeFileSync(source, text);
  run(process.env.CXX || (process.platform === 'win32' ? 'g++' : 'c++'), [
    '-std=c++17', '-pthread', '-Wall', '-Wextra',
    // MinGW DLL allocation bypasses executable delete interposition. Static
    // libstdc++ makes the string-buffer destruction oracle observable as well.
    ...(process.platform === 'win32' ? ['-static-libstdc++'] : []),
    '-I', path.join(__dirname, 'native-bridge/include'),
    '-I', path.join(root, 'entry/src/main/cpp'),
    `-DBRIDGE_SOURCE="${source.replaceAll('\\', '/')}"`,
    ...(injected ? ['-DBRIDGE_THREAD_INJECTION'] : []),
    path.join(__dirname, 'native-bridge/bridge_test.cpp'), '-o', binary
  ]);
  if (!expectFailure) return run(binary, []);
  const r = spawnSync(binary, [], { cwd: root, encoding: 'utf8', timeout: 15000 });
  const failures = (r.stdout || '').split(/\r?\n/).filter(x => x.startsWith('FAIL '));
  if (r.error || r.signal || r.status !== 1 || failures.length === 0) {
    throw new Error(`Invalid negative control ${name}: ${r.error ?? r.signal ?? r.status}\n${r.stdout}\n${r.stderr}`);
  }
  console.log(`CONTROL ${name}: ${failures.length} failing checks as expected`);
}
function replaceOnce(text, from, to) {
  if (text.split(from).length !== 2) throw new Error(`Non-unique mutation site: ${from}`);
  return text.replace(from, to);
}
try {
  variant('production', original, false);
  const injected = original.replace(site, 'receive_thread = MakeReceiveThread(');
  variant('thread-injection', injected, true);
  if (process.argv.includes('--negative-controls')) {
    const controls = [
      ['blocking-stop', 'stop->thread = std::move(receive_thread);',
        'stop->thread = std::move(receive_thread); if (stop->thread.joinable()) stop->thread.join();'],
      ['early-stopped', '        });\n    } catch (...) {',
        '        loop_state = LoopState::Stopped;\n        });\n    } catch (...) {'],
      ['busy-start-silent', 'if (loop_state == LoopState::Stopping || pending_stop != nullptr ||',
        'if (false || false ||'],
      ['queue-restores-running', 'pending_stop = nullptr;\n        // The producer',
        'pending_stop = nullptr; loop_state = LoopState::Running;\n        // The producer'],
      ['constructor-lease-leak', '        napi_release_threadsafe_function(threadsafe_callback, napi_tsfn_release);\n        threadsafe_callback = nullptr;',
        '        // MUTATION: missing terminal release.\n        threadsafe_callback = nullptr;']
    ];
    for (const [name, from, to] of controls) {
      variant(name, replaceOnce(injected.replaceAll('\r\n', '\n'), from, to), true, true);
    }
  }
} catch (error) {
  console.error(String(error));
  process.exitCode = 1;
} finally {
  // Delete only the unique build directory we just created under the OS temp root.
  if (path.dirname(path.resolve(build)) !== tempRoot || !path.basename(build).startsWith('telegram-native-bridge-')) {
    throw new Error('Unsafe native test cleanup path');
  }
  fs.rmSync(build, { recursive: true, force: true });
}
