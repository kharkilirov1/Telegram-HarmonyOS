// I1: notification grouping — stable per-chat group/app-message identity, unread badge, the bridge using
// them and the chat-open cancellation hook.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  const P = load('app/notifications/notificationPolicy.ets',
    ['notificationGroupName', 'notificationAppMessageId', 'notificationBadgeNumber',
      'shouldPublishMessageNotification', 'buildMessageNotificationContent',
      'NOTIFICATION_GROUP_PREFIX', 'NOTIFICATION_BODY_MAX_LENGTH', 'NOTIFICATION_MEDIA_BODY',
      'MessageNotificationContent']);

  // Group identity ---------------------------------------------------------------------------------
  assert.equal(P.NOTIFICATION_GROUP_PREFIX, 'telegram_chat_');
  assert.equal(P.notificationGroupName(42), 'telegram_chat_42');
  assert.equal(P.notificationGroupName(0), '', 'no group without a chat');
  assert.equal(P.notificationGroupName(-5), '');
  assert.equal(P.notificationAppMessageId(42), 'chat_42');
  assert.equal(P.notificationAppMessageId(0), '');
  assert.notEqual(P.notificationGroupName(1), P.notificationGroupName(2), 'chats group separately');
  assert.equal(P.notificationGroupName(42), P.notificationGroupName(42), 'the same chat keeps one group');

  // Badge ------------------------------------------------------------------------------------------
  const stateWith = (unread) => ({
    chats: { chats: new Map([[7, { unreadCount: unread }]]) }
  });
  assert.equal(P.notificationBadgeNumber(stateWith(3), 7), 3);
  assert.equal(P.notificationBadgeNumber(stateWith(0), 7), 0);
  assert.equal(P.notificationBadgeNumber(stateWith(-2), 7), 0);
  assert.equal(P.notificationBadgeNumber(stateWith(1.9), 7), 1, 'the badge is an integer');
  assert.equal(P.notificationBadgeNumber(stateWith(5), 8), 0, 'an unknown chat has no badge');
  assert.equal(P.notificationBadgeNumber(stateWith(5), 0), 0);
  assert.equal(P.notificationBadgeNumber({ chats: { chats: new Map() } }, 7), 0);

  // The gate stays unchanged -----------------------------------------------------------------------
  const message = { isOutgoing: false, chatId: 7, content: { text: 'hi', caption: '' }, senderId: 1 };
  const event = { type: 'newMessage', chatId: 7, messageData: message };
  const state = {
    chats: { chats: new Map([[7, { title: 'Chat', muteForSeconds: 0, unreadCount: 2 }]]) },
    users: { users: new Map([[1, { firstName: 'Ann', lastName: '' }]]) }
  };
  assert.equal(P.shouldPublishMessageNotification(state, event, false, 0), true);
  assert.equal(P.shouldPublishMessageNotification(state, event, true, 0), false, 'foreground stays silent');
  assert.equal(P.shouldPublishMessageNotification(state, event, false, 7), false, 'the open chat stays silent');
  state.chats.chats.get(7).muteForSeconds = 60;
  assert.equal(P.shouldPublishMessageNotification(state, event, false, 0), false, 'a muted chat stays silent');
  state.chats.chats.get(7).muteForSeconds = 0;
  const content = P.buildMessageNotificationContent(state, event);
  assert.equal(content.chatId, 7);
  assert.equal(content.title, 'Chat');
  assert.equal(content.body, 'Ann: hi');

  // Bridge -----------------------------------------------------------------------------------------
  const bridge = read('app/notifications/MessageNotificationBridge.ets');
  assert.match(bridge, /private chatNotificationIds: Map<number, number> = new Map<number, number>\(\);/);
  assert.match(bridge, /private notificationIdFor\(chatId: number\): number \{/);
  assert.match(bridge, /const existing = this\.chatNotificationIds\.get\(chatId\);/,
    'a chat reuses its notification id');
  assert.match(bridge, /async cancelForChat\(chatId: number\): Promise<void> \{/);
  assert.match(bridge, /notificationManager\.cancel\(id\)/);
  assert.match(bridge, /async cancelAll\(\): Promise<void> \{/);
  assert.match(bridge, /notificationManager\.cancelAll\(\)/);
  assert.match(bridge, /if \(id === undefined \|\| !this\.enabled\) \{/);
  assert.match(bridge, /const notificationId = this\.notificationIdFor\(content\.chatId\);/);
  assert.match(bridge, /groupName: notificationGroupName\(content\.chatId\),/);
  assert.match(bridge, /appMessageId: notificationAppMessageId\(content\.chatId\),/);
  assert.match(bridge, /badgeNumber: notificationBadgeNumber\(state, content\.chatId\),/);
  assert.match(bridge, /this\.publish\(state, content\);/);

  // Chat open cancels its notification -------------------------------------------------------------
  const ownership = read('ui/pages/chat/ChatRouteOwnershipCoordinator.ets');
  assert.match(ownership, /import \{ getMessageNotificationBridge \} from '\.\.\/\.\.\/\.\.\/app\/notifications\/MessageNotificationBridge';/);
  assert.match(ownership, /getMessageNotificationBridge\(\)\.cancelForChat\(ownedChatId\)\.catch\(\(\): void => \{\}\);/);

  console.log('PASS notification grouping contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
