// D16: custom emoji rendering chain — the rich-span splitter marks the emoji span, the body draws an
// ImageSpan when a resolved file exists and keeps the glyph otherwise, and the row/router/bubble carry the
// path map from the timeline row.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

function load(relative, names, deps = {}) {
  const source = read(relative)
    .replace(/^import\s[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}

async function main() {
  const A = load('core/model/AppState.ets', ['TextEntity']);
  // The splitter lives inside the component file; import it through a stubbed decorator environment.
  const bodySource = read('ui/tg_ui/atoms/TgTextBodyV3.ets');
  const splitterSource = bodySource.substring(
    bodySource.indexOf('class RichSpan'),
    bodySource.indexOf('/** A text body segment'));
  const split = new Function(`${stripTypeScriptTypes(splitterSource, { mode: 'transform' })}
    return { splitRichSpans, RichSpan };`)();

  const emojiEntity = () => {
    const entity = new A.TextEntity();
    entity.offset = 0;
    entity.length = 2;
    entity.type = 'customEmoji';
    entity.customEmojiId = '5301234567890123456';
    return entity;
  };

  // Splitter --------------------------------------------------------------------------------------
  const spans = split.splitRichSpans('🙂ab', 0, [emojiEntity()]);
  assert.equal(spans.length, 2);
  assert.equal(spans[0].text, '🙂');
  assert.equal(spans[0].customEmojiId, '5301234567890123456', 'the emoji span carries its id');
  assert.equal(spans[0].isLink, false, 'a custom emoji is not a link');
  assert.equal(spans[1].text, 'ab');
  assert.equal(spans[1].customEmojiId, '0', 'plain text keeps the empty id');

  const bold = new A.TextEntity();
  bold.offset = 0;
  bold.length = 2;
  bold.type = 'bold';
  assert.equal(split.splitRichSpans('🙂ab', 0, [bold])[0].customEmojiId, '0');
  assert.equal(split.splitRichSpans('plain', 0, [])[0].customEmojiId, '0');

  // A segment that starts mid-text still maps the entity offset correctly.
  const middle = split.splitRichSpans('🙂', 2, [(() => {
    const entity = emojiEntity();
    entity.offset = 2;
    return entity;
  })()]);
  assert.equal(middle.length, 1);
  assert.equal(middle[0].customEmojiId, '5301234567890123456');

  // Body renders an image only when a file exists ------------------------------------------------
  assert.match(bodySource, /@Param customEmojiPaths: Map<string, string> = new Map<string, string>\(\)/);
  assert.match(bodySource, /private customEmojiPath\(span: RichSpan\): string \{/);
  assert.match(bodySource, /if \(span\.customEmojiId === '0' \|\| span\.customEmojiId\.length === 0\) \{/);
  assert.match(bodySource, /const path = this\.customEmojiPaths\.get\(span\.customEmojiId\);/);
  assert.match(bodySource, /if \(this\.customEmojiPath\(span\)\.length > 0\) \{/);
  assert.match(bodySource, /ImageSpan\(this\.customEmojiPath\(span\)\)/);
  assert.match(bodySource, /\.width\(TgUiTokens\.MSG_CUSTOM_EMOJI_SIZE\)/);
  assert.match(bodySource, /\.height\(TgUiTokens\.MSG_CUSTOM_EMOJI_SIZE\)/);
  assert.match(bodySource, /\.verticalAlign\(ImageSpanAlignment\.CENTER\)/);
  assert.match(bodySource, /Span\(span\.text\)/, 'the glyph fallback is still rendered');

  const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
  assert.match(tokens, /MSG_CUSTOM_EMOJI_SIZE: number = 20;/);

  // Path map flows from the row to the body -------------------------------------------------------
  const vo = read('ui/pages/chat/ChatTimelineVO.ets');
  assert.match(vo, /customEmojiPaths: Map<string, string> = new Map<string, string>\(\);/);
  const row = read('ui/pages/chat/TgChatTimelineRow.ets');
  assert.match(row, /customEmojiPaths: this\.entry\.message\.customEmojiPaths,/);
  const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');
  assert.match(router, /@Param customEmojiPaths: Map<string, string>/);
  assert.match(router, /customEmojiPaths: this\.customEmojiPaths,/);
  const bubble = read('ui/tg_ui/atoms/TgTextBubbleV3.ets');
  assert.match(bubble, /@Param customEmojiPaths: Map<string, string>/);
  assert.match(bubble, /customEmojiPaths: this\.customEmojiPaths,/);

  console.log('PASS custom emoji rendering contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
