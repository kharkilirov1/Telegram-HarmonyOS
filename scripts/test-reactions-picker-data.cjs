// S3d.1 data contract: getMessageAvailableReactions command shape, response parsing and the picker
// merge model. The popup keeps the chat-level row while the request is in flight, so the merge must
// degrade to it on an empty/failed answer.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const etsRoot = path.join(root, 'entry/src/main/ets');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(etsRoot);

const tdCommon = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', { TdObject: tdCommon.TdObject });
const commands = load('core/model/AppCommand.ets');
const state = load('core/model/AppState.ets');
const messageDto = load('core/model/dto/MessageDto.ets', { ...tdCommon, ...accessors });
const serializer = load('infra/td/serialization/CommandSerializer.ets', {
  ...commands,
  TdObject: tdCommon.TdObject,
  ...accessors,
  hilog: { info() {}, warn() {}, error() {}, debug() {} }
});
const td = (json) => tdCommon.TdObject.fromJSON(JSON.stringify(json));

function requestFor(command) {
  const serialized = serializer.serializeCommand(command);
  const body = serializer.buildTdlibRequestJson(serialized.method, serialized.params);
  return { serialized, body: JSON.parse(body) };
}

// Command ----------------------------------------------------------------

const request = requestFor(commands.createGetMessageAvailableReactionsCommand(42, '777', 12));
assert.equal(request.serialized.method, 'getMessageAvailableReactions');
assert.equal(request.body['@type'], 'getMessageAvailableReactions');
assert.equal(request.body.chat_id, 42);
assert.equal(request.body.message_id, '777', 'int64 stays a decimal string');
assert.equal(request.body.row_size, 12);

// Response parsing -------------------------------------------------------

const availableReaction = (type) => ({
  '@type': 'availableReaction',
  type,
  needs_premium: false
});
const response = (top, recent, popular, extra = {}) => td({
  '@type': 'availableReactions',
  top_reactions: top,
  recent_reactions: recent,
  popular_reactions: popular,
  allow_custom_emoji: true,
  are_tags: false,
  ...extra
});

const parsed = messageDto.parseAvailableReactions(response(
  [availableReaction({ '@type': 'reactionTypeEmoji', emoji: '👍' }),
    availableReaction({ '@type': 'reactionTypeEmoji', emoji: '👍' }),
    availableReaction({ '@type': 'reactionTypeCustomEmoji', custom_emoji_id: '42' })],
  [availableReaction({ '@type': 'reactionTypeEmoji', emoji: '🔥' })],
  [availableReaction({ '@type': 'reactionTypePaid' }),
    availableReaction({ '@type': 'reactionTypeEmoji', emoji: '🎉' })]
));
assert.deepEqual(parsed.top, ['emoji:👍', 'custom:42'], 'each list is deduped and unsupported types drop');
assert.deepEqual(parsed.recent, ['emoji:🔥']);
assert.deepEqual(parsed.popular, ['emoji:🎉']);
assert.equal(parsed.allowCustomEmoji, true);
assert.equal(parsed.areTags, false);

const wrongType = messageDto.parseAvailableReactions(td({ '@type': 'error', code: 400 }));
assert.deepEqual(wrongType.top, [], 'an error object parses as an empty snapshot');
assert.deepEqual(wrongType.recent, []);

// Merge model ------------------------------------------------------------

const chat = (keys, all, maxCount) => {
  const value = new state.Chat();
  value.availableReactionKeys = keys;
  value.availableReactionsAll = all;
  value.maxReactionCount = maxCount;
  return value;
};

assert.deepEqual(state.pickerReactionKeys(undefined, ['emoji:👍'], ['emoji:🔥'], ['emoji:🎉']),
  ['emoji:👍', 'emoji:🔥', 'emoji:🎉'], 'top, then recent, then popular');
assert.deepEqual(state.pickerReactionKeys(undefined, ['emoji:👍'], ['emoji:👍', 'emoji:🔥'], []),
  ['emoji:👍', 'emoji:🔥'], 'lists are deduplicated across buckets');
assert.deepEqual(state.pickerReactionKeys(undefined, [], [], []),
  state.DEFAULT_QUICK_REACTION_KEYS, 'an empty answer falls back to the chat-level default row');
assert.deepEqual(state.pickerReactionKeys(chat(['emoji:🔥'], false, 1), [], [], []), ['emoji:🔥'],
  'the fallback uses the chat list when the chat is not "all"');
const many = [];
for (let index = 0; index < 20; index++) {
  many.push('emoji:e' + index);
}
assert.equal(state.pickerReactionKeys(undefined, many, [], []).length,
  state.MAX_PICKER_REACTION_KEYS, 'the merged row is capped');

// Wiring -----------------------------------------------------------------

const coordinator = fs.readFileSync(path.join(etsRoot, 'ui/pages/chat/ChatMessagePopupCoordinator.ets'), 'utf8');
assert.match(coordinator, /export function chatLevelPickerKeys\(/);
assert.match(coordinator, /export function refreshPickerReactionKeys\(/);
assert.match(coordinator, /host\.messageActionsReactionKeys = chatLevelPickerKeys\(host\)/,
  'opening the popup seeds the chat-level row synchronously');
assert.match(coordinator, /refreshPickerReactionKeys\(host, entry\.message\.messageId, host\.messageActionsGeneration\)/,
  'opening the popup also requests the per-message list');
assert.match(coordinator, /generation !== host\.messageActionsGeneration/, 'a stale answer is fenced');
assert.match(coordinator, /host\.getLifecycleToken\(\) !== lifecycle/, 'a stale page is fenced');
assert.match(coordinator, /!chatAllowsReactions\(chat\)/, 'a forbidden chat cannot gain reactions');
assert.match(coordinator, /host\.messageActionsReactionKeys = \[\];/, 'closing the popup clears the row');

const serializerSource = fs.readFileSync(
  path.join(etsRoot, 'infra/td/serialization/CommandSerializer.ets'), 'utf8');
assert.match(serializerSource,
  /COMMAND_SERIALIZATION_HANDLERS\.set\('getMessageAvailableReactions', serializeGetMessageAvailableReactions\)/);

const usecase = fs.readFileSync(
  path.join(etsRoot, 'domain/usecases/getMessageAvailableReactions.ets'), 'utf8');
assert.match(usecase, /catch \(error\)/, 'the use case never breaks opening the menu');
assert.match(usecase, /return empty;/, 'a failure degrades to the chat-level row');

console.log('PASS reaction picker data contracts');
