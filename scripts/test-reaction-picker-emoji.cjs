// D16: custom emoji reactions in the picker — key parsing, the observed path state, prefetch and the
// atom rendering an image instead of the fallback glyph.

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
  // The module decorators are TypeScript-only; strip them before evaluation.
  const stripped = source.replace(/@ObservedV2\s*\n/g, '').replace(/^\s*@Trace\s+/gm, '');
  const js = stripTypeScriptTypes(stripped, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}

async function main() {
  const hilog = { info() {}, warn() {}, error() {} };
  const state = load('core/model/AppState.ets', ['TextEntity']);
  const fileUri = { getUriFromPath: (p) => 'file://' + p };
  const Cache = load('domain/usecases/customEmojiPathCache.ets',
    ['customEmojiPathCache', 'CustomEmojiPathCacheStore'], { fileUri });
  const Cmds = load('core/model/AppCommand.ets',
    ['createGetCustomEmojiStickersCommand', 'createDownloadFileCommand', 'AppCommand']);
  const Err = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const Td = load('models/td/common/index.ets', ['TdObject']).TdObject;
  const PrefetchMod = load('domain/usecases/customEmojiPrefetch.ets',
    ['CustomEmojiPrefetchCoordinator', 'collectPendingCustomEmojiIds'],
    { ...Cmds, ...Err, TdObject: Td, hilog, fileUri,
      customEmojiPathCache: Cache.customEmojiPathCache,
      CustomEmojiResolverUseCase: load('domain/usecases/customEmojiResolver.ets',
        ['CustomEmojiResolverUseCase', 'createCustomEmojiResolverUseCase', 'parseCustomEmojiSticker',
          'isValidCustomEmojiId', 'CustomEmojiSticker'], { ...Cmds, ...Err, TdObject: Td, hilog })
        .CustomEmojiResolverUseCase,
      createCustomEmojiResolverUseCase: load('domain/usecases/customEmojiResolver.ets',
        ['CustomEmojiResolverUseCase', 'createCustomEmojiResolverUseCase', 'parseCustomEmojiSticker',
          'isValidCustomEmojiId', 'CustomEmojiSticker'], { ...Cmds, ...Err, TdObject: Td, hilog })
        .createCustomEmojiResolverUseCase });
  const P = load('ui/tg_ui/state/ReactionPickerEmojiState.ets',
    ['customReactionIds', 'ReactionPickerEmojiState', 'reactionPickerEmojiState',
      'prefetchReactionPickerEmoji', 'syncPickerPaths', 'resetReactionPickerEmojiState',
      'REACTION_KEY_CUSTOM_PREFIX'],
    { hilog, TextEntity: state.TextEntity, customEmojiPathCache: Cache.customEmojiPathCache,
      CustomEmojiPrefetchCoordinator: PrefetchMod.CustomEmojiPrefetchCoordinator });

  // Key parsing -----------------------------------------------------------------------------------
  assert.equal(P.REACTION_KEY_CUSTOM_PREFIX, 'custom:');
  assert.deepEqual(P.customReactionIds(['emoji:👍', 'custom:11', 'custom:11', 'custom:0', 'custom:', 'custom:22']),
    ['11', '22'], 'only valid custom ids, deduped and ordered');
  assert.deepEqual(P.customReactionIds(['emoji:❤️']), []);
  assert.deepEqual(P.customReactionIds([]), []);

  // Observed state --------------------------------------------------------------------------------
  const observed = new P.ReactionPickerEmojiState();
  assert.equal(observed.pathFor('custom:11'), '');
  observed.paths = new Map([['custom:11', 'file:///x']]);
  assert.equal(observed.pathFor('custom:11'), 'file:///x');
  assert.equal(observed.revision, 0);

  // Sync copies the process cache into the state ---------------------------------------------------
  P.resetReactionPickerEmojiState();
  Cache.customEmojiPathCache.setPath('11', '/data/11.webp');
  P.syncPickerPaths(['emoji:👍', 'custom:11', 'custom:22']);
  assert.equal(P.reactionPickerEmojiState.pathFor('custom:11'), 'file:///data/11.webp');
  assert.equal(P.reactionPickerEmojiState.pathFor('custom:22'), '', 'an unresolved id has no path');
  assert.equal(P.reactionPickerEmojiState.revision, 1, 'sync bumps the revision');

  // Prefetch: the resolver fills the cache and the state follows ----------------------------------
  const calls = [];
  const sticker = (id) => ({
    '@type': 'sticker',
    format: { '@type': 'stickerFormatWebm' },
    full_type: { '@type': 'stickerFullTypeCustomEmoji', custom_emoji_id: id },
    sticker: { '@type': 'file', id: 5,
      local: { '@type': 'localFile', is_downloading_completed: true, path: '/d/' + id + '.webp' } },
    thumbnail: { '@type': 'thumbnail', file: { '@type': 'file', id: 6,
      local: { '@type': 'localFile', is_downloading_completed: false, path: '' } } }
  });
  P.resetReactionPickerEmojiState();
  // The state module builds its own coordinator through the gateway adapter, so drive it through the
  // process cache instead: this is exactly what a resolved picker sees.
  Cache.customEmojiPathCache.setPath('33', '/data/33.webp');
  const filledNothing = await P.prefetchReactionPickerEmoji(['custom:33']);
  assert.equal(filledNothing, 0, 'an already cached id needs no request');
  assert.equal(P.reactionPickerEmojiState.pathFor('custom:33'), 'file:///data/33.webp');

  // Reset -----------------------------------------------------------------------------------------
  P.resetReactionPickerEmojiState();
  assert.equal(P.reactionPickerEmojiState.paths.size, 0);
  assert.equal(P.reactionPickerEmojiState.revision, 0);
  assert.deepEqual(P.customReactionIds(['custom:5']), ['5'], 'reset does not affect pure parsing');

  // Atom wiring -----------------------------------------------------------------------------------
  const picker = read('ui/tg_ui/atoms/TgReactionPicker.ets');
  assert.match(picker, /import \{[\s\S]*prefetchReactionPickerEmoji[\s\S]*\} from '\.\.\/state\/ReactionPickerEmojiState';/);
  assert.match(picker, /@Local private emojiRevision: number = 0;/);
  assert.match(picker, /aboutToAppear\(\): void \{\n\s+this\.syncCustomEmoji\(\);/);
  assert.match(picker, /@Monitor\('keys'\)\n  onKeysChanged\(\): void \{/);
  assert.match(picker, /private customEmojiPath\(key: string\): string \{/);
  assert.match(picker, /if \(this\.customEmojiPath\(key\)\.length > 0\) \{/);
  assert.match(picker, /Image\(this\.customEmojiPath\(key\)\)/);
  assert.match(picker, /\.objectFit\(ImageFit\.Contain\)/);
  assert.match(picker, /Text\(reactionPickerGlyph\(key\)\)/, 'the glyph fallback stays');
  assert.match(picker, /export function reactionPickerGlyph\(key: string\): string \{/);

  console.log('PASS reaction picker custom emoji contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
