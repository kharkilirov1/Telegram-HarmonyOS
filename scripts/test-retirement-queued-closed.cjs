// Node >=24. Actual Gateway/Dispatcher/TdObject/AppError via the read-only host fixture.
// Native delivery, timers and the partial-drain clock are explicit fixture boundaries.
// No production writes, native compilation, SDK/device or ClientManager acceptance claims.
// --negative-controls injects a queue-discard regression into source reads IN MEMORY.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { fixture, auth, observed } = require('./test-td-gateway-recovery.cjs');
const gatewayPath = path.resolve(__dirname, '../entry/src/main/ets/infra/td/gateway/TdGateway.ets');
const tests = [];
const test = (name, run) => tests.push([name, run]);
const tick = () => new Promise(resolve => setImmediate(resolve));
const hash = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const retiredAssertion = 'queued current-client Closed must retire ID before shutdown';
const staleAssertion = 'immediate retry must deliver fresh updates only, never old-generation updates';

async function setup() {
  const failures = [];
  const f = await fixture({
    beforeRestart: async () => {}, afterRestart() {}, onFailure(error) { failures.push(error); }
  });
  f.emit([auth(1, 'Closed')]);
  await f.flush();
  assert.equal(f.created(), 2, 'actual recovery must allocate client2');
  assert.equal(f.gateway.getState(), 'ready');
  const probe = f.sends.find(s => s.id === 2 && s.request['@type'] === 'getAuthorizationState');
  assert.ok(probe, 'actual recovery bootstrap request must engage');
  const deadlines = [...f.timers].filter(([, t]) => t.ms === f.getMethodTimeout('getAuthorizationState'));
  assert.equal(deadlines.length, 1, 'one actual bootstrap timeout');
  f.deadline = deadlines[0];
  f.failures = failures;
  f.deliver = value => f.emit(value);
  return f;
}

async function timeoutBeforeDrain(f) {
  const [id, timer] = f.deadline;
  assert.ok(f.timers.has(id), 'bootstrap deadline still active before expiry');
  f.timers.delete(id);
  timer.fn();
  // Crucially, do NOT call flush(): run Promise continuations before drain timers.
  // Models a native batch enqueued just before an already-due request deadline.
  await tick();
  assert.equal(f.gateway.getGatewayStats().timeouts, 1, 'real timeout callback engaged');
  assert.ok(f.failures.length > 0, 'actual reportRecoveryFailure engaged');
}

async function retireAndStop(f) {
  await f.flush();
  assert.equal(f.gateway.clientId, 0, retiredAssertion);
  assert.equal(f.created(), 2, 'automatic recovery budget must not create client3');
  const closeCount = f.sends.filter(s => s.request['@type'] === 'close').length;
  const shutdown = observed(f.gateway.destroy());
  for (let i = 0; i < 12 && !shutdown.settled; i++) await f.flush();
  assert.equal(shutdown.settled, true, 'retired client shutdown must settle');
  assert.equal(shutdown.error, undefined, 'retired client shutdown must fulfill');
  assert.equal(f.gateway.getState(), 'idle');
  assert.equal(f.stopped(), 1, 'retirement still requires native stop');
  assert.equal(f.sends.filter(s => s.request['@type'] === 'close').length, closeCount,
    'never send close again to an already-retired native ID');
  assert.equal(f.gateway.getGatewayStats().pendingRequests, 0);
  assert.equal(f.timers.size, 0, 'no stranded request/drain timers');
  f.cleanDispatcher();
}

function partialDrain(f) {
  let elapsed = 0, delivered = 0;
  const unsubscribe = f.gateway.subscribeUpdates(update => {
    if (update.getType() === 'updateUser') { delivered++; elapsed = 9; }
  });
  const [id, timer] = [...f.timers].find(([, value]) => value.ms <= 250);
  f.timers.delete(id);
  const realNow = f.clock.now, epoch = realNow();
  // Deterministic subscriber cost exhausts the actual production drain budget.
  // Neither dispatch logic nor generation/scheduling logic is replaced.
  f.clock.now = () => epoch + elapsed;
  try { timer.fn(); } finally { f.clock.now = realNow; unsubscribe(); }
  assert.equal(delivered, 1, 'actual first update must be dispatched');
  assert.equal(f.gateway.drainIndex, 1, 'drain actually stopped after first item');
  assert.equal(f.gateway.drainScheduled, true, 'old-generation continuation is scheduled');
}

