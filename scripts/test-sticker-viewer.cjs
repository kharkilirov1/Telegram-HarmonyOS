// F6 contract: a sticker message opens in the shared media viewer.
// Covers the gallery item collection, the index search, the gallery render branch and the sticker tap.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const coordinator = read('ui/pages/chat/ChatMediaGalleryCoordinator.ets');
const galleryPage = read('ui/tg_ui/atoms/TgMediaGalleryPage.ets');
const galleryModel = read('models/MediaGalleryItem.ets');
const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');

// Collection: a sticker message becomes one gallery item with preview and geometry --------------------
assert.match(coordinator, /ct === 'sticker'/,
  'the collector visits sticker messages');
assert.match(coordinator, /stickerItem\.type = 'sticker';/);
assert.match(coordinator, /stickerItem\.path = entry\.message\.stickerPath;/);
assert.match(coordinator, /stickerItem\.thumbnailPath = entry\.message\.stickerThumbnailPath;/);
assert.match(coordinator, /stickerItem\.width = entry\.message\.stickerWidth;/);
assert.match(coordinator, /stickerItem\.height = entry\.message\.stickerHeight;/);
assert.match(coordinator, /stickerItem\.sourceMessageId = entry\.message\.messageId;/);
assert.match(coordinator, /items\.push\(stickerItem\);/);

// The index search must skip nothing, otherwise the tapped sticker opens the wrong item.
const searchBlock = coordinator.slice(coordinator.indexOf('handleMediaGalleryOpen'));
assert.match(searchBlock, /ct === 'sticker'/, 'index search counts stickers');

// Rendering: the photo branch already draws path/thumbnail with Contain, which is right for stickers.
assert.match(galleryPage, /if \(item\.type === 'sticker'\) \{\n\s+this\.buildStickerItem\(item, index\)/);
  assert.match(galleryPage, /} else if \(item\.type === 'photo'\) \{/);
assert.match(galleryPage, /this\.buildPhotoItem\(item\)/);

// Model: the type union documents the new kind.
assert.match(galleryModel, /'photo' \| 'video' \| 'animation' \| 'videoNote' \| 'sticker'/);

// Tap: a sticker opens the same viewer as photos.
assert.match(router, /private isSticker\(\): boolean/);
const stickerBranch = router.slice(router.indexOf('if (this.isSticker())'));
const tapBlock = stickerBranch.slice(0, stickerBranch.indexOf('} else if (this.isTextLike())'));
assert.match(tapBlock, /\.onClick\(\(\) => \{/,
  'the sticker surface is tappable');
assert.match(tapBlock, /this\.onMediaGalleryOpen\(this\.messageId\);/,
  'the tap routes into the media viewer');

// A sticker whose file is not downloaded yet still shows its thumbnail through the shared fallback.
const notDownloaded = galleryPage.slice(galleryPage.indexOf('private buildNotDownloaded'));
const fallbackBody = notDownloaded.slice(0, notDownloaded.indexOf('private galleryPreviewKind'));
assert.match(fallbackBody, /thumbnailPath/, 'the fallback renders a thumbnail');

console.log('PASS sticker viewer contract');
