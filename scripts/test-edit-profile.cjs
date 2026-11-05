// A5: profile editing data layer — setName/setBio/setUsername wire, validation boundaries,
// the Ok answer contract and gateway failure mapping.

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
    ['createSetProfileNameCommand', 'createSetProfileBioCommand', 'createSetProfileUsernameCommand',
      'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog, ...errors });
  const U = load('domain/usecases/editProfile.ets',
    ['EditProfileUseCase', 'createEditProfileUseCase', 'isValidProfileUsername', 'isValidProfileNamePart',
      'isValidProfileBio', 'PROFILE_NAME_PART_MAX_LENGTH', 'PROFILE_BIO_MAX_LENGTH',
      'PROFILE_USERNAME_MIN_LENGTH', 'PROFILE_USERNAME_MAX_LENGTH'],
    { ...C, ...errors, TdObject, hilog });

  // Wire ------------------------------------------------------------------------------------------
  const nameWire = serializer.buildTdlibRequestJson('setName',
    serializer.serializeCommand(C.createSetProfileNameCommand('Ann', 'Lee')).params);
  assert.ok(nameWire.includes('"@type":"setName"'));
  assert.ok(nameWire.includes('"first_name":"Ann"'));
  assert.ok(nameWire.includes('"last_name":"Lee"'));
  const bioWire = serializer.buildTdlibRequestJson('setBio',
    serializer.serializeCommand(C.createSetProfileBioCommand('designer')).params);
  assert.ok(bioWire.includes('"@type":"setBio"'));
  assert.ok(bioWire.includes('"bio":"designer"'));
  const usernameWire = serializer.buildTdlibRequestJson('setUsername',
    serializer.serializeCommand(C.createSetProfileUsernameCommand('ann_lee')).params);
  assert.ok(usernameWire.includes('"@type":"setUsername"'));
  assert.ok(usernameWire.includes('"username":"ann_lee"'));

  // Validation ------------------------------------------------------------------------------------
  assert.equal(U.isValidProfileUsername('ann_lee'), true);
  assert.equal(U.isValidProfileUsername('a2345'), true, 'five characters is the minimum');
  assert.equal(U.isValidProfileUsername('a'.repeat(32)), true, 'thirty-two characters is the maximum');
  assert.equal(U.isValidProfileUsername('a234'), false, 'four characters is too short');
  assert.equal(U.isValidProfileUsername('a'.repeat(33)), false, 'thirty-three characters is too long');
  assert.equal(U.isValidProfileUsername('1ann_lee'), false, 'it must start with a letter');
  assert.equal(U.isValidProfileUsername('ann lee'), false, 'no spaces');
  assert.equal(U.isValidProfileUsername('ann-lee'), false, 'no dashes');
  assert.equal(U.isValidProfileUsername(''), false);
  assert.equal(U.PROFILE_USERNAME_MIN_LENGTH, 5);
  assert.equal(U.PROFILE_USERNAME_MAX_LENGTH, 32);
  assert.equal(U.isValidProfileNamePart(''), true, 'an empty last name is valid');
  assert.equal(U.isValidProfileNamePart('a'.repeat(64)), true);
  assert.equal(U.isValidProfileNamePart('a'.repeat(65)), false);
  assert.equal(U.isValidProfileBio('a'.repeat(70)), true);
  assert.equal(U.isValidProfileBio('a'.repeat(71)), false);

  // Use case --------------------------------------------------------------------------------------
  const sent = [];
  const ok = new U.EditProfileUseCase({
    send: (command) => {
      sent.push(command);
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
  });
  await ok.updateName('  Ann  ', ' Lee ');
  assert.equal(sent.at(-1).type, 'setName');
  assert.equal(sent.at(-1).payload.firstName, 'Ann', 'names are trimmed');
  assert.equal(sent.at(-1).payload.lastName, 'Lee');
  await ok.updateBio('  designer  ');
  assert.equal(sent.at(-1).type, 'setBio');
  assert.equal(sent.at(-1).payload.bio, 'designer');
  await ok.updateUsername('@ann_lee');
  assert.equal(sent.at(-1).type, 'setUsername');
  assert.equal(sent.at(-1).payload.username, 'ann_lee', 'a leading @ is dropped');
  await ok.updateUsername('');
  assert.equal(sent.at(-1).payload.username, '', 'an empty value removes the username');

  const before = sent.length;
  await assert.rejects(() => ok.updateName('   '), /First name is required/);
  await assert.rejects(() => ok.updateName('a'.repeat(65)), /Name is too long/);
  await assert.rejects(() => ok.updateBio('a'.repeat(71)), /Bio is too long/);
  await assert.rejects(() => ok.updateUsername('1bad'), /Invalid username/);
  await assert.rejects(() => ok.updateUsername('a'.repeat(33)), /Invalid username/);
  assert.equal(sent.length, before, 'invalid input never reaches the gateway');

  await assert.rejects(() => new U.EditProfileUseCase(
    { send: () => Promise.reject(new Error('native status')) }).updateBio('x'),
    /Failed to update the profile/);
  await assert.rejects(() => new U.EditProfileUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"error"}')) }).updateName('Ann'),
    /Profile update rejected/);
  await assert.rejects(() => new U.EditProfileUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).updateUsername('a'.repeat(33)),
    /Invalid username/, 'validation still runs on the success path');

  // Commands are registered for serialization.
  const commandsSource = read('core/model/AppCommand.ets');
  for (const name of ['SetProfileNameCommand', 'SetProfileBioCommand', 'SetProfileUsernameCommand']) {
    assert.ok(commandsSource.includes(name), 'command exists: ' + name);
  }
  const serializerSource = read('infra/td/serialization/CommandSerializer.ets');
  for (const method of ['setName', 'setBio', 'setUsername']) {
    assert.ok(serializerSource.includes(`COMMAND_SERIALIZATION_HANDLERS.set('${method}'`), method + ' is registered');
  }
  const useCaseSource = read('domain/usecases/editProfile.ets');
  assert.match(useCaseSource, /export function createEditProfileUseCase\(gateway: TdGatewayPort\): EditProfileUseCase/);
  assert.match(useCaseSource, /response\.getTopLevelStringStrict\('@type'\) !== 'ok'/);

  console.log('PASS profile editing contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
