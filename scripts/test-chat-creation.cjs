// Node >= 24. Execute real ETS use cases, commands, TdObject and DTO mapping.
// Only the TDLib gateway and platform log sink are inert; no network/device access.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(relative, names, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8')
    .replace(/^import\s[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '').replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const hilog = { info() {}, warn() {}, error() {}, debug() {} };
const { TdObject } = load('models/td/common/index.ets', ['TdObject']);
const accessors = load('core/utils/tdAccessors.ets',
  ['tdGetString', 'tdGetNumber', 'tdGetBoolean', 'tdGetInt64', 'tdGetObject', 'tdGetArray', 'tdHasKeys'], { TdObject });
const commands = load('core/model/AppCommand.ets', ['createGetChatCommand', 'createNewBasicGroupChatCommand',
  'createNewSupergroupChatCommand', 'CustomEmojiTextEntity']);
const permissions = load('core/model/dto/GroupAccessDto.ets', ['GroupSendPermissionsDto'], { TdObject });
const dto = load('core/model/dto/ChatDto.ets', ['ChatDto', 'ChatType', 'createChatDtoFromTd'],
  { TdObject, hilog, ...accessors, ...permissions, ...commands });
const basic = load('domain/usecases/createBasicGroupChat.ets',
  ['CreateBasicGroupChatUseCase', 'CreateBasicGroupChatResult', 'BasicGroupFailedMember',
    'parseCreatedBasicGroupChatResponse'], { TdObject, ...commands, ...dto });
const channel = load('domain/usecases/createChannelChat.ets',
  ['CreateChannelChatUseCase', 'parseCreatedChannelChat'], { TdObject, ...commands, ...dto });
const td = value => TdObject.fromJSON(JSON.stringify(value));
const created = chatId => td({ '@type': 'createdBasicGroupChat', chat_id: chatId,
  failed_to_add_members: { '@type': 'failedToAddMembers', failed_to_add_members: [
    { '@type': 'failedToAddMember', user_id: 42, premium_would_allow_invite: true,
      premium_required_to_send_messages: false },
    { '@type': 'failedToAddMember', user_id: 43, premium_would_allow_invite: false,
      premium_required_to_send_messages: true }
  ] } });
const groupChat = id => td({ '@type': 'chat', id, title: 'Server group',
  type: { '@type': 'chatTypeBasicGroup', basic_group_id: 7001 } });
const channelChat = (id, overrides = {}) => td({ '@type': 'chat', id, title: 'Server channel',
  type: { '@type': 'chatTypeSupergroup', supergroup_id: 8100, is_channel: true }, ...overrides });
function gateway(...responses) {
  const sent = [];
  return { sent, send: async command => {
    sent.push(command);
    assert.ok(sent.length <= responses.length, 'unexpected duplicate gateway send');
    const response = responses[sent.length - 1];
    if (response instanceof Error) throw response;
    return response;
  } };
}
function checkFailedMembers(result) {
  assert.equal(result.failedMembers.length, 2);
  assert.ok(result.failedMembers.every(member => member instanceof basic.BasicGroupFailedMember));
  assert.deepEqual(result.failedMembers.map(member => [member.userId,
    member.premiumWouldAllowInvite, member.premiumRequiredToSendMessages]),
  [[42, true, false], [43, false, true]]);
}
const tests = [];
const test = (name, run) => tests.push([name, run]);
for (const id of [-7001, -1000000008100, -4503599627370495, 7001]) {
  test(`group preserves exact signed ID ${id}, hydrates once and keeps partial failures`, async () => {
    const g = gateway(created(id), groupChat(id));
    const result = await new basic.CreateBasicGroupChatUseCase(g).execute([42, 42, 43], ' Group ');
    assert.ok(result instanceof basic.CreateBasicGroupChatResult);
    assert.ok(result.chat instanceof dto.ChatDto);
    assert.equal(result.chat.id, id);
    assert.equal(result.chat.type, dto.ChatType.GROUP);
    assert.equal(result.chat.title, 'Server group');
    assert.equal(result.isHydrated, true);
    checkFailedMembers(result);
    assert.deepEqual(g.sent.map(command => command.type), ['createNewBasicGroupChat', 'getChat']);
    assert.deepEqual({ ...g.sent[0].payload }, { userIds: [42, 43], title: 'Group', messageAutoDeleteTime: 0 });
    assert.equal(g.sent[1].payload.chatId, id);
  });
}
for (const [name, response] of [
  ['throw', new Error('synthetic hydration failure')], ['missing', undefined],
  ['wrong envelope', td({ '@type': 'ok' })], ['wrong identity', groupChat(-9999)],
  ['wrong kind', channelChat(-7001)]
]) {
  test(`committed group: hydration ${name} returns identity, never resends create`, async () => {
    const g = gateway(created(-7001), response);
    const result = await new basic.CreateBasicGroupChatUseCase(g).execute([42, 43], ' Group ');
    assert.ok(result instanceof basic.CreateBasicGroupChatResult);
    assert.equal(result.chat.id, -7001);
    assert.equal(result.chat.title, 'Group');
    assert.equal(result.chat.type, dto.ChatType.GROUP);
    assert.equal(result.isHydrated, false);
    checkFailedMembers(result);
    assert.deepEqual(g.sent.map(command => command.type), ['createNewBasicGroupChat', 'getChat']);
  });
}
for (const id of [-1000000008100, -4503599627370495, 8100]) {
  test(`channel preserves exact signed ID ${id} and sends create only once`, async () => {
    const g = gateway(channelChat(id));
    const result = await new channel.CreateChannelChatUseCase(g).execute(' Channel ', ' Description ');
    assert.ok(result instanceof dto.ChatDto);
    assert.equal(result.id, id);
    assert.equal(result.type, dto.ChatType.CHANNEL);
    assert.equal(result.supergroupId, 8100);
    assert.equal(result.title, 'Server channel');
    assert.deepEqual(g.sent.map(command => command.type), ['createNewSupergroupChat']);
    assert.deepEqual({ ...g.sent[0].payload }, { title: 'Channel', isForum: false, isChannel: true,
      description: 'Description', messageAutoDeleteTime: 0, forImport: false });
  });
}
const invalidIds = [
  ['zero', 0], ['missing', undefined], ['null', null], ['boolean', true],
  ['fraction', 12.5], ['negative fraction', -12.5], ['unsafe integer', 9007199254740992],
  ['unsafe negative integer', -9007199254740992], ['numeric string', '123'], ['junk suffix', '123junk']
];
for (const [name, value] of invalidIds) {
  test(`group rejects ${name} ID without hydration/retry`, async () => {
    const response = created(value), g = gateway(response);
    assert.equal(basic.parseCreatedBasicGroupChatResponse(response), undefined);
    await assert.rejects(new basic.CreateBasicGroupChatUseCase(g).execute([], 'Group'),
      { name: 'Error', message: 'Group creation failed' });
    assert.equal(g.sent.length, 1);
  });
  test(`channel rejects ${name} ID without retry`, async () => {
    const response = channelChat(value), g = gateway(response);
    assert.equal(channel.parseCreatedChannelChat(response), undefined);
    await assert.rejects(new channel.CreateChannelChatUseCase(g).execute('Channel'),
      { name: 'Error', message: 'Channel creation failed' });
    assert.equal(g.sent.length, 1);
  });
}
for (const [name, response] of [
  ['missing', undefined], ['plain object', { '@type': 'createdBasicGroupChat', chat_id: -7001 }],
  ['wrong type', td({ '@type': 'ok', chat_id: -7001 })],
  ['nested identity', td({ '@type': 'createdBasicGroupChat', nested: { chat_id: 7001 } })],
  ['nested type', td({ nested: { '@type': 'createdBasicGroupChat' }, chat_id: 7001 })],
  ['infinite number', TdObject.fromJSON('{"@type":"createdBasicGroupChat","chat_id":1e400}')]
]) {
  test(`group rejects ${name} response with stable exception`, async () => {
    const g = gateway(response);
    await assert.rejects(new basic.CreateBasicGroupChatUseCase(g).execute([], 'Group'),
      { name: 'Error', message: 'Group creation failed' });
    assert.equal(g.sent.length, 1);
  });
}
for (const [name, response] of [
  ['missing', undefined], ['plain object', { '@type': 'chat', id: -1000000008100 }],
  ['wrong type', td({ '@type': 'ok', id: 8100 })],
  ['non-channel', channelChat(8100, { type: { '@type': 'chatTypeSupergroup', supergroup_id: 8100, is_channel: false } })],
  ['zero supergroup', channelChat(8100, { type: { '@type': 'chatTypeSupergroup', supergroup_id: 0, is_channel: true } })],
  ['invalid supergroup', channelChat(8100, { type: { '@type': 'chatTypeSupergroup', supergroup_id: 8100.5, is_channel: true } })],
  ['string channel flag', channelChat(8100, { type: { '@type': 'chatTypeSupergroup', supergroup_id: 8100, is_channel: 'true' } })],
  ['nested identity', channelChat(undefined, { nested: { id: 8100 } })],
  ['infinite number', TdObject.fromJSON('{"@type":"chat","id":1e400,"type":{"@type":"chatTypeSupergroup","supergroup_id":8100,"is_channel":true}}')]
]) {
  test(`channel rejects ${name} response with stable exception`, async () => {
    const g = gateway(response);
    await assert.rejects(new channel.CreateChannelChatUseCase(g).execute('Channel'),
      { name: 'Error', message: 'Channel creation failed' });
    assert.equal(g.sent.length, 1);
  });
}
for (const [name, UseCase, args] of [
  ['group', basic.CreateBasicGroupChatUseCase, [[], 'Group']],
  ['channel', channel.CreateChannelChatUseCase, ['Channel']]
]) {
  test(`${name} create rejection propagates original error without retry`, async () => {
    const error = new Error('synthetic create rejection'), g = gateway(error);
    await assert.rejects(new UseCase(g).execute(...args), caught => caught === error);
    assert.equal(g.sent.length, 1);
  });
}
test('invalid input fails before any group/channel send', async () => {
  const g = gateway();
  await assert.rejects(new basic.CreateBasicGroupChatUseCase(g).execute([], ' '), /title/);
  await assert.rejects(new basic.CreateBasicGroupChatUseCase(g).execute(Array.from({ length: 201 }, (_, i) => i + 1), 'Group'), /too many members/);
  await assert.rejects(new channel.CreateChannelChatUseCase(g).execute(' '), /title/);
  await assert.rejects(new channel.CreateChannelChatUseCase(g).execute('Channel', 'x'.repeat(256)), /description/);
  assert.equal(g.sent.length, 0);
});
async function main() {
  let passed = 0;
  for (const [name, run] of tests) {
    try { await run(); passed++; console.log(`PASS ${name}`); }
    catch (error) { console.error(`FAIL ${name}\n${error.stack}`); }
  }
  console.log(`${passed}/${tests.length} PASS; ${tests.length - passed} FAIL (production chat creation, host fixtures only)`);
  if (passed !== tests.length) process.exitCode = 1;
}
let finished = false;
process.on('beforeExit', () => {
  if (!finished) { console.error('FAIL incomplete test run'); process.exitCode = 1; }
});
main().then(() => { finished = true; }).catch(error => {
  finished = true; console.error(error); process.exitCode = 1;
});
