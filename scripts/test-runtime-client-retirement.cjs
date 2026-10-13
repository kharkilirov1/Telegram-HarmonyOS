// Node >=24. Actual Runtime/Store/auth reducer/Gateway/Dispatcher source.
// NAPI, timers, normalizer, UI bridge, adapters and account watchers are fixture boundaries.
// Imports below expose helpers only; no other test suite is executed.
// --negative-controls mutates runtime source in memory only, never files on disk.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { fixture: transportFixture, auth, observed } = require('./test-td-gateway-recovery.cjs');
const { load } = require('./test-runtime-account-recovery.cjs');
const A = load('core/model/AppState.ets');
const E = load('core/model/AppEvent.ets');
const errors = load('core/model/AppError.ets');
const clone = load('core/utils/stateClone.ets', A);
const { authReducer } = load('core/reducers/authReducer.ets', { ...A, ...clone });
const tests = [];
const test = (name, run) => tests.push([name, run]);

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

async function fixture(initialize = true) {
  const t = await transportFixture(undefined, false);
  const stops = [], watchers = [], resets = [], hooks = [], logs = [];
  const hilog = { info() {}, warn() {}, debug() {}, error(...args) { logs.push(args); } };
  const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog, assertInvariants() {} });
  class TestStore extends AppStore {
    constructor() {
      const initial = A.createInitialAppState();
      initial.auth.userId = 123;
      initial.users.users.set(123, Object.assign(new A.User(), { id: 123, firstName: 'Account A' }));
      super(authReducer, initial, false);
    }
  }
  const setHooks = t.gateway.setClientRecoveryHooks.bind(t.gateway);
  t.gateway.setClientRecoveryHooks = value => { hooks.push(value); setHooks(value); };
  t.native.stopReceiveLoop = () => { const stop = deferred(); stops.push(stop); return stop.promise; };
  const runtimeModule = load('app/bootstrap/AppCoreRuntime.ets', {
    ...errors, ...E, hilog, AppStore: TestStore, appReducer: authReducer,
    getTdGateway: () => t.gateway, TdGatewayImpl: { getInstance: () => t.gateway },
    getMainThreadDispatcher: () => t.dispatcher,
    getEventNormalizer: () => ({ normalize: update => update.getType() === 'updateAuthorizationState'
      ? [E.createAuthStateChangedEvent('waitPhoneNumber')] : [] }),
    getTdGatewayAdapter: () => ({}), resetTdGatewayAdapter: () => resets.push('adapter'),
    createLoadChatHistoryUseCase: () => ({ async hydrateUsersIfMissing() {} }),
    LoadChatHistoryUseCase: { resetState: () => resets.push('history') },
    resetLoadChatsUseCase: () => resets.push('chats'),
    resetMessageCacheManager: () => resets.push('messages'),
    resetAccountNavigationContext: () => resets.push('navigation'),
    initAppStoreBridge() {}, resetAppStoreBridge: () => resets.push('bridge'),
    setAuthSideEffectStore() {}, startAuthSideEffect: () => watchers.push('auth'),
    stopAuthSideEffect: () => resets.push('auth'),
    createDownloadAvatarsUseCase: () => ({ start: () => watchers.push('avatars') }),
    createDownloadMessageMediaUseCase: () => ({ start: () => watchers.push('media') }),
    resetDownloadAvatarsUseCase: () => resets.push('avatars'),
    resetDownloadMessageMediaUseCase: () => resets.push('media')
  });
  const runtime = runtimeModule.getAppCoreRuntime();
  if (initialize) await runtime.initialize();
  return { t, runtime, runtimeModule, stops, watchers, resets, hooks, logs,
    deliver: envelopes => t.callbacks.at(-1)(JSON.stringify(envelopes)) };
}

async function settle(f, result) {
  for (let turn = 0; turn < 20 && !result.settled; turn++) await f.t.flush();
  assert.equal(result.settled, true, 'operation must settle, not silently exit Node with a pending Promise');
}

async function closed(f, id = 1) {
  assert.ok(f.t.sends.some(s => s.id === id && s.request['@type'] === 'close'), 'actual close must engage');
  f.deliver([auth(id, 'Closed')]);
  await f.t.flush();
}

