const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const helper = path.join(__dirname, 'host-test-completion.cjs');
const options = { cwd: path.resolve(__dirname, '..'), encoding: 'utf8', timeout: 15000 };
function child(body) {
  const result = spawnSync(process.execPath, ['-e', `const { guardSuite } = require(process.argv[1]);\n${body}`, helper], options);
  assert.equal(result.error, undefined);
  assert.equal(result.signal, null);
  return result;
}
const completed = child("new Promise(() => {}); guardSuite(Promise.resolve('completed')).then(value => console.log(value));");
assert.equal(completed.status, 0, 'completed suite may leave deliberately pending fixture promises');
assert.match(completed.stdout, /completed/);
assert.doesNotMatch(completed.stderr, /incomplete async suite/);
const rejected = child("guardSuite(Promise.reject(new Error('expected rejection'))).catch(error => { console.error(error.message); process.exitCode = 7; });");
assert.equal(rejected.status, 7, 'existing catch retains rejection/exit semantics');
assert.match(rejected.stderr, /expected rejection/);
assert.doesNotMatch(rejected.stderr, /incomplete async suite/);
for (const previousCode of [0, 3]) {
  const pending = child(`process.exitCode = ${previousCode}; guardSuite(new Promise(() => {}));`);
  assert.equal(pending.status, previousCode || 2);
  assert.match(pending.stderr, /HARNESS_ERROR incomplete async suite/);
}

// Reproduce the actual adapter test's missing-completion failure, not just a
// synthetic helper promise. Source files remain unchanged; edit memory only.
const adapter = path.join(__dirname, 'test-td-gateway-adapter-session.cjs');
const baseline = spawnSync(process.execPath, [adapter], options);
assert.equal(baseline.error, undefined);
assert.equal(baseline.signal, null);
assert.equal(baseline.status, 0, baseline.stdout + baseline.stderr);
assert.match(baseline.stdout, /4\/4 PASS/);
const mutate = `
const fs = require('node:fs'), Module = require('node:module'), path = require('node:path');
const file = process.argv[1];
const source = fs.readFileSync(file, 'utf8');
const site = "f.pending[0].resolve('new-account-response');";
if (source.split(site).length !== 2) throw new Error('Adapter pending-response mutation must have one anchor');
const m = new Module(file); m.filename = file; m.paths = Module._nodeModulePaths(path.dirname(file));
m._compile(source.replace(site, '/* Keep the actual fixture request pending. */'), file);
`;
const incomplete = spawnSync(process.execPath, ['-e', mutate, adapter], options);
assert.equal(incomplete.error, undefined);
assert.equal(incomplete.signal, null);
assert.equal(incomplete.status, 2, incomplete.stdout + incomplete.stderr);
assert.equal(incomplete.stdout.split(/\r?\n/).filter(line => line.startsWith('PASS ')).length, 1);
assert.doesNotMatch(incomplete.stdout, /4\/4 PASS/);
assert.match(incomplete.stderr, /HARNESS_ERROR incomplete async suite/);
console.log('PASS suite completion: completed/rejected/pending guards, pending fixture allowance, actual adapter 4/4 and incomplete 1/4 rejection');
