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
    ['createSetChatMemberStatusCommand', 'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog });
  const U = load('domain/usecases/chatMemberAdmin.ets',
    ['ChatMemberAdminUseCase', 'createChatMemberAdminUseCase', 'memberStatusKind'],
    { ...C, ...errors, hilog });

  // Action → status mapping ------------------------------------------------------------------------
  assert.equal(U.memberStatusKind('ban'), 'banned');
  assert.equal(U.memberStatusKind('unban'), 'member');
  assert.equal(U.memberStatusKind('restrict'), 'restricted');

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
  assert.match(page, /const actions: ChatMemberModerationAction\[\] = \['ban', 'unban', 'restrict'\];/);
  assert.match(page, /buttons: \[b0, b1, b2\]/);
  assert.match(page, /useCase\.apply\(this\.chatId, userId, action\)/);
  assert.match(page, /onLongPress: \(\): void => \{\n              this\.openMemberActions\(row\);/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['member_action_ban', 'member_action_unban', 'member_action_restrict',
      'member_action_applied', 'member_action_failed']) {
      assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
    }
  }

  console.log('PASS chat member admin contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