async function rejectStop(f) {
  const shutdown = observed(f.runtime.shutdown());
  await closed(f);
  assert.equal(f.stops.length, 1);
  f.stops[0].reject(new Error('Injected stop failure'));
  await settle(f, shutdown);
  assert.ok(shutdown.error, 'stop rejection must propagate');
  assert.equal(f.t.gateway.getState(), 'destroying');
  assert.equal(f.t.dispatcher.getStats().isSubscribed, false, 'failed destroy must detach app dispatcher');
  return shutdown;
}

async function timeoutClose(f) {
  const shutdown = observed(f.runtime.shutdown());
  const close = f.t.sends.find(s => s.request['@type'] === 'close');
  assert.ok(close, 'real gateway owns the close command');
  f.deliver([{ '@type': 'ok', '@client_id': close.id, '@extra': close.request['@extra'] }]);
  await f.t.flush();
  const timer = [...f.t.timers].find(([, value]) => value.ms === 5000);
  assert.ok(timer, 'Closed wait deadline must engage');
  f.t.timers.delete(timer[0]); timer[1].fn();
  await settle(f, shutdown);
  assert.ok(shutdown.error, 'Ok alone is not retirement');
  assert.equal(f.t.gateway.getState(), 'destroying');
  assert.equal(f.stops.length, 0, 'receiver retained for late Closed');
  assert.equal(f.t.dispatcher.getStats().isSubscribed, false, 'finally must detach even on timeout');
}

test('normal shutdown is single-flight and restart waits for stop, preserving account invalidation', async () => {
  const f = await fixture();
  const old = f.runtime.getStore();
  const oldHooks = f.hooks.at(-1);
  assert.equal(old.getState().auth.userId, 123, 'nonempty account seed must engage');
  const first = f.runtime.shutdown();
  assert.equal(f.runtime.shutdown(), first);
  assert.equal(old.isScopeCurrent(), false, 'revoke in the calling stack');
  assert.equal(old.getState().auth.userId, 0);
  const shutdown = observed(first), restart = observed(f.runtime.initialize());
  oldHooks.afterRestart();
  await closed(f);
  assert.equal(f.stops.length, 1);
  assert.equal(shutdown.settled, false); assert.equal(restart.settled, false);
  assert.equal(f.t.created(), 1); assert.equal(f.watchers.length, 3);
  f.stops[0].resolve(); await settle(f, shutdown); await settle(f, restart);
  assert.equal(shutdown.error, undefined); assert.equal(restart.error, undefined);
  assert.equal(f.t.created(), 2); assert.equal(f.watchers.length, 6);
  assert.equal(f.runtime.getStore().getState().users.users.size, 0);
  await old.dispatch(E.createMyUserResolvedEvent(999));
  assert.equal(f.runtime.getStore().getState().auth.userId, 0);
  f.deliver([auth(2, 'WaitPhoneNumber')]); await f.t.flush();
  assert.equal(f.runtime.getStore().getState().auth.status, 'waitPhoneNumber', 'new pipeline actually receives');
  assert.equal(f.t.dispatcher.getStats().handlerErrors, 0);
});

test('shutdown after rejected destroy explicitly retries stop instead of returning success', async () => {
  const f = await fixture(); await rejectStop(f);
  const retry = f.runtime.shutdown(), result = observed(retry);
  assert.equal(f.runtime.shutdown(), retry);
  await f.t.flush();
  assert.equal(f.stops.length, 2, 'retry must reach actual native stop');
  assert.equal(result.settled, false, 'retry cannot declare success before idle');
  assert.equal(f.t.created(), 1);
  f.stops[1].resolve(); await settle(f, result);
  assert.equal(result.error, undefined); assert.equal(f.t.gateway.getState(), 'idle');
});

test('initialize after failed shutdown cannot grant a scope, install hooks or implicitly retry stop', async () => {
  const f = await fixture(); await rejectStop(f);
  const oldScope = f.runtime.getStore(), hookCount = f.hooks.length;
  const restart = observed(f.runtime.initialize());
  await f.t.flush();
  assert.equal(f.stops.length, 1, 'initialize is not a manual shutdown retry');
  await settle(f, restart); assert.ok(restart.error);
  assert.equal(f.runtime.getStore(), oldScope); assert.equal(oldScope.isScopeCurrent(), false);
  assert.equal(f.hooks.length, hookCount); assert.equal(f.watchers.length, 3);
  assert.equal(f.t.created(), 1); assert.equal(f.runtime.isPipelineRunning(), false);
});

