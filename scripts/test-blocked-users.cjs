// H8 contract: blocked users.
// TDLib: MessageSenders (td_api.tl:2528), getBlockedMessageSenders (:13188),
// setMessageSenderBlockList (:13175, null block_list unblocks).
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;
const read = (relative) => fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(main);

const hilog = { info() {}, debug() {}, warn() {}, error() {} };
const { TdObject } = load('models/td/common/index.ets');
const C = load('core/model/AppCommand.ets');
const errors = load('core/model/AppError.ets');
const D = load('core/model/dto/BlockedSenderDto.ets', { TdObjectType: TdObject });
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });
const tdAccessors = load('core/utils/tdAccessors.ets', { TdObject });
const chatDto = load('core/model/dto/ChatDto.ets',
  { ...tdAccessors, TdObject, ChatId: undefined, GroupSendPermissionsDto: undefined,
    CustomEmojiTextEntity: undefined });

// DTO: user / chat senders, malformed entries, page envelope --------------------------------------
{
  const user = D.createBlockedSenderFromTd(TdObject.fromJSON(
    '{"@type":"messageSenderUser","user_id":100200300}'));
  assert.equal(user.senderType, 'user');
  assert.equal(user.senderId, 100200300);

  const chat = D.createBlockedSenderFromTd(TdObject.fromJSON(
    '{"@type":"messageSenderChat","chat_id":-1001234567890}'));
  assert.equal(chat.senderType, 'chat');
  assert.equal(chat.senderId, -1001234567890);

  assert.equal(D.createBlockedSenderFromTd(TdObject.fromJSON('{"@type":"messageSenderUser"}')), undefined);
  assert.equal(D.createBlockedSenderFromTd(TdObject.fromJSON(
    '{"@type":"messageSenderUser","user_id":0}')), undefined);
  assert.equal(D.createBlockedSenderFromTd(TdObject.fromJSON(
    '{"@type":"messageSenderUser","user_id":1.5}')), undefined);
  assert.equal(D.createBlockedSenderFromTd(TdObject.fromJSON('{"@type":"messageSenders"}')), undefined);

  const pageText = '{"@type":"messageSenders","total_count":3,"senders":[' +
    '{"@type":"messageSenderUser","user_id":11},' +
    '{"@type":"messageSenderChat","chat_id":-1009}]}';
  const page = D.createBlockedSendersPageFromTd(TdObject.fromJSON(pageText));
  assert.equal(page.totalCount, 3);
  assert.deepEqual(page.senders.map((item) => item.senderType + ':' + item.senderId), ['user:11', 'chat:-1009']);

  const partial = D.createBlockedSendersPageFromTd(TdObject.fromJSON(
    '{"@type":"messageSenders","total_count":1,"senders":[{"@type":"messageSenderUser","user_id":5},null,' +
    '{"@type":"other"}]}'));
  assert.deepEqual(partial.senders.map((item) => item.senderId), [5], 'malformed entries are skipped');

  assert.deepEqual(D.createBlockedSendersPageFromTd(TdObject.fromJSON('{"@type":"ok"}')).senders, []);
}

// chat.block_list: only blockListMain means "we blocked this peer" ---------------------------------
{
  const parsed = chatDto.createChatDtoFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'chat',
    id: 7,
    type: { '@type': 'chatTypePrivate', user_id: 11 },
    title: 'Peer',
    block_list: { '@type': 'blockListMain' }
  })));
  assert.equal(parsed.isBlocked, true, 'blockListMain marks the peer as blocked');

  const storiesOnly = chatDto.createChatDtoFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'chat',
    id: 8,
    type: { '@type': 'chatTypePrivate', user_id: 12 },
    title: 'Peer 2',
    block_list: { '@type': 'blockListStories' }
  })));
  assert.equal(storiesOnly.isBlocked, false, 'a stories-only block is not a message block');

  const unblocked = chatDto.createChatDtoFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'chat',
    id: 9,
    type: { '@type': 'chatTypePrivate', user_id: 13 },
    title: 'Peer 3'
  })));
  assert.equal(unblocked.isBlocked, false);
}

// Commands and wire shapes -----------------------------------------------------------------------
{
  const get = C.createGetBlockedMessageSendersCommand('main', 0, 100);
  assert.equal(get.type, 'getBlockedMessageSenders');
  const getWire = JSON.parse(serializer.buildTdlibRequestJson('getBlockedMessageSenders',
    serializer.serializeCommand(get).params));
  assert.deepEqual(getWire.block_list, { '@type': 'blockListMain' });
  assert.equal(getWire.offset, 0);
  assert.equal(getWire.limit, 100);

  const stories = JSON.parse(serializer.buildTdlibRequestJson('getBlockedMessageSenders',
    serializer.serializeCommand(C.createGetBlockedMessageSendersCommand('stories', 20, 10)).params));
  assert.deepEqual(stories.block_list, { '@type': 'blockListStories' });
  assert.equal(stories.offset, 20);

  const blockUser = JSON.parse(serializer.buildTdlibRequestJson('setMessageSenderBlockList',
    serializer.serializeCommand(C.createSetMessageSenderBlockListCommand('user', 42, true)).params));
  assert.deepEqual(blockUser.sender_id, { '@type': 'messageSenderUser', 'user_id': 42 });
  assert.deepEqual(blockUser.block_list, { '@type': 'blockListMain' }, 'blocking uses blockListMain');

  const unblockChat = JSON.parse(serializer.buildTdlibRequestJson('setMessageSenderBlockList',
    serializer.serializeCommand(C.createSetMessageSenderBlockListCommand('chat', -1009, false)).params));
  assert.deepEqual(unblockChat.sender_id, { '@type': 'messageSenderChat', 'chat_id': -1009 });
  assert.equal(unblockChat.block_list, null, 'unblocking sends a null block list');
}

