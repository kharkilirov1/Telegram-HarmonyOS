// Node >= 24. Real gateway, dispatcher, TdObject and AppError; only NAPI/timers are fixtures.
// Transport witnesses only: account cleanup/auth/UI are the runtime integration suite's scope.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(relative, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  const names = [...source.matchAll(/^export\s+(?:default\s+)?(?:async\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, ''),
    { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
const auth = (id, state) => ({ '@type': 'updateAuthorizationState', '@client_id': id,
  authorization_state: { '@type': `authorizationState${state}` } });
const update = id => ({ '@type': 'updateUser', '@client_id': id, user: { '@type': 'user', id: 7 } });
const observed = promise => {
  const result = { settled: false, value: undefined, error: undefined, count: 0 };
  promise.then(value => Object.assign(result, { settled: true, value, count: result.count + 1 }),
    error => Object.assign(result, { settled: true, error, count: result.count + 1 }));
  return result;
};
async function fixture(hooks, initialize = true) {
  const logs = [], sends = [], callbacks = [], timers = new Map();
  let nextTimer = 0, created = 0, stopped = 0;
  const hilog = { info() {}, warn() {}, debug() {}, error(...args) { logs.push(args); } };
  const { TdObject } = load('models/td/common/index.ets');
  const errors = load('core/model/AppError.ets');
  const { MainThreadDispatcher } = load('infra/threading/MainThreadDispatcher.ets', { hilog });
  const dispatcher = new MainThreadDispatcher();
  const native = {
    createClient() { return ++created; },
    startReceiveLoop(callback) { callbacks.push(callback); },
    stopReceiveLoop() { stopped++; },
    send(id, json) { sends.push({ id, request: JSON.parse(json) }); }
  };
  const { TdGatewayImpl, getMethodTimeout } = load('infra/td/gateway/TdGateway.ets', {
    ...errors, TdObject, hilog, tdlib: native, getMainThreadDispatcher: () => dispatcher,
    setTimeout(fn, ms) { const id = ++nextTimer; timers.set(id, { fn, ms }); return id; },
    clearTimeout(id) { timers.delete(id); }
  });
  const gateway = TdGatewayImpl.getInstance();
  dispatcher.subscribeUpdates(raw => gateway.handleUpdateOnMainThread(raw));
  // Baseline can execute actual Closed without this not-yet-implemented API.
  // Recovery assertions below still require the hook to engage (not a fixture fallback).
  if (hooks && gateway.setClientRecoveryHooks) gateway.setClientRecoveryHooks(hooks);
  if (initialize) await gateway.initialize();
  const f = { gateway, dispatcher, native, sends, callbacks, timers, logs, TdObject, getMethodTimeout,
    created: () => created, stopped: () => stopped,
    emit(value) { callbacks[0](JSON.stringify(value)); },
    drainSync() {
      let budget = 100;
      for (;;) {
        const entry = [...timers].find(([, timer]) => timer.ms <= 250);
        if (!entry) return;
        assert.ok(--budget > 0, 'drain must be bounded');
        timers.delete(entry[0]); entry[1].fn();
      }
    },
    async flush() { f.drainSync(); await tick(); f.drainSync(); await tick(); },
    reply(send, type = 'ok', id = send.id) {
      f.emit([{ '@type': type, '@client_id': id, '@extra': send.request['@extra'] }]);
    },
    async settleBootstrap() {
      for (const send of sends.filter(s => s.request['@type'] === 'getAuthorizationState')) {
        f.reply(send, 'authorizationStateWaitTdlibParameters');
      }
      await f.flush();
    },
    cleanDispatcher() {
      assert.equal(dispatcher.getStats().handlerErrors, 0, 'no swallowed dispatcher errors');
      assert.deepEqual(logs, [], 'no swallowed gateway errors');
    }
  };
  return f;
}
const hooks = (overrides = {}) => ({ beforeRestart: async () => {}, afterRestart() {}, onFailure() {}, ...overrides });
const tests = [];
const test = (name, run) => tests.push([name, run]);

test('native receive startup failure rejects initialization; retry restores the response path', async () => {
  const f = await fixture(undefined, false);
  const start = f.native.startReceiveLoop;
  f.native.startReceiveLoop = () => { throw new Error('Cannot create TDLib receive callback'); };
  await assert.rejects(f.gateway.initialize(), error =>
    error.kind === 'NETWORK' && error.retryable === true &&
    error.message.includes('Cannot create TDLib receive callback'));
  assert.equal(f.gateway.getState(), 'idle');
  assert.equal(f.gateway.isReady(), false);
  assert.equal(f.stopped(), 1);
  assert.equal(f.callbacks.length, 0);
  assert.equal(f.gateway.getGatewayStats().pendingRequests, 0);
  await assert.rejects(f.gateway.send('getMe'));
  assert.equal(f.sends.length, 0, 'failed init must not expose a usable transport');
  assert.equal(f.created(), 0, 'failed receive setup must not allocate an orphan client ID');
  f.native.startReceiveLoop = start;
  await f.gateway.initialize();
  assert.equal(f.gateway.isReady(), true);
  assert.equal(f.created(), 1, 'retry allocates the first client only after receive succeeds');
  assert.equal(f.callbacks.length, 1);
  // AppCoreRuntime owns update subscriptions and reattaches them on its retry.
  // Here exercise the response subscription actually owned by gateway.initialize.
  const response = observed(f.gateway.send('getMe'));
  f.reply(f.sends[0], 'user'); await f.flush();
  assert.equal(response.value?.getType(), 'user', 'retry must restore delivery, not only ready state');
  assert.equal(response.count, 1);
  f.cleanDispatcher();
});

test('Closed without runtime hooks is terminal; explicit initialize creates client2 with the same loop', async () => {
  const f = await fixture();
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.gateway.isReady(), false, 'Closed cannot leave transport ready');
  assert.equal(f.created(), 1, 'no unsafe automatic recovery without account barrier');
  await f.gateway.initialize();
  assert.equal(f.created(), 2);
  assert.equal(f.callbacks.length, 1);
  assert.equal(f.stopped(), 0);
  f.cleanDispatcher();
});

