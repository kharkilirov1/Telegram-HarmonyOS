// Node >=24: actual commands, serializer, DTO, use case, AppStore and chatsReducer.
// Only hilog/native gateway are test boundaries; no build, device or account actions.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const sources = {};
const errors = [];
const hilog = { debug() {}, info() {}, warn() {}, error(...args) { errors.push(args); } };
function load(relative, deps = {}) {
  const file = path.join(root, relative);
  assert.ok(fs.existsSync(file), `required R6 source missing: ${relative}`);
  const source = fs.readFileSync(file, 'utf8');
  sources[relative] = createHash('sha256').update(source).digest('hex');
  const names = [...source.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, '');
  const js = stripTypeScriptTypes(code, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const td = load('models/td/common/index.ets');
const commands = load('core/model/AppCommand.ets');
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...td, ...commands, hilog });
let modules;
function production() {
  if (modules) return modules;
  const accessors = load('core/utils/tdAccessors.ets', td);
  const dto = load('core/model/dto/GroupAccessDto.ets', { ...td, ...accessors });
  const A = load('core/model/AppState.ets', dto);
  const E = load('core/model/AppEvent.ets', dto);
  const clone = load('core/utils/stateClone.ets', { ...A, ...dto });
  const reducer = load('core/reducers/chatsReducer.ets', { ...A, ...E, ...clone, ...dto, ...accessors, hilog });
  const invariants = load('core/invariants/assertInvariants.ets', { ...A, ...accessors, hilog });
  const store = load('core/store/AppStore.ets', { ...A, ...invariants, hilog });
  const appErrors = load('core/model/AppError.ets');
  const usecase = load('domain/usecases/loadChatAccess.ets', {
    ...td, ...accessors, ...dto, ...E, ...commands, ...store, ...appErrors, hilog
  });
  assert.equal(typeof usecase.LoadChatAccessUseCase, 'function');
  assert.equal(typeof usecase.createLoadChatAccessUseCase, 'function');
  modules = { ...dto, ...A, ...E, ...store, ...usecase, ...reducer };
  return modules;
}
function response(kind, id, status = { '@type': 'chatMemberStatusMember' }) {
  return td.TdObject.fromJSON(JSON.stringify({ '@type': kind, id, is_active: true, status }));
}
function deferred() {
  let resolve, reject;
  const promise = new Promise((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}
const turn = () => new Promise(resolve => setImmediate(resolve));
function fixture() {
  const m = production();
  const store = new m.AppStore(m.chatsReducer, undefined, false);
  const pending = [];
  const gateway = { send(command) {
    const request = { command, ...deferred() };
    pending.push(request);
    return request.promise;
  } };
  const usecase = m.createLoadChatAccessUseCase(store.createScope(), gateway);
  const get = (kind, id) => (kind === 'supergroup' ? store.getState().chats.supergroupAccess : store.getState().chats.basicGroupAccess).get(id);
  async function live(kind, id, status) {
    const access = m.createGroupAccessDtoFromTd(response(kind, id, status), kind);
    assert.ok(access, 'live fixture must be valid');
    await store.dispatch(m.createGroupAccessUpdatedEvent(access));
    return get(kind, id);
  }
  return { ...m, store, gateway, pending, usecase, get, live };
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
for (const [kind, factory, method, field] of [
  ['supergroup', 'createGetSupergroupCommand', 'getSupergroup', 'supergroup_id'],
  ['basicGroup', 'createGetBasicGroupCommand', 'getBasicGroup', 'basic_group_id']
]) {
  test(`${method}: exact td_api method and int53 parameter`, () => {
    assert.equal(typeof commands[factory], 'function', `${factory} must exist`);
    const id = 4503599627370495;
    const command = commands[factory](id);
    assert.equal(command.type, method);
    const serialized = serializer.serializeCommand(command);
    assert.equal(serialized.method, method);
    assert.deepEqual(JSON.parse(serialized.params.toJSON()), { [field]: id });
    assert.notEqual(commands[factory](19).payload, command.payload);
  });
  test(`${kind}: valid direct response hydrates the requested group`, async () => {
    const f = fixture();
    const result = f.usecase.load(kind, 4503599627370495);
    await turn();
    assert.equal(f.pending.length, 1);
    assert.equal(f.pending[0].command.type, method);
    assert.equal(serializer.serializeCommand(f.pending[0].command).params.getNumber(field), 4503599627370495);
    f.pending[0].resolve(response(kind, 4503599627370495));
    await result;
    assert.equal(f.get(kind, 4503599627370495).isMember, true);
    assert.equal(f.get(kind, 4503599627370495).kind, kind);
    assert.equal(f.get(kind, 4503599627370495).groupId, 4503599627370495);
    assert.equal(f.get(kind === 'supergroup' ? 'basicGroup' : 'supergroup', 4503599627370495), undefined);
  });
  for (const [label, badResponse] of [
    ['plain record', () => ({ '@type': kind, is_active: true, id: 51, status: { '@type': 'chatMemberStatusMember' } })],
    ['null', () => null],
    ['TDLib error', () => td.TdObject.fromJSON('{"@type":"error","code":500,"message":"failed"}')],
    ['unknown status', () => response(kind, 51, { '@type': 'chatMemberStatusFuture' })],
    ['missing status', () => td.TdObject.fromJSON(JSON.stringify({ '@type': kind, is_active: true, id: 51 }))],
    ['creator without membership', () => response(kind, 51, { '@type': 'chatMemberStatusCreator' })],
    ['creator with malformed membership', () => response(kind, 51, { '@type': 'chatMemberStatusCreator', is_member: 'true' })],
    ['wrong kind', () => response(kind === 'supergroup' ? 'basicGroup' : 'supergroup', 51)],
    ['FullInfo instead of group', () => response(kind + 'FullInfo', 51)],
    ['ID mismatch', () => response(kind, 52)],
    ['missing ID', () => td.TdObject.fromJSON(JSON.stringify({ '@type': kind, is_active: true, status: { '@type': 'chatMemberStatusMember' } }))],
    ['nested ID without direct ID', () => td.TdObject.fromJSON(JSON.stringify({ '@type': kind, is_active: true, nested: { id: 51 }, status: { '@type': 'chatMemberStatusMember' } }))],
    ['zero ID', () => response(kind, 0)],
    ['negative ID', () => response(kind, -51)],
    ['fractional ID', () => response(kind, 51.5)]
  ]) {
    test(`${kind}: reject ${label}; retry remains available`, async () => {
      const f = fixture();
      const result = f.usecase.load(kind, 51);
      const rejected = assert.rejects(result);
      await turn();
      f.pending[0].resolve(badResponse());
      await rejected;
      assert.equal(f.get(kind, 51), undefined);
      const retry = f.usecase.load(kind, 51);
      await turn();
      assert.equal(f.pending.length, 2);
      f.pending[1].resolve(response(kind, 51));
      await retry;
      assert.equal(f.get(kind, 51).isMember, true);
    });
  }
  test(`${kind}: a nested ID cannot shadow the direct response ID`, async () => {
    const f = fixture();
    const result = f.usecase.load(kind, 51);
    await turn();
    f.pending[0].resolve(td.TdObject.fromJSON(JSON.stringify({ '@type': kind, is_active: true, nested: { id: 7 }, id: 51, status: { '@type': 'chatMemberStatusLeft' } })));
    await result;
    assert.equal(f.get(kind, 51).isMember, false);
    assert.equal(f.get(kind, 7), undefined);
  });
  test(`${kind}: known status is refreshed, not an early return`, async () => {
    const f = fixture();
    const before = await f.live(kind, 51, { '@type': 'chatMemberStatusLeft' });
    const result = f.usecase.load(kind, 51);
    await turn();
    assert.equal(f.pending.length, 1);
    f.pending[0].resolve(response(kind, 51));
    await result;
    assert.notEqual(f.get(kind, 51), before);
    assert.equal(f.get(kind, 51).isMember, true);
  });
  test(`${kind}: an unrelated group update must not discard valid hydration`, async () => {
    const f = fixture();
    await f.live(kind, 51, { '@type': 'chatMemberStatusLeft' });
    const result = f.usecase.load(kind, 51);
    await turn();
    await f.live(kind, 52, { '@type': 'chatMemberStatusLeft' });
    f.pending[0].resolve(response(kind, 51));
    await result;
    assert.equal(f.get(kind, 51).isMember, true);
    assert.equal(f.get(kind, 52).isMember, false);
  });
  test(`${kind}: semantically identical live status still supersedes an older request`, async () => {
    const f = fixture();
    const before = await f.live(kind, 51, { '@type': 'chatMemberStatusMember' });
    const result = f.usecase.load(kind, 51);
    await turn();
    const after = await f.live(kind, 51, { '@type': 'chatMemberStatusMember' });
    assert.notEqual(after, before, 'live event must publish a fresh value identity');
    f.pending[0].resolve(response(kind, 51, { '@type': 'chatMemberStatusLeft' }));
    await result;
    assert.equal(f.get(kind, 51), after);
    assert.equal(f.get(kind, 51).isMember, true);
  });
  for (const known of [false, true]) {
    test(`${kind}: newer live update wins ${known ? 'known' : 'unknown'} hydration at dequeue`, async () => {
      const f = fixture();
      if (known) await f.live(kind, 51, { '@type': 'chatMemberStatusMember' });
      const result = f.usecase.load(kind, 51);
      await turn();
      // Response continuation queues hydration AFTER the live event, but runs
      // BEFORE that event's reducer. A pre-dispatch-only identity check is stale.
      f.pending[0].resolve(response(kind, 51));
      const newer = f.createGroupAccessDtoFromTd(response(kind, 51, { '@type': 'chatMemberStatusLeft' }), kind);
      const update = f.store.dispatch(f.createGroupAccessUpdatedEvent(newer));
      await update;
      const liveValue = f.get(kind, 51);
      await result;
      assert.equal(f.get(kind, 51), liveValue);
      assert.equal(f.get(kind, 51).isMember, false);
    });
  }
}
test('invalid kind and IDs reject without sending commands', async () => {
  const f = fixture();
  for (const id of [0, -1, 0.5, NaN, Infinity, -Infinity, Number.MAX_SAFE_INTEGER + 1, '51', undefined]) {
    await assert.rejects(f.usecase.load('supergroup', id));
  }
  for (const kind of ['channel', '', undefined]) await assert.rejects(f.usecase.load(kind, 51));
  assert.equal(f.pending.length, 0);
});
test('same kind/ID shares a single promise and cleans up on success', async () => {
  const f = fixture();
  const first = f.usecase.load('supergroup', 51);
  const second = f.usecase.load('supergroup', 51);
  assert.equal(first, second);
  await turn();
  assert.equal(f.pending.length, 1);
  f.pending[0].resolve(response('supergroup', 51));
  await Promise.all([first, second]);
  const next = f.usecase.load('supergroup', 51);
  assert.notEqual(next, first);
  await turn();
  assert.equal(f.pending.length, 2);
  f.pending[1].resolve(response('supergroup', 51));
  await next;
});
test('shared failure rejects every caller without cancelling another group', async () => {
  const f = fixture();
  const error = new Error('group unavailable');
  const first = f.usecase.load('supergroup', 51);
  const second = f.usecase.load('supergroup', 51);
  const other = f.usecase.load('supergroup', 52);
  const rejected = Promise.all([assert.rejects(first, reason => reason === error), assert.rejects(second, reason => reason === error)]);
  await turn();
  assert.equal(f.pending.length, 2);
  f.pending[0].reject(error);
  await rejected;
  assert.equal(f.get('supergroup', 51), undefined);
  assert.equal(f.usecase.load('supergroup', 52), other);
  f.pending[1].resolve(response('supergroup', 52));
  await other;
  const retry = f.usecase.load('supergroup', 51);
  await turn();
  assert.equal(f.pending.length, 3);
  f.pending[2].resolve(response('supergroup', 51));
  await retry;
  assert.equal(f.get('supergroup', 51).isMember, true);
});
test('distinct groups and kinds remain independent', async () => {
  const f = fixture();
  const requests = [['supergroup', 51], ['supergroup', 52], ['basicGroup', 51]];
  const promises = requests.map(([kind, id]) => f.usecase.load(kind, id));
  await turn();
  assert.equal(f.pending.length, 3);
  for (let i = 2; i >= 0; i--) f.pending[i].resolve(response(...requests[i]));
  await Promise.all(promises);
  requests.forEach(([kind, id]) => assert.equal(f.get(kind, id).isMember, true));
});
test('singleflight is per instance, not static', async () => {
  const f = fixture();
  const g = fixture();
  const first = f.usecase.load('supergroup', 51);
  const second = g.usecase.load('supergroup', 51);
  await turn();
  assert.equal(f.pending.length, 1);
  assert.equal(g.pending.length, 1);
  f.pending[0].resolve(response('supergroup', 51));
  g.pending[0].resolve(response('supergroup', 51, { '@type': 'chatMemberStatusLeft' }));
  await Promise.all([first, second]);
  assert.equal(f.get('supergroup', 51).isMember, true);
  assert.equal(g.get('supergroup', 51).isMember, false);
});
test('gateway reentrancy shares the published in-flight promise', async () => {
  const f = fixture();
  const send = f.gateway.send.bind(f.gateway);
  let reentrant;
  f.gateway.send = command => {
    if (!reentrant) reentrant = f.usecase.load('supergroup', 51);
    return send(command);
  };
  const first = f.usecase.load('supergroup', 51);
  await turn();
  assert.equal(f.pending.length, 1);
  assert.equal(reentrant, first);
  f.pending[0].resolve(response('supergroup', 51));
  await first;
});
for (const synchronous of [false, true]) {
  test(`${synchronous ? 'sync throw' : 'async rejection'} clears singleflight before caller retry`, async () => {
    const f = fixture();
    const error = new Error('gateway failed');
    const send = f.gateway.send.bind(f.gateway);
    let attempts = 0;
    f.gateway.send = command => {
      if (++attempts === 1) {
        if (synchronous) throw error;
        return Promise.reject(error);
      }
      return send(command);
    };
    const first = f.usecase.load('supergroup', 51);
    const retry = first.catch(reason => {
      assert.equal(reason, error);
      return f.usecase.load('supergroup', 51);
    });
    await turn();
    assert.equal(attempts, 2);
    assert.equal(f.pending.length, 1);
    f.pending[0].resolve(response('supergroup', 51));
    await retry;
    assert.equal(f.get('supergroup', 51).isMember, true);
  });
}
test('store notification reentrancy does not launch another hydration', async () => {
  const f = fixture();
  let reentrant;
  const unsubscribe = f.store.subscribe(() => { reentrant = f.usecase.load('supergroup', 51); });
  const first = f.usecase.load('supergroup', 51);
  await turn();
  f.pending[0].resolve(response('supergroup', 51));
  await first;
  unsubscribe();
  assert.equal(reentrant, first);
  assert.equal(f.pending.length, 1);
});
for (const queued of [false, true]) {
  test(`${queued ? 'queued reset' : 'reset'} rejects late old-account writes and new account can hydrate`, async () => {
    const f = fixture();
    const first = f.usecase.load('supergroup', 51);
    await turn();
    if (queued) await f.store.resetStateQueued();
    else f.store.resetState();
    const current = f.createLoadChatAccessUseCase(f.store.createScope(), f.gateway);
    const second = current.load('supergroup', 51);
    await turn();
    f.pending[1].resolve(response('supergroup', 51, { '@type': 'chatMemberStatusLeft' }));
    await second;
    const newer = f.get('supergroup', 51);
    f.pending[0].resolve(response('supergroup', 51));
    await first;
    assert.equal(f.get('supergroup', 51), newer);
    assert.equal(f.get('supergroup', 51).isMember, false);
  });
}
test('constructor captures account scope even when passed the root store', async () => {
  const f = fixture();
  const usecase = f.createLoadChatAccessUseCase(f.store, f.gateway);
  const result = usecase.load('supergroup', 51);
  await turn();
  f.store.resetState();
  f.pending[0].resolve(response('supergroup', 51));
  await result;
  assert.equal(f.get('supergroup', 51), undefined);
});
test('account invalidation at hydration dequeue drops the already queued write', async () => {
  const f = fixture();
  const result = f.usecase.load('supergroup', 51);
  await turn();
  const resetOnLive = f.store.subscribe(() => { f.store.invalidateScopes(); });
  f.pending[0].resolve(response('supergroup', 51));
  const other = f.createGroupAccessDtoFromTd(response('supergroup', 52), 'supergroup');
  await f.store.dispatch(f.createGroupAccessUpdatedEvent(other));
  resetOnLive();
  await result;
  assert.equal(f.get('supergroup', 51), undefined);
  assert.equal(f.get('supergroup', 52).isMember, true);
});
async function main() {
  let failed = 0;
  assert.ok(tests.length > 0);
  for (const { name, run } of tests) {
    const before = errors.length;
    try {
      await run();
      assert.deepEqual(errors.slice(before), [], 'no swallowed reducer/store errors');
      console.log('PASS', name);
    } catch (error) {
      failed++;
      console.error('FAIL', name, error.stack);
      if (errors.length > before) console.error('STORE_ERRORS', JSON.stringify(errors.slice(before)));
    }
  }
  console.log(JSON.stringify({ passed: tests.length - failed, failed, sources }));
  process.exitCode = failed ? 1 : 0;
}
main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
