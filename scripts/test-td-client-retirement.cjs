// Node >=24. Actual Gateway/Dispatcher and runtimeFixture; only NAPI/timers are fixtures.
// No native-manager, device, DB, SDK compilation or TSFN lifetime claims.
// --negative-controls: exact, in-memory source mutants must fail named assertions.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { fixture, auth, observed } = require('./test-td-gateway-recovery.cjs');
const { fixture: runtimeFixture, load: runtimeLoad } = require('./test-runtime-account-recovery.cjs');
const { createMyUserResolvedEvent } = runtimeLoad('core/model/AppEvent.ets');
const tests = [];
const test = (name, run) => tests.push([name, run]);
const gatewayPath = path.resolve(__dirname, '../entry/src/main/ets/infra/td/gateway/TdGateway.ets');
const hash = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  // Observe injected native rejection even on a broken source that ignores stop.
  return { promise, resolve, reject, outcome: observed(promise) };
}

async function setup(initialize = true) {
  const f = await fixture(undefined, false);
  f.events = []; f.stops = [];
  const start = f.native.startReceiveLoop, create = f.native.createClient;
  f.native.startReceiveLoop = callback => { f.events.push('start'); return start(callback); };
  f.native.createClient = () => { f.events.push('create'); return create(); };
  f.native.stopReceiveLoop = () => {
    f.events.push('stop');
    const stop = deferred(); f.stops.push(stop); return stop.promise;
  };
  f.deliver = envelopes => {
    assert.ok(f.callbacks.length > 0, 'native receive callback exists');
    f.callbacks.at(-1)(JSON.stringify(envelopes));
  };
  if (initialize) {
    const init = observed(f.gateway.initialize());
    await settle(f, init, 'setup initialize');
    succeeded(init, 'setup initialize');
  }
  return f;
}

async function settle(f, result, label) {
  for (let i = 0; i < 16 && !result.settled; i++) await f.flush();
  assert.equal(result.settled, true, `${label}: must settle, not silently abandon a hung Promise`);
  assert.equal(result.count, 1, `${label}: exactly one settlement`);
}
function succeeded(result, label) {
  assert.equal(result.settled, true, `${label}: fulfilled operation must settle`);
  assert.equal(result.error, undefined, `${label}: must fulfill`);
}
async function rejected(f, promise, label) {
  const result = observed(promise); await settle(f, result, label);
  assert.ok(result.error, `${label}: must reject`); return result;
}
function closeSends(f) { return f.sends.filter(s => s.request['@type'] === 'close'); }
function currentClose(f) {
  const close = closeSends(f).at(-1);
  assert.ok(close, 'actual gateway sent close'); return close;
}
function replyClose(f) {
  const close = currentClose(f);
  f.deliver([{ '@type': 'ok', '@client_id': close.id, '@extra': close.request['@extra'] }]);
}
function fireTimer(f, ms) {
  const entries = [...f.timers].filter(([, timer]) => timer.ms === ms);
  assert.equal(entries.length, 1, `exactly one actual ${ms}ms timer engaged`);
  const [id, timer] = entries[0]; f.timers.delete(id); timer.fn();
}
async function expireClose(f, mode) {
  if (mode === 'close-ok') { replyClose(f); await f.flush(); }
  fireTimer(f, mode === 'close-ok' ? 5000 : f.getMethodTimeout('close'));
  await f.flush();
}
function retained(f, id = 1) {
  assert.equal(f.gateway.getState(), 'destroying', 'unretired client remains destroying');
  assert.equal(f.gateway.clientId, id, 'same native ID retained until correct-client Closed');
  assert.equal(f.gateway.receiveLoopStarted, true, 'receive path retained until Closed');
  assert.equal(f.gateway.isReady(), false);
  assert.equal(f.stops.length, 0, 'no native stop before correct-client Closed');
  assert.equal(f.created(), id, 'no new ID while previous ID is unretired');
}
async function idleAfterStop(f, index = 0) {
  assert.equal(f.stops.length, index + 1, 'exactly one stop per attempt');
  assert.equal(f.gateway.getState(), 'destroying', 'stop barrier must precede idle');
  f.stops[index].resolve();
  for (let i = 0; i < 16 && f.gateway.getState() !== 'idle'; i++) await f.flush();
  await settle(f, f.stops[index].outcome, 'native stop fulfillment');
  succeeded(f.stops[index].outcome, 'native stop fulfillment');
  assert.equal(f.gateway.getState(), 'idle', 'native stop fulfillment completes retirement');
  assert.equal(f.gateway.clientId, 0);
  assert.equal(f.gateway.getGatewayStats().pendingRequests, 0);
  assert.equal(f.timers.size, 0, 'no orphaned request/close/drain timers');
  f.cleanDispatcher();
}

