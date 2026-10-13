// Node >=24. Executes the actual GlobalMediaPlayback ETS body, not a model.
// Unit cases double the controller boundary; integration cases load the actual
// controller too, with only SDK/network/filesystem/timer boundaries mocked.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const file = path.join(root, 'entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets');
const original = fs.readFileSync(file, 'utf8');
const source = original.replaceAll('\r\n', '\n');
const controllerFile = path.join(root, 'entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets');
const controllerSource = fs.readFileSync(controllerFile, 'utf8');
const hash = value => createHash('sha256').update(value).digest('hex');
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
async function flush() { for (let i = 0; i < 80; i++) await Promise.resolve(); }
const snapshot = (id = '10', playing = true) => ({
  messageId: id, path: id === '0' ? '' : `/audio/${id}`, contentType: 'audio',
  isPlaying: playing, progress: 0, durationMs: 90000, currentTimeMs: 0
});
const track = (id = '11', localPath = `/audio/${id}`) => ({
  messageId: id, localPath, fileId: 110, title: `track-${id}`, performer: 'artist',
  coverPath: '', coverFileId: 0
});
function load(code, result, deps) {
  const body = code.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '')
    .replace(/^@ObservedV2\s*\n/gm, '').replace(/@Trace\s+/g, '');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(body, { mode: 'strip' }) +
    `\nreturn ${result};`)(...Object.values(deps));
}
function fixture(code = source, realController = false, bindTestAccount = true) {
  const f = {
    finds: [], downloads: [], covers: [], toggles: [], speeds: [], metadata: [],
    events: [], timers: new Map(), wantGates: [], startGates: [], stopGates: [],
    active: false, wantCalls: 0, startCalls: 0, stopCalls: 0, searchCreates: 0,
    sessions: [], sessionCreateGates: [], sessionDestroyGates: [], sessionActivateGates: []
  };
  class Controller {
    operation = 0;
    setListener(fn) { this.listener = fn; this.emit('0', false); }
    setOnCompleted(fn) { this.completed = fn; }
    emit(id, playing = true) { if (id !== '0') this.operation++; this.listener(snapshot(id, playing)); }
    async toggle(id, p, type) {
      const operation = ++this.operation;
      f.toggles.push([id, p, type]); this.emit('0', false);
      if (f.toggleGate) await f.toggleGate.promise;
      if (operation === this.operation) this.emit(id);
    }
    async release() {
      // Release relinquishes ownership before its async cleanup settles.
      // Stale controller emits are a separate controller-level contract.
      this.operation++; this.emit('0', false);
      if (f.releaseGate) await f.releaseGate.promise;
    }
    async setPlaybackSpeed(speed) { f.speeds.push(speed); }
    async pause() { this.emit(f.ui.messageId, false); }
    async seekToProgress() {}
  }
  const useCase = {
    findAdjacentAudio(...args) { const d = deferred(); f.finds.push({ ...d, args }); return d.promise; },
    downloadAudioSync(...args) { const d = deferred(); f.downloads.push({ ...d, args }); return d.promise; },
    requestThumbDownload(...args) { const d = deferred(); f.covers.push({ ...d, args }); return d.promise; }
  };
  function session() {
    const handlers = new Map(); const destroyGate = f.sessionDestroyGates.shift();
    const activateGate = f.sessionActivateGates.shift();
    const value = {
      destroyed: false, destroys: 0, activations: 0, metadata: [], states: [],
      on(event, fn) { handlers.set(event, fn); },
      emit(event, ...args) { handlers.get(event)?.(...args); },
      async activate() { this.activations++; if (activateGate) await activateGate.promise; },
      async destroy() { this.destroys++; if (destroyGate) await destroyGate.promise; this.destroyed = true; },
      async setAVPlaybackState(state) { this.states.push(state); },
      async setAVMetadata(data) { this.metadata.push(data); f.metadata.push(data); }
    };
    f.sessions.push(value); return value;
  }
  let timer = 0;
  const deps = {
    MediaPlaybackController: Controller,
    MediaPlaybackSnapshot: load(controllerSource, 'MediaPlaybackSnapshot', {}),
    createSearchChatMessagesUseCase: () => { f.searchCreates++; return { ...useCase }; }, getTdGatewayAdapter: () => ({}),
    hilog: { debug() {}, warn() {} },
    AVSessionManager: {
      createAVSession: async () => { const value = session(); const gate = f.sessionCreateGates.shift(); if (gate) await gate.promise; return value; },
      PlaybackState: { PLAYBACK_STATE_STOP: 0, PLAYBACK_STATE_PLAY: 1, PLAYBACK_STATE_PAUSE: 2 }
    },
    wantAgent: {
      OperationType: { START_ABILITY: 1 }, WantAgentFlags: { UPDATE_PRESENT_FLAG: 1 },
      async getWantAgent() {
        f.wantCalls++; const d = f.wantGates.shift(); if (d) await d.promise; return {};
      }
    },
    backgroundTaskManager: {
      BackgroundMode: { AUDIO_PLAYBACK: 1 },
      async startBackgroundRunning() {
        f.startCalls++; f.events.push('start');
        const d = f.startGates.shift(); if (d) await d.promise;
        f.active = true; f.events.push('started');
      },
      async stopBackgroundRunning() {
        f.stopCalls++; f.events.push('stop');
        const d = f.stopGates.shift(); if (d) await d.promise;
        f.active = false; f.events.push('stopped');
      }
    },
    setTimeout(fn) { f.timers.set(++timer, fn); return timer; },
    clearTimeout(id) { f.timers.delete(id); }
  };
  if (realController) {
    f.players = []; f.files = []; f.closed = []; f.playGates = []; f.playerReleaseGates = [];
    f.playerCreateGates = []; f.prepareGates = []; f.seeks = [];
    f.violations = [];
    const requireState = (condition, message) => {
      if (!condition) f.violations.push(message);
      assert.ok(condition, message);
    };
    const media = {
      PlaybackSpeed: { SPEED_FORWARD_1_00_X: 1, SPEED_FORWARD_1_50_X: 1.5, SPEED_FORWARD_2_00_X: 2 },
      async createAVPlayer() {
        const playGate = f.playGates.shift(), releaseGate = f.playerReleaseGates.shift();
        const createGate = f.playerCreateGates.shift(), prepareGate = f.prepareGates.shift();
        const handlers = new Map();
        const player = {
          state: 'idle', stateVersion: 0, duration: 90000,
          on(event, handler) { if (!handlers.has(event)) handlers.set(event, new Set()); handlers.get(event).add(handler); },
          off(event, handler) { handlers.get(event)?.delete(handler); },
          emit(state) { this.state = state; this.stateVersion++; for (const fn of [...(handlers.get('stateChange') || [])]) fn(state); },
          tick(time = 4000) { for (const fn of [...(handlers.get('timeUpdate') || [])]) fn(time); },
          set fdSrc(value) { this.fd = value.fd; this.emit('initialized'); },
          async prepare() { requireState(this.state === 'initialized', 'prepare after initialized'); if (prepareGate) await prepareGate.promise; this.emit('prepared'); },
          async play() {
            requireState(['prepared', 'paused', 'completed'].includes(this.state), 'play after prepared');
            const stateVersion = this.stateVersion;
            if (playGate) await playGate.promise;
            // SDK state/events and Promise settlement are independent. A late
            // resolution cannot undo pause/completion or resurrect a released player.
            if (this.stateVersion === stateVersion) this.emit('playing');
          },
          async stop() { this.emit('stopped'); },
          async release() { if (releaseGate) await releaseGate.promise; this.emit('released'); },
          async pause() { this.emit('paused'); }, async seek(value) { f.seeks.push(value); },
          setSpeed(speed) { f.speeds.push(speed); }
        };
        f.players.push(player); if (createGate) await createGate.promise; return player;
      }
    };
    deps.MediaPlaybackController = load(controllerSource, 'MediaPlaybackController', {
      media,
      fs: {
        openSync(p) { const value = { fd: f.files.length + 1, path: p }; f.files.push(value); return value; },
        statSync: () => ({ size: 1024 }),
        closeSync(value) {
          requireState(f.files.includes(value) && !f.closed.includes(value.fd), 'close acquired fd exactly once');
          f.closed.push(value.fd);
        }
      },
      setTimeout: deps.setTimeout, clearTimeout: deps.clearTimeout
    });
  }
  const loaded = load(code, '{ globalMediaPlayback, mediaPlaybackUIState }', deps);
  f.global = loaded.globalMediaPlayback;
  f.ui = loaded.mediaPlaybackUIState;
  // Operation-only tests start with an explicitly pre-bound account boundary.
  // Do not run account bind/stop here: a stop-generation mutant would then
  // break setup instead of the named operation witness. Account integration
  // disables this boundary and exercises actual AppStore + page binding.
  if (bindTestAccount && typeof f.global.createPageHandle === 'function') {
    const owner = { createScope() { return this; }, isScopeCurrent: () => true,
      subscribeScopeInvalidation: () => () => {} };
    f.global.playbackAccount = owner;
    f.global.playbackScope = owner;
  }
  f.controller = f.global.controller;
  f.snapshots = [];
  f.global.setPageHandlers(value => f.snapshots.push({ ...value }));
  f.publish = (title = 'B', chat = -200, id = '20') => {
    f.global.setNowPlaying(title, 'artist', chat);
    f.controller.emit(id);
  };
  f.attach = async () => {
    f.global.attachAvSession({ abilityInfo: { bundleName: 'test', name: 'EntryAbility' } });
    await flush();
  };
  f.seed = () => f.publish('A', -100, '10');
  f.playReal = async (id = '10', title = 'A', cover = 0) => {
    f.global.setNowPlaying(title, 'artist', -100, '', cover);
    await f.controller.toggle(id, `/audio/${id}`, 'audio'); await flush();
  };
  f.fireTimers = async () => {
    const callbacks = [...f.timers.values()]; f.timers.clear();
    callbacks.forEach(fn => fn()); await flush();
  };
  return f;
}
const tests = new Map();
function test(name, run) { tests.set(name, run); }

