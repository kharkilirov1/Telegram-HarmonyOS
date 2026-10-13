// Node >=24. Executes the actual ETS controller and duration policy, not a copy.
// Only SDK, filesystem, clock/timer and send/presentation boundaries are fakes.
// Exit 0 = corrected behavior; historical media_races.cjs used the opposite oracle.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const controllerPath = 'entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets';
const policyPath = 'entry/src/main/ets/ui/tg_ui/utils/TgVoiceRecordingPolicy.ets';
const source = fs.readFileSync(path.join(root, controllerPath), 'utf8').replaceAll('\r\n', '\n');
const policySource = fs.readFileSync(path.join(root, policyPath), 'utf8');
function load(code, name, deps = {}) {
  const body = code.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(body, { mode: 'strip' }) +
    `\nreturn ${name};`)(...Object.values(deps));
}
const sendable = load(policySource, 'isVoiceRecordingDurationSendable');
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
// Drain finite promise chains without wall-clock sleeps or real microphone access.
async function flush() { for (let i = 0; i < 60; i++) await Promise.resolve(); }

let fixtures = [];
function fixture(code = source) {
  const f = {
    now: 100000, lifecycle: 1, chat: -100, allowed: true, dispatchAllowed: true,
    creates: [], files: [], closed: [], deleted: [], paths: new Set(),
    states: [], toasts: [], logs: [], calls: [], sends: [], timers: new Map(),
    clearReply: 0, scrolls: 0, permission: undefined, send: undefined, violations: []
  };
  fixtures.push(f);
  // Controller catches SDK errors by design. Do not let it hide a broken fake
  // lifecycle/FD assertion and make the test accidentally green.
  function boundary(fn) {
    function record(error) {
      if (error.code === 'ERR_ASSERTION') f.violations.push(error.message);
      throw error;
    }
    return function (...args) {
      try {
        const value = fn.apply(this, args);
        return value instanceof Promise ? value.catch(record) : value;
      } catch (error) { return record(error); }
    };
  }
  const fileIo = {
    OpenMode: { READ_WRITE: 1, CREATE: 2, TRUNC: 4 },
    accessSync: p => p === '/files/composer_voice' || f.paths.has(p),
    mkdirSync() {},
    openSync(p) {
      const file = { fd: f.files.length + 1, path: p };
      f.files.push(file); f.paths.add(p); return file;
    },
    closeSync(file) {
      assert.ok(f.files.includes(file), 'close must use an acquired file');
      assert.ok(!f.closed.includes(file.fd), 'double close');
      f.closed.push(file.fd); f.calls.push(`close:${file.fd}`);
    },
    unlinkSync(p) {
      assert.ok(f.paths.delete(p), 'unlink must target an existing owned path');
      f.deleted.push(p); f.calls.push(`unlink:${p}`);
    }
  };
  for (const name of ['openSync', 'closeSync', 'unlinkSync']) fileIo[name] = boundary(fileIo[name]);
  const log = (...args) => f.logs.push(args.join(' '));
  let timer = 0;
  const Controller = load(code, 'ChatVoiceRecordingController', {
    abilityAccessCtrl: { createAtManager: () => ({ requestPermissionsFromUser: () =>
      f.permission ? f.permission.promise : Promise.resolve({ authResults: [0] }) }) },
    fileIo,
    media: {
      createAVRecorder() { const d = deferred(); f.creates.push(d); return d.promise; },
      CodecMimeType: { AUDIO_AAC: 1 }, ContainerFormatType: { CFT_MPEG_4A: 1 },
      AudioSourceType: { AUDIO_SOURCE_TYPE_MIC: 1 }
    },
    hilog: { info: log, warn: log, error: log },
    localized: (_id, fallback) => fallback, $r: id => ({ id }),
    isVoiceRecordingDurationSendable: sendable, SendMediaMessageParams: class {},
    Date: { now: () => f.now },
    setInterval(fn) { f.timers.set(++timer, fn); return timer; },
    clearInterval(id) { f.timers.delete(id); }
  });
  const useCase = { execute(params) {
    f.sends.push(params); return f.send ? f.send.promise : Promise.resolve();
  } };
  f.host = {
    canSendNewMessages: () => f.allowed && f.dispatchAllowed,
    getActiveChatId: () => f.chat, getLifecycleToken: () => f.lifecycle,
    getChatUIContext: () => ({ getHostContext: () => ({ filesDir: '/files' }),
      getPromptAction: () => ({ showToast: value => f.toasts.push(value.message) }) }),
    getSendMediaUseCase(kind) {
      assert.equal(kind, 'voice', 'preserve existing per-kind permission guard');
      return f.allowed ? useCase : undefined;
    },
    getReplyToMessageId: () => '17', clearReplyMode() { f.clearReply++; },
    isNearBottom: () => true, scrollToBottomSoon() { f.scrolls++; },
    setVoiceRecordingState(state, duration) { f.states.push({ state, duration }); }
  };
  f.controller = new Controller();
  f.state = () => f.states.at(-1)?.state;
  f.recorder = (id, gates = {}) => {
    const recorder = {
    state: 'idle', prepared: [], starts: 0, stops: 0, releases: 0, busy: false,
    async prepare(config) {
      assert.equal(this.state, 'idle'); this.prepared.push(config.url);
      const fd = Number(config.url.slice(5));
      assert.ok(f.files.some(file => file.fd === fd) && !f.closed.includes(fd), 'prepare requires open FD');
      this.busy = true;
      try { if (gates.prepare) await gates.prepare.promise; this.state = 'prepared'; }
      finally { this.busy = false; }
    },
    async start() {
      assert.equal(this.state, 'prepared'); this.starts++; this.busy = true;
      try { if (gates.start) await gates.start.promise; this.state = 'started'; }
      finally { this.busy = false; }
    },
    async stop() {
      assert.ok(['started', 'paused'].includes(this.state)); this.stops++;
      f.calls.push(`stop:${id}`);
      if (gates.stop) await gates.stop.promise;
      this.state = 'stopped';
    },
    async release() {
      assert.equal(this.busy, false, 'must not release during prepare/start');
      assert.notEqual(this.state, 'released'); this.releases++;
      f.calls.push(`release:${id}`);
      if (gates.release) await gates.release.promise;
      this.state = 'released'; f.calls.push(`released:${id}`);
    }
    };
    for (const name of ['prepare', 'start', 'stop', 'release']) recorder[name] = boundary(recorder[name]);
    return recorder;
  };
  f.begin = async () => { f.controller.begin(f.host); await flush(); };
  f.start = async (id, gates) => {
    await f.begin(); const r = f.recorder(id, gates);
    f.creates.at(-1).resolve(r); await flush(); return r;
  };
  f.cancel = async () => { f.controller.cancel(f.host); await flush(); };
  f.dispose = async () => { f.controller.dispose(); await flush(); };
  f.assertClean = () => {
    assert.deepEqual([...f.closed].sort(), f.files.map(x => x.fd).sort(), 'every acquired FD closed once');
    assert.equal(f.paths.size, 0, 'every abandoned path deleted');
    assert.equal(f.timers.size, 0, 'no abandoned timer');
  };
  return f;
}

