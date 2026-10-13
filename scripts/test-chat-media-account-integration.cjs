#!/usr/bin/env node
// Node >=24. Actual page methods/lifecycle + Global + AppStore + controller.
// AVPlayer/files/AVSession/background APIs, navigation delivery, row sink and
// adjacent-audio network use case are controlled boundaries, not a real device.
const assert = require('node:assert/strict');
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const hash = text => createHash('sha256').update(text).digest('hex');
const files = ['entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets',
  'entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets',
  'entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets', 'entry/src/main/ets/core/store/AppStore.ets',
  'scripts/test-global-media-ownership.cjs', 'scripts/test-chat-lifecycle-account-scope.cjs',
  'scripts/test-chat-media-page-ownership.cjs'];
const original = Object.fromEntries(files.map(file => [file, readChatSource(path.join(root, file), 'utf8')]));
const { fixture: globalFixture, load, flush, deferred, track } = require('./test-global-media-ownership.cjs');
const { createFixtureHarness } = require('./test-chat-lifecycle-account-scope.cjs');
const page = require('./test-chat-media-page-ownership.cjs');
assert.equal(page.pageSourceHash, hash(original[files[0]]), 'exported full methods match current page source');
const cases = [];
const test = (name, run) => cases.push({ name, run });
let fixtures = [];
const stalledCleanupProbe = process.argv.includes('--harness-stalled-cleanup');
assert.ok(!stalledCleanupProbe || !process.argv.includes('--negative-controls'), 'run the harness probe separately');
let stalledReleaseCalls = 0;

async function bounded(work, label) {
  let timer;
  try {
    return await Promise.race([work(), new Promise((_, reject) => {
      timer = setTimeout(() => {
        const error = new Error(label + ' did not settle'); error.code = 'HARNESS_TIMEOUT'; reject(error);
      }, stalledCleanupProbe ? 100 : 2000);
    })]);
  } finally { clearTimeout(timer); }
}

