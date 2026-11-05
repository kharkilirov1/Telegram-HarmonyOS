// F6 (pack card data layer): sticker set id travels from TDLib to the gallery item, and the pack use
// case reads/installs it. Covers the model plumbing plus the getStickerSet/changeStickerSet wire.

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
    ['createGetStickerSetCommand', 'createChangeStickerSetCommand', 'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog });
  const U = load('domain/usecases/stickerPack.ets',
    ['StickerPackUseCase', 'createStickerPackUseCase', 'isValidStickerSetId', 'parseStickerPack',
      'StickerPackInfo'], { ...C, ...errors, hilog, TdObject });
  const K = load('ui/pages/chat/ChatStickerPackCoordinator.ets',
    ['visibleStickerSetId', 'syncStickerPackCard', 'loadStickerPack', 'toggleStickerPackInstalled',
      'handleStickerPackLoad', 'handleStickerPackToggle'],
    { isValidStickerSetId: U.isValidStickerSetId, hilog });

  // Set id validation ------------------------------------------------------------------------------
  assert.equal(U.isValidStickerSetId('1368304386507618432'), true);
  assert.equal(U.isValidStickerSetId('0'), false, 'no pack is not a callable id');
  assert.equal(U.isValidStickerSetId('-4'), false);
  assert.equal(U.isValidStickerSetId('abc'), false);

  // Parse ------------------------------------------------------------------------------------------
  const parsed = U.parseStickerPack(TdObject.fromJSON(JSON.stringify({
    '@type': 'stickerSet', id: '1368304386507618432', title: 'Ducks', name: 'ducks',
    thumbnail: { '@type': 'thumbnail' }, is_owned: false, is_installed: true, is_archived: false,
    is_official: false, sticker_type: { '@type': 'stickerTypeRegular' }, needs_repainting: false,
    is_allowed_as_chat_emoji_status: false, is_viewed: true,
    stickers: [{ '@type': 'sticker', id: '1' }, { '@type': 'sticker', id: '2' }],
    emojis: []
  })));
  assert.equal(parsed.setId, '1368304386507618432');
  assert.equal(parsed.title, 'Ducks');
  assert.equal(parsed.isInstalled, true);
  assert.equal(parsed.isArchived, false);
  assert.equal(parsed.stickerCount, 2);
  assert.equal(U.parseStickerPack(TdObject.fromJSON('{"@type":"ok"}')), undefined);

  // Load and install through the gateway -----------------------------------------------------------
  const sent = [];
  const useCase = new U.StickerPackUseCase({
    send: (command) => {
      sent.push(command);
      if (command.type === 'getStickerSet') {
        return Promise.resolve(TdObject.fromJSON(JSON.stringify({
          '@type': 'stickerSet', id: '1368304386507618432', title: 'Ducks', name: 'ducks',
          is_installed: false, is_archived: false, stickers: []
        })));
      }
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
  });
  const info = await useCase.load('1368304386507618432');
  assert.equal(info.title, 'Ducks');
  assert.equal(info.isInstalled, false);
  assert.equal(info.stickerCount, 0);
  assert.equal(sent.at(-1).type, 'getStickerSet');
  const loadRaw = serializer.buildTdlibRequestJson('getStickerSet',
    serializer.serializeCommand(sent.at(-1)).params);
  // The id is emitted as a raw int64 literal, so JSON.parse would round it; assert the digits.
  assert.ok(loadRaw.includes('1368304386507618432'), 'getStickerSet keeps the exact set id');

  await useCase.setInstalled('1368304386507618432', true);
  assert.equal(sent.at(-1).type, 'changeStickerSet');
  const installWire = JSON.parse(serializer.buildTdlibRequestJson('changeStickerSet',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(installWire.set_id, '1368304386507618432', 'int64 id is a decimal string');
  assert.equal(installWire.is_installed, true);
  assert.equal(installWire.is_archived, false);

  await useCase.setInstalled('1368304386507618432', false);
  const removeWire = JSON.parse(serializer.buildTdlibRequestJson('changeStickerSet',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(removeWire.is_installed, false, 'removal is the same call with false');

  const before = sent.length;
  await assert.rejects(() => useCase.load('0'), /Invalid sticker set id/);
  await assert.rejects(() => useCase.setInstalled('x', true), /Invalid sticker set id/);
  assert.equal(sent.length, before, 'invalid input never reaches the gateway');
  await assert.rejects(() => new U.StickerPackUseCase(
    { send: () => Promise.reject(new Error('native status')) }).load('1368304386507618432'),
    /Failed to load the sticker pack/);
  await assert.rejects(() => new U.StickerPackUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).load('1368304386507618432'),
    /Unsupported sticker set response/);
  await assert.rejects(() => new U.StickerPackUseCase(
    { send: () => Promise.reject(new Error('native status')) }).setInstalled('1368304386507618432', true),
    /Failed to update the sticker pack/);

  // Pack card coordinator ---------------------------------------------------------------------------
  const makeHost = (items, index, useCase) => ({
    galleryCurrentIndex: index,
    galleryItems: items,
    stickerPackSetId: '0',
    stickerPackTitle: '',
    stickerPackInstalled: false,
    stickerPackBusy: false,
    stickerPackUseCase: useCase,
    pageLifecycleToken: 1,
    stickerPackRequestToken: 0
  });

  const fakePack = {
    load: (setId) => Promise.resolve({
      setId, title: 'Ducks', isInstalled: false, isArchived: false, stickerCount: 2
    }),
    setInstalled: () => Promise.resolve()
  };

  assert.equal(K.visibleStickerSetId(makeHost([{ stickerSetId: '0' }], 0, fakePack)), '0',
    'a non-sticker item has no pack');
  assert.equal(K.visibleStickerSetId(makeHost([], 0, fakePack)), '0');
  assert.equal(K.visibleStickerSetId(makeHost([{ stickerSetId: '777' }], 5, fakePack)), '0');

  const cardHost = makeHost([{ stickerSetId: '777' }], 0, fakePack);
  K.syncStickerPackCard(cardHost);
  assert.equal(cardHost.stickerPackSetId, '777');
  assert.equal(cardHost.stickerPackBusy, true, 'the card shows a loading state');
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(cardHost.stickerPackTitle, 'Ducks');
  assert.equal(cardHost.stickerPackInstalled, false);
  assert.equal(cardHost.stickerPackBusy, false);

  const loadedBefore = cardHost.stickerPackTitle;
  K.syncStickerPackCard(cardHost);
  assert.equal(cardHost.stickerPackTitle, loadedBefore, 'the same pack is not reloaded');

  K.handleStickerPackToggle(cardHost);
  assert.equal(cardHost.stickerPackBusy, true);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(cardHost.stickerPackInstalled, true, 'the toggle installs the pack');

  const clearedHost = makeHost([{ stickerSetId: '777' }], 0, fakePack);
  clearedHost.stickerPackSetId = '777';
  clearedHost.stickerPackTitle = 'Ducks';
  clearedHost.stickerPackInstalled = true;
  clearedHost.galleryItems = [{ stickerSetId: '0' }];
  K.syncStickerPackCard(clearedHost);
  assert.equal(clearedHost.stickerPackSetId, '0');
  assert.equal(clearedHost.stickerPackTitle, '');
  assert.equal(clearedHost.stickerPackInstalled, false);

  // A failed load clears the spinner and keeps the card hidden rather than showing a stale title.
  const failingHost = makeHost([{ stickerSetId: '888' }], 0,
    { load: () => Promise.reject(new Error('native status')), setInstalled: () => Promise.resolve() });
  K.handleStickerPackLoad(failingHost);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(failingHost.stickerPackBusy, false);
  assert.equal(failingHost.stickerPackTitle, '');

  // A stale response after the page token changed must not touch the state.
  const staleHost = makeHost([{ stickerSetId: '999' }], 0, fakePack);
  K.handleStickerPackLoad(staleHost);
  staleHost.pageLifecycleToken += 1;
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(staleHost.stickerPackTitle, '', 'stale responses are dropped');

  // Model plumbing: TDLib → content → timeline row → gallery item -----------------------------------
  const state = read('core/model/AppState.ets');
  assert.match(state, /stickerSetId: string = '0';/);
  const dto = read('core/model/dto/MessageDto.ets');
  assert.match(dto, /stickerSetId: string = '0';/, 'the content DTO declares the field');
  assert.match(dto, /contentDto\.stickerSetId = tdGetInt64\(stickerObj, 'set_id'\);/);
  const reducer = read('core/reducers/messagesReducer.ets');
  assert.match(reducer, /content\.stickerSetId = dto\.stickerSetId;/, 'new messages map the pack id');
  assert.match(reducer, /clonedContent\.stickerSetId = msg\.content\.stickerSetId;/, 'clones keep it');
  const vo = read('ui/pages/chat/ChatTimelineVO.ets');
  assert.match(vo, /row\.stickerSetId = content\.stickerSetId;/);
  const item = read('models/MediaGalleryItem.ets');
  assert.match(item, /stickerSetId: string = '0';/);
  const coordinator = read('ui/pages/chat/ChatMediaGalleryCoordinator.ets');
  assert.match(coordinator, /stickerItem\.stickerSetId = entry\.message\.stickerSetId;/);

  // Card UI and wiring.
  const overlay = read('ui/pages/chat/TgChatMediaOverlay.ets');
  assert.match(overlay, /this\.bindings\.loadStickerPack\(\);/);
  assert.match(overlay, /@Monitor\('media\.galleryCurrentIndex', 'media\.stickerPackStickers', 'media\.galleryItems'\)/);
  assert.match(overlay, /private buildStickerPackCard\(\)/);
  assert.match(overlay, /this\.bindings\.toggleStickerPackInstalled\(\);/);
  const viewState = read('ui/pages/chat/ChatMediaViewState.ets');
  for (const field of ['stickerPackSetId', 'stickerPackTitle', 'stickerPackInstalled',
    'stickerPackBusy']) {
    assert.ok(viewState.includes('@Trace ' + field), 'view state field ' + field);
  }
  const ports = read('ui/pages/chat/ChatScreenViewPorts.ets');
  assert.match(ports, /loadStickerPack\(\): void;/);
  assert.match(ports, /toggleStickerPackInstalled\(\): void;/);
  const bindings = read('ui/pages/chat/ChatScreenViewBindings.ets');
  assert.match(bindings, /loadStickerPack\(\): void \{ this\.session\.loadStickerPack\(\); \}/);
  const gallery = read('ui/pages/chat/ChatMediaGalleryCoordinator.ets');
  assert.match(gallery, /host\.syncStickerPackCard\(\);/,
    'the viewer loads the pack card when it opens');
  const session = read('ui/pages/chat/ChatScreenSession.ets');
  assert.match(session, /syncStickerPackCard\(\): void \{ delegateSyncStickerPackCard\(this\); \}/);
  const activation = read('ui/pages/chat/ChatRouteActivationCoordinator.ets');
  assert.match(activation, /host\.stickerPackUseCase = createStickerPackUseCase\(gateway\);/);
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources/' + locale + '/element/string.json'), 'utf8'));
    for (const name of ['sticker_pack_add', 'sticker_pack_remove']) {
      assert.ok(strings.string.find((item) => item.name === name), locale + ' has ' + name);
    }
  }

  console.log('PASS sticker pack contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