const tests = new Map();
function test(name, run) { tests.set(name, run); }

test('late create A cannot replace or clean active B', async code => {
  const f = fixture(code);
  await f.begin(); await f.cancel();
  f.now++; // isolate ownership race from the separate same-millisecond path test
  const b = await f.start('B');
  assert.equal(f.state(), 'recording');
  const fileB = f.files[1], events = f.states.length;
  const a = f.recorder('A'); f.creates[0].resolve(a); await flush();
  assert.ok(!f.closed.includes(fileB.fd), 'late A closed B FD');
  assert.ok(f.paths.has(fileB.path), 'late A deleted B path');
  assert.equal(a.prepared.length, 0, 'stale create must never prepare');
  assert.equal(a.releases, 1); assert.equal(b.releases, 0);
  assert.equal(f.states.length, events, 'late A changed B UI');
  assert.equal(f.timers.size, 1, 'late A stopped B timer');
  f.now += 750; for (const tick of f.timers.values()) tick();
  assert.equal(f.states.at(-1).duration, 750, 'B timer remains live');
  await f.dispose(); assert.equal(b.releases, 1, 'dispose must still own B'); f.assertClean();
});

test('prepare failure retains FD/path until deferred release completes', async code => {
  const f = fixture(code), prepare = deferred(), release = deferred();
  const a = await f.start('A', { prepare, release });
  prepare.reject(new Error('prepare failure')); await flush();
  assert.equal(a.releases, 1, 'failure must start cleanup');
  assert.deepEqual(f.closed, [], 'FD must remain open during release');
  release.resolve(); await flush();
  f.assertClean(); assert.equal(f.state(), 'idle');
  assert.equal(f.toasts.length, 1); assert.equal(f.sends.length, 0);
  assert.ok(f.calls.indexOf('released:A') < f.calls.indexOf('close:1'));
});

