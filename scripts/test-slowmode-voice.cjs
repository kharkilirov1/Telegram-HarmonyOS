// Actual public voice controller; SDK recorder/permission/files are controlled.
// Dispatch policy and stable media capability are intentionally separate.
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { fixture, deferred, flush, runCase } = require('./test-voice-recording-ownership.cjs');
const args = process.argv.slice(2), value = flag => args[args.indexOf(flag) + 1];
const root = args.includes('--baseline-dir') ? path.resolve(value('--baseline-dir')) : path.resolve(__dirname, '..');
const output = args.includes('--json') ? path.resolve(value('--json')) : undefined;
const controllerPath = path.join(root, 'entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets');
const source = fs.readFileSync(controllerPath, 'utf8').replaceAll('\r\n', '\n');
let executableSource = source;
const mutant = args.includes('--mutant-preview-discard');
if (mutant) {
  const before = "this.setState(host, 'preview', this.durationMs);";
  assert.equal(source.split(before).length, 2, 'Preview mutation route must exist exactly once');
  executableSource = source.replace(before, "this.deleteOutputFile(resources); this.resetFields(); this.setState(host, 'idle', 0);");
}
const tests = new Map();
for (const phase of ['permission', 'create', 'prepare', 'start']) tests.set('cooldown during ' + phase + ' prevents recording startup and cleans only acquired resources', async code => {
  const f = fixture(code), gate = deferred();
  if (phase === 'permission') {
    f.permission = gate; await f.begin(); f.dispatchAllowed = false;
    gate.resolve({ authResults: [0] }); await flush();
    assert.equal(f.creates.length, 0, 'cooldown after permission must prevent AVRecorder acquisition');
  } else if (phase === 'create') {
    await f.begin(); f.dispatchAllowed = false;
    const recorder = f.recorder('A'); f.creates[0].resolve(recorder); await flush();
    assert.equal(recorder.prepared.length, 0, 'cooldown after create must prevent prepare');
    assert.equal(recorder.releases, 1);
  } else {
    const recorder = await f.start('A', { [phase]: gate }); f.dispatchAllowed = false;
    gate.resolve(); await flush();
    if (phase === 'prepare') assert.equal(recorder.starts, 0, 'cooldown after prepare must prevent start');
    assert.equal(recorder.releases, 1);
  }
  assert.equal(f.state(), 'idle', 'owned canceled startup must return the UI to idle');
  assert.equal(f.sends.length, 0); f.assertClean();
});
tests.set('cooldown arriving during stop retains a closed playable preview until an explicit manual send', async code => {
  const f = fixture(code), stop = deferred(), recorder = await f.start('A', { stop }); f.now += 750;
  f.controller.finishAndSend(f.host); await flush(); f.dispatchAllowed = false; stop.resolve(); await flush();
  assert.equal(f.state(), 'preview'); assert.equal(f.sends.length, 0); assert.equal(f.paths.size, 1);
  assert.equal(f.closed.length, 1); assert.equal(recorder.releases, 1); assert.equal(f.clearReply, 0);
  f.controller.finishAndSend(f.host); await flush(); assert.equal(f.state(), 'preview'); assert.equal(f.sends.length, 0);
  f.dispatchAllowed = true; await flush(); assert.equal(f.sends.length, 0, 'expiry never auto-sends preview');
  f.controller.finishAndSend(f.host); await flush(); assert.equal(f.sends.length, 1); assert.equal(f.state(), 'idle');
  assert.equal(f.sends[0].localPath, f.files[0].path); assert.equal(f.sends[0].replyToMessageId, '17');
  assert.equal(recorder.stops, 1); assert.equal(recorder.releases, 1);
  // Accepted file belongs to transport; disposal must not delete it.
  const deleted = f.deleted.length; await f.dispose(); assert.equal(f.deleted.length, deleted);
});
tests.set('cancel retained cooldown preview deletes its exact unsent file once', async code => {
  const f = fixture(code); await f.start('A'); f.now += 750; f.dispatchAllowed = false;
  f.controller.finishAndSend(f.host); await flush(); assert.equal(f.state(), 'preview'); assert.equal(f.paths.size, 1);
  await f.cancel(); assert.equal(f.state(), 'idle'); assert.equal(f.sends.length, 0); f.assertClean();
  assert.equal(f.deleted.length, 1); assert.equal(f.deleted[0], f.files[0].path);
});
for (const action of ['finish', 'cancel']) tests.set('rights revoked after recording: ' + action + ' restores owned idle without a stuck sending state', async code => {
  const f = fixture(code); await f.start('A'); f.now += 750; f.allowed = false;
  if (action === 'finish') f.controller.finishAndSend(f.host); else f.controller.cancel(f.host);
  await flush(); assert.equal(f.state(), 'idle'); assert.equal(f.sends.length, 0); f.assertClean();
});
tests.set('rights revocation during preparation cleans its bundle and owned UI', async code => {
  const f = fixture(code), gate = deferred(), recorder = await f.start('A', { prepare: gate });
  f.allowed = false; gate.resolve(); await flush(); assert.equal(f.state(), 'idle');
  assert.equal(recorder.starts, 0); assert.equal(f.sends.length, 0); f.assertClean();
});
tests.set('account lifecycle replacement during stopped preview never resets replacement UI', async code => {
  const f = fixture(code), stop = deferred(); await f.start('A', { stop }); f.now += 750;
  f.controller.finishAndSend(f.host); await flush(); f.lifecycle++; f.chat = -200;
  const states = f.states.length; stop.resolve(); await flush(); assert.equal(f.states.length, states);
  assert.equal(f.sends.length, 0); f.assertClean();
});
async function main() {
  let passed = 0; const failures = [];
  for (const [name, run] of tests) {
    try { await runCase(run, executableSource); passed++; } catch (error) { failures.push({ name, type: error.constructor.name, message: error.message }); }
  }
  const receipt = { passed, failed: failures.length, assertionFailures: failures.filter(x => x.type === 'AssertionError').length,
    hostCount: tests.size, controller: controllerPath, sha256: createHash('sha256').update(source).digest('hex'), activatedMutant: mutant, failures };
  if (output) fs.writeFileSync(output, JSON.stringify(receipt, null, 2) + '\n');
  console.log(JSON.stringify(receipt));
  if (args.includes('--expect-red')) assert.ok(failures.length > 0 && failures.every(x => x.type === 'AssertionError'), 'RED assertions only');
  else assert.equal(failures.length, 0);
}
main().catch(error => { console.error(error.stack); process.exitCode = 1; });
