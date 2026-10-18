'use strict';
// Executes the native test helpers and fixture methods after stripping types.
// The UI boundary is modeled; these controls do not claim ArkUI validation.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const arg = process.argv.find(value => value.startsWith('--source-root='));
const root = arg ? path.resolve(arg.slice(14)) : path.resolve(__dirname, '..');
const section = (process.argv.find(value => value.startsWith('--section=')) || '--section=all').slice(10);
const mutant = (process.argv.find(value => value.startsWith('--mutant=')) || '--mutant=none').slice(9);
const paths = {
  timeline: 'entry/src/ohosTest/ets/test/TimelineUpdateNative.test.ets',
  fixture: 'entry/src/ohosTest/ets/testability/TimelineTransactionFixture.ets',
  photo: 'entry/src/ohosTest/ets/test/PhotoSelectionPreview.test.ets',
  viewport: 'entry/src/ohosTest/ets/testability/components/PhotoSelectionPreviewFixture.ets'
};
const sources = Object.fromEntries(Object.entries(paths).map(([key, value]) => [key, fs.readFileSync(path.join(root, value), 'utf8').replace(/\r\n/g, '\n')]));
const photoOverride = process.argv.find(value => value.startsWith('--photo-source='));
if (photoOverride) sources.photo = fs.readFileSync(path.resolve(photoOverride.slice(15)), 'utf8').replace(/\r\n/g, '\n');
function mutate(key, before, after) {
  assert.ok(sources[key].includes(before), 'negative mutation must engage: ' + mutant);
  sources[key] = sources[key].replace(before, after);
}
if (mutant === 'no-shared-guard') mutate('fixture', 'if (this.mounted && token === this.pageLifecycleToken) task();', 'task();');
if (mutant === 'no-token-guard') mutate('fixture', 'this.mounted && token === this.pageLifecycleToken', 'this.mounted');
if (mutant === 'no-mounted-guard') mutate('fixture', 'this.mounted && token === this.pageLifecycleToken', 'token === this.pageLifecycleToken');
if (mutant === 'no-dispose-barrier') mutate('timeline', 'await waitForDisappearance(old);', '// removed real disappearance barrier');
if (mutant === 'no-release') mutate('timeline', 'releaseOldApply();', '// dropped old callback');
if (mutant === 'no-generation-reset') mutate('timeline', 'prior.observationGeneration === current.observationGeneration', 'true');
if (mutant === 'swallow-native-errors') mutate('timeline', 'if ((error as BusinessError).code !== 17000004) throw error as Error;', '// swallowed unrelated native error');
if (mutant === 'one-stable-transition') mutate('timeline', 'if (stable >= 3)', 'if (stable >= 1)');
if (mutant === 'extend-deadline') mutate('timeline', 'const deadline = Date.now() + 5000;', 'const deadline = Date.now() + 50000;');
if (mutant === 'accept-late-measurement') mutate('timeline', "      if (Date.now() >= observation.deadline) throw new Error('Native timeline observation deadline');\n      const index", '      const index');
if (mutant === 'skip-x-clipping') mutate('photo', 'bounds.left >= viewport.left && bounds.right <= viewport.right &&', '');
if (mutant === 'skip-y-clipping') mutate('photo', 'bounds.top >= viewport.top && bounds.bottom <= viewport.bottom', 'true');
if (mutant === 'accept-empty-bounds') mutate('photo', 'bounds.right > bounds.left && bounds.bottom > bounds.top &&', '');
if (mutant === 'swallow-photo-errors') mutate('photo', 'if ((error as BusinessError).code !== 17000004) throw error as Error;', '// swallowed unrelated native error');
if (mutant === 'skip-enabled-check') mutate('photo', "expect(await photoRpc(id, 'Component.isEnabled', () => component.isEnabled())).assertTrue();", '// skipped disabled guard');
if (mutant === 'skip-footer-identity') mutate('photo', "if (footer !== undefined) expect(await photoRpc(fixtureId ?? text, 'Component.getText(footer)', () => footer.getText())).assertEqual(text);", '// accepted decoy label');
if (mutant === 'ignore-nested-strip') mutate('photo', 'if (nested) {', 'if (false) {');

