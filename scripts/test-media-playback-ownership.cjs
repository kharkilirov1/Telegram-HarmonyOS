// Actual ETS controller, deterministic AVPlayer/filesystem/time boundaries only.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const sourcePath = path.join(__dirname, '../entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets');
const source = fs.readFileSync(sourcePath, 'utf8').replaceAll('\r\n', '\n');
const deferred = () => { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; };
async function flush() { for (let i = 0; i < 70; i++) await Promise.resolve(); }
let fixtures = [];
function fixture(code = source) {
  const f = { creates: [], files: [], closed: [], calls: [], states: [], completed: [], violations: [], timers: new Map(), players: [] };
  fixtures.push(f);
  const checked = fn => function (...args) {
    const record = e => { if (e.code === 'ERR_ASSERTION') f.violations.push(e.message); throw e; };
    try { const r = fn.apply(this, args); return r instanceof Promise ? r.catch(record) : r; } catch (e) { return record(e); }
  };
  let timer = 0;
  const fileIo = {
    openSync: checked(p => { const file = { fd: f.files.length + 1, path: p }; f.files.push(file); return file; }),
    statSync: () => { if (f.statFails) throw new Error('stat failure'); return { size: 1024 }; },
    closeSync: checked(file => {
      assert.ok(f.files.includes(file), 'close acquired FD'); assert.ok(!f.closed.includes(file.fd), 'close once');
      assert.ok(!f.players.some(p => p.fdSrc?.fd === file.fd && p.releases === 0), 'release before FD close');
      f.closed.push(file.fd); f.calls.push('close:' + file.fd);
    })
  };
  const media = { createAVPlayer: () => { const d = deferred(); f.creates.push(d); return d.promise; }, PlaybackSpeed: { SPEED_FORWARD_1_00_X: 1, SPEED_FORWARD_1_50_X: 1.5, SPEED_FORWARD_2_00_X: 2 } };
  const body = code.replace(/^import[^\n]*\n/gm, '').replace(/^export\s+/gm, '');
  const C = new Function('media', 'fs', 'setTimeout', 'clearTimeout', stripTypeScriptTypes(body, { mode: 'strip' }) + '\nreturn MediaPlaybackController;')(
    media, fileIo, fn => { f.timers.set(++timer, fn); return timer; }, id => f.timers.delete(id));
  f.controller = new C();
  f.controller.setListener(s => f.states.push(s));
  f.controller.setOnCompleted((id, type) => f.completed.push({ id, type }));
  f.snapshot = () => f.states.at(-1);
  f.player = (name, gates = {}) => {
    const listeners = new Map(); let fdSrc;
    const p = { name, state: 'idle', duration: 10000, prepares: 0, plays: 0, pauses: 0, stops: 0, releases: 0, seeks: [], speeds: [],
      on(event, fn) { if (!listeners.has(event)) listeners.set(event, new Set()); listeners.get(event).add(fn); },
      off(event, fn) { if (fn) listeners.get(event)?.delete(fn); else listeners.delete(event); },
      handlers(event) { return [...(listeners.get(event) || [])]; },
      emit(event, value) { if (event === 'stateChange') this.state = value; for (const fn of this.handlers(event)) fn(value); },
      get fdSrc() { return fdSrc; }, set fdSrc(value) { fdSrc = value; if (!gates.initialized) this.emit('stateChange', 'initialized'); },
      async prepare() { this.prepares++; assert.equal(this.state, 'initialized'); if (gates.prepare) await gates.prepare.promise; this.emit('stateChange', 'prepared'); },
      async play() {
        this.plays++; assert.ok(['prepared', 'paused', 'completed'].includes(this.state));
        if (gates.earlyPlaying) this.emit('stateChange', 'playing');
        if (gates.play) await gates.play.promise;
        if (this.state === 'released') throw new Error('released while play pending');
        if (!gates.earlyPlaying) this.emit('stateChange', 'playing');
      },
      async pause() { this.pauses++; if (gates.pause) await gates.pause.promise; this.emit('stateChange', 'paused'); },
      async seek(ms) { this.seeks.push(ms); if (gates.seek) await gates.seek.promise; },
      setSpeed(speed) { this.speeds.push(speed); },
      async stop() { this.stops++; assert.equal(this.stops, 1, 'stop once'); if (gates.stop) await gates.stop.promise; this.emit('stateChange', 'stopped'); },
      async release() { this.releases++; assert.equal(this.releases, 1, 'release once'); f.calls.push('release:' + name); if (gates.release) await gates.release.promise; this.emit('stateChange', 'released'); }
    };
    for (const key of ['prepare', 'play', 'pause', 'seek', 'stop', 'release']) p[key] = checked(p[key]);
    f.players.push(p); return p;
  };
  f.start = async (id = 'A', gates = {}, type = 'audio') => {
    const work = f.controller.play(id, '/' + id, type); await flush();
    const p = f.player(id, gates); f.creates.at(-1).resolve(p); await flush(); return { work, p };
  };
  return f;
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
test('normal audio plays exact FD and snapshot, seeks, pauses, resumes and releases', async code => {
  const f = fixture(code); const { work, p } = await f.start(); await work;
  assert.equal(f.snapshot().messageId, 'A'); assert.equal(f.snapshot().isPlaying, true); assert.equal(p.fdSrc.fd, 1);
  await f.controller.seekToProgress(0.5); assert.deepEqual(p.seeks, [5000]); assert.equal(f.snapshot().progress, 0.5);
  await f.controller.setPlaybackSpeed(1.5); assert.deepEqual(p.speeds, [1.5]);
  await f.controller.pause(); assert.equal(f.snapshot().isPlaying, false);
  await f.controller.toggle('A', '/A', 'audio'); assert.equal(p.plays, 2);
  await f.controller.release(); assert.equal(f.snapshot().messageId, '0'); assert.deepEqual(f.closed, [1]);
});
test('late create A cannot replace B and is released without opening A file', async code => {
  const f = fixture(code); const a = f.controller.play('A', '/A'); await flush(); const da = f.creates[0];
  const { work: b, p: pb } = await f.start('B'); await b;
  const pa = f.player('A'); da.resolve(pa); await a;
  assert.equal(f.snapshot().messageId, 'B'); assert.equal(pa.releases, 1); assert.equal(pa.prepares, 0);
  assert.equal(pb.releases, 0); assert.deepEqual(f.files.map(x => x.path), ['/B']);
});
test('stop during delayed create prevents resurrection', async code => {
  const f = fixture(code); const a = f.controller.play('A', '/A'); await flush(); await f.controller.release();
  const p = f.player('A'); f.creates[0].resolve(p); await a;
  assert.equal(p.plays, 0); assert.equal(p.releases, 1); assert.equal(f.snapshot().messageId, '0');
});
test('late prepare failure A cannot release B or escape as current failure', async code => {
  const f = fixture(code); const gate = deferred(); const { work: a, p: pa } = await f.start('A', { prepare: gate });
  const result = a.then(() => 'ok', () => 'error'); const { work: b, p: pb } = await f.start('B'); await b;
  gate.reject(new Error('late prepare')); assert.equal(await result, 'ok');
  assert.equal(f.snapshot().messageId, 'B'); assert.equal(pa.releases, 1); assert.equal(pb.releases, 0); assert.deepEqual(f.closed, [1]);
});
test('cancel while prepare pending waits until it settles before release', async code => {
  const f = fixture(code); const gate = deferred(); const { work, p } = await f.start('A', { prepare: gate });
  await f.controller.release(); assert.equal(p.releases, 0); gate.resolve(); await work;
  assert.equal(p.plays, 0); assert.equal(p.releases, 1); assert.deepEqual(f.closed, [1]); assert.equal(f.snapshot().messageId, '0');
});
test('late play completion after stop stays silent and frees its own FD', async code => {
  const f = fixture(code); const gate = deferred(); const { work, p } = await f.start('A', { play: gate });
  await f.controller.release(); gate.resolve(); await work;
  assert.equal(f.snapshot().messageId, '0'); assert.equal(f.snapshot().isPlaying, false); assert.equal(p.releases, 1); assert.deepEqual(f.closed, [1]);
});
test('stop during initialized wait cannot prepare stale player', async code => {
  const f = fixture(code); const { work, p } = await f.start('A', { initialized: true });
  await f.controller.release(); p.emit('stateChange', 'initialized'); await work;
  assert.equal(p.prepares, 0); assert.equal(p.plays, 0); assert.equal(p.releases, 1); assert.equal(f.timers.size, 0);
});
test('current stat failure releases acquired player and file and rejects', async code => {
  const f = fixture(code); f.statFails = true; const { work, p } = await f.start();
  await assert.rejects(work, /stat failure/); assert.equal(p.releases, 1); assert.deepEqual(f.closed, [1]); assert.equal(f.snapshot().messageId, '0');
});
test('old callback deliveries cannot publish B state or complete B', async code => {
  const f = fixture(code); const { work: a, p: pa } = await f.start('A'); await a;
  const states = pa.handlers('stateChange'), ticks = pa.handlers('timeUpdate');
  const { work: b } = await f.start('B'); await b; const before = f.states.length;
  for (const fn of states) fn('completed'); for (const fn of ticks) fn(9000);
  assert.equal(f.states.length, before); assert.deepEqual(f.completed, []); assert.equal(f.snapshot().messageId, 'B');
});
test('late pause completion cannot pause B UI', async code => {
  const f = fixture(code); const gate = deferred(); const { work: a } = await f.start('A', { pause: gate }); await a;
  const pause = f.controller.pause(); const { work: b } = await f.start('B'); await b;
  gate.resolve(); await pause; assert.equal(f.snapshot().messageId, 'B'); assert.equal(f.snapshot().isPlaying, true);
});
test('late seek completion cannot move B progress', async code => {
  const f = fixture(code); const gate = deferred(); const { work: a } = await f.start('A', { seek: gate }); await a;
  const seek = f.controller.seekToProgress(0.9); const { work: b } = await f.start('B'); await b;
  gate.resolve(); await seek; assert.equal(f.snapshot().messageId, 'B'); assert.equal(f.snapshot().progress, 0);
});
test('completed toggle delayed seek cannot play replacement B', async code => {
  const f = fixture(code); const gate = deferred(); const { work: a, p: pa } = await f.start('A', { seek: gate }); await a; pa.emit('stateChange', 'completed');
  const toggle = f.controller.toggle('A', '/A', 'audio'); const { work: b, p: pb } = await f.start('B'); await b;
  gate.resolve(); await toggle; assert.equal(pb.plays, 1); assert.equal(f.creates.length, 2); assert.equal(f.snapshot().messageId, 'B');
});
test('resume rejection after replacement cannot retry obsolete A', async code => {
  const f = fixture(code); const { work: a, p: pa } = await f.start('A'); await a; await f.controller.pause();
  const gate = deferred(); pa.play = () => gate.promise; const toggle = f.controller.toggle('A', '/A');
  const { work: b } = await f.start('B'); await b; gate.reject(new Error('late resume')); await flush();
  assert.equal(f.creates.length, 2, 'obsolete retry must not create another player'); await toggle;
});
test('concurrent release joins captured resources once and leaves FD open until release settles', async code => {
  const f = fixture(code); const gate = deferred(); const { work, p } = await f.start('A', { release: gate }); await work;
  let done1 = false, done2 = false; const r1 = f.controller.release().then(() => { done1 = true; }); await flush();
  const r2 = f.controller.release().then(() => { done2 = true; }); await flush();
  assert.equal(done1, false); assert.equal(done2, false); assert.deepEqual(f.closed, []); gate.resolve(); await Promise.all([r1, r2]);
  assert.equal(p.releases, 1); assert.equal(p.stops, 1); assert.deepEqual(f.closed, [1]);
});
test('two starts waiting for old stop create only latest requested player', async code => {
  const f = fixture(code); const gate = deferred(); const { work } = await f.start('A', { stop: gate }); await work;
  const b = f.controller.play('B', '/B'); const c = f.controller.play('C', '/C'); await flush(); gate.resolve(); await flush();
  assert.equal(f.creates.length, 2); f.creates[1].resolve(f.player('C')); await Promise.all([b, c]); assert.equal(f.snapshot().messageId, 'C');
});
test('voice completed callback and missing playing-event tick still work', async code => {
  const f = fixture(code); const { work, p } = await f.start('V', {}, 'voice'); await work;
  p.emit('stateChange', 'paused'); p.state = 'playing'; p.emit('timeUpdate', 4000);
  assert.equal(f.snapshot().isPlaying, true); assert.equal(f.snapshot().progress, 0.4);
  p.emit('stateChange', 'completed'); assert.deepEqual(f.completed, [{ id: 'V', type: 'voice' }]); assert.equal(f.snapshot().progress, 1);
});
test('failure cleanup finishing after B starts does not reject as current error', async code => {
  const f = fixture(code); const cleanup = deferred(); f.statFails = true;
  const { work: a } = await f.start('A', { release: cleanup }); const result = a.then(() => 'ok', () => 'error');
  f.statFails = false; const { work: b, p: pb } = await f.start('B'); await b; cleanup.resolve();
  assert.equal(await result, 'ok'); assert.equal(f.snapshot().messageId, 'B'); assert.equal(pb.releases, 0);
});
test('publication listener failure does not leave an active leaked player', async code => {
  const f = fixture(code);
  f.controller.setListener(s => { if (s.messageId === 'A') throw new Error('observer failure'); });
  const { work, p } = await f.start('A'); await assert.rejects(work, /observer failure/);
  assert.equal(f.controller.getActiveMessageId(), '0'); assert.equal(p.releases, 1); assert.deepEqual(f.closed, [1]);
});
test('release reaches already-playing startup before play Promise settles', async code => {
  const f = fixture(code); const gate = deferred(); const { work, p } = await f.start('V', { play: gate, earlyPlaying: true }, 'voice');
  let done = false; const release = f.controller.release().then(() => { done = true; }); await flush();
  const stoppedOrWaiting = !done || p.state !== 'playing'; gate.resolve(); await Promise.all([work, release]);
  assert.equal(stoppedOrWaiting, true, 'release must not finish while owned player is still playing');
  assert.equal(p.releases, 1); assert.deepEqual(f.closed, [1]);
});
test('pause reaches already-playing startup before play Promise settles', async code => {
  const f = fixture(code); const gate = deferred(); const { work, p } = await f.start('V', { play: gate, earlyPlaying: true }, 'voice');
  await f.controller.pause(); const state = p.state; gate.resolve(); await work;
  assert.equal(state, 'paused'); assert.equal(f.snapshot().isPlaying, false);
});
test('completion before play Promise settles is delivered once without progress reset', async code => {
  const f = fixture(code); const gate = deferred(); const { work, p } = await f.start('V', { play: gate, earlyPlaying: true }, 'voice');
  p.emit('timeUpdate', 10000); p.emit('stateChange', 'completed'); gate.resolve(); await work;
  assert.deepEqual(f.completed, [{ id: 'V', type: 'voice' }]); assert.equal(f.snapshot().progress, 1); assert.equal(f.snapshot().currentTimeMs, 10000);
});
test('completion listener stopping playback prevents stale auto-advance', async code => {
  const f = fixture(code); const { work, p } = await f.start('V'); await work;
  f.controller.setListener(s => { if (s.progress === 1) f.controller.release(); });
  p.emit('stateChange', 'completed'); await flush();
  assert.deepEqual(f.completed, []); assert.equal(f.controller.getActiveMessageId(), '0');
});
async function run(code = source, quiet = false) {
  let passed = 0, failed = 0;
  for (const t of tests) {
    fixtures = [];
    let deadline;
    try {
      await Promise.race([t.run(code), new Promise((_, reject) => {
        deadline = setTimeout(() => reject(new Error('test did not settle')), 1000);
      })]);
      for (const f of fixtures) assert.deepEqual(f.violations, [], 'SDK assertions must not be swallowed');
      passed++; if (!quiet) console.log('PASS ' + t.name);
    }
    catch (e) { failed++; if (!quiet) console.error('FAIL ' + t.name + '\n' + e.stack); }
    finally { clearTimeout(deadline); }
  }
  if (!quiet) console.log('playback ownership: ' + passed + ' passed, ' + failed + ' failed');
  return { passed, failed };
}
async function main() {
  const result = await run();
  if (result.failed) { process.exitCode = 1; return; }
  if (!process.argv.includes('--negative-controls')) return;
  const controls = [
    ['startup generation ignored', s => s.replace(/if \(operationId !== this.operationId\) \{\s*return;\s*\}/g, '')],
    ['stale callback ownership ignored', s => s.replaceAll('if (this.resources === resources) this.', 'this.')],
    ['late command ownership ignored', s => s.replace(/if \(this.resources !== resources\) \{\s*return;\s*\}/g, '')],
    ['cleanup captures replacement FD', s => s.replace('const openedFile = resources.openedFile;', 'const openedFile = this.resources?.openedFile;')],
    ['concurrent release no longer joins', s => s.replace('const pending = previous ? previous.then(() => current) : current;', 'const pending = current;')],
    ['late error escapes', s => s.replace('if (startupError && operationId === this.operationId)', 'if (startupError)')],
    ['unpublished startup leaks', s => s.replace('await this.releaseResources(resources);\n      }\n    }', '/* missing local cleanup */\n      }\n    }')],
    ['ownership published only after play settles', s => {
      const start = s.indexOf('      this.resources = resources;');
      const publicationEnd = s.indexOf('      // Publication callbacks', start);
      const end = s.indexOf('    } catch (error)', publicationEnd);
      assert.ok(start > 0 && publicationEnd > start && end > publicationEnd);
      const publication = s.slice(start, publicationEnd).replace('this.isPlaying = false;', "this.isPlaying = player.state === 'playing';");
      return s.slice(0, start) + '      await player.play();\n      if (operationId !== this.operationId) return;\n' + publication + s.slice(end);
    }]
  ];
  let survived = 0;
  for (const [name, change] of controls) {
    const mutated = change(source); assert.notEqual(mutated, source, 'mutation must engage: ' + name);
    const r = await run(mutated, true);
    if (!r.failed) survived++;
    console.log((r.failed ? 'REJECTED ' : 'SURVIVED ') + name + ': ' + r.failed + ' failing cases');
  }
  console.log('playback negative controls: ' + (controls.length - survived) + ' rejected, ' + survived + ' survived');
  process.exitCode = survived ? 1 : 0;
}
if (require.main === module) main().catch(e => { console.error(e); process.exitCode = 1; });
module.exports = { run, fixture, deferred, flush };