test('native Closed invokes synchronous invalidation barrier; bootstrap and hook requests use client2', async () => {
  const barrier = deferred(), events = [];
  let f;
  f = await fixture(hooks({
    beforeRestart() {
      events.push(['before', f.gateway.getClientGeneration(), f.gateway.isReady(), f.gateway.getGatewayStats().pendingRequests]);
      return barrier.promise;
    },
    afterRestart() { events.push(['after', f.gateway.getClientGeneration()]); observed(f.gateway.send('setTdlibParameters')); }
  }));
  assert.equal(f.gateway.getClientGeneration?.(), 0, 'initial initialize must not stale preconstructed adapters');
  const seen = [];
  f.gateway.subscribeUpdates(u => seen.push(u.getType()));
  const old = observed(f.gateway.send('getMe'));
  f.emit([auth(1, 'Closed'), update(1)]); f.drainSync();
  assert.deepEqual(events, [['before', 1, false, 0]], 'barrier called before returning from dispatch');
  assert.equal(f.created(), 1);
  barrier.resolve(); await f.flush();
  assert.equal(old.error?.retryable, false);
  assert.deepEqual(events, [['before', 1, false, 0], ['after', 1]]);
  assert.equal(f.created(), 2);
  assert.deepEqual(f.sends[1], { id: 2, request: { '@type': 'setTdlibParameters', '@extra': f.sends[1].request['@extra'] } });
  assert.equal(f.sends.find(s => s.request['@type'] === 'getAuthorizationState')?.id, 2);
  f.emit([update(2)]); await f.flush();
  assert.deepEqual(seen, ['updateAuthorizationState', 'updateUser']);
  assert.equal(f.callbacks.length, 1); assert.equal(f.stopped(), 0);
  f.cleanDispatcher();
});

test('old client responses cannot steal new @extra through batch, single fallback or direct dispatcher', async () => {
  const f = await fixture(hooks());
  f.emit([auth(1, 'Closed')]); await f.flush(); await f.settleBootstrap();
  const result = observed(f.gateway.send('getMe'));
  const send = f.sends.at(-1);
  assert.equal(send.id, 2, 'automatic recovery must engage');
  const stale = { '@type': 'user', '@client_id': 1, '@extra': send.request['@extra'] };
  f.emit([stale]); f.emit(stale); f.dispatcher.dispatchResponse(JSON.stringify(stale));
  await f.flush();
  assert.equal(result.settled, false);
  assert.equal(f.gateway.getGatewayStats().pendingRequests, 1);
  f.reply(send, 'user'); await f.flush();
  assert.equal(result.value?.getType(), 'user'); assert.equal(result.count, 1);
  assert.equal(f.gateway.getGatewayStats().pendingRequests, 0);
  f.cleanDispatcher();
});

