// Node >=24. Executes the actual lease, TdObject, commands, serializer, adapter
// and Hypium bodies. Only transport and the Hypium/platform surfaces are fakes.
// No build/device/network. Mutations are in-memory; source hashes must stay stable.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const mainRoot = 'entry/src/main/ets/';
const leasePath = mainRoot + 'domain/usecases/ChatOpenLease.ets';
const nativePath = 'entry/src/ohosTest/ets/test/ChatOpenLease.test.ets';
const mutant = process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9);
assert.ok(!mutant || ['open', 'close', 'result'].includes(mutant), 'unknown mutation');
const hashes = new Map();
const digest = source => createHash('sha256').update(source).digest('hex');
hashes.set('scripts/test-chat-open-lease.cjs', digest(fs.readFileSync(__filename, 'utf8')));
let mutations = 0;
function load(relative, deps = {}) {
  let source = fs.readFileSync(path.join(root, relative), 'utf8');
  hashes.set(relative, digest(source));
  source = source.replaceAll('\r\n', '\n');
  if (relative === leasePath && mutant) {
    const changes = {
      open: ['if (this.pending !== undefined)', 'if (false)'],
      close: ['if (acquisition === undefined || !await acquisition)', 'if (acquisition === undefined)'],
      result: ["result instanceof TdObject && result.getTopLevelStringStrict('@type') === 'ok'", 'true']
    };
    const [before, after] = changes[mutant];
    assert.equal(source.split(before).length - 1, 1, 'mutation must engage exactly one intended site');
    source = source.replace(before, after);
    mutations++;
  }
  const names = [...source.matchAll(/^export\s+(?:default\s+)?(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() {
  let resolve, reject;
  const promise = new Promise((ok, fail) => { resolve = ok; reject = fail; });
  return { promise, resolve, reject };
}
async function bounded(run) {
  let timer;
  try {
    await Promise.race([Promise.resolve().then(run), new Promise((_resolve, reject) => {
      timer = setTimeout(() => reject(new assert.AssertionError({ message: 'test did not settle (possible circular await)' })), 1500);
    })]);
  } finally { clearTimeout(timer); }
}
async function main() {
  if (!fs.existsSync(path.join(root, leasePath))) {
    console.error('STRUCTURAL BASELINE FAIL: missing ChatOpenLease helper; not an old-app behavioral result');
    process.exitCode = 1;
    return;
  }
  const C = load(mainRoot + 'core/model/AppCommand.ets');
  const td = load(mainRoot + 'models/td/common/index.ets');
  const { ChatOpenLease } = load(leasePath, { ...C, ...td });
  const ok = () => td.TdObject.fromJSON('{"@type":"ok"}');
  function fixture(id = 7, response = ok()) {
    const commands = [];
    const open = deferred();
    const close = deferred();
    const f = { commands, open, close, deferOpen: false, deferClose: false, response,
      send(command) {
        commands.push(command);
        if (command.type === 'openChat') return f.deferOpen ? open.promise : Promise.resolve(f.response);
        assert.equal(command.type, 'closeChat');
        return f.deferClose ? close.promise : Promise.resolve(ok());
      }
    };
    f.lease = new ChatOpenLease(id, f);
    return f;
  }
  const types = f => f.commands.map(c => c.type).join(',');
  test('one pending promise and one cached acknowledged result', async () => {
    const f = fixture(); f.deferOpen = true;
    const first = f.lease.ensureOpen(() => true);
    assert.equal(f.lease.ensureOpen(() => true), first);
    await tick(); assert.equal(types(f), 'openChat'); assert.equal(f.lease.isOpen(), false);
    f.open.resolve(ok()); assert.equal(await first, true); assert.equal(f.lease.isOpen(), true);
    assert.equal(f.lease.ensureOpen(() => true), first);
    assert.equal(await first, true); assert.equal(types(f), 'openChat');
    await f.lease.release(); assert.equal(types(f), 'openChat,closeChat');
  });
  for (const id of [0, -0, NaN, Infinity, -Infinity, 1.5, -1.5, Number.MAX_SAFE_INTEGER + 1, Number.MIN_SAFE_INTEGER - 1]) {
    test(`invalid chat id ${String(id)} never sends or retries`, async () => {
      const f = fixture(id);
      assert.equal(await f.lease.ensureOpen(() => true), false);
      assert.equal(await f.lease.ensureOpen(() => true), false);
      await f.lease.release(); assert.equal(types(f), '');
    });
  }
  for (const id of [7, -100123, Number.MAX_SAFE_INTEGER, Number.MIN_SAFE_INTEGER]) {
    test(`safe nonzero id ${id} is retained by open and close`, async () => {
      const f = fixture(id);
      assert.equal(await f.lease.ensureOpen(() => true), true);
      const releasing = f.lease.release();
      assert.equal(f.lease.isReleased(), true); assert.equal(f.lease.isOpen(), false);
      await releasing; await f.lease.release();
      assert.equal(types(f), 'openChat,closeChat');
      assert.deepEqual(f.commands.map(c => c.payload.chatId), [id, id]);
    });
  }
  for (const throws of [false, true]) {
    test(`preflight ${throws ? 'throws' : 'false'} is cached without dispatch`, async () => {
      const f = fixture();
      const first = f.lease.ensureOpen(() => { if (throws) throw new Error('scope'); return false; });
      assert.equal(await first, false); assert.equal(await f.lease.ensureOpen(() => true), false);
      await f.lease.release(); assert.equal(types(f), '');
    });
  }
  const built = new td.TdObject(); built.setString('@type', 'ok');
  const nonOk = [
    ['fulfilled Error', new Error('fulfilled')], ['plain ok', JSON.parse('{"@type":"ok"}')],
    ['null', null], ['undefined', undefined], ['boolean', true], ['number', 1], ['string', 'ok'],
    ['empty TdObject', td.TdObject.empty()], ['builder-only ok', built],
    ...['{"@type":"error","code":400}', '{"@type":"chat"}', '{}',
      '{"nested":{"@type":"ok"}}', '{"nested":{"@type":"ok"},"@type":"error"}',
      '{"@type":true}', '[{"@type":"ok"}]', 'null', '{"@type":"ok"'].map(json => [json, td.TdObject.fromJSON(json)])
  ];
  for (const [name, response] of nonOk) {
    test(`non-ack ${name} never owns close or retries`, async () => {
      const f = fixture(); f.response = response;
      assert.equal(await f.lease.ensureOpen(() => true), false);
      assert.equal(f.lease.isOpen(), false);
      assert.equal(await f.lease.ensureOpen(() => true), false);
      await f.lease.release(); await f.lease.release(); assert.equal(types(f), 'openChat');
    });
  }
  test('strict top-level ok overrides misleading nested type', async () => {
    const f = fixture(7, td.TdObject.fromJSON('{"nested":{"@type":"error"},"@type":"ok"}'));
    assert.equal(await f.lease.ensureOpen(() => true), true);
    await f.lease.release(); assert.equal(types(f), 'openChat,closeChat');
  });
  test('release before ensure permanently blocks acquisition', async () => {
    const f = fixture(); await f.lease.release();
    assert.equal(await f.lease.ensureOpen(() => true), false); assert.equal(types(f), '');
  });
  test('same-turn release cancels reserved but not dispatched acquisition', async () => {
    const f = fixture(); const opening = f.lease.ensureOpen(() => true);
    const releasing = f.lease.release();
    assert.equal(f.lease.isReleased(), true); assert.equal(f.lease.isOpen(), false);
    await releasing; assert.equal(await opening, false); assert.equal(types(f), '');
  });
  for (const outcome of ['ack', 'error', 'reject']) {
    test(`release while pending ${outcome} waits and closes only own ack once`, async () => {
      const f = fixture(); f.deferOpen = true;
      const opening = f.lease.ensureOpen(() => true); await tick();
      let done = false;
      const releasing = f.lease.release(); releasing.then(() => { done = true; });
      const duplicate = f.lease.release();
      assert.equal(f.lease.isReleased(), true); assert.equal(f.lease.isOpen(), false);
      assert.equal(await f.lease.ensureOpen(() => true), false);
      await tick(); assert.equal(types(f), 'openChat'); assert.equal(done, false);
      if (outcome === 'reject') f.open.reject(new Error('transport'));
      else f.open.resolve(outcome === 'ack' ? ok() : new Error('fulfilled'));
      assert.equal(await opening, false); await releasing; await duplicate;
      assert.equal(types(f), outcome === 'ack' ? 'openChat,closeChat' : 'openChat');
    });
  }
  for (const throws of [false, true]) {
    test(`scope ${throws ? 'throws' : 'false'} after pending ack releases instead of leaking`, async () => {
      const f = fixture(); f.deferOpen = true; let current = true;
      const opening = f.lease.ensureOpen(() => { if (!current && throws) throw new Error('scope'); return current; });
      await tick(); assert.equal(types(f), 'openChat'); current = false; f.open.resolve(ok());
      assert.equal(await opening, false); assert.equal(f.lease.isOpen(), false); assert.equal(f.lease.isReleased(), true);
      await f.lease.release(); assert.equal(types(f), 'openChat,closeChat');
    });
  }
  test('callback reentry cannot duplicate acquire', async () => {
    const f = fixture(); let nested;
    const opening = f.lease.ensureOpen(() => { nested = f.lease.ensureOpen(() => true); return true; });
    assert.equal(await opening, true); assert.equal(nested, opening);
    await f.lease.release(); assert.equal(types(f), 'openChat,closeChat');
  });
  test('callback can release synchronously without sending open afterward', async () => {
    const f = fixture(); let closing;
    const opening = f.lease.ensureOpen(() => { closing = f.lease.release(); return true; });
    assert.equal(await opening, false); await closing; assert.equal(types(f), '');
  });
  test('synchronous send exception is a cached failed acquisition', async () => {
    let sends = 0;
    const lease = new ChatOpenLease(7, { send() { sends++; throw new Error('sync'); } });
    assert.equal(await lease.ensureOpen(() => true), false);
    assert.equal(await lease.ensureOpen(() => true), false); await lease.release(); assert.equal(sends, 1);
  });
  test('rejected acquisition caches failure without retry or unowned close', async () => {
    const f = fixture(); f.deferOpen = true;
    const opening = f.lease.ensureOpen(() => true); await tick(); f.open.reject(new Error('transport'));
    assert.equal(await opening, false);
    assert.equal(f.lease.ensureOpen(() => true), opening);
    assert.equal(await f.lease.ensureOpen(() => true), false);
    await f.lease.release(); assert.equal(types(f), 'openChat');
  });
  test('synchronous close exception is swallowed without replay', async () => {
    const commands = [];
    const lease = new ChatOpenLease(7, { send(command) {
      commands.push(command.type);
      if (command.type === 'closeChat') throw new Error('sync close');
      return Promise.resolve(ok());
    } });
    assert.equal(await lease.ensureOpen(() => true), true);
    await lease.release(); await lease.release();
    assert.equal(lease.isOpen(), false); assert.equal(commands.join(','), 'openChat,closeChat');
  });
  for (const outcome of ['reject', 'error', 'unknown']) {
    test(`close ${outcome} is best effort without replay`, async () => {
      const f = fixture(); f.deferClose = true;
      assert.equal(await f.lease.ensureOpen(() => true), true);
      const releasing = f.lease.release(); const duplicate = f.lease.release(); await tick();
      assert.equal(f.lease.isOpen(), false); assert.equal(types(f), 'openChat,closeChat');
      if (outcome === 'reject') f.close.reject(new Error('close'));
      else f.close.resolve(outcome === 'error' ? new Error('fulfilled') : null);
      await releasing; await duplicate; await f.lease.release();
      assert.equal(await f.lease.ensureOpen(() => true), false); assert.equal(types(f), 'openChat,closeChat');
    });
  }
  test('overlapping same-chat leases own independent acknowledged calls', async () => {
    const f = fixture(); const second = new ChatOpenLease(7, f);
    await Promise.all([f.lease.ensureOpen(() => true), second.ensureOpen(() => true)]);
    await f.lease.release(); await f.lease.release(); assert.equal(second.isOpen(), true);
    assert.equal(types(f), 'openChat,openChat,closeChat');
    await second.release(); assert.equal(types(f), 'openChat,openChat,closeChat,closeChat');
  });
  const hilog = { info() {}, warn() {}, error() {} };
  const errors = load(mainRoot + 'core/model/AppError.ets');
  const port = load(mainRoot + 'domain/ports/TdGatewayPort.ets', errors);
  const serializer = load(mainRoot + 'infra/td/serialization/CommandSerializer.ets', { ...C, ...td, hilog });
  for (const boundary of ['before open', 'pending open', 'after ack', 'current']) {
    test(`actual captured adapter fences generation change ${boundary}`, async () => {
      let generation = 1; const wire = []; const pending = deferred();
      const transport = { getClientGeneration: () => generation, isReady: () => true,
        send(method, params) { wire.push({ method, id: params.getNumber('chat_id'), generation });
          return boundary === 'pending open' ? pending.promise : Promise.resolve(ok()); } };
      const adapter = load(mainRoot + 'infra/td/adapter/TdGatewayAdapter.ets', {
        ...port, ...td, ...errors, ...serializer, hilog, getTdGateway: () => transport
      });
      const captured = adapter.getTdGatewayAdapter(); const lease = new ChatOpenLease(-100123, captured);
      if (boundary === 'before open') generation++;
      const opening = lease.ensureOpen(() => true); await tick();
      if (boundary === 'pending open') { generation++; pending.resolve(ok()); }
      assert.equal(await opening, boundary === 'after ack' || boundary === 'current');
      if (boundary === 'after ack') generation++;
      await lease.release();
      assert.equal(wire.length, boundary === 'before open' ? 0 : boundary === 'current' ? 2 : 1);
      if (wire.length) assert.deepEqual(wire[0], { method: 'openChat', id: -100123, generation: 1 });
      if (boundary === 'current') {
        assert.deepEqual(wire[1], { method: 'closeChat', id: -100123, generation: 1 });
        assert.equal(adapter.getTdGatewayAdapter(), captured);
      } else assert.notEqual(adapter.getTdGatewayAdapter(), captured);
    });
  }
  const hostCount = tests.length;
  const native = load(nativePath, { ...C, ...td, ChatOpenLease,
    describe(_name, body) { body(); },
    it(name, _flags, body) { test('Hypium: ' + name, body); },
    expect(actual) { return { assertEqual(expected) { assert.equal(actual, expected); } }; }
  });
  assert.equal(Object.keys(native).length, 1, 'expected one native suite export');
  Object.values(native)[0]();
  assert.ok(tests.length > hostCount, 'real native test bodies must register');
  let failed = 0;
  for (const { name, run } of tests) {
    try { await bounded(run); console.log('PASS', name); }
    catch (error) {
      if (error.code !== 'ERR_ASSERTION') throw error;
      failed++; console.log('FAIL', name, error.message);
    }
  }
  for (const [relative, hash] of hashes) assert.equal(digest(fs.readFileSync(path.join(root, relative), 'utf8')), hash, 'source changed during test: ' + relative);
  assert.equal(mutations, mutant ? 1 : 0);
  console.log(`${tests.length - failed}/${tests.length} PASS (${hostCount} host + ${tests.length - hostCount} actual Hypium bodies); ${hashes.size} stable source hashes`);
  if (mutant) console.log(`MUTATION ${mutant}: ${mutations} engaged site; ${failed} assertion failures`);
  process.exitCode = failed ? 1 : 0;
}
main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
