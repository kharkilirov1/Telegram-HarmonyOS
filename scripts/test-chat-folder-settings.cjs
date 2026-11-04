// B7/S7b.4 contract: Settings → Chat Folders (create / edit / delete).
// TDLib: chatFolder (td_api.tl:3106), createChatFolder (:12054), editChatFolder (:12057),
// deleteChatFolder (:12060). The folder list itself is pushed by updateChatFolders.
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
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });
const D = load('core/model/dto/ChatFolderDto.ets', { TdObjectType: TdObject });
const LINKS_TEXT = '{"@type":"chatFolderInviteLinks","invite_links":[' +
  '{"@type":"chatFolderInviteLink","invite_link":"https://t.me/addlist/a","name":"First",' +
  '"chat_ids":[5,9007199254740001]},' +
  '{"@type":"chatFolderInviteLink","invite_link":"https://t.me/addlist/b","name":"",' +
  '"chat_ids":[]}]}';
const L = load('core/model/dto/ChatFolderInviteLinkDto.ets', { TdObjectType: TdObject });

function draft(overrides = {}) {
  return Object.assign(new C.ChatFolderDraftPayload(), overrides);
}

// Wire shapes: the whole chatFolder object, name escaping, flags and delete -----------------------
{
  const create = JSON.parse(serializer.buildTdlibRequestJson('createChatFolder',
    serializer.serializeCommand(C.createChatFolderCommand(draft({ title: 'Work', excludeMuted: true }))).params));
  assert.equal(create.folder['@type'], 'chatFolder');
  assert.equal(create.folder.name['@type'], 'chatFolderName');
  assert.equal(create.folder.name.text['@type'], 'formattedText');
  assert.equal(create.folder.name.text.text, 'Work');
  assert.deepEqual(create.folder.name.text.entities, []);
  assert.equal(create.folder.name.animate_custom_emoji, false);
  assert.deepEqual(create.folder.icon, { '@type': 'chatFolderIcon', name: '' });
  assert.equal(create.folder.color_id, 0);
  assert.equal(create.folder.is_shareable, false);
  assert.deepEqual(create.folder.pinned_chat_ids, []);
  assert.deepEqual(create.folder.included_chat_ids, []);
  assert.deepEqual(create.folder.excluded_chat_ids, []);
  assert.equal(create.folder.exclude_muted, true);
  assert.equal(create.folder.exclude_read, false);
  assert.equal(create.folder.exclude_archived, false);
  assert.equal(create.folder.include_groups, false);

  const includeAll = JSON.parse(serializer.buildTdlibRequestJson('createChatFolder',
    serializer.serializeCommand(C.createChatFolderCommand(draft({
      title: 'All',
      includeContacts: true,
      includeNonContacts: true,
      includeBots: true,
      includeGroups: true,
      includeChannels: true
    }))).params));
  assert.equal(includeAll.folder.include_contacts, true);
  assert.equal(includeAll.folder.include_non_contacts, true);
  assert.equal(includeAll.folder.include_bots, true);
  assert.equal(includeAll.folder.include_groups, true);
  assert.equal(includeAll.folder.include_channels, true);

  const selected = JSON.parse(serializer.buildTdlibRequestJson('createChatFolder',
    serializer.serializeCommand(C.createChatFolderCommand(draft({
      title: 'Pick',
      includedChatIds: [5, 9007199254740001]
    }))).params));
  assert.deepEqual(selected.folder.included_chat_ids, [5, 9007199254740001],
    'selected chat ids reach included_chat_ids unchanged');
  const filtered = JSON.parse(serializer.buildTdlibRequestJson('createChatFolder',
    serializer.serializeCommand(C.createChatFolderCommand(draft({
      title: 'Pick',
      includedChatIds: [3, 0, -1, 1.5]
    }))).params));
  assert.deepEqual(filtered.folder.included_chat_ids, [3], 'invalid ids never reach TDLib');

  // Quotes and backslashes must not break the raw JSON object.
  const quoted = JSON.parse(serializer.buildTdlibRequestJson('createChatFolder',
    serializer.serializeCommand(C.createChatFolderCommand(draft({ title: 'A"B\\C' }))).params));
  assert.equal(quoted.folder.name.text.text, 'A"B\\C');

  const edit = JSON.parse(serializer.buildTdlibRequestJson('editChatFolder',
    serializer.serializeCommand(C.createEditChatFolderCommand(12, draft({ title: 'Later', excludeArchived: true }))).params));
  assert.equal(edit.chat_folder_id, 12);
  assert.equal(edit.folder.name.text.text, 'Later');
  assert.equal(edit.folder.exclude_archived, true);

  const remove = JSON.parse(serializer.buildTdlibRequestJson('deleteChatFolder',
    serializer.serializeCommand(C.createDeleteChatFolderCommand(12)).params));
  assert.equal(remove.chat_folder_id, 12);
  assert.deepEqual(remove.leave_chat_ids, [], 'deleting never leaves chats implicitly');
}

