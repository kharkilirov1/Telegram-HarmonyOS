// Run the same SDK-free behavioral suites locally and in CI (Node >=24).
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
function discoverSuites() {
  return fs.readdirSync(__dirname).filter(p => /^test-.*\.cjs$/.test(p)).sort();
}
function runSuites(files, { spawn = spawnSync, log = console.log } = {}) {
  if (files.length === 0) { log('FAIL no host suites discovered'); return 1; }
  let failed = 0;
  for (const file of files) {
    const result = spawn(process.execPath, [path.join(__dirname, file)], {
      cwd: root, encoding: 'utf8', timeout: file === 'test-chat-screen-decomposition.cjs' ? 240000 : 120000, maxBuffer: 4 * 1024 * 1024
    });
    const passed = result.status === 0 && !result.error && !result.signal;
    log(`${passed ? 'PASS' : 'FAIL'} ${file}`);
    if (!passed) {
      failed++;
      log(result.stdout ?? '');
      log(result.stderr ?? '');
      log(String(result.error ?? result.signal ?? `exit ${result.status}`));
    }
  }
  log(JSON.stringify({ suites: files.length, passed: files.length - failed, failed }));
  return failed === 0 ? 0 : 1;
}
module.exports = { discoverSuites, runSuites };
if (require.main === module) process.exitCode = runSuites(discoverSuites());
