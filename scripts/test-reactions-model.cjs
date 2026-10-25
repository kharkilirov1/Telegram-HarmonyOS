// Reaction data path: TDLib shapes → primitive snapshot → chips → sorted/packed row. Pure functions
// only; the bubble footer (S3b) renders whatever this returns, so the contract is pinned here.
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
const state = load('core/model/AppState.ets');
const dto = load('core/model/dto/MessageDto.ets', { ...tdCommon, ...accessors });
const td = (json) => tdCommon.TdObject.fromJSON(JSON.stringify(json));

const reaction = (type, count, chosen) => ({
  '@type': 'messageReaction',
  type,
  total_count: count,
  is_chosen: chosen
});

const snapshot = (reactor) => td({
  '@type': 'messageReactions',
  reactions: reactor,
  are_tags: false
});

// Parsing ---------------------------------------------------------------

assert.equal(dto.parseReactionTypeKey(td({ '@type': 'reactionTypeEmoji', emoji: '👍' })), 'emoji:👍');
assert.equal(dto.parseReactionTypeKey(td({ '@type': 'reactionTypeCustomEmoji', custom_emoji_id: '5566' })),
  'custom:5566');
assert.equal(dto.parseReactionTypeKey(td({ '@type': 'reactionTypePaid' })), '',
  'unsupported reaction types are dropped');
assert.equal(dto.parseReactionTypeKey(td({ '@type': 'reactionTypeEmoji', emoji: '' })), '',
  'an empty emoji is not a chip');

const parsed = dto.parseReactionSnapshot(snapshot([
  reaction({ '@type': 'reactionTypeEmoji', emoji: '👍' }, 5, false),
  reaction({ '@type': 'reactionTypeCustomEmoji', custom_emoji_id: '42' }, 2, true),
  reaction({ '@type': 'reactionTypePaid' }, 4, false),
  reaction({ '@type': 'reactionTypeEmoji', emoji: '🔥' }, 0, false)
]));
assert.deepEqual(parsed.keys, ['emoji:👍', 'custom:42']);
assert.deepEqual(parsed.counts, [5, 2]);
assert.deepEqual(parsed.chosen, [false, true]);
assert.deepEqual(dto.parseReactionSnapshot(td({ '@type': 'messageReactions', reactions: [] })).keys, []);

assert.deepEqual(dto.parseReactionTypeKeys([
  td({ '@type': 'reactionTypeEmoji', emoji: '👍' }),
  td({ '@type': 'reactionTypeEmoji', emoji: '👍' }),
  td({ '@type': 'reactionTypeCustomEmoji', custom_emoji_id: '7' }),
  td({ '@type': 'reactionTypePaid' })
]), ['emoji:👍', 'custom:7'], 'delta keys are unique and typed');

// Chips -----------------------------------------------------------------

const built = state.buildReactionChips(['emoji:👍', 'custom:42', 'emoji:🔥'], [3, 1, 0], [false, true, false]);
assert.deepEqual(built.map((chip) => chip.key), ['emoji:👍', 'custom:42'],
  'zero-count chips are dropped');
assert.equal(built[1].isCustom(), true);
assert.equal(built[1].chosen, true);

// Sorting ---------------------------------------------------------------

const chip = (key, count, chosen) => {
  const value = state.reactionChipFromKey(key);
  value.count = count;
  value.chosen = chosen;
  return value;
};
const sorted = state.sortReactionChips([
  chip('emoji:😁', 1, false),
  chip('emoji:👍', 9, false),
  chip('custom:42', 2, true),
  chip('emoji:🔥', 9, false)
]);
assert.deepEqual(sorted.map((item) => item.key), ['custom:42', 'emoji:👍', 'emoji:🔥', 'emoji:😁'],
  'chosen first, then count desc, then deterministic code-unit key order');

// Packing ---------------------------------------------------------------

const many = [];
for (let index = 1; index <= 8; index++) {
  many.push(chip(`emoji:e${index}`, 8 - index, false));
}
const packed = state.packReactionChips(many);
assert.equal(packed.visible.length, state.MAX_VISIBLE_REACTION_CHIPS);
assert.equal(packed.visible.length, 6);
assert.equal(packed.hidden, 2, 'hidden counts chips, not reactions');
assert.equal(packed.total, 8);
assert.equal(state.packReactionChips(many.slice(0, 2)).hidden, 0);
assert.equal(state.packReactionChips([]).visible.length, 0);

// Incremental delta -----------------------------------------------------

const base = [chip('emoji:👍', 3, false), chip('emoji:🔥', 1, false)];

const someoneAdded = state.applyReactionDelta(base, false, [], ['emoji:👍', 'emoji:🎉']);
assert.equal(someoneAdded[0].count, 4);
assert.equal(someoneAdded[0].chosen, false, 'another actor must not mark the chip chosen');
assert.equal(someoneAdded[2].key, 'emoji:🎉');
assert.equal(someoneAdded[2].count, 1);
assert.equal(base[0].count, 3, 'delta is mutation free');

const meAdded = state.applyReactionDelta(base, true, [], ['emoji:👍']);
assert.equal(meAdded[0].count, 4);
assert.equal(meAdded[0].chosen, true);

const meRemoved = state.applyReactionDelta([chip('emoji:👍', 1, true)], true, ['emoji:👍'], []);
assert.equal(meRemoved.length, 0, 'a chip drops when the last reaction leaves');

const meSwitched = state.applyReactionDelta(base, true, ['emoji:🔥'], ['emoji:👍']);
assert.equal(meSwitched.length, 1);
assert.equal(meSwitched[0].key, 'emoji:👍');
assert.equal(meSwitched[0].count, 4);
assert.equal(meSwitched[0].chosen, true);

const unknownRemoval = state.applyReactionDelta(base, false, ['emoji:🎉'], []);
assert.deepEqual(unknownRemoval.map((item) => item.count), [3, 1], 'unknown removals are ignored');

// Wiring ---------------------------------------------------------------

const read = (file) => fs.readFileSync(path.join(etsRoot, file), 'utf8');
const normalizer = read('core/events/normalizers/MessageNormalizer.ets');
assert.match(normalizer, /handlers\.set\('updateMessageReactions', handleMessageReactions\)/,
  'full reaction snapshots must reach the store');
assert.match(normalizer, /handlers\.set\('updateMessageReaction', handleMessageReactionChanged\)/,
  'incremental reaction updates must reach the store');
assert.match(read('core/model/AppState.ets'), /reactions: ReactionChipData\[\] = \[\];/,
  'messages must carry reaction chips');
const reducer = read('core/reducers/messagesReducer.ets');
assert.match(reducer, /case 'messageReactionsUpdated'/);
assert.match(reducer, /case 'messageReactionChanged'/);
assert.match(reducer, /applyReactionDelta\(/, 'the reducer must reuse the shared delta function');
const timeline = read('ui/pages/chat/ChatTimelineVO.ets');
assert.match(timeline, /packReactionChips\(message\.reactions\)/, 'the VO packs the row once');
assert.match(timeline, /reactionRenderStamp\(row\)/, 'the LazyForEach key must change when chips change');

console.log('PASS reaction model contracts');