test('every envelope needs a top-level current client_id, including single update and direct dispatcher', async () => {
  const f = await fixture(); const seen = [];
  f.gateway.subscribeUpdates(u => seen.push(u.getType()));
  const bad = [update(2), { ...update(1), '@client_id': '1' }, { '@type': 'updateUser' },
    { '@type': 'updateUser', user: { '@client_id': 1 } }, null, 42];
  f.emit(bad);
  for (const value of bad) { f.emit(value); f.dispatcher.dispatchUpdate(JSON.stringify(value)); f.dispatcher.dispatchResponse(JSON.stringify(value)); }
  await f.flush();
  assert.deepEqual(seen, [], 'malformed/missing/stale identity cannot enter state');
  f.emit(update(1)); await f.flush();
  assert.deepEqual(seen, ['updateUser']);
  f.cleanDispatcher();
});

test('duplicate Closed and queued old batch tail neither restart twice nor leak updates', async () => {
  let before = 0, after = 0;
  const barrier = deferred();
  const f = await fixture(hooks({ beforeRestart() { before++; return barrier.promise; }, afterRestart() { after++; } }));
  const seen = []; f.gateway.subscribeUpdates(u => seen.push(u.getType()));
  f.emit([auth(1, 'Closed'), auth(1, 'Closed'), update(1)]); f.emit([update(1)]);
  f.drainSync();
  assert.equal(before, 1); assert.equal(f.gateway.getClientGeneration(), 1);
  assert.equal(f.gateway.isDrainCongested(), false);
  f.emit(auth(1, 'Closed')); f.drainSync();
  barrier.resolve(); await f.flush(); await f.settleBootstrap();
  f.emit([auth(1, 'Closed'), update(1)]); f.emit(auth(1, 'Closed')); await f.flush();
  assert.equal(f.created(), 2); assert.equal(before, 1); assert.equal(after, 1);
  assert.deepEqual(seen, ['updateAuthorizationState']);
  assert.equal(f.timers.size, 0); f.cleanDispatcher();
});

test('Closed clears pending and timeouts exactly once before listeners observe it', async () => {
  const f = await fixture();
  const result = observed(f.gateway.send('downloadFile'));
  const lateTimeout = [...f.timers.values()][0].fn;
  let snapshot;
  f.gateway.subscribeUpdates(() => { snapshot = [f.gateway.isReady(), f.gateway.getGatewayStats().pendingRequests]; });
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.deepEqual(snapshot, [false, 0]);
  assert.equal(result.error?.retryable, false); assert.equal(result.count, 1); assert.equal(f.timers.size, 0);
  lateTimeout(); await tick();
  assert.equal(f.gateway.getGatewayStats().timeouts, 0); assert.equal(result.count, 1);
});

test('sleeping retry cannot send old-account command after client generation changes', async () => {
  const f = await fixture(hooks());
  const result = observed(f.gateway.sendWithRetry('getChat', undefined, 3, 1000));
  const first = f.sends[0];
  f.emit([{ '@type': 'error', '@client_id': 1, '@extra': first.request['@extra'], code: 500, message: 'Temporary network error' }]);
  await f.flush();
  const backoff = [...f.timers].find(([, t]) => t.ms === 1000);
  assert.ok(backoff, 'real retry path entered backoff');
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.created(), 2);
  f.timers.delete(backoff[0]); backoff[1].fn(); await tick();
  assert.equal(result.error?.retryable, false);
  assert.equal(f.sends.filter(s => s.request['@type'] === 'getChat').length, 1);
});

for (const closedFirst of [true, false]) test(`destroy preserves close response/waiter (Closed first=${closedFirst}) without recovery`, async () => {
  let barriers = 0;
  const f = await fixture(hooks({ beforeRestart: async () => { barriers++; } }));
  const old = observed(f.gateway.send('getMe'));
  const destroyed = observed(f.gateway.destroy());
  const close = f.sends.at(-1);
  assert.equal(close.request['@type'], 'close');
  const response = { '@type': 'ok', '@client_id': 1, '@extra': close.request['@extra'] };
  f.emit(closedFirst ? [auth(1, 'Closed'), response] : [response, auth(1, 'Closed')]);
  await f.flush();
  assert.equal(destroyed.settled, true); assert.equal(destroyed.error, undefined);
  assert.equal(old.error?.retryable, false);
  assert.equal(f.gateway.getState(), 'idle'); assert.equal(f.created(), 1); assert.equal(barriers, 0);
  assert.equal(f.stopped(), 1); assert.equal(f.timers.size, 0);
  assert.equal(f.gateway.getClientGeneration(), 1);
  f.emit([auth(1, 'Closed'), update(1)]); await f.flush();
  assert.equal(f.timers.size, 0); assert.equal(f.created(), 1);
  f.cleanDispatcher();
});

