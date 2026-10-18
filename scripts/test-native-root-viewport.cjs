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
    'empty-as-clear': ["      return undefined;\n    }\n    if (bundle !== CONTROLLED_IME_BUNDLE)", "      return false;\n    }\n    if (bundle !== CONTROLLED_IME_BUNDLE)"],
    'skip-viewport': ["          await scrollOwnedToTop(driver, root, 40000, 0, 'chat-test-fixture-scroll', observation);", ''],
    'scroll-shared-back': ['        if (shared === undefined) {', '        if (true) {'],
    'reset-observation': ["          checkNativeUiObservation(observation);\n          await acquireOwnedUiContext(driver, 0, observation);", '          await acquireOwnedUiContext(driver, 0);'],
    'skip-post-owner-proof': ["          checkNativeUiObservation(observation);\n          await acquireOwnedUiContext(driver, 0, observation);", '          checkNativeUiObservation(observation);'],
    'independent-gesture-observation': ["await scrollOwnedToTop(driver, root, 40000, 0, 'chat-test-fixture-scroll', observation)", "await scrollOwnedToTop(driver, root, 40000, 0, 'chat-test-fixture-scroll')"],
    'skip-ime-target-refresh': ["const ownedTarget = await prepareOwnedGestureTarget(driver, target, targetId, observation);\n  recordOwnedAction(observation, 'scrollToTop');", "await acquireOwnedUiContext(driver, expectedDepth, observation);\n  const ownedTarget = target;\n  recordOwnedAction(observation, 'scrollToTop');"]
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
const imeBundle = 'com.huawei.hmos.inputmethod';
const selector = (key, value) => ({ [key === 'text' ? 'textValue' : key]: value, text(value) { this.textValue = value; return this; }, inWindow(value) { this.window = value; return this; } });
function create(options = {}) {
  let now = 0, depth = options.depth ?? 0, generation = 0, focusReads = 0;
  let viewport = options.viewport ?? 'bottom', focus = options.foreignFocus ? 'foreign.application' : appBundle;
  let preparations = 0, clicks = 0, topCalls = 0, rootLookups = 0, imePhase = 'none', oldTargetInvalid = false;
  let capturedOwners = 0;
  const events = [], logs = [];
  const button = { click: async () => { events.push('route-click'); clicks++; depth = 1; } };
  const root = {
    scrollToTop: async speed => {
      assert(!oldTargetInvalid, 'old root handle must be refreshed after IME decline');
      return performTop(speed);
    },
    scrollSearch: async selector => {
      assert.equal(selector.id, 'stabilization-open-startup');
      events.push('route-search-' + viewport);
      now += viewport === 'bottom' ? 14013 : 50;
      return button;
    }
  };
  const performTop = async speed => {
      assert.equal(speed, 40000); assert.equal(focus, appBundle); assert.equal(depth, 0);
      topCalls++; events.push('scroll-top'); now += options.scrollMs ?? 500;
      if (options.scrollFailure) throw new Error('native top scroll failed');
      if (options.changeOwnerDuringScroll) generation++;
      if (options.changeDepthDuringScroll) depth = 1;
      if (options.foreignAfterScroll) focus = 'foreign.application';
      viewport = 'top';
  };
  const freshRoot = { ...root, scrollToTop: performTop };
  const ability = { context: { abilityInfo: { name: 'TestAbility', bundleName: appBundle }, currentHapModuleInfo: { name: 'entry' } } };
  const fixture = {
    navigationDepth: () => depth, navigationBound: () => true,
    captureUiOwnership: () => { capturedOwners++; return { generation }; }, isUiOwnershipCurrent: owner => owner.generation === generation
  };
  const driver = {
    findWindow: async filter => {
      if (filter.bundleName === imeBundle && filter.focused === undefined && Object.prototype.hasOwnProperty.call(options, 'panelBundle')) {
        if (options.panelQueryError) throw options.panelQueryError;
        return { getBundleName: async () => { if (options.panelPropertyError) throw options.panelPropertyError; return options.panelBundle; },
          getBounds: async () => ({ left: 0, top: 0, right: 100, bottom: 100 }), isFocused: async () => false };
      }
      focusReads++;
      now += options.focusMs ?? 0;
      if (options.changeOwnerAtFocusRead === focusReads) generation++;
      if (options.foreignAtFocusRead === focusReads) focus = 'foreign.application';
      const windows = [{ bundleName: focus, focused: true }];
      const found = windows.find(w => Object.entries(filter).every(([key, value]) => w[key] === value));
      return found ? { getBundleName: async () => found.bundleName, isFocused: async () => found.bundleName === focus } : undefined;
    },
    waitForComponent: async selector => {
      if (selector.id !== 'chat-test-fixture-scroll' || options.missingRoot) return undefined;
      rootLookups++;
      if (rootLookups === 1 && options.imeAfterRootLookup) { focus = imeBundle; imePhase = 'firstUse'; }
      if (rootLookups === 2 && options.changeOwnerDuringRefresh) generation++;
      if (oldTargetInvalid) return options.missingRefreshedRoot ? undefined : freshRoot;
      return root;
    },
    findComponent: async selector => {
      if (focus !== imeBundle) return undefined;
      if (imePhase === 'firstUse') {
        if (selector.id === 'Paf.Permission.button_cancel') return { click: async () => { events.push('ime-cancel'); imePhase = 'confirmation'; } };
        if (selector.textValue === 'Agree' || selector.textValue === 'Celia Keyboard') return {};
      }
      if (imePhase === 'confirmation') {
        if (selector.id === 'advanced_dialog_button_2') return { click: async () => { events.push('ime-exit'); imePhase = 'done'; focus = appBundle; oldTargetInvalid = true; } };
        if (selector.textValue === 'Use Full mode' || selector.textValue === 'Use Basic mode') return {};
      }
      return undefined;
    },
    delayMs: async ms => { now += ms; }, waitForIdle: async () => true
  };
  const api = new Function('abilityDelegatorRegistry', '$r', 'StabilizationNativeFixture', 'SlowmodeNativeFixture', 'Date', 'console', 'ON',
    code + ';return { rootReady, open, scrollOwnedToTop, readVisibleKeyboardPanel, observation: () => new NativeUiObservation(0) };')(
    { getArguments: () => ({ bundleName: appBundle }), getAbilityDelegator: () => ({ getCurrentTopAbility: async () => ability }) },
    () => ({ moduleName: 'entry' }), fixture, { configurationReady: () => true }, { now: () => now },
    { info: line => {
      if (options.diagnosticLogFailure && /event=keyboard-window-(query-enter|query-return-|bundle-enter|bundle-return-)/.test(line)) throw new Error('diagnostic logger unavailable');
      logs.push(line);
    } }, { id: id => selector('id', id), text: value => selector('text', value) });
  return {
    run: async () => { await api.rootReady(driver); events.push('prepare-startup'); preparations++; await api.open(driver, 'stabilization-open-startup'); },
    ready: () => api.rootReady(driver), sharedReady: () => api.rootReady(driver, api.observation()),
    wrongSharedDepth: () => api.scrollOwnedToTop(driver, root, 40000, 1, 'chat-test-fixture-scroll', api.observation()),
    sharedNearlyExpired: () => { const ob = api.observation(); now = 9800; return api.rootReady(driver, ob); },
    captures: () => capturedOwners, rootLookups: () => rootLookups,
    readPanel: () => api.readVisibleKeyboardPanel(driver, api.observation()),
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
  ['owner changes immediately before gesture', { changeOwnerAtFocusRead: 3 }, /route\/session identity changed/, 0],
  ['foreign focus before gesture', { foreignFocus: true }, /foreign focused owner/, 0],
  ['foreign focus after gesture', { foreignAfterScroll: true }, /foreign focused owner/, 1],
  ['owner changes during final observation', { changeOwnerAtFocusRead: 5 }, /route\/session identity changed/, 1],
  ['single scroll outlives unchanged observation deadline', { scrollMs: 10001 }, /deadline exhausted/, 1],
  ['root fixture missing', { missingRoot: true }, /Actual owned Index root is absent/, 0],
  ['nonempty navigation stack', { depth: 1 }, /actual empty Index stack/, 0]
]) test(name + ' prevents startup preparation and click without replay', async () => {
  const f = create(options); await assert.rejects(f.run(), reason);
  assert.equal(f.preparations(), 0); assert.equal(f.clicks(), 0); assert.equal(f.topCalls(), topCalls);
});
test('slow sequential ownership RPCs and a 3s gesture retain final proof inside the original 10s', async () => {
  const f = create({ focusMs: 1000, scrollMs: 3000 });
  await assert.doesNotReject(f.ready());
  assert.equal(f.topCalls(), 1); assert(f.elapsed() < 10000);
});
test('case entry keeps one captured owner/deadline through the gesture and final proof', async () => {
  const f = create(); await f.ready(); assert.equal(f.captures(), 1);
  const ids = new Set(f.logs.map(line => /ownerTxn=(\d+)/.exec(line)?.[1]).filter(Boolean));
  assert.equal(ids.size, 1);
});
test('known IME decline refreshes the root target before the single gesture', async () => {
  const f = create({ imeAfterRootLookup: true }); await assert.doesNotReject(f.ready());
  assert.deepEqual(f.events, ['ime-cancel', 'ime-exit', 'scroll-top']);
  assert.equal(f.topCalls(), 1); assert.equal(f.rootLookups(), 2); assert.equal(f.captures(), 1);
});
test('missing refreshed root after IME decline fails without gesture', async () => {
  const f = create({ imeAfterRootLookup: true, missingRefreshedRoot: true });
  await assert.rejects(f.ready(), /Actual target absent after known IME decline/); assert.equal(f.topCalls(), 0);
});
test('owner changes while reacquiring the root after IME decline prevents gesture', async () => {
  const f = create({ imeAfterRootLookup: true, changeOwnerDuringRefresh: true });
  await assert.rejects(f.ready(), /route\/session identity changed/); assert.equal(f.topCalls(), 0);
});
test('foreign focused window during post-lookup proof prevents gesture', async () => {
  const f = create({ foreignAtFocusRead: 3 });
  await assert.rejects(f.ready(), /foreign focused owner/); assert.equal(f.topCalls(), 0);
});
test('gesture rejects mismatched shared depth before scrolling', async () => {
  const f = create(); await assert.rejects(f.wrongSharedDepth(), /transaction depth mismatch/); assert.equal(f.topCalls(), 0);
});
test('nearly expired shared Back observation is not restarted', async () => {
  const f = create(); await assert.rejects(f.sharedNearlyExpired(), /deadline exhausted/); assert.equal(f.topCalls(), 0);
});
test('foreign keyboard bundle remains hard rejected with exact package diagnostic and no gesture', async () => {
  const f = create({ panelBundle: 'foreign.keyboard' });
  await assert.rejects(f.readPanel(), /Keyboard window has foreign bundle/); assert.equal(f.topCalls(), 0);
  for (const event of ['keyboard-window-query-enter', 'keyboard-window-query-return-handle', 'keyboard-window-bundle-enter', 'keyboard-window-bundle-return-type=string-kind=value-value="foreign.keyboard"'])
    assert(f.logs.some(line => line.includes('event=' + event)), event);
});
test('diagnostic logger failure does not replace foreign-bundle rejection', async () => {
  const f = create({ panelBundle: 'foreign.keyboard', diagnosticLogFailure: true });
  await assert.rejects(f.readPanel(), /Keyboard window has foreign bundle/); assert.equal(f.topCalls(), 0);
});
test('allowed keyboard panel retains original nonfocused visible result', async () => {
  const f = create({ panelBundle: imeBundle }); assert.equal(await f.readPanel(), true);
});
test('native keyboard query error preserves the original error identity', async () => {
  const error = Object.assign(new Error('native query failed'), { code: 17000002 });
  const f = create({ panelBundle: imeBundle, panelQueryError: error });
  await assert.rejects(f.readPanel(), caught => caught === error);
});
test('native keyboard property error preserves the original error identity', async () => {
  const error = Object.assign(new Error('native property failed'), { code: 17000001 });
  const f = create({ panelBundle: imeBundle, panelPropertyError: error });
  await assert.rejects(f.readPanel(), caught => caught === error);
});
for (const [bundle, type, kind, value] of [['', 'string', 'empty', '""'], [null, 'object', 'null', 'null'], [undefined, 'undefined', 'undefined', 'undefined']])
  test('missing keyboard bundle classification remains explicit: ' + kind, async () => {
    const f = create({ panelBundle: bundle });
    if (bundle === '') {
      assert.equal(await f.readPanel(), undefined, 'empty owner is unknown, never false/Clear');
      assert(f.logs.some(line => line.includes('event=keyboard-empty-owner-sample-invalidated')));
      assert(!f.logs.some(line => line.includes('event=action-') || line.includes('phase=OWNED_CLEAR')));
      assert.deepEqual(f.events, []); assert.equal(f.preparations(), 0); assert.equal(f.clicks(), 0);
    } else await assert.rejects(f.readPanel(), /Keyboard window has foreign bundle/);
    assert(f.logs.some(line => line.includes('keyboard-window-bundle-return-type=' + type + '-kind=' + kind + '-value=' + value)));
    assert.equal(f.topCalls(), 0);
  });
const circularPanelBundle = { syntheticPrivateField: 'do-not-log-fixture-data' };
circularPanelBundle.self = circularPanelBundle;
for (const [bundle, type] of [[circularPanelBundle, 'object'], [42, 'number']])
  test('unsupported keyboard bundle remains hard rejected without diagnostic serialization: ' + type, async () => {
    const f = create({ panelBundle: bundle });
    await assert.rejects(f.readPanel(), /Keyboard window has foreign bundle/);
    assert(f.logs.some(line => line.includes('keyboard-window-bundle-return-type=' + type + '-kind=non-string-value=<non-string>')));
    assert(!f.logs.some(line => line.includes('do-not-log-fixture-data')));
    assert.equal(f.topCalls(), 0);
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
  if (option('--receipt')) fs.writeFileSync(path.resolve(option('--receipt')), JSON.stringify(receipt, null, 2) + '\n', { flag: 'wx' });
  process.exitCode = process.exitCode || (receipt.passed === receipt.total ? 0 : 1);
})().catch(error => { console.error(error); process.exitCode = 1; })
  .finally(() => { suiteComplete = true; clearTimeout(watchdog); });
