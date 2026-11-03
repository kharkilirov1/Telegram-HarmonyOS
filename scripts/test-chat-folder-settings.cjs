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

  await useCase.editFolder(3, draft({ title: 'Home', excludeRead: true }));
  assert.equal(sent[1].type, 'editChatFolder');
  assert.equal(sent[1].payload.folderId, 3);
  assert.equal(sent[1].payload.draft.excludeRead, true);

  await useCase.deleteFolder(4);
  assert.equal(sent[2].type, 'deleteChatFolder');
  assert.equal(sent[2].payload.folderId, 4);

  // iOS caps the name at 12 characters and rejects an empty one.
  await assert.rejects(() => useCase.createFolder(draft({ title: '   ' })), /Invalid folder name/);
  await assert.rejects(() => useCase.createFolder(draft({ title: 'x'.repeat(13) })), /Invalid folder name/);
  await assert.rejects(() => useCase.editFolder(0, draft({ title: 'A' })), /Invalid folderId/);
  await assert.rejects(() => useCase.editFolder(1.5, draft({ title: 'A' })), /Invalid folderId/);
  await assert.rejects(() => useCase.deleteFolder(-2), /Invalid folderId/);
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
  assert.match(page, /enabled\(!this\.isBusy && !this\.isLoadingFolder && this\.draftTitle\.trim\(\)\.length > 0\)/,
    'saving stays disabled until the stored flags are read');
  assert.match(page, /folders_exclude_muted/);

  const routeMap = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources/base/profile/route_map.json'), 'utf8'));
  const route = routeMap.routerMap.find((item) => item.name === 'TgChatFoldersPage');
  assert.ok(route, 'TgChatFoldersPage is registered');
  assert.equal(route.buildFunction, 'TgChatFoldersPageBuilder');

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
      'folders_exclude_archived', 'folders_created_toast', 'folders_saved_toast', 'folders_deleted_toast',
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