// Invite links: wire shapes, list parsing and int53 chat ids --------------------------------------
{
  const listWire = JSON.parse(serializer.buildTdlibRequestJson('getChatFolderInviteLinks',
    serializer.serializeCommand(C.createGetChatFolderInviteLinksCommand(12)).params));
  assert.equal(listWire.chat_folder_id, 12);

  const createWire = JSON.parse(serializer.buildTdlibRequestJson('createChatFolderInviteLink',
    serializer.serializeCommand(C.createCreateChatFolderInviteLinkCommand(12, 'Friends')).params));
  assert.equal(createWire.chat_folder_id, 12);
  assert.equal(createWire.name, 'Friends');
  assert.deepEqual(createWire.chat_ids, []);

  const restrictedCreate = JSON.parse(serializer.buildTdlibRequestJson('createChatFolderInviteLink',
    serializer.serializeCommand(C.createCreateChatFolderInviteLinkCommand(12, 'Pick', [5, 9007199254740001]))
      .params));
  assert.deepEqual(restrictedCreate.chat_ids, [5, 9007199254740001],
    'restricted link keeps its chat ids, including int53');
  const filteredCreate = JSON.parse(serializer.buildTdlibRequestJson('createChatFolderInviteLink',
    serializer.serializeCommand(C.createCreateChatFolderInviteLinkCommand(12, 'Pick', [3, 0, -1])).params));
  assert.deepEqual(filteredCreate.chat_ids, [3], 'invalid chat ids are dropped from a link');

  const editWire = JSON.parse(serializer.buildTdlibRequestJson('editChatFolderInviteLink',
    serializer.serializeCommand(C.createEditChatFolderInviteLinkCommand(12, 'https://t.me/addlist/a', 'Best'))
      .params));
  assert.equal(editWire.chat_folder_id, 12);
  assert.equal(editWire.invite_link, 'https://t.me/addlist/a');
  assert.equal(editWire.name, 'Best');
  assert.deepEqual(editWire.chat_ids, [], 'no selection means all folder chats');
  const restrictedEdit = JSON.parse(serializer.buildTdlibRequestJson('editChatFolderInviteLink',
    serializer.serializeCommand(C.createEditChatFolderInviteLinkCommand(12, 'https://t.me/addlist/a', 'Best',
      [5, 9007199254740001])).params));
  assert.deepEqual(restrictedEdit.chat_ids, [5, 9007199254740001],
    'renaming a restricted link must not widen it to all folder chats');

  const deleteWire = JSON.parse(serializer.buildTdlibRequestJson('deleteChatFolderInviteLink',
    serializer.serializeCommand(C.createDeleteChatFolderInviteLinkCommand(12, 'https://t.me/addlist/abc')).params));
  assert.equal(deleteWire.chat_folder_id, 12);
  assert.equal(deleteWire.invite_link, 'https://t.me/addlist/abc');

  const links = L.createChatFolderInviteLinksFromTd(TdObject.fromJSON(LINKS_TEXT));
  assert.equal(links.links.length, 2);
  assert.equal(links.links[0].inviteLink, 'https://t.me/addlist/a');
  assert.equal(links.links[0].name, 'First');
  assert.deepEqual(links.links[0].chatIds, [5, 9007199254740001]);
  assert.deepEqual(links.links[1].chatIds, []);

  assert.equal(L.createChatFolderInviteLinksFromTd(TdObject.fromJSON('{"@type":"ok"}')).links.length, 0);
  assert.equal(L.createChatFolderInviteLinkFromTd(TdObject.fromJSON(
    '{"@type":"chatFolderInviteLink","invite_link":"","name":"x"}')), undefined);
}

