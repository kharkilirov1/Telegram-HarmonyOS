// D26: sending a contact card — phone/name validation, the card serialization through the existing share
// command, the picker normalisation and the attachment-tile wiring.

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
  // Picker normalisation ---------------------------------------------------------------------------
  const D = load('infra/contacts/DeviceContacts.ets',
    ['PickedContact', 'splitContactName', 'toPickedContact'], { hilog: { info() {} }, contact: {} });
  assert.deepEqual(D.splitContactName('Ann Lee'), ['Ann', 'Lee']);
  assert.deepEqual(D.splitContactName('Ann van der Berg'), ['Ann', 'van der Berg']);
  assert.deepEqual(D.splitContactName('Ann'), ['Ann', '']);
  assert.deepEqual(D.splitContactName('   '), ['', '']);
  const picked = D.toPickedContact('Ann Lee', '', '', ' +7 999 123-45-67 ');
  assert.ok(picked instanceof D.PickedContact);
  assert.equal(picked.phoneNumber, '+7 999 123-45-67');
  assert.equal(picked.firstName, 'Ann');
  assert.equal(picked.lastName, 'Lee');
  const explicit = D.toPickedContact('Ann Lee', 'Anna', 'Lee-Smith', '+1 555 0100');
  assert.equal(explicit.firstName, 'Anna', 'explicit given name wins over the split');
  assert.equal(explicit.lastName, 'Lee-Smith');
  assert.equal(D.toPickedContact('Ann Lee', '', '', '   '), undefined, 'a contact without a number is skipped');

  // Validation -------------------------------------------------------------------------------------
  const hilog = { info() {} };
  class TdObjectFixture {}
  const commandCalls = [];
  const U = load('domain/usecases/sendContact.ets',
    ['SendContactUseCase', 'createSendContactUseCase', 'isValidContactPhone', 'isValidContactName'], {
      createShareContactCommand: (payload) => {
        commandCalls.push(payload);
        return { type: 'sendContactMessage', payload };
      },
      ShareContactPayload: class ShareContactPayload {},
      TdObject: TdObjectFixture,
      hilog
    });
  assert.equal(U.isValidContactPhone('+7 999 123-45-67'), true);
  assert.equal(U.isValidContactPhone('5550100'), true);
  assert.equal(U.isValidContactPhone('+4'), false, 'too short');
  assert.equal(U.isValidContactPhone(''), false);
  assert.equal(U.isValidContactPhone('abcdefgh'), false, 'letters are not a phone number');
  assert.equal(U.isValidContactPhone('1234'), false, 'four digits is not enough');
  assert.equal(U.isValidContactName('Ann', ''), true);
  assert.equal(U.isValidContactName('', 'Lee'), true);
  assert.equal(U.isValidContactName('  ', '  '), false);

  // Use case ---------------------------------------------------------------------------------------
  const sent = [];
  let fail = false;
  const gateway = {
    async send(cmd) {
      sent.push(cmd);
      if (fail) throw new Error('network');
      return new TdObjectFixture();
    }
  };
  const useCase = new U.SendContactUseCase(gateway);
  assert.equal(await useCase.execute(0, '+7 999 123-45-67', 'Ann'), false, 'no chat means no send');
  assert.equal(await useCase.execute(7, 'x', 'Ann'), false, 'invalid number never reaches the gateway');
  assert.equal(await useCase.execute(7, '+7 999 123-45-67', ''), false, 'a card needs a name');
  assert.equal(sent.length, 0);
  assert.equal(await useCase.execute(7, '+7 999 123-45-67', ' Ann ', ' Lee ', 0), true);
  assert.equal(commandCalls[0].phoneNumber, '+7 999 123-45-67', 'the number is trimmed, not reshaped');
  assert.equal(commandCalls[0].firstName, 'Ann');
  assert.equal(commandCalls[0].lastName, 'Lee');
  assert.equal(commandCalls[0].userId, 0);
  assert.equal(await useCase.execute(7, '+1 555 0100', 'Ann', '', 42), true);
  assert.equal(commandCalls[1].userId, 42);
  fail = true;
  assert.equal(await useCase.execute(7, '+1 555 0100', 'Ann'), false);

  // The card reuses the existing share-contact command and its serialization.
  const commandSource = read('core/model/AppCommand.ets');
  assert.match(commandSource, /export class ShareContactCommand extends AppCommand \{/);
  assert.equal(commandSource.includes('SendContactCommand'), false, 'no duplicate contact command');
  const serializer = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializer, /COMMAND_SERIALIZATION_HANDLERS\.set\('sendContactMessage', serializeSendContactMessage\);/);
  assert.match(serializer, /"@type":"inputMessageContact","contact":\{"@type":"contact"/);
  assert.match(serializer, /"user_id":' \+ cmd\.payload\.userId\.toString\(\)/);

  // Composer wiring --------------------------------------------------------------------------------
  const controller = read('ui/pages/chat/ChatComposerController.ets');
  assert.match(controller, /async sendPickedContact\(host: ChatComposerControllerHost\): Promise<void> \{/);
  assert.match(controller, /const picked: PickedContact \| undefined = await pickContactOnce\(\);/);
  assert.match(controller, /this\.contactUseCase = createSendContactUseCase\(getTdGatewayAdapter\(\)\);/);
  assert.match(controller, /composer_contact_unavailable/);
  assert.match(controller, /composer_contact_failed/);
  assert.match(controller, /      case 5:\n        this\.sendPickedContact\(host\);\n        break;/);
  const dock = read('ui/pages/chat/TgChatComposerDock.ets');
  assert.match(dock, /this\.bindings\.composerAllows\('document'\), true, false, true/,
    'the contact tile is enabled');

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(`${locale}/element/string.json`)).string;
    for (const name of ['composer_contact_unavailable', 'composer_contact_failed']) {
      assert.ok(strings.find((item) => item.name === name), `${locale} ships ${name}`);
    }
  }

  console.log('PASS contact send contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