test('receiver starts BEFORE createClient', async () => {
  const f = await setup();
  assert.deepEqual(f.events, ['start', 'create'], 'receiver must start before native ID allocation');
  assert.equal(f.created(), 1); assert.equal(f.callbacks.length, 1);
});

for (const partial of [false, true]) test(`start failure allocates zero IDs and awaits stop (partial=${partial})`, async () => {
  const f = await setup(false); const start = f.native.startReceiveLoop;
  f.native.startReceiveLoop = callback => {
    if (partial) start(callback);
    throw new Error('injected receiver start failure');
  };
  const init = observed(f.gateway.initialize()); await f.flush();
  assert.equal(f.created(), 0, 'start failure must allocate zero native IDs');
  assert.equal(f.stops.length, 1, 'failed/partial start still needs stop barrier');
  assert.equal(init.settled, false, 'initialize rejection awaits stop');
  assert.equal(f.gateway.getState(), 'destroying');
  const destroy = observed(f.gateway.destroy()); await f.flush();
  assert.equal(destroy.settled, false); assert.equal(f.stops.length, 1);
  if (partial) { f.deliver([auth(1, 'Closed')]); await f.flush(); }
  await rejected(f, f.gateway.initialize(), 'initialize during startup cleanup');
  assert.equal(f.created(), 0); assert.equal(f.sends.length, 0);
  await idleAfterStop(f); await settle(f, init, 'failed initialize');
  assert.match(init.error?.message, /injected receiver start failure/);
  await settle(f, destroy, 'joined startup cleanup'); succeeded(destroy, 'joined startup cleanup');
});

test('create failure stops the already started receiver and awaits its barrier', async () => {
  const f = await setup(false);
  f.native.createClient = () => { f.events.push('create-throw'); throw new Error('injected create failure'); };
  const init = observed(f.gateway.initialize()); await f.flush();
  assert.deepEqual(f.events, ['start', 'create-throw', 'stop'], 'create failure cleans up a started receiver');
  assert.equal(f.callbacks.length, 1); assert.equal(f.created(), 0);
  assert.equal(init.settled, false); assert.equal(f.gateway.getState(), 'destroying');
  await idleAfterStop(f); await settle(f, init, 'create failure');
  assert.match(init.error?.message, /injected create failure/);
});

for (const mode of ['close-ok', 'request-timeout']) {
  test(`${mode}: destroy rejects but retains ID/receiver, blocks create and stop`, async () => {
    const f = await setup(); const pending = observed(f.gateway.send('getMe'));
    const destroyed = observed(f.gateway.destroy()); await f.flush();
    await expireClose(f, mode); await settle(f, destroyed, 'destroy timeout');
    assert.ok(destroyed.error, 'destroy timeout must reject, not report success');
    await settle(f, pending, 'revoked old request'); assert.equal(pending.error?.retryable, false);
    retained(f); assert.equal(f.gateway.getClientGeneration(), 1);
    await rejected(f, f.gateway.initialize(), 'initialize during retirement');
    await rejected(f, f.gateway.retryClosedClient(), 'recovery during retirement');
    retained(f); assert.equal(closeSends(f).length, 1); assert.equal(f.callbacks.length, 1);
  });

  for (const single of [false, true]) test(`${mode}: late Closed auto-retires after unsubscribe (single=${single})`, async () => {
    const f = await setup(); const destroyed = observed(f.gateway.destroy());
    await expireClose(f, mode); await settle(f, destroyed, 'destroy timeout');
    assert.ok(destroyed.error, 'timeout must reject before late Closed'); retained(f);
    f.dispatcher.unsubscribe();
    const encode = value => single ? value : [value];
    for (const id of [2, '1', undefined]) {
      f.deliver(encode(auth(id, 'Closed'))); await f.flush(); retained(f);
    }
    f.deliver(encode(auth(1, 'Ready'))); await f.flush(); retained(f);
    f.deliver(encode(auth(1, 'Closed'))); await f.flush();
    assert.equal(f.stops.length, 1, 'late Closed automatically starts stop without another destroy');
    assert.equal(f.created(), 1); assert.equal(f.callbacks.length, 1);
    await rejected(f, f.gateway.initialize(), 'initialize while late stop pending');
    await idleAfterStop(f);
    assert.equal(destroyed.count, 1, 'late success cannot rewrite prior timeout rejection');
  });
}