for (const boundary of ['find', 'download']) {
  for (const replacement of ['stop', 'setNowPlaying']) {
    test(`${boundary}: ${replacement} invalidates late continuation`, async code => {
      const f = fixture(code); f.seed(); const pending = f.global.playNextAudio();
      if (boundary === 'download') { f.finds[0].resolve(track('11', '')); await flush(); }
      if (replacement === 'stop') await f.global.stop();
      else f.global.setNowPlaying('B', 'new artist', -200);
      if (boundary === 'find') f.finds[0].resolve(track('11', ''));
      else f.downloads[0].resolve('/late/audio');
      await flush();
      assert.equal(f.downloads.length, boundary === 'download' ? 1 : 0, 'stale find must not start download');
      assert.equal(await pending, false, 'superseded adjacent result must be false');
      assert.equal(f.toggles.length, 0, 'old track must not start');
      assert.equal(f.ui.title, replacement === 'stop' ? '' : 'B', 'metadata owner preserved');
    });
  }
}
test('local adjacent success uses exact anchor, direction and path', async code => {
  const f = fixture(code); f.seed(); const pending = f.global.playPrevAudio();
  assert.deepEqual(f.finds[0].args, [-100, '10', false]);
  f.finds[0].resolve(track('9')); assert.equal(await pending, true);
  assert.deepEqual(f.toggles, [['9', '/audio/9', 'audio']]);
  assert.equal(f.ui.title, 'track-9'); assert.equal(f.downloads.length, 0);
});
test('download success and speed reapplication stay live', async code => {
  const f = fixture(code); f.seed(); await f.global.cyclePlaybackSpeed(); f.speeds.length = 0;
  const pending = f.global.playNextAudio(); f.finds[0].resolve(track('11', '')); await flush();
  assert.deepEqual(f.downloads[0].args, [110]); f.downloads[0].resolve('/downloaded');
  assert.equal(await pending, true); assert.deepEqual(f.speeds, [1.5]);
  assert.deepEqual(f.toggles, [['11', '/downloaded', 'audio']]);
});
for (const empty of ['track', 'path']) {
  test(`empty ${empty} cannot start playback`, async code => {
    const f = fixture(code); f.seed(); const pending = f.global.playNextAudio();
    f.finds[0].resolve(empty === 'track' ? undefined : track('11', '')); await flush();
    if (empty === 'path') f.downloads[0].resolve('');
    assert.equal(await pending, false); assert.equal(f.toggles.length, 0);
  });
}
test('no active anchor performs no network call', async code => {
  const f = fixture(code); assert.equal(await f.global.playNextAudio(), false);
  assert.equal(f.finds.length, 0);
});
for (const first of ['old', 'new']) {
  test(`latest adjacent request wins when ${first} search resolves first`, async code => {
    const f = fixture(code); f.seed();
    const a = f.global.playNextAudio(); const b = f.global.playPrevAudio();
    const index = first === 'old' ? 0 : 1;
    f.finds[index].resolve(track(index ? '9' : '11')); await flush();
    f.finds[1 - index].resolve(track(index ? '11' : '9'));
    assert.equal(await a, false); assert.equal(await b, true);
    assert.deepEqual(f.toggles, [['9', '/audio/9', 'audio']]);
  });
}
test('new adjacent intent supersedes pending download', async code => {
  const f = fixture(code); f.seed(); const a = f.global.playNextAudio();
  f.finds[0].resolve(track('11', '')); await flush();
  const b = f.global.playPrevAudio(); f.finds[1].resolve(track('9')); await b;
  f.downloads[0].resolve('/stale'); assert.equal(await a, false);
  assert.deepEqual(f.toggles, [['9', '/audio/9', 'audio']]);
});
for (const replacement of ['stop', 'setNowPlaying']) {
  test(`cover: ${replacement} invalidates request before any new snapshot`, async code => {
    const f = fixture(code); f.global.setNowPlaying('A', 'artist', -100, '', 101);
    assert.deepEqual(f.covers[0].args, [101, 32]);
    if (replacement === 'stop') await f.global.stop();
    else f.global.setNowPlaying('B', 'artist', -200, '/cover/B');
    f.covers[0].resolve('/cover/A'); await flush();
    assert.equal(f.ui.coverPath, replacement === 'stop' ? '' : '/cover/B');
  });
}
test('cover remains valid across the intended first playback snapshot', async code => {
  const f = fixture(code); await f.attach();
  f.global.setNowPlaying('A', 'artist', -100, '', 101); f.controller.emit('10');
  f.covers[0].resolve('/cover/A'); await flush(); f.controller.emit('10');
  assert.equal(f.ui.coverPath, '/cover/A'); assert.equal(f.metadata.at(-1).mediaImage, 'file:///cover/A');
});
test('cover ABA: repeated message and file ids do not restore old metadata', async code => {
  const f = fixture(code); await f.attach(); f.seed();
  f.global.setNowPlaying('A', 'artist', -100, '', 101);
  await f.global.stop(); f.seed(); f.global.setNowPlaying('B', 'artist', -200, '', 101);
  f.covers[1].resolve('/cover/B'); await flush();
  f.covers[0].resolve('/cover/A'); await flush(); f.controller.emit('10');
  assert.equal(f.ui.coverPath, '/cover/B'); assert.equal(f.metadata.at(-1).title, 'B');
  assert.equal(f.metadata.at(-1).mediaImage, 'file:///cover/B');
});
test('empty or rejected cover leaves current metadata intact', async code => {
  const f = fixture(code); f.global.setNowPlaying('A', 'artist', -100, '', 101);
  f.covers[0].resolve(''); await flush(); assert.equal(f.ui.coverPath, '');
  f.global.setNowPlaying('B', 'artist', -100, '', 102);
  f.covers[1].reject(new Error('offline')); await flush(); assert.equal(f.ui.title, 'B');
});
for (const replacement of ['stop', 'setNowPlaying']) {
  test(`late toggle completion after ${replacement} cannot reapply speed`, async code => {
    const f = fixture(code); f.seed(); await f.global.cyclePlaybackSpeed(); f.speeds.length = 0;
    f.toggleGate = deferred(); const pending = f.global.playNextAudio();
    f.finds[0].resolve(track()); await flush(); assert.equal(f.toggles.length, 1);
    if (replacement === 'stop') await f.global.stop(); else f.publish();
    f.toggleGate.resolve(); assert.equal(await pending, false); assert.deepEqual(f.speeds, []);
  });
}
test('late release completion cannot stop newer playback background', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  f.releaseGate = deferred(); const pending = f.global.stop();
  f.publish(); await flush(); const stops = f.stopCalls;
  f.releaseGate.resolve(); await pending; await flush();
  assert.equal(f.stopCalls, stops, 'old stop continuation must not stop B'); assert.equal(f.active, true);
});
test('pending wantAgent cannot start background after stop', async code => {
  const f = fixture(code); await f.attach(); const want = deferred(); f.wantGates.push(want);
  f.seed(); await flush(); assert.equal(f.wantCalls, 1);
  await f.global.stop(); want.resolve(); await flush();
  assert.equal(f.startCalls, 0); assert.equal(f.active, false);
});
test('stop waits behind in-flight background start and leaves no task', async code => {
  const f = fixture(code); await f.attach(); const start = deferred(); f.startGates.push(start);
  f.seed(); await flush(); assert.equal(f.startCalls, 1);
  await f.global.stop(); await flush(); assert.equal(f.stopCalls, 0, 'SDK operations must not overlap');
  start.resolve(); await flush(); assert.equal(f.active, false); assert.equal(f.stopCalls, 1);
  assert.deepEqual(f.events, ['start', 'started', 'stop', 'stopped']);
});
test('new background start waits behind already issued stop', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  const stop = deferred(); f.stopGates.push(stop); await f.global.stop(); await flush();
  assert.equal(f.stopCalls, 1); f.publish(); await flush();
  assert.equal(f.startCalls, 1, 'new start must wait for old SDK stop');
  stop.resolve(); await flush(); assert.equal(f.startCalls, 2); assert.equal(f.active, true);
  assert.deepEqual(f.events, ['start', 'started', 'stop', 'stopped', 'start', 'started']);
});
test('pending old background start can transfer to newer playback', async code => {
  const f = fixture(code); await f.attach(); const start = deferred(); f.startGates.push(start);
  f.seed(); await flush(); await f.global.stop(); f.publish(); await flush();
  start.resolve(); await flush();
  assert.equal(f.active, true); assert.equal(f.startCalls, 1); assert.equal(f.stopCalls, 0);
});
test('failed old start does not suppress newer retry', async code => {
  const f = fixture(code); await f.attach(); const start = deferred(); f.startGates.push(start);
  f.seed(); await flush(); await f.global.stop(); f.publish(); await flush();
  start.reject(new Error('SDK start failed')); await flush();
  assert.equal(f.active, true); assert.equal(f.startCalls, 2);
  f.controller.emit('20'); await flush(); assert.equal(f.startCalls, 2, 'no duplicate start after retry');
});
test('a queued old linger callback cannot stop newer metadata owner', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  f.controller.emit('0', false); const timer = [...f.timers.values()][0]; assert.ok(timer);
  f.global.setNowPlaying('B', 'artist', -200); timer(); await flush();
  assert.equal(f.stopCalls, 0); assert.equal(f.active, true);
});
test('normal linger stops idle task; paused playback keeps background', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  await f.global.pauseCurrent(); await f.fireTimers(); assert.equal(f.active, true);
  f.controller.emit('0', false); await f.fireTimers(); assert.equal(f.active, false);
  assert.equal(f.stopCalls, 1);
});
test('normal stop releases background once and clears playback mirror', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  await f.global.stop(); await flush(); await f.global.stop(); await flush();
  assert.equal(f.active, false); assert.equal(f.stopCalls, 1); assert.equal(f.ui.hasActive, false);
  assert.equal(f.timers.size, 0);
});
test('stop queues cleanup even if newer metadata never reaches playing', async code => {
  const f = fixture(code); await f.attach(); const start = deferred(); f.startGates.push(start);
  f.seed(); await flush(); f.releaseGate = deferred(); const stopped = f.global.stop();
  f.global.setNowPlaying('B', 'artist', -200); f.controller.emit('0', false);
  start.resolve(); await flush(); f.releaseGate.resolve(); await stopped; await flush();
  await f.fireTimers();
  assert.equal(f.active, false, 'orphaned start must receive cleanup even after stop ownership changes');
});
test('queued linger stop is superseded by new startup with a bounded new grace period', async code => {
  const f = fixture(code); await f.attach(); const start = deferred(); f.startGates.push(start);
  f.seed(); await flush(); f.controller.emit('0', false); await f.fireTimers();
  f.global.setNowPlaying('B', 'artist', -200); f.controller.emit('0', false);
  start.resolve(); await flush();
  assert.equal(f.stopCalls, 0, 'old linger intent must not stop the new startup');
  assert.equal(f.active, true); assert.equal(f.timers.size, 1, 'failed startup must still have bounded cleanup');
  await f.fireTimers(); assert.equal(f.active, false);
});
test('same-generation canceled linger callback cannot stop active playback', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  f.controller.emit('0', false); const timer = [...f.timers.values()][0]; assert.ok(timer);
  f.controller.emit('10'); timer(); await flush();
  assert.equal(f.stopCalls, 0); assert.equal(f.active, true);
});

