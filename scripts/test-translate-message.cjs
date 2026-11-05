// D24: message translation contract — the translateText wire, the response parser, the use case
// validation and the Translate action in the message menu.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  const hilog = { info() {}, warn() {}, error() {}, debug() {} };
  const { TdObject } = load('models/td/common/index.ets', ['TdObject']);
  const accessors = load('core/utils/tdAccessors.ets',
    ['tdGetArray', 'tdGetString', 'tdGetNumber', 'tdGetObject', 'tdGetInt64'], { TdObject });
  const C = load('core/model/AppCommand.ets',
    ['createTranslateTextCommand', 'TranslateTextCommand', 'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog, ...errors });
  const U = load('domain/usecases/translateMessage.ets',
    ['TranslateMessageUseCase', 'createTranslateMessageUseCase', 'createTranslatedTextFromTd',
      'isValidLanguageCode', 'MAX_TRANSLATE_TEXT_LENGTH', 'TranslatedText'],
    { ...C, ...errors, ...accessors, TdObject, hilog });

  // Wire ------------------------------------------------------------------------------------------
  const wire = serializer.buildTdlibRequestJson('translateText',
    serializer.serializeCommand(C.createTranslateTextCommand('Привет, "мир"', 'en')).params);
  assert.ok(wire.includes('"@type":"translateText"'));
  assert.ok(wire.includes('"to_language_code":"en"'));
  assert.ok(wire.includes('"text":"Привет, \\"мир\\""'), 'quotes are escaped, not broken');

  // Parser ----------------------------------------------------------------------------------------
  const translated = U.createTranslatedTextFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'formattedText', text: 'Hello, world',
    entities: [{ '@type': 'textEntity', offset: 0, length: 5 }]
  })));
  assert.equal(translated.text, 'Hello, world');
  assert.equal(translated.entityCount, 1);
  assert.equal(U.createTranslatedTextFromTd(TdObject.fromJSON('{"@type":"ok"}')), undefined);
  const plain = U.createTranslatedTextFromTd(TdObject.fromJSON(
    '{"@type":"formattedText","text":"Hallo","entities":[]}'));
  assert.equal(plain.entityCount, 0);

  // Validation ------------------------------------------------------------------------------------
  assert.equal(U.isValidLanguageCode('en'), true);
  assert.equal(U.isValidLanguageCode('de'), true);
  assert.equal(U.isValidLanguageCode('pt-BR'), true);
  assert.equal(U.isValidLanguageCode('EN'), false, 'codes are lowercase');
  assert.equal(U.isValidLanguageCode('e'), false);
  assert.equal(U.isValidLanguageCode('en!'), false);
  assert.equal(U.isValidLanguageCode(''), false);
  assert.equal(U.MAX_TRANSLATE_TEXT_LENGTH, 4096);

  // Use case --------------------------------------------------------------------------------------
  const sent = [];
  const ok = new U.TranslateMessageUseCase({
    send: (command) => {
      sent.push(command);
      return Promise.resolve(TdObject.fromJSON(
        '{"@type":"formattedText","text":"Hello","entities":[]}'));
    }
  });
  const result = await ok.translate('  Привет  ', 'en');
  assert.equal(result.text, 'Hello');
  assert.equal(sent.at(-1).type, 'translateText');
  assert.equal(sent.at(-1).payload.text, 'Привет', 'the text is trimmed before sending');
  assert.equal(sent.at(-1).payload.toLanguageCode, 'en');

  const before = sent.length;
  await assert.rejects(() => ok.translate('   ', 'en'), /Nothing to translate/);
  await assert.rejects(() => ok.translate('x'.repeat(4097), 'en'), /Nothing to translate/);
  await assert.rejects(() => ok.translate('hello', 'en!'), /Invalid target language/);
  assert.equal(sent.length, before, 'invalid input never reaches the gateway');

  await assert.rejects(() => new U.TranslateMessageUseCase(
    { send: () => Promise.reject(new Error('native status')) }).translate('hello', 'en'),
    /Failed to translate the message/);
  await assert.rejects(() => new U.TranslateMessageUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).translate('hello', 'en'),
    /Translation unavailable/);
  await assert.rejects(() => new U.TranslateMessageUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"formattedText","text":"","entities":[]}')) })
    .translate('hello', 'en'), /Translation unavailable/);

  // Inline translation through the message store -------------------------------------------------
  const state = read('core/model/AppState.ets');
  assert.match(state, /translatedText: string = '';/);
  assert.match(state, /translationVisible: boolean = false;/);
  const events = read('core/model/AppEvent.ets');
  assert.match(events, /export class MessageTranslationEvent extends AppEvent \{/);
  assert.match(events, /type: string = 'messageTranslation';/);
  const reducer = read('core/reducers/messagesReducer.ets');
  assert.match(reducer, /case 'messageTranslation': \{/);
  assert.match(reducer, /type === 'messageTranslation' \|\|/, 'the reducer claims the event');
  assert.match(reducer, /updated\.translatedText = event\.translatedText;/);
  assert.match(reducer, /updated\.translationVisible = event\.visible;/);
  assert.match(reducer, /clone\.translatedText = msg\.translatedText;/, 'the clone keeps the translation');
  const vo = read('ui/pages/chat/ChatTimelineVO.ets');
  assert.match(vo, /row\.translatedText = message\.translatedText;/);
  assert.match(vo, /row\.translationVisible = message\.translationVisible;/);

  // Bubble, router and row wiring.
  const bubble = read('ui/tg_ui/atoms/TgTextBubbleV3.ets');
  assert.match(bubble, /@Param translatedText: string = ''/);
  assert.match(bubble, /@Param translationVisible: boolean = false/);
  assert.match(bubble, /@Event onTranslationToggle: \(\) => void/);
  assert.match(bubble, /this\.buildTranslation\(\)/, 'the bubble renders the translation block');
  assert.match(bubble, /if \(this\.translationVisible && this\.translatedText\.length > 0\)/);
  assert.match(bubble, /translation_show_original/, 'the block offers Show original');
  assert.match(bubble, /TgUiTokens\.TRANSLATION_DIVIDER_OPACITY/);
  const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');
  assert.match(router, /translatedText: this\.translatedText,/);
  assert.match(router, /translationVisible: this\.translationVisible,/);
  assert.match(router, /onTranslationToggle: \(\): void => \{/);
  const row = read('ui/pages/chat/TgChatTimelineRow.ets');
  assert.match(row, /translatedText: this\.entry\.message\.translatedText,/);
  assert.match(row, /private toggleTranslation\(\): void \{/);
  assert.match(row, /event\.chatId = this\.chrome\.activeChatId;/);
  assert.match(row, /getAppCoreRuntime\(\)\.getStore\(\)\.dispatch\(event\)/);

  // Cache and toggle ------------------------------------------------------------------------------
  const cacheSource = read('ui/pages/chat/ChatMessageActionsController.ets');
  assert.match(cacheSource, /export const MAX_CACHED_TRANSLATIONS = 50;/);
  assert.match(cacheSource, /private translationCache: Map<string, string> = new Map<string, string>\(\);/);
  assert.match(cacheSource, /private translationKey\(messageId: string, language: string\): string \{/);
  assert.match(cacheSource, /private getActiveChatKey\(\): string \{/, 'the cache is per chat');
  assert.match(cacheSource, /this\.translationCache\.size >= MAX_CACHED_TRANSLATIONS/, 'the cache is bounded');
  assert.match(cacheSource, /const cached = this\.translationCache\.get\(this\.translationKey\(messageId, language\)\);/);
  assert.match(cacheSource, /if \(cached !== undefined\) \{/, 'a cached translation never hits the network');
  assert.match(cacheSource, /this\.cacheTranslation\(this\.translationKey\(messageId, language\), translated\.text\);/);
  assert.match(cacheSource, /private applyTranslation\(chatId: number, messageId: string, text: string, visible: boolean\): void \{/);
  assert.match(cacheSource, /if \(entry\.message\.translationVisible && !force\) \{/, 'the action toggles the shown translation off');
  assert.match(cacheSource, /this\.translationCache\.has\(this\.translationKey\(entry\.message\.messageId, this\.targetLanguageCode\(\)\)\)/,
    'the menu label reflects the cache');
  assert.match(cacheSource, /action_show_translation/, 'a translated message offers Show Translation');

  // Menu action -----------------------------------------------------------------------------------
  const actions = read('ui/pages/chat/ChatMessageActionsController.ets');
  assert.match(actions, /new ChatMessageActionItem\('translate',/, 'the menu offers Translate');
  assert.match(actions, /if \(actionId === 'translate'\) \{/);
  assert.match(actions, /private translateMessage\(entry: ChatTimelineEntryVO, host: ChatMessageActionsHost,\n    force: boolean = false\): void \{/);
  assert.match(actions, /createTranslateMessageUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(actions, /useCase\.translate\(text, language\)/);
  assert.match(actions, /i18n\.System\.getSystemLanguage\(\)\.toLowerCase\(\)/);
  assert.match(actions, /if \(text\.trim\(\)\.length === 0\) \{/, 'empty messages are ignored');
  assert.match(actions, /translation_failed/);
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources/' + locale + '/element/string.json'), 'utf8'));
    for (const name of ['action_translate', 'action_show_translation', 'translation_title', 'translation_failed',
      'translation_label', 'translation_show_original']) {
      assert.ok(strings.string.find((item) => item.name === name), locale + ' has ' + name);
    }
  }

  console.log('PASS message translation contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
