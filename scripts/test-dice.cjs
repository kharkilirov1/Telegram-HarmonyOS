// D27: dice messages — content parsing, the large-emoji presentation, the send command/serialization and
// the use case.

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
  // Model ------------------------------------------------------------------------------------------
  const D = load('core/model/dto/MessageDto.ets',
    ['MessageContentType', 'MessageContentDto', 'parseMessageContent'], {
      TdObject: class TdObject {},
      tdHasKeys: () => true,
      tdGetString: (object, key) => (object && object[key] !== undefined ? object[key] : ''),
      tdGetNumber: (object, key) => (object && typeof object[key] === 'number' ? object[key] : 0),
      tdGetBoolean: (object, key) => Boolean(object && object[key]),
      tdGetObject: () => undefined,
      tdGetArray: () => []
    });
  assert.equal(D.MessageContentType.DICE, 'dice');

  const dice = D.parseMessageContent({ '@type': 'messageDice', emoji: '🎯', value: 5 });
  assert.equal(dice.type, 'dice');
  assert.equal(dice.diceEmoji, '🎯');
  assert.equal(dice.diceValue, 5);
  assert.equal(dice.text, '🎯', 'the emoji doubles as the rendered text');
  const fallback = D.parseMessageContent({ '@type': 'messageDice' });
  assert.equal(fallback.text, '🎲', 'an unknown dice still renders a die');

  const parserSource = read('core/model/dto/MessageDto.ets');
  assert.match(parserSource, /case 'messageDice': \{/);
  assert.match(parserSource, /contentDto\.diceValue = tdGetNumber\(contentObj, 'value'\);/);

  // State plumbing ---------------------------------------------------------------------------------
  const appState = read('core/model/AppState.ets');
  assert.match(appState, /'voice' \| 'sticker' \| 'dice' \|/);
  assert.match(appState, /diceEmoji: string = '';/);
  assert.match(appState, /diceValue: number = 0;/);
  const reducer = read('core/reducers/messagesReducer.ets');
  assert.match(reducer, /content\.diceEmoji = dto\.diceEmoji;/);
  assert.match(reducer, /content\.diceValue = dto\.diceValue;/);
  assert.match(reducer, /clonedContent\.diceValue = msg\.content\.diceValue;/);

  // Presentation -----------------------------------------------------------------------------------
  const vo = read('ui/pages/chat/ChatTimelineVO.ets');
  assert.match(vo, /row\.isEmojiOnly = \(content\.type === 'text' \|\| content\.type === 'dice'\) && isEmojiOnlyText\(row\.text\);/);
  const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');
  assert.match(router, /return ct === 'text'\n      \|\| ct === 'dice'/);

  // Command and serialization ----------------------------------------------------------------------
  const C = load('core/model/AppCommand.ets',
    ['SendDiceCommand', 'SendDicePayload', 'createSendDiceCommand'], {});
  const command = C.createSendDiceCommand(42, '🎰');
  assert.ok(command instanceof C.SendDiceCommand);
  assert.equal(command.type, 'sendDice');
  assert.equal(command.payload.chatId, 42);
  assert.equal(command.payload.emoji, '🎰');
  assert.equal(new C.SendDicePayload().emoji, '🎲');
  const commandSource = read('core/model/AppCommand.ets');
  assert.match(commandSource, /\| SendDiceCommand/, 'the command belongs to AnyAppCommand');

  const serializer = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializer, /COMMAND_SERIALIZATION_HANDLERS\.set\('sendDice', serializeSendDice\);/);
  assert.match(serializer, /result\.method = 'sendMessage';/);
  assert.match(serializer, /"@type":"inputMessageDice","emoji":/);

  // Use case ---------------------------------------------------------------------------------------
  const hilog = { info() {} };
  class TdObjectFixture {}
  const sent = [];
  let fail = false;
  const gateway = {
    async send(cmd) {
      sent.push(cmd);
      if (fail) throw new Error('network');
      return new TdObjectFixture();
    }
  };
  const U = load('domain/usecases/sendDice.ets',
    ['SendDiceUseCase', 'createSendDiceUseCase', 'DICE_EMOJIS', 'isSupportedDiceEmoji'], {
      createSendDiceCommand: (chatId, emoji) => ({ type: 'sendDice', payload: { chatId, emoji } }),
      TdObject: TdObjectFixture,
      hilog
    });
  assert.deepEqual(U.DICE_EMOJIS, ['🎲', '🎯', '🏀', '⚽', '🎳', '🎰']);
  assert.equal(U.isSupportedDiceEmoji('🎲'), true);
  assert.equal(U.isSupportedDiceEmoji('🍕'), false);
  const useCase = new U.SendDiceUseCase(gateway);
  assert.equal(await useCase.execute(0, '🎲'), false, 'no chat means no send');
  assert.equal(await useCase.execute(7, '🍕'), false, 'an unsupported emoji is rejected locally');
  assert.equal(sent.length, 0, 'rejected dice never reach the gateway');
  assert.equal(await useCase.execute(7), true);
  assert.equal(sent[0].payload.emoji, '🎲', 'the default dice is a die');
  assert.equal(sent[0].payload.chatId, 7);
  assert.equal(await useCase.execute(7, '🎯'), true);
  assert.equal(sent[1].payload.emoji, '🎯');
  fail = true;
  assert.equal(await useCase.execute(7, '🎲'), false);

  console.log('PASS dice contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
