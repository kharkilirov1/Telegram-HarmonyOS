// Actual ETS gateway/dispatcher/DTO. Native delivery and scheduler are explicit boundaries.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = process.env.RECEIVE_REPO_ROOT || path.resolve(__dirname, '..');
const gatewayPath = process.env.RECEIVE_GATEWAY_SOURCE || path.join(root, 'entry/src/main/ets/infra/td/gateway/TdGateway.ets');
function load(relative, deps = {}) {
  const filename = relative.endsWith('TdGateway.ets') ? gatewayPath : path.join(root, 'entry/src/main/ets', relative);
  const source = fs.readFileSync(filename, 'utf8');
  const names = [...source.matchAll(/^export\s+(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}}`)(...Object.values(deps));
}
const tick = () => new Promise(resolve => setImmediate(resolve));
async function fixture() {
  const timers = new Map(), monitors = new Map(), calls = [], acks = [], logs = [];
  let next = 1, callback, created = 0, stopped = 0, clock = 100, nativeStatus = 1, id = 0;
  const errors = load('core/model/AppError.ets'), { TdObject } = load('models/td/common/index.ets');
  const hilog = Object.fromEntries(['info', 'warn', 'error', 'debug'].map(name => [name, (...args) => logs.push(args)]));
  const { MainThreadDispatcher } = load('infra/threading/MainThreadDispatcher.ets', { hilog });
  const dispatcher = new MainThreadDispatcher();
  const tdlib = {
    createClient() { return ++created; },
    startReceiveLoop(cb) { callback = cb; return 7; },
    ackReceiveBatch(epoch, batchId) { acks.push([epoch, batchId]); return true; },
    getReceiveLoopStatus() { return nativeStatus; },
    stopReceiveLoop() { stopped++; return Promise.resolve(); },
    send(clientId, json) { calls.push(JSON.parse(json)); }
  };
  const { TdGatewayImpl } = load('infra/td/gateway/TdGateway.ets', { ...errors, TdObject, hilog, tdlib,
    systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => clock },
    getMainThreadDispatcher: () => dispatcher,
    setTimeout(fn, ms) { const key = next++; timers.set(key, { fn, ms }); return key; }, clearTimeout(key) { timers.delete(key); },
    setInterval(fn, ms) { const key = next++; monitors.set(key, { fn, ms }); return key; }, clearInterval(key) { monitors.delete(key); }
  });
  const gateway = TdGatewayImpl.getInstance();
  dispatcher.subscribeUpdates(raw => gateway.handleUpdateOnMainThread(raw));
  await gateway.initialize();
  const f = { gateway, tdlib, calls, acks, logs, timers, monitors, errors, dispatcher,
    created: () => created, stopped: () => stopped, clock(value) { clock = value; },
    emit(items, epoch = 7, batchId = ++id, bytes) {
      const json = typeof items === 'string' ? items : JSON.stringify(items);
      return callback(json, epoch, batchId, bytes ?? Buffer.byteLength(json));
    },
    poll(status = 1) { nativeStatus = status; for (const monitor of [...monitors.values()]) monitor.fn(); },
    async drain() {
      for (let n = 0; n < 100; n++) {
        const entry = [...timers].find(([, timer]) => timer.ms <= 250);
        if (!entry) { await tick(); return; }
        timers.delete(entry[0]); entry[1].fn();
      }
      assert.fail('Unbounded actual gateway drain');
    }
  };
  return f;
}
const tests = [];
const test = (name, run) => tests.push([name, run]);
const update = { '@type': 'updateUser', '@client_id': 1, user: { id: 12 } };
test('admission is synchronous and ACK follows synchronous dispatch with references cleared', async () => {
  const f = await fixture(); let seen = 0;
  f.gateway.subscribeUpdates(() => { seen++; assert.equal(f.acks.length, 0); });
  assert.equal(f.emit([update]), true); assert.equal(seen, 0); assert.equal(f.acks.length, 0);
  const ack = f.tdlib.ackReceiveBatch;
  f.tdlib.ackReceiveBatch = (...args) => {
    assert.equal(f.gateway.drainItems.length, 0); assert.equal(f.gateway.activeBatch, undefined);
    return ack(...args);
  };
  await f.drain(); assert.equal(seen, 1); assert.deepEqual(f.acks, [[7, 1]]);
});
test('active parsed batch remains charged across a budgeted drain slice', async () => {
  const f = await fixture(); let transferred = 0;
  f.gateway.subscribeUpdates(() => { transferred++; if (transferred === 1) f.clock(109); });
  assert.equal(f.emit([update, update, update]), true);
  const [id, timer] = [...f.timers][0]; f.timers.delete(id); timer.fn();
  assert.equal(transferred, 1); assert.equal(f.gateway.admittedBatchCount, 1);
  assert.equal(f.gateway.activeBatch.batchId, 1); assert.equal(f.acks.length, 0);
  f.clock(110); await f.drain();
  assert.equal(transferred, 3); assert.deepEqual(f.acks, [[7, 1]]);
});
test('admission scheduling failure reports false and never hides accepted work', async () => {
  const f = await fixture();
  f.gateway.scheduleDrain = () => { throw new Error('scheduler failure'); };
  assert.equal(f.emit([update]), false); assert.equal(f.gateway.getState(), 'failed');
  assert.equal(f.gateway.pendingBatchQueue.length, 0); assert.equal(f.acks.length, 0);
});
test('bounded admission faults on fifth waiting batch instead of growing queue', async () => {
  const f = await fixture();
  for (let i = 0; i < 4; i++) assert.equal(f.emit([update]), true);
  assert.equal(f.emit([update]), false); assert.equal(f.gateway.getState(), 'failed');
  assert.equal(f.gateway.pendingBatchQueue.length, 0); assert.equal(f.gateway.clientId, 1);
  assert.equal(f.created(), 1); assert.equal(f.stopped(), 1);
});
test('byte framing and metadata validation fail closed', async () => {
  for (const [epoch, id, bytes] of [[7, 1, 0], [7, 1, 8388609], [7, 0, 2], [7, 1.5, 2], [7, 1, 1.5]]) {
    const f = await fixture(); assert.equal(f.emit('[]', epoch, id, bytes), false); assert.equal(f.gateway.getState(), 'failed');
  }
});
test('watchdog catches terminal fault without payload and preserves unknown dispatched outcome', async () => {
  const f = await fixture(); let error;
  const pending = f.gateway.send('sendMessage').catch(e => { error = e; });
  assert.equal(f.calls.length, 1); f.poll(102); assert.equal(f.gateway.getState(), 'failed'); await pending;
  assert.ok(error instanceof f.errors.AppError); assert.equal(error.requestRejected, false); assert.equal(error.retryable, false);
  assert.equal(f.gateway.clientId, 1); assert.equal(f.gateway.getState(), 'failed'); assert.equal(f.monitors.size, 0);
  await assert.rejects(f.gateway.initialize()); await assert.rejects(f.gateway.retryClosedClient());
  await assert.rejects(f.gateway.sendWithRetry('sendMessage')); await assert.rejects(f.gateway.destroy());
  assert.equal(f.created(), 1); assert.equal(f.calls.length, 1);
});
test('watchdog API failure and ACK failure latch safe live fault', async () => {
  const f = await fixture(); f.tdlib.getReceiveLoopStatus = () => { throw new Error('private fault marker'); }; f.poll();
  assert.equal(f.gateway.getState(), 'failed'); assert.ok(!JSON.stringify(f.logs).includes('private fault marker'));
  const g = await fixture(); g.tdlib.ackReceiveBatch = () => false; g.emit([update]); await g.drain();
  assert.equal(g.gateway.getState(), 'failed'); assert.equal(g.gateway.clientId, 1);
});
test('malformed admitted JSON faults once without fake consumption', async () => {
  const f = await fixture(); assert.equal(f.emit('[broken]'), true); await f.drain();
  assert.equal(f.gateway.getState(), 'failed'); assert.deepEqual(f.acks, []);
});
test('Closed retirement can cancel queued old envelopes and return every charged batch', async () => {
  const f = await fixture();
  f.emit([{ '@type': 'updateAuthorizationState', '@client_id': 1, authorization_state: { '@type': 'authorizationStateClosed' } }]);
  f.emit([update]); await f.drain();
  assert.equal(f.gateway.clientId, 0); assert.equal(f.gateway.getState(), 'closed'); assert.equal(f.acks.length, 2);
  assert.equal(new Set(f.acks.map(x => x[1])).size, 2);
});
test('synthetic request correlation is monotonic and 406 stays silent', async () => {
  const f = await fixture(); let error;
  const pending = f.gateway.send('getMe').catch(e => { error = e; });
  const request = f.calls[0];
  assert.match(request['@extra'], /^req_\d+_g\d+$/);
  f.emit([{ '@type': 'error', '@client_id': 1, '@extra': request['@extra'], code: 406, message: 'private 406 marker' }]);
  await f.drain(); await pending;
  assert.equal(error.tdlibCode, 406); assert.equal(error.message, ''); assert.ok(!JSON.stringify(f.logs).includes('private 406 marker'));
});
async function main() {
  let failed = 0;
  for (const [name, run] of tests) {
    try { await run(); console.log(`PASS ${name}`); } catch (error) { failed++; console.log(`FAIL ${name}: ${error.message}`); }
  }
  console.log(`SUMMARY ${tests.length - failed} passed, ${failed} failed`); process.exitCode = failed ? 1 : 0;
}
const suiteWatchdog = setTimeout(() => { console.error('HARNESS_ERROR unresolved receive suite'); process.exit(2); }, 15000);
main().catch(error => { console.error(error); process.exitCode = 2; }).finally(() => clearTimeout(suiteWatchdog));
