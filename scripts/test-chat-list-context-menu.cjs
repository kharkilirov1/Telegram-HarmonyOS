// B6 contract: chat list context menu (long-press row).
// iOS grounding: ChatContextMenus.swift offers mark read/unread, archive/unarchive, pin/unpin,
// mute/unmute and a destructive delete, in that order, and nothing for Saved Messages.
// The menu is a pure selector over Chat state; the page only renders and dispatches to use cases.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;
const read = (relative) => fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(main);

const A = load('core/model/AppState.ets');
const S = load('domain/selectors/chatContextMenuSelectors.ets', { ...A });

function chat(overrides = {}) {
  return Object.assign(new A.Chat(), {
    id: 7, title: 'Ann', type: 'private', peerUserId: 55, order: '10', archiveOrder: '0',
    unreadCount: 0, unreadMentionCount: 0, isPinned: false, muteForSeconds: 0,
    ...overrides
  });
}
const actions = (entries) => entries.map((entry) => entry.action);
const C = S.ChatContextAction;

// Base shape: iOS order, delete last and destructive ------------------------------------------------
{
  const entries = S.selectChatContextMenuEntries(chat(), 999);
  assert.deepEqual(actions(entries), [C.MarkUnread, C.Archive, C.Pin, C.Mute, C.Delete]);
  assert.deepEqual(entries.filter((entry) => entry.destructive).map((entry) => entry.action), [C.Delete],
    'only delete is destructive');
  assert.equal(new Set(actions(entries)).size, entries.length, 'no duplicate action');
}
// Unread chat offers "mark as read"; mentions count as unread too --------------------------------------
{
  assert.equal(actions(S.selectChatContextMenuEntries(chat({ unreadCount: 3 }), 999))[0], C.MarkRead);
  assert.equal(actions(S.selectChatContextMenuEntries(chat({ unreadMentionCount: 1 }), 999))[0], C.MarkRead);
  assert.equal(actions(S.selectChatContextMenuEntries(chat({ unreadCount: 0 }), 999))[0], C.MarkUnread);
}
// Archived, pinned and muted chats flip their actions ------------------------------------------------
{
  const archived = actions(S.selectChatContextMenuEntries(chat({ archiveOrder: '123' }), 999));
  assert.equal(archived[1], C.Unarchive);
  const pinned = actions(S.selectChatContextMenuEntries(chat({ isPinned: true }), 999));
  assert.equal(pinned[2], C.Unpin);
  const muted = actions(S.selectChatContextMenuEntries(chat({ muteForSeconds: 2147483647 }), 999));
  assert.equal(muted[3], C.Unmute);
  const everything = actions(S.selectChatContextMenuEntries(chat({
    unreadCount: 1, archiveOrder: '321', isPinned: true, muteForSeconds: 60
  }), 999));
  assert.deepEqual(everything, [C.MarkRead, C.Unarchive, C.Unpin, C.Unmute, C.Delete]);
}
// Saved Messages has no list management menu; a missing chat yields nothing ----------------------------
{
  const saved = chat({ id: 5, peerUserId: 999, title: 'Saved Messages' });
  assert.deepEqual(S.selectChatContextMenuEntries(saved, 999), [], 'Saved Messages has no context menu');
  assert.deepEqual(S.selectChatContextMenuEntries(undefined, 999), []);
  assert.deepEqual(S.selectChatContextMenuEntries(chat({ id: 0 }), 999), []);
}
// Icons are concrete assets the page can resolve -----------------------------------------------
{
  for (const action of [C.MarkRead, C.MarkUnread, C.Archive, C.Unarchive, C.Pin, C.Unpin,
    C.Mute, C.Unmute, C.Delete]) {
    const icon = S.chatContextActionIcon(action);
    assert.match(icon, /^ic_[a-z_]+$/, 'action ' + action + ' has an icon asset name');
    assert.ok(fs.existsSync(path.join(root, 'entry/src/main/resources/base/media', icon + '.svg')),
      'icon asset exists: ' + icon);
  }
  assert.notEqual(S.chatContextActionIcon(C.MarkRead), S.chatContextActionIcon(C.MarkUnread));
  assert.equal(S.chatContextActionIcon(C.Mute), 'ic_mute');
  assert.equal(S.chatContextActionIcon(C.Unmute), 'ic_unmute');
}

