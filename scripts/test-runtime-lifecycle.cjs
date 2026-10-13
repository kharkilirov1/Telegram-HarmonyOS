// Node >=24. Actual Gateway + Dispatcher + Runtime + Store + Adapter + AuthSideEffect.
// Reuses the native/timer/platform fixtures; no SDK/build, device, network or account actions.
// Two tests delay gateway.initialize at its boundary, then run the original implementation.
// Bridge and download watchers remain the exported runtime fixture's explicit stubs.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { fixture: transportFixture, auth, observed } = require('./test-td-gateway-recovery.cjs');
const { fixture: runtimeFixture, load } = require('./test-runtime-account-recovery.cjs');
const { createMyUserResolvedEvent } = load('core/model/AppEvent.ets');

function track(context, name, promise) {
  const operation = { name, result: observed(promise) };
  context.operations.push(operation);
  return operation;
}

function deliver(context, envelopes) {
  // A sequential restart starts another receive loop; never inject through callbacks[0].
  const callback = context.t.callbacks.at(-1);
  assert.equal(typeof callback, 'function', 'a real receive-loop callback must be installed');
  callback(JSON.stringify(envelopes));
}

function acknowledgeCloses(context) {
  for (const sent of context.t.sends) {
    if (sent.request['@type'] !== 'close' || context.acknowledged.has(sent)) continue;
    context.acknowledged.add(sent);
    deliver(context, [
      { '@type': 'ok', '@client_id': sent.id, '@extra': sent.request['@extra'] },
      auth(sent.id, 'Closed')
    ]);
  }
}

async function finish(context, operations, checkErrors = true) {
  // Bounded pumping avoids both sleeps and an unresolved Promise silently ending Node.
  for (let turns = 0; turns < 40; turns++) {
    acknowledgeCloses(context);
    await context.t.flush();
    if (operations.every(operation => operation.result.settled)) {
      if (checkErrors) {
        for (const operation of operations) {
          assert.equal(operation.result.error, undefined, `${operation.name} must succeed`);
        }
      }
      return;
    }
  }
  assert.fail(`Unsettled lifecycle operations: ${operations.filter(op => !op.result.settled).map(op => op.name).join(', ')}`);
}

async function stop(context) {
  const operation = track(context, 'shutdown', context.f.runtime.shutdown());
  await finish(context, [operation]);
  assert.equal(context.t.gateway.getState(), 'idle');
}

function delayInitialize(context) {
  const original = context.f.gateway.initialize.bind(context.f.gateway);
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  const control = { calls: 0, release };
  context.releases.push(release);
  context.f.gateway.initialize = async () => {
    control.calls++;
    await gate;
    await original();
  };
  return control;
}

async function useFreshRuntime(context) {
  await stop(context);
  // The constructor comes from the actual loaded source, sharing its real module deps.
  context.f.runtime = new context.f.runtime.constructor();
}

async function withFixture(run) {
  const t = await transportFixture(undefined, false);
  const f = await runtimeFixture(t);
  const context = { t, f, operations: [], releases: [], acknowledged: new Set() };
  let failure;
  try {
    await run(context);
    assert.equal(t.dispatcher.getStats().handlerErrors, 0, 'no swallowed dispatcher errors');
  } catch (error) {
    failure = error;
  } finally {
    try {
      for (const release of context.releases) release();
      await finish(context, context.operations, false);
      await finish(context, [track(context, 'cleanup runtime', f.runtime.shutdown())]);
      // A broken cancelled initialize can leave a live gateway behind a stopped runtime.
      // Clean up the fixture only AFTER assertions; never treat this fallback as a pass.
      if (t.gateway.getState() !== 'idle') {
        await finish(context, [track(context, 'cleanup leaked fixture gateway', t.gateway.destroy())]);
      }
    } catch (cleanupError) {
      if (failure) console.error('CLEANUP_ERROR', cleanupError.message);
      else failure = cleanupError;
    }
  }
  if (failure) throw failure;
}