for (const single of [false, true]) {
  test(`timeout preserves queued current Closed (single=${single})`, async () => {
    const f = await setup();
    f.deliver(single ? auth(2, 'Closed') : [auth(2, 'WaitTdlibParameters'), auth(2, 'Closing'), auth(2, 'Closed')]);
    assert.equal(f.gateway.pendingBatchQueue.length, 1, 'actual native callback queues payload before deadline');
    await timeoutBeforeDrain(f);
    await retireAndStop(f);
  });
}

test('timeout preserves current Closed behind a foreign batch and single-envelope batch', async () => {
  const f = await setup();
  f.deliver([auth(1, 'Closed'), auth(3, 'Closed')]);
  f.deliver(auth(2, 'Closed'));
  assert.equal(f.gateway.pendingBatchQueue.length, 2, 'both actual callback payloads queued');
  await timeoutBeforeDrain(f);
  await retireAndStop(f);
});

test('timeout preserves unconsumed Closed after a partial drain and rearms its generation', async () => {
  const f = await setup();
  f.deliver([{ '@type': 'updateUser', '@client_id': 2, user: { '@type': 'user', id: 7 } },
    auth(1, 'Closed'), auth(2, 'Closed')]);
  partialDrain(f);
  assert.equal(f.gateway.drainItems.length, 3, 'remaining Closed is in the loaded batch');
  assert.equal(f.gateway.pendingBatchQueue.length, 0, 'not merely the pending-batch case');
  await timeoutBeforeDrain(f);
  await retireAndStop(f);
});

for (const mode of ['batch', 'single', 'partial']) {
  test(`immediate retry filters stale ordinary updates but delivers fresh traffic (mode=${mode})`, async () => {
    const f = await setup(), seen = [];
    let readyNotices = 0;
    f.gateway.subscribeUpdates(update => {
      if (update.getType() === 'updateUser') seen.push(update.getNumber('marker'));
      if (update.getType() === 'updateAuthorizationState' &&
        update.getObject('authorization_state').getType() === 'authorizationStateReady') readyNotices++;
    });
    const oldRequest = observed(f.gateway.send('getMe')), oldSend = f.sends.at(-1);
    const payloads = [{ '@type': 'updateUser', '@client_id': 2, marker: 1 }, auth(2, 'Ready'),
      { '@type': 'user', '@client_id': 2, '@extra': oldSend.request['@extra'], id: 111 }];
    if (mode === 'single') payloads.forEach(f.deliver);
    else f.deliver(mode === 'partial'
      ? [{ '@type': 'updateUser', '@client_id': 2, marker: 0 }, ...payloads] : payloads);
    if (mode === 'partial') { partialDrain(f); assert.deepEqual(seen, [0]); seen.length = 0; }
    await timeoutBeforeDrain(f);
    assert.equal(oldRequest.settled, true);
    assert.equal(oldRequest.error?.retryable, false, 'old request capability revoked before retry');
    // Await only microtasks, NOT fixture.flush(): the retained old queue is still pending.
    await f.gateway.retryClosedClient();
    assert.equal(f.gateway.getState(), 'ready', 'immediate retry is ready BEFORE old drain');
    assert.equal(f.created(), 2, 'retry reuses still-owned client2');
    const freshRequest = observed(f.gateway.send('getMe')), freshSend = f.sends.at(-1);
    f.deliver([{ '@type': 'updateUser', '@client_id': 2, marker: 2 },
      { '@type': 'user', '@client_id': 2, '@extra': freshSend.request['@extra'], id: 222 }]);
    await f.flush();
    assert.deepEqual(seen, [2], staleAssertion);
    assert.equal(readyNotices, 0, 'stale Ready must not renew automatic recovery budget');
    assert.equal(oldRequest.count, 1, 'stale response cannot resurrect rejected request');
    assert.equal(freshRequest.value?.getNumber('id'), 222, 'fresh response route actually engaged');
    assert.equal(freshRequest.error, undefined);
    f.deliver([auth(2, 'Closed')]);
    await retireAndStop(f);
  });
}

