// S3b contract: the reaction footer renders what the timeline VO packed, from primitives, and stays
// out of the bubble when a message has no reactions. Source-level guards are enough here: the atom
// has no behaviour beyond layout, and the real geometry is verified by the build and smoke checks.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const etsRoot = path.join(root, 'entry/src/main/ets');
const read = (file) => fs.readFileSync(path.join(etsRoot, file), 'utf8');

const atom = read('ui/tg_ui/atoms/TgReactionsFooter.ets');
assert.match(atom, /export struct TgReactionsFooter/, 'atom must exist');
for (const param of ['emojis: string[]', 'keys: string[]', 'counts: number[]', 'chosenFlags: boolean[]', 'hiddenCount: number']) {
  assert.ok(atom.includes(param), `footer must take primitive ${param}`);
}
assert.match(atom, /@Event onReactionPress: \(key: string\)/, 'S3c tap reports the chip key');
assert.match(atom, /this.onReactionPress\(key\)/, 'a tap forwards the key, not an index');
assert.match(atom, /Flex\(\{ wrap: FlexWrap\.Wrap \}\)/, 'chips wrap inside narrow bubbles');
assert.match(atom, /'\s*\+\s*' \+ this\.hiddenCount\.toString\(\)/, '"+N" comes from the hidden count');
assert.match(atom, /REACTION_CHIP_BG_CHOSEN/, 'chosen chip uses the accent tint token');
assert.match(atom, /REACTION_CUSTOM_EMOJI_FALLBACK/, 'custom emoji falls back to the token glyph');
assert.ok(!/\.fontSize\(\d|\.height\(\d|\.borderRadius\(\d/.test(atom),
  'no raw sizes in the atom — every number comes from tokens');

const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
for (const token of ['REACTION_CHIP_HEIGHT', 'REACTION_CHIP_RADIUS', 'REACTION_CHIP_PADDING_H',
  'REACTION_CHIP_GAP', 'REACTION_CHIP_COUNT_SIZE', 'REACTION_FOOTER_TOP_GAP',
  'REACTION_CHIP_BG', 'REACTION_CHIP_BG_CHOSEN', 'REACTION_CHIP_TEXT', 'REACTION_CHIP_TEXT_CHOSEN']) {
  assert.ok(new RegExp(`static readonly ${token}:`).test(tokens), `token ${token} must exist`);
}
for (const variant of ['base', 'dark']) {
  const colors = JSON.parse(fs.readFileSync(path.join(root,
    `entry/src/main/resources/${variant}/element/color.json`), 'utf8'));
  const names = colors.color.map((entry) => entry.name);
  for (const name of ['reaction_chip_bg', 'reaction_chip_bg_chosen', 'reaction_chip_text',
    'reaction_chip_text_chosen']) {
    assert.ok(names.includes(name), `${variant} colors must define ${name}`);
  }
}

const timeline = read('ui/pages/chat/ChatTimelineVO.ets');
assert.match(timeline, /row\.reactionEmojis = row\.reactionChips\.map/, 'row VO projects glyphs');
assert.match(timeline, /reactionChosenFlags = row\.reactionChips\.map/, 'row VO projects chosen flags');
assert.match(timeline, /REACTION_CUSTOM_EMOJI_FALLBACK/, 'custom chips use the shared fallback glyph');

const bubble = read('ui/tg_ui/atoms/TgTextBubbleV3.ets');
assert.match(bubble, /reactionEmojis\.length > 0/, 'the footer is skipped when there are no reactions');
assert.match(bubble, /TgReactionsFooter\(\{/, 'the text bubble renders the footer');
const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');
for (const field of ['reactionEmojis', 'reactionCounts', 'reactionChosenFlags', 'reactionHiddenCount']) {
  assert.ok(router.includes(`${field}: this.${field}`), `router must forward ${field}`);
}
const row = read('ui/pages/chat/TgChatTimelineRow.ets');
for (const field of ['reactionEmojis', 'reactionCounts', 'reactionChosenFlags', 'reactionHiddenCount']) {
  assert.ok(row.includes(`${field}: this.entry.message.${field}`), `timeline row must forward ${field}`);
}

assert.ok(fs.existsSync(path.join(etsRoot, 'ui/tg_ui/spec/TgReactionsFooter.md')),
  'atom passport must exist');
assert.ok(fs.existsSync(path.join(etsRoot, 'ui/tg_ui/demos/TgReactionsFooterDemo.ets')),
  'atom demo must exist');

console.log('PASS reactions footer contracts');
