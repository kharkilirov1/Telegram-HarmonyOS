// S6b (D7) contract: the shared chat-screen open transaction, and the Saved Messages entry point that
// reuses it. Every entry point must write the same navigation/chat state and roll it back if the push
// throws; a second entry point must not copy that block.
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

const StorageKeys = {
  ACTIVE_CHAT_ID: 'activeChatId', ACTIVE_CHAT_TITLE: 'activeChatTitle',
  CHAT_NAV_LOCK_UNTIL: 'chatNavLockUntil', CHAT_SCREEN_VISIBLE: 'chatScreenVisible'
};
const navigationUIState = { activeChatOwnerToken: 0, activeChatId: 0, activeChatTitle: '', chatScreenVisible: false, chatNavLockUntil: 0 };
const chatUIState = { activeChatId: 0, activeChatTitle: '' };
const storage = new Map();
const AppStorage = {
  get: (key) => storage.get(key),
  set: (key, value) => { storage.set(key, value); }
};
const hilog = { info() {}, debug() {}, warn() {}, error() {} };
class ChatScreenRouteParams {
  constructor(chatId, chatTitle, store) {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
    this.accountStore = store;
    this.navigationToken = ++ChatScreenRouteParams.lastToken;
  }
  isCurrentAccount(store) { return this.accountStore === store && this.chatId !== 0; }
}
ChatScreenRouteParams.lastToken = 0;

const transaction = load('ui/pages/chat/ChatOpenTransaction.ets', {
  StorageKeys, navigationUIState, chatUIState, ChatScreenRouteParams, hilog, AppStorage
});
const store = { id: 'store' };

function reset() {
  navigationUIState.activeChatOwnerToken = 0;
  navigationUIState.activeChatId = 7;
  navigationUIState.activeChatTitle = 'Old';
  navigationUIState.chatScreenVisible = false;
  navigationUIState.chatNavLockUntil = 111;
  chatUIState.activeChatId = 7;
  chatUIState.activeChatTitle = 'Old';
  storage.clear();
  storage.set(StorageKeys.ACTIVE_CHAT_ID, 7);
  storage.set(StorageKeys.ACTIVE_CHAT_TITLE, 'Old');
}

// Push commits the whole navigation state and the route -------------------------------------------
{
  reset();
  const pushed = [];
  const navStack = { pushPathByName: (name, params) => pushed.push({ name, params }) };
  const params = new ChatScreenRouteParams(42, 'Target', store);
  assert.equal(transaction.pushChatScreenRoute(params, navStack, store), true);
  assert.equal(pushed.length, 1);
  assert.equal(pushed[0].name, transaction.CHAT_SCREEN_ROUTE_NAME);
  assert.equal(pushed[0].params, params);
  assert.equal(navigationUIState.activeChatId, 42);
  assert.equal(navigationUIState.activeChatTitle, 'Target');
  assert.equal(navigationUIState.activeChatOwnerToken, params.navigationToken);
  assert.equal(navigationUIState.chatScreenVisible, true);
  assert.ok(navigationUIState.chatNavLockUntil > 0);
  assert.equal(chatUIState.activeChatId, 42);
  assert.equal(storage.get(StorageKeys.ACTIVE_CHAT_ID), 42);
  assert.equal(storage.get(StorageKeys.CHAT_SCREEN_VISIBLE), true);
}

// Invalid input never touches state --------------------------------------------------------------
{
  reset();
  let calls = 0;
  const navStack = { pushPathByName: () => { calls++; } };
  assert.equal(transaction.pushChatScreenRoute(new ChatScreenRouteParams(0, 'X', store), navStack, store), false);
  const otherStore = new ChatScreenRouteParams(42, 'X', { id: 'other' });
  assert.equal(transaction.pushChatScreenRoute(otherStore, navStack, store), false);
  assert.equal(calls, 0, 'nothing is pushed for an invalid target');
  assert.equal(navigationUIState.activeChatId, 7);
  assert.equal(navigationUIState.activeChatTitle, 'Old');
}

