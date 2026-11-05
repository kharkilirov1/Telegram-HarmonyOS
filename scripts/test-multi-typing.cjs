// C2 remainder contract: several peers typing in one group chat.
// Executes the real per-chat sender set helper, the reducer branch and the top-bar formatter wiring.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

const state = load('core/model/AppState.ets', ['ChatTypingInfo', 'ChatActivitySender']);
const T = load('core/model/TypingActions.ets',
  ['applyTypingAction', 'activeSenders', 'formatTypingActors', 'typingSetIsPlainTyping',
    'TYPING_MAX_SENDERS'],
  state);

// One sender replaces itself instead of duplicating ------------------------------------------------
let info = T.applyTypingAction(undefined, 7, 'typing', 1000);
assert.ok(info);
assert.equal(info.senders.length, 1);
assert.equal(info.senderUserId, 7);
assert.equal(info.actionType, 'typing');
assert.equal(info.timestamp, 1000);

info = T.applyTypingAction(info, 7, 'typing', 2000);
assert.equal(info.senders.length, 1, 'the same peer refreshes one entry');
assert.equal(info.timestamp, 2000);

// A second and third sender are kept, newest first -----------------------------------------------
info = T.applyTypingAction(info, 9, 'recordingVoice', 3000);
assert.equal(info.senders.length, 2);
assert.equal(info.senders[0].userId, 9, 'newest sender first');
assert.equal(info.senders[1].userId, 7);
assert.equal(info.senderUserId, 9, 'legacy field mirrors the newest sender');
assert.equal(info.actionType, 'recordingVoice');
assert.equal(T.typingSetIsPlainTyping(info), false);

info = T.applyTypingAction(info, 11, 'typing', 4000);
assert.equal(info.senders.length, 3);
assert.equal(T.typingSetIsPlainTyping(info), false, 'one non-typing sender flips the mode');

// Cancelling one peer keeps the others; cancelling the last drops the entry ------------------------
info = T.applyTypingAction(info, 9, 'cancel', 5000);
assert.ok(info);
assert.equal(info.senders.length, 2);
assert.equal(info.senderUserId, 11);
assert.equal(T.typingSetIsPlainTyping(info), true);

info = T.applyTypingAction(info, 11, 'cancel', 6000);
info = T.applyTypingAction(info, 7, 'cancel', 7000);
assert.equal(info, undefined, 'the last cancel removes the chat entry');

// The set is bounded -------------------------------------------------------------------------------
let bounded = undefined;
for (let userId = 1; userId <= 8; userId += 1) {
  bounded = T.applyTypingAction(bounded, userId, 'typing', userId * 100);
}
assert.equal(bounded.senders.length, T.TYPING_MAX_SENDERS);
assert.equal(bounded.senderUserId, 8, 'the newest sender survives the cap');

// Legacy info objects (only scalar fields) still render as one sender.
const legacy = new state.ChatTypingInfo();
legacy.senderUserId = 5;
legacy.actionType = 'typing';
legacy.timestamp = 500;
assert.equal(T.activeSenders(legacy).length, 1, 'scalar-only info yields one sender');
assert.equal(T.activeSenders(legacy)[0].userId, 5);
assert.equal(T.typingSetIsPlainTyping(legacy), true);
const empty = new state.ChatTypingInfo();
assert.equal(T.activeSenders(empty).length, 0);

// Name formatting ----------------------------------------------------------------------------------
assert.equal(T.formatTypingActors([], 'and', 'others'), '');
assert.equal(T.formatTypingActors(['Ann'], 'and', 'others'), 'Ann');
assert.equal(T.formatTypingActors(['Ann', 'Bob'], 'and', 'others'), 'Ann and Bob');
assert.equal(T.formatTypingActors(['Ann', 'Bob', 'Cid'], 'and', 'others'), 'Ann and 2 others');
assert.equal(T.formatTypingActors(['', 'Bob', ''], 'and', 'others'), 'Bob', 'unknown names are skipped');

// Wiring: the reducer and the top bar both use the shared helper -----------------------------------
const reducer = read('core/reducers/chatsReducer.ets');
assert.match(reducer, /import \{ applyTypingAction \} from '\.\.\/model\/TypingActions';/);
assert.match(reducer, /const next = applyTypingAction\(current, event\.senderUserId, event\.actionType, event\.timestamp\);/);
assert.match(reducer, /newState\.chats\.typingActions\.delete\(event\.chatId\);/);

const presentation = read('ui/pages/chat/ChatTopBarPresentation.ets');
assert.match(presentation, /formatTypingActors\(actorNames,/);
assert.match(presentation, /typingSetIsPlainTyping\(typingInfo\)/);
assert.match(presentation, /typing_and/);
assert.match(presentation, /typing_others/);

const model = read('core/model/AppState.ets');
assert.match(model, /export class ChatActivitySender \{/);
assert.match(model, /senders: ChatActivitySender\[\] = \[\];/);

for (const locale of ['base', 'ru_RU', 'zh_CN']) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, '../resources', locale, 'element/string.json'), 'utf8'));
  for (const name of ['typing_and', 'typing_others']) {
    assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
  }
}

console.log('PASS multi typing contract');
