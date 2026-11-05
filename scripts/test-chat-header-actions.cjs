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
const actions = read('ui/pages/chat/ChatActionsCoordinator.ets');

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
assert.match(page, /this\.chatActions\.currentChatId = this\.view\.chrome\.activeChatId;/);
assert.match(page, /this\.chatActions\.open\(\);/);
assert.match(actions, /private applyMenuAction\(action: ChatMenuAction \| undefined, chatId: number, chat: Chat\): void \{/);
assert.match(actions, /this\.applyMenuAction\(actions\[result\.index\], chatId, chat\)/);
assert.match(actions, /getPromptAction\(\)\.showActionMenu\(/);
assert.match(actions, /localized\(\$r\('app\.string\.chat_actions_info'\)\.id, 'Chat Info'\)/);

// Role-aware admin entries (C10 remainder): getChatMember decides Members.
assert.match(actions, /createChatMemberRoleUseCase\(getTdGatewayAdapter\(\)\)\.load\(chatId, userId\)/);
assert.match(actions, /if \(canManageChat\(role\)\) \{/);
assert.match(actions, /push\(ChatMenuAction\.Manage, localized\(\$r\('app\.string\.chat_actions_manage'\)\.id, 'Manage'\), normal\);/);
assert.match(actions, /const actions: ChatMenuAction\[\] = \[ChatMenuAction\.Members, ChatMenuAction\.InviteLinks,\n      ChatMenuAction\.Administrators, ChatMenuAction\.Permissions, ChatMenuAction\.AutoDelete,\n      ChatMenuAction\.Scheduled\];/);
assert.match(actions, /this\.host\.openInviteLinks\(chatId\)/);
assert.match(actions, /const b0: promptAction\.Button = \{ text: labels\[0\], color: colors\[0\] \};/);
assert.match(page, /private openMembersFromChat\(chatId: number\): void \{/);
assert.match(page, /openMembersScreen\(this\.queryNavigationInfo\(\)\?\.pathStack, chatId\)/);
const adminNav = read('ui/pages/chat/chatAdminNavigation.ets');
assert.match(adminNav, /new ProfileMembersRouteParams\(chatId,/);

// Report comment step (C10 remainder): TDLib can require free text after the reason.
assert.match(actions, /this\.host\.requestReportComment\(chatId, step\.optionId\)/);
assert.match(actions, /submitReportComment\(chatId: number, optionId: string, text: string\): Promise<void> \{/);
assert.match(actions, /useCase\.submitComment\(chatId, optionId, text\)/);
assert.match(page, /private openReportComment\(chatId: number, optionId: string\): void \{/);
assert.match(page, /this\.chatActions\.submitReportComment\(chatId, optionId, this\.reportCommentDraft\)/);
assert.match(page, /@Local private reportCommentVisible: boolean = false;/);
assert.match(page, /TgReportCommentOverlay/);

const reportOverlay = fs.readFileSync(
  path.join(root, 'entry/src/main/ets/ui/tg_ui/molecules/TgReportCommentOverlay.ets'), 'utf8');
assert.match(reportOverlay, /export struct TgReportCommentOverlay/);
assert.match(reportOverlay, /@Event onDraftChange/);
assert.match(reportOverlay, /@Event onSubmit/);
// Report by message selection: TDLib can ask for the offending messages instead.
assert.match(actions, /this\.host\.requestReportMessages\(chatId, step\.optionId\)/);
assert.match(actions, /submitReportMessages\(chatId: number, optionId: string, messageIds: number\[\]\): Promise<void> \{/);
assert.match(actions, /useCase\.submitMessages\(chatId, optionId, messageIds\)/);
assert.match(page, /private beginReportSelection\(chatId: number, optionId: string\): void \{/);
assert.match(page, /this\.view\.timeline\.selectionActive = true;/);
assert.match(page, /this\.chatActions\.submitReportMessages\(chatId, optionId, messageIds\)/);
assert.match(page, /showReport: this\.reportSelectionActive,/);
const selectionPanel = read('ui/tg_ui/molecules/TgSelectionPanel.ets');
assert.match(selectionPanel, /@Param showReport: boolean = false;/);
assert.match(selectionPanel, /@Event onReport: \(\) => void = \(\) => \{\};/);
assert.match(selectionPanel, /SELECTION_PANEL_REPORT_GLYPH/);


for (const locale of ['base', 'ru_RU', 'zh_CN']) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
  for (const name of ['chat_actions_report_comment_title', 'chat_actions_report_comment_placeholder',
    'chat_actions_report_comment_cancel', 'chat_actions_report_comment_send']) {
    assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
  }
}
assert.match(actions, /localized\(\$r\('app\.string\.profile_mute'\)\.id, 'Mute'\)/);
assert.match(actions, /localized\(\$r\('app\.string\.profile_clear_history'\)\.id, 'Clear History'\)/);
assert.match(actions, /localized\(\$r\('app\.string\.profile_delete_chat'\)\.id, 'Delete Chat'\)/);
assert.match(page, /this\.bindings\.openProfile\(\);/);
assert.match(actions, /this\.host\.openProfile\(\);/);
assert.match(actions, /createSetChatMuteUseCase\(getTdGatewayAdapter\(\)\)/);
assert.match(actions, /useCase\.mute\(chatId, MUTE_FOREVER\)/);
assert.match(actions, /useCase\.unmute\(chatId\)/);
assert.match(actions, /createDeleteChatHistoryUseCase\(getTdGatewayAdapter\(\)\)/);
assert.match(actions, /useCase\.execute\(chatId, removeChat, removeChat\)/);
assert.match(actions, /private confirmDeletion\(chatId: number, removeChat: boolean\): void \{/);
assert.match(actions, /this\.host\.handleBackPress\(\);/, 'deleting the chat leaves the screen');
assert.match(actions, /profile_chat_deleted_toast/);
assert.match(actions, /profile_history_cleared_toast/);
assert.match(actions, /private canLeaveChat\(chat: Chat\): boolean \{/);
assert.match(actions, /chat\.type === 'group' \|\| chat\.type === 'supergroup' \|\| chat\.type === 'channel'/);
assert.match(actions, /localized\(\$r\('app\.string\.chat_actions_leave'\)\.id, 'Leave Chat'\)/);
assert.match(actions, /localized\(\$r\('app\.string\.chat_actions_share_contact'\)\.id, 'Share My Contact'\)/);
assert.match(actions, /createLeaveChatUseCase\(getTdGatewayAdapter\(\)\)/);
assert.match(actions, /createShareMyContactUseCase\(getTdGatewayAdapter\(\)\)/);
assert.match(actions, /useCase\.share\(chatId, phoneNumber, firstName, lastName, userId\)/);
assert.match(actions, /const self = state\.users\.users\.get\(userId\)/);

// The header is wired to the live chat, not to a guessed id.
assert.match(page, /this\.chatActions\.currentChatId = this\.view\.chrome\.activeChatId;/);
assert.match(actions, /state\.chats\.chats\.get\(chatId\)/);

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
const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(main);
const hilog = { info() {}, debug() {}, warn() {}, error() {} };
const { TdObject } = load('models/td/common/index.ets');
const C = load('core/model/AppCommand.ets');
const errors = load('core/model/AppError.ets');
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });
const R = load('core/model/dto/ReportChatDto.ets', { TdObjectType: TdObject });
const roleMod = load('domain/usecases/chatMemberRole.ets',
  { ...C, ...errors, hilog: { info() {}, warn() {}, error() {} }, TdObject,
    TdObjectType: TdObject });
assert.equal(roleMod.readChatMemberRole(TdObject.fromJSON('{"@type":"chatMember",' +
  '"status":{"@type":"chatMemberStatusCreator"}}')), 'creator');
assert.equal(roleMod.readChatMemberRole(TdObject.fromJSON('{"@type":"chatMember",' +
  '"status":{"@type":"chatMemberStatusAdministrator"}}')), 'administrator');
assert.equal(roleMod.readChatMemberRole(TdObject.fromJSON('{"@type":"chatMember",' +
  '"status":{"@type":"chatMemberStatusMember"}}')), 'member');
assert.equal(roleMod.readChatMemberRole(TdObject.fromJSON('{"@type":"chatMember",' +
  '"status":{"@type":"chatMemberStatusLeft"}}')), 'left');
assert.equal(roleMod.readChatMemberRole(TdObject.fromJSON('{"@type":"ok"}')), 'unknown');
assert.equal(roleMod.canManageChat('creator'), true);
assert.equal(roleMod.canManageChat('administrator'), true);
assert.equal(roleMod.canManageChat('member'), false);


async function checkMembership() {
  const startWire = JSON.parse(serializer.buildTdlibRequestJson('reportChat',
    serializer.serializeCommand(C.createReportChatCommand(Object.assign(new C.ReportChatPayload(),
      { chatId: 42 }))).params));
  assert.equal(startWire.chat_id, 42);
  assert.equal(startWire.option_id, '', 'the first request sends empty bytes');
  assert.deepEqual(startWire.message_ids, []);
  assert.equal(startWire.text, '');

  const optionWire = JSON.parse(serializer.buildTdlibRequestJson('reportChat',
    serializer.serializeCommand(C.createReportChatCommand(Object.assign(new C.ReportChatPayload(),
      { chatId: 42, optionId: 'AQID' }))).params));
  assert.equal(optionWire.option_id, 'AQID', 'the chosen base64 option id is echoed');

  const optionsStep = R.createReportChatStepFromTd(TdObject.fromJSON('{"@type":"reportChatResultOptionRequired",' +
    '"title":"Why are you reporting?","options":[' +
    '{"@type":"reportOption","id":"AQID","text":"Spam"},' +
    '{"@type":"reportOption","id":"BAUG","text":"Violence"}]}'));
  assert.equal(optionsStep.kind, 'options');
  assert.equal(optionsStep.title, 'Why are you reporting?');
  assert.equal(optionsStep.options.length, 2);
  assert.equal(optionsStep.options[0].id, 'AQID');
  assert.equal(optionsStep.options[1].text, 'Violence');

  const textStep = R.createReportChatStepFromTd(TdObject.fromJSON(
    '{"@type":"reportChatResultTextRequired","option_id":"AQID","is_optional":false}'));
  assert.equal(textStep.kind, 'text');
  assert.equal(textStep.optionId, 'AQID');
  assert.equal(textStep.isTextOptional, false);
  assert.equal(R.createReportChatStepFromTd(TdObject.fromJSON(
    '{"@type":"reportChatResultMessagesRequired"}')).kind, 'messages');
  assert.equal(R.createReportChatStepFromTd(TdObject.fromJSON(
    '{"@type":"reportChatResultOk"}')).kind, 'ok');
  assert.equal(R.createReportChatStepFromTd(TdObject.fromJSON('{"@type":"ok"}')).kind, 'unknown');

  const reportSent = [];
  const reportGateway = { send: (command) => {
    reportSent.push(command);
    return Promise.resolve(TdObject.fromJSON(reportSent.length === 1
      ? '{"@type":"reportChatResultOptionRequired","title":"Why","options":[{"@type":"reportOption","id":"AQID","text":"Spam"}]}'
      : '{"@type":"reportChatResultOk"}'));
  } };
  const reportMod = load('domain/usecases/reportChat.ets',
    { ...C, ...errors, hilog, TdObject, ReportChatStepDto: R.ReportChatStepDto,
      ReportChatOptionDto: R.ReportChatOptionDto, createReportChatStepFromTd: R.createReportChatStepFromTd });
  const report = new reportMod.ReportChatUseCase(reportGateway);
  const first = await report.start(42);
  assert.equal(first.kind, 'options');
  await assert.rejects(() => report.chooseOption(42, ''), /Invalid option/);
  const done = await report.chooseOption(42, first.options[0].id);
  assert.equal(done.kind, 'ok');
  assert.equal(reportSent.at(-1).payload.optionId, 'AQID');
  await assert.rejects(() => report.start(0), /Invalid chatId/);
  await assert.rejects(() => new reportMod.ReportChatUseCase(
    { send: () => Promise.reject(new Error('native status')) }).start(1), /Failed to report the chat/);

  await report.submitComment(42, 'AQID', '  spam  ');
  assert.equal(reportSent.at(-1).type, 'reportChat');
  assert.equal(reportSent.at(-1).payload.optionId, 'AQID');
  assert.equal(reportSent.at(-1).payload.text, 'spam', 'the comment is trimmed');
  await assert.rejects(() => report.submitComment(42, 'AQID', '   '), /Report comment is required/);
  await assert.rejects(() => report.submitComment(42, '', 'text'), /Invalid option/);
  await assert.rejects(() => report.submitComment(0, 'AQID', 'text'), /Invalid chatId/);
  const sentBeforeInvalidComment = reportSent.length;
  await assert.rejects(() => report.submitComment(42, 'AQID', ' '), /Report comment is required/);
  assert.equal(reportSent.length, sentBeforeInvalidComment, 'invalid comments never reach the gateway');
  await assert.rejects(() => new reportMod.ReportChatUseCase(
    { send: () => Promise.reject(new Error('native status')) }).submitComment(1, 'AQID', 'x'),
    /Failed to report the chat/);

  await report.submitMessages(42, 'AQID', [9007199254740001, 7]);
  assert.equal(reportSent.at(-1).type, 'reportChat');
  assert.equal(reportSent.at(-1).payload.optionId, 'AQID');
  assert.deepEqual(reportSent.at(-1).payload.messageIds, [9007199254740001, 7]);
  const messagesWire = JSON.parse(serializer.buildTdlibRequestJson('reportChat',
    serializer.serializeCommand(reportSent.at(-1)).params));
  assert.deepEqual(messagesWire.message_ids, [9007199254740001, 7], 'selected ids reach the request');
  await assert.rejects(() => report.submitMessages(42, 'AQID', []), /Report messages are required/);
  await assert.rejects(() => report.submitMessages(42, 'AQID', [0]), /Invalid message id/);
  await assert.rejects(() => report.submitMessages(0, 'AQID', [1]), /Invalid chatId/);
  const sentBeforeInvalidMessages = reportSent.length;
  await assert.rejects(() => report.submitMessages(42, 'AQID', []), /Report messages are required/);
  assert.equal(reportSent.length, sentBeforeInvalidMessages, 'invalid selections never reach the gateway');
  await assert.rejects(() => new reportMod.ReportChatUseCase(
    { send: () => Promise.reject(new Error('native status')) }).submitMessages(1, 'AQID', [3]),
    /Failed to report the chat/);

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

  const roleSent = [];
  const roleUseCase = new roleMod.ChatMemberRoleUseCase({ send: (command) => {
    roleSent.push(command);
    return Promise.resolve(TdObject.fromJSON('{"@type":"chatMember",' +
      '"status":{"@type":"chatMemberStatusAdministrator"}}'));
  } });
  assert.equal(await roleUseCase.load(42, 7), 'administrator');
  assert.equal(roleSent.at(-1).type, 'getChatMember');
  assert.equal(roleSent.at(-1).payload.chatId, 42);
  assert.equal(roleSent.at(-1).payload.userId, 7);
  const memberWire = JSON.parse(serializer.buildTdlibRequestJson('getChatMember',
    serializer.serializeCommand(roleSent.at(-1)).params));
  assert.equal(memberWire.chat_id, 42);
  assert.equal(memberWire.member_id['@type'], 'messageSenderUser');
  assert.equal(memberWire.member_id.user_id, 7);
  await assert.rejects(() => roleUseCase.load(0, 7), /Invalid chatId/);
  await assert.rejects(() => roleUseCase.load(42, 0), /Invalid userId/);
  assert.equal(await new roleMod.ChatMemberRoleUseCase(
    { send: () => Promise.reject(new Error('native status')) }).load(42, 7), 'unknown',
    'a failed lookup falls back to the member menu');

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
