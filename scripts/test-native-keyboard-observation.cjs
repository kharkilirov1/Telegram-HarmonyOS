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
    'empty-as-clear': ["      return undefined;\n    }\n    if (bundle !== CONTROLLED_IME_BUNDLE)", "      return false;\n    }\n    if (bundle !== CONTROLLED_IME_BUNDLE)"],
    'empty-require-dismiss': ["(observation.keyboardDismissActions === 0 || observation.keyboardDismissActions === 1)", "observation.keyboardDismissActions === 1"],
    'empty-invalid-dismiss-count': ["(observation.keyboardDismissActions === 0 || observation.keyboardDismissActions === 1)", "true"],
    'empty-positive-area': ["observation.navigationBackActions === 0 && !observation.keyboardAreaPositive", "observation.navigationBackActions === 0"],
    'empty-after-navigation': ["observation.navigationBackActions === 0 && !observation.keyboardAreaPositive", "!observation.keyboardAreaPositive"],
    'empty-falsy': ["bundle === '' && (observation.keyboardDismissActions", "!bundle && (observation.keyboardDismissActions"],
    'empty-whitespace': ["bundle === '' && (observation.keyboardDismissActions", "typeof bundle === 'string' && bundle.trim() === '' && (observation.keyboardDismissActions"],
    'empty-no-shared-limit': ["      if (observation.keyboardStaleHandles >= 3) blockNativeUi(observation, 'Back keyboard invalidated-sample limit exhausted');", ""],
    'empty-reset-shared-count': ["      observation.keyboardStaleHandles++; observation.keyboardPanel = 'empty-owner-under-owned-context';", "      observation.keyboardStaleHandles = 1; observation.keyboardPanel = 'empty-owner-under-owned-context';"],
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
  const properties = () => ({ id: current().windowId ?? 30, windowType: 1, type: 1 });
  const mainWindow = { getWindowProperties: properties, getWindowAvoidArea() {
    const positive = current().area;
    const empty = { left: 0, top: 0, width: 0, height: 0 };
    return { visible: true, leftRect: empty, rightRect: empty, topRect: empty,
      bottomRect: { left: 0, top: 1500, width: positive ? 1000 : 0, height: options.invalidGeometry ? -1 : positive ? 500 : 0 } };
  } };
  const ability = { context: { abilityInfo: { name: 'TestAbility', bundleName: bundle },
    currentHapModuleInfo: { name: 'entry' }, windowStage: { getMainWindowSync: () => mainWindow } } };
  const focusedWindow = { getBundleName: async () => options.foreignFocus || current().foreignFocus ? 'foreign.application' : bundle, isFocused: async () => true };
  const panel = { getBundleName: async () => {
      if (current().changeOwnerOnBundle) ownerValid = false;
      if (current().bundleError) throw Object.assign(new Error('panel read failed'), { code: current().bundleError });
      return Object.hasOwn(current(), 'panelBundle') ? current().panelBundle : 'com.huawei.hmos.inputmethod';
    },
    getBounds: async () => {
      if (options.stalePanel) throw Object.assign(new Error('destroyed panel'), { code: 17000004 });
      return options.invalidPanel ? { left: 1, right: 1, top: 0, bottom: 100 } : { left: 0, top: 1500, right: 1000, bottom: 2000 };
    }, isFocused: async () => false };
  const fixture = { navigationDepth: () => depth, navigationBound: () => true,
    captureUiOwnership: () => owner, isUiOwnershipCurrent: () => ownerValid,
    isUiOwnershipPopped: () => depth === 0 && ownerValid };
  const driver = { findWindow: async filter => {
      const windows = [{ bundleName: options.foreignFocus || current().foreignFocus ? 'foreign.application' : bundle, focused: true, handle: focusedWindow }];
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
    code + ';return { back, acquireBackKeyboardState, readVisibleKeyboardPanel, createObservation: () => new NativeUiObservation(1) };')(
    { getArguments: () => ({ bundleName: bundle }), getAbilityDelegator: () => ({ getCurrentTopAbility: async () => ability }) },
    () => ({ moduleName: 'entry' }), fixture, { configurationReady: () => true },
    { getLastWindow: async () => mainWindow, AvoidAreaType: { TYPE_KEYBOARD: 3 }, WindowType: { TYPE_MAIN: 1, TYPE_SYSTEM_ALERT: 1 } },
    { now: () => now }, { info: line => logs.push(line) }, expect, { id: id => ({ id }) });
  return { run: () => api.back(driver), observe: () => api.acquireBackKeyboardState(driver, api.createObservation(), false), effects, logs, actionTimes, elapsed: () => now,
    panelAfterNavigation: () => {
      // Defensive boundary: a consumed navigation proof must not admit an empty panel.
      const observation = api.createObservation(); observation.keyboardDismissActions = 1; observation.navigationBackActions = 1;
      return api.readVisibleKeyboardPanel(driver, observation);
    },
    panelWithInvalidDismissCount: () => {
      const observation = api.createObservation(); observation.keyboardDismissActions = 2;
      return api.readVisibleKeyboardPanel(driver, observation);
    }
  };
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

// These drive the actual native-test helpers; only platform responses/time are injected.
const emptyOwner = { area: false, panel: true, panelBundle: '' };
test('empty owner after the single proven dismissal is discarded before two new clear samples', async () => {
  const f = create([fixed], { afterDismiss: [emptyOwner, clear, clear] });
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['dismiss', 'navigate']);
  assert.deepEqual(f.actionTimes, [250, 750], 'empty ownership grants no clear sample');
  assert.equal(f.logs.filter(line => line.includes('event=keyboard-empty-owner-sample-invalidated')).length, 1);
});
test('two empty owners consume the existing bounded invalidation allowance', async () => {
  const f = create([fixed], { afterDismiss: [emptyOwner, emptyOwner, clear, clear] });
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['dismiss', 'navigate']);
  assert.deepEqual(f.actionTimes, [250, 1000]);
});
test('empty owner interrupts an apparent clear and requires a completely new clear pair', async () => {
  const f = create([fixed], { afterDismiss: [clear, emptyOwner, clear, clear] });
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['dismiss', 'navigate']);
  assert.deepEqual(f.actionTimes, [250, 1000], 'clear before empty cannot survive invalidation');
});
test('three persistent empty owners stop at the existing invalidation ceiling without another key', async () => {
  const f = create([fixed], { afterDismiss: [emptyOwner] });
  await assert.rejects(f.run(), /invalidated-sample limit exhausted/); assert.deepEqual(f.effects, ['dismiss']);
  assert.equal(f.elapsed(), 750);
});
test('empty owner without dismissal is discarded until two fresh clear samples authorize navigation', async () => {
  const f = create([emptyOwner, clear, clear]);
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['navigate']);
  assert.deepEqual(f.actionTimes, [500], 'unknown ownership grants neither dismissal nor a clear sample');
});
test('empty owner with positive keyboard area after dismissal remains blocked', async () => {
  const f = create([fixed], { afterDismiss: [{ ...emptyOwner, area: true }, clear, clear] });
  await assert.rejects(f.run(), /foreign bundle/); assert.deepEqual(f.effects, ['dismiss']);
});
test('empty owner after recorded navigation remains blocked', async () => {
  const f = create([emptyOwner]); await assert.rejects(f.panelAfterNavigation(), /foreign bundle/);
  assert.deepEqual(f.effects, []);
});
for (const [kind, panelBundle] of [
  ['foreign string', 'foreign.application'], ['whitespace string', ' '], ['undefined', undefined],
  ['null', null], ['false', false], ['zero', 0], ['object', {}]
]) test(kind + ' panel owner after dismissal remains blocked', async () => {
  const f = create([fixed], { afterDismiss: [{ ...emptyOwner, panelBundle }, clear, clear] });
  await assert.rejects(f.run(), /foreign bundle/); assert.deepEqual(f.effects, ['dismiss']);
});
test('foreign focused owner before an empty panel sample still blocks', async () => {
  const f = create([fixed], { afterDismiss: [{ ...emptyOwner, foreignFocus: true }] });
  await assert.rejects(f.run(), /foreign focused owner/); assert.deepEqual(f.effects, ['dismiss']);
});
test('route ownership changing while empty bundle resolves still blocks', async () => {
  const f = create([fixed], { afterDismiss: [{ ...emptyOwner, changeOwnerOnBundle: true }] });
  await assert.rejects(f.run(), /route\/session identity changed/); assert.deepEqual(f.effects, ['dismiss']);
});
test('same-owner main window changing after empty invalidation still blocks', async () => {
  const f = create([fixed], { afterDismiss: [emptyOwner, { ...clear, windowId: 31 }] });
  await assert.rejects(f.run(), /main-window identity changed/); assert.deepEqual(f.effects, ['dismiss']);
});
test('keyboard reappearing after clear interrupted by empty ownership still blocks', async () => {
  const f = create([fixed], { afterDismiss: [clear, emptyOwner, fixed] });
  await assert.rejects(f.run(), /Keyboard reappeared after dismissal/); assert.deepEqual(f.effects, ['dismiss']);
});
test('stale plus empty plus empty share one three-sample ceiling', async () => {
  const f = create([fixed], { afterDismiss: [{ ...emptyOwner, bundleError: 17000004 }, emptyOwner, emptyOwner] });
  await assert.rejects(f.run(), /invalidated-sample limit exhausted/); assert.deepEqual(f.effects, ['dismiss']);
  assert.equal(f.elapsed(), 750);
});
test('empty plus stale plus stale share one three-sample ceiling', async () => {
  const stale = { ...emptyOwner, bundleError: 17000004 };
  const f = create([fixed], { afterDismiss: [emptyOwner, stale, stale] });
  await assert.rejects(f.run(), /destroyed-handle limit exhausted/); assert.deepEqual(f.effects, ['dismiss']);
  assert.equal(f.elapsed(), 750);
});
test('unclassified panel error after dismissal still stops without retry or another key', async () => {
  const f = create([fixed], { afterDismiss: [{ ...emptyOwner, bundleError: 17000002 }, clear, clear] });
  await assert.rejects(f.run(), error => error.code === 17000002); assert.deepEqual(f.effects, ['dismiss']);
  assert.equal(f.elapsed(), 250);
});


