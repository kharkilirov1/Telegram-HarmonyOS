// S7a (B7) contract: chat folders data layer.
// TDLib owns the folder list (chatFolderInfo + updateChatFolders). The app mirrors it into state,
// routes it through one reducer, and exposes a tab-strip selector that keeps the "All chats" tab at
// the position TDLib asks for. No UI is wired yet — that is S7b.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;
const read = (relative) => fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');

function load(relative, deps = {}) {
  const text = read(relative);
  const names = [...text.matchAll(/^export\s+(?:default\s+)?(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)]
    .map((match) => match[1]);
  const code = text.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, '')
    .replace(/^@ObservedV2\s*\n/gm, '').replace(/^(\s*)@Trace\s+/gm, '$1');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform', sourceUrl: relative }) +
    `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

const A = load('core/model/AppState.ets');
const F = { ChatFolderInfo: A.ChatFolderInfo, ChatFoldersState: A.ChatFoldersState };
const { TdObject } = load('models/td/common/index.ets');
const access = load('core/utils/tdAccessors.ets', { TdObject });
const C = load('core/model/AppCommand.ets');
const hilog = { info() {}, debug() {}, warn() {}, error() {} };
const dtoModule = load('core/model/dto/ChatDto.ets', { ...access, ...C, hilog });
const E = load('core/model/AppEvent.ets', { ChatFolderInfo: F.ChatFolderInfo, ChatUpdateDto: dtoModule.ChatUpdateDto });
const clone = load('core/utils/stateClone.ets', { ...A });
const R = load('core/reducers/chatFoldersReducer.ets', { ...A, ...E, ...F, ...clone });
const S = load('domain/selectors/chatFolderSelectors.ets', { ...A, ...F, ...access });
const N = load('core/events/normalizers/ChatFolderNormalizer.ets', { ...E, ...F, TdObject, ...access });

function folder(id, title, extra = {}) {
  return Object.assign(new F.ChatFolderInfo(), { id, title }, extra);
}

// State shape ---------------------------------------------------------------------------------------
{
  const state = A.createInitialAppState();
  assert.ok(state.chatFilters instanceof F.ChatFoldersState, 'AppState mirrors the folder list');
  assert.deepEqual(state.chatFilters.folders, []);
  assert.equal(state.chatFilters.mainChatListPosition, 0);
  assert.equal(state.chatFilters.areTagsEnabled, false);
}

// Normalizer: updateChatFolders -> one event with the parsed folders ---------------------------------
function tdUpdate(folders, position, tags) {
  const json = JSON.stringify({
    '@type': 'updateChatFolders',
    chat_folders: folders.map((item) => ({
      '@type': 'chatFolderInfo',
      id: item.id,
      name: { '@type': 'chatFolderName', text: { '@type': 'formattedText', text: item.title, entities: [] },
        animate_custom_emoji: false },
      icon: { '@type': 'chatFolderIcon', name: item.iconName ?? '' },
      color_id: item.colorId ?? -1,
      is_shareable: item.isShareable ?? false,
      has_my_invite_links: false
    })),
    main_chat_list_position: position,
    are_tags_enabled: tags
  });
  return TdObject.fromJSON(json);
}

{
  const events = [];
  N.handleChatFolders(events, tdUpdate([
    { id: 2, title: 'Work', iconName: 'briefcase', colorId: 3, isShareable: true },
    { id: 5, title: 'News' }
  ], 1, true));
  assert.equal(events.length, 1);
  const event = events[0];
  assert.equal(event.type, 'chatFoldersUpdated');
  assert.equal(event.folders.length, 2);
  assert.equal(event.folders[0].id, 2);
  assert.equal(event.folders[0].title, 'Work');
  assert.equal(event.folders[0].iconName, 'briefcase');
  assert.equal(event.folders[0].colorId, 3);
  assert.equal(event.folders[0].isShareable, true);
  assert.equal(event.folders[1].title, 'News');
  assert.equal(event.mainChatListPosition, 1);
  assert.equal(event.areTagsEnabled, true);

  // Malformed / unknown entries are skipped instead of becoming phantom folders.
  const broken = TdObject.fromJSON(JSON.stringify({
    '@type': 'updateChatFolders',
    chat_folders: [{ '@type': 'chatFolderInfo', id: 0, name: { text: { text: 'zero' } } },
      { '@type': 'someUnknown', id: 9 }, { '@type': 'chatFolderInfo', id: 4 }],
    main_chat_list_position: 0,
    are_tags_enabled: false
  }));
  const second = [];
  N.handleChatFolders(second, broken);
  assert.deepEqual(second[0].folders.map((item) => item.id), [4]);
  assert.equal(second[0].folders[0].title, '');
}

// Reducer: replaces the list, never mutates the previous state -----------------------------
{
  const state = A.createInitialAppState();
  state.chatFilters.folders.push(folder(1, 'Old'));
  const event = E.createChatFoldersUpdatedEvent([folder(2, 'Work'), folder(3, 'News')], 2, true);
  const next = R.chatFoldersReducer(state, event);
  assert.notEqual(next, state);
  assert.equal(next.chatFilters.folders.length, 2);
  assert.equal(next.chatFilters.folders[0].title, 'Work');
  assert.equal(next.chatFilters.mainChatListPosition, 2);
  assert.equal(next.chatFilters.areTagsEnabled, true);
  assert.equal(state.chatFilters.folders.length, 1, 'previous state stays untouched');
  assert.equal(R.chatFoldersReducer(state, { type: 'unrelated', payload: undefined }), state,
    'unrelated events pass through without cloning');
}

// Selector: "All chats" sits where TDLib asks -----------------------------------------------
{
  const make = (position, folders) => {
    const state = A.createInitialAppState();
    state.chatFilters = Object.assign(new F.ChatFoldersState(), {
      folders, mainChatListPosition: position
    });
    return S.selectChatFolderTabs(state);
  };
  const titles = (tabs) => tabs.map((tab) => (tab.isAllChats ? 'All' : tab.title));

  assert.deepEqual(titles(make(0, [])), ['All'], 'empty account keeps the plain list');
  assert.deepEqual(titles(make(0, [folder(2, 'Work'), folder(3, 'News')])), ['All', 'Work', 'News']);
  assert.deepEqual(titles(make(1, [folder(2, 'Work'), folder(3, 'News')])), ['Work', 'All', 'News']);
  assert.deepEqual(titles(make(2, [folder(2, 'Work'), folder(3, 'News')])), ['Work', 'News', 'All']);
  assert.deepEqual(titles(make(99, [folder(2, 'Work')])), ['Work', 'All'], 'a position past the end clamps');
  const tabs = make(0, [folder(2, 'Work')]);
  assert.equal(tabs[0].id, S.CHAT_FOLDER_ALL_ID);
  assert.equal(tabs[0].id, 0);
  assert.equal(tabs[1].id, 2);
}

// Folder membership: chatListFolder positions, add/remove updates, per-folder ordering --------------
{
  const chatNormalizer = load('core/events/normalizers/ChatNormalizer.ets',
    { ...E, ...dtoModule, ...access, TdObject, hilog });
  const handlers = new Map();
  chatNormalizer.registerChatHandlers(handlers);
  const dispatch = (type, payload) => {
    const events = [];
    handlers.get(type)(events, TdObject.fromJSON(JSON.stringify(payload)));
    return events;
  };
  const { chatsReducer } = load('core/reducers/chatsReducer.ets', {
    ...A, ...E, ...clone, ...access, ChatDto: dtoModule.ChatDto, DtoChatType: dtoModule.ChatType,
    ChatUpdateDto: dtoModule.ChatUpdateDto
  });

  // Position parser: a folder position is typed and validated, other lists are rejected.
  const folderPosition = dtoModule.extractFolderPosition(TdObject.fromJSON(JSON.stringify({
    '@type': 'chatPosition',
    list: { '@type': 'chatListFolder', chat_folder_id: 7 },
    order: '123456789012345',
    is_pinned: false,
    source: null
  })));
  assert.equal(folderPosition.folderId, 7);
  assert.equal(folderPosition.order, '123456789012345');
  assert.equal(dtoModule.extractFolderPosition(TdObject.fromJSON(JSON.stringify({
    '@type': 'chatPosition', list: { '@type': 'chatListMain' }, order: '1'
  }))), undefined);
  assert.equal(dtoModule.extractFolderPosition(TdObject.fromJSON(JSON.stringify({
    '@type': 'chatPosition', list: { '@type': 'chatListFolder', chat_folder_id: 0 }, order: '1'
  }))), undefined, 'folder id 0 is not a folder');

  // updateChatAddedToList / updateChatRemovedFromList carry the folder membership change.
  const added = dispatch('updateChatAddedToList', {
    '@type': 'updateChatAddedToList', chat_id: 42,
    chat_list: { '@type': 'chatListFolder', chat_folder_id: 7 }
  });
  assert.equal(added.length, 1);
  assert.equal(added[0].updates.folderId, 7);
  assert.ok(added[0].updates.folderOrder.length > 0);
  const removed = dispatch('updateChatRemovedFromList', {
    '@type': 'updateChatRemovedFromList', chat_id: 42,
    chat_list: { '@type': 'chatListFolder', chat_folder_id: 7 }
  });
  assert.equal(removed.length, 1);
  assert.equal(removed[0].updates.folderId, 7);
  assert.equal(removed[0].updates.folderRemoved, true);
  const ignored = dispatch('updateChatRemovedFromList', {
    '@type': 'updateChatRemovedFromList', chat_id: 42,
    chat_list: { '@type': 'chatListFolder', chat_folder_id: 0 }
  });
  assert.equal(ignored.length, 0, 'folder id 0 must not touch state');

  // Reducer: membership is added and dropped without touching main/archive order.
  const base = A.createInitialAppState();
  const chat = Object.assign(new A.Chat(), { id: 42, title: 'Work chat', order: '10', archiveOrder: '0' });
  base.chats.chats.set(42, chat);
  const afterAdd = chatsReducer(base, E.createChatUpdatedEvent(42, added[0].updates));
  const addedChat = afterAdd.chats.chats.get(42);
  assert.equal(addedChat.folderOrders.get(7), added[0].updates.folderOrder);
  assert.equal(addedChat.order, '10', 'main list order is untouched by a folder update');
  const afterRemove = chatsReducer(afterAdd, E.createChatUpdatedEvent(42, removed[0].updates));
  assert.equal(afterRemove.chats.chats.get(42).folderOrders.has(7), false);

  // Selector: only folder members, ordered by the folder's own sort key.
  const sel = A.createInitialAppState();
  const first = Object.assign(new A.Chat(), { id: 1, title: 'A' });
  first.folderOrders.set(7, '100');
  const second = Object.assign(new A.Chat(), { id: 2, title: 'B' });
  second.folderOrders.set(7, '300');
  const other = Object.assign(new A.Chat(), { id: 3, title: 'C' });
  other.folderOrders.set(9, '999');
  sel.chats.chats.set(1, first);
  sel.chats.chats.set(2, second);
  sel.chats.chats.set(3, other);
  assert.deepEqual(S.selectChatIdsForFolder(sel, 7), [2, 1], 'higher folder order first');
  assert.deepEqual(S.selectChatIdsForFolder(sel, 9), [3]);
  assert.deepEqual(S.selectChatIdsForFolder(sel, 11), [], 'unknown folder has no chats');
}

// Per-list unread counters + folder strip UI wiring -------------------------------------------------
{
  // updateUnreadChatCount is keyed per list; archive and folder lists must not collide with main.
  const unreadEvents = [];
  N.handleUnreadChatCount(unreadEvents, TdObject.fromJSON(JSON.stringify({
    '@type': 'updateUnreadChatCount',
    chat_list: { '@type': 'chatListMain' },
    total_count: 12, unread_count: 5, unread_unmuted_count: 3,
    marked_as_unread_count: 0, marked_as_unread_unmuted_count: 0
  })));
  N.handleUnreadChatCount(unreadEvents, TdObject.fromJSON(JSON.stringify({
    '@type': 'updateUnreadChatCount',
    chat_list: { '@type': 'chatListFolder', chat_folder_id: 7 },
    total_count: 3, unread_count: 2, unread_unmuted_count: 0,
    marked_as_unread_count: 0, marked_as_unread_unmuted_count: 0
  })));
  N.handleUnreadChatCount(unreadEvents, TdObject.fromJSON(JSON.stringify({
    '@type': 'updateUnreadChatCount',
    chat_list: { '@type': 'chatListArchive' },
    total_count: 1, unread_count: 1, unread_unmuted_count: 1,
    marked_as_unread_count: 0, marked_as_unread_unmuted_count: 0
  })));
  assert.deepEqual(unreadEvents.map((event) => event.listKey), ['main', 'folder:7', 'archive']);
  assert.equal(unreadEvents[1].unreadCount, 2);
  const beforeZero = unreadEvents.length;
  N.handleUnreadChatCount(unreadEvents, TdObject.fromJSON(JSON.stringify({
    '@type': 'updateUnreadChatCount',
    chat_list: { '@type': 'chatListFolder', chat_folder_id: 0 },
    total_count: 9, unread_count: 9
  })));
  assert.equal(unreadEvents.length, beforeZero, 'folder id 0 is not a list');

  // Reducer keeps the folder strip and only replaces the counter of that list.
  const seeded = A.createInitialAppState();
  seeded.chatFilters.folders.push(folder(7, 'Work'));
  seeded.chatFilters.folders.push(folder(9, 'News'));
  seeded.chatFilters.mainChatListPosition = 1;
  const withMain = R.chatFoldersReducer(seeded, unreadEvents[0]);
  const withFolder = R.chatFoldersReducer(withMain, unreadEvents[1]);
  assert.equal(withFolder.chatFilters.unreadByList.get('main'), 5);
  assert.equal(withFolder.chatFilters.unreadByList.get('folder:7'), 2);
  assert.equal(withFolder.chatFilters.folders.length, 2, 'counters do not drop the folder list');
  assert.equal(withFolder.chatFilters.mainChatListPosition, 1);

  // The tab strip carries those counters.
  const tabs = S.selectChatFolderTabs(withFolder);
  const byId = (id) => tabs.find((tab) => tab.id === id);
  assert.equal(byId(0).unreadCount, 5, 'All chats shows the main list counter');
  assert.equal(byId(7).unreadCount, 2);
  assert.equal(byId(9).unreadCount, 0, 'a folder without a reported counter shows none');
}

// The UI contract: data-driven strip, folder-sourced list, three locales.
{
  const bar = read('ui/tg_ui/atoms/TgChatListFilterBar.ets');
  assert.match(bar, /export class TgChatListFilterTab \{/);
  assert.match(bar, /@Param tabs: TgChatListFilterTab\[\] = \[\];/);
  assert.match(bar, /@Param selectedFolderId: number = 0;/);
  assert.match(bar, /@Event onFolderSelected: \(folderId: number\) => void/);
  assert.match(bar, /private buildFolderTab\(tab: TgChatListFilterTab\)/);
  assert.match(bar, /this\.tabs\.length > 0/);
  const navBar = read('ui/tg_ui/atoms/TgChatListNavigationBar.ets');
  assert.match(navBar, /@Param filterTabs: TgChatListFilterTab\[\] = \[\];/);
  assert.match(navBar, /@Event onFolderFilterChange: \(folderId: number\) => void/);
  assert.match(navBar, /tabs: this\.filterTabs,/);
  const page = read('ui/pages/chatlist/ChatListPage.ets');
  assert.match(page, /import \{ selectChatFolderTabs, selectChatIdsForFolder, ChatFolderTab \}/);
  assert.match(page, /@Local private selectedFolderId: number = 0;/);
  assert.match(page, /this\.folderTabs = this\.buildFolderTabs\(state\);/);
  assert.match(page, /folderId !== 0 \?\n      selectChatIdsForFolder\(state, folderId\) : state\.chats\.orderedChatIds;/);
  assert.match(page, /private selectFolder\(folderId: number\): void \{/);
  assert.match(page, /filterTabs: this\.folderTabs,/);
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    assert.ok(strings.string.find((item) => item.name === 'chat_folders_all'),
      'chat_folders_all exists in ' + locale);
  }
}

// Wiring contracts ---------------------------------------------------------------------------------
const appState = read('core/model/AppState.ets');
assert.match(appState, /chatFilters: ChatFoldersState = new ChatFoldersState\(\);/);
const events = read('core/model/AppEvent.ets');
assert.match(events, /type: string = 'chatFoldersUpdated';/);
assert.match(events, /\| ChatFoldersUpdatedEvent/, 'the event belongs to the AnyAppEvent union');
assert.match(events, /export function createChatFoldersUpdatedEvent\(/);
const reducerIndex = read('core/reducers/index.ets');
assert.match(reducerIndex, /action\.type === 'chatFoldersUpdated'[\s\S]{0,80}chatFoldersReducer\(state, action\)/);
const normalizerIndex = read('core/events/EventNormalizer.ets');
assert.match(normalizerIndex, /registerChatFolderHandlers\(this\.handlers\);/);
assert.match(normalizerIndex, /from '\.\/normalizers\/ChatFolderNormalizer'/);
const normalizer = read('core/events/normalizers/ChatFolderNormalizer.ets');
assert.match(normalizer, /handlers\.set\('updateChatFolders', handleChatFolders\)/);
assert.match(normalizer, /tdGetNumber\(raw, 'color_id'\)/);
assert.match(normalizer, /tdGetBoolean\(update, 'are_tags_enabled'\)/);
// The TDLib contract must stay the local one.
const tl = fs.readFileSync(path.join(root, 'tdlib/td/generate/scheme/td_api.tl'), 'utf8');
assert.match(tl, /updateChatFolders chat_folders:vector<chatFolderInfo> main_chat_list_position:int32 are_tags_enabled:Bool = Update;/);

console.log('PASS chat folders data layer');
