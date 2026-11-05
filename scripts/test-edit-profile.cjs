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
  const accessors = load('core/utils/tdAccessors.ets',
    ['tdGetNumber', 'tdGetString', 'tdGetBoolean', 'tdGetObject', 'tdGetArray', 'tdGetInt64',
      'tdHasKeys', 'compareInt64'], { TdObject });
  const C = load('core/model/AppCommand.ets',
    ['createSetProfileNameCommand', 'createSetProfileBioCommand', 'createSetProfileUsernameCommand',
      'createSetProfilePhotoCommand', 'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog, ...errors });
  const U = load('domain/usecases/editProfile.ets',
    ['EditProfileUseCase', 'createEditProfileUseCase', 'isValidProfileUsername',
      'isUsernameTakenError', 'suggestProfileUsernameAlternatives', 'isValidProfileNamePart',
      'isValidProfileBio', 'PROFILE_NAME_PART_MAX_LENGTH', 'PROFILE_BIO_MAX_LENGTH',
      'PROFILE_USERNAME_MIN_LENGTH', 'PROFILE_USERNAME_MAX_LENGTH'],
    { ...C, ...errors, TdObject, hilog, ...accessors });

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

  // Avatar wire: a local file goes straight into inputChatPhotoStatic.
  const photoWire = serializer.buildTdlibRequestJson('setProfilePhoto',
    serializer.serializeCommand(C.createSetProfilePhotoCommand('/data/photo.jpg', true)).params);
  assert.ok(photoWire.includes('"@type":"setProfilePhoto"'));
  assert.ok(photoWire.includes('"@type":"inputChatPhotoStatic"'));
  assert.ok(photoWire.includes('"@type":"inputFileLocal"'));
  assert.ok(photoWire.includes('"path":"/data/photo.jpg"'));
  assert.ok(photoWire.includes('"is_public":true'));

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
  await ok.updatePhoto('  /data/photo.jpg  ');
  assert.equal(sent.at(-1).type, 'setProfilePhoto');
  assert.equal(sent.at(-1).payload.photoPath, '/data/photo.jpg', 'the path is trimmed');
  assert.equal(sent.at(-1).payload.isPublic, true);
  await ok.updatePhoto('/data/private.jpg', false);
  assert.equal(sent.at(-1).payload.isPublic, false, 'a private photo is supported');

  const before = sent.length;
  await assert.rejects(() => ok.updateName('   '), /First name is required/);
  await assert.rejects(() => ok.updateName('a'.repeat(65)), /Name is too long/);
  await assert.rejects(() => ok.updateBio('a'.repeat(71)), /Bio is too long/);
  await assert.rejects(() => ok.updateUsername('1bad'), /Invalid username/);
  await assert.rejects(() => ok.updateUsername('a'.repeat(33)), /Invalid username/);
  await assert.rejects(() => ok.updatePhoto('   '), /No photo selected/);
  assert.equal(sent.length, before, 'invalid input never reaches the gateway');

  await assert.rejects(() => new U.EditProfileUseCase(
    { send: () => Promise.reject(new Error('native status')) }).updateBio('x'),
    /Failed to update the profile/);
  await assert.rejects(() => new U.EditProfileUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"error"}')) }).updateName('Ann'),
    /Failed to update the profile/);
  await assert.rejects(() => new U.EditProfileUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).updateUsername('a'.repeat(33)),
    /Invalid username/, 'validation still runs on the success path');

  // Commands are registered for serialization.
  const commandsSource = read('core/model/AppCommand.ets');
  for (const name of ['SetProfileNameCommand', 'SetProfileBioCommand', 'SetProfileUsernameCommand']) {
    assert.ok(commandsSource.includes(name), 'command exists: ' + name);
  }
  const serializerSource = read('infra/td/serialization/CommandSerializer.ets');
  for (const method of ['setName', 'setBio', 'setUsername', 'setProfilePhoto']) {
    assert.ok(serializerSource.includes(`COMMAND_SERIALIZATION_HANDLERS.set('${method}'`), method + ' is registered');
  }
  const useCaseSource = read('domain/usecases/editProfile.ets');
  assert.match(useCaseSource, /export function createEditProfileUseCase\(gateway: TdGatewayPort\): EditProfileUseCase/);
  assert.match(useCaseSource, /response\.getTopLevelStringStrict\('@type'\) !== 'ok'/);

  const gatewayReturning = (response) => ({ send: () => Promise.resolve(response) });

  // A taken username is recognised and alternatives are offered -----------------------------------
  const occupied = new U.EditProfileUseCase(gatewayReturning(TdObject.fromJSON('{"@type":"error","code":400,"message":"USERNAME_OCCUPIED"}')));
  let occupiedError;
  try {
    await occupied.updateUsername('taken');
  } catch (error) {
    occupiedError = error;
  }
  assert.ok(occupiedError, 'a taken username fails');
  assert.equal(U.isUsernameTakenError(occupiedError), true);
  assert.equal(occupiedError.userMessage, 'This username is already taken');
  assert.equal(occupiedError.tdlibCode, 400);
  assert.equal(occupiedError.requestRejected, true);

  const invalidName = new U.EditProfileUseCase(gatewayReturning(TdObject.fromJSON('{"@type":"error","code":400,"message":"USERNAME_INVALID"}')));
  let invalidError;
  try {
    await invalidName.updateUsername('validname1');
  } catch (error) {
    invalidError = error;
  }
  assert.equal(U.isUsernameTakenError(invalidError), false, 'invalid is not taken');
  assert.equal(invalidError.userMessage, 'This username is invalid');

  const otherError = new U.EditProfileUseCase(gatewayReturning(TdObject.fromJSON('{"@type":"error","code":500,"message":"SOMETHING_ELSE"}')));
  let genericError;
  try {
    await otherError.updateBio('hello');
  } catch (error) {
    genericError = error;
  }
  assert.equal(U.isUsernameTakenError(genericError), false);
  assert.equal(genericError.userMessage, 'Failed to update the profile');

  assert.deepEqual(U.suggestProfileUsernameAlternatives('alex'), ['alex_1', 'alex_2', 'alex_3']);
  assert.deepEqual(U.suggestProfileUsernameAlternatives('@alex!'), ['alex_1', 'alex_2', 'alex_3'],
    'the @ and invalid characters are stripped');
  assert.deepEqual(U.suggestProfileUsernameAlternatives(''), ['user_1', 'user_2', 'user_3'],
    'an empty base falls back to a neutral prefix');
  const longBase = 'a' + 'b'.repeat(35);
  const longSuggestions = U.suggestProfileUsernameAlternatives(longBase);
  assert.ok(longSuggestions.length > 0);
  for (const suggestion of longSuggestions) {
    assert.ok(suggestion.length <= 32, 'suggestions respect the upper bound');
    assert.ok(U.isValidProfileUsername(suggestion), 'suggestions are valid usernames');
  }
  for (const suggestion of U.suggestProfileUsernameAlternatives('9lives')) {
    assert.ok(/^[A-Za-z]/.test(suggestion), 'a suggestion always starts with a letter');
  }

  // Page and entry point -------------------------------------------------------------------------
  const page = read('ui/pages/settings/TgEditProfilePage.ets');
  assert.match(page, /export class EditProfileRouteParams/);
  assert.match(page, /export function TgEditProfilePageBuilder\(\)/);
  assert.match(page, /@ComponentV2/);
  assert.match(page, /@Local private firstName: string = '';/);
  assert.match(page, /@Local private saving: boolean = false;/);
  assert.match(page, /getParamByName\('TgEditProfilePage'\)/, 'the page reads its route params');
  assert.match(page, /useCase\.updateName\(this\.firstName, this\.lastName\)/);
  assert.match(page, /useCase\.updateUsername\(username\)/);
  assert.match(page, /useCase\.updateBio\(this\.bio\)/);
  assert.match(page, /this\.pageStack\.pop\(true\);/, 'a saved profile closes the page');
  assert.match(page, /private canSave\(\): boolean \{/);
  assert.match(page, /isValidProfileUsername\(username\)/, 'the save gate uses the shared validator');
  assert.match(page, /maxLength\(PROFILE_NAME_PART_MAX_LENGTH\)/);
  assert.match(page, /maxLength\(PROFILE_BIO_MAX_LENGTH\)/);
  assert.match(page, /this\.errorText = error\.message;/, 'a rejected update stays on screen');
  assert.match(page, /localized\(\$r\('app\.string\.edit_profile_save'\)\.id, 'Save'\)/);
  assert.match(page, /import \{ photoAccessHelper \} from '@kit\.MediaLibraryKit';/);
  assert.match(page, /import \{ photoAccessHelper \} from '@kit\.MediaLibraryKit';/);
  assert.match(page, /private pickProfilePhoto\(\): void \{/);
  assert.match(page, /maxSelectNumber: 1/);
  assert.match(page, /private copyPickedPhoto\(sourceUri: string\): Promise<string> \{/);
  assert.match(page, /import \{ AvatarImagePreparation \} from '\.\/avatarImagePrep';/);
  assert.match(page, /return AvatarImagePreparation\.prepare\(context, sourceUri\);/);
  assert.match(page, /useCase\.updatePhoto\(localPath\)/);
  assert.match(page, /edit_profile_change_photo/);

  const routes = JSON.parse(fs.readFileSync(path.join(root, '../module.json5'), 'utf8'));
  assert.ok(routes.module);
  const routeMap = JSON.parse(fs.readFileSync(path.join(
    root, '../resources/base/profile/route_map.json'), 'utf8'));
  const route = routeMap.routerMap.find((item) => item.name === 'TgEditProfilePage');
  assert.ok(route, 'the editor is registered in the system route table');
  assert.equal(route.buildFunction, 'TgEditProfilePageBuilder');
  assert.ok(route.pageSourceFile.includes('TgEditProfilePage.ets'));

  const settings = read('ui/pages/settings/SettingsPage.ets');
  assert.match(settings, /@Event onOpenEditProfile: \(\) => void/);
  assert.match(settings, /this\.userFirstName = user\.firstName;/);
  assert.match(settings, /this\.onOpenEditProfile\(\);/, 'the profile header is the entry point');

  const tabs = read('ui/pages/MainTabsPage.ets');
  assert.match(tabs, /private pushEditProfile\(\): void \{/);
  assert.match(tabs, /new EditProfileRouteParams\(/);
  assert.match(tabs, /this\.chatDetailNavStack\.pushPathByName\('TgEditProfilePage', params\)/);

  assert.match(page, /@Local private usernameTaken: boolean = false;/);
  assert.match(page, /@Local private usernameSuggestions: string\[\] = \[\];/);
  assert.match(page, /if \(isUsernameTakenError\(error\)\) \{/);
  assert.match(page, /this\.usernameSuggestions = suggestProfileUsernameAlternatives\(this\.username\);/);
  assert.match(page, /private applySuggestion\(value: string\): void \{/);
  assert.match(page, /ForEach\(this\.usernameSuggestions, \(suggestion: string\) => \{/);
  assert.match(page, /edit_profile_username_taken/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(path.join(
      root, '../resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['edit_profile_title', 'edit_profile_first_name', 'edit_profile_last_name',
      'edit_profile_username', 'edit_profile_bio', 'edit_profile_save', 'edit_profile_saving',
      'edit_profile_username_hint', 'edit_profile_change_photo', 'edit_profile_photo_busy',
      'edit_profile_photo_updated', 'edit_profile_username_taken']) {
      assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
    }
  }

  console.log('PASS profile editing contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