for (const single of [false, true]) {
  test(`immediate retry still accepts retained current Closed (single=${single})`, async () => {
    const f = await setup(), seen = [];
    f.gateway.subscribeUpdates(update => {
      if (update.getType() === 'updateUser') seen.push(update.getNumber('marker'));
    });
    const payloads = [{ '@type': 'updateUser', '@client_id': 2, marker: 1 }, auth(1, 'Closed'), auth(2, 'Closed')];
    if (single) payloads.forEach(f.deliver); else f.deliver(payloads);
    await timeoutBeforeDrain(f);
    await f.gateway.retryClosedClient();
    assert.equal(f.gateway.getState(), 'ready', 'retry reaches ready before draining retained Closed');
    await retireAndStop(f);
    assert.deepEqual(seen, [], 'retained Closed survives without reviving old account updates');
  });
}

for (const single of [false, true]) {
  test(`foreign Closed cannot retire owner; genuine late Closed still works (single=${single})`, async () => {
    const f = await setup();
    const foreign = [auth(1, 'Closed'), auth(3, 'Closed'), auth('2', 'Closed'), auth(undefined, 'Closed')];
    foreign.push({ '@type': 'updateAuthorizationState', nested: { '@client_id': 2 },
      authorization_state: { '@type': 'authorizationStateClosed' } });
    if (single) foreign.forEach(f.deliver); else f.deliver(foreign);
    await timeoutBeforeDrain(f);
    await f.flush();
    assert.equal(f.gateway.clientId, 2, 'foreign or nested identity is not retirement evidence');
    assert.equal(f.stopped(), 0, 'must retain receiver without current-client Closed');
    assert.equal(f.created(), 2);
    const seen = [];
    const unsubscribe = f.gateway.subscribeUpdates(u => seen.push(u.getType()));
    f.deliver([{ '@type': 'updateUser', '@client_id': 2 }, auth(2, 'Ready')]);
    await f.flush();
    assert.deepEqual(seen, [], 'failed owner must not publish ordinary account updates');
    unsubscribe();
    f.deliver(single ? auth(2, 'Closed') : [auth(2, 'Closed')]);
    await retireAndStop(f);
  });
}

for (const single of [false, true]) {
  test(`reverse-order control: drain Closed before bootstrap deadline (single=${single})`, async () => {
    const f = await setup();
    f.deliver(single ? auth(2, 'Closed') : [auth(2, 'WaitTdlibParameters'), auth(2, 'Closed')]);
    await f.flush();
    assert.equal(f.gateway.clientId, 0, 'known-good ordering consumes Closed');
    assert.equal(f.timers.has(f.deadline[0]), false, 'Closed cancels bootstrap request deadline');
    f.deadline[1].fn(); // Even an already-selected stale timer must be harmless.
    await tick();
    assert.equal(f.gateway.getGatewayStats().timeouts, 0, 'revoked request timer cannot create a failure');
    await retireAndStop(f);
  });
}

async function bounded(run) {
  let watchdog;
  try {
    return await Promise.race([run(), new Promise((_, reject) => {
      watchdog = setTimeout(() => reject(new Error('HARNESS_TIMEOUT: test did not settle')), 5000);
    })]);
  } finally { clearTimeout(watchdog); }
}

