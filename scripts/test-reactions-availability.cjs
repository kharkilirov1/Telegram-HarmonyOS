// S3d data contract: chat.available_reactions parsing, the picker model and its single source of
// truth. The chat and message reaction-type parsers must not drift, so both are fed the same
// fixtures here.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const etsRoot = path.join(root, 'entry/src/main/ets');

function load(file, deps = {}) {
  const source = fs.readFileSync(path.join(etsRoot, file), 'utf8');
  const names = [...source.matchAll(/^export\s+(?:class|function|const)\s+(\w+)/gm)].map((match) => match[1]);
  const js = stripTypeScriptTypes(
    source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''),
    { mode: 'transform' }
  );
  return new Function(...Object.keys(deps), js + `; return {${names.join(',')}};`)(...Object.values(deps));
}

const tdCommon = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', { TdObject: tdCommon.TdObject });
const commands = load('core/model/AppCommand.ets');
const groupAccess = load('core/model/dto/GroupAccessDto.ets', { ...accessors, TdObject: tdCommon.TdObject });
const state = load('core/model/AppState.ets');
const messageDto = load('core/model/dto/MessageDto.ets', { ...tdCommon, ...accessors });
const chatDto = load('core/model/dto/ChatDto.ets', {
  ...tdCommon, ...accessors, ...commands, ...groupAccess,
  hilog: { info() {}, warn() {}, error() {}, debug() {} }
});
const td = (json) => tdCommon.TdObject.fromJSON(JSON.stringify(json));

const chatWithReactions = (available) => td({
  '@type': 'chat',
  id: 42,
  type: { '@type': 'chatTypePrivate', user_id: 7 },
  title: 'Chat',
  available_reactions: available,
  positions: [],
  last_message: {},
  notification_settings: { '@type': 'chatNotificationSettings' },
  permissions: { '@type': 'chatPermissions', can_send_basic_messages: true },
  photo: {},
  draft_message: {}
});

// chatAvailableReactionsSome ------------------------------------------------

const some = chatDto.createChatDtoFromTd(chatWithReactions({
  '@type': 'chatAvailableReactionsSome',
  reactions: [
    { '@type': 'reactionTypeEmoji', emoji: '👍' },
    { '@type': 'reactionTypeEmoji', emoji: '👍' },
    { '@type': 'reactionTypeCustomEmoji', custom_emoji_id: '5566' },
    { '@type': 'reactionTypePaid' }
  ],
  max_reaction_count: 3
}));
assert.deepEqual(some.availableReactionKeys, ['emoji:👍', 'custom:5566'],
  'some-list keeps order, dedupes and drops unsupported types');
assert.equal(some.availableReactionsAll, false);
assert.equal(some.maxReactionCount, 3);

// chatAvailableReactionsAll -----------------------------------------------

const all = chatDto.createChatDtoFromTd(chatWithReactions({
  '@type': 'chatAvailableReactionsAll',
  max_reaction_count: 1
}));
assert.equal(all.availableReactionsAll, true);
assert.deepEqual(all.availableReactionKeys, []);
assert.equal(all.maxReactionCount, 1);

// A chat without the field (old servers) is treated as "all". -----------------
const absent = chatDto.createChatDtoFromTd(chatWithReactions(undefined));
assert.equal(absent.availableReactionsAll, false);
assert.equal(absent.maxReactionCount, 0);
assert.deepEqual(absent.availableReactionKeys, []);

// Parser drift guard -------------------------------------------------------
for (const fixture of [
  { '@type': 'reactionTypeEmoji', emoji: '🔥' },
  { '@type': 'reactionTypeEmoji', emoji: '' },
  { '@type': 'reactionTypeCustomEmoji', custom_emoji_id: '42' },
  { '@type': 'reactionTypeCustomEmoji', custom_emoji_id: '0' },
  { '@type': 'reactionTypePaid' }
]) {
  assert.equal(chatDto.parseChatReactionTypeKey(td(fixture)),
    messageDto.parseReactionTypeKey(td(fixture)),
    `chat and message parsers must agree on ${JSON.stringify(fixture)}`);
}

// Picker model -------------------------------------------------------------

const chat = (keys, isAll, maxCount) => {
  const value = new state.Chat();
  value.availableReactionKeys = keys;
  value.availableReactionsAll = isAll;
  value.maxReactionCount = maxCount;
  return value;
};

assert.deepEqual(state.availableReactionKeys(undefined), state.DEFAULT_QUICK_REACTION_KEYS,
  'an unknown chat falls back to the iOS default row');
assert.deepEqual(state.availableReactionKeys(chat([], true, 3)), state.DEFAULT_QUICK_REACTION_KEYS,
  '"all" uses the default row');
assert.deepEqual(state.availableReactionKeys(chat([], false, 0)), state.DEFAULT_QUICK_REACTION_KEYS,
  'a missing list is treated as "unknown", not as "no reactions"');
assert.deepEqual(state.availableReactionKeys(chat(['emoji:🔥'], false, 1)), ['emoji:🔥']);
assert.equal(state.DEFAULT_QUICK_REACTION_KEYS.length, 12,
  'iOS ChatEntityKeyboardInputNode.swift:231 lists 12 default reactions');
assert.deepEqual(state.DEFAULT_QUICK_REACTION_KEYS, [
  'emoji:👍', 'emoji:👎', 'emoji:😍', 'emoji:😂', 'emoji:😯', 'emoji:😕',
  'emoji:😢', 'emoji:😡', 'emoji:💪', 'emoji:👏', 'emoji:🙈', 'emoji:😒'
]);
const many = [];
for (let index = 0; index < 20; index++) {
  many.push('emoji:e' + index);
}
assert.equal(state.availableReactionKeys(chat(many, false, 20)).length,
  state.MAX_PICKER_REACTION_KEYS, 'the picker row is capped');

assert.equal(state.chatAllowsReactions(undefined), true, 'unknown chat does not hide the picker');
assert.equal(state.chatAllowsReactions(chat([], false, 0)), false, 'an empty some-list forbids reactions');
assert.equal(state.chatAllowsReactions(chat([], true, 1)), true);
assert.equal(state.chatAllowsReactions(chat(['emoji:🔥'], false, 1)), true);

// Wiring -------------------------------------------------------------------

const reducer = fs.readFileSync(path.join(etsRoot, 'core/reducers/chatsReducer.ets'), 'utf8');
assert.match(reducer, /chat\.availableReactionKeys = dto\.availableReactionKeys\.slice\(\)/);
assert.match(reducer, /case 'chatAvailableReactionsUpdated'/, 'the chat-level update reaches the reducer');
const normalizer = fs.readFileSync(path.join(etsRoot, 'core/events/normalizers/ChatNormalizer.ets'), 'utf8');
assert.match(normalizer, /handlers\.set\('updateChatAvailableReactions', handleChatAvailableReactions\)/);
const appReducer = fs.readFileSync(path.join(etsRoot, 'core/reducers/index.ets'), 'utf8');
assert.match(appReducer, /'chatAvailableReactionsUpdated'/);

console.log('PASS reaction availability contracts');