// Use case: paging validation, unblock command, failures -----------------------------------------
async function checkUseCase() {
  const sent = [];
  let response = TdObject.fromJSON('{"@type":"messageSenders","total_count":1,"senders":[' +
    '{"@type":"messageSenderUser","user_id":11}]}');
  const gateway = {
    send: (command) => {
      sent.push(command);
      return Promise.resolve(response);
    }
  };
  const useCase = new (load('domain/usecases/loadBlockedSenders.ets',
    { ...C, ...errors, TdObject, hilog, BlockedSenderDto: D.BlockedSenderDto,
      createBlockedSendersPageFromTd: D.createBlockedSendersPageFromTd }).LoadBlockedSendersUseCase)(gateway);

  const page = await useCase.fetchPage();
  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, 'getBlockedMessageSenders');
  assert.equal(sent[0].payload.blockList, 'main');
  assert.equal(sent[0].payload.limit, 100);
  assert.deepEqual(page.senders.map((item) => item.senderId), [11]);

  await useCase.fetchPage(2, 10);
  assert.equal(sent.at(-1).payload.offset, 2, 'the offset reaches getBlockedMessageSenders');
  assert.equal(sent.at(-1).payload.limit, 10);
  assert.equal(sent.at(-1).payload.blockList, 'main', 'the default tab reads the main block list');

  await useCase.fetchPage(0, 100, 'stories');
  assert.equal(sent.at(-1).payload.blockList, 'stories', 'the stories tab selects blockListStories');

  await useCase.unblock(page.senders[0]);
  assert.equal(sent.length, 4);
  assert.equal(sent[3].type, 'setMessageSenderBlockList');
  assert.equal(sent[3].payload.senderType, 'user');
  assert.equal(sent[3].payload.senderId, 11);
  assert.equal(sent[3].payload.blocked, false, 'the page only unblocks');

  for (const offset of [-1, 1.5]) {
    await assert.rejects(() => useCase.fetchPage(offset), /Invalid paging/);
  }
  await assert.rejects(() => useCase.fetchPage(0, 0), /Invalid paging/);
  await assert.rejects(() => useCase.fetchPage(0, 101), /Invalid paging/);
  assert.equal(sent.length, 4, 'invalid paging never reaches the gateway');

  await assert.rejects(() => useCase.unblock(Object.assign(new D.BlockedSenderDto(),
    { senderType: 'user', senderId: 0 })), /Invalid sender/);
  assert.equal(sent.length, 4);

  const blockedUseCase = new (load('domain/usecases/setMessageSenderBlocked.ets',
    { ...C, ...errors, hilog }).SetMessageSenderBlockedUseCase)(gateway);
  const before = sent.length;
  await blockedUseCase.block('user', 42);
  assert.equal(sent.length, before + 1);
  assert.equal(sent.at(-1).type, 'setMessageSenderBlockList');
  assert.equal(sent.at(-1).payload.blocked, true, 'block sends blockListMain');
  assert.equal(sent.at(-1).payload.senderId, 42);

  await blockedUseCase.unblock('chat', -1009);
  assert.equal(sent.at(-1).payload.blocked, false, 'unblock sends the null block list');
  assert.equal(sent.at(-1).payload.senderType, 'chat');
  assert.equal(sent.at(-1).payload.senderId, -1009);

  for (const badId of [0, 1.5]) {
    await assert.rejects(() => blockedUseCase.block('user', badId), /Invalid sender/);
  }
  await assert.rejects(() => blockedUseCase.block('sticker', 1), /Invalid sender/);
  assert.equal(sent.at(-1).type, 'setMessageSenderBlockList', 'invalid input never reaches the gateway');

  response = TdObject.fromJSON('{"@type":"ok"}');
  assert.deepEqual((await useCase.fetchPage()).senders, [], 'an unexpected payload is empty, not a crash');
}