// getChatFolder read-back: full folder including the flags chatFolderInfo omits -------------------
{
  const folderWire = JSON.parse(serializer.buildTdlibRequestJson('getChatFolder',
    serializer.serializeCommand(C.createGetChatFolderCommand(12)).params));
  assert.equal(folderWire.chat_folder_id, 12);

  const folderText = '{"@type":"chatFolder",' +
    '"name":{"@type":"chatFolderName","text":{"@type":"formattedText","text":"Work","entities":[]},' +
    '"animate_custom_emoji":false},' +
    '"icon":{"@type":"chatFolderIcon","name":"work"},' +
    '"color_id":3,"is_shareable":true,' +
    '"pinned_chat_ids":[9007199254740001],"included_chat_ids":[1,2],"excluded_chat_ids":[3],' +
    '"exclude_muted":true,"exclude_read":true,"exclude_archived":false,' +
    '"include_contacts":true,"include_non_contacts":false,"include_bots":true,' +
    '"include_groups":true,"include_channels":false}';
  const folder = D.createChatFolderDtoFromTd(TdObject.fromJSON(folderText));
  assert.equal(folder.title, 'Work');
  assert.equal(folder.iconName, 'work');
  assert.equal(folder.colorId, 3);
  assert.equal(folder.isShareable, true);
  assert.deepEqual(folder.pinnedChatIds, [9007199254740001], 'int53 ids keep their exact value');
  assert.deepEqual(folder.includedChatIds, [1, 2]);
  assert.deepEqual(folder.excludedChatIds, [3]);
  assert.equal(folder.excludeMuted, true);
  assert.equal(folder.excludeRead, true);
  assert.equal(folder.excludeArchived, false);
  assert.equal(folder.includeContacts, true);
  assert.equal(folder.includeBots, true);
  assert.equal(folder.includeGroups, true);
  assert.equal(folder.includeChannels, false);

  assert.equal(D.createChatFolderDtoFromTd(TdObject.fromJSON('{"@type":"ok"}')), undefined);
  const empty = D.createChatFolderDtoFromTd(TdObject.fromJSON('{"@type":"chatFolder"}'));
  assert.deepEqual(empty.includedChatIds, []);
  assert.equal(empty.excludeMuted, false);
}