if (mutant === 'no-photo-position') mutate('photo', '    PhotoSelectionPreviewFixture.positionInViewport(id, owner);', '    // omitted viewport positioning');
if (mutant === 'no-photo-owner') mutate('photo', '    PhotoSelectionPreviewFixture.assertViewportOwner(owner);', '    // omitted owner validation');
if (mutant === 'late-photo') mutate('photo', "    if (Date.now() >= deadline) throw new Error('Native photo viewport deadline: ' + id);", '    // omitted deadline validation');
if (mutant === 'photo-timeout') mutate('photo', 'const deadline = Date.now() + 5000;', 'const deadline = Date.now() + 50000;');
if (mutant === 'no-px-conversion') mutate('viewport', 'context.px2vp(deltaPx)', 'deltaPx');
if (mutant === 'wrong-scroll-direction') mutate('viewport', 'offset.yOffset + deltaVp', 'offset.yOffset - deltaVp');
if (mutant === 'animated-position') mutate('viewport', 'animation: false', 'animation: true');
if (mutant === 'no-viewport-owner') mutate('viewport', 'PhotoSelectionPreviewFixture.viewportContext === undefined || owner !== PhotoSelectionPreviewFixture.viewportGeneration', 'PhotoSelectionPreviewFixture.viewportContext === undefined || false');
if (mutant === 'wrong-unbind-owner') mutate('viewport', 'if (owner !== PhotoSelectionPreviewFixture.viewportGeneration) return;', '// wrong owner allowed');
if (mutant === 'wrong-target-scope') mutate('viewport', 'if (!/^photo-preview-fixture-', 'if (false && !/^photo-preview-fixture-');
if (mutant === 'skip-click-owner') mutate('photo', "  PhotoSelectionPreviewFixture.assertViewportOwner(owner);\n  await photoRpc(id, 'Component.click'", "  await photoRpc(id, 'Component.click'");
if (mutant === 'skip-footer-owner') {
  const begin = sources.photo.indexOf('async function requireText('), end = sources.photo.indexOf('async function decoded(', begin);
  const original = sources.photo.slice(begin, end);
  mutate('photo', original, original.replaceAll('  PhotoSelectionPreviewFixture.assertViewportOwner(owner);', ''));
}

const check = actual => ({ assertTrue: () => assert.equal(actual, true), assertFalse: () => assert.equal(actual, false), assertEqual: expected => assert.equal(actual, expected) });
const ON = { id: id => ({ id }), text: text => ({ text }) };
function transpile(source) { return stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/export default function /g, 'function ').replace(/^export /gm, ''), { mode: 'transform' }); }
function context(source, values, appended) {
  const ctx = vm.createContext({ console: { info() {} }, expect: check, ON, Math, ...values });
  vm.runInContext(transpile(source) + '\n' + appended, ctx);
  return ctx.exports;
}
function clock() {
  let now = 0, next = 1;
  const tasks = new Map();
  const timer = (callback, delay) => { const id = next++; tasks.set(id, { at: now + delay, callback }); return id; };
  const advance = time => {
    const end = now + time;
    for (;;) {
      const due = [...tasks.entries()].filter(([, task]) => task.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
      if (!due) break;
      now = due[1].at; tasks.delete(due[0]); due[1].callback();
    }
    now = end;
  };
  return { Date: { now: () => now }, now: () => now, advance, setTimeout: timer, clearTimeout: id => tasks.delete(id) };
}
const results = [];
async function test(name, run) { await run(); results.push(name); }

function timelineModel(options = {}) {
  const time = clock();
  const fixture = {
    mounted: true, indexOf: () => 26, dataSource: { totalCount: () => 81 },
    listScroller: { getItemRect: () => ({ x: 0, y: 0, width: 80, height: 20 }) },
    olderCalls: 0, newerCalls: 0, events: []
  };
  const owner = { current: fixture };
  const counts = { waits: 0, assertions: 0, rowBounds: 0, listBounds: 0, delay: 0 };
  const rpc = () => time.advance(options.cost ?? 300);
  const row = { getBounds: async () => {
    rpc(); counts.rowBounds++;
    if (options.ownerChange) owner.current = {};
    if (options.error && counts.rowBounds === 2) throw Object.assign(new Error('native error'), { code: options.error });
    if (options.persistentStale || (options.staleAt && counts.rowBounds === options.staleAt)) throw Object.assign(new Error('stale handle'), { code: 17000004 });
    const top = options.moving ? 250 + counts.rowBounds * 4 : 262;
    return { left: 10, right: 90, top, bottom: top + 20 };
  } };
  const list = { getBounds: async () => { rpc(); counts.listBounds++; return { left: 0, right: 100, top: 200, bottom: 500 }; } };
  const driver = {
    waitForComponent: async selector => { rpc(); counts.waits++; return selector.id === 'timeline-update-list' ? list : row; },
    assertComponentExist: async () => { rpc(); counts.assertions++; },
    delayMs: async ms => { counts.delay++; time.advance(ms); }
  };
  const prefix = sources.timeline.slice(0, sources.timeline.indexOf('export default function'));
  const api = context(prefix, { TimelineUpdateFixture: owner, Date: time.Date, setTimeout: time.setTimeout, clearTimeout: time.clearTimeout,
    hilog: { info() {} }, systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: time.now }, timelineTimingNow: time.now }, 'globalThis.exports = { settled };');
  return { ...time, api, driver, fixture, counts, run: phase => api.settled(driver, fixture, 260, phase || 'host-phase') };
}

