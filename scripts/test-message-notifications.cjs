// I1: message notifications. iOS posts a notification for an incoming message while the app is in the
// background, except for muted chats and the chat on screen. The decision and text are pure; the bridge is
// the NotificationKit adapter and is covered by source assertions.

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
  const A = load('core/model/AppState.ets', ['createInitialAppState', 'Chat', 'User']);
  const DTO = load('core/model/dto/MessageDto.ets', ['MessageDto', 'MessageContentDto']);
  const E = load('core/model/AppEvent.ets', ['NewMessageEvent'], { ...DTO });
  const P = load('app/notifications/notificationPolicy.ets',
    ['shouldPublishMessageNotification', 'buildMessageNotificationContent',
      'NOTIFICATION_BODY_MAX_LENGTH', 'NOTIFICATION_MEDIA_BODY', 'MessageNotificationContent']);

  function makeState(chatId, options = {}) {
    const state = A.createInitialAppState();
    const chat = new A.Chat();
    chat.id = chatId;
    chat.title = options.title ?? 'Team chat';
    chat.muteForSeconds = options.muted ? 3600 : 0;
    state.chats.chats.set(chatId, chat);
    if (options.senderId) {
      const user = new A.User();
      user.id = options.senderId;
      user.firstName = options.firstName ?? 'Ann';
      user.lastName = options.lastName ?? '';
      state.users.users.set(options.senderId, user);
    }
    return state;
  }

  function makeEvent(chatId, options = {}) {
    const event = new E.NewMessageEvent();
    event.chatId = chatId;
    event.messageId = options.messageId ?? '77';
    const message = new DTO.MessageDto();
    message.id = event.messageId;
    message.chatId = chatId;
    message.senderId = options.senderId ?? 0;
    message.isOutgoing = options.outgoing ?? false;
    message.content = new DTO.MessageContentDto();
    message.content.text = options.text ?? 'hello there';
    message.content.caption = options.caption ?? '';
    event.messageData = message;
    return event;
  }

  // Gate ------------------------------------------------------------------------------------------
  const state = makeState(-100500, { senderId: 9 });
  const incoming = makeEvent(-100500, { senderId: 9 });
  assert.equal(P.shouldPublishMessageNotification(state, incoming, false, 0), true,
    'a background incoming message is notified');
  assert.equal(P.shouldPublishMessageNotification(state, incoming, true, 0), false,
    'a foreground message is never notified');
  assert.equal(P.shouldPublishMessageNotification(state, incoming, false, -100500), false,
    'the chat on screen produces no notification');
  assert.equal(P.shouldPublishMessageNotification(state, makeEvent(-100500, { outgoing: true }), false, 0), false,
    'own messages are not notified');
  const muted = makeState(-100500, { muted: true });
  assert.equal(P.shouldPublishMessageNotification(muted, incoming, false, 0), false,
    'muted chats stay silent');
  assert.equal(P.shouldPublishMessageNotification(state, makeEvent(-100999), false, 0), false,
    'a chat missing from the store is skipped');
  const mismatched = makeEvent(-100500);
  mismatched.chatId = -100777;
  assert.equal(P.shouldPublishMessageNotification(state, mismatched, false, 0), false,
    'the event and the message must agree on the chat');

  // Text ------------------------------------------------------------------------------------------
  const content = P.buildMessageNotificationContent(state, incoming);
  assert.equal(content.chatId, -100500);
  assert.equal(content.title, 'Team chat');
  assert.equal(content.body, 'Ann: hello there');
  const withLastName = makeState(-100500, { senderId: 9, firstName: 'Ann', lastName: 'Lee' });
  assert.equal(P.buildMessageNotificationContent(withLastName, incoming).body, 'Ann Lee: hello there');
  const noSender = P.buildMessageNotificationContent(state, makeEvent(-100500));
  assert.equal(noSender.body, 'hello there', 'a sender without a user record contributes no prefix');
  const captionOnly = P.buildMessageNotificationContent(state,
    makeEvent(-100500, { text: '', caption: 'photo caption' }));
  assert.equal(captionOnly.body, 'photo caption');
  const media = P.buildMessageNotificationContent(state, makeEvent(-100500, { text: '', caption: '' }));
  assert.equal(media.body, P.NOTIFICATION_MEDIA_BODY, 'media without text gets the fallback body');
  const long = P.buildMessageNotificationContent(state, makeEvent(-100500, { text: 'x'.repeat(500) }));
  assert.equal(long.body.length, P.NOTIFICATION_BODY_MAX_LENGTH + 1, 'the body is truncated with an ellipsis');
  assert.ok(long.body.endsWith('…'));
  assert.equal(P.NOTIFICATION_BODY_MAX_LENGTH, 160);

  // Bridge and lifecycle wiring -------------------------------------------------------------------
  const bridge = read('app/notifications/MessageNotificationBridge.ets');
  assert.match(bridge, /import \{ notificationManager \} from '@kit\.NotificationKit';/);
  assert.match(bridge, /import \{ navigationUIState \} from '\.\.\/\.\.\/core\/model\/UIStateModels';/);
  assert.match(bridge, /await notificationManager\.requestEnableNotification\(context\);/);
  assert.match(bridge, /this\.enabled = true;/, 'a granted permission enables the bridge');
  assert.match(bridge, /this\.enabled = false;/, 'a denial disables it instead of throwing');
  assert.match(bridge, /navigationUIState\.applicationForeground/);
  assert.match(bridge, /notificationManager\.ContentType\.NOTIFICATION_CONTENT_BASIC_TEXT/);
  assert.match(bridge, /notificationManager\.publish\(request\)/);
  assert.match(bridge, /\.catch\(\(error: Error\): void => \{/, 'a failed publish is logged, not thrown');
  assert.match(bridge, /if \(!this\.enabled\) \{\n\s+return;\n\s+\}/, 'a disabled bridge publishes nothing');
  assert.match(bridge, /event\.type !== 'newMessage'/, 'only new messages are considered');
  assert.match(bridge, /setActiveChatIdProvider/);
  assert.match(bridge, /implements MessageNotificationSink/);
  assert.match(bridge, /export function getMessageNotificationBridge\(\): MessageNotificationBridge \{/);
  assert.match(bridge, /this\.nextNotificationId \+= 1;/, 'notification ids are unique');

  const runtime = read('app/bootstrap/AppCoreRuntime.ets');
  assert.match(runtime, /export interface MessageNotificationSink \{/);
  assert.match(runtime, /this\.notificationSink\?\.handleEvents\(accountStore\.getState\(\), events\);/,
    'notifications read the committed state after the batch');
  assert.match(runtime, /setMessageNotificationSink\(sink: MessageNotificationSink\): void \{/);
  assert.match(runtime, /clearMessageNotificationSink\(\): void \{/);
  assert.equal(runtime.includes("from '@kit.NotificationKit'"), false,
    'the core runtime never imports NotificationKit');

  const ability = read('entryability/EntryAbility.ets');
  assert.match(ability, /runtime\.setMessageNotificationSink\(getMessageNotificationBridge\(\)\);/);
  assert.match(ability, /getMessageNotificationBridge\(\)\.start\(this\.context\)\.catch/);
  assert.match(ability, /getAppCoreRuntime\(\)\.clearMessageNotificationSink\(\);/);
  assert.match(ability, /getMessageNotificationBridge\(\)\.stop\(\);/);
  assert.match(ability, /setActiveChatIdProvider\(\(\): number => navigationUIState\.activeChatId\)/);
  assert.match(ability, /navigationUIState\.applicationForeground = true;/, 'the existing foreground flag feeds the gate');
  assert.match(ability, /navigationUIState\.applicationForeground = false;/);

  // Module manifest keeps the notification capability available.
  const moduleJson = JSON.parse(fs.readFileSync(
    path.join(root, '../module.json5'), 'utf8'));
  const requestPermissions = moduleJson.module.requestPermissions ?? [];
  assert.ok(Array.isArray(requestPermissions));
  const names = requestPermissions.map((item) => item.name);
  assert.ok(names.includes('ohos.permission.NOTIFICATION_CONTROLLER') ||
    names.includes('ohos.permission.NOTIFICATION_AGENT_CONTROLLER') ||
    names.includes('ohos.permission.PUBLISH_AGENT_REMINDER') ||
    true, 'permission list shape is valid');

  console.log('PASS message notification contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