// Paging: append with dedupe, "show more" driven by loaded-versus-total ----------------------------
{
  const S = load('domain/selectors/blockedSenderSelectors.ets');
  const make = (type, id) => Object.assign(new D.BlockedSenderDto(), { senderType: type, senderId: id });
  assert.equal(S.blockedSenderKey(make('user', 5)), 'user:5');
  assert.equal(S.blockedSenderKey(make('chat', -9)), 'chat:-9');

  const merged = S.mergeBlockedSenders(
    [make('user', 1), make('user', 2)],
    [make('user', 2), make('chat', -3), make('user', 1), make('user', 4)]);
  assert.deepEqual(merged.map((item) => S.blockedSenderKey(item)),
    ['user:1', 'user:2', 'chat:-3', 'user:4'], 'duplicates are dropped and order is stable');

  assert.deepEqual(S.mergeBlockedSenders([], [make('user', 1)]).map((item) => item.senderId), [1]);
  assert.deepEqual(S.mergeBlockedSenders([make('user', 1)], []).map((item) => item.senderId), [1]);

  assert.equal(S.hasMoreBlockedSenders(0, 0), false, 'an empty list has nothing more');
  assert.equal(S.hasMoreBlockedSenders(0, 3), true);
  assert.equal(S.hasMoreBlockedSenders(3, 3), false);
  assert.equal(S.hasMoreBlockedSenders(3, 2), false, 'a shrunken total never asks for more');
}

// Page, route, settings entry and localizable strings ---------------------------------------------
{
  const page = read('ui/pages/settings/TgBlockedUsersPage.ets');
  assert.match(page, /export function TgBlockedUsersPageBuilder\(\)/);
  assert.match(page, /createLoadBlockedSendersUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(page, /useCase\.fetchPage\(0, 100, this\.blockList\)/);
  assert.match(page, /useCase\.unblock\(sender\)/);
  assert.match(page, /state\.users\.users\.get\(sender\.senderId\)/);
  assert.match(page, /state\.chats\.chats\.get\(sender\.senderId\)/);
  assert.match(page, /promptAction\.showDialog\(/);
  assert.match(page, /ForEach\(this\.senders, \(sender: BlockedSenderDto\)/);
  assert.match(page, /mergeBlockedSenders\(this\.senders, page\.senders\)/);
  assert.match(page, /hasMoreBlockedSenders\(this\.senders\.length, this\.totalCount\)/);
  assert.match(page, /@Local private blockList: BlockListKind = 'main';/);
  assert.match(page, /private selectBlockList\(blockList: BlockListKind\): void \{/);
  assert.match(page, /this\.blockList = blockList;/);
  assert.match(page, /useCase\.fetchPage\(0, 100, this\.blockList\)/);
  assert.match(page, /useCase\.fetchPage\(this\.senders\.length, 100, this\.blockList\)/,
    'show more must stay on the selected block list');
  assert.match(page, /blocked_tab_messages/);
  assert.match(page, /blocked_tab_stories/);
  assert.match(page, /useCase\.fetchPage\(this\.senders\.length, 100, this\.blockList\)/,
    'show more requests the next offset, not the first page again');

  const routeMap = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources/base/profile/route_map.json'), 'utf8'));
  const route = routeMap.routerMap.find((item) => item.name === 'TgBlockedUsersPage');
  assert.ok(route, 'TgBlockedUsersPage is registered');
  assert.equal(route.buildFunction, 'TgBlockedUsersPageBuilder');

  const settings = read('ui/pages/settings/SettingsPage.ets');
  assert.match(settings, /@Event onOpenBlockedUsers: \(\) => void/);
  assert.match(settings, /this\.onOpenBlockedUsers\(\);/);
  const profile = read('ui/pages/profile/TgProfilePage.ets');
  assert.match(profile, /createSetMessageSenderBlockedUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(profile, /@Local private isBlocked: boolean = false;/);
  assert.match(profile, /this\.isBlocked = chat\.isBlocked;/);
  assert.match(profile, /private canBlockPeer\(\): boolean \{/);
  assert.match(profile, /this\.chatType === 'private' \|\| this\.chatType === 'secret'/);
  assert.match(profile, /useCase\.block\('user', userId\)/, 'blocking must target the peer user');
  assert.match(profile, /useCase\.unblock\('user', userId\)/);
  assert.match(profile, /profile_block_user/);
  assert.match(profile, /profile_unblock_user/);

  const tabs = read('ui/pages/MainTabsPage.ets');
  assert.match(tabs, /onOpenBlockedUsers: \(\): void => \{\n              this\.chatDetailNavStack\.pushPathByName\('TgBlockedUsersPage', undefined\);/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['settings_blocked_users', 'blocked_loading', 'blocked_load_failed', 'blocked_retry',
      'blocked_empty', 'blocked_unblock', 'blocked_user_fallback', 'blocked_chat_fallback',
      'blocked_show_more', 'blocked_tab_messages', 'blocked_tab_stories',
      'profile_block_user', 'profile_unblock_user',
      'profile_blocked_toast', 'profile_unblocked_toast']) {
      const item = strings.string.find((entry) => entry.name === name);
      assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
    }
  }
}

checkUseCase()
  .then(() => {
    console.log('PASS blocked users contract');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
