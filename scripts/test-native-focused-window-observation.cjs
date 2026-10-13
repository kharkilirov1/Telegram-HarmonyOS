// Runs the actual native test helpers with SDK calls modeled sequentially.
// The window finder honors every supplied filter field, including bundle AND focus.
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
    'omit-bundle': ['findWindow({ bundleName: observation.bundleName, focused: true })', 'findWindow({ focused: true })'],
    'omit-focus': ['findWindow({ bundleName: observation.bundleName, focused: true })', 'findWindow({ bundleName: observation.bundleName })'],
    'ignore-owner-change': ["  checkNativeUiObservation(observation);\n  if (ownedFocused !== undefined", "  if (ownedFocused !== undefined"],
    'single-sample': ['if (candidate !== undefined && candidate.state === sample.state && candidate.ability === sample.ability && candidate.windowId === sample.windowId)', 'if (true)']
  };
  assert(mutations[mutant], 'known mutation');
  const [before, after] = mutations[mutant];
  assert.equal(source.split(before).length - 1, 1, 'mutation must activate exactly once');
  source = source.replace(before, after);
}
const end = source.indexOf('export default function stabilizationNativeTest()');
assert(end > 1000, 'complete native helper source');
const code = stripTypeScriptTypes(source.slice(0, end).replace(/^import[\s\S]*?;\s*/gm, ''), { mode: 'transform' });
const appBundle = 'test.fixture';
const imeBundle = 'com.huawei.hmos.inputmethod';

function create(options = {}) {
  let now = 0, turn = 0, depth = 1, ownerValid = true, rpcCount = 0;
  const effects = [], logs = [], queries = [], actionTimes = [];
  const focusAt = () => (options.focuses ?? [appBundle])[Math.min(turn, (options.focuses ?? [appBundle]).length - 1)];
  const sdk = async (name, result) => {
    rpcCount++;
    now += options.rpcMs ?? 0;
    if (options.ownerChangeAtRpc === rpcCount) ownerValid = false;
    if (options.errorRpc === name) throw Object.assign(new Error('SDK failure'), { code: 17000001 });
    return result();
  };
  const focusedWindow = bundle => ({
    getBundleName: () => sdk('getBundleName', () => {
      if (options.staleFocus) throw Object.assign(new Error('focus destroyed'), { code: 17000004 });
      return bundle;
    }),
    isFocused: () => sdk('isFocused', () => !options.lostFocus && focusAt() === bundle)
  });
  const mainWindow = {
    getWindowProperties: () => ({ id: 30, windowType: 1, type: 1 }),
    getWindowAvoidArea: () => {
      const zero = { left: 0, top: 0, width: 0, height: 0 };
      return { visible: true, leftRect: zero, topRect: zero, rightRect: zero, bottomRect: zero };
    }
  };
  const ability = { context: { abilityInfo: { name: 'TestAbility', bundleName: appBundle },
    currentHapModuleInfo: { name: 'entry' }, windowStage: { getMainWindowSync: () => mainWindow } } };
  const otherAbility = { ...ability };
  const owner = {};
  const fixture = { navigationDepth: () => depth, navigationBound: () => true, captureUiOwnership: () => owner,
    isUiOwnershipCurrent: () => ownerValid, isUiOwnershipPopped: () => depth === 0 && ownerValid };
  const driver = {
    findWindow: async filter => {
      queries.push({ ...filter });
      return sdk('findWindow', () => {
        // Keep the app's visible background window when another window owns focus.
        const focusedBundle = focusAt();
        const windows = [{ bundleName: appBundle, focused: focusedBundle === appBundle }];
        if (focusedBundle && focusedBundle !== appBundle) windows.unshift({ bundleName: focusedBundle, focused: true });
        const match = windows.find(w => Object.entries(filter).every(([field, value]) => w[field] === value));
        return match ? focusedWindow(match.bundleName) : undefined;
      });
    },
    delayMs: async ms => { now += ms; turn++; },
    pressBack: async () => { assert.equal(focusAt(), appBundle, 'no Back into foreign/absent focus'); effects.push('navigate'); actionTimes.push(now); depth--; },
    waitForIdle: async () => true,
    waitForComponent: async () => ({})
  };
  const expect = value => ({ assertTrue: () => assert.equal(value, true), assertFalse: () => assert.equal(value, false), assertEqual: expected => assert.equal(value, expected) });
  const api = new Function('abilityDelegatorRegistry', '$r', 'StabilizationNativeFixture', 'SlowmodeNativeFixture', 'window', 'Date', 'console', 'expect', 'ON',
    code + ';return { back, readFocusedBundle, createObservation: () => new NativeUiObservation(1) };')(
    { getArguments: () => ({ bundleName: appBundle }), getAbilityDelegator: () => ({ getCurrentTopAbility: async () => options.abilityChangeAfterTurn && turn > 0 ? otherAbility : ability }) },
    () => ({ moduleName: 'entry' }), fixture, { configurationReady: () => true },
    { getLastWindow: async () => mainWindow, AvoidAreaType: { TYPE_KEYBOARD: 3 }, WindowType: { TYPE_MAIN: 1, TYPE_SYSTEM_ALERT: 1 } },
    { now: () => now }, { info: line => logs.push(line) }, expect, { id: id => ({ id }) });
  const observation = api.createObservation();
  return { run: () => api.back(driver), readFocus: () => api.readFocusedBundle(driver, observation), observation,
    effects, logs, queries, actionTimes, elapsed: () => now, rpcCount: () => rpcCount };
}