async function negativeControl() {
  const originalRead = fs.readFileSync;
  const bytes = originalRead(gatewayPath);
  const source = bytes.toString('utf8').replace(/\r\n/g, '\n');
  const begin = source.indexOf('  private reportRecoveryFailure(');
  const end = source.indexOf('\n  async send(', begin);
  assert.ok(begin >= 0 && end > begin, 'unique reportRecoveryFailure boundary');
  const method = source.slice(begin, end), anchor = '    this.rearmBatchDrain(getMainThreadDispatcher());';
  assert.equal(method.split(anchor).length - 1, 1, 'unique failure rearm mutation anchor');
  const replaceMethod = replacement => source.slice(0, begin) + method.replace(anchor, replacement) + source.slice(end);
  const staleGuard = '    if (generation !== this.clientGeneration && !this.isClosedEnvelope(obj)) return;';
  assert.equal(source.split(staleGuard).length - 1, 1, 'unique generation guard');
  const controls = [
    { name: 'discard-queued-Closed', source: replaceMethod('    this.resetBatchDrain();'),
      test: tests[0][0], assertion: retiredAssertion, actual: 2, expected: 0 },
    { name: 'preserve-without-rearming', source: replaceMethod('    // Mutant: stale drain timer is never rearmed.'),
      test: tests[0][0], assertion: retiredAssertion, actual: 2, expected: 0 },
    { name: 'revive-stale-ordinary-updates', source: source.replace(staleGuard, '    // Mutant: omit batch generation guard.'),
      test: 'immediate retry filters stale ordinary updates but delivers fresh traffic (mode=batch)',
      assertion: staleAssertion, actual: [1, 2], expected: [2] }
  ];
  for (const control of controls) {
    let reads = 0, failure;
    const target = tests.find(([name]) => name === control.test);
    assert.ok(target, 'named behavioral control target');
    assert.notEqual(control.source, source, 'nonempty source mutation');
    fs.readFileSync = function(file, ...args) {
      const result = originalRead.call(this, file, ...args);
      if (typeof file === 'string' && path.resolve(file) === gatewayPath) {
        assert.equal(args[0], 'utf8');
        assert.equal(result.replace(/\r\n/g, '\n'), source, 'stable source during in-memory mutation');
        reads++; return control.source;
      }
      return result;
    };
    try { await bounded(target[1]); } catch (error) { failure = error; }
    finally { fs.readFileSync = originalRead; }
    assert.equal(reads, 1, 'mutant engaged in actual Gateway source loader');
    assert.ok(failure instanceof assert.AssertionError, 'behavioral assertion, not a harness/syntax error');
    assert.ok(failure.message.includes(control.assertion), `wrong failure: ${failure.message}`);
    assert.deepEqual(failure.actual, control.actual); assert.deepEqual(failure.expected, control.expected);
    console.log(`CONTROL REJECTED ${control.name}: ${control.assertion}`);
  }
  assert.deepEqual(originalRead(gatewayPath), bytes, 'mutation never writes production bytes');
  console.log(`${controls.length}/${controls.length} in-memory negative controls rejected`);
}

async function main() {
  const inputs = [gatewayPath, __filename,
    path.resolve(__dirname, 'test-td-gateway-recovery.cjs'),
    path.resolve(__dirname, '../entry/src/main/ets/infra/threading/MainThreadDispatcher.ets'),
    path.resolve(__dirname, '../entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets')];
  const before = new Map(inputs.map(file => [file, hash(file)]));
  console.log(`SOURCE TdGateway.ets sha256=${before.get(gatewayPath)}`);
  let failed = 0;
  for (const [name, run] of tests) {
    try { await bounded(run); console.log(`PASS ${name}`); }
    catch (error) { failed++; console.log(`FAIL ${name}: ${error.stack}`); }
  }
  if (process.argv.includes('--negative-controls')) {
    if (failed) console.log('SKIP mutation: baseline must be GREEN before testing a regression mutant');
    else await negativeControl();
  }
  for (const file of inputs) assert.equal(hash(file), before.get(file), `${path.basename(file)} changed; rerun stable snapshot`);
  console.log(`${inputs.length}/${inputs.length} source/fixture/test hashes stable`);
  console.log(`${tests.length - failed}/${tests.length} PASS; ${failed} FAIL`);
  process.exitCode = failed ? 1 : 0;
}

if (require.main === module) main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