const tests = [
  ['initialize during shutdown waits for destroy and keeps the new dispatcher alive', async context => {
    const { f, t } = context;
    const watcherCount = f.watchers.length;
    const stopping = track(context, 'old shutdown', f.runtime.shutdown());
    await t.flush();
    assert.equal(t.gateway.getState(), 'destroying', 'hold real close response/Closed');
    const starting = track(context, 'new initialize', f.runtime.initialize());
    await t.flush();
    assert.equal(starting.result.settled, false, 'initialize must not resolve over a destroying gateway');
    assert.equal(stopping.result.settled, false);
    assert.equal(f.runtime.isPipelineRunning(), false);
    assert.equal(t.created(), 1, 'no new client until close completes');
    assert.equal(f.watchers.length, watcherCount, 'no watchers on a destroying gateway');

    await finish(context, [stopping, starting]);
    assert.equal(t.created(), 2);
    assert.equal(t.stopped(), 1);
    assert.equal(t.gateway.isReady(), true);
    assert.equal(f.runtime.isPipelineRunning(), true);
    assert.equal(t.dispatcher.getStats().isSubscribed, true, 'old shutdown must not detach the new run');
    deliver(context, [auth(2, 'WaitPhoneNumber')]);
    await t.flush();
    assert.equal(f.runtime.getStore().getState().auth.status, 'waitPhoneNumber', 'client2 really reaches the new pipeline');
    assert.equal(f.watchers.length, watcherCount + 2);
    assert.equal(f.watchers.at(-1), f.runtime.getStore());
  }],

  ['sequential same-instance initialize clears A before granting client2 its scope', async context => {
    const { f, t } = context;
    const root = f.runtime.getLifecycleStore();
    const old = f.runtime.getStore();
    assert.equal(old.getState().auth.userId, 123, 'A seed must engage, not empty-state fallback');
    assert.equal(old.getState().users.users.get(123).firstName, 'Account A');
    assert.equal(old.getState().files.aliases.size, 1);
    await stop(context);
    assert.equal(old.getState().auth.userId, 0);
    const starting = track(context, 'sequential initialize', f.runtime.initialize());
    await finish(context, [starting]);
    assert.equal(t.created(), 2);
    assert.equal(f.runtime.getLifecycleStore(), root);
    assert.notEqual(f.runtime.getStore(), old);
    deliver(context, [auth(2, 'WaitPhoneNumber')]);
    await t.flush();

    const state = f.runtime.getStore().getState();
    assert.equal(state.auth.status, 'waitPhoneNumber');
    assert.equal(state.auth.userId, 0, 'new client must not inherit A identity');
    assert.equal(state.users.users.size, 0);
    assert.equal(state.chats.chats.size, 0);
    assert.equal(state.messages.messages.size, 0);
    assert.equal(state.files.transfers.size, 0);
    assert.equal(state.files.aliases.size, 0);
    assert.ok(f.resets.includes('navigation'), 'reinitialize must reset account navigation too');
    await old.dispatch(createMyUserResolvedEvent(999));
    await f.runtime.getStore().dispatch(createMyUserResolvedEvent(456));
    assert.equal(root.getState().auth.userId, 456, 'new scope must remain live');
    assert.equal(old.getState().auth.userId, 0);
  }],

  ['concurrent initialize joins one pending initialization rather than returning early', async context => {
    await useFreshRuntime(context);
    const { f, t } = context;
    const watcherCount = f.watchers.length;
    const delayed = delayInitialize(context);
    const first = track(context, 'first initialize', f.runtime.initialize());
    const second = track(context, 'duplicate initialize', f.runtime.initialize());
    await t.flush();
    assert.equal(delayed.calls, 1, 'single-flight must reach the actual gateway boundary once');
    assert.equal(first.result.settled, false);
    assert.equal(second.result.settled, false, 'duplicate initialize must await the first operation');
    assert.equal(t.created(), 1);
    assert.equal(f.watchers.length, watcherCount);
    delayed.release();
    await finish(context, [first, second]);
    assert.equal(delayed.calls, 1);
    assert.equal(t.created(), 2);
    assert.equal(t.gateway.isReady(), true);
    assert.equal(f.runtime.isPipelineRunning(), true);
    assert.equal(f.watchers.length, watcherCount + 2, 'watchers start once');
  }],

  ['shutdown joins a pending initialize and destroys its late client without reviving callbacks', async context => {
    await useFreshRuntime(context);
    const { f, t } = context;
    const watcherCount = f.watchers.length;
    const sendCount = t.sends.length;
    const delayed = delayInitialize(context);
    const starting = track(context, 'cancelled initialize', f.runtime.initialize());
    await t.flush();
    assert.equal(delayed.calls, 1, 'initialize must be in flight before shutdown');
    const scope = f.runtime.getStore();
    const stopping = track(context, 'shutdown during initialize', f.runtime.shutdown());
    const duplicate = track(context, 'duplicate shutdown during initialize', f.runtime.shutdown());
    assert.equal(scope.getState().auth.userId, 0, 'shutdown revokes account access synchronously');
    await t.flush();
    assert.equal(stopping.result.settled, false, 'shutdown must wait for pending native initialization');
    assert.equal(duplicate.result.settled, false, 'duplicate shutdown must join the same cleanup');
    assert.equal(f.runtime.isPipelineRunning(), false);
    delayed.release();
    // A superseded initialize may resolve or reject; both shutdown promises must succeed.
    await finish(context, [starting, stopping, duplicate], false);
    assert.equal(stopping.result.error, undefined);
    assert.equal(duplicate.result.error, undefined);
    assert.equal(t.created(), 2, 'late actual native initialization did engage');
    assert.equal(t.stopped(), 2, 'the late client receive loop must also be stopped');
    assert.equal(t.gateway.getState(), 'idle');
    assert.equal(t.dispatcher.getStats().isSubscribed, false);
    assert.equal(f.runtime.isPipelineRunning(), false);
    assert.equal(f.watchers.length, watcherCount, 'stale initialize must not start watchers');
    assert.deepEqual(t.sends.slice(sendCount).map(sent => sent.request['@type']), ['close'],
      'stale initialize must not start auth/ready continuations or bootstrap requests');
  }],

  ['duplicate shutdown stays pending until the real close and destroys only once', async context => {
    const { f, t } = context;
    const first = track(context, 'first shutdown', f.runtime.shutdown());
    const second = track(context, 'duplicate shutdown', f.runtime.shutdown());
    await t.flush();
    assert.equal(t.gateway.getState(), 'destroying');
    assert.equal(first.result.settled, false);
    assert.equal(second.result.settled, false, 'a duplicate shutdown is a barrier, not a no-op');
    assert.equal(t.sends.filter(sent => sent.request['@type'] === 'close').length, 1);
    await finish(context, [first, second]);
    assert.equal(t.gateway.getState(), 'idle');
    assert.equal(t.stopped(), 1);
    assert.equal(t.created(), 1);
    assert.equal(t.dispatcher.getStats().isSubscribed, false);
    assert.equal(f.runtime.isPipelineRunning(), false);
  }]
];

async function main() {
  let failed = 0;
  for (const [name, run] of tests) {
    try { await withFixture(run); console.log('PASS', name); }
    catch (error) { failed++; console.error('FAIL', name, error.stack); }
  }
  const runtimePath = path.resolve(__dirname, '../entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets');
  console.log(JSON.stringify({ passed: tests.length - failed, failed,
    runtimeSha256: createHash('sha256').update(fs.readFileSync(runtimePath)).digest('hex') }));
  process.exitCode = failed ? 1 : 0;
}
if (require.main === module) require('./host-test-completion.cjs').guardSuite(main()).catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
