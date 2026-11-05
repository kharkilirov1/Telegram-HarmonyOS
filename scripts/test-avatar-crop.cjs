// A5: avatar crop contract — centered square math, uniform scale to the upload size and the picker →
// crop → JPEG pipeline wiring.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  const C = load('domain/usecases/avatarCrop.ets',
    ['computeAvatarCropRect', 'avatarCropScale', 'isValidAvatarCropRect', 'AvatarCropRect',
      'computeAvatarCropRectFromTransform', 'clampAvatarZoom', 'AVATAR_EDITOR_MIN_ZOOM',
      'AVATAR_EDITOR_MAX_ZOOM',
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
  assert.match(prep, /const cropRect = requestedRect !== undefined\n      \? requestedRect\n      : computeAvatarCropRect\(info\.size\.width, info\.size\.height\);/);
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
  assert.match(page, /import \{ AvatarImagePreparation, AvatarSourceSize \} from '\.\/avatarImagePrep';/);
  assert.match(page, /return AvatarImagePreparation\.prepare\(context, sourceUri\);/);
  assert.equal(page.includes('fileIo.'), false, 'the page no longer copies files itself');

  // Editor transform math -------------------------------------------------------------------------
  const SIDE = 280;
  const centered = C.computeAvatarCropRectFromTransform(1000, 1000, SIDE, 1, 0, 0);
  assert.equal(centered.size, 1000, "zoom 1 shows the whole short side");
  assert.equal(centered.x, 0);
  assert.equal(centered.y, 0);
  const zoomed = C.computeAvatarCropRectFromTransform(1000, 1000, SIDE, 2, 0, 0);
  assert.equal(zoomed.size, 500, "zoom 2 halves the crop");
  assert.equal(zoomed.x, 250);
  assert.equal(zoomed.y, 250);
  const panned = C.computeAvatarCropRectFromTransform(1000, 1000, SIDE, 2, 70, -70);
  assert.equal(panned.size, 500);
  assert.equal(panned.x, 125, "panning right moves the crop left");
  const panEdge = C.computeAvatarCropRectFromTransform(1000, 1000, SIDE, 2, 200, 0);
  assert.equal(panEdge.x, 0, "a large pan clamps at the edge");
  assert.equal(panned.y, 375, "panning up moves the crop down");
  assert.ok(C.isValidAvatarCropRect(panned, 1000, 1000));
  const wide = C.computeAvatarCropRectFromTransform(2000, 1000, SIDE, 1, 0, 0);
  assert.equal(wide.size, 1000, "the short side bounds the crop");
  assert.equal(wide.x, 500, "a wide image is cropped from its center");
  const overzoomed = C.computeAvatarCropRectFromTransform(1000, 1000, SIDE, 99, 0, 0);
  assert.equal(overzoomed.size, 250, "the zoom ceiling is applied");
  const underzoomed = C.computeAvatarCropRectFromTransform(1000, 1000, SIDE, 0.1, 0, 0);
  assert.equal(underzoomed.size, 1000, "the zoom floor is applied");
  const invalid = C.computeAvatarCropRectFromTransform(0, 0, SIDE, 2, 0, 0);
  assert.equal(invalid.size, 0, "no crop without a source");
  assert.equal(C.computeAvatarCropRectFromTransform(1000, 1000, 0, 2, 0, 0).size, 0);
  assert.equal(C.computeAvatarCropRectFromTransform(1000, 1000, SIDE, Number.NaN, 0, 0).size, 1000);
  assert.equal(C.clampAvatarZoom(0), C.AVATAR_EDITOR_MIN_ZOOM);
  assert.equal(C.clampAvatarZoom(99), C.AVATAR_EDITOR_MAX_ZOOM);
  assert.equal(C.clampAvatarZoom(Number.NaN), C.AVATAR_EDITOR_MIN_ZOOM);
  assert.equal(C.clampAvatarZoom(2.5), 2.5);

  // Editor UI wiring ------------------------------------------------------------------------------
  const prepEditor = read("ui/pages/settings/avatarImagePrep.ets");
  assert.match(prepEditor, /static async measure\(sourceUri: string\): Promise<AvatarSourceSize> \{/);
  assert.match(prepEditor, /static async prepare\(context: common\.UIAbilityContext, sourceUri: string,/);
  assert.match(prepEditor, /requestedRect !== undefined/);
  const profilePage = read("ui/pages/settings/TgEditProfilePage.ets");
  assert.match(profilePage, /return AvatarImagePreparation\.prepare\(context, sourceUri, rect\);/);
  assert.match(profilePage, /@Local private editorOpen: boolean = false;/);
  assert.match(profilePage, /private commitEditorCrop\(\): void \{/);
  assert.match(profilePage, /computeAvatarCropRectFromTransform\(this\.editorWidth, this\.editorHeight,/);
  assert.match(profilePage, /private buildAvatarEditor\(\) \{/);
  assert.match(profilePage, /PinchGesture\(\{ fingers: 2 \}\)/);
  assert.match(profilePage, /PanGesture\(\{ fingers: 1, direction: PanDirection\.All \}\)/);
  assert.match(profilePage, /clampAvatarZoom\(this\.pinchStartZoom \* event\.scale\)/);
  assert.match(profilePage, /this\.cropPickedPhoto\(uri, rect\)/);
  assert.match(profilePage, /if \(this\.editorOpen\) \{\n\s+this\.buildAvatarEditor\(\)/);
  for (const name of ["edit_profile_photo_frame", "edit_profile_photo_use", "edit_profile_error"]) {
    for (const locale of ["base", "ru_RU", "zh_CN"]) {
      assert.ok(fs.readFileSync(path.join(root, '..', 'resources', locale, 'element', 'string.json'), 'utf8').includes(name), `${locale} ships ${name}`);
    }
  }
  console.log('PASS avatar crop contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
