// S3d contract: the reaction row above message actions is fed by chat availability state and its tap
// reaches the S3c controller only after the menu closes. Behaviour of the model itself lives in
// test-reactions-availability.cjs; this file pins the surface and the wiring.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const etsRoot = path.join(root, 'entry/src/main/ets');
const read = (file) => fs.readFileSync(path.join(etsRoot, file), 'utf8');

const atom = read('ui/tg_ui/atoms/TgReactionPicker.ets');
assert.match(atom, /export struct TgReactionPicker/, 'picker atom must exist');
assert.match(atom, /@Param keys: string\[\]/, 'picker takes the available keys');
assert.match(atom, /@Event onReactionPress: \(key: string\)/, 'a pick reports the chip key');
assert.match(atom, /Scroll\(\)[\s\S]*scrollable\(ScrollDirection\.Horizontal\)/, 'the row scrolls');
assert.match(atom, /export function reactionPickerGlyph/, 'glyph mapping is a named contract');
assert.ok(!/\.width\(\d|\.height\(\d|\.fontSize\(\d/.test(atom),
  'no raw sizes in the atom — geometry comes from tokens');

const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
for (const token of ['REACTION_PICKER_HEIGHT', 'REACTION_PICKER_PILL_SIZE',
  'REACTION_PICKER_GLYPH_SIZE', 'REACTION_PICKER_PADDING_H']) {
  assert.ok(new RegExp(`static readonly ${token}:`).test(tokens), `token ${token} must exist`);
}

const popup = read('ui/pages/chat/TgChatMessageActionsPopup.ets');
assert.match(popup, /TgReactionPicker\(\{/, 'the actions popup renders the picker');
assert.match(popup, /keys: this\.bindings\.messageActionReactionKeys\(\)/,
  'the popup asks the session for the chat keys, not a hardcoded list');
assert.match(popup, /handleMessageActionReaction\(key\)/, 'a pick is routed through the popup port');

const ports = read('ui/pages/chat/ChatScreenViewPorts.ets');
const popupPort = ports.slice(ports.indexOf('export interface ChatMessageActionsPopupPort'),
  ports.indexOf('export interface ChatTimelineRowPort'));
assert.match(popupPort, /messageActionReactionKeys\(\): string\[\];/);
assert.match(popupPort, /handleMessageActionReaction\(key: string\): void;/);

const coordinator = read('ui/pages/chat/ChatMessagePopupCoordinator.ets');
assert.match(coordinator, /export function messageActionReactionKeys\(/);
assert.match(coordinator, /export function handleMessageActionReaction\(/);
assert.match(coordinator, /chatAllowsReactions\(chat\) \? availableReactionKeys\(chat\) : \[\]/,
  'an unavailable chat yields an empty picker');
const closeAt = coordinator.indexOf('host.closeMessageActions();', coordinator.indexOf('handleMessageActionReaction'));
const toggleAt = coordinator.indexOf('toggleMessageReaction(host, messageId, key);');
assert.ok(closeAt > 0 && toggleAt > closeAt,
  'the menu closes before the optimistic toggle so the footer update is visible');
assert.match(coordinator, /extends ChatMessageActionsHost, ChatReactionHost/,
  'the popup host owns the S3c controller contract');

const session = read('ui/pages/chat/ChatScreenSession.ets');
assert.match(session, /messageActionReactionKeys\(\): string\[\] \{ return delegateMessageActionReactionKeys\(this\); \}/);
assert.match(session, /handleMessageActionReaction\(key: string\): void \{ delegateHandleMessageActionReaction\(this, key\); \}/);

const bindings = read('ui/pages/chat/ChatScreenViewBindings.ets');
assert.match(bindings, /messageActionReactionKeys\(\): string\[\] \{ return this\.session\.messageActionReactionKeys\(\); \}/);

assert.ok(fs.existsSync(path.join(etsRoot, 'ui/tg_ui/spec/TgReactionPicker.md')), 'passport must exist');
assert.ok(fs.existsSync(path.join(etsRoot, 'ui/tg_ui/demos/TgReactionPickerDemo.ets')), 'demo must exist');

console.log('PASS reaction picker contracts');
