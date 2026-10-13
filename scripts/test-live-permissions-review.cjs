// Independent, host-only review of the live chat-permissions slice.
// Executes current production bodies; no native TDLib, UI, account or network IO.
// Node >=24. Optional --mutant=registration|revoke|mutation changes code IN MEMORY.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const mutant = process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9);
assert.ok(!mutant || ['registration', 'revoke', 'mutation'].includes(mutant));
const sources = new Map();
let mutationApplied = false;
function load(file, deps = {}) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  sources.set(file, createHash('sha256').update(source).digest('hex'));
  let body = source;
  const mutations = {
    registration: ['core/events/normalizers/ChatNormalizer.ets',
      "handlers.set('updateChatPermissions', handleChatPermissions);", ''],
    revoke: ['core/reducers/chatsReducer.ets',
      'if (event.updates.canSendBasicMessages !== undefined)', 'if (event.updates.canSendBasicMessages)'],
    mutation: ['core/reducers/chatsReducer.ets',
      'const updatedChat = cloneChat(existingChat);', 'const updatedChat = existingChat;']
  };
  const change = mutations[mutant];
  if (change && file === change[0]) {
    assert.ok(body.includes(change[1]), 'Mutation anchor missing');
    body = body.replaceAll(change[1], change[2]);
    mutationApplied = true;
  }
  const exports = [...source.matchAll(/^export\s+(?:class|function|enum|const)\s+(\w+)/gm)]
    .map(match => match[1]);
  body = stripTypeScriptTypes(body.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+default\s+\w+;?\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), '"use strict";\n' + body +
    `\nreturn {${exports.join(',')}};`)(...Object.values(deps));
}
const errors = [];
const hilog = { info() {}, warn() {}, debug() {}, error(...args) { errors.push(args); } };
const td = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', td);
const commands = load('core/model/AppCommand.ets');
const state = load('core/model/AppState.ets');
const group = load('core/model/dto/GroupAccessDto.ets', { ...td, ...accessors });
const dto = load('core/model/dto/ChatDto.ets', { ...td, ...accessors, ...commands, ...group, hilog });
const events = load('core/model/AppEvent.ets', { ...dto, ...group });
const clone = load('core/utils/stateClone.ets', { ...state, ...commands, ...group });
const { chatsReducer } = load('core/reducers/chatsReducer.ets', {
  ...state, ...events, ...clone, ...accessors, DtoChatType: dto.ChatType
});
const { registerChatHandlers } = load('core/events/normalizers/ChatNormalizer.ets', {
  ...td, ...accessors, ...dto, ...group, ...events, hilog
});
const { AppStore } = load('core/store/AppStore.ets', { ...state, hilog });
const handlers = new Map();
registerChatHandlers(handlers);
const raw = value => td.TdObject.fromJSON(JSON.stringify(value));
const update = (id, value) => ({ '@type': 'updateChatPermissions', chat_id: id,
  permissions: { '@type': 'chatPermissions', can_send_basic_messages: value } });
function normalize(object) {
  const output = [];
  const handler = handlers.get('updateChatPermissions');
  assert.equal(typeof handler, 'function', 'Actual registration must be engaged');
  handler(output, object);
  return output;
}
function event(id, value) {
  const output = normalize(raw(update(id, value)));
  assert.equal(output.length, 1);
  assert.equal(output[0].chatId, id);
  assert.equal(output[0].type, 'chatUpdated');
  return output[0];
}
function seed(id, value) {
  return events.createNewChatEvent(id, Object.assign(new dto.ChatDto(), {
    id, type: dto.ChatType.SUPERGROUP, supergroupId: 71, title: 'seed', canSendBasicMessages: value
  }));
}
const tests = [];
const test = (name, run) => tests.push({ name, run });