async function timelineTests() {
  await test('same 5s / 3 comparisons settle under 300ms serial RPC latency', async () => {
    const f = timelineModel(); await f.run();
    assert.equal(f.counts.rowBounds, 4); assert.equal(f.counts.listBounds, 4);
    assert.equal(f.counts.waits, 2); assert.equal(f.counts.assertions, 2); assert.equal(f.now(), 3900);
  });
  await test('handles are reacquired for each settled phase', async () => {
    const f = timelineModel({ cost: 100 }); await f.run('first'); await f.run('second');
    assert.equal(f.counts.waits, 4); assert.equal(f.counts.rowBounds, 8);
  });
  await test('every sample reads fresh geometry; moving rows cannot settle', async () => {
    const f = timelineModel({ moving: true }); await assert.rejects(f.run(), /deadline|did not settle/);
    assert.ok(f.counts.rowBounds >= 4); assert.ok(f.now() < 6500);
  });
  await test('fourth coherent sample finishing after 5s is not accepted', async () => {
    const f = timelineModel({ cost: 400 }); await assert.rejects(f.run(), /deadline|did not settle/);
    assert.equal(f.now(), 5100);
  });
  await test('17000004 reacquires and resets consecutive comparisons', async () => {
    const f = timelineModel({ cost: 100, staleAt: 3 }); await f.run();
    assert.equal(f.counts.waits, 4); assert.equal(f.counts.rowBounds, 7); assert.equal(f.counts.listBounds, 6);
  });
  await test('persistent stale handles cannot renew the 5s invocation deadline', async () => {
    const f = timelineModel({ persistentStale: true }); await assert.rejects(f.run(), /deadline|did not settle/);
    assert.ok(f.now() <= 6000, 'same 5s plus at most one original serial RPC');
  });
  await test('unrelated UiTest failures propagate without handle reacquisition', async () => {
    const f = timelineModel({ error: 17000002 }); await assert.rejects(f.run(), { code: 17000002 }); assert.equal(f.counts.waits, 2);
  });
  await test('fixture identity changes fail before accepting geometry', async () => {
    const f = timelineModel({ ownerChange: true }); await assert.rejects(f.run(), /owner changed/);
  });
}

function fixtureFactory(time) {
  class DataSource { constructor() { this.count = 81; } registerDataChangeListener() {} totalCount() { return this.count; } }
  const api = context(sources.fixture, {
    ChatTimelineDataSource: DataSource, TimelineUpdateRecorder: class {}, createInitialAppState: () => ({ chats: { chats: new Map() } }),
    Chat: class {}, Scroller: class {}, PendingMediaOpenIntent: class {},
    TgChatTopBarSubtitleMode: { Secondary: 0 }, TgChatTopBarTrailingAction: { Search: 0 },
    Date: time.Date, setTimeout: time.setTimeout, clearTimeout: time.clearTimeout,
    systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: time.now },
    handleTimelineScrollIndex: fixture => fixture.olderCalls++
  }, 'globalThis.exports = { TimelineTransactionFixture };');
  return () => {
    const fixture = new api.TimelineTransactionFixture(); fixture.mounted = true;
    // Projection is outside this lifecycle test; observable mutation boundary is explicit.
    fixture.apply = ids => { fixture.dataSource.count = ids.length + 1; };
    return fixture;
  };
}

