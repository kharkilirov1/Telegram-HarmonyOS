// H8/G4: a blocked peer shows an UNBLOCK panel instead of the composer in a private chat.
// Covers the policy decision, the label, the derive/handler wiring and the three locale strings.

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
  const localized = (_id, fallback) => fallback;
  const Policy = load('ui/pages/chat/ChatInputPanelPolicy.ets', ['selectChatInputPanel']);
  const Perm = load('ui/pages/chat/ChatPermissionCoordinator.ets',
    ['bottomBarActionLabel', 'bottomBarMessage'],
    { localized, hilog, $r: (key) => key, TgUiTokens: {}, MUTE_FOREVER: 2147483647 });

  const privateChat = (overrides) => Object.assign({
    id: 7, type: 'private', peerUserId: 55, basicGroupId: 0, supergroupId: 0,
    sendPermissions: undefined, isBlocked: false
  }, overrides);

  // Policy ----------------------------------------------------------------------------------------
  assert.equal(Policy.selectChatInputPanel(privateChat({ isBlocked: true })), 'unblock',
    'a blocked peer gets the Unblock panel');
  assert.equal(Policy.selectChatInputPanel(privateChat({ isBlocked: false })), 'composer');
  assert.equal(Policy.selectChatInputPanel(privateChat({ type: 'secret', isBlocked: true })),
    'unblock', 'secret chats unblock the same way');
  assert.notEqual(Policy.selectChatInputPanel({ id: 9, type: 'group', peerUserId: 0,
    basicGroupId: 0, supergroupId: 0, isBlocked: true }), 'unblock',
    'a group chat is never turned into the private-chat Unblock panel');

  // Label -----------------------------------------------------------------------------------------
  assert.equal(Perm.bottomBarActionLabel({ chatBottomBarAction: 'unblock',
    chatBottomBarDeleteAndExit: false }), 'Unblock');

  // Derive and handler wiring ---------------------------------------------------------------------
  const permission = read('ui/pages/chat/ChatPermissionCoordinator.ets');
  assert.match(permission, /if \(panel === 'unblock'\) host\.chatBottomBarAction = 'unblock';/);
  assert.match(permission, /chatUnblockUseCase\?: SetMessageSenderBlockedUseCase;/);
  const handler = permission.slice(permission.indexOf('export function handleChatBottomBarAction'));
  const body = handler.slice(0, handler.indexOf('retryChatAccess'));
  assert.match(body, /host\.chatBottomBarAction === 'unblock'/);
  assert.match(body, /unblockUseCase\.unblock\('user', peerUserId\)/, 'unblocks the peer user');
  assert.match(body, /peerUserId > 0/, 'no call without a peer id');

  // Chrome/context/ports carry the new action value -----------------------------------------------
  const chrome = read('ui/pages/chat/ChatChromeState.ets');
  assert.match(chrome, /'retry' \| 'unblock'/);
  const context = read('ui/pages/chat/ChatScreenContext.ets');
  assert.match(context, /get chatBottomBarAction\(\): 'none' \| 'mute' \| 'unmute' \| 'join' \| 'retry' \| 'unblock'/);

  // Use case lifecycle ----------------------------------------------------------------------------
  const activation = read('ui/pages/chat/ChatRouteActivationCoordinator.ets');
  assert.match(activation, /host\.chatUnblockUseCase = createSetMessageSenderBlockedUseCase\(gateway\);/);
  const teardown = read('ui/pages/chat/ChatPageTeardownCoordinator.ets');
  assert.match(teardown, /host\.chatUnblockUseCase = undefined;/);

  // Strings ---------------------------------------------------------------------------------------
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const json = JSON.parse(fs.readFileSync(
      path.join(root, '../resources/' + locale + '/element/string.json'), 'utf8'));
    assert.ok(json.string.find((item) => item.name === 'unblock'), locale + ' has the unblock label');
  }

  console.log('PASS blocked peer unblock panel contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
