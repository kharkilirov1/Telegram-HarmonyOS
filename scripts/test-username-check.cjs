// A5: username availability — result mapping, messages, command/serialization, sequence guard and the
// edit-profile wiring.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');
const readResource = (relative) =>
  fs.readFileSync(path.join(root, '..', 'resources', relative), 'utf8').replaceAll('\r\n', '\n');

function load(relative, names, deps = {}) {
  const source = read(relative)
    .replace(/^import\s[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}

async function main() {
  // Result mapping and messages --------------------------------------------------------------------
  const hilog = { info() {} };
  const isValidProfileUsername = (value) => /^[A-Za-z][A-Za-z0-9_]{4,31}$/.test(value);
  class TdObject {
    constructor(type) {
      this.type = type;
    }
    getTopLevelStringStrict(key) {
      return key === '@type' ? this.type : '';
    }
  }
  const C = load('core/model/AppCommand.ets',
    ['CheckChatUsernameCommand', 'CheckChatUsernamePayload', 'createCheckChatUsernameCommand'], {});
  const U = load('domain/usecases/checkUsername.ets',
    ['usernameAvailabilityFromTd', 'usernameAvailabilityMessage',
      'CheckUsernameUseCase', 'createCheckUsernameUseCase'], {
      createCheckChatUsernameCommand: (chatId, username) => ({ type: 'checkChatUsername', payload: { chatId, username } }),
      TdObject,
      isValidProfileUsername,
      hilog
    });

  assert.equal(U.usernameAvailabilityFromTd(undefined), 'unknown');
  assert.equal(U.usernameAvailabilityFromTd(new TdObject('checkChatUsernameResultOk')), 'available');
  assert.equal(U.usernameAvailabilityFromTd(new TdObject('checkChatUsernameResultUsernameInvalid')), 'invalid');
  assert.equal(U.usernameAvailabilityFromTd(new TdObject('checkChatUsernameResultUsernameOccupied')), 'occupied');
  assert.equal(U.usernameAvailabilityFromTd(new TdObject('checkChatUsernameResultUsernamePurchasable')), 'purchasable');
  assert.equal(U.usernameAvailabilityFromTd(new TdObject('checkChatUsernameResultPublicChatsTooMany')), 'tooMany');
  assert.equal(U.usernameAvailabilityFromTd(new TdObject('checkChatUsernameResultPublicGroupsUnavailable')),
    'groupsUnavailable');
  assert.equal(U.usernameAvailabilityFromTd(new TdObject('somethingElse')), 'unknown');

  assert.equal(U.usernameAvailabilityMessage('available'), 'Username is available');
  assert.equal(U.usernameAvailabilityMessage('invalid'), 'This username is invalid');
  assert.equal(U.usernameAvailabilityMessage('occupied'), 'This username is already taken');
  assert.equal(U.usernameAvailabilityMessage('purchasable'), 'This username can be bought on fragment.com');
  assert.equal(U.usernameAvailabilityMessage('tooMany').length > 0, true);
  assert.equal(U.usernameAvailabilityMessage('groupsUnavailable').length > 0, true);
  assert.equal(U.usernameAvailabilityMessage('idle'), '');
  assert.equal(U.usernameAvailabilityMessage('checking'), '');
  assert.equal(U.usernameAvailabilityMessage('unknown'), '');

  // Use case against a gateway double ---------------------------------------------------------------
  const sent = [];
  let response = new TdObject('checkChatUsernameResultOk');
  let fail = false;
  const gateway = {
    async send(command) {
      sent.push(command);
      if (fail) throw new Error('network');
      return response;
    }
  };
  const useCase = new U.CheckUsernameUseCase(gateway);
  assert.equal(await useCase.check(0, 'annlee'), 'idle', 'no chat id means idle');
  assert.equal(await useCase.check(5, ''), 'idle', 'empty input means idle');
  assert.equal(await useCase.check(5, 'ab'), 'invalid', 'local validation avoids a round trip');
  assert.equal(sent.length, 0, 'invalid names never reach the gateway');
  assert.equal(await useCase.check(5, ' @ann_lee '), 'available');
  assert.equal(sent.length, 1);
  assert.equal(sent[0].payload.chatId, 5);
  assert.equal(sent[0].payload.username, 'ann_lee', 'the leading @ and spaces are stripped');
  response = new TdObject('checkChatUsernameResultUsernameOccupied');
  assert.equal(await useCase.check(5, 'ann_lee'), 'occupied');
  fail = true;
  assert.equal(await useCase.check(5, 'ann_lee'), 'unknown', 'a transport failure is unknown, not a throw');

  // Sequence guard ---------------------------------------------------------------------------------
  const first = useCase.nextSequence();
  const second = useCase.nextSequence();
  assert.equal(useCase.isCurrent(first), false, 'an older sequence is stale');
  assert.equal(useCase.isCurrent(second), true);

  // Command + serialization ------------------------------------------------------------------------
  const command = C.createCheckChatUsernameCommand(9, 'ann_lee');
  assert.ok(command instanceof C.CheckChatUsernameCommand);
  assert.equal(command.type, 'checkChatUsername');
  assert.equal(command.payload.chatId, 9);
  assert.equal(command.payload.username, 'ann_lee');
  const commandSource = read('core/model/AppCommand.ets');
  assert.match(commandSource, /\| CheckChatUsernameCommand/, 'the command belongs to AnyAppCommand');
  const serializer = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializer, /COMMAND_SERIALIZATION_HANDLERS\.set\('checkChatUsername', serializeCheckChatUsername\);/);
  assert.match(serializer, /result\.method = 'checkChatUsername';/);
  assert.match(serializer, /result\.params\.setNumber\('chat_id', cmd\.payload\.chatId\);/);
  assert.match(serializer, /result\.params\.setString\('username', cmd\.payload\.username\);/);

  // Page wiring ------------------------------------------------------------------------------------
  const page = read('ui/pages/settings/TgEditProfilePage.ets');
  assert.match(page, /@Local private usernameAvailability: UsernameAvailability = 'idle';/);
  assert.match(page, /private checkUsernameUseCase\?: CheckUsernameUseCase;/);
  assert.match(page, /this\.checkUsernameUseCase = createCheckUsernameUseCase\(getTdGatewayAdapter\(\)\);/);
  assert.match(page, /private scheduleUsernameCheck\(\): void \{/);
  assert.match(page, /const sequence = useCase\.nextSequence\(\);/);
  assert.match(page, /this\.usernameCheckTimer = setTimeout\(\(\): void => \{/);
  assert.match(page, /\}, 400\);/);
  assert.match(page, /if \(token !== this\.pageLifecycleToken \|\| !useCase\.isCurrent\(sequence\)\) \{/);
  assert.match(page, /private cancelUsernameCheck\(\): void \{/);
  assert.match(page, /private usernameAvailabilityText\(\): string \{/);
  assert.match(page, /private usernameAvailabilityColor\(\): ResourceColor \{/);
  assert.match(page, /this\.scheduleUsernameCheck\(\);/);
  assert.match(page, /usernameAvailabilityMessage\(this\.usernameAvailability\)/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(`${locale}/element/string.json`)).string;
    assert.ok(strings.find((item) => item.name === 'edit_profile_username_checking'),
      `${locale} ships edit_profile_username_checking`);
  }

  console.log('PASS username availability contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