// Use case: validation before the gateway, payload selection, error wrapping ----------------------
async function checkUseCase() {
  const sent = [];
  const gateway = { send: (command) => { sent.push(command); return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')); } };
  const mod = load('domain/usecases/manageChatFolders.ets',
    { ...C, ...errors, hilog, ChatFolderDto: D.ChatFolderDto,
      createChatFolderDtoFromTd: D.createChatFolderDtoFromTd });
  const useCase = new mod.ManageChatFoldersUseCase(gateway);

  const readSent = [];
  const folderGateway = { send: (command) => {
    readSent.push(command);
    return Promise.resolve(TdObject.fromJSON('{"@type":"chatFolder",' +
      '"name":{"@type":"chatFolderName","text":{"@type":"formattedText","text":"Work","entities":[]}},' +
      '"exclude_muted":true,"include_groups":true}'));
  } };
  const readingUseCase = new mod.ManageChatFoldersUseCase(folderGateway);
  const loaded = await readingUseCase.fetchFolder(9);
  assert.equal(readSent.at(-1).type, 'getChatFolder');
  assert.equal(readSent.at(-1).payload.folderId, 9);
  assert.equal(loaded.title, 'Work');
  assert.equal(loaded.excludeMuted, true, 'the stored flags are read back');
  assert.equal(loaded.includeGroups, true);

  await assert.rejects(() => readingUseCase.fetchFolder(0), /Invalid folderId/);
  await assert.rejects(() => new mod.ManageChatFoldersUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).fetchFolder(1),
    /Invalid folder response/);
  await assert.rejects(() => new mod.ManageChatFoldersUseCase(
    { send: () => Promise.reject(new Error('native status')) }).fetchFolder(1),
    /Failed to load the folder/);

  await useCase.createFolder(draft({ title: '  Work  ' }));
  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, 'createChatFolder');
  assert.equal(sent[0].payload.title, 'Work', 'the title is trimmed before sending');

  await useCase.editFolder(3, draft({ title: 'Home', excludeRead: true,
    includeContacts: true, includeChannels: true }));
  assert.equal(sent[1].type, 'editChatFolder');
  assert.equal(sent[1].payload.folderId, 3);
  assert.equal(sent[1].payload.draft.excludeRead, true);
  assert.equal(sent[1].payload.draft.includeContacts, true);
  assert.equal(sent[1].payload.draft.includeChannels, true);

  await useCase.deleteFolder(4);
  assert.equal(sent[2].type, 'deleteChatFolder');
  assert.equal(sent[2].payload.folderId, 4);

  // iOS caps the name at 12 characters and rejects an empty one.
  await assert.rejects(() => useCase.createFolder(draft({ title: '   ' })), /Invalid folder name/);
  await assert.rejects(() => useCase.createFolder(draft({ title: 'x'.repeat(13) })), /Invalid folder name/);
  await assert.rejects(() => useCase.editFolder(0, draft({ title: 'A' })), /Invalid folderId/);
  await assert.rejects(() => useCase.editFolder(1.5, draft({ title: 'A' })), /Invalid folderId/);
  await assert.rejects(() => useCase.deleteFolder(-2), /Invalid folderId/);
  await assert.rejects(() => useCase.createFolder(draft({ title: 'A', includedChatIds: [1, 0] })),
    /Invalid chat id/);

  const linkSent = [];
  const linksGateway = { send: (command) => {
    linkSent.push(command);
    if (command.type === 'getChatFolderInviteLinks') {
      return Promise.resolve(TdObject.fromJSON(LINKS_TEXT));
    }
    return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
  } };
  const linksUseCase = new (load('domain/usecases/manageChatFolderInviteLinks.ets',
    { ...C, ...errors, hilog, TdObject, ChatFolderInviteLinkDto: L.ChatFolderInviteLinkDto,
      createChatFolderInviteLinksFromTd: L.createChatFolderInviteLinksFromTd })
    .ManageChatFolderInviteLinksUseCase)(linksGateway);

  const listed = await linksUseCase.listLinks(12);
  assert.equal(linkSent.at(-1).type, 'getChatFolderInviteLinks');
  assert.equal(linkSent.at(-1).payload.folderId, 12);
  assert.equal(listed.length, 2);

  await linksUseCase.createLink(12, '  Friends  ', [5, 9007199254740001]);
  assert.equal(linkSent.at(-1).type, 'createChatFolderInviteLink');
  assert.equal(linkSent.at(-1).payload.name, 'Friends', 'the link name is trimmed');
  assert.deepEqual(linkSent.at(-1).payload.chatIds, [5, 9007199254740001],
    'the restricted chat set reaches the command');

  await linksUseCase.editLink(12, 'https://t.me/addlist/a', '  Best  ', [5]);
  assert.equal(linkSent.at(-1).type, 'editChatFolderInviteLink');
  assert.equal(linkSent.at(-1).payload.inviteLink, 'https://t.me/addlist/a');
  assert.equal(linkSent.at(-1).payload.name, 'Best', 'the renamed link name is trimmed');
  assert.deepEqual(linkSent.at(-1).payload.chatIds, [5], 'the rename keeps the link chat set');

  await linksUseCase.deleteLink(12, 'https://t.me/addlist/a');
  assert.equal(linkSent.at(-1).type, 'deleteChatFolderInviteLink');
  assert.equal(linkSent.at(-1).payload.inviteLink, 'https://t.me/addlist/a');

  await assert.rejects(() => linksUseCase.listLinks(0), /Invalid folderId/);
  await assert.rejects(() => linksUseCase.createLink(12, '   '), /Invalid link name/);
  await assert.rejects(() => linksUseCase.createLink(12, 'x'.repeat(33)), /Invalid link name/);
  await assert.rejects(() => linksUseCase.createLink(12, 'A', [0]), /Invalid chat id/);
  await assert.rejects(() => linksUseCase.editLink(12, 'https://t.me/addlist/a', '   ', []), /Invalid link name/);
  await assert.rejects(() => linksUseCase.editLink(12, 'https://t.me/addlist/a', 'A', [-1]),
    /Invalid chat id/);
  await assert.rejects(() => linksUseCase.deleteLink(12, '  '), /Invalid invite link/);
  assert.equal(linkSent.length, 4, 'invalid input never reaches the gateway');

  const failingLinks = new (load('domain/usecases/manageChatFolderInviteLinks.ets',
    { ...C, ...errors, hilog, TdObject, ChatFolderInviteLinkDto: L.ChatFolderInviteLinkDto,
      createChatFolderInviteLinksFromTd: L.createChatFolderInviteLinksFromTd })
    .ManageChatFolderInviteLinksUseCase)({ send: () => Promise.reject(new Error('native status')) });
  await assert.rejects(() => failingLinks.listLinks(1), /Failed to load invite links/);
  await assert.rejects(() => failingLinks.createLink(1, 'A'), /Failed to create the invite link/);
  await assert.rejects(() => failingLinks.deleteLink(1, 'https://t.me/addlist/x'), /Failed to delete the invite link/);
  await assert.rejects(() => failingLinks.editLink(1, 'https://t.me/addlist/x', 'A'),
    /Failed to update the invite link/);
  assert.equal(sent.length, 3, 'invalid input never reaches the gateway');

  await useCase.createFolder(draft({ title: 'x'.repeat(12) }));
  assert.equal(sent.at(-1).payload.title.length, 12, 'exactly twelve characters is allowed');

  const failing = { send: () => Promise.reject(new Error('native status')) };
  const failingUseCase = new mod.ManageChatFoldersUseCase(failing);
  await assert.rejects(() => failingUseCase.createFolder(draft({ title: 'A' })), /Failed to create the folder/);
  await assert.rejects(() => failingUseCase.editFolder(1, draft({ title: 'A' })), /Failed to update the folder/);
  await assert.rejects(() => failingUseCase.deleteFolder(1), /Failed to delete the folder/);
}

