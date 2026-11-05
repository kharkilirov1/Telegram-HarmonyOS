// D24: translation target language — supported list, normalization, per-chat override, cache invalidation
// on a language change and the controller wiring.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');
const readResource = (relative) =>
  fs.readFileSync(path.join(root, '..', 'resources', relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  const hilog = { info() {}, warn() {}, error() {} };
  const L = load('domain/usecases/translationLanguage.ets',
    ['SUPPORTED_TRANSLATION_LANGUAGES', 'FALLBACK_TRANSLATION_LANGUAGE',
      'normalizeTranslationLanguage', 'isSupportedTranslationLanguage', 'resolveTranslationLanguage',
      'translationLanguageLabel', 'translationLanguagePreferences', 'GLOBAL_TRANSLATION_CHAT_ID'], { hilog });

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

  // App-wide default ------------------------------------------------------------------------------
  L.translationLanguagePreferences.clearAll();
  assert.equal(L.GLOBAL_TRANSLATION_CHAT_ID, 1);
  assert.equal(L.translationLanguagePreferences.globalDefault(), '');
  assert.equal(L.translationLanguagePreferences.setGlobalDefault('xx'), false, 'an unsupported default is refused');
  assert.equal(L.translationLanguagePreferences.setGlobalDefault('fr'), true);
  assert.equal(L.translationLanguagePreferences.globalDefault(), 'fr');
  assert.equal(L.translationLanguagePreferences.set(9, 'de'), true, 'a chat choice coexists with the default');
  assert.equal(L.translationLanguagePreferences.globalDefault(), 'fr');
  L.translationLanguagePreferences.clearAll();

  // Resolution order ------------------------------------------------------------------------------
  assert.equal(L.resolveTranslationLanguage('de', 'ru-RU'), 'de', 'the stored choice wins');
  assert.equal(L.resolveTranslationLanguage('', 'ru-RU'), 'ru', 'the system language is the fallback');
  assert.equal(L.resolveTranslationLanguage('xx', 'ru'), 'ru', 'an unsupported stored value is ignored');
  assert.equal(L.resolveTranslationLanguage('', 'xx'), 'en', 'an unsupported system language falls to English');
  assert.equal(L.resolveTranslationLanguage('', ''), 'en');
  assert.equal(L.resolveTranslationLanguage('', 'xx', 'de'), 'de', 'the app default beats the system language');
  assert.equal(L.resolveTranslationLanguage('it', 'xx', 'de'), 'it', 'the chat choice beats the app default');
  assert.equal(L.resolveTranslationLanguage('', 'ru', 'de'), 'de');
  assert.equal(L.resolveTranslationLanguage('', 'ru', 'yy'), 'ru', 'an unsupported default is skipped');
  assert.equal(L.resolveTranslationLanguage('zz', '', 'yy'), 'en');
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
  assert.match(controller, /return resolveTranslationLanguage\(stored, language, translationLanguagePreferences\.globalDefault\(\)\);/);
  assert.match(controller, /translationLanguages\(\): string\[\] \{/);
  assert.match(controller, /return SUPPORTED_TRANSLATION_LANGUAGES\.slice\(\);/);
  assert.match(controller, /translationLanguageFor\(chatId: number\): string \{/);
  assert.match(controller, /setTranslationLanguage\(chatId: number, code: string\): boolean \{/);
  assert.match(controller, /const prefix = chatId\.toString\(\) \+ ':';/, 'cache keys are invalidated per chat');
  assert.match(controller, /const language = this\.targetLanguageCode\(chatId\);/, 'translation uses the chat choice');
  assert.match(controller, /translationLanguageLabelFor\(code: string\): string \{/);

  // Message popup wiring ---------------------------------------------------------------------------
  assert.match(controller, /translateIntoLanguage\(entry: ChatTimelineEntryVO, host: ChatMessageActionsHost\): void \{/);
  assert.match(controller, /this\.translateMessage\(entry, host, true\);/);
  assert.match(controller, /force: boolean = false\): void \{/);
  assert.match(controller, /if \(entry\.message\.translationVisible && !force\) \{/);

  const bindings = read('ui/pages/chat/ChatScreenViewBindings.ets');
  assert.match(bindings, /messageActionTranslationLanguages\(\): string\[\] \{ return this\.session\.messageActionTranslationLanguages\(\); \}/);
  assert.match(bindings, /handleMessageActionTranslationLanguage\(code: string\): void \{ this\.session\.handleMessageActionTranslationLanguage\(code\); \}/);

  const coordinator = read('ui/pages/chat/ChatMessagePopupCoordinator.ets');
  assert.match(coordinator, /export function messageActionTranslationLanguages\(host: ChatMessagePopupCoordinatorPort\): string\[\] \{/);
  assert.match(coordinator, /export function messageActionTranslationLanguage\(host: ChatMessagePopupCoordinatorPort\): string \{/);
  assert.match(coordinator, /host\.messageActionsCtrl\.translationLanguageFor\(host\.activeChatId\)/);
  assert.match(coordinator, /export function handleMessageActionTranslationLanguage\(host: ChatMessagePopupCoordinatorPort,/);
  assert.match(coordinator, /host\.messageActionsCtrl\.setTranslationLanguage\(chatId, code\)/);
  assert.match(coordinator, /host\.messageActionsCtrl\.translateIntoLanguage\(entry, host\)/);

  const session = read('ui/pages/chat/ChatScreenSession.ets');
  assert.match(session, /messageActionTranslationLanguages\(\): string\[\] \{ return delegateMessageActionTranslationLanguages\(this\); \}/);
  assert.match(session, /handleMessageActionTranslationLanguage\(code: string\): void \{ delegateHandleMessageActionTranslationLanguage\(this, code\); \}/);
  const ports = read('ui/pages/chat/ChatScreenViewPorts.ets');
  assert.match(ports, /messageActionTranslationLanguages\(\): string\[\];/);
  assert.match(ports, /messageActionTranslationLanguage\(\): string;/);
  assert.match(ports, /handleMessageActionTranslationLanguage\(code: string\): void;/);



  const popup = read('ui/pages/chat/TgChatMessageActionsPopup.ets');
  assert.match(popup, /@Local private translationLanguagesOpen: boolean = false;/);
  assert.match(popup, /private buildTranslationLanguageRow\(\) \{/);
  assert.match(popup, /action_translate_to/);
  assert.match(popup, /this\.bindings\.messageActionTranslationLanguages\(\)\.length > 0/);
  assert.match(popup, /this\.bindings\.handleMessageActionTranslationLanguage\(code\);/);
  assert.match(popup, /code === this\.bindings\.messageActionTranslationLanguage\(\)/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(`${locale}/element/string.json`)).string;
    assert.ok(strings.some((entry) => entry.name === 'action_translate_to'), `${locale} ships action_translate_to`);
  }

  // Picker page + settings wiring -----------------------------------------------------------------
  const page = read('ui/pages/settings/TgTranslationLanguagePage.ets');
  assert.match(page, /export class TranslationLanguageRouteParams/);
  assert.match(page, /private choose\(code: string\): void \{/);
  assert.match(page, /translationLanguagePreferences\.setGlobalDefault\(code\)/);
  assert.match(page, /ForEach\(SUPPORTED_TRANSLATION_LANGUAGES, \(code: string\) => \{/);
  assert.match(page, /this\.selected === code/);
  assert.match(page, /TgChatTopBar\(\{/);
  assert.match(page, /translation_language_title/);

  const settings = read('ui/pages/settings/SettingsPage.ets');
  assert.match(settings, /@Event onOpenTranslationLanguage: \(\) => void = \(\): void => \{\};/);
  assert.match(settings, /private translationLanguageText\(\): string \{/);
  assert.match(settings, /settings_translation_language/);
  assert.match(settings, /this\.onOpenTranslationLanguage\(\);/);
  assert.match(settings, /import \{ translationLanguagePreferences \} from '\.\.\/\.\.\/\.\.\/domain\/usecases\/translationLanguage';/);

  const tabs = read('ui/pages/MainTabsPage.ets');
  assert.match(tabs, /private pushTranslationLanguage\(\): void \{/);
  assert.match(tabs, /this\.settingsNavStack\.pushPathByName\('TgTranslationLanguagePage', new TranslationLanguageRouteParams\(\)\);/);
  assert.match(tabs, /onOpenTranslationLanguage: \(\): void => \{\n\s+this\.pushTranslationLanguage\(\);/);

  const routes = JSON.parse(readResource('base/profile/route_map.json')).routerMap;
  const route = routes.find((entry) => entry.name === 'TgTranslationLanguagePage');
  assert.ok(route, 'the picker route is registered');
  assert.equal(route.buildFunction, 'TgTranslationLanguagePageBuilder');

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(`${locale}/element/string.json`)).string;
    for (const name of ['translation_language_title', 'settings_translation_language']) {
      assert.ok(strings.some((entry) => entry.name === name), `${locale} ships ${name}`);
      assert.ok(strings.find((entry) => entry.name === name).value.length > 0);
    }
  }

  console.log('PASS translation language contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