test('destroy during awaited barrier cancels recovery and late hooks/callbacks', async () => {
  const barrier = deferred(); let after = 0;
  const f = await fixture(hooks({ beforeRestart: () => barrier.promise, afterRestart() { after++; } }));
  f.emit([auth(1, 'Closed')]); f.drainSync();
  assert.equal(f.gateway.isReady(), false);
  const destroyed = observed(f.gateway.destroy()); await f.flush();
  barrier.resolve(); await f.flush();
  assert.equal(destroyed.settled, true); assert.equal(f.created(), 1); assert.equal(after, 0);
  assert.equal(f.gateway.getState(), 'idle'); assert.equal(f.gateway.getClientGeneration(), 2);
  f.emit([auth(1, 'Closed')]); await f.flush(); assert.equal(f.timers.size, 0);
});

test('second bootstrap Closed still runs cleanup, fails visibly, then manual retry is single-flight', async () => {
  let barriers = 0, after = 0; const failures = [], manualBarrier = deferred();
  const f = await fixture(hooks({ beforeRestart() { barriers++; return barriers === 3 ? manualBarrier.promise : Promise.resolve(); },
    afterRestart() { after++; }, onFailure(error) { failures.push(error); } }));
  f.emit([auth(1, 'Closed')]); await f.flush();
  f.emit([auth(2, 'Closed')]); await f.flush();
  assert.equal(f.created(), 2, 'bounded to one auto attempt without Ready');
  assert.equal(barriers, 2, 'even exhausted budget clears account state');
  assert.equal(f.gateway.getState(), 'failed'); assert.equal(failures.length, 1);
  assert.equal(failures[0].retryable, true); assert.equal(f.timers.size, 0);
  const a = observed(f.gateway.retryClosedClient()); const b = observed(f.gateway.retryClosedClient());
  const init = observed(f.gateway.initialize());
  assert.equal(barriers, 3); assert.equal(f.created(), 2);
  manualBarrier.resolve(); await f.flush();
  assert.equal(f.created(), 3); assert.equal(after, 2);
  assert.equal(a.settled && b.settled && init.settled, true, 'retry cannot await unreceived bootstrap response');
  assert.equal(a.error || b.error || init.error, undefined);
  f.emit([auth(3, 'Closed')]); await f.flush();
  assert.equal(f.created(), 3, 'manual retry does not silently renew automatic budget');
  assert.equal(barriers, 4); assert.equal(failures.length, 2); assert.equal(f.timers.size, 0);
});

test('create failure is visible and bounded; manual initialize honors the barrier', async () => {
  let before = 0, attempts = 0; const failures = [], barrier = deferred();
  const f = await fixture(hooks({ beforeRestart() { before++; return before === 2 ? barrier.promise : Promise.resolve(); },
    onFailure(error) { failures.push(error); } }));
  const create = f.native.createClient;
  f.native.createClient = () => { if (++attempts === 1) throw new Error('create failed'); return create(); };
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(attempts, 1); assert.equal(f.gateway.getState(), 'failed'); assert.equal(failures.length, 1);
  assert.equal(f.timers.size, 0);
  const retry = observed(f.gateway.initialize());
  assert.equal(before, 2); assert.equal(attempts, 1);
  barrier.resolve(); await f.flush();
  assert.equal(retry.settled, true); assert.equal(retry.error, undefined); assert.equal(attempts, 2);
  assert.equal(f.created(), 2); assert.equal(f.callbacks.length, 1); assert.equal(f.stopped(), 0);
});

for (const mode of ['Ready', 'logOut']) test(`only native Ready or explicit logOut renews auto budget (${mode})`, async () => {
  const f = await fixture(hooks());
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.created(), 2);
  if (mode === 'Ready') { f.emit([auth(2, 'Ready')]); await f.flush(); }
  else { observed(f.gateway.send('logOut')); f.reply(f.sends.at(-1)); await f.flush(); }
  assert.equal(f.created(), 2, 'logOut ok or Ready is not terminal');
  f.emit([auth(2, 'LoggingOut'), auth(2, 'Closing')]); await f.flush();
  assert.equal(f.created(), 2);
  f.emit([auth(2, 'Closed')]); await f.flush(); assert.equal(f.created(), 3);
  if (mode === 'logOut') {
    observed(f.gateway.send('logOut')); f.emit([auth(3, 'Closed')]); await f.flush();
    assert.equal(f.created(), 4, 'wrong-number reset may repeat before Ready');
  }
});

