// D24: message translation contract — the translateText wire, the response parser, the use case
// validation and the Translate action in the message menu.

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

  // Menu action -----------------------------------------------------------------------------------
  const actions = read('ui/pages/chat/ChatMessageActionsController.ets');
  assert.match(actions, /new ChatMessageActionItem\('translate',/, 'the menu offers Translate');
  assert.match(actions, /if \(actionId === 'translate'\) \{/);
  assert.match(actions, /private translateMessage\(entry: ChatTimelineEntryVO, host: ChatMessageActionsHost\): void \{/);
  assert.match(actions, /createTranslateMessageUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(actions, /useCase\.translate\(text, this\.targetLanguageCode\(\)\)/);
  assert.match(actions, /i18n\.System\.getSystemLanguage\(\)\.toLowerCase\(\)/);
  assert.match(actions, /if \(text\.trim\(\)\.length === 0\) \{/, 'empty messages are ignored');
  assert.match(actions, /translation_failed/);
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources/' + locale + '/element/string.json'), 'utf8'));
    for (const name of ['action_translate', 'translation_title', 'translation_failed']) {
      assert.ok(strings.string.find((item) => item.name === name), locale + ' has ' + name);
    }
  }

  console.log('PASS message translation contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
