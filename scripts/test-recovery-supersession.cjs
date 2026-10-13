// Node >= 24. Durable reviewer probes against current gateway/dispatcher/runtime/
// store/adapter/auth code, loaded by the existing source-based host fixtures.
// Only completion timing is gated below; production methods and dispatch guards
// still execute. NAPI, timers, platform UI, history and watchers remain fixtures.
// No real account/logout/native/device actions and no renderer/build coverage.
const assert = require('node:assert/strict');
const { fixture: transportFixture, auth } = require('./test-td-gateway-recovery.cjs');
const { fixture: runtimeFixture, load } = require('./test-runtime-account-recovery.cjs');
const events = load('core/model/AppEvent.ets');

async function supersessionScenario(stage) {
  const transport = await transportFixture(undefined, false);
  const fixture = await runtimeFixture(transport);
  const runtime = fixture.runtime;
  const root = runtime.getLifecycleStore();
  transport.emit([auth(1, 'Closed')]);
  await transport.flush();
  const abandonedScope = runtime.getStore();
  const originalReset = root.resetStateQueued.bind(root);
  const originalDispatch = root.dispatch.bind(root);
  let release;
  let held = false;
  const gate = new Promise(resolve => { release = resolve; });

  if (stage === 'failure-barrier') {
    let resets = 0;
    root.resetStateQueued = () => {
      // Execute real synchronous scope revocation and queued clearing, but delay
      // its completion as seen by the old failure handler's await continuation.
      const result = originalReset();
      if (++resets === 1) {
        held = true;
        return result.then(() => gate);
      }
      return result;
    };
  } else {
    assert.equal(stage, 'queued-error');
    root.dispatch = (event, guard) => {
      // Let the first account-token check pass, then hold the error at the
      // dispatch boundary. Replay the original event AND guard into the real
      // store queue after retry; this exercises the dequeue guard independently.
      if (event.error && !held) {
        held = true;
        return gate.then(() => originalDispatch(event, guard));
      }
      return originalDispatch(event, guard);
    };
  }

  try {
    const bootstrap = transport.sends.find(send =>
      send.id === 2 && send.request['@type'] === 'getAuthorizationState');
    assert.ok(bootstrap, 'real recovery issued a client2 bootstrap probe');
    transport.emit([{
      '@type': 'error', '@client_id': 2, '@extra': bootstrap.request['@extra'],
      code: 500, message: 'fixture bootstrap failure'
    }]);
    await transport.flush();
    assert.equal(transport.gateway.getState(), 'failed');
    assert.equal(held, true, 'the intended old failure continuation was held');

    await abandonedScope.dispatch(events.createMyUserResolvedEvent(999));
    assert.equal(root.getState().auth.userId, 0, 'failed-client scope is already revoked');
    await runtime.retryClientRecovery();
    await transport.flush();
    assert.equal(transport.gateway.getState(), 'ready');
    const probes = transport.sends.filter(send =>
      send.id === 2 && send.request['@type'] === 'getAuthorizationState');
    assert.equal(probes.length, 2, 'manual retry engaged, rather than returning an old flight');
    assert.notEqual(runtime.getStore(), abandonedScope);

    transport.emit([auth(2, 'Ready')]);
    await transport.flush();
    const me = transport.sends.filter(send => send.id === 2 && send.request['@type'] === 'getMe').at(-1);
    assert.ok(me, 'current auth side effect requests getMe after native Ready');
    transport.emit([{ '@type': 'user', '@client_id': 2, '@extra': me.request['@extra'], id: 456 }]);
    await transport.flush();
    assert.equal(root.getState().auth.userId, 456, 'new account is resolved before releasing old work');

    release();
    await transport.flush();
    assert.equal(root.getState().auth.status, 'ready', 'old failure cannot demote recovered auth');
    assert.equal(root.getState().auth.userId, 456);
    assert.equal(root.getState().auth.error, '', 'old failure publication is suppressed');
    assert.equal(transport.gateway.getState(), 'ready');
    assert.equal(transport.created(), 2, 'retry reuses the still-live client, without orphaning it');
  } finally {
    release();
    root.resetStateQueued = originalReset;
    root.dispatch = originalDispatch;
    await transport.flush();
    const shutdown = runtime.shutdown();
    const close = transport.sends.at(-1);
    assert.equal(close.request['@type'], 'close', 'fixture shutdown still closes the live client');
    transport.reply(close);
    transport.emit([auth(close.id, 'Closed')]);
    await transport.flush();
    await shutdown;
    assert.equal(transport.stopped(), 1);
    assert.equal(transport.dispatcher.getStats().handlerErrors, 0);
  }
}

async function main() {
  const stages = ['failure-barrier', 'queued-error'];
  let passed = 0;
  for (const stage of stages) {
    try {
      await supersessionScenario(stage);
      passed++;
      console.log(`PASS superseded ${stage}: old scope revoked; retry engaged; late error cannot demote Ready/getMe`);
    } catch (error) {
      console.error(`FAIL superseded ${stage}: ${error.stack}`);
    }
  }
  console.log(`${passed}/${stages.length} supersession probes PASS (actual source; host fixtures only)`);
  if (passed !== stages.length) process.exitCode = 1;
}

// An unresolved fixture promise must never produce a silent successful Node exit.
let finished = false;
process.once('beforeExit', () => {
  if (!finished) {
    console.error('FAIL incomplete supersession run: unresolved fixture promise');
    process.exitCode = 1;
  }
});
main().then(() => { finished = true; }).catch(error => {
  finished = true;
  console.error(error.stack);
  process.exitCode = 1;
});
