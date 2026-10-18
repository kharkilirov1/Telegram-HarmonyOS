const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const scenarios = ['api-guards', 'startup-failures', 'startup-hook-remove-failure', 'release-failure', 'success', 'stress', 'pause-js', 'pause-ack', 'batch-count', 'target-bytes', 'bytes', 'unicode', 'oversize',
  'string-failure', 'receiver-failure', 'marshal-permanent', 'pending-exception',
  'reject-before', 'reject-after', 'reject-after-drain', 'reject-always', 'queue-full', 'closing', 'invalid-handle',
  'js-failure', 'js-false', 'js-nonboolean', 'js-reentry', 'null-env', 'restart', 'lifecycle', 'cleanup', 'queue-failure', 'cancel-work'];
module.exports = function runFlow(options = {}) {
  const base = path.resolve(os.tmpdir());
  const build = fs.mkdtempSync(path.join(base, 'telegram-receive-flow-'));
  const nativePath = path.join(root, 'entry/src/main/cpp/tdlib_napi.cpp');
  const source = fs.readFileSync(nativePath, 'utf8');
  let failures = 0, checks = 0;
  const inputFiles = ['entry/src/main/cpp/tdlib_napi.cpp', 'entry/src/main/cpp/tdlib_napi.h',
    'scripts/native-bridge/delivery_test.cpp', 'scripts/native-bridge/include/napi/native_api.h',
    'scripts/native-bridge/include/uv.h', 'scripts/native-bridge/run-flow.cjs'];
  const inputHashes = Object.fromEntries(inputFiles.map(file => [file, hash(fs.readFileSync(path.join(root, file)))]));
  const selected = process.argv.find(arg => arg.startsWith('--case='))?.slice(7);
  function execute(command, args, timeout = 15000) {
    const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', timeout });
    if (result.error || result.signal) throw new Error(`${command}: ${result.error || result.signal}`);
    return result;
  }
  function compile(name, text, heap = false) {
    const sourcePath = path.join(build, `${name}.cpp`), binary = path.join(build, name + (process.platform === 'win32' ? '.exe' : ''));
    fs.writeFileSync(sourcePath, text);
    const r = execute(process.env.CXX || (process.platform === 'win32' ? 'g++' : 'c++'), [
      '-std=c++17', '-pthread', '-Wall', '-Wextra', '-Wno-unused-parameter', '-Wno-unused-function', '-Wno-missing-field-initializers',
      ...(process.platform === 'win32' ? ['-static-libstdc++'] : []), ...(heap ? ['-DDELIVERY_HEAP_ORACLE'] : []),
      '-I', path.join(build, 'include'), '-I', build,
      `-DBRIDGE_SOURCE="${sourcePath.replaceAll('\\', '/')}"`, path.join(build, 'delivery_test.cpp'), '-o', binary
    ], 60000);
    if (r.status !== 0) throw new Error(`COMPILE ${name}: ${r.status}\n${r.stdout}\n${r.stderr}`);
    console.log(`COMPILE ${name}: exit 0`); return binary;
  }
  function run(binary, scenario, negative = false) {
    const r = execute(binary, [scenario]);
    const match = r.stdout.match(/^SUMMARY (\d+) passed, (\d+) failed\r?$/m);
    if (!match || ![0, 1].includes(r.status) || (Number(match[2]) > 0) !== (r.status === 1))
      throw new Error(`ABNORMAL ${scenario}: exit ${r.status}\n${r.stdout}\n${r.stderr}`);
    if (negative) { if (r.status !== 1) throw new Error(`SURVIVING MUTANT ${scenario}`); console.log(`CONTROL caught: ${scenario} (${match[2]} failing checks)`); return; }
    checks += Number(match[1]) + Number(match[2]);
    if (r.status) { failures++; process.stdout.write(r.stdout); }
    console.log(`CASE ${path.basename(binary)}/${scenario}: ${match[1]} passed, ${match[2]} failed`);
  }
  function replaceOnce(text, before, after) {
    if (text.split(before).length !== 2) throw new Error(`Mutation site drift: ${before}`);
    return text.replace(before, after);
  }
  try {
    fs.cpSync(path.join(__dirname, 'include'), path.join(build, 'include'), { recursive: true });
    fs.copyFileSync(path.join(__dirname, 'delivery_test.cpp'), path.join(build, 'delivery_test.cpp'));
    fs.copyFileSync(path.join(root, 'entry/src/main/cpp/tdlib_napi.h'), path.join(build, 'tdlib_napi.h'));
    console.log(`SOURCE tdlib_napi.cpp sha256=${hash(source)}`);
    console.log(`INPUT_HASHES ${JSON.stringify(inputHashes)}`);
    console.log('SCOPE actual native source; host NAPI/TDLib/libuv boundaries; no runtime ABI/env claim');
    const cases = selected ? [selected] : options.lifecycle ? ['api-guards', 'startup-failures', 'startup-hook-remove-failure', 'release-failure', 'lifecycle', 'cleanup', 'queue-failure', 'cancel-work', 'js-reentry', 'restart', 'null-env'] : scenarios;
    for (const heap of options.lifecycle ? [false] : [false, true]) {
      const binary = compile(heap ? 'heap' : 'untouched', source, heap);
      for (const scenario of cases) { if (!scenarios.includes(scenario)) throw new Error('Unknown case'); run(binary, scenario); }
      if (heap && !selected) run(binary, 'allocation-failure');
    }
    if (options.lifecycle && !selected) {
      const injected = replaceOnce(replaceOnce(source, 'o->producer = std::thread(', 'o->producer = MakeReceiveThread('), '    const auto status = napi_call_threadsafe_function(callback, nullptr, napi_tsfn_nonblocking);', '    BeforeNativeSubmit();\n    const auto status = napi_call_threadsafe_function(callback, nullptr, napi_tsfn_nonblocking);');
      const injectedBinary = compile('constructor-injection', injected);
      run(injectedBinary, 'thread-failure'); run(injectedBinary, 'submit-lease');
    }
    if (process.argv.includes('--negative-controls')) {
      if (failures) throw new Error('Negative controls require GREEN candidate');
      const mutants = [
        ['window-unbounded', 'pause-js', 'MAX_OUTSTANDING_BATCHES = 4;', 'MAX_OUTSTANDING_BATCHES = 40;'],
        ['byte-window-unbounded', 'bytes', 'MAX_OUTSTANDING_BYTES = 16 * 1024 * 1024;', 'MAX_OUTSTANDING_BYTES = 32 * 1024 * 1024;'],
        ['missing-finalizer-gate', 'lifecycle', ' || !o->stats.tsfnFinalized || o->controlPending', ' || o->controlPending'],
        ['marshal-no-retry', 'string-failure', 'MAX_MARSHAL_ATTEMPTS = 3;', 'MAX_MARSHAL_ATTEMPTS = 1;'],
        ['marshal-hot-spin', 'string-failure', 'RETRY_DELAY = std::chrono::milliseconds(50);', 'RETRY_DELAY = std::chrono::milliseconds(0);'],
        ['wrong-ack-validation', 'success', 'epoch == o->stats.epoch', 'true'],
        ['fault-resurrection', 'js-reentry', 'if (!o->stop) {\n            if (call != napi_ok)', 'if (true) {\n            if (call != napi_ok)']
      ];
      for (const [name, scenario, before, after] of mutants) run(compile(name, replaceOnce(source.replaceAll('\r\n', '\n'), before, after)), scenario, true);
    }
    console.log(`RESULT ${failures ? 'RED' : 'GREEN'}: ${checks} checks; ${failures} failing cases`);
    console.log(`SOURCE ${hash(fs.readFileSync(nativePath)) === hash(source) ? 'unchanged' : 'CHANGED DURING RUN'}`);
    const stable = inputFiles.every(file => hash(fs.readFileSync(path.join(root, file))) === inputHashes[file]);
    console.log(`INPUTS ${stable ? 'stable' : 'changed during run; results apply only to frozen hashes'}`);
    if (failures || !stable) process.exitCode = 1;
  } finally {
    if (path.dirname(path.resolve(build)) !== base || !path.basename(build).startsWith('telegram-receive-flow-')) throw new Error('Unsafe cleanup');
    if (process.argv.includes('--keep-build')) console.log(`EVIDENCE ${build}`);
    else fs.rmSync(build, { recursive: true, force: true });
  }
};
