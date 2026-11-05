// B7 contract: folder invite-link preview and join (checkChatFolderInviteLink /
// addChatFolderByInviteLink), plus the in-app entry point on the folder screen.
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
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });
const I = load('core/model/dto/ChatFolderInviteLinkInfoDto.ets', { TdObjectType: TdObject, TdObject });
const usecaseModule = load('domain/usecases/folderInviteLink.ets',
  { ...C, ...errors, hilog, TdObject, ChatFolderInviteLinkInfoDto: I.ChatFolderInviteLinkInfoDto,
    createChatFolderInviteLinkInfoFromTd: I.createChatFolderInviteLinkInfoFromTd });

const INFO_TEXT = '{"@type":"chatFolderInviteLinkInfo","chat_folder_info":' +
  '{"@type":"chatFolderInfo","id":7,"name":{"@type":"chatFolderName","text":{"@type":"formattedText",' +
  '"text":"Work","entities":[]},"animate_custom_emoji":false},' +
  '"icon":{"@type":"chatFolderIcon","name":"Work"},"color_id":2,"is_shareable":true,' +
  '"has_my_invite_links":false},' +
  '"missing_chat_ids":[9007199254740001],"added_chat_ids":[]}';

async function mainCheck() {
  // Wire: both commands quote the link and add the chat set.
  const checkWire = JSON.parse(serializer.buildTdlibRequestJson('checkChatFolderInviteLink',
    serializer.serializeCommand(C.createCheckChatFolderInviteLinkCommand('https://t.me/addlist/a')).params));
  assert.equal(checkWire.invite_link, 'https://t.me/addlist/a');

  const addWire = JSON.parse(serializer.buildTdlibRequestJson('addChatFolderByInviteLink',
    serializer.serializeCommand(C.createAddChatFolderByInviteLinkCommand('https://t.me/addlist/a',
      [5, 9007199254740001])).params));
  assert.equal(addWire.invite_link, 'https://t.me/addlist/a');
  assert.deepEqual(addWire.chat_ids, [5, 9007199254740001]);
  const filteredAdd = JSON.parse(serializer.buildTdlibRequestJson('addChatFolderByInviteLink',
    serializer.serializeCommand(C.createAddChatFolderByInviteLinkCommand('https://t.me/addlist/a',
      [3, 0, -1])).params));
  assert.deepEqual(filteredAdd.chat_ids, [3], 'invalid ids never reach the add request');

  // DTO: folder info + missing chats, int53 preserved.
  const info = I.createChatFolderInviteLinkInfoFromTd(TdObject.fromJSON(INFO_TEXT));
  assert.equal(info.folderId, 7);
  assert.equal(info.title, 'Work');
  assert.equal(info.iconName, 'Work');
  assert.equal(info.colorId, 2);
  assert.equal(info.isShareable, true);
  assert.equal(info.hasMyInviteLinks, false);
  assert.deepEqual(info.missingChatIds, [9007199254740001]);
  assert.deepEqual(info.addedChatIds, []);
  assert.equal(I.createChatFolderInviteLinkInfoFromTd(TdObject.fromJSON('{"@type":"ok"}')), undefined);
  assert.equal(I.createChatFolderInviteLinkInfoFromTd(TdObject.fromJSON(
    '{"@type":"chatFolderInviteLinkInfo"}')), undefined);

  // Link shape accepted by the UI and the use case.
  for (const valid of ['https://t.me/addlist/abc', 't.me/addlist/abc', 'HTTP://t.me/addlist/abc',
    'https://telegram.me/addlist/abc', '  https://t.me/addlist/abc  ', 'https://t.me/addlist/abc/']) {
    assert.equal(usecaseModule.isFolderInviteLink(valid), true, 'accepted: ' + valid);
  }
  for (const invalid of ['', '   ', 'https://t.me/joinchat/x', 'https://t.me/addlist/', 'addlist/abc',
    'https://example.com/addlist/abc', 'https://t.me/addlist/' + 'x'.repeat(600)]) {
    assert.equal(usecaseModule.isFolderInviteLink(invalid), false, 'rejected: ' + invalid);
  }

  // Use case: check then add, with validation before the gateway.
  const sent = [];
  const gateway = {
    send: (command) => {
      sent.push(command);
      return Promise.resolve(TdObject.fromJSON(command.type === 'checkChatFolderInviteLink'
        ? INFO_TEXT : '{"@type":"ok"}'));
    }
  };
  const useCase = new usecaseModule.FolderInviteLinkUseCase(gateway);
  const checked = await useCase.check('  https://t.me/addlist/abc  ');
  assert.equal(sent.at(-1).type, 'checkChatFolderInviteLink');
  assert.equal(sent.at(-1).payload.inviteLink, 'https://t.me/addlist/abc', 'the link is trimmed');
  assert.deepEqual(checked.missingChatIds, [9007199254740001]);

  await useCase.add('https://t.me/addlist/abc', checked.missingChatIds);
  assert.equal(sent.at(-1).type, 'addChatFolderByInviteLink');
  assert.deepEqual(sent.at(-1).payload.chatIds, [9007199254740001]);

  await assert.rejects(() => useCase.check('https://t.me/joinchat/x'), /Invalid folder link/);
  await assert.rejects(() => useCase.add('nope', []), /Invalid folder link/);
  await assert.rejects(() => useCase.add('https://t.me/addlist/abc', [0]), /Invalid chat id/);
  assert.equal(sent.length, 2, 'invalid input never reaches the gateway');
  await assert.rejects(() => new usecaseModule.FolderInviteLinkUseCase(
    { send: () => Promise.reject(new Error('native status')) }).check('https://t.me/addlist/abc'),
    /Failed to check the folder link/);
  await assert.rejects(() => new usecaseModule.FolderInviteLinkUseCase(
    { send: () => Promise.reject(new Error('native status')) }).add('https://t.me/addlist/abc', []),
    /Failed to add the folder/);
}

