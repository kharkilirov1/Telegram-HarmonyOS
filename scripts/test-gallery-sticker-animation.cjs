// F6: animated stickers inside the media viewer — TGS detection, contained fit math, the player surface
// and the gallery rendering only the current sticker.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  const L = load('ui/tg_ui/util/GalleryStickerLayout.ets',
    ['isTgsPath', 'galleryStickerSize', 'GalleryStickerSize', 'GALLERY_STICKER_MAX_FRACTION']);

  // Detection -------------------------------------------------------------------------------------
  assert.equal(L.isTgsPath('/data/sticker_1.tgs'), true);
  assert.equal(L.isTgsPath('/data/STICKER.TGS'), true);
  assert.equal(L.isTgsPath('  /data/x.tgs  '), true);
  assert.equal(L.isTgsPath('/data/sticker.webp'), false);
  assert.equal(L.isTgsPath('/data/sticker.tgs.json'), false);
  assert.equal(L.isTgsPath(''), false);

  // Fit math --------------------------------------------------------------------------------------
  assert.equal(L.GALLERY_STICKER_MAX_FRACTION, 0.86);
  const viewport = [400, 800];
  const square = L.galleryStickerSize(512, 512, viewport[0], viewport[1]);
  assert.equal(square.width, 344, 'a square sticker fits the width');
  assert.equal(square.height, 344);
  const wide = L.galleryStickerSize(1000, 500, viewport[0], viewport[1]);
  assert.equal(wide.width, 344);
  assert.equal(wide.height, 172, 'the aspect ratio is kept');
  const tall = L.galleryStickerSize(500, 1000, viewport[0], viewport[1]);
  assert.equal(tall.height, 688, 'a tall sticker fits the height');
  assert.equal(tall.width, 344, 'and keeps its narrow ratio');
  const mismatched = L.galleryStickerSize(0, 0, 400, 800);
  assert.equal(mismatched.width, 344, 'a missing size falls back to a square');
  assert.equal(L.galleryStickerSize(0, 0, 0, 800).width, 0, 'no viewport means no render');
  assert.equal(L.galleryStickerSize(0, 0, 400, -1).width, 0);
  assert.equal(L.galleryStickerSize(Number.NaN, 10, 400, 800).height > 0, true);

  // Player surface ---------------------------------------------------------------------------------
  const player = read('ui/tg_ui/atoms/TgTgsPlayer.ets');
  assert.match(player, /@Param surface: TgsPlaybackSurface = TgsPlaybackSurface\.Timeline;/);
  assert.match(player, /if \(!TgsPlaybackPolicy\.shouldPlay\(this\.nativeVisible, this\.surface\)\) \{/);
  assert.equal(player.includes('shouldPlay(this.nativeVisible, TgsPlaybackSurface.Timeline)'), false,
    'the hardcoded timeline surface is gone');

  // Gallery wiring ---------------------------------------------------------------------------------
  const gallery = read('ui/tg_ui/atoms/TgMediaGalleryPage.ets');
  assert.match(gallery, /import \{ TgTgsPlayer, TgsPlaybackSurface \} from '\.\/TgTgsPlayer';/);
  assert.match(gallery, /private buildStickerItem\(item: MediaGalleryItem, index: number\) \{/);
  assert.match(gallery, /isTgsPath\(item\.path as string\) && index === this\.currentIndex/,
    'only the visible page plays');
  assert.match(gallery, /surface: TgsPlaybackSurface\.StickerViewer/);
  assert.match(gallery, /renderWidth: galleryStickerSize\(/);
  assert.match(gallery, /renderHeight: galleryStickerSize\(/);
  assert.match(gallery, /if \(item\.type === 'sticker'\) \{\n\s+this\.buildStickerItem\(item, index\)/);
  assert.match(gallery, /this\.buildPhotoItem\(item\)/, 'the still image path stays for non-TGS stickers');

  console.log('PASS gallery sticker animation contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