test('detaching runtime hooks during barrier prevents unguarded recreation', async () => {
  const barrier = deferred(); let after = 0;
  const f = await fixture(hooks({ beforeRestart: () => barrier.promise, afterRestart() { after++; } }));
  f.emit([auth(1, 'Closed')]); f.drainSync();
  assert.equal(f.gateway.isReady(), false);
  f.gateway.setClientRecoveryHooks(); barrier.resolve(); await f.flush();
  assert.equal(f.created(), 1); assert.equal(after, 0); assert.equal(f.gateway.getState(), 'closed');
  assert.equal(f.timers.size, 0);
});

test('destroy replaces an already scheduled old-generation drain and still receives close flow', async () => {
  const f = await fixture(hooks()); const seen = [];
  f.gateway.subscribeUpdates(u => seen.push(u.getType()));
  f.emit([update(1)]); // Existing drain timer is still pending when destroy invalidates generation.
  const oldDrain = [...f.timers.values()][0].fn;
  const destroyed = observed(f.gateway.destroy());
  const close = f.sends.at(-1);
  f.emit([auth(1, 'Closed'), { '@type': 'ok', '@client_id': 1, '@extra': close.request['@extra'] }]);
  oldDrain(); await f.flush();
  assert.equal(destroyed.settled, true, 'old scheduled drain must not strand the close request');
  assert.deepEqual(seen, ['updateAuthorizationState']); assert.equal(f.timers.size, 0);
});

test('bootstrap send failure is visible without losing a live client needed for explicit shutdown', async () => {
  const failures = [];
  const f = await fixture(hooks({ onFailure(error) { failures.push(error); } }));
  const send = f.native.send;
  f.native.send = (id, json) => {
    if (id === 2 && JSON.parse(json)['@type'] === 'getAuthorizationState') throw new Error('bootstrap unavailable');
    send(id, json);
  };
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.gateway.getState(), 'failed'); assert.equal(failures.length, 1);
  const destroyed = observed(f.gateway.destroy());
  assert.equal(f.sends.at(-1)?.request['@type'], 'close', 'failed live native client still must be closed');
  assert.equal(f.sends.at(-1).id, 2);
  f.reply(f.sends.at(-1)); f.emit([auth(2, 'Closed')]); await f.flush();
  assert.equal(destroyed.settled, true); assert.equal(f.timers.size, 0); assert.equal(f.created(), 2);
});

test('late native Closed after failed bootstrap retires that client before manual retry', async () => {
  let barriers = 0; const failures = [];
  const f = await fixture(hooks({ beforeRestart: async () => { barriers++; }, onFailure(error) { failures.push(error); } }));
  const send = f.native.send;
  f.native.send = (id, json) => {
    if (id === 2 && JSON.parse(json)['@type'] === 'getAuthorizationState') throw new Error('bootstrap unavailable');
    send(id, json);
  };
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.gateway.getState(), 'failed');
  f.emit([auth(2, 'Closed'), update(2)]); await f.flush();
  assert.equal(barriers, 2, 'Closed after bootstrap failure still needs account cleanup');
  assert.equal(f.created(), 2, 'no renewed auto budget');
  const retried = observed(f.gateway.retryClosedClient()); await f.flush();
  assert.equal(retried.settled, true); assert.equal(retried.error, undefined);
  assert.equal(f.created(), 3, 'cannot reuse a native client which has closed');
  assert.equal(f.sends.at(-1).id, 3);
});

test('rejected account barrier cannot create clients and is observable; manual retry runs a new barrier', async () => {
  let before = 0, after = 0; const failures = [];
  const f = await fixture(hooks({ beforeRestart() { before++; return before === 1 ? Promise.reject(new Error('barrier failed')) : Promise.resolve(); },
    afterRestart() { after++; }, onFailure(error) { failures.push(error); } }));
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.created(), 1); assert.equal(after, 0); assert.equal(f.gateway.getState(), 'failed');
  assert.equal(failures.length, 1); assert.equal(f.timers.size, 0);
  const retried = observed(f.gateway.retryClosedClient()); await f.flush();
  assert.equal(retried.settled, true); assert.equal(retried.error, undefined);
  assert.equal(before, 2); assert.equal(after, 1); assert.equal(f.created(), 2);
});

