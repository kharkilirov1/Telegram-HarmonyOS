// D16: custom emoji resolver — request/response wire, id validation, caching, batching, download request
// and the failure paths. The text bubble consumes the returned map.

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
  const hilog = { info() {}, warn() {}, error() {}, debug() {} };
  const { TdObject } = load('models/td/common/index.ets', ['TdObject']);
  const C = load('core/model/AppCommand.ets',
    ['createGetCustomEmojiStickersCommand', 'createDownloadFileCommand', 'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog, ...errors });
  const R = load('domain/usecases/customEmojiResolver.ets',
    ['CustomEmojiResolverUseCase', 'createCustomEmojiResolverUseCase', 'parseCustomEmojiSticker',
      'isValidCustomEmojiId', 'CustomEmojiSticker', 'CUSTOM_EMOJI_MAX_IDS_PER_REQUEST',
      'CUSTOM_EMOJI_CACHE_LIMIT'], { ...C, ...errors, TdObject, hilog });

  // Wire ------------------------------------------------------------------------------------------
  const wire = serializer.buildTdlibRequestJson('getCustomEmojiStickers',
    serializer.serializeCommand(C.createGetCustomEmojiStickersCommand(['5301234567890123456', '5300000000000000001'])).params);
  assert.ok(wire.includes('"@type":"getCustomEmojiStickers"'));
  assert.ok(wire.includes('"custom_emoji_ids":[5301234567890123456,5300000000000000001]'),
    'int64 ids stay numeric in the request');

  // Validation ------------------------------------------------------------------------------------
  assert.equal(R.isValidCustomEmojiId('5301234567890123456'), true);
  assert.equal(R.isValidCustomEmojiId('1'), true);
  assert.equal(R.isValidCustomEmojiId('0'), false);
  assert.equal(R.isValidCustomEmojiId(''), false);
  assert.equal(R.isValidCustomEmojiId('-1'), false);
  assert.equal(R.isValidCustomEmojiId('01'), false, 'no leading zeros');
  assert.equal(R.isValidCustomEmojiId('1.5'), false);
  assert.equal(R.isValidCustomEmojiId('abc'), false);
  assert.equal(R.isValidCustomEmojiId('1'.repeat(20)), false, 'longer than int64');

  const stickerJson = (options = {}) => ({
    '@type': 'sticker',
    id: '990',
    emoji: '🙂',
    format: { '@type': options.format ?? 'stickerFormatTgs' },
    full_type: { '@type': 'stickerFullTypeCustomEmoji',
      custom_emoji_id: options.customEmojiId ?? '5301234567890123456' },
    sticker: {
      '@type': 'file',
      id: options.fileId ?? 41,
      local: { '@type': 'localFile', is_downloading_completed: options.downloaded ?? false,
        path: options.path ?? '' }
    },
    thumbnail: { '@type': 'thumbnail', file: {
      '@type': 'file', id: options.thumbFileId ?? 42,
      local: { '@type': 'localFile', is_downloading_completed: options.thumbDownloaded ?? false,
        path: options.thumbPath ?? '' }
    } }
  });
  const stickersResponse = (stickers) => TdObject.fromJSON(JSON.stringify({ '@type': 'stickers', stickers }));

  // Parsing ---------------------------------------------------------------------------------------
  const parsed = R.parseCustomEmojiSticker(TdObject.fromJSON(JSON.stringify(stickerJson(
    { downloaded: true, path: '/data/emoji.tgs', thumbDownloaded: true, thumbPath: '/data/emoji.webp' }))),
    '5301234567890123456');
  assert.equal(parsed.customEmojiId, '5301234567890123456');
  assert.equal(parsed.fileId, 41);
  assert.equal(parsed.localPath, '/data/emoji.tgs');
  assert.equal(parsed.thumbnailFileId, 42);
  assert.equal(parsed.thumbnailPath, '/data/emoji.webp');
  assert.equal(parsed.isAnimated, true);
  assert.equal(parsed.isVideo, false);
  const webm = R.parseCustomEmojiSticker(TdObject.fromJSON(JSON.stringify(stickerJson(
    { format: 'stickerFormatWebm' }))), '1');
  assert.equal(webm.isVideo, true);
  assert.equal(webm.isAnimated, false);
  assert.equal(webm.localPath, '', 'a missing local file has no path');

  // Resolve: batching, caching, download request --------------------------------------------------
  const calls = [];
  const resolver = new R.CustomEmojiResolverUseCase({
    send: (command) => {
      calls.push(command);
      if (command.type === 'getCustomEmojiStickers') {
        return Promise.resolve(stickersResponse([
          stickerJson({ customEmojiId: command.payload.customEmojiIds[0], downloaded: true, path: '/e.tgs' })
        ]));
      }
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
  });
  const first = await resolver.resolve(['5301234567890123456', '5301234567890123456', 'abc']);
  const request = calls.filter((call) => call.type === 'getCustomEmojiStickers');
  assert.equal(request.length, 1);
  assert.deepEqual(request[0].payload.customEmojiIds, ['5301234567890123456'], 'duplicates and bad ids are dropped');
  assert.equal(first.get('5301234567890123456').localPath, '/e.tgs');
  assert.equal(calls.some((call) => call.type === 'downloadFile'), false, 'an on-disk file needs no download');

  const cachedCalls = calls.length;
  const second = await resolver.resolve(['5301234567890123456']);
  assert.equal(calls.length, cachedCalls, 'a cached id costs no request');
  assert.equal(second.get('5301234567890123456').localPath, '/e.tgs');

  // Missing file → one download request; the entry stays cached with downloadRequested.
  const downloadCalls = [];
  const pendingResolver = new R.CustomEmojiResolverUseCase({
    send: (command) => {
      downloadCalls.push(command);
      if (command.type === 'getCustomEmojiStickers') {
        return Promise.resolve(stickersResponse([stickerJson({ customEmojiId: '7' })]));
      }
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
  });
  await pendingResolver.resolve(['7']);
  assert.equal(downloadCalls.filter((call) => call.type === 'downloadFile').length, 1);
  assert.equal(pendingResolver.peek('7').downloadRequested, true);
  pendingResolver.invalidate('7');
  assert.equal(pendingResolver.peek('7'), undefined, 'a file update re-reads the metadata');

  // Batch cap: at most CUSTOM_EMOJI_MAX_IDS_PER_REQUEST ids per call.
  const capCalls = [];
  const capResolver = new R.CustomEmojiResolverUseCase({
    send: (command) => {
      capCalls.push(command);
      return Promise.resolve(stickersResponse([]));
    }
  });
  const many = [];
  for (let index = 1; index <= R.CUSTOM_EMOJI_MAX_IDS_PER_REQUEST + 5; index += 1) {
    many.push(String(index));
  }
  await capResolver.resolve(many);
  assert.equal(capCalls[0].payload.customEmojiIds.length, R.CUSTOM_EMOJI_MAX_IDS_PER_REQUEST);

  // Failures: a rejected request leaves the id retryable, an unknown shape caches nothing.
  const failing = new R.CustomEmojiResolverUseCase({ send: () => Promise.reject(new Error('offline')) });
  const failed = await failing.resolve(['5']);
  assert.equal(failed.size, 0);
  assert.equal(failing.isPending('5'), false);
  const wrongShape = new R.CustomEmojiResolverUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) });
  assert.equal((await wrongShape.resolve(['5'])).size, 0);
  const emptyResponse = new R.CustomEmojiResolverUseCase({ send: () => Promise.resolve(stickersResponse([])) });
  assert.equal((await emptyResponse.resolve(['5'])).size, 0, 'an omitted id is not cached');

  // Cache eviction stays bounded.
  const evictResolver = new R.CustomEmojiResolverUseCase({
    send: (command) => Promise.resolve(command.type === 'getCustomEmojiStickers'
      ? TdObject.fromJSON(JSON.stringify({ '@type': 'stickers', stickers: command.payload.customEmojiIds
        .map((id) => stickerJson({ customEmojiId: id, downloaded: true, path: '/x' })) }))
      : TdObject.fromJSON('{"@type":"ok"}'))
  });
  const ids = [];
  for (let index = 1; index <= R.CUSTOM_EMOJI_CACHE_LIMIT + 10; index += 1) {
    ids.push(String(index));
  }
  for (let offset = 0; offset < ids.length; offset += R.CUSTOM_EMOJI_MAX_IDS_PER_REQUEST) {
    await evictResolver.resolve(ids.slice(offset, offset + R.CUSTOM_EMOJI_MAX_IDS_PER_REQUEST));
  }
  let cached = 0;
  for (const id of ids) {
    if (evictResolver.peek(id) !== undefined) {
      cached += 1;
    }
  }
  assert.ok(cached <= R.CUSTOM_EMOJI_CACHE_LIMIT, 'the cache stays bounded');

  const commandSource = read('core/model/AppCommand.ets');
  assert.ok(commandSource.includes('GetCustomEmojiStickersCommand'));
  const serializerSource = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializerSource, /COMMAND_SERIALIZATION_HANDLERS\.set\('getCustomEmojiStickers'/);
  assert.match(serializerSource, /_custom_emoji_ids_json/);

  console.log('PASS custom emoji resolver contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
