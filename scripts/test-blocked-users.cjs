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

function load(relative, deps = {}) {
  const text = read(relative);
  const names = [...text.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map((match) => match[1]);
  const code = text.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '')
    .replace(/^@ObservedV2\s*\n/gm, '').replace(/^(\s*)@Trace\s+/gm, '$1');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) + `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

const hilog = { info() {}, debug() {}, warn() {}, error() {} };
const { TdObject } = load('models/td/common/index.ets');
const C = load('core/model/AppCommand.ets');
const errors = load('core/model/AppError.ets');
const D = load('core/model/dto/BlockedSenderDto.ets', { TdObjectType: TdObject });
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });

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

  await useCase.unblock(page.senders[0]);
  assert.equal(sent.length, 2);
  assert.equal(sent[1].type, 'setMessageSenderBlockList');
  assert.equal(sent[1].payload.senderType, 'user');
  assert.equal(sent[1].payload.senderId, 11);
  assert.equal(sent[1].payload.blocked, false, 'the page only unblocks');

  for (const offset of [-1, 1.5]) {
    await assert.rejects(() => useCase.fetchPage(offset), /Invalid paging/);
  }
  await assert.rejects(() => useCase.fetchPage(0, 0), /Invalid paging/);
  await assert.rejects(() => useCase.fetchPage(0, 101), /Invalid paging/);
  assert.equal(sent.length, 2, 'invalid paging never reaches the gateway');

  await assert.rejects(() => useCase.unblock(Object.assign(new D.BlockedSenderDto(),
    { senderType: 'user', senderId: 0 })), /Invalid sender/);
  assert.equal(sent.length, 2);

  response = TdObject.fromJSON('{"@type":"ok"}');
  assert.deepEqual((await useCase.fetchPage()).senders, [], 'an unexpected payload is empty, not a crash');
}

// Page, route, settings entry and localizable strings ---------------------------------------------
{
  const page = read('ui/pages/settings/TgBlockedUsersPage.ets');
  assert.match(page, /export function TgBlockedUsersPageBuilder\(\)/);
  assert.match(page, /createLoadBlockedSendersUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(page, /useCase\.fetchPage\(\)/);
  assert.match(page, /useCase\.unblock\(sender\)/);
  assert.match(page, /state\.users\.users\.get\(sender\.senderId\)/);
  assert.match(page, /state\.chats\.chats\.get\(sender\.senderId\)/);
  assert.match(page, /promptAction\.showDialog\(/);
  assert.match(page, /ForEach\(this\.senders, \(sender: BlockedSenderDto\)/);

  const routeMap = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources/base/profile/route_map.json'), 'utf8'));
  const route = routeMap.routerMap.find((item) => item.name === 'TgBlockedUsersPage');
  assert.ok(route, 'TgBlockedUsersPage is registered');
  assert.equal(route.buildFunction, 'TgBlockedUsersPageBuilder');

  const settings = read('ui/pages/settings/SettingsPage.ets');
  assert.match(settings, /@Event onOpenBlockedUsers: \(\) => void/);
  assert.match(settings, /this\.onOpenBlockedUsers\(\);/);
  const tabs = read('ui/pages/MainTabsPage.ets');
  assert.match(tabs, /onOpenBlockedUsers: \(\): void => \{\n              this\.chatDetailNavStack\.pushPathByName\('TgBlockedUsersPage', undefined\);/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['settings_blocked_users', 'blocked_loading', 'blocked_load_failed', 'blocked_retry',
      'blocked_empty', 'blocked_unblock', 'blocked_user_fallback', 'blocked_chat_fallback']) {
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