// A throwing push rolls the state back -----------------------------------------------------------
{
  reset();
  const navStack = {
    pushPathByName: () => {
      throw new Error('navigation rejected');
    }
  };
  const params = new ChatScreenRouteParams(42, 'Target', store);
  assert.equal(transaction.pushChatScreenRoute(params, navStack, store), false);
  assert.equal(navigationUIState.activeChatId, 7);
  assert.equal(navigationUIState.activeChatTitle, 'Old');
  assert.equal(navigationUIState.activeChatOwnerToken, 0);
  assert.equal(navigationUIState.chatScreenVisible, false);
  assert.equal(navigationUIState.chatNavLockUntil, 111);
  assert.equal(chatUIState.activeChatId, 7);
  assert.equal(storage.get(StorageKeys.ACTIVE_CHAT_ID), 7);
  assert.equal(storage.get(StorageKeys.ACTIVE_CHAT_TITLE), 'Old');
  assert.equal(storage.get(StorageKeys.CHAT_NAV_LOCK_UNTIL), 111);
}

// Rollback does not clobber a newer owner --------------------------------------------------------
{
  reset();
  const navStack = {
    pushPathByName: () => {
      navigationUIState.activeChatOwnerToken = 999;
      throw new Error('navigation rejected');
    }
  };
  const params = new ChatScreenRouteParams(42, 'Target', store);
  assert.equal(transaction.pushChatScreenRoute(params, navStack, store), false);
  assert.equal(navigationUIState.activeChatOwnerToken, 999, 'a newer owner keeps its slot');
  assert.equal(navigationUIState.activeChatId, 42, 'rollback skipped entirely for the newer owner');
}

// Source contracts: one transaction, two entry points ---------------------------------------------
const chatList = read('ui/pages/chatlist/ChatListPage.ets');
assert.match(chatList, /pushChatScreenRoute\(params, navStack, getAppCoreRuntime\(\)\.getStore\(\)\)/,
  'chat list uses the shared transaction');
assert.ok(!/navigationUIState\.activeChatOwnerToken = params\.navigationToken/.test(chatList),
  'the chat list no longer duplicates the state transaction');
assert.ok(!/const CHAT_NAV_TRANSITION_LOCK_MS = 760/.test(chatList), 'the lock constant has one home');

const settings = read('ui/pages/settings/SettingsPage.ets');
assert.match(settings, /@Event onOpenSavedMessages: \(\) => void/);
assert.match(settings, /onRowClick: \(\): void => \{\s*this\.onOpenSavedMessages\(\);/, 'the row is no longer dead');

const tabs = read('ui/pages/MainTabsPage.ets');
assert.match(tabs, /onOpenSavedMessages: \(\): void => \{\s*this\.openSavedMessages\(\);/, 'tabs own the stack and the handler');
assert.match(tabs, /private openSavedMessages\(\): void \{/);
assert.match(tabs, /isSavedMessagesChat\(chat, selfUserId\)/, 'an existing Saved Messages chat opens directly');
assert.match(tabs, /createPrivateChatUseCase\(gateway\)\.execute\(selfUserId, false\)/,
  'a missing chat is created through createPrivateChat(my_id)');
assert.match(tabs, /store\.dispatch\(createNewChatEvent\(chat\.id, chat\)\)/,
  'the created chat is hydrated so the chat screen reducers see it');
assert.match(tabs, /if \(openToken !== this\.savedMessagesOpenToken\) \{\s*return;/, 'stale async answers are fenced');
assert.match(tabs, /pushChatScreenRoute\(new ChatScreenRouteParams\(chat\.id, title, store, gateway\),\s*this\.chatDetailNavStack, store\)/);

console.log('PASS chat open transaction and Saved Messages entry');