test('single fallback Closed engages the same automatic recovery path', async () => {
  let before = 0;
  const f = await fixture(hooks({ beforeRestart: async () => { before++; } }));
  f.emit(auth(1, 'Closed')); await f.flush();
  assert.equal(f.created(), 2); assert.equal(before, 1); assert.equal(f.sends[0].id, 2);
  f.cleanDispatcher();
});

test('old native callback and old drain cannot affect reinitialized gateway even with forged new client_id', async () => {
  const barrier = deferred();
  const f = await fixture(hooks({ beforeRestart: () => barrier.promise }));
  f.emit([auth(1, 'Closed')]); const oldDrain = [...f.timers.values()][0].fn; f.drainSync();
  await f.gateway.destroy();
  f.gateway.setClientRecoveryHooks();
  f.dispatcher.subscribeUpdates(raw => f.gateway.handleUpdateOnMainThread(raw));
  await f.gateway.initialize();
  const seen = []; f.gateway.subscribeUpdates(u => seen.push(u.getType()));
  const pending = observed(f.gateway.send('getMe')); const send = f.sends.at(-1);
  const response = { '@type': 'user', '@client_id': 2, '@extra': send.request['@extra'] };
  f.callbacks[0](JSON.stringify([response, update(2), auth(2, 'Closed')])); oldDrain(); await f.flush();
  assert.equal(pending.settled, false); assert.deepEqual(seen, []); assert.equal(f.gateway.isReady(), true);
  barrier.resolve(); await f.flush();
  f.callbacks[1](JSON.stringify([response, update(2)])); await f.flush();
  assert.equal(pending.value?.getType(), 'user'); assert.deepEqual(seen, ['updateUser']);
  assert.equal(f.created(), 2); assert.equal(f.timers.size, 0);
});

test('reentrant destroy from an update subscriber suppresses remaining stale subscribers', async () => {
  const f = await fixture(); const seen = []; let destroyed;
  f.gateway.subscribeUpdates(u => { if (u.getType() === 'updateUser') destroyed = observed(f.gateway.destroy()); });
  f.gateway.subscribeUpdates(u => seen.push(u.getType()));
  f.emit([update(1)]); await f.flush();
  assert.deepEqual(seen, [], 'a captured handler snapshot must not outlive its generation');
  f.reply(f.sends.at(-1)); f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(destroyed.settled, true);
  assert.deepEqual(seen, ['updateAuthorizationState']);
});

test('normal same-generation retry remains functional and bounded', async () => {
  const f = await fixture();
  const result = observed(f.gateway.sendWithRetry('getMe', undefined, 2, 1000));
  f.emit([{ '@type': 'error', '@client_id': 1, '@extra': f.sends[0].request['@extra'], code: 500, message: 'Temporary network error' }]);
  await f.flush();
  const backoff = [...f.timers].find(([, t]) => t.ms === 1000);
  assert.ok(backoff); f.timers.delete(backoff[0]); backoff[1].fn(); await tick();
  assert.equal(f.sends.length, 2); assert.equal(f.sends[1].id, 1);
  f.reply(f.sends[1], 'user'); await f.flush();
  assert.equal(result.value?.getType(), 'user'); assert.equal(f.timers.size, 0);
});

test('failed bootstrap invalidates sleeping retry even when manual retry reuses the live native ID', async () => {
  const f = await fixture(hooks());
  f.emit([auth(1, 'Closed')]); await f.flush();
  const bootstrap = f.sends.find(s => s.request['@type'] === 'getAuthorizationState');
  assert.equal(bootstrap?.id, 2);
  const result = observed(f.gateway.sendWithRetry('getChat', undefined, 2, 1000));
  const failedResponse = send => ({ '@type': 'error', '@client_id': 2,
    '@extra': send.request['@extra'], code: 500, message: 'Temporary network error' });
  f.emit([failedResponse(f.sends.at(-1))]); await f.flush();
  const backoff = [...f.timers].find(([, t]) => t.ms === 1000); assert.ok(backoff);
  f.emit([failedResponse(bootstrap)]); await f.flush();
  assert.equal(f.gateway.getState(), 'failed');
  observed(f.gateway.retryClosedClient()); await f.flush();
  assert.equal(f.gateway.isReady(), true); assert.equal(f.created(), 2, 'must not orphan an unclosed native client');
  f.timers.delete(backoff[0]); backoff[1].fn(); await tick();
  assert.equal(result.error?.retryable, false, 'failed scope cannot come back to life on manual retry');
  assert.equal(f.sends.filter(s => s.request['@type'] === 'getChat').length, 1);
});

