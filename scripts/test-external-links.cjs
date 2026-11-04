// S14 contract: external t.me link intake, classification and folder-link routing.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;
const read = (relative) => fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');

function load(relative, deps = {}) {
  const text = read(relative);
  const names = [...text.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)]
    .map((match) => match[1]);
  const code = text.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '')
    .replace(/^export\s+type\s+\w+\s*=[^;]+;/gm, '')
    .replace(/^@ObservedV2\s*\n/gm, '').replace(/^(\s*)@Trace\s+/gm, '$1');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) +
    `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

const links = load('core/model/ExternalLink.ets');
const C = load('core/model/AppCommand.ets');
const errors = load('core/model/AppError.ets');
const { TdObject } = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', { TdObject });
const permissions = load('core/model/dto/GroupAccessDto.ets', { TdObject });
const chatDto = load('core/model/dto/ChatDto.ets',
  { TdObject, hilog: { info() {}, warn() {}, error() {}, debug() {} }, ...accessors, ...permissions, ...C });
const U = load('domain/usecases/resolveUsername.ets',
  { ...C, ...errors, hilog: { info() {}, warn() {}, error() {} }, TdObject,
    ChatDto: chatDto.ChatDto, createChatDtoFromTd: chatDto.createChatDtoFromTd });

async function runChecks() {
// Classification --------------------------------------------------------------------------------
const folder = links.classifyExternalLink('https://t.me/addlist/AbCd12');
assert.equal(folder.kind, 'folderInvite');
assert.equal(folder.value, 'https://t.me/addlist/AbCd12');

for (const uri of ['t.me/addlist/abc', 'HTTP://T.ME/addlist/abc/', 'https://telegram.me/addlist/abc',
  '  https://t.me/addlist/abc  ']) {
  const target = links.classifyExternalLink(uri);
  assert.equal(target.kind, 'folderInvite', 'folder link accepted: ' + uri);
  assert.equal(target.value, 'https://t.me/addlist/abc', 'normalized: ' + uri);
}

for (const uri of ['https://t.me/addlist/', 'https://t.me/addlist/   ',
  'https://example.com/addlist/abc', 'https://t.me/addlist']) {
  assert.equal(links.classifyExternalLink(uri).kind, 'unknown', 'not a folder link: ' + uri);
}

assert.equal(links.classifyExternalLink('https://t.me/+AbCdEf').kind, 'chatInvite');
assert.equal(links.classifyExternalLink('https://t.me/joinchat/AbCdEf').kind, 'chatInvite');
const username = links.classifyExternalLink('https://t.me/durov');
assert.equal(username.kind, 'username');
assert.equal(username.value, 'durov');
assert.equal(links.classifyExternalLink('https://t.me/durov/123').kind, 'unknown',
  'post links are not profiles');
assert.equal(links.classifyExternalLink('').kind, 'unknown');
assert.equal(links.classifyExternalLink('   ').kind, 'unknown');

// Intake is one-shot and trims the URI ---------------------------------------------------------
const intake = new links.ExternalLinkIntakeStore();
assert.equal(intake.hasPending(), false);
assert.equal(intake.take(), undefined);
intake.set('   ');
assert.equal(intake.hasPending(), false, 'blank links are ignored');
intake.set('  https://t.me/addlist/abc  ');
assert.equal(intake.hasPending(), true);
const taken = intake.take();
assert.equal(taken.kind, 'folderInvite');
assert.equal(taken.value, 'https://t.me/addlist/abc');
assert.equal(intake.hasPending(), false, 'the intake hands a link over once');
assert.equal(intake.take(), undefined);
intake.set('https://t.me/addlist/xyz');
intake.clear();
assert.equal(intake.hasPending(), false);

// Username resolution ---------------------------------------------------------------------------
for (const valid of ['durov', 'telegram', 'a_b1', 'x'.repeat(32)]) {
  assert.equal(U.isValidUsername(valid), true, 'accepted username: ' + valid);
}
for (const invalid of ['', 'abc', '1abc', 'with space', 'with-dash', 'x'.repeat(33), 'user!']) {
  assert.equal(U.isValidUsername(invalid), false, 'rejected username: ' + invalid);
}

const CHAT_TEXT = '{"@type":"chat","id":42,"title":"Durov","type":' +
  '{"@type":"chatTypePrivate","user_id":7}}';
const sent = [];
const resolveUseCase = new U.ResolveUsernameUseCase({ send: (command) => {
  sent.push(command);
  return Promise.resolve(TdObject.fromJSON(CHAT_TEXT));
} });
const resolved = await resolveUseCase.resolve('  durov  ');
assert.equal(sent.at(-1).type, 'searchPublicChat');
assert.equal(sent.at(-1).payload.username, 'durov', 'the username is trimmed');
assert.equal(resolved.id, 42);
assert.equal(resolved.title, 'Durov');
await assert.rejects(() => resolveUseCase.resolve('bad name'), /Invalid username/);
assert.equal(sent.length, 1, 'invalid usernames never reach the gateway');
await assert.rejects(() => new U.ResolveUsernameUseCase(
  { send: () => Promise.reject(new Error('native status')) }).resolve('durov'),
  /Failed to open the username/);
await assert.rejects(() => new U.ResolveUsernameUseCase(
  { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).resolve('durov'),
  /Username not found/);

// Wiring ---------------------------------------------------------------------------------------
const ability = read('entryability/EntryAbility.ets');
assert.match(ability, /import \{ externalLinkIntake \} from '\.\.\/core\/model\/ExternalLink';/);
assert.match(ability, /onCreate\(want: Want, _launchParam: AbilityConstant\.LaunchParam\): void \{/);
assert.match(ability, /onNewWant\(want: Want, _launchParam: AbilityConstant\.LaunchParam\): void \{/);
assert.match(ability, /private captureExternalLink\(want: Want\): void \{/);
assert.match(ability, /externalLinkIntake\.set\(uri\)/);

const tabs = read('ui/pages/MainTabsPage.ets');
assert.match(tabs, /else if \(target\.kind === 'username'\) \{/);
assert.match(tabs, /this\.openUsernameLink\(target\.value\)/);
assert.match(tabs, /private openUsernameLink\(username: string\): void \{/);
assert.match(tabs, /resolveUsernameUseCase\(gateway\)\.resolve\(username\)/);
assert.match(tabs, /store\.dispatch\(createNewChatEvent\(chat\.id, chat\)\)/);
assert.match(tabs, /pushChatScreenRoute\(new ChatScreenRouteParams\(chat\.id, chat\.title, store, gateway\)/);
assert.match(tabs, /private usernameOpenToken: number = 0;/);
assert.match(tabs, /external_link_failed/);
assert.match(tabs, /this\.consumeExternalLink\(\);/);
assert.match(tabs, /private consumeExternalLink\(\): void \{/);
assert.match(tabs, /externalLinkIntake\.take\(\)/);
assert.match(tabs, /if \(target\.kind === 'folderInvite'\) \{/);
assert.match(tabs, /this\.chatDetailNavStack\.pushPathByName\('TgFolderLinkPage', params\)/);
assert.match(tabs, /import \{ FolderLinkRouteParams \} from '\.\/settings\/folderLinkRoute';/);

for (const locale of ['base', 'ru_RU', 'zh_CN']) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
  assert.ok(strings.string.some((entry) => entry.name === 'external_link_failed'),
    'external_link_failed exists in ' + locale);
}

const page = read('ui/pages/settings/TgFolderLinkPage.ets');
assert.match(page, /import \{ FolderLinkRouteParams \} from '\.\/folderLinkRoute';/);
assert.match(page, /const routeParams = params\[0\] as FolderLinkRouteParams;/);
assert.match(page, /this\.linkDraft = link;/);
assert.match(page, /this\.checkLink\(\);/);

const moduleJson = JSON.parse(fs.readFileSync(path.join(root, 'entry/src/main/module.json5'), 'utf8'));
const skills = moduleJson.module.abilities[0].skills;
const browsable = skills.find((skill) => (skill.entities ?? []).includes('entity.system.browsable'));
assert.ok(browsable, 'a browsable skill is registered');
assert.ok((browsable.actions ?? []).includes('ohos.want.action.viewData'));
const uris = browsable.uris ?? [];
assert.ok(uris.some((uri) => uri.scheme === 'https' && uri.host === 't.me' &&
  uri.pathStartWith === 'addlist'), 't.me/addlist is declared');
assert.ok(uris.some((uri) => uri.scheme === 'https' && uri.host === 'telegram.me' &&
  uri.pathStartWith === 'addlist'), 'telegram.me/addlist is declared');

  console.log('PASS external link routing contract');
}

runChecks().catch((error) => {
  console.error(error);
  process.exit(1);
});
