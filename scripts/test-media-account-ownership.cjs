// Actual Global + AVPlayer controller + AppStore scope; SDK boundaries only.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { fixture, deferred, flush, load, track } = require('./test-global-media-ownership.cjs');
const root = path.resolve(__dirname, '..');
const globalFile = path.join(root, 'entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets');
const original = fs.readFileSync(globalFile, 'utf8');
const source = original.replaceAll('\r\n', '\n');
let activeSource = source;
const storeSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/core/store/AppStore.ets'), 'utf8');
const AppStore = load(storeSource, 'AppStore', { createInitialAppState: () => ({}), assertInvariants() {},
  hilog: { info() {}, warn() {}, debug() {}, error() {} } });
function setup() {
  const f = fixture(activeSource, true, false); f.root = new AppStore(s => s, {}, false); f.owner = f.root.createScope();
  f.handle = (owner = f.owner, chatId = -100, guard = () => true) => {
    if (typeof f.global.createPageHandle === 'function') return f.global.createPageHandle(owner, chatId, guard);
    // Explicit baseline adapter mirrors the former page's raw Global calls.
    // Not a production fallback; all fixed runs must engage createPageHandle.
    return {
      setNowPlaying: (title, subtitle = '', coverPath = '', coverFileId = 0) => f.global.setNowPlaying(title, subtitle, chatId, coverPath, coverFileId),
      toggle: (...args) => f.controller.toggle(...args), seekToProgress: value => f.controller.seekToProgress(value),
      getActiveMessageId: () => f.controller.getActiveMessageId(), getIsPlaying: () => f.controller.getIsPlaying(),
      setHandlers: (listener, completed) => { f.global.setPageHandlers(listener, completed); return () => f.global.setPageHandlers(); }
    };
  };
  f.play = async (handle = f.handle(), id = '10', title = 'A') => { handle.setNowPlaying(title, 'artist'); await handle.toggle(id, '/audio/' + id, 'audio'); await flush(); return handle; };
  return f;
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
test('scope invalidation stops actual active player without queued state notification', async () => {
  const f = setup(); await f.play(); assert.equal(f.players[0].state, 'playing'); f.root.invalidateScopes();
  assert.equal(f.ui.hasActive, false); await flush(); assert.equal(f.players[0].state, 'released'); assert.deepEqual(f.closed, [1]);
});
test('root resetQueued synchronously revokes UI and old handle cannot restart', async () => {
  const f = setup(); const a = await f.play(); const reset = f.root.resetStateQueued(); assert.equal(f.ui.hasActive, false);
  await reset; a.setNowPlaying('stale', ''); await a.toggle('12', '/old', 'audio'); await flush(); assert.equal(f.players.length, 1); assert.equal(f.ui.title, '');
});
test('new account can play same IDs and old page cannot change title or stop it', async () => {
  const f = setup(); const a = await f.play(); f.root.invalidateScopes(); const b = f.handle(f.root.createScope()); await f.play(b, '10', 'B');
  a.setNowPlaying('secret A', ''); await a.toggle('10', '/audio/10', 'audio'); await a.seekToProgress(0.9);
  assert.equal(f.ui.title, 'B'); assert.equal(f.ui.isPlaying, true); assert.equal(a.getActiveMessageId(), '0'); assert.equal(a.getIsPlaying(), false);
});
test('page guard invalidation blocks metadata and toggle but leaving does not stop current global audio', async () => {
  const f = setup(); let current = true; const a = f.handle(undefined, -100, () => current); await f.play(a); current = false;
  a.setNowPlaying('late', ''); await a.toggle('11', '/late', 'audio'); assert.equal(f.ui.title, 'A'); assert.equal(f.players.length, 1); assert.equal(f.players[0].state, 'playing');
});
test('old handler cleanup cannot remove newer same-chat owner', async () => {
  const f = setup(); await f.play(); const a = f.handle(), b = f.handle(); const seen = [];
  const disposeA = a.setHandlers(() => {}); b.setHandlers(s => seen.push(s.messageId)); disposeA();
  const before = seen.length; f.players[0].tick(); assert.equal(seen.length, before + 1); assert.equal(seen.at(-1), '10');
});

test('page handlers registered before first playback survive account binding', async () => {
  const f = setup(); const a = f.handle(); const seen = []; a.setHandlers(s => seen.push(s.messageId));
  await f.play(a); assert.equal(seen.at(-1), '10');
});

test('new account handlers registered before first playback survive rebinding', async () => {
  const f = setup(); await f.play(); f.root.invalidateScopes(); const b = f.handle(f.root.createScope());
  const seen = []; b.setHandlers(s => seen.push(s.messageId)); await f.play(b, '10', 'B'); assert.equal(seen.at(-1), '10');
});

test('switching chats with identical message id and path starts a new owner instead of pausing old sound', async () => {
  const f = setup(); await f.play(); const b = f.handle(undefined, -200); const seen = [];
  b.setHandlers(s => seen.push(s.messageId)); await f.play(b, '10', 'B');
  assert.equal(f.players.length, 2); assert.equal(f.players[0].state, 'released');
  assert.equal(f.ui.isPlaying, true); assert.equal(f.ui.chatId, -200); assert.equal(seen.at(-1), '10');
});

test('synchronous zero-snapshot listener revocation cannot republish old account metadata', async () => {
  const f = setup(); await f.play(); const b = f.handle(undefined, -200); let armed = false;
  b.setHandlers(s => { if (armed && s.messageId === '0') { armed = false; f.root.invalidateScopes(); } });
  armed = true; b.setNowPlaying('revoked secret', ''); await flush();
  assert.equal(f.ui.title, ''); assert.equal(f.ui.chatId, 0); assert.equal(f.ui.hasActive, false);
});

test('new epoch page handler registered by earlier invalidation observer survives cleanup A', async () => {
  const f = setup(); let b; const seen = [];
  f.root.subscribeScopeInvalidation(() => { b = f.handle(f.root.createScope()); b.setHandlers(s => seen.push(s.messageId)); });
  await f.play(); f.root.invalidateScopes(); await f.play(b, '10', 'B'); const count = seen.length; f.players.at(-1).tick();
  assert.equal(seen.at(-1), '10'); assert.equal(seen.length, count + 1);
});

for (const initial of [false, true]) for (const outerToggle of [false, true]) {
  test(`newer same-handle intent survives ${initial ? 'initial bind' : 'cross-chat stop'}${outerToggle ? ' including outer toggle' : ''}`, async () => {
    const f = setup(); if (!initial) await f.play(); const handle = f.handle(undefined, -200);
    let armed = false, fired = false, newer;
    handle.setHandlers(s => { if (armed && !fired && s.messageId === '0') {
      fired = true; handle.setNowPlaying('newer intent', ''); newer = handle.toggle('30', '/audio/30', 'audio');
    } });
    armed = true; handle.setNowPlaying('older intent', ''); if (outerToggle) await handle.toggle('20', '/audio/20', 'audio');
    await newer; await flush(); assert.equal(handle.isCurrent(), true); assert.equal(f.ui.title, 'newer intent');
    assert.equal(f.ui.messageId, '30'); assert.equal(f.ui.isPlaying, true);
  });
}
test('different chat with same message ID sees zero snapshot and cannot seek old track', async () => {
  const f = setup(); await f.play(); const b = f.handle(undefined, -200); const seen = [];
  b.setHandlers(s => seen.push(s.messageId)); f.players[0].tick(); assert.equal(seen.at(-1), '0'); assert.equal(b.getActiveMessageId(), '0');
  await b.seekToProgress(0.9); assert.equal(f.ui.progress, 4000 / 90000);
});
test('different-chat handler cannot consume old audio completion', async () => {
  const f = setup(); await f.play(); const completed = []; f.handle(undefined, -200).setHandlers(() => {}, id => completed.push(id));
  f.players[0].emit('completed'); await flush(); assert.deepEqual(completed, []); assert.equal(f.finds.length, 1); assert.equal(f.finds[0].args[0], -100);
  f.finds[0].resolve(undefined); await flush();
});
test('same account reopening matching chat replays current snapshot and completion', async () => {
  const f = setup(); const a = await f.play(); const dispose = a.setHandlers(() => {}); dispose(); const seen = [], complete = [];
  f.handle().setHandlers(s => seen.push(s.messageId), id => complete.push(id)); assert.equal(seen.at(-1), '10');
  f.players[0].emit('completed'); assert.deepEqual(complete, ['10']); assert.equal(f.finds.length, 0);
});
test('invalidated lookup/cover cannot cross account boundary and next account uses a fresh search capability', async () => {
  const f = setup(); const a = await f.play(); a.setNowPlaying('A', '', '', 31);
  const next = f.global.playNextAudio(); f.root.invalidateScopes(); const b = f.handle(f.root.createScope()); await f.play(b, '10', 'B');
  f.finds[0].resolve(track('11')); f.covers[0].resolve('/old-cover'); assert.equal(await next, false); await flush();
  assert.equal(f.ui.title, 'B'); assert.equal(f.ui.coverPath, ''); assert.equal(f.players.length, 2);
  assert.equal(f.searchCreates, 1); const newNext = f.global.playNextAudio(); assert.equal(f.searchCreates, 2);
  f.finds[1].resolve(undefined); assert.equal(await newNext, false);
});
test('stale handle registering after account reset does not replace current subscription', async () => {
  const f = setup(); const a = await f.play(); f.root.invalidateScopes(); const b = f.handle(f.root.createScope()); await f.play(b, '10', 'B');
  const seen = []; b.setHandlers(s => seen.push(s.messageId)); a.setHandlers(() => { throw new Error('stale handler'); });
  const before = seen.length; f.players.at(-1).tick(); assert.equal(seen.length, before + 1);
});
test('captured root handle stays revoked even when root is reused', async () => {
  const f = setup(); const a = f.handle(f.root); await f.play(a); f.root.invalidateScopes(); const b = f.handle(f.root); await f.play(b, '10', 'B');
  a.setNowPlaying('old root', ''); await a.toggle('11', '/old-root', 'audio'); assert.equal(f.ui.title, 'B'); assert.equal(f.players.length, 2);
});
test('account invalidation destroys old AVSession and stale system commands cannot control B', async () => {
  const f = setup(); await f.play(); await f.attach(); const old = f.sessions[0]; assert.ok(old);
  f.root.invalidateScopes(); const b = f.handle(f.root.createScope()); await f.play(b, '10', 'B'); await flush();
  assert.equal(old.destroyed, true); assert.equal(f.sessions.length, 2); old.emit('stop'); old.emit('pause'); await flush();
  assert.equal(f.ui.title, 'B'); assert.equal(f.ui.isPlaying, true); assert.equal(f.sessions[1].metadata.at(-1).title, 'B');
});
test('pending AVSession create is retired without activation after invalidation', async () => {
  const f = setup(); const gate = deferred(); f.sessionCreateGates.push(gate); await f.play(); await f.attach();
  f.root.invalidateScopes(); gate.resolve(); await flush(); assert.equal(f.sessions[0].activations, 0); assert.equal(f.sessions[0].destroyed, true);
});
test('new session creation waits for old destroy and receives only new metadata', async () => {
  const f = setup(); const gate = deferred(); f.sessionDestroyGates.push(gate); await f.play(); await f.attach();
  f.root.invalidateScopes(); const b = f.handle(f.root.createScope()); await f.play(b, '10', 'B');
  assert.equal(f.sessions.length, 1); gate.resolve(); await flush(); assert.equal(f.sessions.length, 2); assert.equal(f.sessions[1].metadata.at(-1).title, 'B');
});
test('ordinary page detach keeps AVSession and root controls operational', async () => {
  const f = setup(); const a = await f.play(); await f.attach(); const detach = a.setHandlers(() => {}); detach();
  await f.global.pauseCurrent(); assert.equal(f.ui.isPlaying, false); await f.global.resumeCurrent(); assert.equal(f.ui.isPlaying, true);
  assert.equal(f.sessions[0].destroyed, false);
});

test('root attach before account is inert and first binding syncs current metadata', async () => {
  const f = setup(); await f.attach(); assert.equal(f.sessions.length, 0); await f.play();
  assert.equal(f.sessions.length, 1); assert.equal(f.sessions[0].metadata.at(-1).title, 'A');
});

test('repeated attach while creation pending coalesces one native session', async () => {
  const f = setup(); const gate = deferred(); f.sessionCreateGates.push(gate); await f.play(); await f.attach(); await f.attach();
  assert.equal(f.sessions.length, 1); gate.resolve(); await flush(); assert.equal(f.sessions[0].activations, 1);
});

test('invalidation during activate serializes cleanup before B and rejects all stale commands', async () => {
  const f = setup(); const gate = deferred(); f.sessionActivateGates.push(gate); await f.play(); await f.attach(); const old = f.sessions[0];
  assert.equal(old.activations, 1); f.root.invalidateScopes(); const b = f.handle(f.root.createScope()); await f.play(b, '10', 'B');
  assert.equal(f.sessions.length, 1); for (const event of ['stop', 'pause', 'play', 'playNext', 'playPrevious', 'seek']) old.emit(event, 50000);
  await flush(); assert.equal(f.ui.isPlaying, true); assert.equal(f.finds.length, 0); assert.equal(f.seeks.length, 0);
  gate.resolve(); await flush(); assert.equal(old.destroyed, true); assert.equal(old.destroys, 1);
  assert.equal(old.metadata.length, 0); assert.equal(f.sessions.length, 2); assert.equal(f.sessions[1].metadata.at(-1).title, 'B');
});

test('current AVSession play pause seek and adjacent commands engage actual playback', async () => {
  const f = setup(); await f.play(); await f.attach(); const session = f.sessions[0];
  session.emit('pause'); await flush(); assert.equal(f.ui.isPlaying, false);
  session.emit('play'); await flush(); assert.equal(f.ui.isPlaying, true);
  session.emit('seek', 45000); await flush(); assert.deepEqual(f.seeks, [45000]);
  session.emit('playNext'); assert.equal(f.finds.length, 1); assert.deepEqual(f.finds[0].args, [-100, '10', true]);
  f.finds[0].resolve(undefined); await flush(); session.emit('stop'); await flush(); assert.equal(f.ui.hasActive, false);
});

for (const phase of ['create', 'activate']) test(`AVSession ${phase} failure is retried by next playback intent`, async () => {
  const f = setup(); const gate = deferred(); (phase === 'create' ? f.sessionCreateGates : f.sessionActivateGates).push(gate);
  // A negative control can skip the SDK call entirely. Keep that unconsumed
  // fixture rejection handled; the original promise still rejects its awaiter.
  gate.promise.catch(() => {});
  await f.play(); await f.attach(); gate.reject(new Error('expected ' + phase)); await flush();
  if (phase === 'activate') assert.equal(f.sessions[0].destroyed, true);
  await f.play(f.handle(), '11', 'retry'); assert.equal(f.sessions.length, 2);
  assert.equal(f.sessions[1].metadata.at(-1).title, 'retry');
});

test('destroy rejection does not grant stale commands or poison next account creation', async () => {
  const f = setup(); const gate = deferred(); f.sessionDestroyGates.push(gate); await f.play(); await f.attach(); const old = f.sessions[0];
  gate.promise.catch(() => {});
  f.root.invalidateScopes(); const b = f.handle(f.root.createScope()); await f.play(b, '10', 'B');
  gate.reject(new Error('expected destroy failure')); await flush(); assert.equal(old.destroyed, false);
  old.emit('stop'); await flush(); assert.equal(f.ui.title, 'B'); assert.equal(f.ui.isPlaying, true); assert.equal(f.sessions.length, 2);
});

for (const phase of ['create', 'prepare']) test(`account revoked during player ${phase} cannot resurrect A`, async () => {
  const f = setup(); const gate = deferred(); (phase === 'create' ? f.playerCreateGates : f.prepareGates).push(gate);
  const a = f.handle(); a.setNowPlaying('A', ''); const starting = a.toggle('10', '/A', 'audio'); await flush();
  f.root.invalidateScopes(); gate.resolve(); await starting; await flush(); assert.equal(f.ui.hasActive, false);
  assert.equal(f.players[0].state, 'released'); assert.equal(f.closed.length, phase === 'create' ? 0 : 1);
});

test('root commands after account revocation do not acquire player or network capability', async () => {
  const f = setup(); await f.play(); f.root.invalidateScopes();
  await f.global.toggleCurrent(); await f.global.resumeCurrent(); await f.global.pauseCurrent(); await f.global.seekToProgress(0.8);
  assert.equal(await f.global.playNextAudio(), false); assert.equal(await f.global.cyclePlaybackSpeed(), 1);
  assert.equal(f.players.length, 1); assert.equal(f.finds.length, 0); assert.equal(f.seeks.length, 0);
});

for (const boundary of ['shutdown', 'recovery', 'failure']) test(`actual AppCoreRuntime ${boundary} synchronously revokes playback and AVSession`, async () => {
  const { fixture: runtimeFixture } = require('./test-runtime-account-recovery.cjs'); const runtime = await runtimeFixture();
  const f = setup(); f.root = runtime.runtime.getLifecycleStore(); f.owner = runtime.runtime.getStore();
  const a = await f.play(); await f.attach(); const session = f.sessions[0];
  let work;
  if (boundary === 'shutdown') work = runtime.runtime.shutdown();
  else if (boundary === 'recovery') work = runtime.close();
  else work = runtime.hooks().onFailure(new Error('expected bootstrap failure'));
  assert.equal(f.ui.hasActive, false, 'must revoke before queued store notification');
  await work; await flush(); assert.equal(f.players[0].state, 'released'); assert.equal(session.destroyed, true);
  a.setNowPlaying('stale', ''); await a.toggle('11', '/stale', 'audio'); assert.equal(f.players.length, 1);
  await runtime.runtime.shutdown();
});

async function run(code = source, quiet = false) {
  activeSource = code; const failures = [];
  for (const t of tests) { let timer; try {
    await Promise.race([t.run(), new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('test did not settle')), 1500); })]);
    if (!quiet) console.log('PASS ' + t.name);
  } catch (error) { failures.push({ name: t.name, error }); if (!quiet) console.error('FAIL ' + t.name + '\n' + error.stack); } finally { clearTimeout(timer); } }
  return failures;
}
async function main() {
  const failures = await run(); console.log('media account ownership: ' + (tests.length - failures.length) + '/' + tests.length + ' PASS');
  if (!failures.length) {
    const controls = [
      ['scope invalidation subscription disabled', 'if (this.playbackScope === scope) this.retireAccount();', '',
        'scope invalidation stops actual active player without queued state notification'],
      ['new page handlers dropped on bind', 'if (!this.pageOwner || !this.pageOwner.isCurrent()) {', 'if (true) {',
        'page handlers registered before first playback survive account binding'],
      ['old unsubscribe clears new handler', 'if (this.pageSubscriptionId !== subscription) return;', '',
        'old handler cleanup cannot remove newer same-chat owner'],
      ['chat identity guard removed', 'owner.accountStore === this.playbackAccount && owner.chatId === this.metaChatId', 'owner.accountStore === this.playbackAccount',
        'different chat with same message ID sees zero snapshot and cannot seek old track'],
      ['root scope not captured', 'this.accountScope = accountStore.createScope();', 'this.accountScope = accountStore;',
        'captured root handle stays revoked even when root is reused'],
      ['page current guard removed', 'this.accountScope.isScopeCurrent() && this.pageCurrent()', 'this.accountScope.isScopeCurrent()',
        'page guard invalidation blocks metadata and toggle but leaving does not stop current global audio'],
      ['search capability retained across accounts', 'this.searchUseCase = undefined;', '',
        'invalidated lookup/cover cannot cross account boundary and next account uses a fresh search capability'],
      ['cross-chat resource handoff removed', 'if (this.metaChatId !== 0 && this.metaChatId !== owner.chatId)', 'if (false)',
        'switching chats with identical message id and path starts a new owner instead of pausing old sound'],
      ['initial publish ordering removed',
        'if (this.playbackGeneration !== generation + 1 || !owner.isCurrent()) return 0;', '',
        'newer same-handle intent survives initial bind'],
      ['cross-chat publish ordering removed', 'if (this.playbackGeneration !== generation + 1) return 0;', '',
        'newer same-handle intent survives cross-chat stop'],
      ['stale outer toggle allowed', 'intent === 0 || intent !== this.playbackGeneration || !this.ownsPageTrack(owner)', '!this.ownsPageTrack(owner)',
        'newer same-handle intent survives cross-chat stop including outer toggle'],
      ['session retirement removed', '    this.retireAvSession();', '',
        'account invalidation destroys old AVSession and stale system commands cannot control B'],
      ['post-create generation guard removed',
        "        created = await AVSessionManager.createAVSession(context, 'TgIslandPlayer', 'audio');\n        if (!this.isAvSessionRequestCurrent(revision)) {\n          await this.destroyAvSession(created);\n          return;\n        }",
        "        created = await AVSessionManager.createAVSession(context, 'TgIslandPlayer', 'audio');",
        'pending AVSession create is retired without activation after invalidation'],
      ['post-activate generation guard removed',
        '        await created.activate();\n        if (!this.isAvSessionRequestCurrent(revision)) {\n          await this.destroyAvSession(created);\n          return;\n        }',
        '        await created.activate();',
        'invalidation during activate serializes cleanup before B and rejects all stale commands'],
      ['session create not serialized with destroy', 'this.avSessionQueue = this.avSessionQueue.then(async', 'this.avSessionQueue = Promise.resolve().then(async',
        'new session creation waits for old destroy and receives only new metadata'],
      ['stale session command gate removed', 'this.isAvSessionRequestCurrent(revision) && this.avSession === session', 'true',
        'account invalidation destroys old AVSession and stale system commands cannot control B'],
      ['session native destroy removed', 'await session.destroy();', '// mutation: not destroyed',
        'account invalidation destroys old AVSession and stale system commands cannot control B'],
      ['pending creation coalescing removed', 'if (!this.hasCurrentAccount() || this.avSessionRequested) return;', 'if (!this.hasCurrentAccount()) return;',
        'repeated attach while creation pending coalesces one native session'],
      ['same-account intent retry removed', 'if (this.avContext) this.attachAvSession(this.avContext);', '',
        'AVSession create failure is retried by next playback intent']
    ];
    for (const [name, before, after, witness] of controls) {
      assert.equal(source.split(before).length - 1, 1, name + ': exact source site must engage');
      const rejected = await run(source.replace(before, after), true);
      assert.ok(rejected.some(f => f.name === witness), name + ': named behavioral witness must fail');
      assert.ok(rejected.every(f => f.error.code === 'ERR_ASSERTION'), name + ': reject on behavior, not harness failure');
      console.log('NEGATIVE CONTROL ' + name + ': ' + rejected.length + '/' + tests.length + ' FAIL (expected)');
    }
    console.log('In-memory account/session controls: ' + controls.length + '/' + controls.length + ' rejected');
  }
  assert.equal(fs.readFileSync(globalFile, 'utf8'), original, 'tests do not mutate production'); process.exitCode = failures.length ? 1 : 0;
}
if (require.main === module) main().catch(e => { console.error(e); process.exitCode = 1; });
module.exports = { setup, run, tests };
