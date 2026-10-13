#!/usr/bin/env node
// Node >=24. Execute complete production helper/page methods, not copied logic.
// SDK Window and timers are explicit in-memory boundaries: no build, device or account.
// --mutant=global-off|search-dispose|search-generation are in-memory negative controls.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
// Slow-mode imports execute real production code; only the SDK uptime service is a fixture.
const slowmodeFixtureDeps = (() => {
  const etsRoot = path.resolve(__dirname, '../entry/src/main/ets');
  function module(file, deps = {}) {
    const source = fs.readFileSync(path.join(etsRoot, file), 'utf8');
    const names = [...source.matchAll(/^export\s+(?:class|function)\s+(\w+)/gm)].map(match => match[1]);
    const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
    return new Function(...Object.keys(deps), js + `; return {${names.join(',')}};`)(...Object.values(deps));
  }
  const clock = module('core/utils/SlowmodeClock.ets', { systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => 0 } });
  return { ...clock, ...module('ui/pages/chat/ChatSlowmodeController.ets', {
    ...clock, navigationUIState: { applicationForeground: true }
  }) };
})();
Object.assign(globalThis, slowmodeFixtureDeps);

const pages = ['chat/TgChatScreenPage', 'chatlist/ChatListPage', 'chatlist/TgArchivedChatsPage',
  'contacts/ContactsPage', 'calls/CallsPage', 'settings/SettingsPage'];
const mutant = process.argv.find(a => a.startsWith('--mutant='))?.slice(9);
assert.ok(!mutant || ['global-off', 'search-dispose', 'search-generation'].includes(mutant));
const hashes = {};
let mutationSites = 0;
function read(file) {
  const source = readChatSource(path.join(root, file), 'utf8').replaceAll('\r\n', '\n');
  hashes[file] = createHash('sha256').update(source).digest('hex');
  return source;
}
function replaceOnce(source, from, to) {
  assert.equal(source.split(from).length - 1, 1, `mutation must engage: ${from}`);
  mutationSites++;
  return source.replace(from, to);
}
function method(source, name) {
  const matches = [...source.matchAll(new RegExp(
    `^  (?:(?:private|public|protected|async)\\s+)*${name}\\(`, 'gm'))];
  assert.equal(matches.length, 1, `one full method: ${name}`);
  const start = matches[0].index;
  const end = source.indexOf('\n  }', start);
  assert.ok(end > start);
  return source.slice(start, end + 4);
}
let helperSource = read('ui/utils/SafeAreaUtils.ets');
if (mutant === 'global-off') {
  helperSource = replaceOnce(helperSource, "off('windowSizeChange', sizeListener)", "off('windowSizeChange')");
  helperSource = replaceOnce(helperSource, "off('avoidAreaChange', avoidAreaListener)", "off('avoidAreaChange')");
}
const exportNames = [...helperSource.matchAll(/^export (?:function|class|const) (\w+)/gm)].map(m => m[1]);
const helperJs = stripTypeScriptTypes(helperSource.replace(/^import[\s\S]*?;\s*/gm, '')
  .replace(/^export /gm, ''), { mode: 'transform' });
const helpers = new Function(helperJs + `\nreturn {${exportNames.join(',')}};`)();
const pageMethods = pages.map((name, index) => {
  const source = read(`ui/pages/${name}.ets`);
  const names = ['bindWindowSizeListener', 'aboutToDisappear'];
  if (index === 0) names.push('flashSearchHit', 'clearSearchFlash');
  return names.map(n => {
    let code = method(source, n);
    if (index === 0 && mutant === 'search-dispose' && n === 'aboutToDisappear') {
      code = replaceOnce(code, 'this.clearSearchFlash();', '// Mutant: missing teardown.');
    }
    if (index === 0 && mutant === 'search-generation' && n === 'flashSearchHit') {
      code = replaceOnce(code, 'lifecycleToken !== this.pageLifecycleToken || this.searchFlashTimerId !== timerId', 'false');
    }
    return code;
  }).join('\n');
});
assert.equal(mutationSites, mutant === 'global-off' ? 2 : mutant ? 1 : 0,
  'negative controls must modify the expected production sites');
