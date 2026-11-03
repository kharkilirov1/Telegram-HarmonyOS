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
const E = load('core/model/AppEvent.ets', { ChatFolderInfo: F.ChatFolderInfo });
const clone = load('core/utils/stateClone.ets', { ...A });
const R = load('core/reducers/chatFoldersReducer.ets', { ...A, ...E, ...F, ...clone });
const S = load('domain/selectors/chatFolderSelectors.ets', { ...A, ...F });
const { TdObject } = load('models/td/common/index.ets');
const access = load('core/utils/tdAccessors.ets', { TdObject });
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