for (const value of [false, true]) {
  test(`strict literal ${value} wins over earlier nested lookalike and legacy cache`, () => {
    const object = raw({ nested: { can_send_basic_messages: !value }, can_send_basic_messages: value });
    object.setBool('can_send_basic_messages', !value);
    assert.equal(object.getTopLevelBooleanStrict('can_send_basic_messages'), value);
    assert.equal(object.getBool('can_send_basic_messages'), !value, 'Strict getter must not alter legacy cache');
    const envelope = raw({ '@type': 'updateChatPermissions', nested: update(999, !value), ...update(-71, value) });
    envelope.setNumber('chat_id', 999);
    envelope.setString('permissions', 'invalid cached replacement');
    assert.equal(normalize(envelope)[0].updates.canSendBasicMessages, value);
    assert.equal(normalize(envelope)[0].chatId, -71);
  });
  test(`strict nested object round-trip retains literal ${value} and escaped keys`, () => {
    const source = '{"@type":"updateChatPermissions","chat_\\u0069d":-71,' +
      '"permi\\u0073sions":{"nested":{"can_send_basic_messages":' + !value +
      '},"can_send_basic_\\u006dessages":' + value + '}}';
    const output = normalize(td.TdObject.fromJSON(source));
    assert.equal(output.length, 1);
    assert.equal(output[0].chatId, -71);
    assert.equal(output[0].updates.canSendBasicMessages, value);
  });
  test(`explicit ${value} changes only permission and preserves prior DTO/state snapshots`, () => {
    const d = Object.assign(new dto.ChatDto(), { id: -71, type: dto.ChatType.SUPERGROUP,
      title: 'title', order: '9007199254740993123', draftText: 'draft', canSendBasicMessages: !value });
    const patch = Object.assign(new dto.ChatUpdateDto(), { canSendBasicMessages: value });
    const originalDto = JSON.stringify(d);
    Object.freeze(d);
    const applied = dto.applyChatUpdate(d, patch);
    assert.deepEqual({ ...applied, canSendBasicMessages: !value }, { ...d });
    assert.equal(JSON.stringify(d), originalDto);
    assert.equal(applied.canSendBasicMessages, value);

    let before = chatsReducer(state.createInitialAppState(), events.createNewChatEvent(-71, d));
    before = chatsReducer(before, seed(-72, false));
    const prior = before.chats.chats.get(-71);
    const snapshot = JSON.stringify(prior);
    Object.freeze(prior);
    const changed = event(-71, value);
    const after = chatsReducer(before, changed);
    const next = after.chats.chats.get(-71);
    assert.notEqual(after, before);
    assert.notEqual(after.chats, before.chats);
    assert.notEqual(after.chats.chats, before.chats.chats);
    assert.notEqual(next, prior);
    assert.equal(next.canSendBasicMessages, value);
    assert.equal(JSON.stringify(prior), snapshot);
    assert.equal(next.sendPermissions.canSendBasicMessages, value);
    assert.equal(next.sendPermissions.canSendPhotos, false);
    assert.deepEqual({ ...next, canSendBasicMessages: !value, sendPermissions: prior.sendPermissions }, { ...prior });
    assert.deepEqual(after.chats.chats.get(-72), before.chats.chats.get(-72));
    assert.deepEqual(after.chats.orderedChatIds, before.chats.orderedChatIds);
    for (const key of ['auth', 'messages', 'users', 'files']) assert.equal(after[key], before[key]);
    changed.updates.canSendBasicMessages = !value;
    assert.equal(next.canSendBasicMessages, value, 'Reducer must not retain mutable event DTO');
    const renamed = chatsReducer(after, events.createChatUpdatedEvent(-71,
      Object.assign(new dto.ChatUpdateDto(), { title: 'renamed' })));
    assert.equal(renamed.chats.chats.get(-71).canSendBasicMessages, value);
    const placeholder = chatsReducer(state.createInitialAppState(), event(-73, value));
    assert.equal(placeholder.chats.chats.get(-73).canSendBasicMessages, value);
  });
}

const invalidJson = ['', 'null', 'true', '[]', '[{"chat_id":-71,"permissions":{"can_send_basic_messages":false}}]',
  '{', '{"chat_id":-71,"permissions":{"can_send_basic_messages":false},}',
  '{"chat_id":-71,"permissions":{"can_send_basic_messages":false}}garbage',
  '{"chat_id":-71,"permissions":{"can_send_basic_messages":False}}',
  '{"chat_id":-71,"permissions":{"can_send_basic_messages":false}} {}',
  '{"chat_id":NaN,"permissions":{"can_send_basic_messages":false}}'];
invalidJson.forEach((source, i) => test(`malformed raw JSON/root ${i} returns undefined, not an event`, () => {
  const object = td.TdObject.fromJSON(source);
  assert.equal(object.getTopLevelObjectStrict('permissions'), undefined);
  assert.equal(object.getTopLevelBooleanStrict('can_send_basic_messages'), undefined);
  assert.deepEqual(normalize(object), []);
}));