for (const replacement of ['stop', 'setNowPlaying']) {
  test(`local-path find: ${replacement} rejects stale track without download`, async code => {
    const f = fixture(code); f.seed(); const pending = f.global.playNextAudio();
    if (replacement === 'stop') await f.global.stop(); else f.global.setNowPlaying('B', 'artist', -200);
    f.finds[0].resolve(track()); assert.equal(await pending, false);
    assert.equal(f.toggles.length, 0); assert.equal(f.downloads.length, 0);
  });
}
test('rejected release still requests background cleanup', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  f.releaseGate = deferred(); const pending = f.global.stop();
  const rejected = assert.rejects(pending, /release failed/);
  f.releaseGate.reject(new Error('release failed')); await rejected; await flush();
  assert.equal(f.active, false); assert.equal(f.stopCalls, 1);
});
test('rejected old release does not stop new background owner', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  f.releaseGate = deferred(); const pending = f.global.stop();
  const rejected = assert.rejects(pending, /release failed/);
  f.publish(); await flush(); const stops = f.stopCalls;
  f.releaseGate.reject(new Error('release failed')); await rejected; await flush();
  assert.equal(f.active, true); assert.equal(f.stopCalls, stops);
});
test('SDK stop failure preserves confirmed active state and allows retry', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  f.releaseGate = deferred();
  const stop = deferred(); f.stopGates.push(stop); const stopped = f.global.stop(); await flush();
  stop.reject(new Error('stop rejected')); await flush(); assert.equal(f.active, true);
  f.releaseGate.resolve(); await stopped; await flush();
  assert.equal(f.active, false); assert.equal(f.stopCalls, 2);
});
test('completed linger does not start a background task for metadata alone', async code => {
  const f = fixture(code); await f.attach(); f.seed(); await flush();
  f.controller.emit('0', false); await f.fireTimers(); assert.equal(f.active, false);
  f.global.setNowPlaying('B', 'artist', -200); await flush();
  assert.equal(f.startCalls, 1); assert.equal(f.active, false);
});

