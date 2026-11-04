// S12i contract: chat administrators list (getChatAdministrators), the screen and the Manage submenu
// entry. Executes real DTO, use case and serializer; only the TDLib gateway is inert.

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
    ['createGetChatAdministratorsCommand', 'GetChatAdministratorsPayload', 'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog });
  const D = load('core/model/dto/ChatAdministratorDto.ets',
    ['ChatAdministratorDto', 'ChatAdministratorsDto', 'createChatAdministratorsFromTd'],
    { TdObjectType: TdObject });
  const U = load('domain/usecases/chatAdministrators.ets',
    ['ChatAdministratorsUseCase', 'createChatAdministratorsUseCase'],
    { ...C, ...errors, hilog, TdObject, ...D });

  // DTO parsing ------------------------------------------------------------------------------------
  const parsed = D.createChatAdministratorsFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'chatAdministrators',
    administrators: [
      { '@type': 'chatAdministrator', user_id: 7, custom_title: 'Founder', is_owner: true },
      { '@type': 'chatAdministrator', user_id: 9, custom_title: '', is_owner: false },
      { '@type': 'chatAdministrator', user_id: 0, custom_title: 'invalid', is_owner: false },
      { '@type': 'ok' }
    ]
  })));
  assert.equal(parsed.administrators.length, 2, 'invalid entries are dropped');
  assert.equal(parsed.administrators[0].userId, 7);
  assert.equal(parsed.administrators[0].customTitle, 'Founder');
  assert.equal(parsed.administrators[0].isOwner, true);
  assert.equal(parsed.administrators[1].isOwner, false);
  assert.equal(D.createChatAdministratorsFromTd(TdObject.fromJSON('{"@type":"ok"}')), undefined);
  assert.deepEqual(D.createChatAdministratorsFromTd(
    TdObject.fromJSON('{"@type":"chatAdministrators"}')).administrators, []);

  // Use case and wire ------------------------------------------------------------------------------
  const sent = [];
  const useCase = new U.ChatAdministratorsUseCase({
    send: (command) => {
      sent.push(command);
      return Promise.resolve(TdObject.fromJSON(JSON.stringify({
        '@type': 'chatAdministrators',
        administrators: [{ '@type': 'chatAdministrator', user_id: 7, custom_title: 'Founder', is_owner: true }]
      })));
    }
  });
  const loaded = await useCase.load(42);
  assert.equal(loaded.administrators.length, 1);
  assert.equal(sent.at(-1).type, 'getChatAdministrators');
  assert.equal(sent.at(-1).payload.chatId, 42);
  const wire = JSON.parse(serializer.buildTdlibRequestJson('getChatAdministrators',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(wire.chat_id, 42);

  const sentBefore = sent.length;
  await assert.rejects(() => useCase.load(0), /Invalid chatId/);
  await assert.rejects(() => useCase.load(-5), /Invalid chatId/);
  assert.equal(sent.length, sentBefore, 'invalid chat ids never reach the gateway');
  await assert.rejects(() => new U.ChatAdministratorsUseCase(
    { send: () => Promise.reject(new Error('native status')) }).load(42),
    /Failed to load administrators/);
  await assert.rejects(() => new U.ChatAdministratorsUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).load(42),
    /Unsupported administrators response/);

  // Screen, route, submenu and labels --------------------------------------------------------------
  const screen = read('ui/pages/chat/TgChatAdministratorsPage.ets');
  assert.match(screen, /export function TgChatAdministratorsPageBuilder\(\)/);
  assert.match(screen, /createChatAdministratorsUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(screen, /useCase\.load\(this\.chatId\)/);
  assert.match(screen, /administrators_owner/);
  assert.match(screen, /administrators_unknown_user/);
  assert.match(screen, /administrators_empty/);
  assert.match(screen, /\.get\(admin\.userId\)/);
  // Tap opens the user profile through the exported params + context helper.
  assert.match(screen, /private openProfile\(admin: ChatAdministratorDto\): void \{/);
  assert.match(screen, /new DirectUserProfileRouteParams\(admin\.userId, captureProfileLoadContext\(\)\)/);
  assert.match(screen, /this\.pageStack\.pushPathByName\('TgProfilePage',/);
  const membersPage = read('ui/pages/profile/TgProfileMembersPage.ets');
  assert.match(membersPage, /export class DirectUserProfileRouteParams \{/, 'params are exported');
  const loadInfo = read('domain/usecases/loadProfileInfo.ets');
  assert.match(loadInfo, /export function captureProfileLoadContext\(\): ProfileLoadContext \{/, 'context helper is exported');

  const routes = JSON.parse(fs.readFileSync(
    path.join(root, '../resources/base/profile/route_map.json'), 'utf8'));
  const route = routes.routerMap.find((item) => item.name === 'TgChatAdministratorsPage');
  assert.ok(route, 'TgChatAdministratorsPage is registered');
  assert.equal(route.buildFunction, 'TgChatAdministratorsPageBuilder');

  const actions = read('ui/pages/chat/ChatActionsCoordinator.ets');
  assert.match(actions,
    /const actions: ChatMenuAction\[\] = \[ChatMenuAction\.Members, ChatMenuAction\.InviteLinks,\n      ChatMenuAction\.Administrators, ChatMenuAction\.Permissions, ChatMenuAction\.AutoDelete,\n      ChatMenuAction\.Scheduled\];/);
  assert.match(actions, /text: localized\(\$r\('app\.string\.chat_actions_administrators'\)\.id, 'Administrators'\), color: normal \};/);
  assert.match(actions, /this\.host\.openAdministrators\(chatId\)/);
  assert.match(actions, /openAdministrators\(chatId: number\): void \{/);

  const chatPage = read('ui/pages/chat/TgChatScreenPage.ets');
  assert.match(chatPage, /private openAdministratorsFromChat\(chatId: number\): void \{/);
  assert.match(chatPage, /openAdministratorsScreen\(this\.queryNavigationInfo\(\)\?\.pathStack, chatId\)/);
  const adminNav = read('ui/pages/chat/chatAdminNavigation.ets');
  assert.match(adminNav,
    /stack\.pushPathByName\('TgChatAdministratorsPage', new ChatAdministratorsRouteParams\(chatId\)\)/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['chat_actions_administrators', 'administrators_title', 'administrators_loading',
      'administrators_failed', 'administrators_empty', 'administrators_owner',
      'administrators_unknown_user']) {
      assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
    }
  }

  console.log('PASS chat administrators contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
