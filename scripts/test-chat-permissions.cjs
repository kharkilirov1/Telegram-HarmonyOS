// S12j contract: participant permissions screen (getChat → chat.permissions, setChatPermissions) and the
// Manage submenu entry. Executes real DTO, use case and serializer; only the TDLib gateway is inert.

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
    ['createGetChatCommand', 'createSetChatPermissionsCommand', 'SetChatPermissionsPayload',
      'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog });
  const D = load('core/model/dto/ChatPermissionsDto.ets',
    ['ChatPermissionsDto', 'createChatPermissionsFromTd', 'chatPermissionsToJson'],
    { TdObjectType: TdObject });
  const U = load('domain/usecases/chatPermissions.ets',
    ['ChatPermissionsUseCase', 'createChatPermissionsUseCase'],
    { ...C, ...errors, hilog, TdObject, ...D });

  // DTO and JSON round trip ------------------------------------------------------------------------
  const permissions = D.createChatPermissionsFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'chatPermissions',
    can_send_basic_messages: true,
    can_send_audios: false,
    can_send_documents: true,
    can_send_photos: false,
    can_send_videos: true,
    can_send_video_notes: false,
    can_send_voice_notes: true,
    can_send_polls: false,
    can_send_other_messages: true,
    can_add_link_previews: false,
    can_change_info: true,
    can_invite_users: false,
    can_pin_messages: true,
    can_create_topics: false
  })));
  assert.equal(permissions.canSendBasicMessages, true);
  assert.equal(permissions.canSendDocuments, true);
  assert.equal(permissions.canCreateTopics, false);
  const json = JSON.parse(D.chatPermissionsToJson(permissions));
  assert.equal(json['@type'], 'chatPermissions');
  assert.equal(json.can_send_basic_messages, true);
  assert.equal(json.can_create_topics, false);
  assert.equal(Object.keys(json).length, 15, 'all fourteen bits are written back');
  const clone = permissions.clone();
  clone.canSendBasicMessages = false;
  assert.equal(permissions.canSendBasicMessages, true, 'clone is independent');
  assert.equal(D.createChatPermissionsFromTd(TdObject.fromJSON('{"@type":"ok"}')), undefined);

  // Use case and wire ------------------------------------------------------------------------------
  const sent = [];
  const useCase = new U.ChatPermissionsUseCase({
    send: (command) => {
      sent.push(command);
      if (command.type === 'getChat') {
        return Promise.resolve(TdObject.fromJSON(JSON.stringify({
          '@type': 'chat', id: 42, title: 'Group',
          permissions: JSON.parse(D.chatPermissionsToJson(permissions))
        })));
      }
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
  });
  const loaded = await useCase.load(42);
  assert.equal(loaded.canSendBasicMessages, true);
  assert.equal(sent.at(-1).type, 'getChat');
  await useCase.save(42, loaded);
  assert.equal(sent.at(-1).type, 'setChatPermissions');
  const saveWire = JSON.parse(serializer.buildTdlibRequestJson('setChatPermissions',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(saveWire.chat_id, 42);
  assert.equal(saveWire.permissions['@type'], 'chatPermissions');
  assert.equal(saveWire.permissions.can_send_basic_messages, true);
  assert.equal(saveWire.permissions.can_create_topics, false);

  const sentBefore = sent.length;
  await assert.rejects(() => useCase.load(0), /Invalid chatId/);
  await assert.rejects(() => useCase.save(-1, permissions), /Invalid chatId/);
  assert.equal(sent.length, sentBefore, 'invalid chat ids never reach the gateway');
  await assert.rejects(() => new U.ChatPermissionsUseCase(
    { send: () => Promise.reject(new Error('native status')) }).load(42),
    /Failed to load permissions/);
  await assert.rejects(() => new U.ChatPermissionsUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).load(42),
    /Unsupported chat response/);
  await assert.rejects(() => new U.ChatPermissionsUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"chat","id":1}')) }).load(42),
    /Chat has no permissions/);
  await assert.rejects(() => new U.ChatPermissionsUseCase(
    { send: () => Promise.reject(new Error('native status')) }).save(42, permissions),
    /Failed to save permissions/);

  // Screen, route, submenu and labels --------------------------------------------------------------
  const screen = read('ui/pages/chat/TgChatPermissionsPage.ets');
  assert.match(screen, /export function TgChatPermissionsPageBuilder\(\)/);
  assert.match(screen, /createChatPermissionsUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(screen, /useCase\.load\(this\.chatId\)/);
  assert.match(screen, /useCase\.save\(this\.chatId, next\)/);
  assert.match(screen, /struct PermissionToggleRow/);
  assert.match(screen, /this\.permissions = previous;/, 'a rejected write restores the toggle');
  assert.equal((screen.match(/PermissionToggleRow\(\{/g) || []).length, 14, 'all fourteen toggles');

  const routes = JSON.parse(fs.readFileSync(
    path.join(root, '../resources/base/profile/route_map.json'), 'utf8'));
  const route = routes.routerMap.find((item) => item.name === 'TgChatPermissionsPage');
  assert.ok(route, 'TgChatPermissionsPage is registered');
  assert.equal(route.buildFunction, 'TgChatPermissionsPageBuilder');

  const actions = read('ui/pages/chat/ChatActionsCoordinator.ets');
  assert.match(actions,
    /ChatMenuAction\.Administrators, ChatMenuAction\.Permissions, ChatMenuAction\.AutoDelete,\n      ChatMenuAction\.Scheduled\];/);
  assert.match(actions, /text: localized\(\$r\('app\.string\.chat_actions_permissions'\)\.id, 'Permissions'\), color: normal \};/);
  assert.match(actions, /this\.host\.openPermissions\(chatId\)/);
  const chatPage = read('ui/pages/chat/TgChatScreenPage.ets');
  assert.match(chatPage, /private openPermissionsFromChat\(chatId: number\): void \{/);
  assert.match(chatPage, /openPermissionsScreen\(this\.queryNavigationInfo\(\)\?\.pathStack, chatId\)/);
  const adminNav = read('ui/pages/chat/chatAdminNavigation.ets');
  assert.match(adminNav,
    /stack\.pushPathByName\('TgChatPermissionsPage', new ChatPermissionsRouteParams\(chatId\)\)/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['chat_actions_permissions', 'permissions_title', 'permissions_loading',
      'permissions_failed', 'permissions_save_failed', 'permissions_send_messages',
      'permissions_send_audios', 'permissions_send_documents', 'permissions_send_photos',
      'permissions_send_videos', 'permissions_send_video_notes', 'permissions_send_voice_notes',
      'permissions_send_polls', 'permissions_send_other', 'permissions_link_previews',
      'permissions_change_info', 'permissions_invite_users', 'permissions_pin_messages',
      'permissions_create_topics']) {
      assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
    }
  }

  console.log('PASS chat permissions contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