async function lifecycleTests() {
  await test('actual native remount case waits for real disposal after Back returns', async () => {
    const time = clock(), make = fixtureFactory(time), old = make(), current = make();
    const cases = [], events = []; let opened = 0;
    const driver = { pressBack: async () => {
      events.push('Back');
      if (opened === 1) {
        time.advance(1700);
        // Real navigation can return before disappearance: no fake mounted flag.
        setImmediate(() => { events.push('dispose'); old.dispose(); });
      } else current.dispose();
    }, delayMs: async ms => time.advance(ms) };
    let code = sources.timeline;
    const start = code.indexOf('async function openTimeline('), end = code.indexOf('\n// No scrollSearch', start);
    assert.ok(start >= 0 && end > start);
    code = code.slice(0, start) + 'async function openTimeline(driver: Driver): Promise<TimelineTransactionFixture> { return hostOpen(); }\n' + code.slice(end);
    context(code, { Driver: { create: () => driver }, describe: (_name, run) => run(), it: (name, _flags, run) => cases.push({ name, run }),
      Date: time.Date, setTimeout, clearTimeout, TimelineUpdateFixture: { current },
      hostOpen: () => { opened++; events.push('open' + opened); if (opened === 2) assert.equal(old.mounted, false, 'actual disappearance must precede new mount'); return opened === 1 ? old : current; }
    }, 'timelineUpdateNativeTest(); globalThis.exports = {};');
    await cases.find(entry => entry.name.includes('remount rejects')).run();
    assert.deepEqual(events.slice(0, 4), ['open1', 'Back', 'dispose', 'open2']);
    assert.equal(old.queuedApplyDeliveries, 1); assert.equal(old.dataSource.totalCount(), 81);
  });
  await test('same captured lifecycle guard protects timer and explicitly released task', async () => {
    const time = clock(), make = fixtureFactory(time), f = make();
    f.queueApply([10, 20], 10); time.advance(10); assert.equal(f.dataSource.totalCount(), 3);
    f.dataSource.count = 81; const held = f.captureQueuedApply([10, 20]); f.dispose(); held();
    assert.equal(f.dataSource.totalCount(), 81); assert.equal(f.queuedApplyDeliveries, 1);
  });
  await test('captured token rejects ABA mounted state and not-mounted same-token', async () => {
    const time = clock(), make = fixtureFactory(time), f = make();
    let calls = 0;
    const first = f.captureLifecycleTask(() => calls++); f.pageLifecycleToken++; first(); assert.equal(calls, 0);
    const second = f.captureLifecycleTask(() => calls++); f.mounted = false; second(); assert.equal(calls, 0);
  });
  await test('missing disposal rejects at bounded latch deadline without manufacturing disposal', async () => {
    const time = clock(), make = fixtureFactory(time), f = make();
    const prefix = sources.timeline.slice(0, sources.timeline.indexOf('export default function'));
    const api = context(prefix, { Date: time.Date, setTimeout: time.setTimeout, clearTimeout: time.clearTimeout },
      'globalThis.exports = { waitForDisappearance };');
    const pending = api.waitForDisappearance(f); let finished = false;
    pending.then(() => { finished = true; }, () => { finished = true; });
    time.advance(4999); await Promise.resolve(); assert.equal(finished, false);
    time.advance(1); await assert.rejects(pending, /disappearance timeout/);
    assert.equal(f.mounted, true); assert.equal(f.pageLifecycleToken, 1);
  });
}