// Marked-as-unread: TDLib keeps this flag separate from unreadCount ------------------------------
{
  const { TdObject } = load('models/td/common/index.ets');
  const access = load('core/utils/tdAccessors.ets', { TdObject });
  const cmd = load('core/model/AppCommand.ets');
  const hilog = { info() {}, debug() {}, warn() {}, error() {} };
  const dto = load('core/model/dto/ChatDto.ets', { ...access, ...cmd, hilog });
  const events = load('core/model/AppEvent.ets', { ChatFolderInfo: A.ChatFolderInfo, ChatUpdateDto: dto.ChatUpdateDto });
  const clone = load('core/utils/stateClone.ets', { ...A });
  const { chatsReducer } = load('core/reducers/chatsReducer.ets',
    { ...A, ...events, ...clone, ...access, ChatDto: dto.ChatDto, DtoChatType: dto.ChatType, ChatUpdateDto: dto.ChatUpdateDto });
  const normalizer = load('core/events/normalizers/ChatNormalizer.ets',
    { ...events, ...dto, ...access, TdObject, hilog });

  // The full chat object carries the flag.
  const parsed = dto.createChatDtoFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'chat', id: 42, title: 'Ann', type: { '@type': 'chatTypePrivate', user_id: 7 },
    unread_count: 0, is_marked_as_unread: true, positions: [], photo: null, last_message: null,
    notification_settings: { '@type': 'chatNotificationSettings' },
    permissions: { '@type': 'chatPermissions' }, available_reactions: null, draft_message: null
  })));
  assert.equal(parsed.isMarkedAsUnread, true);

  // updateChatIsMarkedAsUnread reached the reducer (previously unhandled).
  const handlers = new Map();
  normalizer.registerChatHandlers(handlers);
  const dispatch = (type, payload) => {
    const produced = [];
    handlers.get(type)(produced, TdObject.fromJSON(JSON.stringify(payload)));
    return produced;
  };
  const marked = dispatch('updateChatIsMarkedAsUnread', {
    '@type': 'updateChatIsMarkedAsUnread', chat_id: 42, is_marked_as_unread: true
  });
  assert.equal(marked.length, 1);
  assert.equal(marked[0].type, 'chatUpdated');
  assert.equal(marked[0].updates.isMarkedAsUnread, true);

  const base = A.createInitialAppState();
  base.chats.chats.set(42, Object.assign(new A.Chat(), { id: 42, title: 'Ann', order: '10' }));
  const next = chatsReducer(base, marked[0]);
  assert.equal(next.chats.chats.get(42).isMarkedAsUnread, true, 'the flag must reach the chat');
  const cleared = chatsReducer(next, dispatch('updateChatIsMarkedAsUnread', {
    '@type': 'updateChatIsMarkedAsUnread', chat_id: 42, is_marked_as_unread: false
  })[0]);
  assert.equal(cleared.chats.chats.get(42).isMarkedAsUnread, false, 'and clear again');

  // A chat with no unread messages but a manual mark still offers "mark as read".
  const manual = S.selectChatContextMenuEntries(chat({ isMarkedAsUnread: true }), 999);
  assert.equal(manual[0].action, C.MarkRead, 'manual unread mark offers mark as read');

  // Row VO + diff contract, so the row repaints when the flag flips.
  const vo = read('ui/pages/chatlist/ChatItemVO.ets');
  assert.match(vo, /isMarkedAsUnread: boolean = false;/);
  assert.match(vo, /vo\.isMarkedAsUnread = chat\.isMarkedAsUnread;/);
  const dataSource = read('ui/pages/chatlist/ChatListDataSource.ets');
  assert.match(dataSource, /prev\.isMarkedAsUnread === next\.isMarkedAsUnread/);
}