// The SDK contract: missing callback means remove ALL; identity means only that callback.
class FakeWindow {
  listeners = { windowSizeChange: new Set(), avoidAreaChange: new Set() };
  offCalls = [];
  failOn;
  failOff = new Set();
  on(event, callback) {
    const fail = this.failOn?.event === event ? this.failOn : undefined;
    if (fail) this.failOn = undefined;
    if (fail?.phase === 'before') throw Error('on before registration');
    this.listeners[event].add(callback);
    if (fail?.phase === 'after') throw Error('on after registration');
  }
  off(event, callback) {
    this.offCalls.push({ event, callback });
    if (this.failOff.has(event)) throw Error('off failed');
    if (callback === undefined) this.listeners[event].clear();
    else this.listeners[event].delete(callback);
  }
  getWindowProperties() { return { windowRect: { width: 720 } }; }
  emit() {
    for (const cb of this.listeners.windowSizeChange) cb({ width: 800, height: 600 });
    for (const cb of this.listeners.avoidAreaChange) cb({ type: 1, area: { bottomRect: { height: 20 } } });
  }
  queued() { return [...this.listeners.windowSizeChange].map(cb => () => cb({ width: 800 }))
    .concat([...this.listeners.avoidAreaChange].map(cb => () => cb({ type: 1 }))); }
}
function foreignOwner(win) {
  const owner = { size: 0, avoid: 0 };
  win.on('windowSizeChange', owner.onSize = () => owner.size++);
  win.on('avoidAreaChange', owner.onAvoid = () => owner.avoid++);
  return owner;
}
function onlyForeign(win, owner) {
  assert.deepEqual([...win.listeners.windowSizeChange], [owner.onSize], 'only B size callback remains');
  assert.deepEqual([...win.listeners.avoidAreaChange], [owner.onAvoid], 'only B avoid callback remains');
  assert.ok(win.offCalls.every(c => typeof c.callback === 'function'), 'every off is callback-specific');
  const before = owner.size + owner.avoid;
  win.emit();
  assert.equal(owner.size + owner.avoid, before + 2, 'B still receives both events');
}
function fixture(index = 0, win = new FakeWindow()) {
  let nextTimerId = 0;
  const pending = new Map();
  const callbacks = new Map();
  const delays = new Map();
  const f = { win, pending, callbacks, delays, updates: 0, notifications: [], entries: [] };
  const deps = { ...helpers, window: { AvoidAreaType: { TYPE_SYSTEM: 1, TYPE_KEYBOARD: 2 } },
    TgUiTokens: { MSG_DEMO_BASE_CONTAINER_WIDTH: 360 }, hilog: { info() {} }, DOMAIN: 0, TAG: 'fixture',
    setTimeout(callback, delay) {
      const id = ++nextTimerId;
      pending.set(id, callback); callbacks.set(id, callback); delays.set(id, delay); return id;
    },
    clearTimeout(id) { pending.delete(id); }
  };
  const js = stripTypeScriptTypes(`class Page {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${pageMethods[index]}\n}`, { mode: 'transform' });
  const Page = index === 0 && process.argv.includes('--actual-delegates') ? require('./chat-screen-source.cjs').compileExports(
    require('./chat-screen-source.cjs').sourceGraph(path.join(root, 'ui/pages/chat/TgChatScreenPage.ets')), deps, undefined,
    mutant === 'search-dispose' ? { aboutToDisappear: method(pageMethods[0], 'aboutToDisappear') } :
      mutant === 'search-generation' ? { flashSearchHit: method(pageMethods[0], 'flashSearchHit') } : {}).Session :
    new Function(...Object.keys(deps), js + '\nreturn Page;')(...Object.values(deps));
  // Unrelated UI, stores, navigation and media are explicit stubs. Relevant methods above stay real.
  const stubs = ['closeMessageActions', 'resetBotMenuState', 'resetEmojiSearchState', 'resetStickerSearchState',
    'resetGifSearchState', 'resetPinnedMessageState', 'saveScrollPosition', 'clearOwnedChatContext',
    'clearTransientTimers', 'setSendingMessage', 'clearPendingMediaDownloads', 'resetPaginationState',
    'teardownMediaPlaybackController', 'clearRebuildTimer', 'clearDeferredOpen', 'clearLoadMoreTimer'];
  f.page = Object.assign(new Page(), Object.fromEntries(stubs.map(n => [n, () => {}])), {
    slowmodeController: new slowmodeFixtureDeps.ChatSlowmodeController(), composerSlowmodeSeconds: 0,
    pageLifecycleToken: 1, pinnedMessageRequestId: 0, routeActivated: false,
    draftDebounceTimerId: -1, historyFallbackTimerId: -1, rebuildTimerId: -1, paginationRecheckTimerId: -1,
    searchFlashTimerId: -1, searchFlashMessageId: '', loadedRecords: [], isLoading: false,
    voiceRecordingCtrl: { dispose() {} }, searchCtrl: { clearPendingTimer() {} },
    mediaDownloadCtrl: { setChangeListener() {} }, replyHydrationCoordinator: { reset() {} },
    ownsNavigationContext: () => false,
    getUIContext: () => ({ getHostContext: () => ({ windowStage: { getMainWindowSync: () => f.win } }) }),
    computeSafeInsets: () => f.updates++, updateTimelineContainerWidth: () => f.updates++,
    onKeyboardVisibilityChange: () => f.updates++,
    dataSource: { getData: i => f.entries[i], totalCount: () => f.entries.length,
      notifyItemChangedByMessageId: id => f.notifications.push(id) }
  });
  f.add = id => f.entries.push({ kind: 'message', message: { messageId: id }, key: id, searchFlash: false });
  f.fire = id => { pending.delete(id); callbacks.get(id)(); };
  return f;
}
const results = [];
function test(name, run) {
  try { run(); results.push({ name, passed: true }); }
  catch (error) { results.push({ name, passed: false, error: error.stack }); }
}
test('SDK control: callback-specific A off preserves B; callback-less off removes B', () => {
  const w = new FakeWindow(), a = foreignOwner(w), b = foreignOwner(w);
  w.off('windowSizeChange', a.onSize); w.off('avoidAreaChange', a.onAvoid);
  onlyForeign(w, b);
  w.off('windowSizeChange'); w.off('avoidAreaChange');
  assert.equal(w.listeners.windowSizeChange.size + w.listeners.avoidAreaChange.size, 0);
});
pages.forEach((name, index) => {
  test(`${name}: A teardown and repeated teardown preserve actual page B`, () => {
    const w = new FakeWindow(), a = fixture(index, w), b = fixture(index, w);
    a.page.bindWindowSizeListener(); b.page.bindWindowSizeListener();
    const dispose = a.page.windowSizeListener;
    const before = b.updates; w.emit(); assert.ok(b.updates > before, 'B active before teardown');
    a.page.aboutToDisappear(); a.page.aboutToDisappear();
    const next = b.updates; w.emit(); assert.ok(b.updates > next, 'B active after A teardown');
    assert.equal(typeof dispose, 'function', 'page retains its owned disposer');
    const offCount = w.offCalls.length; dispose(); dispose();
    assert.equal(w.offCalls.length, offCount, 'saved disposer is itself idempotent');
    b.page.aboutToDisappear();
    assert.equal(w.listeners.windowSizeChange.size + w.listeners.avoidAreaChange.size, 0);
    assert.ok(w.offCalls.every(c => typeof c.callback === 'function'));
  });
  test(`${name}: same-window rebind owns new callbacks; old queued callbacks inert`, () => {
    const f = fixture(index), w = f.win;
    f.page.bindWindowSizeListener(); const old = w.queued();
    const b = foreignOwner(w); f.page.bindWindowSizeListener();
    assert.equal(w.listeners.windowSizeChange.size, 2);
    assert.equal(w.listeners.avoidAreaChange.size, index < 2 ? 2 : 1);
    const before = f.updates; old.forEach(cb => cb()); assert.equal(f.updates, before);
    w.emit(); assert.ok(f.updates > before, 'new callback engaged');
    f.page.aboutToDisappear(); onlyForeign(w, b);
  });
  test(`${name}: rebind to another window releases only old owned callbacks`, () => {
    const f = fixture(index), old = f.win, b = foreignOwner(old);
    f.page.bindWindowSizeListener(); f.win = new FakeWindow();
    f.page.bindWindowSizeListener(); onlyForeign(old, b);
    const before = f.updates; f.win.emit(); assert.ok(f.updates > before);
    f.page.aboutToDisappear(); assert.equal(f.win.listeners.windowSizeChange.size, 0);
  });
  test(`${name}: missing window releases old owned callbacks without harming B`, () => {
    const f = fixture(index), w = f.win, b = foreignOwner(w);
    f.page.bindWindowSizeListener(); f.win = undefined; f.page.bindWindowSizeListener();
    onlyForeign(w, b); f.page.aboutToDisappear(); onlyForeign(w, b);
  });
  for (const event of index < 2 ? ['windowSizeChange', 'avoidAreaChange'] : ['windowSizeChange']) {
    for (const phase of ['before', 'after']) {
      test(`${name}: partial bind rollback, ${event} throws ${phase} registration`, () => {
        const f = fixture(index), w = f.win, b = foreignOwner(w);
        w.failOn = { event, phase }; f.page.bindWindowSizeListener();
        onlyForeign(w, b); f.page.aboutToDisappear(); onlyForeign(w, b);
        f.page.bindWindowSizeListener(); const before = f.updates;
        w.emit(); assert.ok(f.updates > before, 'recovery bind actually engaged');
      });
    }
  }
});
for (const index of [0, 1]) {
  test(`${pages[index]}: off failure still fences late callbacks and attempts both cleanups`, () => {
    const f = fixture(index), w = f.win;
    f.page.bindWindowSizeListener(); const old = w.queued(), b = foreignOwner(w);
    w.failOff.add('windowSizeChange'); f.page.bindWindowSizeListener();
    const before = f.updates; old.forEach(cb => cb()); assert.equal(f.updates, before);
    assert.ok(w.offCalls.some(c => c.event === 'avoidAreaChange'));
    assert.ok(w.listeners.avoidAreaChange.has(b.onAvoid));
    assert.ok(w.offCalls.every(c => typeof c.callback === 'function'));
  });
}
test('search: normal 1600ms expiry restores key/highlight and notifies actual entry', () => {
  const f = fixture(); f.add('a'); f.page.flashSearchHit('a', 0);
  const id = f.page.searchFlashTimerId;
  assert.equal(f.delays.get(id), 1600); assert.equal(f.entries[0].key, 'a_hl');
  assert.equal(f.entries[0].searchFlash, true); f.fire(id);
  assert.equal(f.entries[0].key, 'a'); assert.equal(f.entries[0].searchFlash, false);
  assert.deepEqual(f.notifications, ['a', 'a']); assert.equal(f.page.searchFlashTimerId, -1);
});
test('search: actual aboutToDisappear cancels pending timer and clears highlight exactly once', () => {
  const f = fixture(); f.add('a'); f.page.flashSearchHit('a', 0);
  f.page.aboutToDisappear(); f.page.aboutToDisappear();
  assert.equal(f.pending.size, 0); assert.equal(f.page.searchFlashTimerId, -1);
  assert.equal(f.page.searchFlashMessageId, ''); assert.equal(f.entries[0].key, 'a');
  assert.equal(f.entries[0].searchFlash, false); assert.deepEqual(f.notifications, ['a', 'a']);
});
test('search: queued expired-lifecycle callback cannot clear a new lifecycle flash', () => {
  const f = fixture(); f.add('a'); f.add('b'); f.page.flashSearchHit('a', 0);
  const old = f.page.searchFlashTimerId; f.page.aboutToDisappear();
  f.page.flashSearchHit('b', 1); const current = f.page.searchFlashTimerId;
  const before = [...f.notifications]; f.callbacks.get(old)();
  assert.deepEqual(f.notifications, before); assert.equal(f.page.searchFlashTimerId, current);
  assert.equal(f.entries[1].searchFlash, true); assert.ok(f.pending.has(current));
});
test('search: superseded callback cannot clear newer flash within same lifecycle', () => {
  const f = fixture(); f.add('a'); f.add('b'); f.page.flashSearchHit('a', 0);
  const old = f.page.searchFlashTimerId; f.page.flashSearchHit('b', 1);
  const current = f.page.searchFlashTimerId, before = [...f.notifications];
  assert.equal(f.pending.has(old), false); f.callbacks.get(old)();
  assert.deepEqual(f.notifications, before); assert.equal(f.page.searchFlashTimerId, current);
  assert.equal(f.entries[1].key, 'b_hl'); f.fire(current); assert.equal(f.entries[1].key, 'b');
});
test('search: lifecycle-only invalidation fences callback even with unchanged timer id', () => {
  const f = fixture(); f.add('a'); f.page.flashSearchHit('a', 0);
  const id = f.page.searchFlashTimerId, before = [...f.notifications];
  f.page.pageLifecycleToken++; f.callbacks.get(id)();
  assert.deepEqual(f.notifications, before); assert.equal(f.page.searchFlashTimerId, id);
});
const failed = results.filter(r => !r.passed);
for (const [file, expected] of Object.entries(hashes)) {
  assert.equal(createHash('sha256').update(readChatSource(path.join(root, file), 'utf8')
    .replaceAll('\r\n', '\n')).digest('hex'), expected, `source stable during suite: ${file}`);
}
console.log(JSON.stringify({ suite: 'ui-window-search-lifecycle', tests: results.length,
  passed: results.length - failed.length, failed: failed.length, mutant: mutant ?? null,
  mutationSites, results, sourceHashes: hashes }, null, 2));
process.exitCode = failed.length ? 1 : 0;