async function setup(harness, globalCode) {
  const f = await harness.fixture(7, { bind: false });
  // No fixture seed/playReal/private metadata helpers are used. The page's first
  // publish must perform the first real account binding and keep its handlers.
  const media = globalCode === undefined ? globalFixture(undefined, true, false) : globalFixture(globalCode, true, false);
  assert.equal(media.global.playbackAccount, undefined, 'fixture must not prebind an account');
  assert.equal(media.controller.getActiveMessageId(), '0');
  const calls = [], gates = [];
  for (const name of ['createPageHandle', 'bindPageHandlers', 'publishForPage', 'toggleForPage', 'seekForPage']) {
    const actual = media.global[name];
    assert.equal(typeof actual, 'function', 'actual Global method exists: ' + name);
    // Observation only: unchanged receiver, arguments, return value and async chain.
    media.global[name] = function (...args) { calls.push({ name, args }); return actual.apply(this, args); };
  }
  const Methods = load(`class ActualPageMediaMethods {\n${page.methodSource}\n}`, 'ActualPageMediaMethods', {
    globalMediaPlayback: media.global, navigationUIState: f.navigation,
    localized: (_id, fallback) => fallback, $r: id => ({ id }),
    fileUri: { FileUri: class { constructor(uri) { this.path = uri.slice('file://'.length); } } }
  });
  function install(p) {
    for (const name of page.methods) p[name] = Methods.prototype[name];
    p.locallyListenedVoiceIds = new Set(); p.resetPlaybackState();
    p.entries = [page.entry('1'), page.entry('2')]; p.rowNotifications = [];
    p.dataSource = { getAllEntries: () => p.entries,
      notifyItemChangedByMessageId: id => p.rowNotifications.push(id) };
    p.clearPendingMediaOpenIntent = () => {};
    p.rememberPendingMediaOpenIntent = () => assert.fail('local-path cases must not use download fixture');
    p.requestMediaDownload = () => assert.fail('local-path cases must not request a download');
    return p;
  }
  async function appear(p, route) {
    p.aboutToAppear(); p.bindChatRoute(route);
    assert.equal(p.showOwnedChatRoute(), true, 'actual onShown path must acquire navigation ownership');
    await flush();
    assert.equal(p.routeActivated, true);
    assert.equal(f.logs.some(log => /Chat route activation failed|Owned chat initialization failed/.test(String(log))), false);
    assert.equal(media.global.pageOwner, p.mediaPlaybackHandle, 'actual Global registration belongs to the page handle');
  }
  Object.assign(f, { media, calls, gates, install, appear,
    gate() { const value = deferred(); gates.push(value); return value; },
    async nextPage(chatId = 7) {
      const p = install(f.newPage()), route = f.newRoute(chatId);
      f.stackParams.push(route); await appear(p, route); return p;
    },
    async play(p = f.p, id = '1', type = 'audio', file = '/audio/' + id, title = 'Track ' + id) {
      const existing = p.entries.find(e => e.message.messageId === id);
      assert.ok(existing, 'test track has actual page row metadata'); existing.message.audioTitle = title;
      if (type === 'voice') p.handleVoiceTap(id, file, 0);
      else p.handleAudioTap(file, 0, 'audio/mp3', id);
      await flush();
      assert.equal(media.controller.getActiveMessageId(), id, 'actual controller engaged');
      assert.equal(media.ui.messageId, id, 'actual root state receives controller snapshot');
    },
    async cleanup() {
      for (const gate of gates) gate.resolve();
      for (const request of [...media.finds, ...media.downloads, ...media.covers]) request.resolve(undefined);
      await flush();
      for (const p of f.pages) p.aboutToDisappear();
      f.runtimeStore.invalidateScopes(); f.store.invalidateScopes();
      await media.global.stop(); await flush();
      assert.deepEqual(media.violations, [], 'no swallowed SDK/filesystem contract violation');
      assert.equal(media.players.every(p => p.state === 'released'), true, 'all acquired mock AVPlayers released');
      assert.equal(media.closed.length, media.files.length, 'all acquired mock FDs closed');
      assert.equal(new Set(media.closed).size, media.closed.length, 'no duplicate FD close');
    }
  });
  fixtures.push(f); install(f.p); await appear(f.p, f.route);
  return f;
}
function noCommands(f, before) {
  assert.deepEqual(f.calls.slice(before).filter(c => ['publishForPage', 'toggleForPage', 'seekForPage'].includes(c.name)), [],
    'retained page must reject before calling actual Global capability methods');
}
function assertPlaying(f, p = f.p, id = '1') {
  assert.equal(f.media.ui.hasActive, true); assert.equal(f.media.ui.isPlaying, true);
  assert.equal(f.media.ui.messageId, id); assert.equal(f.media.ui.chatId, p.activeChatId);
  assert.equal(f.media.players.at(-1).state, 'playing');
}

