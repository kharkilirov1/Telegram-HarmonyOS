#!/usr/bin/env node
// Node >=24. Complete actual page methods, actual route/lifecycle/AppStore from
// the existing fixture. Only GlobalMediaPlayback's agreed handle API is faked:
// this suite proves page integration, NOT the global implementation or SDK.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const { createFixtureHarness } = require('./test-chat-lifecycle-account-scope.cjs');
const pageFile = path.join(__dirname, '../entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets');
const source = readChatSource(pageFile, 'utf8');
const hash = value => createHash('sha256').update(value).digest('hex');
const mutant = require.main === module ? process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9) : undefined;
assert.ok(!mutant || ['unguarded-handle', 'lost-unsubscribe', 'stale-zero-row'].includes(mutant), 'known negative control');
let mutations = 0;
const methods = ['resetPlaybackState', 'setupMediaPlaybackController', 'notifyPlaybackRows',
  'teardownMediaPlaybackController', 'publishNowPlayingMeta', 'handlePlaybackCompleted',
  'handleVoiceTap', 'handleAudioTap', 'handleAudioSeek', 'handleVoiceSeek'];
// The helper is absent on the RED baseline. All changed entry points still run.
if (/^  private getCurrentMediaPlaybackHandle\(/m.test(source)) methods.push('getCurrentMediaPlaybackHandle');
const hashes = {}, executedHashes = {};
const methodSource = methods.map(name => {
  const matches = [...source.matchAll(new RegExp(`^  (?:(?:private|public|async)\\s+)*${name}\\(`, 'gm'))];
  assert.equal(matches.length, 1, `one complete production method: ${name}`);
  const start = matches[0].index, end = source.indexOf('\n  }', start);
  assert.ok(end > start, `complete class-level method boundary: ${name}`);
  let full = source.slice(start, end + 4);
  hashes[name] = hash(full);
  const replacements = {
    'unguarded-handle': ['getCurrentMediaPlaybackHandle',
      'return this.mediaPlaybackIsCurrent?.() === true ? this.mediaPlaybackHandle : undefined;',
      'return this.mediaPlaybackHandle;'],
    'lost-unsubscribe': ['teardownMediaPlaybackController', 'unsubscribe?.();', '// Mutant: lost unsubscribe.'],
    'stale-zero-row': ['setupMediaPlaybackController', "this.activeAudioMessageId = '0';",
      "if (snapshot.isPlaying) this.activeAudioMessageId = '0';"]
  };
  const replacement = replacements[mutant];
  if (replacement && name === replacement[0]) {
    assert.equal(full.split(replacement[1]).length - 1, 1, 'negative control must engage one actual method site');
    full = full.replace(replacement[1], replacement[2]); mutations++;
  }
  executedHashes[name] = hash(full);
  return full;
}).join('\n');
assert.equal(mutations, mutant ? 1 : 0, 'negative control must change actual executed source');
const code = stripTypeScriptTypes(`class MediaPageMethods {\n${methodSource}\n}`, { mode: 'transform' });
const tick = () => new Promise(resolve => setImmediate(resolve));
const zero = () => ({ messageId: '0', contentType: 'voice', isPlaying: false, progress: 0 });
function entry(id, type = 'audio', overrides = {}) {
  return { kind: 'message', message: { messageId: id, contentType: type, senderName: 'Sender',
    isOutgoing: false, audioTitle: 'Track ' + id, audioPerformer: 'Artist', audioCoverPath: '/cover',
    audioCoverFileId: 33, audioExternalCoverFileId: 44, audioPath: '/' + id, voicePath: '/' + id, ...overrides } };
}

function mediaBoundary(f) {
  const calls = [], handles = [], registrations = [];
  let legacyListener, legacyCompleted, legacyChat = 0, stopped = 0, autoAdvances = 0;
  let playing = { ...zero(), chatId: 0, account: undefined };
  const matching = handle => playing.account === handle.account && playing.chatId === handle.chatId;
  function emit() {
    legacyListener?.(playing);
    for (const registration of registrations) {
      if (registration.attached && registration.handle.current()) {
        registration.listener?.(matching(registration.handle) ? playing : zero());
      }
    }
  }
  function toggle(account, chatId, id, file, type) {
    playing = { messageId: id, path: file, contentType: type, isPlaying: true, progress: 0, account, chatId };
    emit();
    return Promise.resolve();
  }
  // Legacy boundary is deliberately functional: RED demonstrates observed old
  // behavior (not a TypeError from removing controllerRef/setPageHandlers).
  const controller = {
    toggle: (id, file, type) => { calls.push(['raw-toggle', id, file, type]); return toggle(f.runtimeStore, legacyChat, id, file, type); },
    getActiveMessageId: () => playing.messageId,
    getIsPlaying: () => playing.isPlaying,
    seekToProgress: progress => { calls.push(['raw-seek', progress]); return Promise.resolve(); }
  };
  const global = {
    controllerRef: () => controller,
    setPageHandlers(listener, completed) { legacyListener = listener; legacyCompleted = completed; listener?.(playing); },
    setNowPlaying(...args) { calls.push(['raw-meta', ...args]); legacyChat = args[2]; },
    stop() { stopped++; playing = { ...zero(), chatId: 0 }; return Promise.resolve(); },
    createPageHandle(account, chatId, pageGuard) {
      const scope = account.createScope();
      const handle = {
        account, chatId, pageGuard,
        current: () => scope.isScopeCurrent() && pageGuard(),
        setHandlers(listener, completed) {
          const registration = { handle, listener, completed, attached: true, unsubscribed: 0 };
          registrations.push(registration);
          if (handle.current()) listener?.(matching(handle) ? playing : zero());
          return () => { registration.unsubscribed++; registration.attached = false; };
        },
        setNowPlaying(...args) { calls.push(['handle-meta', ...args]); if (handle.current()) handle.meta = args; },
        toggle(id, file, type) {
          calls.push(['handle-toggle', id, file, type]);
          return handle.current() ? toggle(account, chatId, id, file, type) : Promise.resolve();
        },
        getActiveMessageId: () => handle.current() && matching(handle) ? playing.messageId : '0',
        getIsPlaying: () => handle.current() && matching(handle) && playing.isPlaying,
        seekToProgress(progress) { calls.push(['handle-seek', progress]); return Promise.resolve(); }
      };
      handles.push(handle);
      return handle;
    }
  };
  return { global, calls, handles, registrations, emit, stopped: () => stopped,
    playing: () => playing, autoAdvances: () => autoAdvances,
    currentRegistration: () => registrations.findLast(r => r.attached && r.handle.current()),
    snapshot(snapshot, account = f.runtimeStore, chatId = f.navigation.activeChatId) {
      playing = { ...zero(), ...snapshot, account, chatId }; emit();
    },
    complete(id, type) {
      if (legacyCompleted) { legacyCompleted(id, type); return; }
      const registration = registrations.findLast(r => r.attached && r.handle.current() && matching(r.handle));
      if (registration?.completed) registration.completed(id, type);
      else if (type === 'audio') autoAdvances++;
    }
  };
}

async function fixture(harness, options = {}) {
  const f = await harness.fixture(7, { bind: false });
  const media = mediaBoundary(f);
  const deps = { globalMediaPlayback: media.global, navigationUIState: f.navigation,
    localized: (_id, fallback) => fallback, $r: id => ({ id }),
    fileUri: { FileUri: class { constructor(uri) { this.path = uri.slice('file://'.length); } } } };
  const Methods = new Function(...Object.keys(deps), code + '\nreturn MediaPageMethods;')(...Object.values(deps));
  function install(p) {
    for (const name of methods) p[name] = Methods.prototype[name];
    p.locallyListenedVoiceIds = new Set();
    p.resetPlaybackState();
    p.entries = [entry('1'), entry('2')];
    p.rowNotifications = []; p.downloads = []; p.pendingIntents = [];
    p.dataSource = { getAllEntries: () => p.entries,
      notifyItemChangedByMessageId: id => p.rowNotifications.push(id) };
    p.rememberPendingMediaOpenIntent = (...args) => p.pendingIntents.push(args);
    p.clearPendingMediaOpenIntent = () => {};
    p.requestMediaDownload = id => p.downloads.push(id);
    return p;
  }
  install(f.p);
  async function appear(p, route) {
    p.aboutToAppear(); p.bindChatRoute(route); p.showOwnedChatRoute();
    await tick(); await tick();
    assert.equal(p.routeActivated, true, 'actual route activation engaged');
    assert.equal(f.logs.some(log => /Chat route activation failed|Owned chat initialization failed/.test(String(log))),
      false, 'no setup exception swallowed by actual activation');
  }
  if (!options.unbound) await appear(f.p, f.route);
  return Object.assign(f, { media, install, appear,
    async nextPage(chatId = 7) {
      const p = install(f.newPage()), route = f.newRoute(chatId);
      f.stackParams.push(route); await appear(p, route); return p;
    } });
}
function assertSilent(media, before, label) {
  assert.deepEqual(media.calls.slice(before), [], label + ': no metadata/toggle/seek may enter even the fake handle');
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
async function main() {
  const harness = await createFixtureHarness();
  test('activation/onShown registers an account/chat-bound handle, not raw controller', async () => {
    const f = await fixture(harness);
    assert.ok(f.media.handles.length > 0, 'actual setup must call createPageHandle');
    const handle = f.media.handles.at(-1);
    assert.equal(handle.account, f.p.accountStore); assert.equal(handle.chatId, 7);
    assert.equal(handle.current(), true); assert.ok(f.media.currentRegistration());
  });
  test('voice tap publishes two metadata arguments then toggles through handle', async () => {
    const f = await fixture(harness); f.p.entries = [entry('1', 'voice')];
    f.p.handleVoiceTap('1', '/voice', 0);
    assert.deepEqual(f.media.calls, [['handle-meta', 'Sender', 'Voice message'], ['handle-toggle', '1', '/voice', 'voice']]);
    assert.equal(f.p.locallyListenedVoiceIds.has('1'), true);
    assert.equal(f.p.activeVoiceMessageId, '1');
  });
  test('audio tap passes cover as third arg (no chat id) and normalizes file URI', async () => {
    const f = await fixture(harness); f.p.handleAudioTap('file:///song', 0, 'audio/mp3', '1');
    assert.deepEqual(f.media.calls, [['handle-meta', 'Track 1', 'Artist', '/cover', 33], ['handle-toggle', '1', '/song', 'audio']]);
    assert.equal(f.p.activeAudioMessageId, '1'); assert.equal(f.p.activeAudioPlaying, true);
    assert.ok(f.p.rowNotifications.includes('1'));
  });
  test('external cover fallback retains correct handle argument positions', async () => {
    const f = await fixture(harness); f.p.entries = [entry('1', 'audio', { audioCoverFileId: 0 })];
    f.p.publishNowPlayingMeta('1', 'audio');
    assert.deepEqual(f.media.calls, [['handle-meta', 'Track 1', 'Artist', '/cover', 44]]);
  });
  test('fallback metadata uses owned route title, not mutable global title', async () => {
    const f = await fixture(harness); f.p.entries = [];
    f.navigation.activeChatTitle = 'Unrelated mutable title';
    f.p.publishNowPlayingMeta('missing', 'voice');
    assert.deepEqual(f.media.calls, [['handle-meta', 'A chat', 'Voice message']]);
  });
  for (const type of ['voice', 'audio']) {
    test(type + ' completion uses actual page auto-advance through current handle', async () => {
      const f = await fixture(harness); f.p.entries = [entry('1', type), entry('2', type)];
      f.media.snapshot({ messageId: '1', contentType: type, isPlaying: true });
      f.media.complete('1', type);
      assert.deepEqual(f.media.calls.at(-1), ['handle-toggle', '2', '/2', type]);
      assert.equal(f.media.playing().messageId, '2');
    });
    test(type + ' seek matches active id and goes through handle', async () => {
      const f = await fixture(harness);
      f.media.snapshot({ messageId: '1', contentType: type, isPlaying: true });
      const seek = type === 'audio' ? 'handleAudioSeek' : 'handleVoiceSeek';
      f.p[seek]('other', 0.2); assert.deepEqual(f.media.calls, []);
      f.p[seek]('1', 0.7); assert.deepEqual(f.media.calls, [['handle-seek', 0.7]]);
    });
  }
  test('zero snapshot clears both media types and repaints prior audio row', async () => {
    const f = await fixture(harness);
    f.media.snapshot({ messageId: '1', contentType: 'audio', isPlaying: true, progress: 0.5 });
    f.p.rowNotifications.length = 0; f.media.snapshot(zero());
    assert.equal(f.p.activeAudioMessageId, '0'); assert.equal(f.p.activeVoiceMessageId, '0');
    assert.equal(f.p.activeAudioPlaying, false); assert.equal(f.p.activeAudioProgress, 0);
    assert.deepEqual(f.p.rowNotifications, ['1']);
  });
  test('paused cross-type snapshot retires the previous active row', async () => {
    const f = await fixture(harness);
    f.media.snapshot({ messageId: '1', contentType: 'audio', isPlaying: true });
    f.media.snapshot({ messageId: '2', contentType: 'voice', isPlaying: false, progress: 0.3 });
    assert.equal(f.p.activeAudioMessageId, '0'); assert.equal(f.p.activeVoiceMessageId, '2');
  });
  test('another chat with same message id receives zero and cannot seek old audio', async () => {
    const f = await fixture(harness); f.p.handleAudioTap('/song', 0, '', '1');
    const b = await f.nextPage(8), count = f.media.calls.length;
    assert.equal(b.activeAudioMessageId, '0'); b.handleAudioSeek('1', 0.6);
    assertSilent(f.media, count, 'unrelated chat');
    assert.equal(f.media.playing().chatId, 7);
  });
  test('unrelated page completion cannot swallow old global audio continuation', async () => {
    const f = await fixture(harness); f.p.handleAudioTap('/song', 0, '', '1');
    await f.nextPage(8); const count = f.media.calls.length;
    f.media.complete('1', 'audio');
    assert.equal(f.media.autoAdvances(), 1, 'fake global fallback must remain reachable from page contract');
    assertSilent(f.media, count, 'unrelated completion');
  });
  test('old same-chat disappear unsubscribes only its registration and preserves global track', async () => {
    const f = await fixture(harness); f.p.handleAudioTap('/song', 0, '', '1');
    const old = f.media.currentRegistration(), b = await f.nextPage(7);
    f.p.aboutToDisappear();
    f.media.snapshot({ messageId: '2', contentType: 'audio', isPlaying: true });
    assert.equal(b.activeAudioMessageId, '2', 'new registration survives old actual disappear');
    assert.equal(old?.unsubscribed, 1); assert.equal(old.handle.current(), false);
    assert.equal(f.media.stopped(), 0); assert.equal(f.media.playing().isPlaying, true);
  });
  test('repeated setup revokes old handle and callbacks even in same lifecycle', async () => {
    const f = await fixture(harness), old = f.media.currentRegistration();
    assert.ok(old, 'setup must return owned unsubscribe');
    f.p.setupMediaPlaybackController();
    assert.equal(old.unsubscribed, 1); assert.equal(old.handle.current(), false);
    old.listener({ messageId: 'old', contentType: 'audio', isPlaying: true, progress: 0.5 });
    old.completed('1', 'audio');
    assert.equal(f.p.activeAudioMessageId, '0'); assert.deepEqual(f.media.calls, []);
  });
  test('teardown is idempotent and never stops the app-global player', async () => {
    const f = await fixture(harness); f.p.handleAudioTap('/song', 0, '', '1');
    const old = f.media.currentRegistration(); assert.ok(old);
    f.p.teardownMediaPlaybackController(); f.p.teardownMediaPlaybackController();
    assert.equal(old.unsubscribed, 1); assert.equal(old.handle.current(), false);
    assert.equal(f.media.stopped(), 0); assert.equal(f.media.playing().isPlaying, true);
    assert.equal(f.p.activeAudioMessageId, '0');
  });
  for (const action of ['setupMediaPlaybackController', 'aboutToDisappear']) {
    test('synchronous initial snapshot re-enters ' + action + ' without orphaning unsubscribe', async () => {
      const f = await fixture(harness); f.p.handleAudioTap('/song', 0, '', '1');
      const notify = f.p.dataSource.notifyItemChangedByMessageId;
      let hits = 0;
      f.p.dataSource.notifyItemChangedByMessageId = id => {
        notify(id);
        if (hits++ === 0) f.p[action]();
      };
      f.p.setupMediaPlaybackController();
      assert.ok(hits > 0, 'initial snapshot actually re-entered the lifecycle');
      const current = f.media.currentRegistration();
      for (const registration of f.media.registrations) {
        if (registration !== current) assert.equal(registration.unsubscribed, 1, 'superseded registration detached exactly once');
      }
      f.p.teardownMediaPlaybackController();
      assert.equal(f.media.registrations.some(r => r.attached), false, 'no lost registration cleanup');
      assert.equal(f.media.stopped(), 0);
    });
  }
  test('onShown registration refresh preserves local listened state for the retained route', async () => {
    const f = await fixture(harness); f.p.entries = [entry('1', 'voice')];
    f.p.handleVoiceTap('1', '/voice', 0);
    const b = await f.nextPage(8); b.aboutToDisappear(); f.stackParams.pop();
    assert.equal(f.p.showOwnedChatRoute(), true);
    assert.equal(f.p.locallyListenedVoiceIds.has('1'), true, 'reattaching is not leaving the route');
    f.p.aboutToDisappear(); assert.equal(f.p.locallyListenedVoiceIds.size, 0);
  });
  test('returning to retained route restores handlers and current playback snapshot', async () => {
    const f = await fixture(harness); f.p.handleAudioTap('/song', 0, '', '1');
    const b = await f.nextPage(8); b.aboutToDisappear(); f.stackParams.pop();
    f.media.snapshot({ messageId: '1', contentType: 'audio', isPlaying: true, progress: 0.8 }, f.runtimeStore, 7);
    assert.equal(f.p.showOwnedChatRoute(), true);
    assert.equal(f.p.activeAudioProgress, 0.8); assert.equal(f.media.stopped(), 0);
    const count = f.media.calls.length; f.p.handleAudioSeek('1', 0.9);
    assert.deepEqual(f.media.calls.slice(count), [['handle-seek', 0.9]]);
  });
  for (const chatId of [7, 8]) {
    test('return after chat ' + chatId + ' changes track repaints the previously active A row', async () => {
      const f = await fixture(harness); f.p.handleAudioTap('/first', 0, '', '1');
      const b = await f.nextPage(chatId); b.handleAudioTap('/second', 0, '', '2');
      f.p.rowNotifications.length = 0;
      b.aboutToDisappear(); f.stackParams.pop();
      assert.equal(f.p.showOwnedChatRoute(), true);
      assert.equal(f.p.activeAudioMessageId, chatId === 7 ? '2' : '0');
      assert.ok(f.p.rowNotifications.includes('1'), 'old LazyForEach row receives reset repaint');
      if (chatId === 7) assert.ok(f.p.rowNotifications.includes('2'), 'new same-chat row also repaints');
    });
  }
  const invalidations = {
    'account reset': f => f.store.resetState(),
    'account replacement without revoke': f => f.switchAccount(false),
    'released route': f => { void f.route.openLease.release(); },
    'non-owning same-chat route': f => { f.navigation.activeChatOwnerToken++; },
    'closing page': f => { f.p.isClosing = true; },
    'inactive route': f => { f.p.routeActivated = false; },
    'changed lifecycle': f => { f.p.pageLifecycleToken++; },
    'changed chat': f => { f.p.activeChatId = 8; },
    'changed route object': f => { f.p.routeContext = f.newRoute(); },
    'changed account field': f => { f.p.accountStore = f.store.createScope(); }
  };
  for (const [name, invalidate] of Object.entries(invalidations)) {
    test(name + ': retained snapshot/completion callbacks cannot mutate page or auto-play', async () => {
      const f = await fixture(harness), registration = f.media.currentRegistration();
      assert.ok(registration, 'guard callbacks must be registered through page handle');
      invalidate(f);
      assert.equal(registration.handle.current(), false, 'captured guard rejects stale ownership');
      registration.listener({ messageId: 'stale', contentType: 'audio', isPlaying: true, progress: 0.5 });
      registration.completed('1', 'audio');
      assert.equal(f.p.activeAudioMessageId, '0'); assert.equal(f.p.rowNotifications.length, 0);
      assert.deepEqual(f.media.calls, []);
    });
  }
  for (const name of ['account reset', 'account replacement without revoke', 'released route',
    'non-owning same-chat route', 'closing page', 'inactive route', 'changed lifecycle', 'changed chat',
    'changed route object', 'changed account field']) {
    test(name + ': retained tap/meta/seek/completion rejected before boundary calls', async () => {
      const f = await fixture(harness);
      f.media.snapshot({ messageId: '1', contentType: 'audio', isPlaying: true });
      invalidations[name](f); const before = f.media.calls.length;
      f.p.publishNowPlayingMeta('1', 'audio');
      f.p.handleAudioTap('/song', 0, '', '1'); f.p.handleVoiceTap('1', '/voice', 0);
      f.p.handleAudioSeek('1', 0.4); f.p.handleVoiceSeek('1', 0.4);
      f.p.handlePlaybackCompleted('1', 'audio');
      assertSilent(f.media, before, name);
    });
  }
  test('invalid page cannot start lazy downloads or attach a new handle', async () => {
    const f = await fixture(harness); f.p.teardownMediaPlaybackController();
    f.switchAccount(); const count = f.media.handles.length;
    f.p.handleVoiceTap('1', '', 12); f.p.handleAudioTap('', 13, '', '1');
    assert.deepEqual(f.p.downloads, []); assert.deepEqual(f.p.pendingIntents, []);
    assert.equal(f.media.handles.length, count); assert.deepEqual(f.media.calls, []);
  });
  test('route-less setup never registers a playback capability', async () => {
    const f = await fixture(harness, { unbound: true });
    f.p.setupMediaPlaybackController(); f.p.handleVoiceTap('1', '/voice', 0);
    assert.equal(f.media.handles.length, 0); assert.deepEqual(f.media.calls, []);
  });
  test('actual disappear detaches while preserving track and blocks retained taps', async () => {
    const f = await fixture(harness); f.p.handleAudioTap('/song', 0, '', '1');
    const registration = f.media.currentRegistration(), count = f.media.calls.length;
    f.p.aboutToDisappear();
    assert.equal(registration.unsubscribed, 1); assert.equal(registration.handle.current(), false);
    f.p.handleAudioTap('/song', 0, '', '1'); f.p.handleVoiceTap('1', '/voice', 0);
    assertSilent(f.media, count, 'disappeared page');
    assert.equal(f.media.stopped(), 0); assert.equal(f.media.playing().messageId, '1');
  });
  test('retained A cannot publish or toggle over active B with identical chat/message ids', async () => {
    const f = await fixture(harness); f.p.handleAudioTap('/A', 0, '', '1');
    f.switchAccount(); const b = await f.nextPage(7);
    b.entries = [entry('1', 'audio', { audioTitle: 'B track' })];
    b.handleAudioTap('/B', 0, '', '1');
    assert.equal(b.activeAudioMessageId, '1');
    assert.equal(f.media.playing().account, f.runtimeStore);
    const count = f.media.calls.length;
    f.p.publishNowPlayingMeta('1', 'audio'); f.p.handleAudioTap('/A', 0, '', '1');
    f.p.handlePlaybackCompleted('1', 'audio'); f.p.handleAudioSeek('1', 0.8);
    assertSilent(f.media, count, 'retained A after B starts');
    assert.equal(f.media.playing().path, '/B');
    f.p.aboutToDisappear();
    f.media.snapshot({ messageId: '1', contentType: 'audio', isPlaying: true, progress: 0.6 });
    assert.equal(b.activeAudioProgress, 0.6);
  });
  test('owned page keeps pending download behavior before a local path exists', async () => {
    const f = await fixture(harness);
    f.p.handleVoiceTap('1', '', 12); f.p.handleAudioTap('', 13, 'audio/mp3', '2');
    assert.deepEqual(f.p.downloads, [12, 13]); assert.equal(f.p.pendingIntents.length, 2);
    assert.deepEqual(f.media.calls, []);
  });
  let passed = 0, failed = 0;
  for (const { name, run } of tests) {
    try { await run(); passed++; console.log('PASS ' + name); }
    catch (error) { failed++; console.error('FAIL ' + name + '\n' + error.stack); }
  }
  const stable = hash(readChatSource(pageFile, 'utf8')) === hash(source) && harness.loadedSourceStable();
  console.log(JSON.stringify({ suite: 'chat-media-page-ownership', passed, failed, sourceStable: stable,
    mutant, mutations, pageHash: hash(source), methodHashes: hashes, executedMethodHashes: executedHashes,
    boundaries: ['fake GlobalMediaPlayback handle', 'native/ArkUI/network boundaries inherited from lifecycle fixture'],
    actual: ['full page methods and lifecycle callbacks', 'AppStore scopes', 'ChatScreenRouteParams', 'ChatOpenLease'] }));
  process.exitCode = failed || !stable ? 1 : 0;
}
if (require.main === module) main().catch(error => { console.error(error.stack); process.exitCode = 1; });
// Raw full methods let the account integration suite inject the actual Global,
// without importing this file's fake boundary or copying production behavior.
module.exports = { fixture, mediaBoundary, methods, hashes, methodSource, entry, pageSourceHash: hash(source) };