mainCheck().then(() => {
  const page = read('ui/pages/settings/TgFolderLinkPage.ets');
  assert.match(page, /export function TgFolderLinkPageBuilder\(\)/);
  assert.match(page, /createFolderInviteLinkUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(page, /if \(!isFolderInviteLink\(this\.linkDraft\)\)/);
  assert.match(page, /useCase\.check\(this\.linkDraft\)/);
  assert.match(page, /useCase\.add\(this\.linkDraft, preview\.missingChatIds\)/);
  assert.match(page, /enabled\(!this\.isAdding\)/);
  assert.match(page, /folders_link_join/);
  assert.match(page, /folders_link_check/);

  const foldersPage = read('ui/pages/settings/TgChatFoldersPage.ets');
  assert.match(foldersPage, /this\.pageStack\.pushPathByName\('TgFolderLinkPage', undefined\)/);
  assert.match(foldersPage, /folders_link_open/);

  const routeMap = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources/base/profile/route_map.json'), 'utf8'));
  const route = routeMap.routerMap.find((item) => item.name === 'TgFolderLinkPage');
  assert.ok(route, 'TgFolderLinkPage is registered');
  assert.equal(route.buildFunction, 'TgFolderLinkPageBuilder');
  assert.equal(route.pageSourceFile, 'src/main/ets/ui/pages/settings/TgFolderLinkPage.ets');

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['folders_link_open', 'folders_link_title', 'folders_link_hint',
      'folders_link_check', 'folders_link_checking', 'folders_link_invalid', 'folders_link_check_failed',
      'folders_link_join', 'folders_link_added', 'folders_link_add_failed', 'folders_link_chats',
      'folders_link_missing']) {
      const item = strings.string.find((entry) => entry.name === name);
      assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
    }
  }
  console.log('PASS folder link preview contract');
}).catch((error) => {
  console.error(error);
  process.exit(1);
});