test('invalid recovery client ID fails without sending bootstrap or restarting the loop', async () => {
  const failures = [];
  const f = await fixture(hooks({ onFailure(error) { failures.push(error); } }));
  f.native.createClient = () => 0;
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.gateway.getState(), 'failed'); assert.equal(failures.length, 1);
  assert.equal(f.sends.length, 0); assert.equal(f.callbacks.length, 1); assert.equal(f.timers.size, 0);
});

for (const failureMode of ['error', 'timeout']) test(`Ready/getMeB cannot be demoted by late bootstrap ${failureMode}`, async () => {
  const failures = [], states = [];
  const f = await fixture(hooks({ onFailure(error) { failures.push(error); } }));
  f.gateway.subscribeUpdates(u => { if (u.getType() === 'updateAuthorizationState') states.push(u.getObject('authorization_state').getType()); });
  f.emit([auth(1, 'Closed')]); await f.flush();
  const bootstrap = f.sends.find(s => s.request['@type'] === 'getAuthorizationState');
  assert.equal(bootstrap?.id, 2);
  const bootstrapTimeout = [...f.timers].find(([, t]) => t.ms === 30000);
  assert.ok(bootstrapTimeout);
  f.emit([auth(2, 'Ready')]); await f.flush();
  const me = observed(f.gateway.send('getMe'));
  f.emit([{ '@type': 'user', '@client_id': 2, '@extra': f.sends.at(-1).request['@extra'], id: 202, first_name: 'B' }]);
  await f.flush(); assert.equal(me.value?.getNumber('id'), 202);
  const generation = f.gateway.getClientGeneration();
  const pending = observed(f.gateway.send('getChats')); const query = f.sends.at(-1);
  if (failureMode === 'error') {
    f.emit([{ '@type': 'error', '@client_id': 2, '@extra': bootstrap.request['@extra'], code: 500, message: 'Late bootstrap error' }]);
  } else {
    f.timers.delete(bootstrapTimeout[0]); bootstrapTimeout[1].fn();
  }
  await f.flush();
  assert.equal(f.gateway.getState(), 'ready', 'the bootstrap probe cannot overrule native Ready');
  assert.deepEqual(failures, [], 'runtime must not receive a false recovery failure after getMeB');
  assert.equal(f.gateway.getClientGeneration(), generation, 'B scopes remain valid');
  assert.equal(pending.settled, false, 'live B requests must not be rejected by the obsolete probe');
  f.reply(query, 'chats'); await f.flush();
  assert.equal(pending.value?.getType(), 'chats'); assert.equal(f.gateway.getGatewayStats().pendingRequests, 0);
  assert.deepEqual(states, ['authorizationStateClosed', 'authorizationStateReady']);
  assert.equal(f.created(), 2); assert.equal(f.callbacks.length, 1); f.cleanDispatcher();
});

// td_api.tl AuthorizationState: each listed state asks the caller for an actual
// initialization/login step, or confirms authorized readiness. Closing states do not.
for (const liveState of ['WaitTdlibParameters', 'WaitPhoneNumber', 'WaitPremiumPurchase', 'WaitEmailAddress',
  'WaitEmailCode', 'WaitCode', 'WaitOtherDeviceConfirmation', 'WaitRegistration', 'WaitPassword', 'Ready']) {
  test(`native ${liveState} confirms bootstrap without forgiving a subsequent Closed`, async () => {
    const failures = [];
    const f = await fixture(hooks({ onFailure(error) { failures.push(error); } }));
    f.emit([auth(1, 'Closed')]); await f.flush();
    const bootstrap = f.sends.find(s => s.request['@type'] === 'getAuthorizationState');
    // Error resolution and live auth update in the same drain: rejection continuation
    // must re-check the evidence, not rely on state captured when the probe was sent.
    f.emit([{ '@type': 'error', '@client_id': 2, '@extra': bootstrap.request['@extra'], code: 500, message: 'Obsolete probe' },
      auth(2, liveState)]);
    await f.flush();
    assert.equal(f.gateway.getState(), 'ready', `${liveState} is native bootstrap evidence`);
    assert.equal(failures.length, 0); assert.equal(f.gateway.getClientGeneration(), 1);
    assert.equal(f.timers.size, 0);
    f.emit([auth(2, 'Closed')]); await f.flush();
    if (liveState === 'Ready') {
      assert.equal(f.created(), 3, 'only Ready renews automatic recovery budget');
      assert.equal(failures.length, 0);
      // The new generation has no bootstrap evidence: B confirmation must not mask C failure.
      const next = f.sends.at(-1);
      f.emit([{ '@type': 'error', '@client_id': 3, '@extra': next.request['@extra'], code: 500, message: 'C bootstrap failed' }]);
      await f.flush(); assert.equal(f.gateway.getState(), 'failed'); assert.equal(failures.length, 1);
    } else {
      assert.equal(f.created(), 2, 'login progress must not renew automatic recovery budget');
      assert.equal(f.gateway.getState(), 'failed'); assert.equal(failures.length, 1);
    }
    f.cleanDispatcher();
  });
}