const tests = [];
const test = (name, run) => tests.push({ name, run });
test('slow sequential window RPCs still obtain two coherent Back samples inside unchanged 10s', async () => {
  const f = create({ rpcMs: 800 });
  await assert.doesNotReject(f.run());
  assert.deepEqual(f.effects, ['navigate']);
  assert.equal(f.actionTimes[0], 5050, 'four combined focus queries and two panel queries, then 250ms sample separation');
  assert(f.logs.some(line => line.includes('back-combined-two-coherent-samples')));
  assert.equal(f.logs.filter(line => /keyboard-combined-clear-sample/.test(line)).length, 2);
});
test('focus query binds expected bundle and focus together without property re-enumeration', async () => {
  const f = create(); assert.equal(await f.readFocus(), appBundle);
  assert.deepEqual(f.queries, [{ bundleName: appBundle, focused: true }]);
  assert.equal(f.rpcCount(), 1);
});
test('foreign focused window is rejected even with a visible background app window', async () => {
  const f = create({ focuses: ['foreign.application'] });
  await assert.rejects(f.run(), /foreign focused owner/); assert.deepEqual(f.effects, []);
  assert(f.queries.some(q => q.focused === true && q.bundleName === undefined), 'generic foreign-owner fallback runs');
});
test('IME focus uses the existing generic fallback and preserves its distinct bundle', async () => {
  const f = create({ focuses: [imeBundle] });
  assert.equal(await f.readFocus(), imeBundle); assert.deepEqual(f.effects, []);
  assert(f.queries.some(q => q.focused === true && q.bundleName === undefined));
});
test('absent focus cannot authorize an app owner from its background window', async () => {
  const f = create({ focuses: [undefined] });
  assert.equal(await f.readFocus(), undefined); assert.deepEqual(f.effects, []);
  await assert.rejects(f.run(), /deadline exhausted|sample limit exhausted/); assert.deepEqual(f.effects, []);
});
test('destroyed fallback handles retain the bounded stale-handle rejection', async () => {
  const f = create({ focuses: [imeBundle], staleFocus: true });
  assert.equal(await f.readFocus(), undefined); assert.equal(await f.readFocus(), undefined);
  await assert.rejects(f.readFocus(), /destroyed-handle limit exhausted/); assert.deepEqual(f.effects, []);
});
test('fallback handle losing focus is an invalid sample', async () => {
  const f = create({ focuses: [imeBundle], lostFocus: true });
  assert.equal(await f.readFocus(), undefined); assert.deepEqual(f.effects, []);
});
test('owner changes during a successful combined query fail before returning owner proof', async () => {
  const f = create({ ownerChangeAtRpc: 1 });
  await assert.rejects(f.readFocus(), /route\/session identity changed/); assert.deepEqual(f.effects, []);
});
test('bundle changing between coherent samples prevents navigation', async () => {
  const f = create({ focuses: [appBundle, 'foreign.application'] });
  await assert.rejects(f.run(), /foreign focused owner/); assert.deepEqual(f.effects, []);
});
test('same-bundle ability replacement between samples remains rejected', async () => {
  const f = create({ abilityChangeAfterTurn: true });
  await assert.rejects(f.run(), /Back ability identity changed/); assert.deepEqual(f.effects, []);
});
test('combined query errors fail closed without fallback or action replay', async () => {
  const f = create({ errorRpc: 'findWindow' });
  await assert.rejects(f.readFocus(), /SDK failure/); assert.deepEqual(f.effects, []); assert.equal(f.queries.length, 1);
});
test('one over-budget query cannot return a successful owner proof', async () => {
  const f = create({ rpcMs: 10001 });
  await assert.rejects(f.readFocus(), /deadline exhausted/); assert.deepEqual(f.effects, []);
});

let suiteComplete = false;
const watchdog = setTimeout(() => {
  if (!suiteComplete) { console.error('Native focus observation host suite did not finish within 3s'); process.exitCode = 1; }
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
