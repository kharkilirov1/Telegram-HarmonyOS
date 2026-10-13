// Actual-source delivery witness. No SDK, device, account or real TDLib.
// Both variants compile identical production bytes. The heap variant adds only
// host executable allocation interposition (not a production source rewrite).
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const tempRoot = path.resolve(os.tmpdir());
const nativePath = path.join(root, 'entry/src/main/cpp/tdlib_napi.cpp');
const original = fs.readFileSync(nativePath);
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const scenarios = ['success', 'reject-before', 'reject-after', 'reject-after-drain', 'reject-always',
  'queue-full', 'closing', 'invalid-handle', 'null-env', 'string-failure', 'receiver-failure', 'js-failure', 'restart', 'js-reentry'];
const selected = process.argv.find(x => x.startsWith('--case='))?.slice(7);
if (selected && !scenarios.includes(selected)) throw new Error(`Unknown case: ${selected}`);
if (selected && process.argv.includes('--negative-controls')) {
  throw new Error('Negative controls require the full positive matrix; omit --case');
}
const build = fs.mkdtempSync(path.join(tempRoot, 'telegram-native-delivery-'));
let failures = 0;
let transcript = '';
function output(text) { process.stdout.write(text); transcript += text; }
function invoke(command, args, timeout = 30000) {
  return spawnSync(command, args, { cwd: root, encoding: 'utf8', timeout });
}
function compile(name, source, heap) {
  const sourcePath = path.join(build, `${name}.cpp`);
  const binary = path.join(build, `${name}${process.platform === 'win32' ? '.exe' : ''}`);
  fs.writeFileSync(sourcePath, source);
  const compiled = invoke(process.env.CXX || (process.platform === 'win32' ? 'g++' : 'c++'), [
    '-std=c++17', '-pthread', '-Wall', '-Wextra', '-Wno-unused-parameter', '-Wno-unused-function',
    ...(process.platform === 'win32' ? ['-static-libstdc++'] : []),
    '-I', path.join(build, 'include'), '-I', build,
    ...(heap ? ['-DDELIVERY_HEAP_ORACLE'] : []),
    `-DBRIDGE_SOURCE="${sourcePath.replaceAll('\\', '/')}"`,
    path.join(build, 'delivery_test.cpp'), '-o', binary
  ], 60000);
  if (compiled.error || compiled.signal || compiled.status !== 0) {
    throw new Error(`COMPILE ${name}: ${compiled.error ?? compiled.signal ?? compiled.status}\n${compiled.stdout}\n${compiled.stderr}`);
  }
  output(`COMPILE ${name}: exit 0\n`);
  return binary;
}
function assertionResult(r) {
  if (r.error || r.signal || ![0, 1].includes(r.status)) return false;
  const summary = (r.stdout || '').match(/^SUMMARY (\d+) passed, (\d+) failed\r?$/m);
  if (!summary || Number(summary[1]) + Number(summary[2]) === 0) return false;
  const failed = (r.stdout.match(/^FAIL /gm) || []).length;
  return Number(summary[2]) === failed && r.status === (failed ? 1 : 0);
}
function replaceOnce(text, from, to) {
  const matches = typeof from === 'string' ? text.split(from).length - 1 : [...text.matchAll(new RegExp(from.source, 'g'))].length;
  if (matches !== 1) throw new Error(`Expected one mutation site, got ${matches}: ${from}`);
  const result = text.replace(from, to);
  if (result === text) throw new Error('Mutation did not change source');
  return result;
}
function negativeControls() {
  const source = original.toString('utf8').replaceAll('\r\n', '\n');
  // Only temp source copies are mutated. Acceptance cases above never inspect
  // ReceiveDelivery/member names; these deliberately narrow source mutations
  // fail closed on source drift instead of silently exercising another path.
  const controls = [
    {
      name: 'payload-in-wakeup', scenario: 'success', expected: 'FAIL TSFN carries ONLY nullptr',
      mutate: s => replaceOnce(s, /(napi_call_threadsafe_function\([^,]+, )nullptr(, napi_tsfn_nonblocking\))/, '$1reinterpret_cast<void*>(1)$2')
    },
    {
      name: 'status-as-delivery', scenario: 'reject-before', expected: 'FAIL non-ok retries',
      mutate: s => replaceOnce(s, 'if (status == napi_ok) return true;', 'if (status == napi_ok || status == napi_generic_failure) return true;')
    },
    {
      name: 'retry-hot-spin', scenario: 'reject-always', expected: 'FAIL persistent retry is paced',
      mutate: s => replaceOnce(s, /std::this_thread::sleep_for\(NOTIFY_RETRY_DELAY\);/, '(void)0;')
    },
    {
      name: 'missing-pop', scenario: 'success', expected: 'FAIL success: exact once and FIFO',
      mutate: s => replaceOnce(s, /\w+->\w+\.pop_front\(\);/, '(void)0;')
    },
    {
      name: 'lifo-batches', scenario: 'success', expected: 'FAIL success: exact once and FIFO',
      mutate: s => replaceOnce(replaceOnce(s, '.front()', '.back()'), '.pop_front()', '.pop_back()')
    },
    {
      name: 'unbounded-callback', scenario: 'success', expected: 'FAIL one native callback invokes at most one JS batch',
      mutate: s => replaceOnce(s, '    }\n}\n\nstatic bool NotifyReceiveBatch()',
        '    }\n    CallJs(env, js_callback, context, nullptr); // MUTATION: unbounded drain.\n}\n\nstatic bool NotifyReceiveBatch()')
    },
    {
      name: 'missing-finalizer-delete', scenario: 'null-env', expected: 'FAIL native tracked C++ heap is empty',
      mutate: s => replaceOnce(s, /delete static_cast<\w+\*>\(data\);/, '(void)data;')
    },
    {
      name: 'missing-env-guard', scenario: 'null-env', crashAt: 'PROBE null-env/poisoned-context',
      mutate: s => replaceOnce(s, 'env == nullptr || js_callback == nullptr || context == nullptr', 'js_callback == nullptr || context == nullptr')
    },
    {
      name: 'missing-callback-guard', scenario: 'null-env', crashAt: 'PROBE null-callback/poisoned-context',
      mutate: s => replaceOnce(s, 'env == nullptr || js_callback == nullptr || context == nullptr', 'env == nullptr || context == nullptr')
    },
    {
      name: 'terminal-extra-release', scenario: 'closing', expected: 'FAIL terminal status ends handle use',
      mutate: s => replaceOnce(s, 'if (status == napi_closing || status == napi_invalid_arg) {',
        'if (status == napi_closing || status == napi_invalid_arg) {\n                napi_release_threadsafe_function(threadsafe_callback, napi_tsfn_release);')
    },
    {
      name: 'old-callback-new-context', scenario: 'restart', expected: 'FAIL old/new callbacks each deliver their own batches',
      mutate: s => {
        s = replaceOnce(s, 'static void CallJs(', 'static void* delivery_test_latest_context = nullptr;\nstatic void CallJs(');
        s = replaceOnce(s, /(= \*static_cast<\w+\*>\()context(\);)/, '$1delivery_test_latest_context$2');
        return replaceOnce(s, /(0, 1, [^,\n]+, \w+, )([^,\n]+)(,\n\s*CallJs,)/,
          '$1(delivery_test_latest_context = $2)$3');
      }
    },
    {
      name: 'queue-mutex-across-js', scenario: 'js-reentry', expected: 'FAIL producer reaches next notification while JS callback is paused',
      mutate: s => replaceOnce(s, /std::string batch;\n    \{\n        std::lock_guard<std::mutex> guard\(([^)]+)\);/,
        'std::string batch;\n    std::lock_guard<std::mutex> delivery_test_held_lock($1);\n    {')
    }
  ];
  for (const control of controls) {
    const binary = compile(`mutation-${control.name}`, control.mutate(source), true);
    const r = invoke(binary, [control.scenario], 10000);
    output(`\nMUTATION ${control.name}/${control.scenario}\n${r.stdout || ''}${r.stderr || ''}`);
    const expectedAccessViolation = !r.error && (r.signal === 'SIGSEGV' || r.signal === 'SIGBUS' ||
      r.status === 3221225477 || r.status === -1073741819);
    const caught = control.crashAt
      ? expectedAccessViolation && (r.stdout || '').trimEnd().endsWith(control.crashAt)
      : assertionResult(r) && r.status === 1 && (r.stdout || '').includes(control.expected);
    if (!caught) throw new Error(`Invalid negative control ${control.name}: ${r.error ?? r.signal ?? r.status}`);
    output(`CONTROL ${control.name}: caught (${control.crashAt ? 'expected poisoned-context access violation' : 'target assertion RED'})\n`);
  }
  output(`CONTROLS ${controls.length}/${controls.length} caught\n`);
}
try {
  // Freeze all compilation inputs: another agent may edit production/harness.
  fs.writeFileSync(path.join(build, 'tdlib_napi.cpp'), original);
  fs.copyFileSync(path.join(root, 'entry/src/main/cpp/tdlib_napi.h'), path.join(build, 'tdlib_napi.h'));
  fs.copyFileSync(path.join(__dirname, 'native-bridge/delivery_test.cpp'), path.join(build, 'delivery_test.cpp'));
  fs.cpSync(path.join(__dirname, 'native-bridge/include'), path.join(build, 'include'), { recursive: true });
  output(`SOURCE sha256=${hash(original)}\n`);
  output('BOUNDARY host adversarial enqueue fixture; no OS reachability or env-cleanup-order claim\n');
  for (const variant of ['untouched', 'heap-oracle']) {
    const binary = compile(variant, original, variant === 'heap-oracle');
    for (const scenario of selected ? [selected] : scenarios) {
      const r = invoke(binary, [scenario], 10000);
      output(`\nCASE ${variant}/${scenario}\n${r.stdout || ''}${r.stderr || ''}`);
      // Crashes/timeouts are reported distinctly, never confused with a normal
      // assertion RED. Each scenario has its own process to contain bad lifetimes.
      if (!assertionResult(r)) {
        output(`ABNORMAL ${variant}/${scenario}: ${r.error ?? r.signal ?? r.status}\n`);
        ++failures;
      } else if (r.status !== 0) {
        ++failures;
      }
      output(`EXIT ${r.status}\n`);
    }
  }
  if (process.argv.includes('--negative-controls')) {
    if (failures) throw new Error('Negative controls require a GREEN unmutated source first');
    negativeControls();
  }
  const unchanged = hash(fs.readFileSync(nativePath)) === hash(original);
  output(`SOURCE ${unchanged ? 'unchanged during run' : 'changed concurrently; results apply ONLY to frozen hash above'}\n`);
  output(`RESULT ${failures ? 'RED' : 'GREEN'}: ${failures} failing scenario variants\n`);
  process.exitCode = failures ? 1 : 0;
} catch (error) {
  output(`${String(error)}\n`);
  process.exitCode = 1;
} finally {
  if (path.dirname(path.resolve(build)) !== tempRoot || !path.basename(build).startsWith('telegram-native-delivery-')) {
    throw new Error('Unsafe native delivery cleanup path');
  }
  if (process.argv.includes('--keep-build')) {
    fs.writeFileSync(path.join(build, 'output.log'), transcript);
    console.log(`EVIDENCE ${build}`);
  } else {
    fs.rmSync(build, { recursive: true, force: true });
  }
}
