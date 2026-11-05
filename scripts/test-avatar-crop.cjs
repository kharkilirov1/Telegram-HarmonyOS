// A5: avatar crop contract — centered square math, uniform scale to the upload size and the picker →
// crop → JPEG pipeline wiring.

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
  const C = load('domain/usecases/avatarCrop.ets',
    ['computeAvatarCropRect', 'avatarCropScale', 'isValidAvatarCropRect', 'AvatarCropRect',
      'AVATAR_CROP_OUTPUT_SIZE']);

  // Square math -----------------------------------------------------------------------------------
  const landscape = C.computeAvatarCropRect(4000, 3000);
  assert.equal(landscape.size, 3000);
  assert.equal(landscape.x, 500, 'a landscape photo is cropped from the left');
  assert.equal(landscape.y, 0);
  assert.equal(C.isValidAvatarCropRect(landscape, 4000, 3000), true);

  const portrait = C.computeAvatarCropRect(1200, 2000);
  assert.equal(portrait.size, 1200);
  assert.equal(portrait.x, 0);
  assert.equal(portrait.y, 400);
  assert.equal(C.isValidAvatarCropRect(portrait, 1200, 2000), true);

  const square = C.computeAvatarCropRect(800, 800);
  assert.deepEqual({ x: square.x, y: square.y, size: square.size }, { x: 0, y: 0, size: 800 });

  const tiny = C.computeAvatarCropRect(1, 1);
  assert.equal(tiny.size, 1);
  assert.equal(C.isValidAvatarCropRect(tiny, 1, 1), true);

  for (const [width, height] of [[0, 100], [100, 0], [-5, 10], [Number.NaN, 10], [10, Infinity]]) {
    const rect = C.computeAvatarCropRect(width, height);
    assert.equal(rect.size, 0, `invalid source ${width}x${height} yields no crop`);
    assert.equal(C.isValidAvatarCropRect(rect, width, height), false);
  }
  const outside = C.computeAvatarCropRect(10, 10);
  outside.x = 5;
  assert.equal(C.isValidAvatarCropRect(outside, 10, 10), false, 'a rect outside the source is rejected');

  // Scale -----------------------------------------------------------------------------------------
  assert.equal(C.AVATAR_CROP_OUTPUT_SIZE, 512);
  assert.equal(C.avatarCropScale(256), 2);
  assert.equal(C.avatarCropScale(1024), 0.5);
  assert.equal(C.avatarCropScale(512), 1);
  assert.equal(C.avatarCropScale(0), 1, 'a zero size never divides');
  assert.equal(C.avatarCropScale(-4), 1);
  assert.equal(C.avatarCropScale(Number.NaN), 1);

  // Prepared pipeline -----------------------------------------------------------------------------
  const prep = read('ui/pages/settings/avatarImagePrep.ets');
  assert.match(prep, /import \{ image \} from '@kit\.ImageKit';/);
  assert.match(prep, /import \{ fileIo \} from '@kit\.CoreFileKit';/);
  assert.match(prep, /source = image\.createImageSource\(sourceUri\);/);
  assert.match(prep, /const info = await source\.getImageInfo\(\);/);
  assert.match(prep, /const cropRect = computeAvatarCropRect\(info\.size\.width, info\.size\.height\);/);
  assert.match(prep, /await pixelMap\.crop\(toRegion\(cropRect\)\);/);
  assert.match(prep, /const region: image\.Region = \{ x: rect\.x, y: rect\.y, size: \{ width: rect\.size, height: rect\.size \} \};/,
    'the crop region carries a Size object, not a number');
  assert.match(prep, /const scale = avatarCropScale\(cropRect\.size\);/);
  assert.match(prep, /await pixelMap\.scale\(scale, scale\);/);
  assert.match(prep, /const packer = image\.createImagePacker\(\);/);
  assert.match(prep, /format: 'image\/jpeg'/);
  assert.match(prep, /const target = context\.cacheDir \+ '\/avatar_' \+ Date\.now\(\)\.toString\(\) \+ '\.jpg';/);
  assert.match(prep, /fileIo\.writeSync\(file\.fd, jpeg\);/);
  assert.match(prep, /pixelMap\.release\(\);/, 'the decoded map is released');
  assert.match(prep, /source\.release\(\);/, 'the image source is released');
  assert.match(prep, /\.catch|catch \(error\)/, 'a decode failure resolves to an empty path');
  assert.match(prep, /return '';/);

  const page = read('ui/pages/settings/TgEditProfilePage.ets');
  assert.match(page, /import \{ AvatarImagePreparation \} from '\.\/avatarImagePrep';/);
  assert.match(page, /return AvatarImagePreparation\.prepare\(context, sourceUri\);/);
  assert.equal(page.includes('fileIo.'), false, 'the page no longer copies files itself');

  console.log('PASS avatar crop contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