// Page, route, settings row and labels ------------------------------------------------------------
{
  const page = read('ui/pages/settings/TgChatFoldersPage.ets');
  assert.match(page, /export function TgChatFoldersPageBuilder\(\)/);
  assert.match(page, /createManageChatFoldersUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(page, /useCase\.createFolder\(this\.buildDraft\(\)\)/);
  assert.match(page, /useCase\.editFolder\(editing, this\.buildDraft\(\)\)/);
  assert.match(page, /useCase\.deleteFolder\(folderId\)/);
  assert.match(page, /store\.subscribe\(\(state: AppState\)/);
  assert.match(page, /state\.chatFilters\.folders/);
  assert.match(page, /maxLength\(CHAT_FOLDER_TITLE_MAX_LENGTH\)/);
  assert.match(page, /folders_delete_confirm/);
  assert.match(page, /useCase\.fetchFolder\(folderId\)/);
  assert.match(page, /this\.excludeMuted = folder\.excludeMuted;/);
  assert.match(page, /this\.excludeRead = folder\.excludeRead;/);
  assert.match(page, /@Local private includeContacts: boolean = false;/);
  assert.match(page, /this\.includeContacts = folder\.includeContacts;/);
  assert.match(page, /this\.includeChannels = folder\.includeChannels;/);
  assert.match(page, /draft\.includeContacts = this\.includeContacts;/);
  assert.match(page, /draft\.includeChannels = this\.includeChannels;/);
  assert.match(page, /folders_include_contacts/);
  assert.match(page, /folders_include_channels/);
  assert.match(page, /private resetIncludeFlags\(\): void \{/);
  assert.match(page, /enabled\(!this\.isBusy && !this\.isLoadingFolder && this\.draftTitle\.trim\(\)\.length > 0\)/,
    'saving stays disabled until the stored flags are read');
  assert.match(page, /folders_exclude_muted/);

  assert.match(page, /@Local private includedChatIds: number\[\] = \[\];/);
  assert.match(page, /this\.includedChatIds = folder\.includedChatIds\.slice\(\);/);
  assert.match(page, /draft\.includedChatIds = this\.includedChatIds\.slice\(\);/);
  assert.match(page, /private openChatSelection\(\): void \{/);
  assert.match(page, /pushPathByName\('TgFolderChatsPage', params,/);
  assert.match(page, /this\.includedChatIds = result\.selectedChatIds\.slice\(\);/);
  assert.match(page, /folders_included_chats/);
  assert.match(page, /createManageChatFolderInviteLinksUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(page, /useCase\.listLinks\(folderId\)/);
  assert.match(page, /useCase\.createLink\(folderId, name, chatIds\)/);
  assert.match(page, /useCase\.editLink\(folderId, inviteLink, this\.linkNameDraft, this\.editingLinkChatIds\)/);
  assert.match(page, /this\.editingLinkChatIds = link\.chatIds\.slice\(\);/);
  assert.match(page, /private openLinkChatSelection\(\): void \{/);
  assert.match(page, /params\.selectedChatIds = this\.includedChatIds\.slice\(\);/);
  assert.match(page, /this\.createInviteLink\(result\.selectedChatIds\.slice\(\)\);/);
  assert.match(page, /private startRenameLink\(link: ChatFolderInviteLinkDto\): void \{/);
  assert.match(page, /private saveLinkName\(\): void \{/);
  assert.match(page, /folders_rename_link/);
  assert.match(page, /useCase\.deleteLink\(folderId, inviteLink\)/);
  assert.match(page, /pasteboard\.getSystemPasteboard\(\)\.setDataSync\(data\)/);
  assert.match(page, /folders_invite_links/);
  assert.match(page, /folders_create_link/);

  const selectionPage = read('ui/pages/settings/TgFolderChatsPage.ets');
  assert.match(selectionPage, /export function TgFolderChatsPageBuilder\(\)/);
  assert.match(selectionPage, /getParamByName\('TgFolderChatsPage'\)/);
  assert.match(selectionPage, /this\.selected\.add\(chatId\)/);
  assert.match(selectionPage, /this\.selected\.delete\(chatId\)/);
  assert.match(selectionPage, /this\.selected = new Set<number>\(this\.selected\)/);
  assert.match(selectionPage, /this\.pageStack\.pop\(result, true\)/);
  assert.match(selectionPage, /selectOrderedChats\(state\)/);
  assert.match(selectionPage, /folder_chats_save/);

  const routeMap = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources/base/profile/route_map.json'), 'utf8'));
  const route = routeMap.routerMap.find((item) => item.name === 'TgChatFoldersPage');
  assert.ok(route, 'TgChatFoldersPage is registered');
  assert.equal(route.buildFunction, 'TgChatFoldersPageBuilder');
  const selectionRoute = routeMap.routerMap.find((item) => item.name === 'TgFolderChatsPage');
  assert.ok(selectionRoute, 'TgFolderChatsPage is registered');
  assert.equal(selectionRoute.buildFunction, 'TgFolderChatsPageBuilder');

  const settings = read('ui/pages/settings/SettingsPage.ets');
  assert.match(settings, /@Event onOpenChatFolders: \(\) => void/);
  assert.match(settings, /this\.onOpenChatFolders\(\);/);
  const tabs = read('ui/pages/MainTabsPage.ets');
  assert.match(tabs, /onOpenChatFolders: \(\): void => \{\n              this\.chatDetailNavStack\.pushPathByName\('TgChatFoldersPage', undefined\);/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['folders_list_section', 'folders_empty', 'folders_new', 'folders_edit_title',
      'folders_editing', 'folders_name_placeholder', 'folders_create', 'folders_save', 'folders_delete',
      'folders_cancel', 'folders_delete_confirm', 'folders_exclude_muted', 'folders_exclude_read',
      'folders_exclude_archived', 'folders_include_contacts', 'folders_include_non_contacts',
      'folders_include_bots', 'folders_include_groups', 'folders_include_channels',
      'folders_included_chats', 'folders_select_chats', 'folder_chats_title', 'folder_chats_empty',
      'folder_chats_save', 'folders_invite_links', 'folders_create_link', 'folders_links_empty',
      'folders_copy_link', 'folders_delete_link', 'folders_delete_link_confirm',
      'folders_link_default_name', 'folders_link_created_toast', 'folders_link_deleted_toast',
      'folders_link_copied_toast', 'folders_link_copy_failed', 'folders_link_failed_toast',
      'folders_rename_link', 'folders_link_renamed_toast', 'folders_link_chats',
      'folders_created_toast', 'folders_saved_toast', 'folders_deleted_toast',
      'folders_failed_toast']) {
      const item = strings.string.find((entry) => entry.name === name);
      assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
    }
  }
}

checkUseCase()
  .then(() => {
    console.log('PASS chat folder settings contract');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