for (const unsubscribe of [false, true]) test(`Closed WITHOUT close Ok is authoritative (unsubscribe=${unsubscribe})`, async () => {
  const f = await setup(); const destroyed = observed(f.gateway.destroy());
  currentClose(f);
  if (unsubscribe) f.dispatcher.unsubscribe();
  f.deliver([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.stops.length, 1, 'Closed must start stop without firing the close response timeout');
  assert.equal(destroyed.settled, false, 'Closed still waits for native stop');
  assert.equal(f.gateway.getGatewayStats().pendingRequests, 0);
  assert.equal(f.timers.size, 0, 'Closed clears close request timeout');
  await idleAfterStop(f); await settle(f, destroyed, 'Closed without Ok');
  succeeded(destroyed, 'Closed without Ok');
});

test('concurrent and reentrant destroy are single-flight through close and stop', async () => {
  const f = await setup(); let reentrant;
  const stop = f.native.stopReceiveLoop;
  f.native.stopReceiveLoop = () => { reentrant = f.gateway.destroy(); return stop(); };
  const first = f.gateway.destroy(), second = f.gateway.destroy();
  assert.equal(second, first, 'concurrent destroy shares one Promise');
  const a = observed(first), b = observed(second);
  replyClose(f); f.deliver([auth(1, 'Closed')]); await f.flush();
  assert.equal(reentrant, first, 'reentrant native stop joins existing flight');
  assert.equal(a.settled || b.settled, false); assert.equal(closeSends(f).length, 1);
  await idleAfterStop(f); await settle(f, a, 'first destroy'); await settle(f, b, 'second destroy');
  succeeded(a, 'first destroy'); succeeded(b, 'second destroy');
});

test('same gateway instance resets Closed before planning the next client shutdown', async () => {
  const f = await setup();
  const first = observed(f.gateway.destroy());
  replyClose(f); f.deliver([auth(1, 'Closed')]); await f.flush();
  await idleAfterStop(f); await settle(f, first, 'first retirement'); succeeded(first, 'first retirement');
  const init = observed(f.gateway.initialize()); await settle(f, init, 'same-instance initialize');
  succeeded(init, 'same-instance initialize'); assert.equal(f.created(), 2);
  const second = observed(f.gateway.destroy()); await f.flush();
  assert.equal(closeSends(f).length, 2, 'second client must send its own close, not reuse prior Closed');
  assert.equal(currentClose(f).id, 2); assert.equal(f.stops.length, 1, 'second client cannot stop before its own Closed');
  f.deliver([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.stops.length, 1); assert.equal(second.settled, false);
  replyClose(f); f.deliver([auth(2, 'Closed')]); await f.flush();
  await idleAfterStop(f, 1); await settle(f, second, 'second retirement'); succeeded(second, 'second retirement');
});

for (const late of [false, true]) test(`stop rejection after Closed requires explicit stop-only retry (late=${late})`, async () => {
  const f = await setup(); const destroyed = observed(f.gateway.destroy());
  if (late) {
    await expireClose(f, 'close-ok'); await settle(f, destroyed, 'destroy timeout');
    assert.ok(destroyed.error); f.dispatcher.unsubscribe();
  } else { replyClose(f); }
  f.deliver([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.stops.length, 1, 'correct Closed starts exactly one native stop');
  f.stops[0].reject(new Error('injected stop failure')); await f.flush();
  await settle(f, destroyed, 'destroy rejection'); assert.ok(destroyed.error);
  for (let i = 0; i < 16; i++) {
    f.deliver([auth(1, 'Closed')]); await f.flush();
  }
  assert.equal(f.gateway.getState(), 'destroying');
  assert.equal(f.stops.length, 1, 'stop rejection must not enter an automatic retry loop');
  await rejected(f, f.gateway.initialize(), 'initialize after stop rejection');
  await rejected(f, f.gateway.retryClosedClient(), 'recovery after stop rejection');
  const retry = observed(f.gateway.destroy()); await f.flush();
  assert.equal(f.stops.length, 2); assert.equal(retry.settled, false);
  assert.equal(closeSends(f).length, 1, 'explicit retry repeats stop only, never close');
  assert.equal(f.created(), 1); assert.equal(f.gateway.getClientGeneration(), 1);
  await idleAfterStop(f, 1); await settle(f, retry, 'explicit stop retry'); succeeded(retry, 'explicit stop retry');
});

// Deliver Closed during the async timeout/catch handoff as well as after it.
// No synthetic Gateway methods: advance only native envelopes and microtasks.
for (const turns of [0, 1, 2, 3, 4, 6]) test(`timeout/Closed catch race completes retirement (microtasks=${turns})`, async () => {
  const f = await setup(); const destroyed = observed(f.gateway.destroy());
  replyClose(f); await f.flush(); f.dispatcher.unsubscribe();
  fireTimer(f, 5000);
  for (let i = 0; i < turns; i++) await Promise.resolve();
  f.deliver([auth(1, 'Closed')]); f.drainSync(); await f.flush();
  assert.equal(f.stops.length, 1, 'Closed during timeout/catch handoff cannot strand retirement');
  await idleAfterStop(f); await settle(f, destroyed, 'timeout/Closed race');
  assert.equal(f.created(), 1); assert.equal(closeSends(f).length, 1);
});

for (const mode of ['close-ok', 'request-timeout']) test(`actual runtime ${mode} revokes scope and blocks recreate until late Closed/stop`, async () => {
  const f = await setup(false); const r = await runtimeFixture(f);
  const old = r.runtime.getStore(); const rootStore = r.runtime.getLifecycleStore();
  assert.equal(old.getState().auth.userId, 123, 'runtime starts with seeded account A');
  const liveWrite = observed(old.dispatch(createMyUserResolvedEvent(456)));
  await settle(f, liveWrite, 'live account write'); succeeded(liveWrite, 'live account write');
  assert.equal(rootStore.getState().auth.userId, 456, 'positive control: this event really updates the auth reducer');
  const shutdown = observed(r.runtime.shutdown());
  assert.equal(old.getState().auth.userId, 0, 'actual runtime synchronously revokes old account reads');
  await f.flush();
  await expireClose(f, mode); await settle(f, shutdown, 'runtime shutdown timeout');
  assert.ok(shutdown.error, 'actual runtime exposes shutdown failure'); retained(f);
  assert.equal(f.dispatcher.getStats().isSubscribed, false, 'runtime detached shared dispatcher');
  const restart = observed(r.runtime.initialize()); await f.flush();
  // Runtime initialize failure may retry destroy for cleanup. Drive any new close
  // attempt to timeout, never resolve an unretired operation by hand.
  for (let i = 0; i < 4 && !restart.settled; i++) {
    const timer = [...f.timers].find(([, t]) => t.ms > 250);
    if (timer) { f.timers.delete(timer[0]); timer[1].fn(); }
    await f.flush();
  }
  await settle(f, restart, 'runtime restart while unretired'); assert.ok(restart.error);
  retained(f); assert.equal(old.getState().auth.userId, 0);
  // Retaining an inaccessible lifecycle snapshot is allowed; the contract is
  // scope revocation, not when the root store is cleared during a failed retry.
  const rootBeforeStaleWrite = rootStore.getState().auth.userId;
  assert.notEqual(rootBeforeStaleWrite, 999, 'stale write sentinel differs from live state');
  const write = observed(old.dispatch(createMyUserResolvedEvent(999)));
  await settle(f, write, 'stale account write'); succeeded(write, 'stale account write');
  assert.equal(rootStore.getState().auth.userId, rootBeforeStaleWrite, 'revoked scope cannot change lifecycle state');
  f.deliver([auth(2, 'Closed')]); await f.flush(); retained(f);
  f.deliver([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.stops.length, 1, 'actual runtime unsubscribe cannot strand late retirement');
  await rejected(f, f.gateway.initialize(), 'initialize until actual stop settles');
  await idleAfterStop(f);
  const resumed = observed(r.runtime.initialize()); await settle(f, resumed, 'runtime restart after retirement');
  succeeded(resumed, 'runtime restart after retirement');
  assert.equal(f.created(), 2); assert.equal(f.callbacks.length, 2);
  assert.notEqual(r.runtime.getStore(), old); assert.equal(old.getState().auth.userId, 0);
  const final = observed(r.runtime.shutdown()); await f.flush();
  replyClose(f); f.deliver([auth(2, 'Closed')]); await f.flush();
  await idleAfterStop(f, 1); await settle(f, final, 'final runtime shutdown'); succeeded(final, 'final runtime shutdown');
});

async function bounded(run) {
  let watchdog;
  try {
    // A real timer prevents Node from exiting successfully on a hung test body.
    return await Promise.race([run(), new Promise((_, reject) => {
      watchdog = setTimeout(() => reject(new Error('HARNESS_TIMEOUT: test body did not settle')), 5000);
    })]);
  } finally { clearTimeout(watchdog); }
}

async function negativeControls() {
  const originalRead = fs.readFileSync;
  const originalBytes = originalRead(gatewayPath);
  const source = originalBytes.toString('utf8').replace(/\r\n/g, '\n');
  const allocate = '      this.clientId = tdlib.createClient();\n';
  const start = '      tdlib.startReceiveLoop((batchJson: string) => {';
  const privateRoute = `    if (this.state === 'destroying') {
      // Runtime can unsubscribe its dispatcher after a failed shutdown. Keep only
      // this owner's close responses/Closed on the already-main-thread NAPI path;
      // broadcastUpdate still rejects non-Closed account updates while destroying.
      if (hasExtra) this.handleResponseOnMainThread(rawJson);
      else this.handleUpdateOnMainThread(rawJson);
      return;
    }
`;
  const catchFinish = '      // Closed can arrive after a close timeout but before this rejection handler.\n' +
    '      this.finishLateClientRetirement();';
  const controls = [
    { id: 'early-allocate', replacements: [[allocate, ''], [start, allocate + start]],
      test: 'start failure allocates zero IDs and awaits stop (partial=false)',
      assertion: 'start failure must allocate zero native IDs', actual: 1, expected: 0 },
    { id: 'cleanup-on-close-timeout', replacements: [
      ['      if (!this.destroyClosedObserved) {\n        // Do not lose',
        '      if (false) {\n        // Do not lose']],
      test: 'close-ok: destroy rejects but retains ID/receiver, blocks create and stop',
      assertion: 'destroy timeout: must settle, not silently abandon a hung Promise', actual: false, expected: true },
    { id: 'missing-private-destroying-route', replacements: [[privateRoute, '']],
      test: 'close-ok: late Closed auto-retires after unsubscribe (single=false)',
      assertion: 'late Closed automatically starts stop without another destroy', actual: 0, expected: 1 },
    { id: 'no-late-close-finish', replacements: [
      ['    if (closed) this.finishLateClientRetirement();', '    // Mutant: omit late-Closed retirement.']],
      test: 'close-ok: late Closed auto-retires after unsubscribe (single=true)',
      assertion: 'late Closed automatically starts stop without another destroy', actual: 0, expected: 1 },
    { id: 'automatic-retry-on-stop-failure', replacements: [
      ['    this.clientRetirementPending = false;', '    // Mutant: leave retirement armed after stop begins.']],
      test: 'stop rejection after Closed requires explicit stop-only retry (late=true)',
      assertion: 'stop rejection must not enter an automatic retry loop', actual: 2, expected: 1 },
    { id: 'wait-for-ok-after-closed', replacements: [
      ['await Promise.race([closeResponse, closeStatePromise.then((): void => {})]);', 'await closeResponse;']],
      test: 'Closed WITHOUT close Ok is authoritative (unsubscribe=false)',
      assertion: 'Closed must start stop without firing the close response timeout', actual: 0, expected: 1 },
    { id: 'missing-catch-race-finish', replacements: [[catchFinish, '      // Mutant: omit catch handoff.']],
      test: 'timeout/Closed catch race completes retirement (microtasks=1)',
      assertion: 'Closed during timeout/catch handoff cannot strand retirement', actual: 0, expected: 1 },
    { id: 'reuse-prior-client-closed', replacements: [
      ['      this.destroyClosedObserved = false;', '      // Mutant: stale prior-client Closed.']],
      test: 'same gateway instance resets Closed before planning the next client shutdown',
      assertion: 'second client must send its own close, not reuse prior Closed', actual: 1, expected: 2 }
  ];
  const hashes = new Set();
  for (const control of controls) {
    let mutated = source;
    for (const [from, to] of control.replacements) {
      assert.equal(mutated.split(from).length - 1, 1, `unique mutation anchor: ${control.id}`);
      mutated = mutated.replace(from, to);
    }
    assert.notEqual(mutated, source, `nonempty mutation: ${control.id}`);
    const digest = createHash('sha256').update(mutated).digest('hex');
    assert.equal(hashes.has(digest), false, `distinct mutant: ${control.id}`); hashes.add(digest);
    const target = tests.find(([name]) => name === control.test);
    assert.ok(target, `named behavioral test: ${control.test}`);
    let reads = 0, failure;
    // Substitute only the actual-source Gateway read. Never write production/tests.
    fs.readFileSync = function(file, ...args) {
      const result = originalRead.call(this, file, ...args);
      if (typeof file === 'string' && path.resolve(file) === gatewayPath) {
        assert.equal(args[0], 'utf8', 'fixture reads actual Gateway text');
        assert.equal(result.replace(/\r\n/g, '\n'), source, 'stable source during controls');
        reads++; return mutated;
      }
      return result;
    };
    try { await bounded(target[1]); }
    catch (error) { failure = error; }
    finally { fs.readFileSync = originalRead; }
    assert.equal(reads, 1, `actual-source mutation engaged once: ${control.id}`);
    assert.ok(failure instanceof assert.AssertionError, `${control.id}: named behavioral failure required, got ${failure}`);
    assert.equal(failure.operator, 'strictEqual', `${control.id}: expected strict assertion`);
    assert.ok(failure.message.includes(control.assertion), `${control.id}: wrong assertion: ${failure.message}`);
    assert.equal(failure.actual, control.actual, `${control.id}: expected failing actual`);
    assert.equal(failure.expected, control.expected, `${control.id}: expected failing oracle`);
    console.log(`CONTROL PASS ${control.id}: RED ${control.assertion} (actual=${failure.actual}, expected=${failure.expected})`);
  }
  assert.deepEqual(originalRead(gatewayPath), originalBytes, 'controls never alter production bytes');
  console.log(`${controls.length}/${controls.length} negative controls rejected at named assertions`);
}

async function main() {
  const inputs = [gatewayPath,
    '../entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets',
    '../entry/src/main/ets/core/store/AppStore.ets',
    '../entry/src/main/ets/core/reducers/authReducer.ets',
    '../entry/src/main/ets/core/model/AppEvent.ets',
    '../entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets',
    '../entry/src/main/ets/infra/threading/MainThreadDispatcher.ets',
    './test-td-gateway-recovery.cjs', './test-runtime-account-recovery.cjs', __filename
  ].map(file => path.resolve(__dirname, file));
  const before = new Map(inputs.map(file => [file, hash(file)])); let failed = 0;
  console.log(`SOURCE TdGateway.ets sha256=${before.get(gatewayPath)}`);
  console.log(`SOURCE AppCoreRuntime.ets sha256=${before.get(inputs[1])}`);
  for (const [name, run] of tests) {
    try {
      await bounded(run);
      console.log(`PASS ${name}`);
    } catch (error) { failed++; console.log(`FAIL ${name}: ${error.stack}`); }
  }
  if (process.argv.includes('--negative-controls')) await negativeControls();
  for (const file of inputs) {
    assert.equal(hash(file), before.get(file), `${path.basename(file)} changed during run; rerun a stable snapshot`);
  }
  console.log(`${inputs.length}/${inputs.length} source/fixture/test hashes stable`);
  console.log(`${tests.length - failed}/${tests.length} PASS; ${failed} FAIL`);
  process.exitCode = failed ? 1 : 0;
}
if (require.main === module) {
  main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
}