test('first page setup -> metadata -> toggle binds real account and preserves row handler', async f => {
  assert.equal(f.media.global.playbackAccount, undefined);
  const handle = f.p.mediaPlaybackHandle;
  assert.equal(handle.accountStore, f.runtimeStore); assert.equal(handle.isCurrent(), true);
  await f.play(f.p, '1', 'audio', 'file:///audio/first', 'First song');
  assertPlaying(f); assert.equal(f.media.global.playbackAccount, f.runtimeStore);
  assert.equal(f.media.global.pageOwner, handle); assert.equal(f.p.activeAudioMessageId, '1');
  assert.equal(f.p.activeAudioPlaying, true); assert.equal(f.media.ui.title, 'First song');
  assert.equal(f.media.ui.subtitle, 'Artist'); assert.equal(f.media.ui.coverPath, '/cover');
  assert.deepEqual(f.media.files.map(v => v.path), ['/audio/first']);
  assert.equal(f.media.players[0].fd, f.media.files[0].fd);
  assert.deepEqual(f.media.toggles, [], 'stub controller was NOT used');
  assert.deepEqual(f.calls.filter(c => ['publishForPage', 'toggleForPage'].includes(c.name)).map(c => c.name),
    ['publishForPage', 'toggleForPage']);
  f.media.players[0].tick(22500);
  assert.equal(f.p.activeAudioProgress, 0.25); assert.equal(f.media.ui.progress, 0.25);
  assert.ok(f.p.rowNotifications.includes('1'));
});
for (const type of ['voice', 'audio']) {
  test(type + ': page seek/pause/resume reaches actual controller and row', async f => {
    f.p.entries = [page.entry('1', type)]; await f.play(f.p, '1', type);
    const seek = type === 'voice' ? 'handleVoiceSeek' : 'handleAudioSeek';
    f.p[seek]('other', 0.8); await flush(); assert.equal(f.media.ui.progress, 0);
    const seeks = [], player = f.media.players[0], actualSeek = player.seek;
    player.seek = function (...args) { seeks.push(args); return actualSeek.apply(this, args); };
    f.p[seek]('1', 0.5); await flush();
    assert.deepEqual(seeks, [[45000]]); assert.equal(f.media.ui.progress, 0.5);
    assert.equal(type === 'voice' ? f.p.activeVoiceProgress : f.p.activeAudioProgress, 0.5);
    await f.play(f.p, '1', type); assert.equal(player.state, 'paused'); assert.equal(f.media.ui.isPlaying, false);
    await f.play(f.p, '1', type); assertPlaying(f); assert.equal(f.media.players.length, 1);
  });
  test(type + ': native completed event invokes page auto-advance on actual Global/controller', async f => {
    f.p.entries = [page.entry('1', type), page.entry('2', type)]; await f.play(f.p, '1', type);
    f.media.players[0].emit('completed'); await flush();
    assertPlaying(f, f.p, '2'); assert.equal(f.media.players.length, 2);
    assert.equal(f.media.players[0].state, 'released'); assert.deepEqual(f.media.closed, [1]);
    assert.deepEqual(f.media.finds, [], 'matching page completion, not global network fallback');
    assert.ok(f.p.rowNotifications.includes('2'));
    if (type === 'voice') assert.equal(f.p.locallyListenedVoiceIds.has('2'), true);
  });
}
test('same-chat newer route owns progress after old actual disappear/unsubscribe', async f => {
  await f.play(); const oldHandle = f.p.mediaPlaybackHandle;
  const b = await f.nextPage(7); assert.equal(b.activeAudioMessageId, '1');
  f.p.aboutToDisappear(); assert.equal(oldHandle.isCurrent(), false);
  f.media.players[0].tick(45000);
  assert.equal(b.activeAudioProgress, 0.5); assert.equal(f.media.global.pageOwner, b.mediaPlaybackHandle);
  assertPlaying(f, b); assert.deepEqual(f.media.closed, []);
});
test('different-chat same message ID sees zero and cannot seek the old track', async f => {
  await f.play(); const b = await f.nextPage(8);
  f.media.players[0].tick(22500);
  assert.equal(b.activeAudioMessageId, '0'); assert.equal(b.activeVoiceMessageId, '0');
  assert.equal(b.mediaPlaybackHandle.getActiveMessageId(), '0');
  const before = f.calls.length; b.handleAudioSeek('1', 0.9); await flush();
  noCommands(f, before); assert.equal(f.media.ui.progress, 0.25); assertPlaying(f);
});
test('different chat with same ID/path starts a new player instead of pausing A', async f => {
  await f.play(); const b = await f.nextPage(8); await f.play(b, '1', 'audio', '/audio/1', 'B song');
  assertPlaying(f, b); assert.equal(f.media.ui.title, 'B song');
  assert.equal(f.media.players.length, 2); assert.equal(f.media.players[0].state, 'released');
  assert.deepEqual(f.media.files.map(v => v.path), ['/audio/1', '/audio/1']);
  assert.deepEqual(f.media.closed, [1]); assert.equal(b.activeAudioPlaying, true);
});
test('unrelated page cannot consume A completion: actual global adjacent search remains live', async f => {
  await f.play(); const b = await f.nextPage(8);
  f.media.players[0].emit('completed'); await flush();
  assert.equal(f.media.finds.length, 1); assert.deepEqual(f.media.finds[0].args, [7, '1', true]);
  assert.equal(f.media.players.length, 1, 'unrelated page did not play its own row 2');
  f.media.finds[0].resolve(track('next')); await flush();
  assertPlaying(f, f.p, 'next'); assert.equal(f.media.ui.title, 'track-next');
  assert.equal(b.activeAudioMessageId, '0');
});
for (const chatId of [7, 8]) {
  test('return to A after B chat ' + chatId + ' changes track restores snapshot and old-row repaint', async f => {
    await f.play(); const b = await f.nextPage(chatId); await f.play(b, '2');
    f.p.rowNotifications.length = 0; b.aboutToDisappear(); f.stackParams.pop();
    assert.equal(f.p.showOwnedChatRoute(), true);
    assert.equal(f.media.global.pageOwner, f.p.mediaPlaybackHandle);
    assert.equal(f.p.activeAudioMessageId, chatId === 7 ? '2' : '0');
    assert.ok(f.p.rowNotifications.includes('1'));
    if (chatId === 7) assert.ok(f.p.rowNotifications.includes('2'));
    assert.equal(f.media.ui.isPlaying, true); assert.equal(f.media.ui.messageId, '2');
  });
}
test('page disappear keeps real root playback/AVSession controls alive', async f => {
  await f.play(); await f.media.attach(); const session = f.media.sessions[0];
  assert.equal(session.metadata.at(-1).title, 'Track 1');
  f.p.aboutToDisappear(); await flush(); assertPlaying(f); assert.equal(session.destroyed, false);
  await f.media.global.pauseCurrent(); assert.equal(f.media.players[0].state, 'paused');
  await f.media.global.resumeCurrent(); assertPlaying(f);
  assert.equal(f.p.activeAudioMessageId, '0'); assert.deepEqual(f.media.closed, []);
});
for (const reset of ['invalidateScopes', 'resetState', 'resetStateQueued']) {
  test(reset + ': actual store synchronously revokes playback before UI delivery', async f => {
    await f.play(); const old = f.p.mediaPlaybackHandle, before = f.calls.length;
    const pending = f.store[reset]();
    assert.equal(old.isCurrent(), false); assert.equal(f.media.ui.hasActive, false, 'synchronous revocation');
    assert.equal(f.media.controller.getActiveMessageId(), '0');
    f.p.publishNowPlayingMeta('1', 'audio'); f.p.handleAudioTap('/stale', 0, '', '1'); f.p.handleAudioSeek('1', 0.9);
    noCommands(f, before);
    await pending; await flush();
    assert.equal(f.media.players.length, 1); assert.equal(f.media.players[0].state, 'released');
    assert.deepEqual(f.media.closed, [1]); assert.equal(f.media.ui.title, '');
  });
}
test('retained A cannot change real B playback with identical chat/message IDs', async f => {
  await f.play(); f.switchAccount(); const b = await f.nextPage(7);
  await f.play(b, '1', 'audio', '/audio/1', 'Account B'); assertPlaying(f, b);
  assert.equal(f.media.global.playbackAccount, f.runtimeStore); assert.equal(b.activeAudioMessageId, '1');
  const before = f.calls.length;
  f.p.publishNowPlayingMeta('1', 'audio'); f.p.handleVoiceTap('1', '/stale', 0);
  f.p.handleAudioTap('/audio/1', 0, '', '1'); f.p.handleAudioSeek('1', 0.9); f.p.handlePlaybackCompleted('1', 'audio');
  noCommands(f, before); f.p.aboutToDisappear(); f.media.players.at(-1).tick(45000);
  assert.equal(b.activeAudioProgress, 0.5); assert.equal(f.media.ui.title, 'Account B');
  assert.equal(f.media.players.length, 2); assert.deepEqual(f.media.closed, [1]);
});
test('runtime account replacement without explicit revoke still fences retained A commands', async f => {
  await f.play(); f.switchAccount(false); const before = f.calls.length;
  f.p.publishNowPlayingMeta('1', 'audio'); f.p.handleAudioTap('/old', 0, '', '1'); f.p.handleAudioSeek('1', 0.9);
  noCommands(f, before);
  const b = await f.nextPage(7); await f.play(b, '1', 'audio', '/audio/1', 'B replacement');
  assertPlaying(f, b); assert.equal(f.media.players.length, 2); assert.equal(f.media.players[0].state, 'released');
});
test('page reset during pending native play cannot resurrect A after B starts', async f => {
  const gate = f.gate(); f.media.playGates.push(gate);
  f.p.handleAudioTap('/A', 0, '', '1'); await flush();
  assert.equal(f.media.players.length, 1); assert.equal(f.media.players[0].state, 'prepared');
  f.switchAccount(); const b = await f.nextPage(7);
  b.handleAudioTap('/B', 0, '', '1'); await flush(); gate.resolve(); await flush();
  assertPlaying(f, b); assert.equal(f.media.files.at(-1).path, '/B');
  assert.equal(f.media.players[0].state, 'released'); assert.deepEqual(f.media.closed, [1]);
});
test('page-started AVSession is replaced on account switch and old controls cannot stop B', async f => {
  await f.play(); await f.media.attach(); const old = f.media.sessions[0];
  f.switchAccount(); const b = await f.nextPage(7); await f.play(b, '1', 'audio', '/B', 'B session');
  assert.equal(old.destroyed, true); assert.equal(f.media.sessions.length, 2);
  old.emit('stop'); old.emit('pause'); old.emit('seek', 80000); await flush();
  assertPlaying(f, b); assert.equal(f.media.ui.progress, 0);
  assert.equal(f.media.sessions[1].metadata.at(-1).title, 'B session');
});
test('reentrant first snapshot cannot orphan real Global subscription on repeat setup', async f => {
  await f.play(); const notify = f.p.dataSource.notifyItemChangedByMessageId; let reentered = false;
  f.p.dataSource.notifyItemChangedByMessageId = id => {
    notify(id); if (!reentered) { reentered = true; f.p.setupMediaPlaybackController(); }
  };
  f.p.setupMediaPlaybackController(); assert.equal(reentered, true);
  assert.equal(f.media.global.pageOwner, f.p.mediaPlaybackHandle);
  f.media.players[0].tick(45000); assert.equal(f.p.activeAudioProgress, 0.5);
  f.p.aboutToDisappear(); assert.equal(f.media.global.pageOwner, undefined);
  assertPlaying(f); assert.deepEqual(f.media.closed, []);
});
for (const crossChat of [false, true]) {
  test((crossChat ? 'cross-chat' : 'first-bind') + ' synchronous page repaint preserves newer same-handle media intent', async f => {
    if (crossChat) await f.play();
    const p = crossChat ? await f.nextPage(8) : f.p;
    p.entries = [page.entry('1', 'audio', { audioTitle: 'Superseded' }),
      page.entry('2', 'audio', { audioTitle: 'Newer intent' })];
    const notify = p.notifyPlaybackRows;
    let armed = true, reentries = 0;
    // Observe the actual snapshot -> page repaint callback, including its zero
    // snapshot. Inject one synchronous user intent; keep the original repaint.
    p.notifyPlaybackRows = function (...args) {
      notify.apply(this, args);
      if (armed) { armed = false; reentries++; p.handleAudioTap('/newer', 0, '', '2'); }
    };
    p.handleAudioTap('/superseded', 0, '', '1'); await flush();
    assert.equal(reentries, 1, 'actual synchronous snapshot callback engaged');
    assertPlaying(f, p, '2'); assert.equal(f.media.ui.title, 'Newer intent');
    assert.equal(p.activeAudioMessageId, '2');
    assert.deepEqual(f.media.files.map(v => v.path), crossChat ? ['/audio/1', '/newer'] : ['/newer']);
    assert.equal(f.media.global.pageOwner, p.mediaPlaybackHandle);
  });
}
test('early actual scope invalidation callback registers B before A retirement without losing B handlers', async f => {
  let b, callbacks = 0;
  // Installed before the first page metadata binds Global's account observer.
  f.store.subscribeScopeInvalidation(() => {
    callbacks++;
    f.runtimeStore = f.store.createScope(); f.generation++;
    b = f.install(f.newPage()); const route = f.newRoute(8);
    f.stackParams.push(route); b.aboutToAppear(); b.bindChatRoute(route);
    assert.equal(b.showOwnedChatRoute(), true);
  });
  await f.play();
  f.store.invalidateScopes();
  assert.equal(callbacks, 1); assert.ok(b);
  assert.equal(f.media.global.pageOwner, b.mediaPlaybackHandle, 'later old-account observer preserves current B registration');
  assert.equal(f.media.ui.hasActive, false, 'old audio revoked synchronously');
  await f.play(b, '1', 'audio', '/B-early', 'B early');
  assertPlaying(f, b); assert.equal(b.activeAudioMessageId, '1');
  assert.equal(f.media.ui.title, 'B early'); assert.deepEqual(f.media.closed, [1]);
});

