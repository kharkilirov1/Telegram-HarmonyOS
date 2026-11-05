// F6: sticker pack paging — pack parsing with sticker identities, clamped stepping, gallery items built
// from a pack and the viewer switching from chat media to the pack.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  const tdMod = load('models/td/common/index.ets', ['TdObject']);
  const Td = tdMod.TdObject;
  const hilog = { info() {}, warn() {}, error() {} };
  const Pack = load('domain/usecases/stickerPack.ets',
    ['StickerPackInfo', 'StickerPackSticker', 'parseStickerPack', 'parseStickerPackSticker',
      'nextStickerPackIndex', 'isValidStickerSetId'],
    { TdObject: Td, hilog, createGetStickerSetCommand: () => ({}), createChangeStickerSetCommand: () => ({}),
      AppError: class extends Error {}, AppErrorKind: { UNKNOWN: 'UNKNOWN' } });
  const Items = load('ui/pages/chat/StickerPackGalleryItems.ets',
    ['buildStickerPackGalleryItems', 'stickerPackStartIndex', 'stepStickerPackIndex',
      'stickerPackPreloadPlan', 'stickerPackPreloadFileIds', 'StickerPackPreloadPlan'],
    { MediaGalleryItem: load('models/MediaGalleryItem.ets', ['MediaGalleryItem']).MediaGalleryItem,
      StickerPackInfo: Pack.StickerPackInfo, StickerPackSticker: Pack.StickerPackSticker,
      nextStickerPackIndex: Pack.nextStickerPackIndex });

  // Stepping --------------------------------------------------------------------------------------
  assert.equal(Pack.nextStickerPackIndex(0, 5, 1), 1);
  assert.equal(Pack.nextStickerPackIndex(4, 5, 1), 4, 'the last sticker does not wrap');
  assert.equal(Pack.nextStickerPackIndex(0, 5, -1), 0, 'the first sticker does not wrap');
  assert.equal(Pack.nextStickerPackIndex(2, 5, 0), 2, 'no movement for a zero delta');
  assert.equal(Pack.nextStickerPackIndex(2, 0, 1), 2, 'an empty pack cannot move');
  assert.equal(Pack.nextStickerPackIndex(2, 5, 10), 4, 'a large delta clamps');
  assert.equal(Pack.nextStickerPackIndex(2, 5, -10), 0);
  assert.equal(Pack.nextStickerPackIndex(1.5, 5, 1), 1.5, 'non-integer input is refused');

  // Pack parsing ----------------------------------------------------------------------------------
  const stickerJson = (id, options = {}) => ({
    '@type': 'sticker',
    id,
    emoji: options.emoji ?? '🙂',
    width: options.width ?? 512,
    height: options.height ?? 512,
    format: { '@type': options.format ?? 'stickerFormatTgs' },
    sticker: { '@type': 'file', id: options.fileId ?? 100,
      remote: { '@type': 'remoteFile', id: 'remote_' + id },
      local: { '@type': 'localFile', is_downloading_completed: options.downloaded ?? false,
        path: options.path ?? '' } },
    thumbnail: { '@type': 'thumbnail', file: { '@type': 'file', id: options.thumbFileId ?? 200,
      local: { '@type': 'localFile', is_downloading_completed: options.thumbDownloaded ?? false,
        path: options.thumbPath ?? '' } } }
  });
  const packJson = { '@type': 'stickerSet', id: '987', title: 'Pets', is_installed: true,
    is_archived: false, stickers: [stickerJson('11', { downloaded: true, path: '/s/11.tgs' }),
      stickerJson('22', { format: 'stickerFormatWebm', thumbDownloaded: true, thumbPath: '/s/22.webp' })] };
  const parsed = Pack.parseStickerPack(Td.fromJSON(JSON.stringify(packJson)));
  assert.equal(parsed.setId, '987');
  assert.equal(parsed.stickerCount, 2);
  assert.equal(parsed.stickers.length, 2);
  assert.equal(parsed.stickers[0].stickerId, '11');
  assert.equal(parsed.stickers[0].fileId, 100);
  assert.equal(parsed.stickers[0].remoteFileId, 'remote_11');
  assert.equal(parsed.stickers[0].localPath, '/s/11.tgs');
  assert.equal(parsed.stickers[0].isAnimated, true);
  assert.equal(parsed.stickers[1].isVideo, true);
  assert.equal(parsed.stickers[1].thumbPath, '/s/22.webp');
  assert.equal(parsed.stickers[1].width, 512);
  assert.equal(parsed.stickers[0].emoji, '🙂');

  const emptyPack = Pack.parseStickerPack(Td.fromJSON(JSON.stringify({ '@type': 'stickerSet', id: '5',
    title: 'Empty', is_installed: false, is_archived: false })));
  assert.deepEqual(emptyPack.stickers, []);
  assert.equal(Pack.parseStickerPack(Td.fromJSON('{"@type":"ok"}')), undefined);

  // Gallery items ---------------------------------------------------------------------------------
  const items = Items.buildStickerPackGalleryItems(parsed);
  assert.equal(items.length, 2);
  assert.equal(items[0].type, 'sticker');
  assert.equal(items[0].path, '/s/11.tgs');
  assert.equal(items[0].fileId, 100);
  assert.equal(items[0].stickerSetId, '987');
  assert.equal(items[1].thumbnailPath, '/s/22.webp');
  assert.equal(Items.buildStickerPackGalleryItems(emptyPack).length, 0);

  assert.equal(Items.stickerPackStartIndex(parsed.stickers, '22'), 1);
  assert.equal(Items.stickerPackStartIndex(parsed.stickers, '999'), 0, 'an unknown id starts at the first');
  assert.equal(Items.stickerPackStartIndex([], '11'), 0);
  assert.equal(Items.stepStickerPackIndex(1, parsed, 1), 1);

  // Neighbour preload -----------------------------------------------------------------------------
  const packOf = (localPaths) => {
    const info = new Pack.StickerPackInfo();
    info.setId = '1';
    for (let index = 0; index < localPaths.length; index += 1) {
      const sticker = new Pack.StickerPackSticker();
      sticker.stickerId = String(index + 1);
      sticker.fileId = 100 + index;
      sticker.localPath = localPaths[index];
      info.stickers.push(sticker);
    }
    return info;
  };
  const fresh = packOf(['', '', '']);
  assert.deepEqual(Items.stickerPackPreloadFileIds(fresh.stickers, 1), [102, 100],
    'both neighbours are preloaded, next first');
  assert.deepEqual(Items.stickerPackPreloadFileIds(fresh.stickers, 0), [101], 'the first sticker has one neighbour');
  assert.deepEqual(Items.stickerPackPreloadFileIds(fresh.stickers, 2), [101], 'the last sticker has one neighbour');
  assert.deepEqual(Items.stickerPackPreloadFileIds(packOf(['/s/0.tgs', '', '']).stickers, 0), [101],
    'an on-disk neighbour is skipped');
  assert.deepEqual(Items.stickerPackPreloadFileIds(fresh.stickers, -1), [], 'no preload without an index');
  assert.deepEqual(Items.stickerPackPreloadFileIds(fresh.stickers, 5), [],
    'an out-of-range index preloads nothing');
  assert.deepEqual(Items.stickerPackPreloadFileIds(packOf(['']).stickers, 0), [],
    'a single-sticker pack preloads nothing');
  const noHandle = packOf(['', '']);
  noHandle.stickers[1].fileId = 0;
  assert.deepEqual(Items.stickerPackPreloadFileIds(noHandle.stickers, 0), [],
    'a sticker without a download handle is skipped');
  const plan = Items.stickerPackPreloadPlan(fresh.stickers, 1);
  assert.equal(plan.nextFileId, 102);
  assert.equal(plan.previousFileId, 100);

  // Viewer wiring ---------------------------------------------------------------------------------
  const viewState = read('ui/pages/chat/ChatMediaViewState.ets');
  assert.match(viewState, /@Trace stickerPackStickers: StickerPackSticker\[\] = \[\];/);
  assert.match(viewState, /@Trace stickerPackPagingIndex: number = -1;/);

  const coordinator = read('ui/pages/chat/ChatStickerPackCoordinator.ets');
  assert.match(coordinator, /stickerPackStickers: StickerPackSticker\[\];/);
  assert.match(coordinator, /host\.stickerPackStickers = info\.stickers;/);
  assert.match(coordinator, /host\.stickerPackStickers = \[\];\n\s+host\.stickerPackPagingIndex = -1;/);

  const overlay = read('ui/pages/chat/TgChatMediaOverlay.ets');
  assert.match(overlay, /@Local private packGalleryItems: MediaGalleryItem\[\] = \[\];/);
  assert.match(overlay, /private syncPackPaging\(\): void \{/);
  assert.match(overlay, /@Monitor\('media\.galleryCurrentIndex', 'media\.stickerPackStickers', 'media\.galleryItems'\)/);
  assert.match(overlay, /mediaItems: this\.galleryItems\(\),/);
  assert.match(overlay, /initialIndex: this\.galleryStartIndex\(\),/);
  assert.match(overlay, /stickers\[index\]\.fileId === tappedFileId/, 'the tapped sticker picks the start index');
  assert.match(overlay, /private preloadPackNeighbours\(\): void \{/);
  assert.match(overlay, /const ids = stickerPackPreloadFileIds\(this\.media\.stickerPackStickers, this\.packGalleryIndex\);/);
  assert.match(overlay, /this\.bindings\.requestMediaDownload\(fileId\);/);
  assert.match(overlay, /this\.preloadPackNeighbours\(\);/);
  assert.match(overlay, /if \(this\.packGalleryItems\.length > 0\) \{\n\s+this\.packGalleryIndex = index;/,
    'paging stays inside the pack');

  const gallery = read('ui/pages/chat/ChatMediaGalleryCoordinator.ets');
  assert.match(gallery, /stickerItem\.fileId = entry\.message\.stickerFileId;/);

  const context = read('ui/pages/chat/ChatScreenContext.ets');
  assert.match(context, /get stickerPackStickers\(\): StickerPackSticker\[\]/);
  assert.match(context, /set stickerPackPagingIndex\(value: number\)/);

  console.log('PASS sticker pack paging contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