test('integration: initial zero then delayed play accepts only current cover', async code => {
  const f = fixture(code, true); await f.attach();
  const play = deferred(); f.playGates.push(play);
  let settled = false;
  const pending = f.playReal('10', 'A', 101).then(() => { settled = true; });
  // Initial release emits zero synchronously, before prepare publishes ownership.
  assert.equal(f.ui.messageId, '0'); assert.equal(f.ui.hasActive, false);
  assert.equal(f.snapshots.at(-1).messageId, '0');
  await flush();
  assert.equal(f.ui.messageId, '10'); assert.equal(f.ui.hasActive, true); assert.equal(f.ui.isPlaying, false);
  assert.equal(f.snapshots.at(-1).path, '/audio/10'); assert.equal(f.snapshots.at(-1).isPlaying, false);
  assert.equal(f.startCalls, 0); assert.equal(f.players[0].state, 'prepared');
  f.covers[0].resolve('/cover/A'); await flush(); f.players[0].tick(0);
  assert.equal(f.ui.coverPath, '/cover/A'); assert.equal(f.metadata.at(-1).mediaImage, 'file:///cover/A');
  assert.equal(f.ui.isPlaying, false); assert.equal(settled, false);
  f.players[0].emit('playing'); await flush();
  assert.equal(f.ui.isPlaying, true); assert.equal(f.active, true); assert.equal(settled, false);
  play.resolve(); await pending; assert.equal(f.ui.messageId, '10'); assert.equal(f.ui.isPlaying, true);
  assert.equal(f.active, true); assert.deepEqual(f.violations, []);
});
test('integration: stop during actual play rejects adjacent and stale cover', async code => {
  const f = fixture(code, true); await f.attach(); await f.playReal();
  await f.global.cyclePlaybackSpeed(); f.speeds.length = 0;
  const play = deferred(); f.playGates.push(play);
  const snapshotStart = f.snapshots.length;
  const pending = f.global.playNextAudio(); f.finds[0].resolve({ ...track(), coverFileId: 101 }); await flush();
  assert.ok(f.snapshots.slice(snapshotStart).some(value => value.messageId === '0'), 'actual initial zero observed');
  assert.equal(f.ui.messageId, '11'); assert.equal(f.ui.hasActive, true); assert.equal(f.ui.isPlaying, false);
  assert.equal(f.players[1].state, 'prepared');
  f.players[1].emit('playing'); await flush(); assert.equal(f.ui.isPlaying, true);
  await f.global.stop(); assert.equal(f.players[1].state, 'released');
  play.resolve(); assert.equal(await pending, false); await flush();
  f.covers[0].resolve('/stale'); await flush();
  assert.equal(f.ui.messageId, '0'); assert.equal(f.ui.coverPath, ''); assert.equal(f.active, false);
  assert.equal(f.players[1].state, 'released'); assert.deepEqual(f.speeds, []);
  assert.deepEqual(f.closed.toSorted(), f.files.map(v => v.fd).toSorted()); assert.deepEqual(f.violations, []);
});
test('integration: newer actual track supersedes pending adjacent play', async code => {
  const f = fixture(code, true); await f.attach(); await f.playReal();
  await f.global.cyclePlaybackSpeed(); f.speeds.length = 0;
  const play = deferred(); f.playGates.push(play);
  const snapshotStart = f.snapshots.length;
  const pending = f.global.playNextAudio(); f.finds[0].resolve(track()); await flush();
  assert.ok(f.snapshots.slice(snapshotStart).some(value => value.messageId === '0'), 'actual initial zero observed');
  assert.equal(f.ui.messageId, '11'); assert.equal(f.ui.hasActive, true); assert.equal(f.ui.isPlaying, false);
  assert.equal(f.players[1].state, 'prepared'); await f.playReal('20', 'B');
  assert.equal(f.players[1].state, 'released');
  play.resolve(); assert.equal(await pending, false); await flush();
  assert.equal(f.ui.messageId, '20'); assert.equal(f.ui.title, 'B');
  assert.equal(f.players[1].state, 'released'); assert.equal(f.players[2].state, 'playing');
  assert.deepEqual(f.speeds, []); assert.equal(f.active, true); assert.deepEqual(f.violations, []);
});
test('integration: new metadata while actual old release waits keeps newer task alive', async code => {
  const f = fixture(code, true); await f.attach();
  const release = deferred(); f.playerReleaseGates.push(release); await f.playReal();
  const stopped = f.global.stop(); const started = f.playReal('20', 'B'); await flush();
  assert.equal(f.ui.messageId, '0'); assert.equal(f.players.length, 1, 'controller joins pending old cleanup');
  release.resolve(); await stopped; await started; await flush();
  assert.equal(f.ui.messageId, '20'); assert.equal(f.ui.title, 'B'); assert.equal(f.active, true);
  assert.deepEqual(f.violations, []);
});

