// S3b.1 contract: media bubbles show the reactions row BELOW the bubble, and the row is owned by the
// router (one place) rather than duplicated inside every media atom. The text bubble keeps its own
// inline placement from S3b, so the router must not add a second row for text messages.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const etsRoot = path.join(root, 'entry/src/main/ets');
const read = (file) => fs.readFileSync(path.join(etsRoot, file), 'utf8');

const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');
assert.match(router, /import \{ TgReactionsFooter \} from '\.\.\/atoms\/TgReactionsFooter';/);
assert.match(router, /private buildReactionsRow\(\)/);

const builderStart = router.indexOf('private buildReactionsRow()');
const builderEnd = router.indexOf('@Builder', builderStart);
const builder = router.slice(builderStart, builderEnd > 0 ? builderEnd : router.length);

for (const param of ['emojis', 'keys', 'counts', 'chosenFlags', 'hiddenCount']) {
  assert.ok(builder.includes(`${param}: this.reaction`), `footer must receive ${param}`);
}
assert.ok(builder.includes('onReactionPress: (key: string)'), 'footer owns the tap callback');
assert.ok(builder.includes('this.onReactionPress(key)'), 'a media pill reports the tap upward');

const callSites = [...router.matchAll(/this\.buildReactionsRow\(\)/g)].length;
assert.ok(callSites >= 6, `every media branch needs the row: found ${callSites} call sites`);

// Text bubble renders its own footer inside the bubble (S3b) — the router must not duplicate it.
const textStart = router.indexOf('} else if (this.isTextLike())');
const textBranch = router.slice(textStart, router.indexOf('} else if (this.contentType ===', textStart));
assert.ok(!textBranch.includes('buildReactionsRow'), 'the text branch keeps its inline footer');

// The row lives outside the media container: the balloon atom keeps no reaction wiring.
const shell = read('ui/tg_ui/atoms/TgMediaBubbleShellV2.ets');
assert.ok(!shell.includes('TgReactionsFooter') && !shell.includes('reactionEmojis'),
  'TgMediaBubbleShellV2 stays free of reaction wiring');

// Visual media is wrapped so the row sits under the media bubble, aligned to the bubble side.
assert.match(router, /Column\(\) \{\s*this\.buildVisualMediaBubbleShell\(\)\s*this\.buildReactionsRow\(\)\s*\}/);

console.log('PASS reaction media footer contracts');
