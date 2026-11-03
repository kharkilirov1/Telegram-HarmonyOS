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

// The header is wired to the live chat, not to a guessed id.
assert.match(page, /const chatId = this\.view\.chrome\.activeChatId;/);
assert.match(page, /state\.chats\.chats\.get\(chatId\)/);

for (const locale of ['base', 'ru_RU', 'zh_CN']) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
  for (const name of ['chat_actions_info', 'profile_mute', 'profile_unmute', 'profile_clear_history',
    'profile_clear_history_confirm', 'profile_delete_chat', 'profile_delete_chat_confirm',
    'profile_history_cleared_toast', 'profile_chat_deleted_toast']) {
    const item = strings.string.find((entry) => entry.name === name);
    assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
  }
}

console.log('PASS chat header actions contract');
