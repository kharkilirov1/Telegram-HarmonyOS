// C6 (S5a) contract: the "Unread messages" divider exists in the timeline model and is rendered by
// the viewport. The matrix carried this row as `missing`; the code was there, so this suite is the
// evidence that the row is `partial` (code + host tests, no device witness) rather than absent.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;

function read(relative) {
  return fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');
}
const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(main);

const A = load('core/model/AppState.ets');
const ac = load('core/utils/tdAccessors.ets', load('models/td/common/index.ets'));
const selectors = load('domain/selectors/messageSelectors.ets', { ...A, ...ac });
const reply = load('core/utils/replyMessageKey.ets');
const metaText = read('ui/tg_ui/atoms/TgMessageMeta.ets')
  .match(/export enum TgMessageSendStatus\s*\{[\s\S]*?\n\}/)[0];
const statuses = new Function(stripTypeScriptTypes(metaText.replace('export ', ''), { mode: 'transform' }) +
  '\nreturn TgMessageSendStatus;')();
// Tokens are referenced only through the custom-emoji fallback; a numeric stand-in keeps the
// timeline build host-side without loading ArkUI resource types.
const tokenStub = new Proxy(function () { return 0; }, { get: () => 0 });
const platform = {
  hilog: { info() {}, debug() {}, warn() {}, error() {} },
  $r: (id) => ({ id }),
  getString: () => '',
  fileUri: { getUriFromPath: (p) => 'file://' + p },
  TgUiTokens: tokenStub
};
const VO = load('ui/pages/chat/ChatTimelineVO.ets',
  { ...A, ...ac, ...selectors, ...reply, TgMessageSendStatus: statuses, ...platform });

function message(id, extra = {}) {
  const value = Object.assign(new A.Message(), {
    id: String(id), chatId: 7, timestamp: 1700000000 + Number(id), isOutgoing: false
  }, extra);
  value.content = Object.assign(new A.MessageContent(), { type: 'text', text: 'text ' + id });
  return value;
}
function build(chatFields, messages, sticky = '') {
  const state = A.createInitialAppState();
  const chat = Object.assign(new A.Chat(), {
    id: 7, type: 'private', title: 'Fixture', unreadCount: 0, lastReadInboxMessageId: '0'
  }, chatFields);
  state.chats.chats.set(7, chat);
  const map = new Map();
  for (const item of messages) map.set(item.id, item);
  state.messages.messages.set(7, map);
  return VO.buildChatTimeline(7, state, sticky);
}
function unreadEntries(result) {
  return result.entries.filter((entry) => entry.kind === 'unread');
}

// Placement: incoming message newer than lastReadInbox gets the divider before it ---------------
const inserted = build({ unreadCount: 2, lastReadInboxMessageId: '100' },
  [message(100), message(101), message(102)]);
const divider = unreadEntries(inserted);
assert.equal(divider.length, 1, 'exactly one divider');
assert.equal(divider[0].unreadText, 'Unread messages', 'iOS Conversation_UnreadMessages wording');
assert.equal(divider[0].key, 'unread_before_101');
assert.equal(inserted.entries[inserted.unreadEntryIndex].kind, 'unread',
  'unreadEntryIndex points at the divider for scrolling');
assert.equal(inserted.entries[inserted.unreadEntryIndex + 1].message.messageId, '101',
  'the divider sits immediately above the first unread message');

// lastReadInbox '0' is a valid boundary: the first incoming message is unread -------------------
const firstUnread = unreadEntries(build({ unreadCount: 1, lastReadInboxMessageId: '0' }, [message(100)]));
assert.equal(firstUnread.length, 1);
assert.equal(firstUnread[0].key, 'unread_before_100');

// Outgoing messages are skipped when finding the boundary --------------------------------------
const withOutgoing = unreadEntries(build({ unreadCount: 1, lastReadInboxMessageId: '100' },
  [message(100), message(101, { isOutgoing: true }), message(102)]));
assert.equal(withOutgoing[0].key, 'unread_before_102');

// A captured entry-time boundary survives markChatRead resetting the live chat ------------------
const sticky = unreadEntries(build({ unreadCount: 0, lastReadInboxMessageId: '0' },
  [message(100), message(101)], '100'));
assert.equal(sticky.length, 1, 'sticky boundary keeps the divider after the chat was read');
assert.equal(sticky[0].key, 'unread_before_101');

// No unread messages, no divider ----------------------------------------------------------------
assert.equal(unreadEntries(build({ unreadCount: 0, lastReadInboxMessageId: '102' },
  [message(100), message(101)])).length, 0, 'a fully read chat has no divider');
assert.equal(build({ unreadCount: 0 }, [message(100)]).unreadEntryIndex, -1);

// The divider resets sender grouping: the first unread message shows its sender again -----------
const grouped = build({ type: 'group', unreadCount: 1, lastReadInboxMessageId: '100' },
  [message(100, { senderId: 5 }), message(101, { senderId: 5 })]);
const dividerIndex = grouped.entries.findIndex((entry) => entry.kind === 'unread');
const firstAfter = grouped.entries[dividerIndex + 1];
assert.ok(dividerIndex >= 0);
assert.equal(firstAfter.message.showSenderName, true,
  'iMessage shows the sender name after the unread divider');

// Rendering + fidelity contracts ----------------------------------------------------------------
const viewport = read('ui/pages/chat/TgChatTimelineViewport.ets');
assert.match(viewport, /entry\.kind === 'unread'[\s\S]*TgUnreadMarker\(\{/,
  'the viewport renders the divider through the atom');
assert.match(viewport, /text: entry\.unreadText/);
const atomSource = read('ui/tg_ui/atoms/TgDateSeparator.ets');
assert.match(atomSource, /export struct TgUnreadMarker/);
const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
const expectations = {
  UNREAD_MARKER_HEIGHT: '25',           // iOS ChatUnreadItem: backgroundSize height 25
  UNREAD_MARKER_RADIUS: '0',            // full-width bar, not a pill
  UNREAD_MARKER_MARGIN_TOP: '6',        // iOS insets top 6.0
  UNREAD_MARKER_MARGIN_BOTTOM: '5',     // iOS insets bottom 5.0
  UNREAD_MARKER_MAX_WIDTH_RATIO: '1.0'  // iOS bar spans the list width
};
for (const [token, value] of Object.entries(expectations)) {
  assert.match(tokens, new RegExp(`${token}: number = ${value.replace('.', '\\.')}`),
    `${token} must stay on the iOS geometry (${value})`);
}
for (const [locale, value] of Object.entries({
  base: 'Unread messages',
  ru_RU: 'Непрочитанные сообщения',
  zh_CN: '未读消息'
})) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, `entry/src/main/resources/${locale}/element/string.json`), 'utf8'));
  const entry = strings.string.find((item) => item.name === 'chat_unread_messages');
  assert.ok(entry, `chat_unread_messages missing in ${locale}`);
  assert.equal(entry.value, value, `wrong wording in ${locale}`);
}
assert.ok(fs.existsSync(path.join(main, 'ui/tg_ui/spec/TgUnreadMarker.md')),
  'the divider needs a passport');
assert.match(read('ui/pages/chat/ChatTimelineVO.ets'),
  /localizedString\(\$r\('app\.string\.chat_unread_messages'\)\.id, 'Unread messages'\)/,
  'the VO uses the dedicated string, not the chat-filter "Unread"');

console.log('PASS unread divider contracts');
