// S6a (D7) contract: Saved Messages presentation.
// TDLib has no chat-type flag for Saved Messages (td_api.tl:8726: it is createPrivateChat with
// getOption("my_id")), so identity is "private chat whose peer is the current account". This slice pins
// the title in the chat list and in the chat screen, the bookmark avatar, and the list-diff flag; the
// entry point that opens the chat is still missing and recorded as debt.
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
  const tail = names.includes('isSavedMessagesChat') ? '' : '';
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform', sourceUrl: relative }) +
    `\nreturn {${names.join(',')}};${tail}`)(...Object.values(deps));
}

const A = load('core/model/AppState.ets');
const ac = load('core/utils/tdAccessors.ets', load('models/td/common/index.ets'));
const tokenStub = new Proxy(function () { return 0; }, { get: () => 0 });
const getString = () => '';
const fileUri = { getUriFromPath: (p) => 'file://' + p };
const items = load('ui/pages/chatlist/ChatItemVO.ets', {
  ...A, ...ac, getString, $r: (id) => ({ id }), TgUiTokens: tokenStub, fileUri, CHAT_ACTIVITY_TTL_MS: 5000
});

function chat(extra = {}) {
  return Object.assign(new A.Chat(), {
    id: 7, type: 'private', title: 'Ann', peerUserId: 7
  }, extra);
}
function state(selfUserId, peers) {
  const s = A.createInitialAppState();
  s.auth.userId = selfUserId;
  const map = new Map();
  for (const [id, first, last] of peers) {
    map.set(id, Object.assign(new A.User(), { id, firstName: first, lastName: last }));
  }
  s.users.users = map;
  return s;
}

// Predicate ---------------------------------------------------------------------------------------
assert.equal(A.isSavedMessagesChat(chat(), 7), true, 'private chat with the current account');
assert.equal(A.isSavedMessagesChat(chat(), 8), false, 'other private chat');
assert.equal(A.isSavedMessagesChat(chat({ peerUserId: 0 }), 7), false, 'chat without a peer id');
assert.equal(A.isSavedMessagesChat(chat({ type: 'group' }), 7), false, 'groups are never Saved Messages');
assert.equal(A.isSavedMessagesChat(chat({ type: 'secret' }), 7), false, 'secret chats have their own type');
assert.equal(A.isSavedMessagesChat(undefined, 7), false, 'undefined chat');
assert.equal(A.isSavedMessagesChat(chat(), 0), false, 'unknown self id cannot match');

// Chat list VO ------------------------------------------------------------------------------------
{
  const saved = items.buildChatItemVO(chat(), state(7, [[7, 'Ann', 'Lee']]));
  assert.equal(saved.isSavedMessages, true);
  assert.equal(saved.title, 'Saved Messages', 'title is the iOS string, not the account name');
  assert.equal(saved.initials, 'SM', 'initials follow the Saved Messages title (word initials)');
  assert.equal(items.buildChatItemVO(chat({ id: 9, peerUserId: 8 }), state(7, [[8, 'Bob', 'Ray']])).isSavedMessages,
    false);
  assert.equal(items.buildChatItemVO(chat({ id: 9, peerUserId: 8 }), state(7, [[8, 'Bob', 'Ray']])).title, 'Bob Ray');
  const group = chat({ id: 10, type: 'supergroup', peerUserId: 0, title: 'Team' });
  assert.equal(items.buildChatItemVO(group, state(7, [])).isSavedMessages, false, 'groups keep their title');
  assert.equal(items.buildChatItemVO(group, state(7, [])).title, 'Team');
}

// Chat screen title (timeline result feeds the top bar) -------------------------------------------
{
  const selectors = load('domain/selectors/messageSelectors.ets', { ...A, ...ac });
  const reply = load('core/utils/replyMessageKey.ets');
  const metaText = read('ui/tg_ui/atoms/TgMessageMeta.ets')
    .match(/export enum TgMessageSendStatus\s*\{[\s\S]*?\n\}/)[0];
  const statuses = new Function(stripTypeScriptTypes(metaText.replace('export ', ''), { mode: 'transform' }) +
    '\nreturn TgMessageSendStatus;')();
  const VO = load('ui/pages/chat/ChatTimelineVO.ets', {
    ...A, ...ac, ...selectors, ...reply, TgMessageSendStatus: statuses,
    hilog: { info() {}, debug() {}, warn() {}, error() {} }, $r: (id) => ({ id }),
    getString, fileUri, TgUiTokens: tokenStub
  });
  const savedState = state(7, [[7, 'Ann', 'Lee']]);
  savedState.chats.chats.set(7, chat());
  assert.equal(VO.buildChatTimeline(7, savedState).chatTitle, 'Saved Messages');
  const otherState = state(7, [[8, 'Bob', 'Ray']]);
  otherState.chats.chats.set(11, chat({ id: 11, peerUserId: 8 }));
  assert.equal(VO.buildChatTimeline(11, otherState).chatTitle, 'Bob Ray', 'normal private chat keeps the peer name');
}

// Presentation contracts --------------------------------------------------------------------------
const avatar = read('ui/tg_ui/atoms/TgAvatar.ets');
assert.match(avatar, /@Param symbolIcon: Resource \| undefined = undefined;/);
assert.match(avatar, /SymbolGlyph\(this\.symbolIcon\)/, 'the avatar renders the glyph instead of initials');
const row = read('ui/tg_ui/atoms/TgChatRow.ets');
assert.match(row, /@Param avatarIsSavedMessages: boolean = false;/);
assert.match(row, /symbolIcon: this\.avatarIsSavedMessages \? \$r\('sys\.symbol\.bookmark_fill'\) : undefined/);
const list = read('ui/pages/chatlist/ChatListPage.ets');
assert.match(list, /avatarIsSavedMessages: item\.isSavedMessages,/);
const diff = read('ui/pages/chatlist/ChatListDataSource.ets');
assert.match(diff, /prev\.isSavedMessages === next\.isSavedMessages/,
  'the VO flag participates in the row diff, otherwise the avatar never repaints');
const vo = read('ui/pages/chatlist/ChatItemVO.ets');
assert.match(vo, /isSavedMessagesChat\(chat, state\.auth\.userId\)/);
assert.match(vo, /getString\(\$r\('app\.string\.saved_messages'\)\.id\)/);
const timeline = read('ui/pages/chat/ChatTimelineVO.ets');
assert.match(timeline, /isSavedMessagesChat\(chat, state\.auth\.userId\)[\s\S]{0,120}saved_messages/);
for (const [locale, expected] of Object.entries({
  base: 'Saved Messages',
  ru_RU: 'Избранное',
  zh_CN: '收藏夹'
})) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, `entry/src/main/resources/${locale}/element/string.json`), 'utf8'));
  const entry = strings.string.find((item) => item.name === 'saved_messages');
  assert.equal(entry?.value, expected, `saved_messages in ${locale}`);
}
// The entry point is still missing: Settings renders the row but never wires navigation.
const settings = read('ui/pages/settings/SettingsPage.ets');
const settingsRow = settings.slice(settings.indexOf("saved_messages"), settings.indexOf("saved_messages") + 320);
assert.ok(!settingsRow.includes('onRowClick'), 'debt: the Settings row has no navigation yet');

console.log('PASS saved messages presentation contract');