test('close timeout keeps a retry reachable after dispatcher detach', async () => {
  const f = await fixture(); await timeoutClose(f);
  const retry = observed(f.runtime.shutdown()); await f.t.flush();
  assert.equal(retry.settled, false, 'non-running runtime still owns unresolved client');
  assert.equal(f.t.created(), 1);
  await closed(f);
  assert.equal(f.stops.length, 1); assert.equal(retry.settled, false);
  f.stops[0].resolve(); await settle(f, retry);
  assert.equal(retry.error, undefined); assert.equal(f.t.gateway.getState(), 'idle');
});

test('late Closed auto stop survives app detach; shutdown joins it without early success', async () => {
  const f = await fixture(); await timeoutClose(f);
  await closed(f);
  assert.equal(f.stops.length, 1, 'private route must start native stop after app unsubscribe');
  const retry = observed(f.runtime.shutdown()); await f.t.flush();
  assert.equal(retry.settled, false, 'runtime must join gateway retirement already in flight');
  assert.equal(f.stops.length, 1);
  f.stops[0].resolve(); await settle(f, retry);
  assert.equal(retry.error, undefined); assert.equal(f.t.gateway.getState(), 'idle');
});

test('late Closed stop rejection stays explicit-retry-only and cannot reopen account scopes', async () => {
  const f = await fixture(); await timeoutClose(f);
  const old = f.runtime.getStore();
  await closed(f); assert.equal(f.stops.length, 1);
  f.stops[0].reject(new Error('Injected late retirement stop failure')); await f.t.flush();
  f.deliver([auth(1, 'Closed')]); await f.t.flush();
  assert.equal(f.stops.length, 1, 'late updates cannot spin an automatic stop-retry loop');
  const initialize = observed(f.runtime.initialize()); await settle(f, initialize);
  assert.ok(initialize.error); assert.equal(f.runtime.getStore(), old);
  assert.equal(old.isScopeCurrent(), false); assert.equal(f.stops.length, 1);
  const retry = observed(f.runtime.shutdown()); await f.t.flush();
  assert.equal(f.stops.length, 2); assert.equal(retry.settled, false);
  f.stops[1].resolve(); await settle(f, retry);
  assert.equal(retry.error, undefined); assert.equal(f.t.gateway.getState(), 'idle');
});

test('reset failure retains the owner singleton so the next reset retries retirement', async () => {
  const f = await fixture();
  const first = observed(f.runtimeModule.resetAppCoreRuntime());
  assert.equal(f.runtime.getStore().isScopeCurrent(), false, 'reset revokes synchronously');
  await closed(f); f.stops[0].reject(new Error('Injected reset stop failure')); await settle(f, first);
  assert.ok(first.error);
  assert.equal(f.runtimeModule.getAppCoreRuntime(), f.runtime, 'failed reset must not discard owner');
  const retry = observed(f.runtimeModule.resetAppCoreRuntime()); await f.t.flush();
  assert.equal(f.stops.length, 2); assert.equal(retry.settled, false);
  assert.throws(() => f.runtimeModule.getAppCoreRuntime(), /being reset/);
  f.stops[1].resolve(); await settle(f, retry);
  assert.equal(retry.error, undefined); assert.equal(f.t.gateway.getState(), 'idle');
  assert.notEqual(f.runtimeModule.getAppCoreRuntime(), f.runtime);
});

test('concurrent resets share pending completion and the same rejection', async () => {
  const f = await fixture();
  const first = f.runtimeModule.resetAppCoreRuntime(), a = observed(first);
  const second = f.runtimeModule.resetAppCoreRuntime(), b = observed(second);
  await f.t.flush();
  assert.equal(b.settled, false, 'duplicate reset must not return early success');
  assert.equal(second, first, 'one reset flight');
  await closed(f); f.stops[0].reject(new Error('Injected shared failure'));
  await settle(f, a); await settle(f, b);
  assert.ok(a.error); assert.equal(b.error, a.error);
});

