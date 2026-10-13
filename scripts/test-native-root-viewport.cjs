// Exercises actual rootReady/open/owned gesture helpers at SDK boundaries.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const option = key => process.argv.find(a => a.startsWith(key + '='))?.slice(key.length + 1);
const sourcePath = option('--source') ? path.resolve(option('--source')) :
  path.resolve(__dirname, '../entry/src/ohosTest/ets/test/StabilizationNative.test.ets');
let source = fs.readFileSync(sourcePath, 'utf8').replace(/\r\n/g, '\n');
const mutant = option('--mutant');
if (mutant) {
  const mutations = {
    'skip-viewport': ["          await scrollOwnedToTop(driver, root, 40000, 0, 'chat-test-fixture-scroll');", ''],
    'scroll-shared-back': ['        if (shared === undefined) {', '        if (true) {'],
    'reset-observation': ["          checkNativeUiObservation(observation);\n          await acquireOwnedUiContext(driver, 0, observation);", '          await acquireOwnedUiContext(driver, 0);'],
    'skip-post-owner-proof': ["          await acquireOwnedUiContext(driver, 0, observation);", '']
  };
  assert(mutations[mutant], 'known mutation');
  const [before, after] = mutations[mutant];
  assert.equal(source.split(before).length - 1, 1, 'mutation must activate exactly once');
  source = source.replace(before, after);
}
const end = source.indexOf('export default function stabilizationNativeTest()');
assert(end > 1000);
const code = stripTypeScriptTypes(source.slice(0, end).replace(/^import[\s\S]*?;\s*/gm, ''), { mode: 'transform' });
const appBundle = 'test.fixture';
function create(options = {}) {
  let now = 0, depth = options.depth ?? 0, generation = 0, focusReads = 0;
  let viewport = options.viewport ?? 'bottom', focus = options.foreignFocus ? 'foreign.application' : appBundle;
  let preparations = 0, clicks = 0, topCalls = 0;
  const events = [], logs = [];
  const button = { click: async () => { events.push('route-click'); clicks++; depth = 1; } };
  const root = {
    scrollToTop: async speed => {
      assert.equal(speed, 40000); assert.equal(focus, appBundle); assert.equal(depth, 0);
      topCalls++; events.push('scroll-top'); now += options.scrollMs ?? 500;
      if (options.scrollFailure) throw new Error('native top scroll failed');
      if (options.changeOwnerDuringScroll) generation++;
      if (options.changeDepthDuringScroll) depth = 1;
      if (options.foreignAfterScroll) focus = 'foreign.application';
      viewport = 'top';
    },
    scrollSearch: async selector => {
      assert.equal(selector.id, 'stabilization-open-startup');
      events.push('route-search-' + viewport);
      now += viewport === 'bottom' ? 14013 : 50;
      return button;
    }
  };
  const ability = { context: { abilityInfo: { name: 'TestAbility', bundleName: appBundle }, currentHapModuleInfo: { name: 'entry' } } };
  const fixture = {
    navigationDepth: () => depth, navigationBound: () => true,
    captureUiOwnership: () => ({ generation }), isUiOwnershipCurrent: owner => owner.generation === generation
  };
  const driver = {
    findWindow: async filter => {
      focusReads++;
      if (options.changeOwnerAtFocusRead === focusReads) generation++;
      const windows = [{ bundleName: focus, focused: true }];
      const found = windows.find(w => Object.entries(filter).every(([key, value]) => w[key] === value));
      return found ? { getBundleName: async () => found.bundleName, isFocused: async () => found.bundleName === focus } : undefined;
    },
    waitForComponent: async selector => selector.id === 'chat-test-fixture-scroll' && !options.missingRoot ? root : undefined,
    delayMs: async ms => { now += ms; }, waitForIdle: async () => true
  };
  const api = new Function('abilityDelegatorRegistry', '$r', 'StabilizationNativeFixture', 'SlowmodeNativeFixture', 'Date', 'console', 'ON',
    code + ';return { rootReady, open, observation: () => new NativeUiObservation(0) };')(
    { getArguments: () => ({ bundleName: appBundle }), getAbilityDelegator: () => ({ getCurrentTopAbility: async () => ability }) },
    () => ({ moduleName: 'entry' }), fixture, { configurationReady: () => true }, { now: () => now },
    { info: line => logs.push(line) }, { id: id => ({ id }) });
  return {
    run: async () => { await api.rootReady(driver); events.push('prepare-startup'); preparations++; await api.open(driver, 'stabilization-open-startup'); },
    ready: () => api.rootReady(driver), sharedReady: () => api.rootReady(driver, api.observation()),
    events, logs, preparations: () => preparations, clicks: () => clicks, topCalls: () => topCalls, elapsed: () => now
  };
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
test('bottom viewport is restored by one owned gesture before startup preparation and route click', async () => {
  const f = create(); await assert.doesNotReject(f.run());
  assert.deepEqual(f.events, ['scroll-top', 'prepare-startup', 'route-search-top', 'route-click']);
  assert.equal(f.topCalls(), 1); assert.equal(f.preparations(), 1); assert.equal(f.clicks(), 1);
  assert(f.elapsed() < 10000);
  const action = f.logs.findIndex(line => line.includes('-scrollToTop'));
  assert(action > 0); assert(f.logs.slice(0, action).some(line => line.includes('owned-coherent-two-samples')));
});
test('shared Back root return keeps its original path and performs no viewport gesture', async () => {
  const f = create(); await assert.doesNotReject(f.sharedReady());
  assert.equal(f.topCalls(), 0); assert.equal(f.preparations(), 0); assert.equal(f.clicks(), 0);
  assert.equal(f.elapsed(), 500, 'unchanged two owner pairs with their existing sample pauses');
});
for (const [name, options, reason, topCalls] of [
  ['native scroll failure', { scrollFailure: true }, /native top scroll failed/, 1],
  ['owner changes during scroll', { changeOwnerDuringScroll: true }, /route\/session identity changed/, 1],
  ['depth changes during scroll', { changeDepthDuringScroll: true }, /navigation depth changed/, 1],
  ['owner changes immediately before gesture', { changeOwnerAtFocusRead: 5 }, /route\/session identity changed/, 0],
  ['foreign focus before gesture', { foreignFocus: true }, /foreign focused owner/, 0],
  ['foreign focus after gesture', { foreignAfterScroll: true }, /foreign focused owner/, 1],
  ['owner changes during final observation', { changeOwnerAtFocusRead: 7 }, /route\/session identity changed/, 1],
  ['single scroll outlives unchanged observation deadline', { scrollMs: 10001 }, /deadline exhausted/, 1],
  ['root fixture missing', { missingRoot: true }, /Actual owned Index root is absent/, 0],
  ['nonempty navigation stack', { depth: 1 }, /actual empty Index stack/, 0]
]) test(name + ' prevents startup preparation and click without replay', async () => {
  const f = create(options); await assert.rejects(f.run(), reason);
  assert.equal(f.preparations(), 0); assert.equal(f.clicks(), 0); assert.equal(f.topCalls(), topCalls);
});
let suiteComplete = false;
const watchdog = setTimeout(() => {
  if (!suiteComplete) { console.error('Native root viewport suite did not finish within 3s'); process.exitCode = 1; }
}, 3000);
(async () => {
  const results = [];
  for (const { name, run } of tests) {
    try { await run(); results.push({ name, pass: true }); }
    catch (error) { results.push({ name, pass: false, code: error.code, message: error.message }); }
  }
  const receipt = { sourcePath, mutant, passed: results.filter(r => r.pass).length, total: results.length, results };
  console.log(JSON.stringify(receipt, null, 2));
  if (option('--receipt')) fs.writeFileSync(path.resolve(option('--receipt')), JSON.stringify(receipt, null, 2) + '\n');
  process.exitCode = process.exitCode || (receipt.passed === receipt.total ? 0 : 1);
})().catch(error => { console.error(error); process.exitCode = 1; })
  .finally(() => { suiteComplete = true; clearTimeout(watchdog); });
