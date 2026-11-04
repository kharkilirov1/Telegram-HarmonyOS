// S12h contract: chat invite links screen for admins (list, create, revoke) and the "Manage" submenu
// that reaches it. Executes the real DTO, use case and serializer; only the TDLib gateway is inert.

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

const hilog = { info() {}, warn() {}, error() {}, debug() {} };
const { TdObject } = load('models/td/common/index.ets', ['TdObject']);
const C = load('core/model/AppCommand.ets', ['createGetChatInviteLinksCommand',
  'createCreateChatInviteLinkCommand', 'createRevokeChatInviteLinkCommand', 'AppCommand']);
const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
const serializer = load('infra/td/serialization/CommandSerializer.ets',
  ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog });
const D = load('core/model/dto/ChatInviteLinkDto.ets',
  ['ChatInviteLinkDto', 'ChatInviteLinksDto', 'createChatInviteLinkFromTd',
    'createChatInviteLinksFromTd'], { TdObjectType: TdObject });
const U = load('domain/usecases/chatInviteLinks.ets',
  ['ChatInviteLinksUseCase', 'createChatInviteLinksUseCase', 'INVITE_LINK_PAGE_SIZE'],
  { ...C, ...errors, hilog, TdObject, ...D });

async function main() {
// DTO parsing --------------------------------------------------------------------------------------
const LINK_JSON = (overrides = {}) => JSON.stringify({
  '@type': 'chatInviteLink',
  invite_link: 'https://t.me/+AbCdEf',
  name: 'Welcome',
  creator_user_id: 7,
  date: 1730000000,
  expiration_date: 0,
  member_limit: 100,
  member_count: 12,
  pending_join_request_count: 3,
  creates_join_request: false,
  is_primary: false,
  is_revoked: false,
  ...overrides
});

const primary = D.createChatInviteLinkFromTd(TdObject.fromJSON(LINK_JSON({
  invite_link: 'https://t.me/joinchat/Primary', is_primary: true, member_limit: 0
})));
assert.equal(primary.inviteLink, 'https://t.me/joinchat/Primary');
assert.equal(primary.isPrimary, true);
assert.equal(primary.memberLimit, 0);
assert.equal(primary.memberCount, 12);
assert.equal(primary.pendingJoinRequestCount, 3);
assert.equal(primary.name, 'Welcome');

const page = D.createChatInviteLinksFromTd(TdObject.fromJSON(JSON.stringify({
  '@type': 'chatInviteLinks',
  total_count: 3,
  invite_links: [JSON.parse(LINK_JSON()), JSON.parse(LINK_JSON({ invite_link: 'https://t.me/+Second' })),
    JSON.parse(LINK_JSON({ invite_link: '' }))]
})));
assert.equal(page.totalCount, 3);
assert.equal(page.links.length, 2, 'links without an invite_link are dropped');
assert.equal(page.links[1].inviteLink, 'https://t.me/+Second');
assert.equal(D.createChatInviteLinksFromTd(TdObject.fromJSON('{"@type":"ok"}')), undefined);

// Use case -----------------------------------------------------------------------------------------
const sent = [];
const gateway = {
  send: (command) => {
    sent.push(command);
    if (command.type === 'getChatInviteLinks') {
      return Promise.resolve(TdObject.fromJSON(JSON.stringify({
        '@type': 'chatInviteLinks', total_count: 1, invite_links: [JSON.parse(LINK_JSON())]
      })));
    }
    if (command.type === 'createChatInviteLink') {
      return Promise.resolve(TdObject.fromJSON(LINK_JSON({ invite_link: 'https://t.me/+New', name: '' })));
    }
    return Promise.resolve(TdObject.fromJSON(JSON.stringify({
      '@type': 'chatInviteLinks', total_count: 0, invite_links: []
    })));
  }
};
const useCase = new U.ChatInviteLinksUseCase(gateway);
const loaded = await useCase.load(42);
assert.equal(loaded.links.length, 1);
assert.equal(sent.at(-1).type, 'getChatInviteLinks');
assert.equal(sent.at(-1).payload.limit, U.INVITE_LINK_PAGE_SIZE);
const loadWire = JSON.parse(serializer.buildTdlibRequestJson('getChatInviteLinks',
  serializer.serializeCommand(sent.at(-1)).params));
assert.equal(loadWire.chat_id, 42);
assert.equal(loadWire.is_revoked, false);
assert.equal(loadWire.limit, 50);

const created = await useCase.create(42);
assert.equal(created.inviteLink, 'https://t.me/+New');
const createWire = JSON.parse(serializer.buildTdlibRequestJson('createChatInviteLink',
  serializer.serializeCommand(sent.at(-1)).params));
assert.equal(createWire.chat_id, 42);
assert.equal(createWire.name, '');
assert.equal(createWire.member_limit, 0);
assert.equal(createWire.creates_join_request, false);

const revoked = await useCase.revoke(42, '  https://t.me/+AbCdEf  ');
assert.equal(revoked.links.length, 0);
const revokeWire = JSON.parse(serializer.buildTdlibRequestJson('revokeChatInviteLink',
  serializer.serializeCommand(sent.at(-1)).params));
assert.equal(revokeWire.chat_id, 42);
assert.equal(revokeWire.invite_link, 'https://t.me/+AbCdEf', 'the link is trimmed');

const sentBeforeValidation = sent.length;
await assert.rejects(() => useCase.load(0), /Invalid chatId/);
await assert.rejects(() => useCase.create(-1), /Invalid chatId/);
await assert.rejects(() => useCase.revoke(42, '   '), /Invalid invite link/);
assert.equal(sent.length, sentBeforeValidation, 'invalid input never reaches the gateway');
await assert.rejects(() => new U.ChatInviteLinksUseCase(
  { send: () => Promise.reject(new Error('native status')) }).load(42),
  /Failed to load invite links/);
await assert.rejects(() => new U.ChatInviteLinksUseCase(
  { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).create(42),
  /Invite link was not created/);

// Screen, route, submenu and labels ----------------------------------------------------------------
const screen = read('ui/pages/chat/TgChatInviteLinksPage.ets');
assert.match(screen, /export function TgChatInviteLinksPageBuilder\(\)/);
assert.match(screen, /createChatInviteLinksUseCase\(getTdGatewayAdapter\(\)\)/);
assert.match(screen, /useCase\.load\(this\.chatId\)/);
assert.match(screen, /useCase\.create\(this\.chatId\)/);
assert.match(screen, /useCase\.revoke\(this\.chatId, link\.inviteLink\)/);
assert.match(screen, /if \(useCase === undefined \|\| link\.isPrimary\) \{/);
assert.match(screen, /invite_links_primary/);
assert.match(screen, /invite_links_pending/);

const routes = JSON.parse(fs.readFileSync(
  path.join(root, '../resources/base/profile/route_map.json'), 'utf8'));
const route = routes.routerMap.find((item) => item.name === 'TgChatInviteLinksPage');
assert.ok(route, 'TgChatInviteLinksPage is registered');
assert.equal(route.buildFunction, 'TgChatInviteLinksPageBuilder');

const actions = read('ui/pages/chat/ChatActionsCoordinator.ets');
assert.match(actions, /private showManageMenu\(chatId: number, chat: Chat\): void \{/);
assert.match(actions, /push\(ChatMenuAction\.Manage, localized\(\$r\('app\.string\.chat_actions_manage'\)\.id, 'Manage'\), normal\);/);
assert.match(actions, /const actions: ChatMenuAction\[\] = \[ChatMenuAction\.Members, ChatMenuAction\.InviteLinks,\n      ChatMenuAction\.Administrators, ChatMenuAction\.Permissions, ChatMenuAction\.AutoDelete\];/);
assert.match(actions, /this\.host\.openInviteLinks\(chatId\)/);
assert.match(actions, /openInviteLinks\(chatId: number\): void \{/);
const chatPage = read('ui/pages/chat/TgChatScreenPage.ets');
assert.match(chatPage, /private openInviteLinksFromChat\(chatId: number\): void \{/);
assert.match(chatPage, /openInviteLinksScreen\(this\.queryNavigationInfo\(\)\?\.pathStack, chatId\)/);
const adminNav = read('ui/pages/chat/chatAdminNavigation.ets');
assert.match(adminNav, /stack\.pushPathByName\('TgChatInviteLinksPage', new ChatInviteLinksRouteParams\(chatId\)\)/);

for (const locale of ['base', 'ru_RU', 'zh_CN']) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, '../resources', locale, 'element/string.json'), 'utf8'));
  for (const name of ['chat_actions_manage', 'chat_actions_invite_links', 'invite_links_title',
    'invite_links_create', 'invite_links_loading', 'invite_links_failed',
    'invite_links_create_failed', 'invite_links_revoke_failed', 'invite_links_primary',
    'invite_links_joined', 'invite_links_pending']) {
    assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
  }
}

  console.log('PASS chat invite links contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
