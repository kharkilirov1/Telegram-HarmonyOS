// Node >= 24: actual AppStore, state, reducers, invariants and AppStoreSession .ets tests.
// Read-only host witness: no SDK/build, native TDLib, device, network or account actions.
// Only the platform hilog sink and Hypium assertions are replaced. Not an ArkTS compile.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const sources = {};
function load(relative, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  sources[relative] = createHash('sha256').update(source).digest('hex');
  const names = [...source.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, '');
  const js = stripTypeScriptTypes(code, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const errors = [];
const hilog = { debug() {}, info() {}, warn() {}, error(...args) { errors.push(args); } };
const main = 'entry/src/main/ets/';
const A = load(main + 'core/model/AppState.ets');
const td = load(main + 'models/td/common/index.ets');
const accessors = load(main + 'core/utils/tdAccessors.ets', td);
const U = load(main + 'core/model/dto/UserDto.ets', { ...accessors, hilog });
const E = load(main + 'core/model/AppEvent.ets', U);
const clone = load(main + 'core/utils/stateClone.ets', A);
const { authReducer } = load(main + 'core/reducers/authReducer.ets', { ...A, ...clone });
const { usersReducer } = load(main + 'core/reducers/usersReducer.ets', { ...A, ...clone });
const invariants = load(main + 'core/invariants/assertInvariants.ets', { ...A, ...accessors, hilog });
const store = load(main + 'core/store/AppStore.ets', { ...A, ...invariants, hilog });
const tests = [];
const hypium = {
  describe(_name, run) { run(); },
  it(name, _flag, run) { tests.push({ name, run }); },
  expect(actual) {
    return {
      assertEqual(expected) { assert.strictEqual(actual, expected); },
      assertTrue() { assert.strictEqual(actual, true); },
      assertFalse() { assert.strictEqual(actual, false); }
    };
  }
};
load('entry/src/ohosTest/ets/test/AppStoreSession.test.ets',
  { ...A, ...E, ...store, authReducer, usersReducer, ...hypium }).appStoreSessionTest();
async function mainTest() {
  assert.ok(tests.length > 0, 'test registration must not silently be empty');
  let failed = 0;
  for (const { name, run } of tests) {
    const priorErrors = errors.length;
    try {
      await run();
      assert.deepEqual(errors.slice(priorErrors), [], 'no swallowed AppStore/reducer errors');
      console.log(`PASS ${name}`);
    } catch (error) {
      failed++;
      console.log(`FAIL ${name}: ${error.stack}`);
      if (errors.length > priorErrors) console.log('STORE_ERRORS', JSON.stringify(errors.slice(priorErrors)));
    }
  }
  console.log(JSON.stringify({ passed: tests.length - failed, failed, sources }));
  process.exitCode = failed ? 1 : 0;
}
require('./host-test-completion.cjs').guardSuite(mainTest()).catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