async function bounded(body, timeoutMs = 1500) {
  let timer;
  try {
    return await Promise.race([body(), new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('test did not settle (not an ownership assertion)')), timeoutMs);
    })]);
  } finally { clearTimeout(timer); }
}

async function run(code, quiet = false) {
  const failures = [];
  for (const [name, body] of tests) {
    try { await bounded(() => body(code)); if (!quiet) console.log(`PASS ${name}`); }
    catch (error) { failures.push({ name, error }); if (!quiet) console.error(`FAIL ${name}\n${error.stack}`); }
  }
  return failures;
}
function replaceOnce(code, before, after) {
  assert.equal(code.split(before).length - 1, 1, 'mutation must engage exactly one source site');
  return code.replace(before, after);
}
const mutations = [
  ['setNowPlaying generation disabled', 'this.playbackGeneration++;', 'this.playbackGeneration += 0;',
    'local-path find: setNowPlaying rejects stale track without download'],
  ['stop generation disabled', 'const generation = ++this.playbackGeneration;', 'const generation = this.playbackGeneration;',
    'local-path find: stop rejects stale track without download'],
  ['adjacent request ordering disabled', 'const requestId = ++this.adjacentRequestId;', 'const requestId = this.adjacentRequestId;',
    'latest adjacent request wins when old search resolves first'],
  ['post-find guard removed',
    '    if (!this.isAdjacentCurrent(generation, requestId)) {\n      return false;\n    }', '',
    'find: stop invalidates late continuation'],
  ['post-download guard removed',
    'if (!this.isAdjacentCurrent(generation, requestId) || path.length === 0)', 'if (path.length === 0)',
    'download: setNowPlaying invalidates late continuation'],
  ['cover ownership removed', 'generation === this.playbackGeneration && this.metaCoverFileId === coverFileId', 'true',
    'cover ABA: repeated message and file ids do not restore old metadata'],
  ['post-toggle guard removed',
    '    if (!this.isAdjacentCurrent(committedGeneration, requestId)) {\n      return false;\n    }', '',
    'late toggle completion after stop cannot reapply speed'],
  ['late stop guard removed', 'if (generation === this.playbackGeneration) {', 'if (true) {',
    'late release completion cannot stop newer playback background'],
  ['background effects made concurrent', 'this.bgTaskQueue = this.bgTaskQueue.then(', 'this.bgTaskQueue = Promise.resolve().then(',
    'stop waits behind in-flight background start and leaves no task'],
  ['post-wantAgent guard removed',
    '      const agent = await wantAgent.getWantAgent(wantAgentInfo);\n      if (!this.bgTaskWanted) {\n        return;\n      }',
    '      const agent = await wantAgent.getWantAgent(wantAgentInfo);',
    'pending wantAgent cannot start background after stop'],
  ['linger generation guard removed',
    '        if (generation !== this.playbackGeneration || stopToken !== this.bgTaskStopToken) {\n          return;\n        }', '',
    'a queued old linger callback cannot stop newer metadata owner'],
  ['same-generation linger token removed',
    'generation !== this.playbackGeneration || stopToken !== this.bgTaskStopToken', 'generation !== this.playbackGeneration',
    'same-generation canceled linger callback cannot stop active playback'],
  ['immediate stop cleanup removed',
    '    this.stopBackgroundTaskNow();\n    try {\n      await this.controller.release();',
    '    this.bgTaskWanted = false;\n    try {\n      await this.controller.release();',
    'stop queues cleanup even if newer metadata never reaches playing'],
  ['new startup does not revoke queued linger', 'if (this.bgTaskLingerStop) {', 'if (false) {',
    'queued linger stop is superseded by new startup with a bounded new grace period']
];
if (require.main === module) (async () => {
  console.log(`GlobalMediaPlayback SHA256 ${hash(original)}`);
  console.log(`Actual controller integration SHA256 ${hash(controllerSource)}`);
  const baseline = process.argv.includes('--baseline-head');
  const code = baseline ? require('node:child_process').execFileSync('git',
    ['show', 'HEAD:entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets'], { cwd: root, encoding: 'utf8' })
    .replaceAll('\r\n', '\n') : source;
  if (baseline) console.log(`READ-ONLY HEAD baseline normalized SHA256 ${hash(code)}`);
  const failures = await run(code);
  console.log(`Global media ownership: ${tests.size - failures.length}/${tests.size} PASS`);
  if (!baseline && !failures.length) {
    await assert.rejects(bounded(() => new Promise(() => {}), 25), /test did not settle/);
    console.log('Harness deadline control: dangling Promise rejected (real keepalive timer)');
    for (const [name, before, after, witness] of mutations) {
      const rejected = await run(replaceOnce(code, before, after), true);
      assert.ok(rejected.some(value => value.name === witness), `${name}: expected witness must fail`);
      assert.ok(rejected.every(value => value.error.code === 'ERR_ASSERTION'), `${name}: failures must be behavioral, not harness errors`);
      console.log(`NEGATIVE CONTROL ${name}: ${rejected.length}/${tests.size} FAIL (expected)`);
    }
    console.log(`In-memory negative controls: ${mutations.length}/${mutations.length} rejected`);
  }
  assert.equal(fs.readFileSync(file, 'utf8'), original, 'tests must not mutate production source');
  if (failures.length) process.exitCode = 1;
})().catch(error => { console.error(error.stack); process.exitCode = 1; });
module.exports = { fixture, deferred, flush, load, track };
