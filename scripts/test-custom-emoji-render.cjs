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

  // Path cache and prefetch producer ---------------------------------------------------------------
  const fileUri = { getUriFromPath: (p) => 'file://' + p };
  const Cache = load('domain/usecases/customEmojiPathCache.ets',
    ['customEmojiPathCache', 'CustomEmojiPathCacheStore'], { fileUri });
  const cache = new Cache.CustomEmojiPathCacheStore();
  cache.setPath('7', '/data/emoji.tgs');
  assert.equal(cache.getPath('7'), 'file:///data/emoji.tgs', 'a plain path becomes a file URI');
  cache.setPath('8', 'file:///data/already.webp');
  assert.equal(cache.getPath('8'), 'file:///data/already.webp', 'an existing URI is kept');
  cache.setPath('0', '/x');
  cache.setPath('9', '');
  assert.equal(cache.hasPath('0'), false);
  assert.equal(cache.hasPath('9'), false);
  assert.equal(cache.size(), 2);
  cache.clear();
  assert.equal(cache.size(), 0);
  assert.ok(Cache.customEmojiPathCache, 'the cache is a process singleton');

  const hilogStub = { info() {}, warn() {}, error() {} };
  const Td = load('models/td/common/index.ets', ['TdObject']).TdObject;
  const Cmds = load('core/model/AppCommand.ets',
    ['createGetCustomEmojiStickersCommand', 'createDownloadFileCommand', 'AppCommand']);
  const Err = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const ResolverMod = load('domain/usecases/customEmojiResolver.ets',
    ['CustomEmojiResolverUseCase', 'createCustomEmojiResolverUseCase', 'parseCustomEmojiSticker',
      'isValidCustomEmojiId', 'CustomEmojiSticker'], { ...Cmds, ...Err, TdObject: Td, hilog: hilogStub });
  const Prefetch = load('domain/usecases/customEmojiPrefetch.ets',
    ['CustomEmojiPrefetchCoordinator', 'collectPendingCustomEmojiIds', 'CUSTOM_EMOJI_PREFETCH_LIMIT'],
    { ...Cmds, ...Err, TdObject: Td, hilog: hilogStub, fileUri,
      customEmojiPathCache: Cache.customEmojiPathCache,
      CustomEmojiResolverUseCase: ResolverMod.CustomEmojiResolverUseCase,
      createCustomEmojiResolverUseCase: ResolverMod.createCustomEmojiResolverUseCase });

  const entity = (id) => {
    const item = new A.TextEntity();
    item.type = 'customEmoji';
    item.customEmojiId = id;
    return item;
  };
  Cache.customEmojiPathCache.setPath('99', '/cached');
  const pending = Prefetch.collectPendingCustomEmojiIds([
    [entity('5'), entity('5'), entity('0')],
    [(() => { const e = new A.TextEntity(); e.type = 'bold'; return e; })(), entity('6'), entity('99')]
  ]);
  assert.deepEqual(pending, ['5', '6'], 'ids are deduped, filtered and skip already cached ones');

  const manyEntities = [];
  for (let index = 1; index <= Prefetch.CUSTOM_EMOJI_PREFETCH_LIMIT + 5; index += 1) {
    manyEntities.push(entity(String(index)));
  }
  Cache.customEmojiPathCache.clear();
  assert.equal(Prefetch.collectPendingCustomEmojiIds([manyEntities]).length, Prefetch.CUSTOM_EMOJI_PREFETCH_LIMIT);

  const sticker = (id, path) => ({
    '@type': 'sticker',
    format: { '@type': 'stickerFormatTgs' },
    full_type: { '@type': 'stickerFullTypeCustomEmoji', custom_emoji_id: id },
    sticker: { '@type': 'file', id: 11,
      local: { '@type': 'localFile', is_downloading_completed: path.length > 0, path } },
    thumbnail: { '@type': 'thumbnail', file: { '@type': 'file', id: 12,
      local: { '@type': 'localFile', is_downloading_completed: false, path: '' } } }
  });
  const gatewayCalls = [];
  const coordinator = new Prefetch.CustomEmojiPrefetchCoordinator({
    send: (command) => {
      gatewayCalls.push(command);
      if (command.type === 'getCustomEmojiStickers') {
        return Promise.resolve(Td.fromJSON(JSON.stringify({ '@type': 'stickers',
          stickers: command.payload.customEmojiIds.map((id) => sticker(id, '/data/' + id + '.tgs')) })));
      }
      return Promise.resolve(Td.fromJSON('{"@type":"ok"}'));
    }
  });
  const filled = await coordinator.prefetch([[entity('21'), entity('22')]]);
  assert.equal(filled, 2);
  assert.equal(Cache.customEmojiPathCache.getPath('21'), 'file:///data/21.tgs');
  assert.equal(Cache.customEmojiPathCache.getPath('22'), 'file:///data/22.tgs');

  // A second pass with everything resolved costs no request.
  const before = gatewayCalls.length;
  assert.equal(await coordinator.prefetch([[entity('21'), entity('22')]]), 0);
  assert.equal(gatewayCalls.length, before, 'cached ids are not requested again');

  // Failure leaves the ids retryable.
  const failingCoordinator = new Prefetch.CustomEmojiPrefetchCoordinator({ send: () => Promise.reject(new Error('offline')) });
  assert.equal(await failingCoordinator.prefetch([[entity('31')]]), 0);
  assert.equal(Cache.customEmojiPathCache.hasPath('31'), false);

  // The pure row builder reads the cache.
  const voSource = read('ui/pages/chat/ChatTimelineVO.ets');
  assert.match(voSource, /import \{ customEmojiPathCache \} from '\.\.\/\.\.\/\.\.\/domain\/usecases\/customEmojiPathCache';/);
  assert.match(voSource, /const emojiPath = customEmojiPathCache\.getPath\(entity\.customEmojiId\);/);
  assert.match(voSource, /row\.customEmojiPaths\.set\(entity\.customEmojiId, emojiPath\);/);
  assert.match(voSource, /if \(entity\.type !== 'customEmoji' \|\| entity\.customEmojiId === '0'\) \{/);

  // Page-level producer: row entities → prefetch → one rebuild -----------------------------------
  const transaction = read('ui/pages/chat/ChatTimelineTransactionCoordinator.ets');
  assert.match(transaction, /import \{ prefetchMessageCustomEmoji \} from '\.\/ChatMessageCustomEmojiCoordinator';/);
  assert.match(transaction, /host\.dataSource\.applyDiff\(result\.entries\);\n\s+\/\/ D16: resolve custom emoji files/);
  assert.match(transaction, /prefetchMessageCustomEmoji\(host\.activeChatId, result\.entries, \(\): void => \{/);
  assert.match(transaction, /rebuildTimeline\(host, nativeState\);/, 'the resolved files trigger one rebuild');

  const coordinatorSource = read('ui/pages/chat/ChatMessageCustomEmojiCoordinator.ets');
  assert.match(coordinatorSource, /export function collectRowCustomEmojiEntities\(entries: ChatTimelineEntryVO\[\]\): TextEntity\[\]\[\]/);
  assert.match(coordinatorSource, /if \(entry\.kind !== 'message'\) \{/);
  assert.match(coordinatorSource, /entry\.message\.captionEntities\.length > 0/);
  assert.match(coordinatorSource, /if \(emojiState\.inFlight \|\| emojiState\.resolvedChatIds\.has\(chatId\)\) \{/,
    'one pass per chat visit');
  assert.match(coordinatorSource, /if \(emojiState\.chatId !== chatId\) \{/, 'a chat switch resets the pass');
  assert.match(coordinatorSource, /emojiState\.resolvedChatIds\.add\(chatId\);\n\s+rebuild\(\);/,
    'the rebuild runs after the pass is recorded');
  assert.match(coordinatorSource, /export function invalidateMessageCustomEmoji\(chatId: number\): void \{/);

  // The render key includes resolved paths, so the rebuild reaches the list.
  const voKeySource = read('ui/pages/chat/ChatTimelineVO.ets');
  assert.match(voKeySource, /function customEmojiRenderStamp\(row: ChatMessageRowVO\): number \{/);
  assert.match(voKeySource, /if \(row\.customEmojiPaths\.size === 0\) \{\n\s+return 0;/);
  assert.match(voKeySource, /entry\.key = entry\.key \+ '_e' \+ customEmojiRenderStamp\(row\)\.toString\(\);/);
  assert.match(voKeySource, /const ids: string\[\] = Array\.from\(row\.customEmojiPaths\.keys\(\)\)\.sort\(\);/,
    'the stamp is deterministic');

  console.log('PASS custom emoji rendering contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