test('failure cleanup does not publish idle before release', async code => {
  const f = fixture(code), prepare = deferred(), release = deferred();
  await f.start('A', { prepare, release });
  prepare.reject(new Error('prepare failure')); await flush();
  await f.begin(); assert.equal(f.creates.length, 1, 'retry admitted before failure cleanup finished');
  release.resolve(); await flush();
  const b = await f.start('B'); assert.equal(b.state, 'started'); await f.dispose(); f.assertClean();
});

for (const phase of ['prepare', 'start']) {
  test(`cancel during ${phase} leaves cleanup local to A`, async code => {
    const f = fixture(code), gate = deferred();
    const a = await f.start('A', { [phase]: gate });
    await f.cancel(); f.now++;
    const b = await f.start('B'), events = f.states.length;
    gate.resolve(); await flush();
    assert.equal(a.releases, 1); assert.equal(b.releases, 0);
    if (phase === 'prepare') assert.equal(a.starts, 0);
    assert.ok(!f.closed.includes(f.files[1].fd));
    assert.equal(f.states.length, events); assert.equal(f.timers.size, 1);
    await f.dispose(); assert.equal(b.releases, 1); f.assertClean();
  });
}

test('dispose during create releases late result without starting', async code => {
  const f = fixture(code); await f.begin(); await f.dispose();
  const a = f.recorder('A'); f.creates[0].resolve(a); await flush();
  assert.equal(a.prepared.length, 0); assert.equal(a.releases, 1); f.assertClean();
});

test('late create rejection after cancel is silent and cleans only A', async code => {
  const f = fixture(code); await f.begin(); await f.cancel(); f.now++;
  const b = await f.start('B'), events = f.states.length;
  f.creates[0].reject(new Error('late create failure')); await flush();
  assert.equal(f.toasts.length, 0); assert.equal(f.states.length, events);
  assert.ok(!f.closed.includes(f.files[1].fd));
  await f.dispose(); assert.equal(b.releases, 1); f.assertClean();
});

test('late cleanup after dispose cannot close replacement B', async code => {
  const f = fixture(code), release = deferred();
  const a = await f.start('A', { release });
  await f.dispose(); f.now++;
  const b = await f.start('B'), events = f.states.length;
  release.resolve(); await flush();
  assert.equal(a.releases, 1); assert.equal(f.states.length, events);
  assert.ok(!f.closed.includes(f.files[1].fd)); assert.ok(f.paths.has(f.files[1].path));
  await f.dispose(); assert.equal(b.releases, 1); f.assertClean();
});

test('same millisecond retry gets a distinct output path', async code => {
  const f = fixture(code); await f.begin(); await f.cancel();
  await f.begin(); assert.notEqual(f.files[0].path, f.files[1].path, 'A/B path collision');
  const a = f.recorder('A'), b = f.recorder('B');
  f.creates[1].resolve(b); f.creates[0].resolve(a); await flush();
  await f.dispose(); f.assertClean();
});

test('two controllers with the same clock cannot delete each other output', async code => {
  const f = fixture(code), a = await f.start('A');
  // Same loaded production module and filesystem, but a second real controller
  // as on retained pages. Both first operations have token=1, Date.now is frozen.
  const other = new f.controller.constructor();
  const statesB = [];
  const hostB = { ...f.host, setVoiceRecordingState: state => statesB.push(state) };
  other.begin(hostB); await flush();
  assert.equal(f.creates.length, 2);
  const b = f.recorder('B'); f.creates[1].resolve(b); await flush();
  assert.equal(statesB.at(-1), 'recording'); assert.equal(f.timers.size, 2);
  const pathB = f.files[1].path;
  await f.cancel();
  assert.ok(f.paths.has(pathB), 'A cleanup deleted B path across controllers');
  assert.notEqual(f.files[0].path, pathB, 'controllers reused one output path');
  assert.ok(!f.closed.includes(f.files[1].fd));
  assert.equal(a.releases, 1); assert.equal(b.releases, 0); assert.equal(f.timers.size, 1);
  other.dispose(); await flush(); assert.equal(b.releases, 1); f.assertClean();
});