// Page wiring: long-press opens the menu, actions go to the existing use cases -----------------------
const page = read('ui/pages/chatlist/ChatListPage.ets');
assert.match(page, /import \{ selectChatContextMenuEntries, chatContextActionIcon, ChatContextAction, ChatContextMenuEntry, selectAddToFolderTargets, ChatFolderTarget \}/);
assert.match(page, /\.bindContextMenu\(this\.buildChatContextMenu\(item\), ResponseType\.LongPress\)/,
  'long press must open the menu');
assert.match(page, /buildChatContextMenu\(item: ChatItemVO\)/);
assert.match(page, /selectChatContextMenuEntries\(state\.chats\.chats\.get\(item\.chatId\), state\.auth\.userId\)/);
assert.match(page, /private handleContextAction\(action: ChatContextAction, item: ChatItemVO\): void \{/);
// Every action reaches an existing use-case handler instead of a new backend path.
assert.match(page, /case ChatContextAction\.MarkRead:\n      case ChatContextAction\.MarkUnread:\n        this\.handleToggleUnread\(item\);/);
assert.match(page, /case ChatContextAction\.Archive:\n        this\.handleMoveToArchive\(item\);/);
assert.match(page, /case ChatContextAction\.Unarchive:\n        this\.handleMoveToMain\(item\);/);
assert.match(page, /case ChatContextAction\.Pin:\n      case ChatContextAction\.Unpin:\n        this\.handlePinToggle\(item\);/);
assert.match(page, /case ChatContextAction\.Mute:\n      case ChatContextAction\.Unmute:\n        this\.handleMuteToggle\(item\);/);
assert.match(page, /case ChatContextAction\.Delete:\n        this\.handleDeleteChat\(item\);/);
assert.match(page, /useCase\.execute\(item\.chatId, 'main'\)/, 'unarchive moves the chat back to the main list');

// Labels: nine action strings in all three locales, resolved by the page switch.
for (const locale of ['base', 'ru_RU', 'zh_CN']) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
  for (const name of ['chat_context_mark_read', 'chat_context_mark_unread', 'chat_context_archive',
    'chat_context_unarchive', 'chat_context_pin', 'chat_context_unpin', 'chat_context_mute',
    'chat_context_unmute', 'chat_context_delete']) {
    const item = strings.string.find((entry) => entry.name === name);
    assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
  }
}
// Tokens: metrics come from the token file, no magic numbers in the builder.
const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
for (const name of ['CHAT_CONTEXT_MENU_ITEM_HEIGHT', 'CHAT_CONTEXT_MENU_ICON_SIZE',
  'CHAT_CONTEXT_MENU_ICON_GAP', 'CHAT_CONTEXT_MENU_PADDING_H', 'CHAT_CONTEXT_MENU_FONT_SIZE',
  'CHAT_CONTEXT_MENU_RADIUS', 'CHAT_CONTEXT_MENU_WIDTH', 'CHAT_CONTEXT_MENU_BG',
  'CHAT_CONTEXT_MENU_TEXT', 'CHAT_CONTEXT_MENU_DESTRUCTIVE']) {
  assert.ok(tokens.includes(name), 'token ' + name + ' exists');
}
assert.ok(page.includes('TgUiTokens.CHAT_CONTEXT_MENU_ITEM_HEIGHT'), 'builder uses the tokens');

