// S3c contract: one setMessageReactions command per tap, optimistic snapshot before the command and
// the previous chips restored on failure. Pure toggle behaviour is exercised on the real AppState
// helpers; the serializer is exercised on the real ETS module, not a copy.
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
const state = load('core/model/AppState.ets');
const hilog = { info() {}, warn() {}, error() {}, debug() {} };
const serializer = load('infra/td/serialization/CommandSerializer.ets', {
  ...commands,
  TdObject: tdCommon.TdObject,
  ...accessors,
  hilog
});

function requestFor(command) {
  const serialized = serializer.serializeCommand(command);
  const body = serializer.buildTdlibRequestJson(serialized.method, serialized.params);
  return { serialized, body: JSON.parse(body) };
}

// Command shape ----------------------------------------------------------

const emoji = requestFor(commands.createSetMessageReactionsCommand(42, '777', ['emoji:👍']));
assert.equal(emoji.serialized.method, 'setMessageReactions');
assert.equal(emoji.body['@type'], 'setMessageReactions');
assert.equal(emoji.body.chat_id, 42);
assert.equal(emoji.body.message_id, '777', 'int64 stays a decimal string');
assert.equal(emoji.body.is_big, false, 'paid/big reactions are out of scope');
assert.deepEqual(emoji.body.reaction_types, [
  { '@type': 'reactionTypeEmoji', emoji: '👍' }
]);

const custom = requestFor(commands.createSetMessageReactionsCommand(7, '9', ['custom:5566']));
assert.deepEqual(custom.body.reaction_types, [
  { '@type': 'reactionTypeCustomEmoji', custom_emoji_id: '5566' }
]);

const cleared = requestFor(commands.createSetMessageReactionsCommand(7, '9', []));
assert.deepEqual(cleared.body.reaction_types, [], 'an empty list removes the account reactions');

const both = requestFor(commands.createSetMessageReactionsCommand(1, '2',
  ['emoji:🔥', 'custom:42']));
assert.deepEqual(both.body.reaction_types.map((type) => type['@type']),
  ['reactionTypeEmoji', 'reactionTypeCustomEmoji']);

assert.throws(() => requestFor(commands.createSetMessageReactionsCommand(1, '2', ['custom:abc'])),
  /Invalid custom reaction id/, 'a non-numeric custom emoji id must not reach TDLib');
assert.throws(() => requestFor(commands.createSetMessageReactionsCommand(1, '2', ['nonsense'])),
  /Unsupported reaction key/);
assert.throws(() => requestFor(commands.createSetMessageReactionsCommand(1, '2', ['emoji:'])),
  /Invalid reaction emoji key/);

// Optimistic toggle ------------------------------------------------------

const chip = (key, count, chosen) => {
  const value = state.reactionChipFromKey(key);
  value.count = count;
  value.chosen = chosen;
  return value;
};

const base = [chip('emoji:👍', 3, false), chip('emoji:🔥', 1, false)];
const added = state.toggleReactionChips(base, 'emoji:👍');
assert.equal(added[0].count, 4);
assert.equal(added[0].chosen, true, 'my tap marks the chip chosen');
assert.equal(base[0].count, 3, 'toggle is mutation free');

const removed = state.toggleReactionChips(added, 'emoji:👍');
assert.equal(removed[0].count, 3);
assert.equal(removed[0].chosen, false);

const single = state.toggleReactionChips([chip('emoji:👍', 1, true)], 'emoji:👍');
assert.equal(single.length, 0, 'removing the last reaction drops the chip');

const created = state.toggleReactionChips(base, 'emoji:🎉');
assert.equal(created[2].key, 'emoji:🎉');
assert.equal(created[2].count, 1);
assert.equal(created[2].chosen, true);

assert.deepEqual(state.chosenReactionKeys([chip('emoji:👍', 1, true), chip('emoji:🔥', 2, false)]),
  ['emoji:👍']);

// Controller contract ----------------------------------------------------

const controller = fs.readFileSync(path.join(etsRoot, 'ui/pages/chat/ChatReactionController.ets'), 'utf8');
const dispatchAt = controller.indexOf('dispatchSnapshot(store, chatId, messageId, after);');
const sendAt = controller.indexOf('createSetMessageReactionsUseCase(gateway).set(');
assert.ok(dispatchAt > 0 && sendAt > dispatchAt, 'the optimistic snapshot is written before the send');
assert.match(controller, /\.catch\(\(error: Error\) => \{[\s\S]*dispatchSnapshot\(store, chatId, messageId, before\)/,
  'a failed command restores the previous chips');
assert.match(controller, /token !== host\.getLifecycleToken\(\)/, 'a stale page never rolls back a newer chat');
assert.match(controller, /this\.inFlight\.has\(requestKey\)/, 'a fast double tap is collapsed');
assert.match(controller, /this\.inFlight\.delete\(requestKey\)/, 'the guard is released on both outcomes');
assert.match(controller, /chosenReactionKeys\(after\)/, 'only chosen chips are sent to TDLib');

console.log('PASS reactions send contracts');