test('permission completion after cancel creates no resources', async code => {
  const f = fixture(code); f.permission = deferred(); await f.begin(); await f.cancel();
  f.permission.resolve({ authResults: [0] }); await flush();
  assert.equal(f.creates.length, 0); assert.equal(f.files.length, 0); f.assertClean();
});

test('route invalidation during prepare cleans without starting or UI completion', async code => {
  const f = fixture(code), prepare = deferred();
  const a = await f.start('A', { prepare }), events = f.states.length;
  f.lifecycle++; prepare.resolve(); await flush();
  assert.equal(a.starts, 0); assert.equal(a.releases, 1);
  assert.equal(f.states.length, events); f.assertClean();
});

test('cancel and dispose join in-flight stop/release once', async code => {
  const f = fixture(code), stop = deferred();
  const a = await f.start('A', { stop }); f.now += 800;
  f.controller.finishAndSend(f.host); await flush();
  await f.cancel(); await f.cancel(); await f.dispose();
  assert.deepEqual(f.closed, [], 'FD closed before stop/release completion');
  assert.deepEqual(f.deleted, [], 'path deleted before stop/release completion');
  stop.resolve(); await flush();
  assert.equal(a.stops, 1); assert.equal(a.releases, 1); assert.equal(f.sends.length, 0); f.assertClean();
});

test('short recording is closed and deleted, never sent', async code => {
  const f = fixture(code), a = await f.start('A'); f.now += 499;
  f.controller.finishAndSend(f.host); await flush();
  assert.equal(a.stops, 1); assert.equal(a.releases, 1);
  assert.equal(f.sends.length, 0); assert.equal(f.state(), 'idle'); f.assertClean();
});

test('successful locked recording sends owned path and preserves uploaded file', async code => {
  const f = fixture(code), a = await f.start('A');
  f.controller.lock(f.host); assert.equal(f.state(), 'locked'); f.now += 1250;
  f.controller.finishAndSend(f.host); await flush();
  assert.equal(a.stops, 1); assert.equal(a.releases, 1);
  assert.equal(f.sends.length, 1); assert.equal(f.sends[0].localPath, f.files[0].path);
  assert.equal(f.sends[0].durationSeconds, 2); assert.equal(f.sends[0].chatId, -100);
  assert.equal(f.sends[0].replyToMessageId, '17'); assert.deepEqual(f.closed, [1]);
  assert.equal(f.deleted.length, 0); assert.equal(f.clearReply, 1); assert.equal(f.scrolls, 1);
  assert.equal(f.state(), 'idle'); await f.dispose(); assert.equal(f.deleted.length, 0);
});

test('voice permission guard still blocks acquisition', async code => {
  const f = fixture(code); f.allowed = false; await f.begin();
  assert.equal(f.files.length, 0); assert.equal(f.creates.length, 0);
});

test('lock queued during create applies only to that recording', async code => {
  const f = fixture(code); await f.begin(); f.controller.lock(f.host);
  const a = f.recorder('A'); f.creates[0].resolve(a); await flush();
  assert.equal(f.state(), 'locked'); await f.cancel(); f.assertClean();
});

test('send queued during create resolves short recording without leak', async code => {
  const f = fixture(code); await f.begin(); f.controller.finishAndSend(f.host);
  const a = f.recorder('A'); f.creates[0].resolve(a); await flush();
  assert.equal(f.state(), 'idle'); assert.equal(f.sends.length, 0);
  assert.equal(a.releases, 1); f.assertClean();
});

for (const phase of ['prepare', 'start']) {
  test(`late ${phase} failure after cancel cannot reset B`, async code => {
    const f = fixture(code), gate = deferred();
    const a = await f.start('A', { [phase]: gate }); await f.cancel(); f.now++;
    const b = await f.start('B'), events = f.states.length;
    gate.reject(new Error(`late ${phase} failure`)); await flush();
    assert.equal(a.releases, 1); assert.equal(b.releases, 0);
    assert.equal(f.states.length, events); assert.equal(f.toasts.length, 0);
    assert.ok(!f.closed.includes(f.files[1].fd)); await f.dispose(); f.assertClean();
  });
}