async function run(harness, globalCode, quiet = false) {
  const results = [];
  for (const t of cases) {
    fixtures = [];
    try {
      await bounded(async () => {
        const f = await setup(harness, globalCode); await t.run(f);
        if (stalledCleanupProbe && t === cases[0]) {
          assert.equal(f.media.players.length, 1, 'harness probe requires a started actual controller');
          f.media.players[0].release = () => { stalledReleaseCalls++; return new Promise(() => {}); };
        }
        for (const active of fixtures) await active.cleanup();
      }, 'test/setup/cleanup');
      results.push({ name: t.name, passed: true }); if (!quiet) console.log('PASS ' + t.name);
    } catch (error) {
      results.push({ name: t.name, passed: false, code: error.code, error: error.stack });
      if (!quiet) console.error('FAIL ' + t.name + '\n' + error.stack);
      // Retry cleanup remains bounded too; the original failure is already
      // recorded and cannot become a green result if teardown never settles.
      for (const f of fixtures) { try { await bounded(() => f.cleanup(), 'failure cleanup'); } catch (_) {} }
    }
  }
  return results;
}
async function main() {
  const harness = await createFixtureHarness();
  const results = await run(harness);
  const controls = [];
  if (!results.some(r => !r.passed) && process.argv.includes('--negative-controls')) {
    const globalSource = original[files[1]].replaceAll('\r\n', '\n');
    for (const [name, before, after, witness] of [
      ['first-bind-handler', 'if (!this.pageOwner || !this.pageOwner.isCurrent()) {', 'if (true) {', cases[0].name],
      ['crosschat-same-id', 'if (this.metaChatId !== 0 && this.metaChatId !== owner.chatId) {', 'if (false) {',
        'different chat with same ID/path starts a new player instead of pausing A'],
      ['unscoped-unsubscribe', 'if (this.pageSubscriptionId !== subscription) return;', 'if (false) return;',
        'same-chat newer route owns progress after old actual disappear/unsubscribe'],
      ['no-account-retirement', 'if (this.playbackScope === scope) this.retireAccount();', '/* omitted retirement */',
        'invalidateScopes: actual store synchronously revokes playback before UI delivery'],
      ['stale-page-intent', 'if (intent === 0 || intent !== this.playbackGeneration || !this.ownsPageTrack(owner)) return;',
        'if (!this.ownsPageTrack(owner)) return;',
        'first-bind synchronous page repaint preserves newer same-handle media intent']
    ]) {
      assert.equal(globalSource.split(before).length - 1, 1, 'control engages one actual Global source site: ' + name);
      const changed = globalSource.replace(before, after), mutated = await run(harness, changed, true);
      const failures = mutated.filter(r => !r.passed);
      assert.ok(failures.some(r => r.name === witness), 'specific behavioral witness detects ' + name);
      assert.ok(failures.every(r => r.code === 'ERR_ASSERTION'), 'no harness/parser errors masked as negative control');
      controls.push({ name, failed: failures.length, originalHash: hash(globalSource), executedHash: hash(changed) });
      console.log('NEGATIVE CONTROL ' + name + ': ' + failures.length + '/' + cases.length + ' FAIL (expected)');
    }
  }
  const sourceStable = files.every(file => readChatSource(path.join(root, file), 'utf8') === original[file]) && harness.loadedSourceStable();
  const failed = results.filter(r => !r.passed);
  if (stalledCleanupProbe) assert.equal(stalledReleaseCalls, 1, 'harness probe engaged actual SDK release exactly once');
  console.log(JSON.stringify({ suite: 'chat-media-account-integration', passed: results.length - failed.length,
    failed: failed.length, sourceStable, controls, stalledCleanupProbe, stalledReleaseCalls,
    sourceHashes: Object.fromEntries(files.map(file => [file, hash(original[file])])),
    pageMethodHashes: page.hashes, lifecycleMethodHashes: harness.methodHashes,
    actual: ['full page media/lifecycle methods', 'GlobalMediaPlayback + MediaPlaybackPageHandle',
      'AppStore scopes/invalidation', 'MediaPlaybackController', 'ChatScreenRouteParams + ChatOpenLease'],
    mocked: ['AVPlayer/file/AVSession/background SDKs', 'native/TDLib transport', 'adjacent-audio use case/network',
      'ArkUI lifecycle delivery/navigation/row rendering', 'timers/localization/FileUri'],
    failures: failed }));
  process.exitCode = failed.length || !sourceStable ? 1 : 0;
}
if (require.main === module) {
  let finished = false;
  process.once('beforeExit', () => {
    if (!finished) { console.error('HARNESS_ERROR: integration run did not finish'); process.exitCode = 1; }
  });
  main().then(() => { finished = true; }).catch(error => {
    finished = true; console.error(error.stack); process.exitCode = 1;
  });
}
