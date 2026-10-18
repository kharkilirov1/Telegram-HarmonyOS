// Actual gateway/dispatcher/DTO with an explicitly controlled native and scheduler boundary.
// Native-thread timing is separately witnessed on the isolated SDK fixture.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = process.env.RECEIVE_REPO_ROOT || path.resolve(__dirname, '..');
const gatewayPath = process.env.RECEIVE_GATEWAY_SOURCE || path.join(root, 'entry/src/main/ets/infra/td/gateway/TdGateway.ets');
function load(relative, deps = {}) {
  const file = relative.endsWith('TdGateway.ets') ? gatewayPath : path.join(root, 'entry/src/main/ets', relative);
  const source = fs.readFileSync(file, 'utf8');
  const exports = [...source.matchAll(/^export\s+(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), `${js}\nreturn {${exports.join(',')}}`)(...Object.values(deps));
}
async function fixture() {
  let clock = 100, readCost = 0, parseCost = 0, sequence = 0, batch = 0, callback, ackHook;
  const timers = new Map(), ledger = new Map(), calls = [], acks = [], updates = [], trace = [], logs = [];
  const invariantErrors = [];
  const errors = load('core/model/AppError.ets'), { TdObject } = load('models/td/common/index.ets');
  const hilog = Object.fromEntries(['info', 'warn', 'error', 'debug'].map(k => [k, (...a) => logs.push(a)]));
  const { MainThreadDispatcher } = load('infra/threading/MainThreadDispatcher.ets', { hilog });
  const dispatcher = new MainThreadDispatcher();
  const timer = (fn, ms) => { const id = ++sequence; timers.set(id, { fn, due: clock + ms, ms }); return id; };
  const tdlib = {
    createClient: () => 1, startReceiveLoop(cb) { callback = cb; return 7; },
    getReceiveLoopStatus: () => 1, stopReceiveLoop: () => Promise.resolve(),
    send(client, json) { const req = JSON.parse(json); calls.push(req); trace.push({ stage: 'send', at: clock, token: req['@extra'] }); },
    ackReceiveBatch(epoch, id) {
      try {
      if (epoch !== 7 || !ledger.has(id)) return false;
      assert.notEqual(gateway.activeBatch?.batchId, id, 'ACK while this batch is still active');
      assert(!gateway.pendingBatchQueue.some(b => b.batchId === id), 'ACK while this batch is queued');
      if (!gateway.activeBatch) assert.equal(gateway.drainItems.length, 0, 'ACK before parsed references cleared');
      ledger.delete(id);
      assert.equal(gateway.admittedBatchCount, ledger.size, 'Batch credits diverged');
      assert.equal(gateway.admittedBatchBytes, [...ledger.values()].reduce((a,b) => a+b, 0), 'Byte credits diverged');
      acks.push(id); trace.push({ stage: 'ack', at: clock, id });
      if (ackHook) ackHook(id);
      return true;
      } catch (error) { invariantErrors.push(error.message); throw error; }
    }
  };
  const clockApi = { TimeType: { STARTUP: 0 }, getUptime() { const now = clock; clock += readCost; return now; } };
  const jsonApi = { stringify: JSON.stringify, parse(s) { const v = JSON.parse(s); if (Array.isArray(v)) clock += parseCost; return v; } };
  const { TdGatewayImpl } = load('infra/td/gateway/TdGateway.ets', { ...errors, TdObject, hilog, tdlib, JSON: jsonApi,
    systemDateTime: clockApi, getMainThreadDispatcher: () => dispatcher,
    setTimeout: timer, clearTimeout: id => timers.delete(id), setInterval: () => ++sequence, clearInterval() {} });
  const gateway = TdGatewayImpl.getInstance();
  dispatcher.subscribeUpdates(raw => gateway.handleUpdateOnMainThread(raw));
  await gateway.initialize();
  const original = gateway.drainSlice.bind(gateway);
  gateway.drainSlice = d => { trace.push({ stage: 'slice-start', at: clock, updates: updates.length }); original(d); trace.push({ stage: 'slice-end', at: clock, updates: updates.length }); };
  const f = { gateway, tdlib, dispatcher, calls, acks, updates, trace, logs, timers, ledger, invariantErrors,
    onAck(fn) { ackHook = fn; },
    now: () => clock, cost(n) { clock += n; }, readCost(n) { readCost = n; }, parseCost(n) { parseCost = n; },
    timer, emit(items) { const json = JSON.stringify(items), id = ++batch; assert(ledger.size < 4); ledger.set(id, Buffer.byteLength(json)); trace.push({ stage: 'native-boundary', at: clock, id }); const accepted = callback(json, 7, id, Buffer.byteLength(json)); trace.push({ stage: 'admitted', at: clock, id, accepted }); return accepted; },
    async next() { const first = [...timers].sort((a,b) => a[1].due - b[1].due || a[0] - b[0])[0]; if (!first) return false; timers.delete(first[0]); clock = Math.max(clock, first[1].due); first[1].fn(); await Promise.resolve(); await Promise.resolve(); return true; },
    async until(end) { for (let n = 0; n < 5000; n++) { const due = Math.min(...[...timers.values()].map(t => t.due)); if (!Number.isFinite(due) || due > end) return; await this.next(); } assert.fail('Bounded scheduler exhausted'); },
    request(method = 'getMe') { const outcome = { status: 'pending', settled: 0 }; gateway.send(method).then(() => { outcome.status = 'resolved'; outcome.settled++; trace.push({ stage: 'promise-resolve', at: clock }); }, error => { outcome.status = 'rejected'; outcome.settled++; outcome.kind = error.kind; trace.push({ stage: 'promise-reject', at: clock }); }); return outcome; }
  };
  return f;
}
const update = i => ({ '@type': 'updateOption', '@client_id': 1, testIndex: i, name: 'synthetic', value: { '@type': 'optionValueInteger', value: i } });
const response = token => ({ '@type': 'user', '@client_id': 1, '@extra': token, id: 1 });
const tests = [], receipts = [];
const test = (name, run) => tests.push([name, run]);
let current;
const create = async () => (current = await fixture());

test('one response progresses when first budget check costs exactly8ms', async () => {
  const f = await create(), p = f.request(); f.emit([response(f.calls[0]['@extra'])]); f.readCost(8);
  await f.next(); assert.equal(p.status, 'resolved', 'Ready response starved before first item'); assert.equal(p.settled, 1); assert.deepEqual(f.acks, [1]);
});
test('one response progresses under50ms intra-callback clock delay', async () => {
  const f = await create(), p = f.request(); f.emit([response(f.calls[0]['@extra'])]); f.readCost(50);
  await f.next(); assert.equal(p.status, 'resolved', 'Pre-work delay produced an empty slice'); assert.equal(p.settled, 1); assert.deepEqual(f.acks, [1]);
});
test('expensive batch parsing still transfers one item before yielding', async () => {
  const f = await create(), p = f.request(); f.emit([response(f.calls[0]['@extra'])]); f.parseCost(9);
  await f.next(); assert.equal(p.status, 'resolved', 'Parsing alone consumed the first useful quantum'); assert.deepEqual(f.acks, [1]);
});
test('already-admitted response behind199 bounded updates beats unchanged30s deadline', async () => {
  const f = await create(), p = f.request();
  f.gateway.subscribeUpdates(u => { f.updates.push(u.getNumber('testIndex')); f.cost(8); });
  for (let b = 0; b < 4; b++) { const items = Array.from({ length: b === 3 ? 49 : 50 }, (_,i) => update(b * 50 + i)); if (b === 3) items.push(response(f.calls[0]['@extra'])); assert.equal(f.emit(items), true); }
  await f.until(35000); assert.equal(p.status, 'resolved', 'Local pacing exhausted deadline for an admitted response');
  assert.equal(p.settled, 1); assert.deepEqual(f.updates, Array.from({ length: 199 }, (_,i) => i)); assert.deepEqual(f.acks, [1,2,3,4]); assert.equal(f.ledger.size, 0);
});
test('slow synchronous handler yields and keeps active batch charged', async () => {
  const f = await create(); f.gateway.subscribeUpdates(u => { f.updates.push(u.getNumber('testIndex')); f.cost(40); });
  f.emit([update(0), update(1)]); await f.next(); assert.deepEqual(f.updates, [0]); assert.equal(f.ledger.size, 1); assert.equal(f.acks.length, 0);
  let opportunity = false; f.timer(() => { opportunity = true; }, 1); await f.next(); assert(opportunity, 'Competing macrotask did not receive an opportunity');
  await f.until(1000); assert.deepEqual(f.updates, [0,1]); assert.deepEqual(f.acks, [1]);
});

for (const clockCost of [0, -1]) test(`one turn transfers at most50 items with clock cost ${clockCost}`, async () => {
  const f = await create(); f.gateway.subscribeUpdates(u => f.updates.push(u.getNumber('testIndex')));
  for (let b = 0; b < 4; b++) f.emit(Array.from({ length: 50 }, (_,i) => update(b * 50 + i)));
  f.readCost(clockCost); await f.next();
  assert.equal(f.updates.length, 50, 'A coarse/backward clock must not permit the whole backlog in one turn');
  assert.deepEqual(f.acks, [1]); assert.equal(f.ledger.size, 3);
  let opportunity = false; f.timer(() => { opportunity = true; }, 1); await f.next(); assert(opportunity);
  await f.until(1000); assert.deepEqual(f.updates, Array.from({ length: 200 }, (_,i) => i));
  assert.deepEqual(f.acks, [1,2,3,4]); assert.equal(f.ledger.size, 0);
});

test('empty batches with reentrant credit refill remain bounded per turn', async () => {
  const f = await create(); let refilled = 0;
  f.onAck(() => { if (refilled++ < 12) assert.equal(f.emit([]), true); });
  for (let i = 0; i < 4; i++) f.emit([]);
  await f.next(); assert.equal(f.acks.length, 4, 'Empty/refilled batches bypassed the per-turn load bound');
  assert.equal(f.ledger.size, 4);
  await f.until(1000); assert.equal(f.acks.length, 16); assert.equal(new Set(f.acks).size, 16); assert.equal(f.ledger.size, 0);
});
test('deadline-before-response rejects once and later delivery is not replayed', async () => {
  const f = await create(), p = f.request(); await f.until(30100); assert.equal(p.status, 'rejected');
  f.emit([response(f.calls[0]['@extra'])]); await f.until(31000); assert.equal(p.status, 'rejected'); assert.equal(p.settled, 1); assert.deepEqual(f.acks, [1]); assert.equal(f.calls.length, 1);
});
test('response-before-deadline cancels timeout and resolves once', async () => {
  const f = await create(), p = f.request(); f.emit([response(f.calls[0]['@extra'])]); await f.until(31000);
  assert.equal(p.status, 'resolved'); assert.equal(p.settled, 1); assert.equal(f.calls.length, 1); assert.deepEqual(f.acks, [1]);
});

for (const offset of [-1, 0, 1]) test(`response dispatch at deadline${offset >= 0 ? '+' : ''}${offset} respects timer order`, async () => {
  const f = await create(), p = f.request();
  // Admission schedules a real 2ms drain timer. The request timer was inserted first.
  f.timer(() => f.emit([response(f.calls[0]['@extra'])]), 30000 + offset - 2);
  await f.until(30200);
  assert.equal(p.status, offset < 0 ? 'resolved' : 'rejected'); assert.equal(p.settled, 1);
  assert.deepEqual(f.acks, [1]); assert.equal(f.calls.length, 1); assert.equal(f.ledger.size, 0);
});
test('fresh response first quantum cannot revive a retired generation', async () => {
  const f = await create(); let n = 0; f.gateway.subscribeUpdates(() => n++);
  f.emit([{ '@type': 'updateAuthorizationState', '@client_id': 1, authorization_state: { '@type': 'authorizationStateClosed' } }, update(1)]);
  f.emit([update(2)]); f.readCost(8); await f.until(5000);
  assert.equal(f.gateway.getState(), 'closed'); assert.equal(n, 1); assert.deepEqual(f.acks.sort(), [1,2]); assert.equal(new Set(f.acks).size, 2);
});
test('reentrant terminal fault during transfer does not ACK ambiguous work', async () => {
  const f = await create(); f.gateway.subscribeUpdates(() => { f.gateway.failDelivery(102); }); f.emit([update(0), update(1)]); f.readCost(8); await f.until(5000);
  assert.equal(f.gateway.getState(), 'failed'); assert.deepEqual(f.acks, []); assert.equal(f.calls.length, 0);
});
async function main() {
  let failed = 0;
  for (const [name, run] of tests) { current = null; try { await run(); assert.deepEqual(current?.invariantErrors, [], 'Native boundary invariant failed even if production caught the exception'); console.log('PASS '+name); receipts.push({ name, result: 'PASS', trace: current?.trace }); } catch(e) { failed++; console.log('FAIL '+name+': '+e.message); receipts.push({ name, result: 'FAIL', error: e.message, invariantErrors: current?.invariantErrors, trace: current?.trace }); } }
  const result = { gatewayPath, sourceSha256: require('node:crypto').createHash('sha256').update(fs.readFileSync(gatewayPath)).digest('hex'), scope: 'Actual source with controlled native admission and due-time scheduler; not an emulator replay', passed: tests.length-failed, failed, receipts };
  if (process.env.RECEIVE_SCHED_REPORT) fs.writeFileSync(process.env.RECEIVE_SCHED_REPORT, JSON.stringify(result,null,2)+'\n', { flag: 'wx' });
  console.log(`SUMMARY ${tests.length-failed} passed, ${failed} failed`); process.exitCode = failed ? 1 : 0;
}
main().catch(e => { console.error(e); process.exitCode = 2; });