test('send failure deletes only its own completed recording', async code => {
  const f = fixture(code); f.send = deferred(); await f.start('A'); f.now += 750;
  f.controller.finishAndSend(f.host); await flush();
  assert.equal(f.sends.length, 1); f.send.reject(new Error('send failure')); await flush();
  assert.equal(f.state(), 'idle'); assert.equal(f.clearReply, 0); f.assertClean();
});

test('late send completion after cancel cannot reset B', async code => {
  const f = fixture(code); f.send = deferred(); await f.start('A'); f.now += 750;
  f.controller.finishAndSend(f.host); await flush();
  assert.equal(f.sends.length, 1); await f.cancel(); f.now++;
  const b = await f.start('B'), events = f.states.length;
  f.send.resolve(); await flush();
  assert.equal(f.states.length, events); assert.equal(f.clearReply, 0); assert.equal(b.releases, 0);
  await f.dispose(); f.assertClean();
});

async function runCase(run, code) {
  fixtures = [];
  await run(code);
  for (const f of fixtures) assert.deepEqual(f.violations, [], 'SDK assertions were swallowed by production catches');
}

function replaceOnce(code, before, after) {
  assert.equal(code.split(before).length, 2, `mutation anchor must occur exactly once: ${before}`);
  return code.replace(before, after);
}

async function negativeControls() {
  const mutations = [
    ['stale create guard removed', 'late create A cannot replace or clean active B',
      '      resources.recorder = recorder;\n      if (!this.isActive(host, token)) {\n        return;\n      }',
      '      resources.recorder = recorder;', /stale create must never prepare/],
    ['cleanup reads current bundle', 'late cleanup after dispose cannot close replacement B',
      '    const outputFile = resources.outputFile;',
      '    const outputFile = this.resources?.outputFile;', /every acquired FD closed once/],
    ['FD capture dropped', 'prepare failure retains FD/path until deferred release completes',
      '    const outputFile = resources.outputFile;', '    const outputFile = undefined;', /every acquired FD closed once/],
    ['path erased before release', 'prepare failure retains FD/path until deferred release completes',
      '    await resources.releasePromise;', "    resources.outputPath = '';\n    await resources.releasePromise;", /every abandoned path deleted/],
    ['stale cleanup stops shared timer', 'late create A cannot replace or clean active B',
      '    await resources.releasePromise;', '    this.stopTimer();\n    await resources.releasePromise;', /late A stopped B timer/],
    ['cleanup join removed', 'cancel and dispose join in-flight stop/release once',
      '    if (resources.releasePromise === undefined) {', '    if (true) {', /path deleted before stop\/release completion/],
    ['path unique suffix removed', 'same millisecond retry gets a distinct output path',
      'tg_voice_${Date.now()}_${++voiceOutputSequence}.m4a', 'tg_voice_${Date.now()}.m4a', /A\/B path collision/],
    ['path suffix reverted to controller-local token', 'two controllers with the same clock cannot delete each other output',
      'tg_voice_${Date.now()}_${++voiceOutputSequence}.m4a', 'tg_voice_${Date.now()}_${token}.m4a',
      /A cleanup deleted B path across controllers/]
  ];
  for (const [name, testName, before, after, expected] of mutations) {
    const mutated = replaceOnce(source, before, after);
    await assert.rejects(() => runCase(tests.get(testName), mutated), expected,
      `negative control survived: ${name}`);
    console.log(`REJECTED negative control: ${name}`);
  }
  console.log(`negative controls: ${mutations.length} rejected, 0 survived (in memory only)`);
}

async function main() {
  console.log(`controller SHA256 ${createHash('sha256').update(source).digest('hex')} (LF-normalized)`);
  let passed = 0, failed = 0;
  for (const [name, run] of tests) {
    try { await runCase(run, source); passed++; console.log(`PASS ${name}`); }
    catch (error) { failed++; console.error(`FAIL ${name}\n${error.stack}`); }
  }
  console.log(`voice ownership: ${passed} passed, ${failed} failed`);
  if (failed) process.exitCode = 1;
  else if (process.argv.includes('--negative-controls')) await negativeControls();
}
module.exports = { fixture, deferred, flush, runCase, source };
if (require.main === module) main().catch(error => { console.error(error); process.exitCode = 1; });
