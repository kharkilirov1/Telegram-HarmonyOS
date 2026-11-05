// D24: translation target language — supported list, normalization, per-chat override, cache invalidation
// on a language change and the controller wiring.

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
  const hilog = { info() {}, warn() {}, error() {} };
  const L = load('domain/usecases/translationLanguage.ets',
    ['SUPPORTED_TRANSLATION_LANGUAGES', 'FALLBACK_TRANSLATION_LANGUAGE',
      'normalizeTranslationLanguage', 'isSupportedTranslationLanguage', 'resolveTranslationLanguage',
      'translationLanguageLabel', 'translationLanguagePreferences'], { hilog });

  // Supported list --------------------------------------------------------------------------------
  assert.ok(L.SUPPORTED_TRANSLATION_LANGUAGES.includes('en'));
  assert.ok(L.SUPPORTED_TRANSLATION_LANGUAGES.includes('ru'));
  assert.ok(L.SUPPORTED_TRANSLATION_LANGUAGES.includes('zh'));
  assert.equal(new Set(L.SUPPORTED_TRANSLATION_LANGUAGES).size, L.SUPPORTED_TRANSLATION_LANGUAGES.length,
    'no duplicates in the picker order');
  assert.equal(L.SUPPORTED_TRANSLATION_LANGUAGES[0], 'en', 'English leads the list');
  assert.equal(L.FALLBACK_TRANSLATION_LANGUAGE, 'en');

  // Normalization ---------------------------------------------------------------------------------
  assert.equal(L.normalizeTranslationLanguage(' RU '), 'ru');
  assert.equal(L.normalizeTranslationLanguage('pt-BR'), 'pt', 'a region suffix keeps the primary code');
  assert.equal(L.normalizeTranslationLanguage('zh-Hans'), 'zh');
  assert.equal(L.normalizeTranslationLanguage(''), '');
  assert.equal(L.normalizeTranslationLanguage('  '), '');
  assert.equal(L.normalizeTranslationLanguage('english'), '', 'a word is not a code');
  assert.equal(L.normalizeTranslationLanguage('1'), '');

  assert.equal(L.isSupportedTranslationLanguage('en'), true);
  assert.equal(L.isSupportedTranslationLanguage('EN'), true);
  assert.equal(L.isSupportedTranslationLanguage('pt-BR'), true);
  assert.equal(L.isSupportedTranslationLanguage('xx'), false);
  assert.equal(L.isSupportedTranslationLanguage(''), false);

  // Resolution order ------------------------------------------------------------------------------
  assert.equal(L.resolveTranslationLanguage('de', 'ru-RU'), 'de', 'the stored choice wins');
  assert.equal(L.resolveTranslationLanguage('', 'ru-RU'), 'ru', 'the system language is the fallback');
  assert.equal(L.resolveTranslationLanguage('xx', 'ru'), 'ru', 'an unsupported stored value is ignored');
  assert.equal(L.resolveTranslationLanguage('', 'xx'), 'en', 'an unsupported system language falls to English');
  assert.equal(L.resolveTranslationLanguage('', ''), 'en');
  assert.equal(L.resolveTranslationLanguage('pt-BR', ''), 'pt');

  assert.equal(L.translationLanguageLabel('en'), 'EN');
  assert.equal(L.translationLanguageLabel('pt-BR'), 'PT');
  assert.equal(L.translationLanguageLabel(''), '');

  // Per-chat preferences ----------------------------------------------------------------------
  L.translationLanguagePreferences.clearAll();
  assert.equal(L.translationLanguagePreferences.set(0, 'de'), false, 'a zero chat id is not stored');
  assert.equal(L.translationLanguagePreferences.set(5, 'xx'), false, 'an unsupported code is not stored');
  assert.equal(L.translationLanguagePreferences.set(5, 'DE'), true);
  assert.equal(L.translationLanguagePreferences.get(5), 'de');
  assert.equal(L.translationLanguagePreferences.get(6), '', 'other chats keep their own value');
  assert.equal(L.translationLanguagePreferences.size(), 1);
  L.translationLanguagePreferences.clear(5);
  assert.equal(L.translationLanguagePreferences.get(5), '');
  assert.equal(L.translationLanguagePreferences.size(), 0);
  assert.equal(L.translationLanguagePreferences.set(7, 'pt-BR'), true);
  assert.equal(L.translationLanguagePreferences.get(7), 'pt');

  // Controller wiring -----------------------------------------------------------------------------
  const controller = read('ui/pages/chat/ChatMessageActionsController.ets');
  assert.match(controller, /import \{[\s\S]*translationLanguagePreferences[\s\S]*\} from '\.\.\/\.\.\/\.\.\/domain\/usecases\/translationLanguage';/);
  assert.match(controller, /private targetLanguageCode\(chatId: number = 0\): string \{/);
  assert.match(controller, /const stored = chatId !== 0 \? translationLanguagePreferences\.get\(chatId\) : '';/);
  assert.match(controller, /return resolveTranslationLanguage\(stored, language\);/);
  assert.match(controller, /translationLanguages\(\): string\[\] \{/);
  assert.match(controller, /return SUPPORTED_TRANSLATION_LANGUAGES\.slice\(\);/);
  assert.match(controller, /translationLanguageFor\(chatId: number\): string \{/);
  assert.match(controller, /setTranslationLanguage\(chatId: number, code: string\): boolean \{/);
  assert.match(controller, /const prefix = chatId\.toString\(\) \+ ':';/, 'cache keys are invalidated per chat');
  assert.match(controller, /const language = this\.targetLanguageCode\(chatId\);/, 'translation uses the chat choice');
  assert.match(controller, /translationLanguageLabelFor\(code: string\): string \{/);

  console.log('PASS translation language contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
