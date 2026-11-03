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

function load(relative, deps = {}) {
  const text = read(relative);
  const names = [...text.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map((match) => match[1]);
  const code = text.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '')
    .replace(/^@ObservedV2\s*\n/gm, '').replace(/^(\s*)@Trace\s+/gm, '$1');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) + `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

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

// Page wiring: long-press opens the menu, actions go to the existing use cases -----------------------
const page = read('ui/pages/chatlist/ChatListPage.ets');
assert.match(page, /import \{ selectChatContextMenuEntries, chatContextActionIcon, ChatContextAction, ChatContextMenuEntry \}/);
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

console.log('PASS chat list context menu contract');