test('synchronous scope invalidation reentry joins shutdown before any cleanup callbacks', async () => {
  const f = await fixture(); let reentrant;
  f.runtime.getStore().subscribeScopeInvalidation(() => { reentrant = f.runtime.shutdown(); });
  const first = f.runtime.shutdown(), a = observed(first), b = observed(reentrant);
  await f.t.flush();
  assert.equal(b.settled, false, 'reentrant shutdown cannot report immediate success');
  assert.equal(reentrant, first);
  await closed(f); assert.equal(f.stops.length, 1);
  f.stops[0].resolve(); await settle(f, a); await settle(f, b);
  assert.equal(a.error, undefined); assert.equal(b.error, undefined);
});

test('synchronous scope invalidation reentry joins singleton reset', async () => {
  const f = await fixture(); let reentrant;
  f.runtime.getStore().subscribeScopeInvalidation(() => { reentrant = f.runtimeModule.resetAppCoreRuntime(); });
  const first = f.runtimeModule.resetAppCoreRuntime(), a = observed(first), b = observed(reentrant);
  await f.t.flush();
  assert.equal(b.settled, false); assert.equal(reentrant, first);
  await closed(f); f.stops[0].resolve(); await settle(f, a); await settle(f, b);
  assert.equal(a.error, undefined); assert.equal(b.error, undefined);
});

test('failed startup with rejected cleanup creates no ID and remains explicitly stoppable', async () => {
  const f = await fixture(false);
  f.t.native.startReceiveLoop = () => { throw new Error('Injected start failure'); };
  const start = observed(f.runtime.initialize()); await f.t.flush();
  assert.equal(f.t.created(), 0, 'receiver must start before client allocation');
  assert.equal(f.stops.length, 1);
  f.stops[0].reject(new Error('Injected startup stop failure')); await f.t.flush();
  assert.equal(f.stops.length, 2, 'runtime failure cleanup explicitly destroys failed startup');
  f.stops[1].reject(new Error('Injected cleanup stop failure')); await settle(f, start);
  assert.ok(start.error); assert.equal(f.runtime.getStore().isScopeCurrent(), false);
  assert.equal(f.t.dispatcher.getStats().isSubscribed, false);
  const retry = observed(f.runtime.shutdown()); await f.t.flush();
  assert.equal(f.stops.length, 3, 'shutdown retry cannot hide behind isRunning=false');
  assert.equal(retry.settled, false); assert.equal(f.t.created(), 0);
  f.stops[2].resolve(); await settle(f, retry);
  assert.equal(retry.error, undefined); assert.equal(f.t.gateway.getState(), 'idle');
});

test('shutdown during pending initialize keeps lifecycle token cancellation and one destroy', async () => {
  const f = await fixture(false), gate = deferred();
  const initialize = f.t.gateway.initialize.bind(f.t.gateway);
  f.t.gateway.initialize = async () => { await gate.promise; await initialize(); };
  const start = observed(f.runtime.initialize()); await f.t.flush();
  const scope = f.runtime.getStore(), first = f.runtime.shutdown(), shutdown = observed(first);
  assert.equal(f.runtime.shutdown(), first); assert.equal(scope.isScopeCurrent(), false);
  assert.equal(f.runtime.isPipelineRunning(), false);
  gate.resolve(); await f.t.flush(); await closed(f);
  assert.equal(shutdown.settled, false); assert.equal(f.watchers.length, 0);
  f.stops[0].resolve(); await settle(f, shutdown); await settle(f, start);
  assert.equal(shutdown.error, undefined); assert.equal(f.t.gateway.getState(), 'idle');
  assert.equal(f.runtime.isPipelineRunning(), false); assert.equal(f.watchers.length, 0);
});

test('idle shutdown stays a no-op and concurrent initialize still shares one flight', async () => {
  const f = await fixture(false), scope = f.runtime.getStore();
  await f.runtime.shutdown();
  assert.equal(scope.isScopeCurrent(), true); assert.equal(f.resets.length, 0);
  assert.equal(f.stops.length, 0); assert.equal(f.t.created(), 0);
  const first = f.runtime.initialize(); assert.equal(f.runtime.initialize(), first);
  const start = observed(first); await settle(f, start);
  assert.equal(start.error, undefined); assert.equal(f.t.created(), 1);
  assert.equal(f.watchers.length, 3);
});