test('own-property boundary rejects prototypes and nested-only permissions/boolean', () => {
  const empty = raw({});
  for (const key of ['__proto__', 'constructor', 'toString', 'valueOf']) {
    assert.equal(empty.getTopLevelObjectStrict(key), undefined);
    assert.equal(empty.getTopLevelBooleanStrict(key), undefined);
  }
  for (const object of [
    { chat_id: -71, nested: { permissions: { can_send_basic_messages: false } } },
    { chat_id: -71, permissions: { nested: { can_send_basic_messages: false } } },
    { nested: { chat_id: -71 }, permissions: { can_send_basic_messages: false } }
  ]) assert.deepEqual(normalize(raw(object)), []);
});
for (const bad of [null, [], {}, '', 'true', 'false', 0, 1]) {
  test(`malformed boolean ${JSON.stringify(bad)} cannot use nested fallback`, () => {
    const payload = update(-71, bad);
    payload.permissions.nested = { can_send_basic_messages: true };
    assert.deepEqual(normalize(raw(payload)), []);
  });
}
test('malformed permissions object cannot use earlier nested valid object', () => {
  for (const bad of [null, [], '', false, 1]) {
    assert.deepEqual(normalize(raw({ nested: update(-71, true), ...update(-71, false), permissions: bad })), []);
  }
});
test('safe positive/negative int53 IDs are preserved and wrong ID types rejected', () => {
  for (const id of [1, -1, 9007199254740991, -9007199254740991]) assert.equal(event(id, false).chatId, id);
  for (const id of [0, -0, 1.5, -71.5, 9007199254740992, -9007199254740992, null, [], {}, true, '-71']) {
    assert.deepEqual(normalize(raw(update(id, false))), []);
  }
});
test('cache-built request semantics remain unchanged; strict update methods require raw JSON', () => {
  const object = new td.TdObject();
  object.setNumber('chat_id', -71);
  object.setBool('can_send_basic_messages', false);
  object.setString('permissions', '{"can_send_basic_messages":true}');
  const snapshot = object.toJSON();
  assert.equal(object.getTopLevelBooleanStrict('can_send_basic_messages'), undefined);
  assert.equal(object.getTopLevelObjectStrict('permissions'), undefined);
  assert.equal(object.getTopLevelNumberStrict('chat_id'), undefined);
  assert.equal(object.toJSON(), snapshot);
  assert.equal(object.getNumber('chat_id'), -71);
  assert.equal(object.getBool('can_send_basic_messages'), false);
});
test('queued revoke/grant order is retained through the real scoped serial store', async () => {
  const store = new AppStore(chatsReducer, undefined, false), scope = store.createScope();
  await scope.dispatch(seed(-71, true));
  const seen = [];
  const stop = scope.subscribe(next => seen.push(next.chats.chats.get(-71).canSendBasicMessages));
  await Promise.all([scope.dispatch(event(-71, false)), scope.dispatch(event(-71, true)),
    scope.dispatch(event(-71, false))]);
  assert.deepEqual(seen, [false, true, false]);
  assert.equal(scope.getState().chats.chats.get(-71).canSendBasicMessages, false);
  stop();
});
test('old scope cannot change a re-seeded identical ID after reset or regain current scope', async () => {
  const store = new AppStore(chatsReducer, undefined, false), old = store.createScope();
  await old.dispatch(seed(-71, true));
  let oldNotifications = 0;
  const stop = old.subscribe(() => oldNotifications++);
  const pending = old.dispatchBatch([event(-71, false), event(-71, true)]);
  const barrier = store.resetStateQueued();
  const current = store.createScope();
  const reseeded = current.dispatch(seed(-71, true));
  await Promise.all([pending, barrier, reseeded]);
  await old.dispatch(event(-71, false));
  await old.createScope().dispatch(event(-71, false));
  assert.equal(store.getState().chats.chats.get(-71).canSendBasicMessages, true);
  assert.equal(old.getState().chats.chats.size, 0);
  assert.equal(oldNotifications, 0);
  await current.dispatch(event(-71, false));
  assert.equal(store.getState().chats.chats.get(-71).canSendBasicMessages, false);
  stop();
});

let finished = false;
process.on('beforeExit', () => { if (!finished) { console.error('Unresolved review probe'); process.exitCode = 1; } });
(async () => {
  let passed = 0, failed = 0;
  for (const { name, run } of tests) {
    try { await run(); passed++; }
    catch (error) { failed++; console.error('FAIL', name, error.message); }
  }
  if (errors.length) { failed++; console.error('FAIL hidden store/normalizer errors', errors); }
  if (mutant) assert.ok(mutationApplied, 'Requested mutation must engage');
  for (const [file, hash] of sources) {
    assert.equal(createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex'), hash,
      `Source changed during review run: ${file}`);
  }
  finished = true;
  console.log(JSON.stringify({ passed, failed, mutant: mutant || null, sources: Object.fromEntries(sources) }));
  process.exitCode = failed ? 1 : 0;
})().catch(error => { finished = true; console.error(error); process.exitCode = 1; });
