// Actual ETS Gateway/Dispatcher/Runtime; only NAPI, timers and platform boundaries are fixtures.
// Node >=24. No native timing, DB, device or account claims.
// Opt-in --negative-controls runs four in-memory Gateway source mutations.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { fixture, auth, observed } = require('./test-td-gateway-recovery.cjs');
const { fixture: runtimeFixture } = require('./test-runtime-account-recovery.cjs');
const tests = [];
const test = (name, run) => tests.push([name, run]);
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  // Pre-fix gateway ignores this Promise: still observe the injected rejection.
  promise.catch(() => {});
  return { promise, resolve, reject };
}
async function setup(initialize = true) {
  const f = await fixture(undefined, false);
  f.stops = [];
  f.native.stopReceiveLoop = () => {
    const stop = deferred(); f.stops.push(stop); return stop.promise;
  };
  f.deliver = envelopes => f.callbacks.at(-1)(JSON.stringify(envelopes));
  f.ackClose = async (id = 1) => {
    const close = f.sends.find(s => s.id === id && s.request['@type'] === 'close');
    assert.ok(close, 'actual gateway sends close');
    f.deliver([{ '@type': 'ok', '@client_id': id, '@extra': close.request['@extra'] }, auth(id, 'Closed')]);
    await f.flush();
  };
  if (initialize) await f.gateway.initialize();
  return f;
}
async function settle(f, result) {
  for (let i = 0; i < 12 && !result.settled; i++) await f.flush();
  assert.equal(result.settled, true, 'operation must settle; do not let Node silently exit on a hung Promise');
}
async function rejectCall(f, promise) {
  const result = observed(promise); await settle(f, result);
  assert.ok(result.error, 'operation must reject');
}
test('destroy holds destroying/Promise until native stop completes', async () => {
  const f = await setup();
  const pending = observed(f.gateway.send('getMe'));
  const destroyed = observed(f.gateway.destroy());
  assert.equal(f.gateway.getState(), 'destroying');
  assert.equal(f.gateway.getClientGeneration(), 1);
  await f.ackClose();
  assert.equal(f.stops.length, 1);
  assert.equal(pending.error?.retryable, false, 'old requests revoked before stop await');
  assert.equal(destroyed.settled, false, 'stop completion is part of destroy');
  assert.equal(f.gateway.getState(), 'destroying');
  assert.equal(f.gateway.getGatewayStats().pendingRequests, 0);
  f.stops[0].resolve(); await settle(f, destroyed);
  assert.equal(destroyed.error, undefined); assert.equal(f.gateway.getState(), 'idle');
});
test('concurrent/reentrant destroy shares the whole operation, not early success', async () => {
  const f = await setup();
  const stop = f.native.stopReceiveLoop;
  let reentrant;
  f.native.stopReceiveLoop = () => { reentrant = f.gateway.destroy(); return stop(); };
  const first = f.gateway.destroy(); const second = f.gateway.destroy();
  assert.equal(second, first, 'same shutdown Promise before close completes');
  const a = observed(first), b = observed(second);
  await f.ackClose(); assert.equal(reentrant, first);
  assert.equal(a.settled, false); assert.equal(b.settled, false); assert.equal(f.stops.length, 1);
  f.stops[0].resolve(); await settle(f, a); await settle(f, b);
  assert.equal(a.count, 1); assert.equal(b.count, 1);
});
test('initialize and recovery reject during stop without create/start', async () => {
  const f = await setup(); const destroyed = observed(f.gateway.destroy()); await f.ackClose();
  await rejectCall(f, f.gateway.initialize());
  await rejectCall(f, f.gateway.retryClosedClient());
  assert.equal(f.created(), 1); assert.equal(f.callbacks.length, 1);
  f.stops[0].resolve(); await settle(f, destroyed);
});
test('rejected stop remains destroying; explicit destroy retries only stop', async () => {
  const f = await setup(); const destroyed = observed(f.gateway.destroy()); await f.ackClose();
  f.stops[0].reject(new Error('Injected napi_queue_async_work failure')); await settle(f, destroyed);
  assert.ok(destroyed.error);
  assert.equal(f.gateway.getState(), 'destroying', 'rejected stop must retain destroying');
  await rejectCall(f, f.gateway.initialize()); await rejectCall(f, f.gateway.retryClosedClient());
  assert.equal(f.created(), 1);
  const retry = observed(f.gateway.destroy()); await f.flush();
  assert.equal(f.stops.length, 2); assert.equal(retry.settled, false);
  assert.equal(f.sends.filter(s => s.request['@type'] === 'close').length, 1);
  assert.equal(f.gateway.getClientGeneration(), 1, 'retry does not pretend to retire another client');
  f.stops[1].resolve(); await settle(f, retry); assert.equal(retry.error, undefined);
  assert.equal(f.gateway.getState(), 'idle');
});
test('synchronous native stop throw cannot publish idle', async () => {
  const f = await setup();
  f.native.stopReceiveLoop = () => { throw new Error('Injected native throw'); };
  const destroyed = observed(f.gateway.destroy()); await f.ackClose(); await settle(f, destroyed);
  assert.ok(destroyed.error); assert.equal(f.gateway.getState(), 'destroying');
  await rejectCall(f, f.gateway.initialize()); assert.equal(f.created(), 1);
});
test('startup failure revokes callbacks synchronously and awaits shared stop', async () => {
  const f = await setup(false); const start = f.native.startReceiveLoop;
  f.native.startReceiveLoop = cb => { start(cb); throw new Error('Injected partial start'); };
  const init = observed(f.gateway.initialize());
  assert.equal(f.stops.length, 1); assert.equal(f.gateway.getState(), 'destroying');
  const generation = f.gateway.getClientGeneration(); assert.equal(generation, 1);
  const destroy = observed(f.gateway.destroy());
  f.deliver([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.gateway.getClientGeneration(), generation, 'late callback cannot retire twice');
  assert.equal(init.settled, false, 'startup rejection must wait for cleanup stop');
  assert.equal(destroy.settled, false);
  assert.equal(f.stops.length, 1); assert.equal(f.sends.length, 0, 'no new speculative close API');
  await rejectCall(f, f.gateway.initialize()); assert.equal(f.created(), 0, 'failed receive setup must not allocate');
  f.stops[0].resolve(); await settle(f, init); await settle(f, destroy);
  assert.match(init.error?.message, /TDLib init failed/); assert.equal(destroy.error, undefined);
  assert.equal(f.gateway.getState(), 'idle');
});
test('startup cleanup rejection blocks reinitialize until a successful stop retry', async () => {
  const f = await setup(false); const start = f.native.startReceiveLoop;
  f.native.startReceiveLoop = () => { throw new Error('Injected start failure'); };
  const init = observed(f.gateway.initialize());
  f.stops[0].reject(new Error('Injected stop failure')); await settle(f, init);
  assert.ok(init.error); assert.equal(f.gateway.getState(), 'destroying');
  await rejectCall(f, f.gateway.initialize()); assert.equal(f.created(), 0, 'failed receive setup must not allocate');
  const retry = observed(f.gateway.destroy()); await f.flush();
  assert.equal(f.stops.length, 2); f.stops[1].resolve(); await settle(f, retry);
  f.native.startReceiveLoop = start; await f.gateway.initialize();
  assert.equal(f.created(), 1); assert.equal(f.gateway.getState(), 'ready');
  assert.equal(f.sends.length, 0, 'there was no allocated startup client to close');
});
test('AppCoreRuntime serializes restart behind actual gateway stop completion', async () => {
  const f = await setup(false); const r = await runtimeFixture(f);
  const shutdown = observed(r.runtime.shutdown());
  const restart = observed(r.runtime.initialize());
  await f.ackClose();
  assert.equal(shutdown.settled, false); assert.equal(restart.settled, false);
  assert.equal(f.created(), 1); assert.equal(f.callbacks.length, 1);
  f.stops[0].resolve(); await settle(f, shutdown); await settle(f, restart);
  assert.equal(shutdown.error, undefined); assert.equal(restart.error, undefined);
  assert.equal(f.created(), 2); assert.equal(f.callbacks.length, 2);
  const final = observed(r.runtime.shutdown()); await f.ackClose(2);
  f.stops[1].resolve(); await settle(f, final); assert.equal(final.error, undefined);
});
test('terminal Closed still requires stop barrier but sends no duplicate close', async () => {
  const f = await setup(); f.deliver([auth(1, 'Closed')]); await f.flush();
  const destroyed = observed(f.gateway.destroy()); await f.flush();
  assert.equal(f.sends.length, 0); assert.equal(f.stops.length, 1);
  assert.equal(destroyed.settled, false); assert.equal(f.gateway.getState(), 'destroying');
  f.stops[0].resolve(); await settle(f, destroyed); assert.equal(f.gateway.getState(), 'idle');
});
test('late old-loop batch cannot reach subscribers while stop is pending', async () => {
  const f = await setup(); const seen = [];
  f.gateway.subscribeUpdates(update => seen.push(update.getType()));
  const destroyed = observed(f.gateway.destroy()); await f.ackClose();
  const count = seen.length;
  f.deliver([auth(1, 'Ready'), auth(1, 'Closed')]); await f.flush();
  assert.equal(seen.length, count); assert.equal(f.gateway.getClientGeneration(), 1);
  assert.equal(f.gateway.getGatewayStats().pendingRequests, 0);
  assert.equal(f.gateway.getState(), 'destroying'); assert.equal(f.stops.length, 1);
  f.stops[0].resolve(); await settle(f, destroyed);
});
test('runtime stop rejection requires explicit shutdown retry without creating another client', async () => {
  const f = await setup(false); const r = await runtimeFixture(f);
  const shutdown = observed(r.runtime.shutdown()); await f.ackClose();
  f.stops[0].reject(new Error('Injected queue failure')); await settle(f, shutdown);
  assert.ok(shutdown.error);
  const restart = observed(r.runtime.initialize()); await f.flush();
  assert.equal(restart.settled, true); assert.ok(restart.error);
  assert.equal(f.stops.length, 1, 'initialize must not implicitly retry retirement or grant new scopes');
  assert.equal(f.created(), 1); assert.equal(f.callbacks.length, 1);
  const retry = observed(r.runtime.shutdown()); await f.flush();
  assert.equal(f.stops.length, 2); assert.equal(retry.settled, false);
  f.stops[1].reject(new Error('Injected persistent queue failure')); await settle(f, retry);
  assert.ok(retry.error); assert.equal(f.gateway.getState(), 'destroying');
  assert.equal(f.created(), 1); assert.equal(f.callbacks.length, 1);
  assert.equal(f.sends.filter(s => s.request['@type'] === 'close').length, 1);
});

async function negativeControls() {
  const gatewayPath = path.resolve(__dirname, '../entry/src/main/ets/infra/td/gateway/TdGateway.ets');
  const originalRead = fs.readFileSync;
  const originalBytes = originalRead(gatewayPath);
  const source = originalBytes.toString('utf8').replace(/\r\n/g, '\n');
  const warn = 'Logger.warn(`TDLib stopReceiveLoop failed during shutdown: ${String(error)}`);';
  const sharedDestroy = 'destroy(): Promise<void> {\n    if (this.shutdownPromise) return this.shutdownPromise;';
  const mutations = [
    { id: 'remove-await-stop', from: 'await tdlib.stopReceiveLoop();', to: 'tdlib.stopReceiveLoop();',
      test: 'destroy holds destroying/Promise until native stop completes',
      assertion: 'stop completion is part of destroy', actual: true, expected: false },
    { id: 'early-idle-on-reject', from: warn, to: `this.state = 'idle';\n        ${warn}`,
      test: 'rejected stop remains destroying; explicit destroy retries only stop',
      assertion: 'rejected stop must retain destroying', actual: 'idle', expected: 'destroying' },
    { id: 'concurrent-destroy-early-success', from: sharedDestroy,
      to: 'destroy(): Promise<void> {\n    if (this.shutdownPromise) return Promise.resolve();',
      test: 'concurrent/reentrant destroy shares the whole operation, not early success',
      assertion: 'same shutdown Promise before close completes', promises: true },
    { id: 'remove-await-cleanup', from: 'await this.cleanupAfterInitializeFailure();',
      to: 'this.cleanupAfterInitializeFailure();',
      test: 'startup failure revokes callbacks synchronously and awaits shared stop',
      assertion: 'startup rejection must wait for cleanup stop', actual: true, expected: false }
  ];
  const mutantHashes = new Set();
  let passed = 0;
  for (const mutation of mutations) {
    // Exactly one replacement; stale anchors or unchanged/duplicate mutants are harness errors.
    assert.equal(source.split(mutation.from).length - 1, 1, `unique anchor: ${mutation.id}`);
    const mutated = source.replace(mutation.from, mutation.to);
    assert.notEqual(mutated, source);
    const digest = createHash('sha256').update(mutated).digest('hex');
    assert.equal(mutantHashes.has(digest), false, 'mutants must be unique');
    mutantHashes.add(digest);
    const target = tests.find(([name]) => name === mutation.test);
    assert.ok(target, `named behavioral test exists: ${mutation.test}`);
    let reads = 0, failure;
    // Existing loaders read Gateway on fixture creation. Only that exact read is
    // intercepted; no production/test file is written, and no methods are mocked.
    fs.readFileSync = function(file, ...args) {
      const result = originalRead.call(this, file, ...args);
      if (typeof file === 'string' && path.resolve(file) === gatewayPath) {
        assert.equal(args[0], 'utf8', 'actual fixture must load Gateway source as text');
        assert.equal(result.replace(/\r\n/g, '\n'), source, 'source drift during negative control');
        reads++;
        return mutated;
      }
      return result;
    };
    try { await target[1](); }
    catch (error) { failure = error; }
    finally { fs.readFileSync = originalRead; }
    assert.equal(reads, 1, `actual Gateway load engaged once: ${mutation.id}`);
    assert.ok(failure instanceof assert.AssertionError,
      `${mutation.id}: must fail the named behavioral assertion, not pass/compile/throw unexpectedly; got ${failure}`);
    assert.equal(failure.code, 'ERR_ASSERTION');
    assert.equal(failure.operator, 'strictEqual');
    assert.ok(failure.message.includes(mutation.assertion),
      `${mutation.id}: wrong failing assertion: ${failure.message}`);
    if (mutation.promises) {
      assert.ok(failure.actual instanceof Promise && failure.expected instanceof Promise);
      assert.notEqual(failure.actual, failure.expected);
      const early = observed(failure.actual), pending = observed(failure.expected);
      await new Promise(resolve => setImmediate(resolve));
      assert.equal(early.settled, true, 'mutant destroy actually returned early success');
      assert.equal(pending.settled, false, 'original shutdown still waits for close');
    } else {
      assert.equal(failure.actual, mutation.actual);
      assert.equal(failure.expected, mutation.expected);
    }
    assert.deepEqual(originalRead(gatewayPath), originalBytes, 'production bytes must remain untouched');
    passed++;
    console.log(`PASS negative-control ${mutation.id}: ERR_ASSERTION ${mutation.assertion}`);
  }
  console.log(`${passed}/${mutations.length} unique in-memory negative controls rejected by exact behavioral assertions`);
}

async function main() {
  let passed = 0;
  for (const [name, run] of tests) {
    try { await run(); console.log('PASS ' + name); passed++; }
    catch (error) { console.error('FAIL ' + name + '\n' + error.stack); }
  }
  console.log(`${passed}/${tests.length} actual-source stop-barrier tests PASS`);
  if (passed === tests.length && process.argv.includes('--negative-controls')) await negativeControls();
  for (const file of ['entry/src/main/ets/infra/td/gateway/TdGateway.ets',
    'entry/src/main/ets/types/libtdlib_napi.d.ts', 'entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets']) {
    console.log('SHA256 ' + file + ' ' + createHash('sha256').update(fs.readFileSync(path.join(__dirname, '..', file))).digest('hex'));
  }
  if (passed !== tests.length) process.exitCode = 1;
}
main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
