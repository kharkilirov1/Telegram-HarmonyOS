// C10 contract: chat info actions ("..." button on the profile/chat-info screen).
// iOS counterpart: PeerInfoScreen more menu with Mute / Clear History / Delete Chat.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;
const read = (relative) => fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');

function load(relative, deps = {}) {
  const text = read(relative);
  const names = [...text.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map((match) => match[1]);
  const code = text.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '')
    .replace(/^@ObservedV2\s*\n/gm, '').replace(/^(\s*)@Trace\s+/gm, '$1');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) + `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

const hilog = { info() {}, debug() {}, warn() {}, error() {} };
const { TdObject } = load('models/td/common/index.ets');
const C = load('core/model/AppCommand.ets');
const errors = load('core/model/AppError.ets');
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });

// DeleteChatHistory use case: clear keeps the chat, delete removes it -----------------------------
async function checkDeleteHistory() {
  const sent = [];
  const gateway = { send: (command) => { sent.push(command); return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')); } };
  const mod = load('domain/usecases/deleteChatHistory.ets', { ...C, ...errors, hilog });
  const useCase = new mod.DeleteChatHistoryUseCase(gateway);

  await useCase.execute(77, false, false);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, 'deleteChatHistory');
  assert.equal(sent[0].payload.chatId, 77);
  assert.equal(sent[0].payload.removeFromChatList, false, 'clear history keeps the chat in the list');
  assert.equal(sent[0].payload.revoke, false);

  await useCase.execute(77, true, true);
  assert.equal(sent[1].payload.removeFromChatList, true, 'delete removes the chat from the list');
  assert.equal(sent[1].payload.revoke, true);

  for (const bad of [0, -1, 1.5]) {
    await assert.rejects(() => useCase.execute(bad), /Invalid chatId/);
  }
  assert.equal(sent.length, 2, 'invalid chat ids never reach the gateway');

  const wire = JSON.parse(serializer.buildTdlibRequestJson('deleteChatHistory',
    serializer.serializeCommand(sent[1]).params));
  assert.equal(wire.chat_id, 77);
  assert.equal(wire.remove_from_chat_list, true);
  assert.equal(wire.revoke, true);

  const failing = { send: () => Promise.reject(new Error('native status')) };
  const failingUseCase = new mod.DeleteChatHistoryUseCase(failing);
  await assert.rejects(() => failingUseCase.execute(5, false, false), /Failed to delete chat/);
}

// Profile page and navigation bar wiring ----------------------------------------------------------
{
  const page = read('ui/pages/profile/TgProfilePage.ets');
  assert.match(page, /import { createDeleteChatHistoryUseCase, DeleteChatHistoryUseCase } from/);
  assert.match(page, /private deleteHistoryUseCase\?: DeleteChatHistoryUseCase;/);
  assert.match(page, /this\.deleteHistoryUseCase = createDeleteChatHistoryUseCase\(getTdGatewayAdapter\(\)\);/);
  assert.match(page, /showMore: this\.chatId !== 0 && this\.hasPeer/);
  assert.match(page, /onMorePress: \(\): void => \{\n            this\.openChatActions\(\);\n          \}/);
  assert.match(page, /private openChatActions\(\): void \{/);
  assert.match(page, /getPromptAction\(\)\.showActionMenu\(/);
  assert.match(page, /localized\(\$r\('app\.string\.profile_mute'\)\.id, 'Mute'\)/);
  assert.match(page, /localized\(\$r\('app\.string\.profile_clear_history'\)\.id, 'Clear History'\)/);
  assert.match(page, /localized\(\$r\('app\.string\.profile_delete_chat'\)\.id, 'Delete Chat'\)/);
  assert.match(page, /private toggleMuteFromActions\(\): void \{/);
  assert.match(page, /useCase\.mute\(chatId, MUTE_FOREVER\)/);
  assert.match(page, /useCase\.unmute\(chatId\)/);
  assert.match(page, /private confirmClearHistory\(\): void \{/);
  assert.match(page, /private confirmDeleteChat\(\): void \{/);
  assert.match(page, /this\.deleteHistory\(false, false\)/, 'clear history does not remove the chat');
  assert.match(page, /this\.deleteHistory\(true, true\)/, 'delete chat removes it and revokes');
  assert.match(page, /profile_history_cleared_toast/);
  assert.match(page, /profile_chat_deleted_toast/);

  const navBar = read('ui/tg_ui/atoms/TgProfileNavigationBar.ets');
  assert.match(navBar, /@Param showMore: boolean = false;/);
  assert.match(navBar, /@Event onMorePress: \(\) => void = \(\): void => \{\};/);
  assert.match(navBar, /this\.buildMoreAction\(\)/);
  assert.match(navBar, /ICON_RES_MORE/);
  assert.match(navBar, /\.id\('profile_more'\)/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['profile_mute', 'profile_unmute', 'profile_clear_history',
      'profile_clear_history_confirm', 'profile_delete_chat', 'profile_delete_chat_confirm',
      'profile_history_cleared_toast', 'profile_chat_deleted_toast']) {
      const item = strings.string.find((entry) => entry.name === name);
      assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
    }
  }
}

checkDeleteHistory()
  .then(() => {
    console.log('PASS profile chat actions contract');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