// Add to folder: addChatToList(chatListFolder) + only not-yet-member folders -------------------------
async function checkAddToFolder() {
  const { TdObject } = load('models/td/common/index.ets');
  const access = load('core/utils/tdAccessors.ets', { TdObject });
  const cmd = load('core/model/AppCommand.ets');
  const errors = load('core/model/AppError.ets');
  const hilog = { info() {}, debug() {}, warn() {}, error() {} };
  const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...cmd, TdObject, hilog });

  const command = cmd.createAddChatToListCommand(42, 'folder', 7);
  assert.equal(command.type, 'addChatToList');
  assert.equal(command.payload.chatList, 'folder');
  assert.equal(command.payload.folderId, 7);
  assert.equal(cmd.createAddChatToListCommand(42, 'main').payload.folderId, 0, 'main stays folderless');
  const parsed = JSON.parse(serializer.buildTdlibRequestJson('addChatToList',
    serializer.serializeCommand(command).params));
  assert.equal(parsed.chat_id, 42);
  assert.deepEqual(parsed.chat_list, { '@type': 'chatListFolder', 'chat_folder_id': 7 });
  const archiveParsed = JSON.parse(serializer.buildTdlibRequestJson('addChatToList',
    serializer.serializeCommand(cmd.createAddChatToListCommand(42, 'archive')).params));
  assert.deepEqual(archiveParsed.chat_list, { '@type': 'chatListArchive' }, 'archive regression');

  const sent = [];
  const gateway = { send: (issued) => { sent.push(issued); return Promise.resolve({}); } };
  const useCase = new (load('domain/usecases/moveChatToList.ets', { ...cmd, ...errors, hilog }).MoveChatToListUseCase)(gateway);
  await useCase.addToFolder(42, 7);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].payload.chatList, 'folder');
  assert.equal(sent[0].payload.folderId, 7);
  await assert.rejects(() => useCase.addToFolder(42, 0), /Invalid chatId\/folderId/);
  await assert.rejects(() => useCase.addToFolder(0, 7), /Invalid chatId\/folderId/);
  assert.equal(sent.length, 1, 'invalid input must not reach the gateway');
  await useCase.execute(42, 'archive');
  assert.equal(sent[1].payload.chatList, 'archive', 'archive move still works');

  // Targets: only folders the chat is not in yet.
  const state = A.createInitialAppState();
  state.chatFilters.folders.push(Object.assign(new A.ChatFolderInfo(), { id: 7, title: 'Work' }));
  state.chatFilters.folders.push(Object.assign(new A.ChatFolderInfo(), { id: 9, title: 'News' }));
  const member = Object.assign(new A.Chat(), { id: 42, title: 'Ann' });
  member.folderOrders.set(7, '10');
  state.chats.chats.set(42, member);
  const targets = S.selectAddToFolderTargets(state, 42);
  assert.deepEqual(targets.map((target) => target.folderId), [9], 'already-member folder is not offered');
  assert.equal(targets[0].title, 'News');
  assert.deepEqual(S.selectAddToFolderTargets(state, 999), [], 'unknown chat has no targets');
  state.chatFilters.folders = [];
  assert.deepEqual(S.selectAddToFolderTargets(state, 42), [], 'no folders, no section');

  // Page wiring: the section renders only with targets and dispatches to the use case.
  const page = read('ui/pages/chatlist/ChatListPage.ets');
  assert.match(page, /selectAddToFolderTargets, ChatFolderTarget/);
  assert.match(page, /private folderTargets\(item: ChatItemVO\): ChatFolderTarget\[\]/);
  assert.match(page, /if \(this\.folderTargets\(item\)\.length > 0\) \{/);
  assert.match(page, /private handleAddToFolder\(item: ChatItemVO, folderId: number\): void \{/);
  assert.match(page, /useCase\.addToFolder\(item\.chatId, folderId\)/);
  assert.match(page, /chat_context_add_to_folder/);
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    assert.ok(strings.string.find((item) => item.name === 'chat_context_add_to_folder'),
      'chat_context_add_to_folder exists in ' + locale);
  }
}

checkAddToFolder()
  .then(() => {
    console.log('PASS chat list context menu contract');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
