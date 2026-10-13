// Node >=24. Real use case, TdObject, command factories and serializer.
// Only the native gateway and hilog are synthetic; no account/network actions.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(relative, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  const names = [...source.matchAll(/^export\s+(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const td = load('models/td/common/index.ets');
const commands = load('core/model/AppCommand.ets');
const errors = load('core/model/AppError.ets');
const hilog = { info() {}, debug() {}, warn() {}, error() {} };
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...td, ...commands, hilog });
const { createToggleChatUnreadUseCase } = load('domain/usecases/toggleChatUnread.ets', { ...td, ...commands, ...errors, hilog });
const response = obj => td.TdObject.fromJSON(JSON.stringify(obj));
const ok = () => response({ '@type': 'ok' });
function chat(id, last = { '@type': 'message', chat_id: id, id: 4503599627370495 }) {
  return response({ '@type': 'chat', id, unread_count: 0, last_message: last });
}
function fixture(replies) {
  const sent = [];
  const gateway = { async send(command) {
    sent.push(command);
    const reply = replies[sent.length - 1];
    if (reply instanceof Error) throw reply;
    return typeof reply === 'function' ? reply() : reply;
  } };
  return { usecase: createToggleChatUnreadUseCase(gateway), sent };
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
for (const chatId of [19, -7001, -1000000008100]) {
  test(`read ${chatId}: last message force-read before clearing manual unread`, async () => {
    const f = fixture([chat(chatId), ok(), ok()]);
    await f.usecase.markAsRead(chatId);
    assert.deepEqual(f.sent.map(c => c.type), ['getChat', 'viewMessages', 'toggleChatIsMarkedAsUnread']);
    assert.ok(f.sent.every(c => c.payload.chatId === chatId));
    const wire = serializer.serializeCommand(f.sent[1]);
    assert.equal(wire.method, 'viewMessages');
    assert.equal(wire.params.getString('_message_ids_json'), '[4503599627370495]');
    assert.equal(wire.params.getBool('force_read'), true);
    assert.equal(serializer.serializeCommand(f.sent[2]).params.getBool('is_marked_as_unread'), false);
  });
}
test('empty chat clears manual unread without a fake message ID', async () => {
  const f = fixture([chat(-7001, null), ok()]);
  await f.usecase.markAsRead(-7001);
  assert.deepEqual(f.sent.map(c => c.type), ['getChat', 'toggleChatIsMarkedAsUnread']);
});
test('mark unread does not read messages', async () => {
  const f = fixture([ok()]);
  await f.usecase.markAsUnread(-7001);
  assert.deepEqual(f.sent.map(c => c.type), ['toggleChatIsMarkedAsUnread']);
  assert.equal(serializer.serializeCommand(f.sent[0]).params.getBool('is_marked_as_unread'), true);
});
for (const id of [0, NaN, Infinity, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
  test(`invalid chat ID ${id} cannot send either action`, async () => {
    const f = fixture([ok()]);
    await assert.rejects(() => f.usecase.markAsRead(id));
    await assert.rejects(() => f.usecase.markAsUnread(id));
    assert.equal(f.sent.length, 0);
  });
}
for (const [name, reply] of [
  ['wrong chat', chat(-7002)],
  ['nested chat identity', response({ '@type': 'chat', nested: { id: -7001 }, last_message: null })],
  ['wrong response type', response({ '@type': 'user', id: -7001 })],
  ['plain record', { '@type': 'chat', id: -7001 }],
  ['error response', response({ '@type': 'error', code: 403, message: 'synthetic' })],
  ['transport rejection', new Error('synthetic failure')],
  ['malformed last message', chat(-7001, 'invalid')],
  ['unknown last message with unread inbox', response({ '@type': 'chat', id: -7001, unread_count: 4, last_message: null })],
  ['missing inbox knowledge', response({ '@type': 'chat', id: -7001, last_message: null })],
  ['pending last message', chat(-7001, { '@type': 'message', chat_id: -7001, id: 1048577, sending_state: { '@type': 'messageSendingStatePending' } })],
  ['failed last message', chat(-7001, { '@type': 'message', chat_id: -7001, id: 1048577, sending_state: { '@type': 'messageSendingStateFailed' } })],
  ['scheduled last message', chat(-7001, { '@type': 'message', chat_id: -7001, id: 1048576, scheduling_state: { '@type': 'messageSchedulingStateSendAtDate', send_date: 2000000000 } })],
  ['foreign last message', chat(-7001, { '@type': 'message', chat_id: -7002, id: 100 })],
  ['missing message ID', chat(-7001, { '@type': 'message', chat_id: -7001 })],
  ['zero message ID', chat(-7001, { '@type': 'message', chat_id: -7001, id: 0 })],
  ['fractional message ID', chat(-7001, { '@type': 'message', chat_id: -7001, id: 1.5 })],
  ['unsafe message ID', chat(-7001, { '@type': 'message', chat_id: -7001, id: 1e20 })]
]) {
  test(`${name}: failed lookup cannot clear unread`, async () => {
    const f = fixture([reply, ok(), ok()]);
    await assert.rejects(() => f.usecase.markAsRead(-7001));
    assert.deepEqual(f.sent.map(c => c.type), ['getChat']);
  });
}
for (const [name, reply] of [
  ['transport failure', new Error('synthetic')],
  ['TDLib error', response({ '@type': 'error', code: 400, message: 'synthetic' })],
  ['nested fake Ok', response({ nested: { '@type': 'ok' } })]
]) {
  test(`view ${name}: do not clear manual unread or report success`, async () => {
    const f = fixture([chat(-7001), reply, ok()]);
    await assert.rejects(() => f.usecase.markAsRead(-7001));
    assert.deepEqual(f.sent.map(c => c.type), ['getChat', 'viewMessages']);
  });
}
test('manual unread failure remains visible after successful receipt', async () => {
  const f = fixture([chat(-7001), ok(), response({ '@type': 'error', code: 400, message: 'synthetic' })]);
  await assert.rejects(() => f.usecase.markAsRead(-7001));
  assert.equal(f.sent.length, 3);
});
test('no early manual clear while view acknowledgement is pending', async () => {
  let resolve;
  const pending = new Promise(r => { resolve = r; });
  const f = fixture([chat(-7001), () => pending, ok()]);
  const result = f.usecase.markAsRead(-7001);
  await new Promise(r => setImmediate(r));
  assert.deepEqual(f.sent.map(c => c.type), ['getChat', 'viewMessages']);
  resolve(ok());
  await result;
  assert.equal(f.sent.length, 3);
});
async function main() {
  let passed = 0;
  for (const { name, run } of tests) {
    try { await run(); passed++; console.log('PASS', name); }
    catch (error) { console.log('FAIL', name, error.message); }
  }
  console.log(JSON.stringify({ passed, failed: tests.length - passed }));
  process.exitCode = passed === tests.length ? 0 : 1;
}
main().catch(error => { console.error(error); process.exitCode = 2; });