function photoModel(options = {}) {
  const time = clock(), events = [], timing = [];
  const id = options.id || 'photo-preview-fixture-busy-state', text = 'preview busy:false';
  let generation = 1, positioned = false, reads = 0, rootReads = 0;
  const rpc = name => { events.push(name); time.advance(options.slowAt === name ? 5100 : 50); if (options.ownerAt === name) generation++; };
  const row = { getBounds: async () => {
    rpc('rowBounds'); reads++;
    if (options.error || (options.staleOnce && reads === 1)) throw options.errorObject || Object.assign(new Error('native error'), { code: options.error || 17000004 });
    return options.bounds || { left: 10, right: 90, top: 10, bottom: 30 };
  }, getText: async () => { rpc('footerText'); return options.wrongFooter ? 'stale footer' : text; },
  isEnabled: async () => { rpc('enabled'); return !options.disabled; }, click: async () => rpc('click') };
  const root = { getBounds: async () => { rpc('rootBounds'); rootReads++;
      if (options.staleRoot && rootReads === 1) throw Object.assign(new Error('stale root'), { code: 17000004 });
      return options.viewport || { left: 0, right: 100, top: 0, bottom: 100 }; },
    scrollSearch: async () => { events.push('search'); throw new Error('unbounded vertical search must not be entered'); } };
  const strip = { getBounds: async () => { rpc('stripBounds'); return options.strip || { left: 5, right: 95, top: 5, bottom: 35 }; } };
  const driver = {
    waitForComponent: async (selector, timeout) => { assert.ok(timeout > 0 && timeout <= 5000); rpc(selector.id ? 'rootWait' : 'textWait'); return selector.id ? root : row; },
    findComponent: async selector => {
      if (selector.id === 'photo-preview-fixture-strip' && selector.id !== id) { rpc('findStrip'); return options.missingStrip ? undefined : strip; }
      assert.equal(selector.id, id); rpc('find'); return options.missing || (options.offscreen && !positioned) ? undefined : row;
    },
    assertComponentExist: async selector => { assert.equal(selector.id || selector.text, selector.id ? id : text); rpc(selector.id ? 'assert' : 'textAssert'); }
  };
  const prefix = sources.photo.slice(0, sources.photo.indexOf('export default function'));
  const api = context(prefix, { Date: time.Date, systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: time.now },
    console: { info: value => { if (options.loggerError) throw new Error('logger failed'); if (value.startsWith('[PhotoSelectionPreview] RPC ')) timing.push(JSON.parse(value.slice('[PhotoSelectionPreview] RPC '.length))); } },
    PhotoSelectionPreviewFixture: { session: { isSendingMessage: () => false }, view: { composer: { isSending: false } },
      viewportOwner: () => generation, assertViewportOwner: owner => { if (owner !== generation) throw new Error('Photo fixture viewport owner changed'); },
      positionInViewport: (target, owner) => { assert.equal(target, id); assert.equal(owner, generation); events.push('position'); positioned = true; }
    }
  }, 'globalThis.exports = { visible, click, requireText };');
  return { api, driver, events, timing, id, text, time };
}

