const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const runner = path.join(__dirname, 'run-host-tests.cjs');
assert.ok(fs.existsSync(runner), 'behavioral CI entry point is required');
const { discoverSuites, runSuites } = require(runner);
const discovered = discoverSuites();
assert.deepEqual(discovered, fs.readdirSync(__dirname).filter(p => /^test-.*\.cjs$/.test(p)).sort());
assert.ok(discovered.includes('test-chat-list-mark-read.cjs'));
const calls = [];
const log = () => {};
assert.equal(runSuites([], { log, spawn: () => { throw new Error('must not spawn'); } }), 1);
assert.equal(runSuites(['test-a.cjs', 'test-b.cjs'], { log, spawn: (exe, args, options) => {
  calls.push({ exe, args, options });
  return { status: 0, stdout: 'PASS synthetic child', stderr: '' };
} }), 0);
assert.equal(calls.length, 2);
assert.ok(calls.every(c => c.exe === process.execPath && c.options.cwd === root && c.options.shell !== true));
assert.deepEqual(calls[0].args, [path.join(__dirname, 'test-a.cjs')]);
for (const result of [
  { status: 1, stdout: 'FAIL synthetic child', stderr: '' },
  { status: null, signal: 'SIGTERM', stdout: '', stderr: '' },
  { status: null, error: new Error('synthetic spawn failure') }
]) {
  let count = 0;
  assert.equal(runSuites(['test-a.cjs', 'test-b.cjs'], { log, spawn: () => ++count === 1 ? result : { status: 0 } }), 1);
  assert.equal(count, 2, 'one failing suite must not skip the remaining diagnostics');
}
const workflow = fs.readFileSync(path.join(root, '.github/workflows/smoke.yml'), 'utf8');
const job = workflow.split('  smoke-host:')[1]?.split('\n  smoke-build-harmony:')[0] ?? '';
assert.match(job, /node-version: ['"]24['"]/);
assert.match(job, /node scripts\/run-host-tests\.cjs/);
assert.doesNotMatch(job, /continue-on-error|\bif:/);
const budgets = [];
assert.equal(runSuites(['test-chat-screen-decomposition.cjs', 'test-a.cjs'], { log, spawn: (exe, args, options) => { budgets.push(options.timeout); return { status: 0 }; } }), 0);
assert.deepEqual(budgets, [240000, 120000], 'bounded aggregate decomposition budget; ordinary child budget unchanged');
console.log('PASS host runner: discovery, empty/failure/signal/spawn guards, serial continuation, required CI path');
