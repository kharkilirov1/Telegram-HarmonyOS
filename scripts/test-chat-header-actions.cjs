// C10 contract: chat actions menu in the chat header ("..." capsule).
// iOS counterpart: the chat header/info "..." entry point with mute / clear history / delete chat.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;
const read = (relative) => fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');

const topBar = read('ui/tg_ui/atoms/TgChatTopBar.ets');
const page = read('ui/pages/chat/TgChatScreenPage.ets');

// Top bar: a second capsule, not a replacement for search -----------------------------------------
assert.match(topBar, /More = 'more'/);
assert.match(topBar, /@Param showMoreAction: boolean = false;/);
assert.match(topBar, /@Event onMorePress: \(\) => void = \(\): void => \{\};/);
assert.match(topBar, /private buildMoreActionCapsule\(\)/);
assert.match(topBar, /ICON_RES_MORE/);
assert.match(topBar, /\.id\('chat_top_bar_more'\)/);
assert.match(topBar, /if \(this\.showMoreAction\) \{\n {14}this\.buildMoreActionCapsule\(\)/);
assert.match(topBar, /\.onClick\(\(\) => this\.onMorePress\(\)\)/);
assert.match(topBar, /private buildNativeMoreActionCapsule\(\)/,
  'the more capsule follows the same native-material policy as search');
assert.match(topBar, /private buildFallbackMoreActionCapsule\(\)/);

// Page: menu, mute, clear history, delete, profile -------------------------------------------------
assert.match(page, /showMoreAction: this\.view\.chrome\.activeChatId > 0,/);
assert.match(page, /onMorePress: \(\): void => \{\n {12}this\.openChatActions\(\);/);
assert.match(page, /private openChatActions\(\): void \{/);
assert.match(page, /getPromptAction\(\)\.showActionMenu\(/);
assert.match(page, /localized\(\$r\('app\.string\.chat_actions_info'\)\.id, 'Chat Info'\)/);
assert.match(page, /localized\(\$r\('app\.string\.profile_mute'\)\.id, 'Mute'\)/);
assert.match(page, /localized\(\$r\('app\.string\.profile_clear_history'\)\.id, 'Clear History'\)/);
assert.match(page, /localized\(\$r\('app\.string\.profile_delete_chat'\)\.id, 'Delete Chat'\)/);
assert.match(page, /this\.bindings\.openProfile\(\);/);
assert.match(page, /createSetChatMuteUseCase\(getTdGatewayAdapter\(\)\)/);
assert.match(page, /useCase\.mute\(chatId, MUTE_FOREVER\)/);
assert.match(page, /useCase\.unmute\(chatId\)/);
assert.match(page, /createDeleteChatHistoryUseCase\(getTdGatewayAdapter\(\)\)/);
assert.match(page, /useCase\.execute\(chatId, removeChat, removeChat\)/);
assert.match(page, /private confirmChatDeletion\(chatId: number, removeChat: boolean\): void \{/);
assert.match(page, /this\.bindings\.handleBackPress\(\);/, 'deleting the chat leaves the screen');
assert.match(page, /profile_chat_deleted_toast/);
assert.match(page, /profile_history_cleared_toast/);
assert.match(page, /private canLeaveChat\(chat: Chat\): boolean \{/);
assert.match(page, /chat\.type === 'group' \|\| chat\.type === 'supergroup' \|\| chat\.type === 'channel'/);
assert.match(page, /localized\(\$r\('app\.string\.chat_actions_leave'\)\.id, 'Leave Chat'\)/);
assert.match(page, /localized\(\$r\('app\.string\.chat_actions_share_contact'\)\.id, 'Share My Contact'\)/);
assert.match(page, /createLeaveChatUseCase\(getTdGatewayAdapter\(\)\)/);
assert.match(page, /createShareMyContactUseCase\(getTdGatewayAdapter\(\)\)/);
assert.match(page, /useCase\.share\(chatId, phoneNumber, firstName, lastName, userId\)/);
assert.match(page, /const self = state\.users\.users\.get\(userId\)/);

// The header is wired to the live chat, not to a guessed id.
assert.match(page, /const chatId = this\.view\.chrome\.activeChatId;/);
assert.match(page, /state\.chats\.chats\.get\(chatId\)/);

for (const locale of ['base', 'ru_RU', 'zh_CN']) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
  for (const name of ['chat_actions_info', 'chat_actions_leave', 'chat_actions_leave_confirm',
    'chat_actions_left_toast', 'chat_actions_share_contact', 'chat_actions_contact_shared',
    'chat_actions_share_failed', 'profile_mute', 'profile_unmute', 'profile_clear_history',
    'profile_clear_history_confirm', 'profile_delete_chat', 'profile_delete_chat_confirm',
    'profile_history_cleared_toast', 'profile_chat_deleted_toast']) {
    const item = strings.string.find((entry) => entry.name === name);
    assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
  }
}

// Wire + use cases: leaveChat and inputMessageContact -------------------------------------------
const { stripTypeScriptTypes } = require('node:module');
function load(relative, deps = {}) {
  const text = read(relative);
  const names = [...text.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map((m) => m[1]);
  const code = text.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '')
    .replace(/^@ObservedV2\s*\n/gm, '').replace(/^(\s*)@Trace\s+/gm, '$1');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) +
    `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const hilog = { info() {}, debug() {}, warn() {}, error() {} };
const { TdObject } = load('models/td/common/index.ets');
const C = load('core/model/AppCommand.ets');
const errors = load('core/model/AppError.ets');
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });

async function checkMembership() {
  const leaveWire = JSON.parse(serializer.buildTdlibRequestJson('leaveChat',
    serializer.serializeCommand(C.createLeaveChatCommand(42)).params));
  assert.equal(leaveWire.chat_id, 42);

  const payload = new C.ShareContactPayload();
  payload.chatId = 42;
  payload.phoneNumber = '+1555';
  payload.firstName = 'Ann"a';
  payload.lastName = 'Lee';
  payload.userId = 7;
  const shareWire = JSON.parse(serializer.buildTdlibRequestJson('sendMessage',
    serializer.serializeCommand(C.createShareContactCommand(payload)).params));
  assert.equal(shareWire.chat_id, 42);
  assert.equal(shareWire.input_message_content['@type'], 'inputMessageContact');
  assert.equal(shareWire.input_message_content.contact['@type'], 'contact');
  assert.equal(shareWire.input_message_content.contact.phone_number, '+1555');
  assert.equal(shareWire.input_message_content.contact.first_name, 'Ann"a', 'quotes are escaped');
  assert.equal(shareWire.input_message_content.contact.user_id, 7);

  const sent = [];
  const gateway = { send: (command) => { sent.push(command); return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')); } };
  const mod = load('domain/usecases/chatMembership.ets', { ...C, ...errors, hilog });
  const leave = new mod.LeaveChatUseCase(gateway);
  await leave.leave(9);
  assert.equal(sent.at(-1).type, 'leaveChat');
  assert.equal(sent.at(-1).payload.chatId, 9);
  for (const bad of [0, -3, 1.5]) {
    await assert.rejects(() => leave.leave(bad), /Invalid chatId/);
  }
  assert.equal(sent.length, 1, 'invalid chat ids never reach the gateway');

  const share = new mod.ShareMyContactUseCase(gateway);
  await share.share(9, '  +1555  ', ' Ann ', 'Lee', 7);
  assert.equal(sent.at(-1).type, 'sendContactMessage');
  assert.equal(sent.at(-1).payload.phoneNumber, '+1555', 'contact fields are trimmed');
  assert.equal(sent.at(-1).payload.firstName, 'Ann');
  await assert.rejects(() => share.share(9, '', 'A', '', 7), /Invalid contact/);
  await assert.rejects(() => share.share(9, '+1', '', '', 7), /Invalid contact/);
  await assert.rejects(() => share.share(9, '+1', 'A', '', 0), /Invalid userId/);
  assert.equal(sent.length, 2, 'invalid contact data never reaches the gateway');

  const failing = { send: () => Promise.reject(new Error('native status')) };
  const failingMod = load('domain/usecases/chatMembership.ets', { ...C, ...errors, hilog });
  await assert.rejects(() => new failingMod.LeaveChatUseCase(failing).leave(1), /Failed to leave the chat/);
  await assert.rejects(() => new failingMod.ShareMyContactUseCase(failing).share(1, '+1', 'A', '', 7),
    /Failed to share the contact/);
}

checkMembership()
  .then(() => {
    console.log('PASS chat header actions contract');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