for (const state of ['LoggingOut', 'Closing', 'UnknownFutureState']) test(`${state} alone is not live bootstrap evidence`, async () => {
  const failures = [];
  const f = await fixture(hooks({ onFailure(error) { failures.push(error); } }));
  f.emit([auth(1, 'Closed')]); await f.flush();
  const bootstrap = f.sends.find(s => s.request['@type'] === 'getAuthorizationState');
  f.emit([auth(2, state), { '@type': 'error', '@client_id': 2, '@extra': bootstrap.request['@extra'], code: 500, message: 'Bootstrap failed' }]);
  await f.flush(); assert.equal(f.gateway.getState(), 'failed'); assert.equal(failures.length, 1);
});

test('stale auth Ready and ordinary current updates cannot confirm new-client bootstrap', async () => {
  const failures = [];
  const f = await fixture(hooks({ onFailure(error) { failures.push(error); } }));
  f.emit([auth(1, 'Closed')]); await f.flush();
  const bootstrap = f.sends.find(s => s.request['@type'] === 'getAuthorizationState');
  f.emit([auth(1, 'Ready'), update(2), { '@type': 'error', '@client_id': 2,
    '@extra': bootstrap.request['@extra'], code: 500, message: 'Bootstrap failed' }]);
  await f.flush(); assert.equal(f.gateway.getState(), 'failed'); assert.equal(failures.length, 1);
});

for (const thrown of ['barrier string failure', null]) test(`recovery normalizes non-Error throw ${String(thrown)}`, async () => {
  const failures = [];
  const f = await fixture(hooks({ beforeRestart() { throw thrown; }, onFailure(error) { failures.push(error); } }));
  f.emit([auth(1, 'Closed')]); await f.flush();
  assert.equal(f.gateway.getState(), 'failed'); assert.equal(f.created(), 1);
  assert.equal(failures.length, 1); assert.equal(failures[0].technicalMessage, String(thrown));
  assert.equal(failures[0].retryable, true); assert.equal(f.timers.size, 0);
});

test('existing TdGateway.test.ets timeout/state/singleton suite executes against actual source', async () => {
  const f = await fixture(undefined, false); const cases = [];
  load('../../ohosTest/ets/test/TdGateway.test.ets', {
    getTdGateway: () => f.gateway, getMethodTimeout: f.getMethodTimeout,
    describe(_name, run) { run(); }, it(name, _level, run) { cases.push([name, run]); },
    expect(actual) { return { assertEqual: expected => assert.equal(actual, expected),
      assertTrue: () => assert.equal(actual, true), assertFalse: () => assert.equal(actual, false) }; }
  }).tdGatewayTest();
  assert.ok(cases.length > 0);
  for (const [name, run] of cases) {
    try { await run(); } catch (error) { throw new Error(`${name}: ${error.message}`); }
  }
  console.log(`  existing TdGateway.test.ets: ${cases.length}/${cases.length} PASS`);
});

async function main() {
  let failed = 0;
  for (const [name, run] of tests) {
    try { await run(); console.log(`PASS ${name}`); }
    catch (error) { failed++; console.log(`FAIL ${name}: ${error.stack}`); }
  }
  console.log(`${tests.length - failed}/${tests.length} PASS`);
  process.exitCode = failed ? 1 : 0;
}
module.exports = { fixture, auth, observed };
if (require.main === module) {
  main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
}