async function photoTests() {
  await test('offscreen target is positioned without entering global scrollSearch', async () => {
    const f = photoModel({ offscreen: true }); await f.api.visible(f.driver, f.id);
    assert.deepEqual(f.events, ['position', 'rootWait', 'find', 'rowBounds', 'rootBounds', 'assert']);
  });
  await test('exact visible target still verifies native bounds and identity', async () => {
    const f = photoModel(); await f.api.visible(f.driver, f.id); assert.equal(f.events.at(-1), 'assert'); assert.ok(f.events.includes('rowBounds'));
  });
  await test('nested strip child must satisfy both native clipping rectangles', async () => {
    for (const id of ['photo-preview-fixture-thumb-1', 'photo-preview-fixture-ordinal-1']) {
      const f = photoModel({ id }); await f.api.visible(f.driver, id); assert.ok(f.events.includes('stripBounds'));
    }
  });
  for (const [name, options] of [
    ['left clipping', { bounds: { left: -1, right: 90, top: 10, bottom: 30 } }],
    ['right clipping', { bounds: { left: 10, right: 101, top: 10, bottom: 30 } }],
    ['top clipping', { bounds: { left: 10, right: 90, top: -1, bottom: 30 } }],
    ['bottom clipping', { bounds: { left: 10, right: 90, top: 10, bottom: 101 } }],
    ['empty rectangle', { bounds: { left: 10, right: 10, top: 10, bottom: 30 } }],
    ['empty viewport', { viewport: { left: 0, right: 0, top: 0, bottom: 100 }, bounds: { left: 0, right: 0, top: 10, bottom: 30 } }],
    ['missing', { missing: true }], ['persistent stale', { error: 17000004 }],
    ['nested x clipping', { id: 'photo-preview-fixture-thumb-1', strip: { left: 20, right: 95, top: 0, bottom: 100 } }],
    ['nested y clipping', { id: 'photo-preview-fixture-ordinal-1', strip: { left: 0, right: 100, top: 20, bottom: 100 } }],
    ['missing strip', { id: 'photo-preview-fixture-thumb-1', missingStrip: true }]
  ]) await test('one 5s deadline rejects ' + name, async () => {
    const f = photoModel(options); await assert.rejects(f.api.visible(f.driver, f.id), /viewport deadline/);
    assert.equal(f.time.now(), 5000); assert.equal(f.events.includes('assert'), false); assert.equal(f.events.includes('search'), false);
  });
  for (const [name, options] of [['candidate rekey', { staleOnce: true }], ['root rekey', { staleRoot: true }]]) {
    await test(name + ' reacquires under same deadline', async () => { const f = photoModel(options); await f.api.visible(f.driver, f.id); assert.equal(f.events.filter(x => x === 'rootWait').length, 2); assert.ok(f.time.now() < 5000); });
  }
  await test('unrelated photo error preserves object identity and is not retried', async () => {
    const error = Object.assign(new Error('concurrent native call'), { code: 17000002 });
    const f = photoModel({ error: 17000002, errorObject: error }); await assert.rejects(f.api.visible(f.driver, f.id), value => value === error);
    assert.equal(f.events.filter(x => x === 'rootWait').length, 1);
  });
  await test('completed RPC beyond 5s cannot be accepted', async () => {
    const f = photoModel({ slowAt: 'assert' }); await assert.rejects(f.api.visible(f.driver, f.id), /viewport deadline/);
  });
  await test('owner change during native lookup aborts before next RPC', async () => {
    const f = photoModel({ ownerAt: 'find' }); await assert.rejects(f.api.visible(f.driver, f.id), /owner changed/);
    assert.equal(f.events.at(-1), 'find'); assert.equal(f.events.filter(x => x === 'position').length, 1);
  });
  await test('disabled fixture is never clicked', async () => { const f = photoModel({ disabled: true }); await assert.rejects(f.api.click(f.driver, f.id)); assert.equal(f.events.includes('click'), false); });
  await test('owner change during enabled check prevents click', async () => {
    const f = photoModel({ ownerAt: 'enabled' }); await assert.rejects(f.api.click(f.driver, f.id), /owner changed/); assert.equal(f.events.includes('click'), false);
  });
  await test('owner change during issued click rejects without retrying', async () => {
    const f = photoModel({ ownerAt: 'click' }); await assert.rejects(f.api.click(f.driver, f.id), /owner changed/); assert.equal(f.events.filter(x => x === 'click').length, 1);
  });
  await test('matching text decoy cannot replace exact footer value', async () => { const f = photoModel({ wrongFooter: true }); await assert.rejects(f.api.requireText(f.driver, f.text, f.id)); });
  for (const operation of ['textWait', 'textAssert', 'footerText']) await test('footer owner changes at ' + operation + ' reject old/new mixing', async () => {
    const f = photoModel({ ownerAt: operation }); await assert.rejects(f.api.requireText(f.driver, f.text, f.id), /owner changed/); assert.equal(f.events.at(-1), operation);
  });
  await test('RPC markers pair exact sequential operations including errors', async () => {
    const f = photoModel({ error: 17000002 }); await assert.rejects(f.api.visible(f.driver, f.id));
    for (let index = 0; index < f.timing.length; index += 2) {
      const enter = f.timing[index], exit = f.timing[index + 1]; assert.equal(enter.id, f.id); assert.equal(enter.event, 'enter');
      assert.equal(exit.sequence, enter.sequence); assert.equal(exit.operation, enter.operation); assert.ok(exit.mono >= enter.mono);
      assert.equal(exit.event, index + 2 === f.timing.length ? 'throw' : 'return');
    }
  });
  await test('diagnostic logger failure cannot replace successful UI result', async () => { const f = photoModel({ loggerError: true }); await f.api.visible(f.driver, f.id); });
}