function replaceOnce(source, from, to) {
  assert.equal(source.split(from).length, 2, 'negative control must match exactly one production path');
  return source.replace(from, to);
}

async function negativeControls(sourcePath, original) {
  const controls = [
    ['idle early-return regression', 'shutdown after rejected destroy', source => replaceOnce(source,
      "!this.isRunning && !this.initializationTask && this.gateway.getState() === 'idle'",
      '!this.isRunning && !this.initializationTask')],
    ['initialize bypasses retirement gate', 'initialize after failed shutdown', source => replaceOnce(source,
      "if (this.gateway.getState() === 'destroying') {", 'if (false) {')],
    ['failed reset discards singleton', 'reset failure retains', source => replaceOnce(source,
      '// Preserve the stopped runtime as retirement owner until an explicit retry.', 'runtimeInstance = null;')],
    ['duplicate reset resolves early', 'concurrent resets share', source => replaceOnce(source,
      'if (resetTask) return resetTask;', 'if (resetTask) return Promise.resolve();')],
    ['shutdown flight published after synchronous callbacks', 'synchronous scope invalidation reentry joins shutdown',
      source => replaceOnce(source,
        '    this.shutdownTask = task;\n    this.shutdownPipeline(this.initializationTask).then((): void => {',
        '    const pipeline = this.shutdownPipeline(this.initializationTask);\n    this.shutdownTask = task;\n    pipeline.then((): void => {')],
    ['timeout leaves app dispatcher attached', 'close timeout keeps a retry', source => {
      const marker = '  private async shutdownPipeline(';
      const offset = source.indexOf(marker); assert.ok(offset >= 0);
      return source.slice(0, offset) + replaceOnce(source.slice(offset),
        '      getMainThreadDispatcher().unsubscribe();', '      // Injected missing detach.');
    }],
    ['shutdown skips synchronous account invalidation', 'normal shutdown is single-flight', source => {
      const marker = '  private async shutdownPipeline(';
      const offset = source.indexOf(marker); assert.ok(offset >= 0);
      return source.slice(0, offset) + replaceOnce(source.slice(offset),
        '    this.store.invalidateScopes();', '    // Injected missing scope invalidation.');
    }]
  ];
  const read = fs.readFileSync;
  for (const [name, prefix, mutate] of controls) {
    const mutated = mutate(original.replace(/\r\n/g, '\n'));
    const matching = tests.filter(([title]) => title.startsWith(prefix));
    assert.equal(matching.length, 1, 'one focused assertion route per mutant');
    let failure;
    fs.readFileSync = function(file, ...args) {
      if (typeof file === 'string' && path.resolve(file) === sourcePath) return mutated;
      return read.call(this, file, ...args);
    };
    try { await matching[0][1](); } catch (error) { failure = error; }
    finally { fs.readFileSync = read; }
    assert.equal(failure?.code, 'ERR_ASSERTION', `negative control must fail behaviorally: ${name}`);
    console.log('CONTROL REJECTED', name);
  }
  console.log(`${controls.length}/${controls.length} negative controls rejected`);
}

async function main() {
  const sourcePath = path.resolve(__dirname, '../entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets');
  const before = fs.readFileSync(sourcePath);
  const witnesses = ['app/bootstrap/AppCoreRuntime.ets', 'infra/td/gateway/TdGateway.ets',
    'infra/threading/MainThreadDispatcher.ets', 'core/store/AppStore.ets'].map(relative => {
    const file = path.resolve(__dirname, '../entry/src/main/ets', relative);
    return [file, fs.readFileSync(file)];
  });
  console.log('Runtime SHA256', createHash('sha256').update(before).digest('hex'));
  let failures = 0;
  for (const [name, run] of tests) {
    try { await run(); console.log('PASS', name); }
    catch (error) { failures++; console.error('FAIL', name, error.stack); }
  }
  if (!failures && process.argv.includes('--negative-controls')) await negativeControls(sourcePath, before.toString('utf8'));
  for (const [file, content] of witnesses) {
    assert.deepEqual(fs.readFileSync(file), content, `source must remain unchanged during witness: ${file}`);
  }
  console.log(`${tests.length - failures}/${tests.length} PASS`);
  process.exitCode = failures ? 1 : 0;
}
if (require.main === module) main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
