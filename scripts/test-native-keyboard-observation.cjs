// Executes the actual native test's Back observation callbacks, with only SDK boundaries modeled.
// No device calls and no source checkout mutations. Real native rerun is still required.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const path = require('node:path');
const option = key => process.argv.find(a => a.startsWith(key + '='))?.slice(key.length + 1);
const sourcePath = option('--source') ? path.resolve(option('--source')) :
  path.resolve(__dirname, '../entry/src/ohosTest/ets/test/StabilizationNative.test.ets');
let source = fs.readFileSync(sourcePath, 'utf8').replace(/\r\n/g, '\n');
const mutant = process.argv.find(a => a.startsWith('--mutant='))?.slice(9);
if (mutant) {
  const mutations = {
    'trust-area': ["    return sample;\n  }\n  sample.state = after ?", "  }\n  sample.state = after ?"],
    'retain-candidate': ["} else if (sample.state === NativeBackKeyboardState.Transient) {\n      candidate = undefined;", "} else if (sample.state === NativeBackKeyboardState.Transient) {"],
    'repeat-dismiss': ["    await acquireBackKeyboardState(driver, observation, true);", "    await driver.pressBack();\n    await acquireBackKeyboardState(driver, observation, true);"],
    'single-sample': ["if (candidate !== undefined && candidate.state === sample.state && candidate.ability === sample.ability && candidate.windowId === sample.windowId)", "if (true)"]
  };
  assert(mutations[mutant], 'known mutation');
  const [before, after] = mutations[mutant];
  assert.equal(source.split(before).length - 1, 1, 'mutation must activate exactly once');
  source = source.replace(before, after);
}
const prelude = source.slice(0, source.indexOf('export default function stabilizationNativeTest()'));
assert(prelude.length > 1000, 'load complete native helpers');
const code = stripTypeScriptTypes(prelude.replace(/^import[\s\S]*?;\s*/gm, ''), { mode: 'transform' });
const bundle = 'test.fixture';
const clear = { area: false, panel: false };
const fixed = { area: true, panel: true };
function create(frames, options = {}) {
  let now = 0, turn = 0, depth = 1, ownerValid = true, dismissed = false;
  const effects = [], logs = [], actionTimes = [];
  const current = () => (dismissed ? options.afterDismiss ?? [clear] : frames)[Math.min(turn, (dismissed ? options.afterDismiss ?? [clear] : frames).length - 1)];
  const owner = { routes: [{}] };
  const properties = () => ({ id: 30, windowType: 1, type: 1 });
  const mainWindow = { getWindowProperties: properties, getWindowAvoidArea() {
    const positive = current().area;
    const empty = { left: 0, top: 0, width: 0, height: 0 };
    return { visible: true, leftRect: empty, rightRect: empty, topRect: empty,
      bottomRect: { left: 0, top: 1500, width: positive ? 1000 : 0, height: options.invalidGeometry ? -1 : positive ? 500 : 0 } };
  } };
  const ability = { context: { abilityInfo: { name: 'TestAbility', bundleName: bundle },
    currentHapModuleInfo: { name: 'entry' }, windowStage: { getMainWindowSync: () => mainWindow } } };
  const focusedWindow = { getBundleName: async () => options.foreignFocus ? 'foreign.application' : bundle, isFocused: async () => true };
  const panel = { getBundleName: async () => 'com.huawei.hmos.inputmethod',
    getBounds: async () => {
      if (options.stalePanel) throw Object.assign(new Error('destroyed panel'), { code: 17000004 });
      return options.invalidPanel ? { left: 1, right: 1, top: 0, bottom: 100 } : { left: 0, top: 1500, right: 1000, bottom: 2000 };
    }, isFocused: async () => false };
  const fixture = { navigationDepth: () => depth, navigationBound: () => true,
    captureUiOwnership: () => owner, isUiOwnershipCurrent: () => ownerValid,
    isUiOwnershipPopped: () => depth === 0 && ownerValid };
  const driver = { findWindow: async filter => {
      const windows = [{ bundleName: options.foreignFocus ? 'foreign.application' : bundle, focused: true, handle: focusedWindow }];
      if (current().panel) windows.push({ bundleName: 'com.huawei.hmos.inputmethod', focused: false, handle: panel });
      return windows.find(value => Object.entries(filter).every(([key, expected]) => value[key] === expected))?.handle;
    },
    delayMs: async ms => { now += ms; turn++; if (options.changeOwner) ownerValid = false; },
    waitForComponent: async () => ({}), waitForIdle: async () => true,
    pressBack: async () => {
      // A disagreement must never be used to authorize any Back action.
      assert.equal(current().area, current().panel, 'no Back while SDK signals disagree');
      actionTimes.push(now);
      if (current().area) { effects.push('dismiss'); dismissed = true; turn = 0; }
      else { effects.push('navigate'); depth--; }
    }
  };
  const expect = value => ({ assertTrue: () => assert.equal(value, true), assertFalse: () => assert.equal(value, false), assertEqual: expected => assert.equal(value, expected) });
  const api = new Function('abilityDelegatorRegistry', '$r', 'StabilizationNativeFixture', 'SlowmodeNativeFixture', 'window', 'Date', 'console', 'expect', 'ON',
    code + ';return { back, acquireBackKeyboardState, createObservation: () => new NativeUiObservation(1) };')(
    { getArguments: () => ({ bundleName: bundle }), getAbilityDelegator: () => ({ getCurrentTopAbility: async () => ability }) },
    () => ({ moduleName: 'entry' }), fixture, { configurationReady: () => true },
    { getLastWindow: async () => mainWindow, AvoidAreaType: { TYPE_KEYBOARD: 3 }, WindowType: { TYPE_MAIN: 1, TYPE_SYSTEM_ALERT: 1 } },
    { now: () => now }, { info: line => logs.push(line) }, expect, { id: id => ({ id }) });
  return { run: () => api.back(driver), observe: () => api.acquireBackKeyboardState(driver, api.createObservation(), false), effects, logs, actionTimes, elapsed: () => now };
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
test('empty area plus closing panel settles to two coherent clear samples before one navigation', async () => {
  const f = create([{ area: false, panel: true }, clear, clear]);
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['navigate']);
  assert.equal(f.actionTimes[0], 500, 'both clear samples must precede navigation');
});
test('lagging positive area plus absent panel settles without a keyboard-dismiss action', async () => {
  const f = create([{ area: true, panel: false }, clear, clear]);
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['navigate']);
});
test('single apparent clear interrupted by disagreement must restart the coherent candidate', async () => {
  const f = create([clear, { area: false, panel: true }, clear, clear]);
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['navigate']);
  assert.equal(f.actionTimes[0], 750, 'the first clear candidate cannot survive disagreement');
});
test('persistent disagreement remains blocked with zero key actions within the existing observation bounds', async () => {
  const f = create([{ area: false, panel: true }]);
  await assert.rejects(f.run(), /deadline exhausted|sample limit exhausted|disagreement is ambiguous/);
  assert.deepEqual(f.effects, []); assert(f.elapsed() <= 10000);
});
test('fixed keyboard is dismissed once, dismissal transition settles, then exactly one navigation occurs', async () => {
  const f = create([fixed], { afterDismiss: [{ area: false, panel: true }, clear, clear] });
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['dismiss', 'navigate']);
  assert.deepEqual(f.actionTimes, [250, 750], 'dismissal transition has its own coherent clear pair');
});
test('persistent disagreement after dismissal permits no second dismissal or navigation', async () => {
  const f = create([fixed], { afterDismiss: [{ area: false, panel: true }] });
  await assert.rejects(f.run(), /deadline exhausted|sample limit exhausted|disagreement is ambiguous/);
  assert.deepEqual(f.effects, ['dismiss']); assert(f.elapsed() <= 10000);
});
test('keyboard reappearing after the first clear sample still aborts', async () => {
  const f = create([fixed], { afterDismiss: [clear, fixed] });
  await assert.rejects(f.run(), /Keyboard reappeared after dismissal/); assert.deepEqual(f.effects, ['dismiss']);
});
for (const [name, option, reason] of [
  ['foreign focus', { foreignFocus: true }, /foreign focused owner/],
  ['owner change', { changeOwner: true }, /route\/session identity changed/],
  ['invalid avoid geometry', { invalidGeometry: true }, /geometry is invalid/],
  ['invalid panel geometry', { invalidPanel: true }, /bounds are ambiguous/],
  ['repeated destroyed panels', { stalePanel: true }, /destroyed-handle limit exhausted/]
]) test(name + ' still blocks before any input', async () => {
  const f = create([fixed], option); await assert.rejects(f.run(), reason); assert.deepEqual(f.effects, []);
});
let suiteComplete = false;
const watchdog = setTimeout(() => {
  if (!suiteComplete) { console.error('Native keyboard observation host suite did not finish within 3s'); process.exitCode = 1; }
}, 3000);
(async () => {
  const results = [];
  for (const {name, run} of tests) {
    try { await run(); results.push({ name, pass: true }); }
    catch (error) { results.push({ name, pass: false, code: error.code, message: error.message }); }
  }
  const receipt = { sourcePath, mutant, passed: results.filter(r => r.pass).length, total: results.length, results };
  console.log(JSON.stringify(receipt, null, 2));
  if (option('--receipt')) fs.writeFileSync(path.resolve(option('--receipt')), JSON.stringify(receipt, null, 2) + '\n');
  process.exitCode = process.exitCode || (receipt.passed === receipt.total ? 0 : 1);
})().catch(error => { console.error(error); process.exitCode = 1; })
  .finally(() => { suiteComplete = true; clearTimeout(watchdog); });