function viewportModel(options = {}) {
  const calls = [], reads = [];
  const viewport = { windowOffset: { x: 0, y: 100 }, size: { width: 600, height: 400 } };
  const target = { windowOffset: { x: 20, y: options.top ?? 600 }, size: { width: options.width ?? 100, height: options.height ?? 40 } };
  let offset = options.offset ?? 100;
  class Scroller {
    currentOffset() { return options.unbound ? undefined : { xOffset: 0, yOffset: offset }; }
    scrollTo(value) { calls.push(value); target.windowOffset.y -= (value.yOffset - offset) * 2; offset = value.yOffset; }
  }
  const contextValue = { px2vp: px => options.invalidConversion ? NaN : px / 2,
    getComponentUtils: () => ({ getRectangleById: id => { reads.push(id); return id === 'chat-test-fixture-scroll' ? viewport : target; } }) };
  const start = sources.viewport.indexOf('  // Test-only root viewport.'), end = sources.viewport.indexOf('  private static mountedContext()', start);
  assert.ok(start > 0 && end > start, 'extract actual fixture viewport methods');
  const code = 'class PhotoSelectionPreviewFixture {\n' + sources.viewport.slice(start, end) + '\n}';
  const api = context(code, { Scroller }, 'globalThis.exports = PhotoSelectionPreviewFixture;');
  const owner = api.bindViewport(contextValue);
  return { api, owner, calls, reads, viewport, target, contextValue, position: id => api.positionInViewport(id || 'photo-preview-fixture-image', owner) };
}

async function viewportTests() {
  await test('actual fixture converts below-viewport px delta to vp from nonzero offset', async () => {
    const f = viewportModel(); f.position(); assert.equal(f.calls.length, 1); assert.equal(f.calls[0].yOffset, 170); assert.equal(f.calls[0].xOffset, 0); assert.equal(f.calls[0].animation, false);
    f.position(); assert.equal(f.calls.length, 1, 'once placed no second scroll');
  });
  await test('actual fixture moves upward by converted relative delta', async () => { const f = viewportModel({ top: 50 }); f.position(); assert.equal(f.calls[0].yOffset, 75); });
  await test('visible fixture does not change scroll position', async () => { const f = viewportModel({ top: 200 }); f.position(); assert.equal(f.calls.length, 0); });
  await test('nested target positions its actual strip, not a horizontally clipped child', async () => { const f = viewportModel(); f.position('photo-preview-fixture-thumb-1'); assert.deepEqual(f.reads, ['chat-test-fixture-scroll', 'photo-preview-fixture-strip']); });
  await test('same-context remount fences old token and late old unbind', async () => {
    const f = viewportModel(); const current = f.api.bindViewport(f.contextValue); assert.notEqual(current, f.owner);
    f.api.unbindViewport(f.owner); assert.equal(f.api.viewportOwner(), current); assert.throws(() => f.position(), /owner changed/);
    f.api.positionInViewport('photo-preview-fixture-image', current); assert.equal(f.calls.length, 1);
    f.api.unbindViewport(current); assert.throws(() => f.api.viewportOwner(), /not mounted/);
  });
  await test('unrelated target ID cannot reposition root fixture', async () => { const f = viewportModel(); assert.throws(() => f.position('other-fixture-button'), /Unexpected/); assert.equal(f.calls.length, 0); });
  for (const [name, options, expected] of [['nonfinite layout', { top: NaN }, /coordinates/], ['oversized', { height: 401 }, /cannot fit/], ['horizontal clipping', { width: 601 }, /cannot fit/], ['unbound Scroller', { unbound: true }, /Scroller is not bound/], ['invalid conversion', { invalidConversion: true }, /scroll offset/]]) {
    await test('actual fixture rejects ' + name + ' before scrolling', async () => { const f = viewportModel(options); assert.throws(() => f.position(), expected); assert.equal(f.calls.length, 0); });
  }
  await test('zero unlaid-out geometry cannot initiate a fabricated scroll', async () => { const f = viewportModel({ height: 0 }); f.position(); assert.equal(f.calls.length, 0); });
}


const deadline = setTimeout(() => { console.error('HARNESS_ERROR async suite exceeded 3 seconds'); process.exit(2); }, 3000);
require('./host-test-completion.cjs').guardSuite((async () => {
  if (section === 'all' || section === 'timeline') await timelineTests();
  if (section === 'all' || section === 'lifecycle') await lifecycleTests();
  if (section === 'all' || section === 'photo') await photoTests();
  if (section === 'all' || section === 'viewport') await viewportTests();
  assert.ok(results.length > 0, 'nonempty selected section');
  console.log(JSON.stringify({ passed: true, root, section, mutant, cases: results.length, results }));
})()).catch(error => { console.error(error); process.exitCode = 1; }).finally(() => clearTimeout(deadline));
