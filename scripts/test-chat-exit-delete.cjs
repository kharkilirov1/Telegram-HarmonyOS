// G4: a member removed from a group gets the iOS restricted panel with one destructive action that
// leaves the chat and deletes it. Covers the derive decision, the label, the dock atom and the handler.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  const hilog = { info() {}, warn() {}, error() {}, debug() {} };
  const localized = (_id, fallback) => fallback;
  const strings = {
    chat_removed_bottom_bar: 'You were removed from this group.',
    chat_delete_and_exit: 'Delete and Exit',
    conversation_default_restricted_text: "Writing messages isn't allowed in this group.",
    group_access_unavailable: 'This group is unavailable.',
    channel_access_unavailable: 'This channel is unavailable.',
    loading: 'Loading...',
    retry: 'Retry',
    channel_join: 'Join',
    mute: 'Mute',
    unmute: 'Unmute'
  };
  const P = load('ui/pages/chat/ChatPermissionCoordinator.ets',
    ['bottomBarMessage', 'bottomBarActionLabel'],
    { localized, hilog, $r: (key) => key, TgUiTokens: {}, MUTE_FOREVER: 2147483647 });

  // The label is the iOS wording and exists in all three locales.
  assert.equal(P.bottomBarActionLabel({ chatBottomBarDeleteAndExit: true, chatBottomBarAction: 'none' }),
    'Delete and Exit');
  assert.equal(P.bottomBarActionLabel({ chatBottomBarDeleteAndExit: false, chatBottomBarAction: 'join' }),
    'Join', 'the action label still serves the join bar');
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const json = JSON.parse(fs.readFileSync(
      path.join(root, '../resources/' + locale + '/element/string.json'), 'utf8'));
    for (const name of ['chat_removed_bottom_bar', 'chat_delete_and_exit']) {
      assert.ok(json.string.find((item) => item.name === name), locale + ' has ' + name);
    }
  }

  // Restricted panel message prefers the removed-group wording.
  assert.equal(P.bottomBarMessage({ chatBottomBarDeleteAndExit: true, chatBottomBarReason: 'banned',
    chatAccessUnavailable: false }), 'You were removed from this group.');
  assert.equal(P.bottomBarMessage({ chatBottomBarDeleteAndExit: false, chatBottomBarReason: 'restricted',
    chatAccessUnavailable: false }), "Writing messages isn't allowed in this group.");

  // Derive: a banned group member gets the destructive action; channels and restrictions do not.
  const permission = read('ui/pages/chat/ChatPermissionCoordinator.ets');
  assert.match(permission,
    /host\.chatBottomBarDeleteAndExit = panel === 'banned' && chat\.type === 'group';/);
  assert.match(permission, /if \(host\.chatBottomBarDeleteAndExit\) \{/);

  // Chrome state carries the flag through the page.
  const chrome = read('ui/pages/chat/ChatChromeState.ets');
  assert.match(chrome, /@Trace chatBottomBarDeleteAndExit: boolean = false;/);
  const context = read('ui/pages/chat/ChatScreenContext.ets');
  assert.match(context, /get chatBottomBarDeleteAndExit\(\): boolean/);
  const ports = read('ui/pages/chat/ChatScreenViewPorts.ets');
  assert.match(ports, /bottomBarMessage\(\): string;/);

  // Dock passes the label and the handler only when the flag is set.
  const dock = read('ui/pages/chat/TgChatComposerDock.ets');
  assert.match(dock, /restrictedActionText: this\.chrome\.chatBottomBarDeleteAndExit/);
  assert.match(dock, /: this\.bindings\.bottomBarActionLabel\(\)/);
  assert.match(dock, /this\.bindings\.handleChatBottomBarAction\(\);/);
  const atom = read('ui/tg_ui/atoms/TgChatBottomActionBar.ets');
  assert.match(atom, /@Param restrictedActionText: string = '';/);
  assert.match(atom, /@Event onRestrictedAction: \(\) => void/);
  assert.match(atom, /this\.onRestrictedAction\(\);/);
  assert.match(atom, /fontColor\(TgUiTokens\.CHAT_CONTEXT_MENU_DESTRUCTIVE\)/);

  // Handler: the removed-member branch runs before the composer actions and delegates the exit.
  assert.match(permission, /if \(host\.chatBottomBarDeleteAndExit\) \{\n    deleteAndExitChat\(host\.activeChatId, \(\): void => \{ host\.handleBackPress\(\); \}\);/);
  assert.match(dock, /this\.bindings\.handleChatBottomBarAction\(\);/,
    'the restricted action reuses the existing bottom bar handler');

  // Exit helper: leave (tolerating an already-removed member), then delete the chat, then go back.
  const exitSource = read('ui/pages/chat/ChatExitCoordinator.ets');
  assert.match(exitSource, /createLeaveChatUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(exitSource, /createDeleteChatHistoryUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(exitSource, /leave\.leave\(chatId\)/);
  assert.match(exitSource, /\.catch\(\(\): void => \{\}\)/, 'a failed leave must not block the deletion');
  assert.match(exitSource, /remove\.execute\(chatId, true, true\)/, 'delete with removal and revoke');
  assert.match(exitSource, /onExited\(\);/, 'the screen closes after the chat is gone');
  assert.match(exitSource, /!Number\.isSafeInteger\(chatId\) \|\| chatId === 0/, 'no action without an active chat');

  console.log('PASS removed-member delete and exit contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