test('two empty owners without dismissal consume allowance before a new clear pair', async () => {
  const f = create([emptyOwner, emptyOwner, clear, clear]);
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['navigate']); assert.deepEqual(f.actionTimes, [750]);
});
test('empty owner without dismissal invalidates an earlier clear candidate', async () => {
  const f = create([clear, emptyOwner, clear, clear]);
  await assert.doesNotReject(f.run()); assert.deepEqual(f.effects, ['navigate']); assert.deepEqual(f.actionTimes, [750]);
});
test('three persistent empty owners without dismissal exhaust allowance with zero input', async () => {
  const f = create([emptyOwner]); await assert.rejects(f.run(), /invalidated-sample limit exhausted/);
  assert.deepEqual(f.effects, []); assert.equal(f.elapsed(), 500);
});
test('empty owner with positive area without dismissal still blocks with zero input', async () => {
  const f = create([{ ...emptyOwner, area: true }, clear, clear]);
  await assert.rejects(f.run(), /foreign bundle/); assert.deepEqual(f.effects, []);
});
test('impossible repeated dismissal count cannot admit an empty owner', async () => {
  const f = create([emptyOwner]); await assert.rejects(f.panelWithInvalidDismissCount(), /foreign bundle/);
  assert.deepEqual(f.effects, []);
});
for (const [kind, panelBundle] of [
  ['foreign string', 'foreign.application'], ['whitespace string', ' '], ['undefined', undefined],
  ['null', null], ['false', false], ['zero', 0], ['object', {}]
]) test(kind + ' panel owner without dismissal still blocks with zero input', async () => {
  const f = create([{ ...emptyOwner, panelBundle }, clear, clear]);
  await assert.rejects(f.run(), /foreign bundle/); assert.deepEqual(f.effects, []);
});
test('foreign focus without dismissal rejects before any empty-owner relaxation', async () => {
  const f = create([{ ...emptyOwner, foreignFocus: true }]);
  await assert.rejects(f.run(), /foreign focused owner/); assert.deepEqual(f.effects, []);
});
test('route ownership switch across empty-owner await without dismissal still blocks', async () => {
  const f = create([{ ...emptyOwner, changeOwnerOnBundle: true }]);
  await assert.rejects(f.run(), /route\/session identity changed/); assert.deepEqual(f.effects, []);
});
test('main-window switch after empty sample without dismissal still blocks', async () => {
  const f = create([emptyOwner, { ...clear, windowId: 31 }]);
  await assert.rejects(f.run(), /main-window identity changed/); assert.deepEqual(f.effects, []);
});
test('stale then empty then empty without dismissal share the existing ceiling', async () => {
  const f = create([{ ...emptyOwner, bundleError: 17000004 }, emptyOwner, emptyOwner]);
  await assert.rejects(f.run(), /invalidated-sample limit exhausted/); assert.deepEqual(f.effects, []); assert.equal(f.elapsed(), 500);
});
test('empty then stale then stale without dismissal share the existing ceiling', async () => {
  const stale = { ...emptyOwner, bundleError: 17000004 }; const f = create([emptyOwner, stale, stale]);
  await assert.rejects(f.run(), /destroyed-handle limit exhausted/); assert.deepEqual(f.effects, []); assert.equal(f.elapsed(), 500);
});
test('unclassified panel error without dismissal still blocks without retries', async () => {
  const f = create([{ ...emptyOwner, bundleError: 17000002 }, clear, clear]);
  await assert.rejects(f.run(), error => error.code === 17000002); assert.deepEqual(f.effects, []); assert.equal(f.elapsed(), 0);
});
test('empty ownership may settle to fixed but cannot itself authorize dismissal', async () => {
  const f = create([emptyOwner, fixed, fixed]); await assert.doesNotReject(f.run());
  assert.deepEqual(f.effects, ['dismiss', 'navigate']); assert.deepEqual(f.actionTimes, [500, 750]);
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
