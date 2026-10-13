// Node >= 24. Read-only source execution; no SDK, native TDLib, network or accounts.
// Runs all StateClone tests and only FilePipeline / filesReducer (25 cases at creation).
// Reads the actual .ets tests and implementation; removes import/export wiring and types.
// Hypium assertions use node:assert/strict; only hilog is a no-op platform dependency.
// Other FilePipeline groups are deliberately outside this focused witness.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const sources = {};
function load(relative, deps = {}, names) {
  let code = fs.readFileSync(path.join(root, relative), 'utf8');
  sources[relative] = createHash('sha256').update(code).digest('hex');
  names ??= [...code.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  code = code.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, '');
  const js = stripTypeScriptTypes(code, {mode: 'transform', sourceUrl: relative});
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}
const main = 'entry/src/main/ets/';
const C = load(main + 'core/model/AppCommand.ets');
const A = load(main + 'core/model/AppState.ets', C);
const clone = load(main + 'core/utils/stateClone.ets', {...A, ...C});
const M = load(main + 'core/model/dto/MessageDto.ets');
const E = load(main + 'core/model/AppEvent.ets', M);
const { filesReducer } = load(main + 'core/reducers/filesReducer.ets', {
  ...A, ...clone, hilog: {debug() {}, info() {}, warn() {}, error() {}}
});
const { chatsReducer } = load(main + 'core/reducers/chatsReducer.ets', {...A, ...clone});
const results = [], scopes = [];
const hypium = {
  describe(name, run) {
    if (scopes[0] === 'FilePipeline' && name !== 'filesReducer') return;
    scopes.push(name);
    try { run(); } finally { scopes.pop(); }
  },
  it(name, _flag, run) {
    try {
      const result = run();
      assert.equal(result, undefined, 'Focused runner supports synchronous cases only');
      results.push({name: [...scopes, name].join(' / '), status: 'PASS'});
    } catch (error) {
      if (error.code !== 'ERR_ASSERTION') throw error;
      results.push({name: [...scopes, name].join(' / '), status: 'FAIL', actual: error.actual, expected: error.expected});
    }
  },
  expect(actual) {
    return {
      assertEqual(expected) { assert.strictEqual(actual, expected); },
      assertTrue() { assert.strictEqual(actual, true); },
      assertFalse() { assert.strictEqual(actual, false); }
    };
  }
};
load('entry/src/ohosTest/ets/test/StateClone.test.ets',
  {...A, ...C, ...E, ...clone, chatsReducer, ...hypium}).stateCloneTest();
load('entry/src/ohosTest/ets/test/FilePipeline.test.ets',
  {...A, ...E, filesReducer, ...hypium}).filePipelineTest();
for (const r of results) console.log(JSON.stringify(r));
console.log(JSON.stringify({summary: {
  passed: results.filter(r => r.status === 'PASS').length,
  failed: results.filter(r => r.status === 'FAIL').length
}, sources}));
process.exitCode = results.some(r => r.status === 'FAIL') ? 1 : 0;

