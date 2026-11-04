// G6 contract: per-member moderation (setChatMemberStatus with member/banned/restricted states),
// the member-row long-press menu, and the member status wire shapes.

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
    ['createSetChatMemberStatusCommand', 'AppCommand', 'ChatAdminRightsPayload']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog });
  const U = load('domain/usecases/chatMemberAdmin.ets',
    ['ChatMemberAdminUseCase', 'createChatMemberAdminUseCase', 'memberStatusKind',
      'MODERATION_DURATION_SECONDS', 'MODERATION_DURATION_OPTIONS', 'moderationUntilDate'],
    { ...C, ...errors, hilog });

  // Action → status mapping ------------------------------------------------------------------------
  assert.equal(U.memberStatusKind('ban'), 'banned');
  assert.equal(U.memberStatusKind('unban'), 'member');
  assert.equal(U.memberStatusKind('restrict'), 'restricted');
  assert.equal(U.memberStatusKind('promote'), 'administrator');
  assert.equal(U.memberStatusKind('demote'), 'member');

  // Wire shapes ------------------------------------------------------------------------------------
  const sent = [];
  const useCase = new U.ChatMemberAdminUseCase({
    send: (command) => {
      sent.push(command);
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
  });
  await useCase.apply(42, 7, 'ban');
  assert.equal(sent.at(-1).type, 'setChatMemberStatus');
  let wire = JSON.parse(serializer.buildTdlibRequestJson('setChatMemberStatus',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(wire.chat_id, 42);
  assert.equal(wire.member_id['@type'], 'messageSenderUser');
  assert.equal(wire.member_id.user_id, 7);
  assert.equal(wire.status['@type'], 'chatMemberStatusBanned');
  assert.equal(wire.status.banned_until_date, 0, '0 means forever');

  await useCase.apply(42, 7, 'unban');
  wire = JSON.parse(serializer.buildTdlibRequestJson('setChatMemberStatus',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(wire.status['@type'], 'chatMemberStatusMember');

  await useCase.apply(42, 7, 'restrict', 1999999999);
  wire = JSON.parse(serializer.buildTdlibRequestJson('setChatMemberStatus',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(wire.status['@type'], 'chatMemberStatusRestricted');
  assert.equal(wire.status.is_member, true, 'a restricted member stays in the chat');
  assert.equal(wire.status.restricted_until_date, 1999999999);
  const permissions = wire.status.permissions;
  assert.equal(permissions['@type'], 'chatPermissions');
  for (const key of ['can_send_basic_messages', 'can_send_audios', 'can_send_documents',
    'can_send_photos', 'can_send_videos', 'can_send_video_notes', 'can_send_voice_notes',
    'can_send_polls', 'can_send_other_messages', 'can_add_link_previews', 'can_change_info',
    'can_invite_users', 'can_pin_messages', 'can_create_topics']) {
    assert.equal(permissions[key], false, key + ' must be false when restricting');
  }

  await useCase.apply(42, 7, 'promote');
  wire = JSON.parse(serializer.buildTdlibRequestJson('setChatMemberStatus',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(wire.status['@type'], 'chatMemberStatusAdministrator');
  const rights = wire.status.rights;
  assert.equal(rights['@type'], 'chatAdministratorRights');
  for (const key of ['can_manage_chat', 'can_change_info', 'can_post_messages', 'can_edit_messages',
    'can_delete_messages', 'can_invite_users', 'can_restrict_members', 'can_pin_messages',
    'can_manage_topics', 'can_promote_members', 'can_manage_video_chats', 'can_post_stories',
    'can_edit_stories', 'can_delete_stories', 'can_manage_direct_messages', 'is_anonymous']) {
    assert.equal(rights[key], false, key + ' defaults to false for a fresh administrator');
  }

  await useCase.apply(42, 7, 'demote');
  wire = JSON.parse(serializer.buildTdlibRequestJson('setChatMemberStatus',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(wire.status['@type'], 'chatMemberStatusMember', 'demote restores plain membership');

  // Timed moderation ------------------------------------------------------------------------------
  assert.deepEqual(U.MODERATION_DURATION_SECONDS, [3600, 86400, 7 * 86400, 0]);
  assert.deepEqual(U.MODERATION_DURATION_OPTIONS.map((option) => option.seconds),
    [3600, 86400, 7 * 86400, 0]);
  assert.equal(U.moderationUntilDate(1000, 3600), 4600);
  assert.equal(U.moderationUntilDate(1000, 86400), 87400);
  assert.equal(U.moderationUntilDate(1000, 7 * 86400), 605800);
  assert.equal(U.moderationUntilDate(1000, 0), 0, 'zero duration means forever');
  assert.equal(U.moderationUntilDate(-5, 3600), 0);
  assert.equal(U.moderationUntilDate(1000, -1), 0);
  assert.equal(U.moderationUntilDate(1000, 1.5), 0);

  await useCase.apply(42, 7, 'restrict', U.moderationUntilDate(1000, 3600));
  wire = JSON.parse(serializer.buildTdlibRequestJson('setChatMemberStatus',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(wire.status.restricted_until_date, 4600, 'a timed restriction carries the deadline');

  await useCase.apply(42, 7, 'ban', U.moderationUntilDate(1000, 86400));
  wire = JSON.parse(serializer.buildTdlibRequestJson('setChatMemberStatus',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(wire.status['@type'], 'chatMemberStatusBanned');
  assert.equal(wire.status.banned_until_date, 87400, 'a timed ban carries the deadline');

  // Validation and failures ------------------------------------------------------------------------
  const before = sent.length;
  await assert.rejects(() => useCase.apply(0, 7, 'ban'), /Invalid chatId/);
  await assert.rejects(() => useCase.apply(42, 0, 'ban'), /Invalid userId/);
  await assert.rejects(() => useCase.apply(42, 7, 'ban', -1), /Invalid until date/);
  await assert.rejects(() => useCase.apply(42, 7, 'ban', 1.5), /Invalid until date/);
  assert.equal(sent.length, before, 'invalid input never reaches the gateway');
  await assert.rejects(() => new U.ChatMemberAdminUseCase(
    { send: () => Promise.reject(new Error('native status')) }).apply(42, 7, 'ban'),
    /Failed to update the member/);

  // UI wiring --------------------------------------------------------------------------------------
  const row = read('ui/tg_ui/atoms/TgProfileMemberRow.ets');
  assert.match(row, /@Event onLongPress: \(\) => void/);
  assert.match(row, /LongPressGesture\(\{ repeat: false \}\)\.onAction/);

  const page = read('ui/pages/profile/TgProfileMembersPage.ets');
  assert.match(page, /createChatMemberAdminUseCase\(owner\.gateway\)/);
  assert.match(page, /private openMemberActions\(row: TgProfileMemberRowVO\): void \{/);
  assert.match(page, /const actions: ChatMemberModerationAction\[\] = \['promote', 'demote', 'ban', 'unban', 'restrict'\];/);
  assert.match(page, /buttons: \[b0, b1, b2, b3, b4\]/);
  assert.match(page, /useCase\.apply\(this\.chatId, userId, action\)/);
  assert.match(page, /onLongPress: \(\): void => \{\n              this\.openMemberActions\(row\);/);
  assert.match(page, /private openModerationDuration\(action: ChatMemberModerationAction, userId: number\): void \{/);
  assert.match(page, /if \(action === 'ban' \|\| action === 'restrict'\) \{/);
  assert.match(page, /buttons: \[d0, d1, d2, d3\]/);
  assert.match(page, /moderationUntilDate\(Math\.floor\(Date\.now\(\) \/ 1000\),/);

  // Promotion navigates to the rights screen, which applies the status itself.
  assert.match(page, /pushPathByName\('TgChatAdminRightsPage',/);
  const rightsPage = read('ui/pages/chat/TgChatAdminRightsPage.ets');
  assert.match(rightsPage, /export function TgChatAdminRightsPageBuilder\(\)/);
  assert.match(rightsPage, /createChatMemberAdminUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(rightsPage, /useCase\.apply\(this\.chatId, this\.userId, 'promote', 0, this\.buildRights\(\)\)/);
  assert.match(rightsPage, /const ADMIN_RIGHT_ROWS: AdminRightRow\[\] = \[/);
  for (const key of ['canManageChat', 'canChangeInfo', 'canDeleteMessages', 'canInviteUsers',
    'canRestrictMembers', 'canPinMessages', 'canManageTopics', 'canManageVideoChats',
    'canPromoteMembers', 'isAnonymous']) {
    assert.ok(rightsPage.includes("'" + key + "'"), 'rights page exposes ' + key);
  }
  const routes = JSON.parse(fs.readFileSync(
    path.join(root, '../resources/base/profile/route_map.json'), 'utf8'));
  const rightsRoute = routes.routerMap.find((item) => item.name === 'TgChatAdminRightsPage');
  assert.ok(rightsRoute, 'TgChatAdminRightsPage is registered');
  assert.equal(rightsRoute.buildFunction, 'TgChatAdminRightsPageBuilder');

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['member_action_ban', 'member_action_unban', 'member_action_restrict',
      'member_action_promote', 'member_action_demote', 'member_action_applied',
      'member_action_failed', 'admin_rights_title', 'admin_rights_save', 'admin_rights_saved',
      'admin_rights_failed', 'admin_rights_manage_chat', 'admin_rights_change_info',
      'admin_rights_delete_messages', 'admin_rights_invite_users', 'admin_rights_restrict_members',
      'admin_rights_pin_messages', 'admin_rights_manage_topics', 'admin_rights_manage_video_chats',
      'admin_rights_promote_members', 'admin_rights_anonymous', 'moderation_duration_title',
      'moderation_duration_1h', 'moderation_duration_1d', 'moderation_duration_1w',
      'moderation_duration_forever']) {
      assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
    }
  }

  console.log('PASS chat member admin contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
