// Actual gateway/dispatcher/runtime/auth normalizer/reducer/store/adapter/side effect together.
// NAPI, timers, platform UI and history/watchers remain inert fixture boundaries.
const assert = require('node:assert/strict');
const { fixture: transportFixture, auth } = require('./test-td-gateway-recovery.cjs');
const { fixture: runtimeFixture, load } = require('./test-runtime-account-recovery.cjs');

async function recoveryScenario() {
  const t = await transportFixture(undefined, false);
  const f = await runtimeFixture(t);
  const root = f.runtime.getLifecycleStore();
  const oldStore = f.runtime.getStore();
  const oldAdapter = f.adapters.getTdGatewayAdapter();
  const events = load('core/model/AppEvent.ets');
  const states = [];
  root.subscribe(state => states.push({ auth: state.auth.status, user: state.auth.userId, chats: state.chats.chats.size }));
  assert.equal(t.created(), 1);
  assert.equal(t.sends[0].request['@type'], 'setTdlibParameters', 'actual auth side effect bootstraps client1');
  t.emit([auth(1, 'Ready')]); await t.flush();
  const oldMe = t.sends.find(s => s.request['@type'] === 'getMe');
  assert.ok(oldMe);
  t.emit([auth(1, 'Closed'), auth(1, 'Ready')]); await t.flush();
  assert.equal(t.created(), 2, 'actual terminal path automatically engages full runtime barrier');
  assert.equal(t.callbacks.length, 1, 'receive loop preserved');
  assert.equal(f.runtime.getLifecycleStore(), root, 'persistent auth/bridge store identity');
  assert.notEqual(f.runtime.getStore(), oldStore);
  assert.notEqual(f.adapters.getTdGatewayAdapter(), oldAdapter);
  assert.equal(root.getState().auth.status, 'closed');
  assert.equal(root.getState().auth.userId, 0);
  assert.equal(root.getState().users.users.size + root.getState().chats.chats.size + root.getState().messages.messages.size, 0);
  assert.ok(t.sends.some(s => s.id === 2 && s.request['@type'] === 'setTdlibParameters'));
  assert.ok(t.sends.some(s => s.id === 2 && s.request['@type'] === 'getAuthorizationState'));
  const sendCount = t.sends.length;
  await assert.rejects(oldAdapter.send({ type: 'getMe' }), error => error.retryable === false);
  assert.equal(t.sends.length, sendCount, 'old capability cannot issue a command into client2');
  await oldStore.dispatch(events.createMyUserResolvedEvent(999));
  t.emit([{ '@type': 'user', '@client_id': 1, '@extra': oldMe.request['@extra'], id: 123 }, auth(1, 'Ready'), auth(2, 'WaitPhoneNumber')]);
  await t.flush();
  assert.equal(root.getState().auth.status, 'waitPhoneNumber', 'only real client2 auth update reaches login state');
  assert.equal(root.getState().auth.userId, 0);
  const params = t.sends.find(s => s.id === 2 && s.request['@type'] === 'setTdlibParameters');
  t.reply(params); await t.settleBootstrap();
  t.emit([auth(2, 'Ready')]); await t.flush();
  const newMe = t.sends.find(s => s.id === 2 && s.request['@type'] === 'getMe');
  assert.ok(newMe, 'fresh side effect observes Ready of client2');
  t.emit([{ '@type': 'user', '@client_id': 2, '@extra': newMe.request['@extra'], id: 456 }]); await t.flush();
  assert.equal(root.getState().auth.userId, 456);
  assert.equal(root.getState().auth.error, '');
  assert.equal(oldStore.getState().auth.userId, 0);
  const shutdown = f.runtime.shutdown();
  const close = t.sends.find(s => s.id === 2 && s.request['@type'] === 'close');
  assert.ok(close);
  t.reply(close); t.emit([auth(2, 'Closed')]); await t.flush(); await shutdown;
  assert.equal(t.created(), 2, 'explicit shutdown never resurrects the client');
  assert.equal(t.stopped(), 1);
  assert.equal(t.dispatcher.getStats().handlerErrors, 0);
  console.log('PASS full native-fixture client1 -> Closed -> scoped account reset -> client2 -> real WaitPhoneNumber -> Ready/getMe B -> explicit shutdown');
  console.log(JSON.stringify({ clients: t.created(), receiveLoops: t.callbacks.length, stoppedLoops: t.stopped(), states }));
}

async function bootstrapFailureScenario(authorized) {
  const t = await transportFixture(undefined, false);
  const f = await runtimeFixture(t);
  t.emit([auth(1, 'Closed')]); await t.flush();
  const bootstrap = t.sends.find(s => s.id === 2 && s.request['@type'] === 'getAuthorizationState');
  assert.ok(bootstrap);
  const scope = f.runtime.getStore();
  const adapter = f.adapters.getTdGatewayAdapter();
  if (authorized) {
    t.emit([auth(2, 'Ready')]); await t.flush();
    const me = t.sends.find(s => s.id === 2 && s.request['@type'] === 'getMe');
    assert.ok(me);
    t.emit([{ '@type': 'user', '@client_id': 2, '@extra': me.request['@extra'], id: 456 }]);
    await t.flush();
    assert.equal(scope.getState().auth.userId, 456);
  }
  t.emit([{ '@type': 'error', '@client_id': 2, '@extra': bootstrap.request['@extra'],
    code: 500, message: 'fixture-bootstrap-error' }]); await t.flush();
  const root = f.runtime.getLifecycleStore();
  if (authorized) {
    assert.equal(t.gateway.getState(), 'ready', 'late auxiliary error cannot demote an authorized client');
    assert.equal(root.getState().auth.status, 'ready');
    assert.equal(root.getState().auth.userId, 456);
    assert.equal(root.getState().auth.error, '');
    assert.equal(f.runtime.getStore(), scope);
    assert.equal(f.adapters.getTdGatewayAdapter(), adapter);
  } else {
    assert.equal(t.gateway.getState(), 'failed');
    await scope.dispatch(load('core/model/AppEvent.ets').createMyUserResolvedEvent(999));
    assert.equal(root.getState().auth.userId, 0, 'failed native client cannot restore user through captured scope');
    assert.equal(root.getState().auth.status, 'closed');
    assert.ok(root.getState().auth.error.length > 0);
    await assert.rejects(adapter.send({ type: 'getMe' }), error => error.retryable === false);
  }
  const shutdown = f.runtime.shutdown();
  const close = t.sends.find(s => s.id === 2 && s.request['@type'] === 'close');
  assert.ok(close, 'failed live native client is still closed during shutdown');
  t.reply(close); t.emit([auth(2, 'Closed')]); await t.flush(); await shutdown;
  assert.equal(t.created(), 2);
  assert.equal(t.stopped(), 1);
  assert.equal(t.dispatcher.getStats().handlerErrors, 0);
  console.log('PASS full chain bootstrap error ' + (authorized ? 'after Ready preserves B' : 'before Ready revokes B scope'));
}

async function main() {
  await recoveryScenario();
  await bootstrapFailureScenario(false);
  await bootstrapFailureScenario(true);
  console.log('3/3 full account recovery scenarios PASS');
}
main().catch(error => { console.error('FAIL full account recovery', error); process.exitCode = 1; });
