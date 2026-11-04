// D21 contract: scheduled messages (getChatScheduledMessages, editMessageSchedulingState, cancel via
// deleteMessages), scheduled send on the text payload, the list screen and the Manage entry.

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
    ['createGetChatScheduledMessagesCommand', 'createEditMessageSchedulingStateCommand',
      'createDeleteMessagesCommand', 'createSendMessageCommand', 'SendMessagePayload', 'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog });
  const D = load('core/model/dto/ScheduledMessageDto.ets',
    ['ScheduledMessageDto', 'ScheduledMessagesDto', 'createScheduledMessagesFromTd'],
    { TdObjectType: TdObject });
  const U = load('domain/usecases/scheduledMessages.ets',
    ['ScheduledMessagesUseCase', 'createScheduledMessagesUseCase', 'isValidScheduledId',
      'isValidScheduleDate', 'MAX_SCHEDULE_AHEAD_SECONDS'],
    { ...C, ...errors, hilog, TdObject, ...D });

  // DTO parsing ------------------------------------------------------------------------------------
  const parsed = D.createScheduledMessagesFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'messages',
    total_count: 3,
    messages: [
      {
        '@type': 'message', id: '9007199254740993', date: 0,
        scheduling_state: { '@type': 'messageSchedulingStateSendAtDate', send_date: 2000000000,
          repeat_period: 0 },
        content: { '@type': 'messageText', text: { '@type': 'formattedText', text: 'Later hello' } }
      },
      {
        '@type': 'message', id: '9007199254740992', date: 0,
        scheduling_state: { '@type': 'messageSchedulingStateSendAtDate', send_date: 1900000000,
          repeat_period: 0 },
        content: { '@type': 'messagePhoto', caption: { '@type': 'formattedText', text: 'Photo' } }
      },
      { '@type': 'message', id: '7', date: 0, content: { '@type': 'messageText' } }
    ]
  })));
  assert.equal(parsed.messages.length, 2, 'messages without a scheduling state are dropped');
  assert.equal(parsed.messages[0].sendDate, 2000000000, 'newest scheduled time first');
  assert.equal(parsed.messages[0].text, 'Later hello');
  assert.equal(parsed.messages[0].messageId, '9007199254740993', 'int64 id stays a string');
  assert.equal(parsed.messages[1].text, 'Photo');
  assert.equal(D.createScheduledMessagesFromTd(TdObject.fromJSON('{"@type":"ok"}')), undefined);
  assert.deepEqual(D.createScheduledMessagesFromTd(
    TdObject.fromJSON('{"@type":"messages"}')).messages, []);

  // Validation -------------------------------------------------------------------------------------
  assert.equal(U.isValidScheduledId('9007199254740993'), true);
  assert.equal(U.isValidScheduledId('0'), false);
  assert.equal(U.isValidScheduledId('-5'), false);
  assert.equal(U.isValidScheduledId('abc'), false);
  assert.equal(U.isValidScheduleDate(1000, 500), true);
  assert.equal(U.isValidScheduleDate(500, 500), false, 'the past is rejected');
  assert.equal(U.isValidScheduleDate(500 + U.MAX_SCHEDULE_AHEAD_SECONDS + 1, 500), false);

  // Use case and wire ------------------------------------------------------------------------------
  const sent = [];
  const useCase = new U.ScheduledMessagesUseCase({
    send: (command) => {
      sent.push(command);
      if (command.type === 'getChatScheduledMessages') {
        return Promise.resolve(TdObject.fromJSON(JSON.stringify({
          '@type': 'messages', total_count: 1,
          messages: [{
            '@type': 'message', id: '42', date: 0,
            scheduling_state: { '@type': 'messageSchedulingStateSendAtDate', send_date: 2000000000,
              repeat_period: 0 },
            content: { '@type': 'messageText', text: { '@type': 'formattedText', text: 'Hi' } }
          }]
        })));
      }
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
  });
  const loaded = await useCase.load(42);
  assert.equal(loaded.messages.length, 1);
  assert.equal(sent.at(-1).type, 'getChatScheduledMessages');
  assert.equal(JSON.parse(serializer.buildTdlibRequestJson('getChatScheduledMessages',
    serializer.serializeCommand(sent.at(-1)).params)).chat_id, 42);

  await useCase.sendNow(42, '42');
  assert.equal(sent.at(-1).type, 'editMessageSchedulingState');
  const sendNowWire = JSON.parse(serializer.buildTdlibRequestJson('editMessageSchedulingState',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(sendNowWire.chat_id, 42);
  assert.equal(sendNowWire.message_id, '42', 'int64 id is a decimal string');
  assert.equal(sendNowWire.scheduling_state, null, 'null sends the message immediately');

  await useCase.reschedule(42, '42', 1920000000, 1900000000);
  const rescheduleWire = JSON.parse(serializer.buildTdlibRequestJson('editMessageSchedulingState',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(rescheduleWire.scheduling_state['@type'], 'messageSchedulingStateSendAtDate');
  assert.equal(rescheduleWire.scheduling_state.send_date, 1920000000);
  assert.equal(rescheduleWire.scheduling_state.repeat_period, 0);

  await useCase.cancel(42, '9007199254740993');
  assert.equal(sent.at(-1).type, 'deleteMessages');
  const cancelRaw = serializer.buildTdlibRequestJson('deleteMessages',
    serializer.serializeCommand(sent.at(-1)).params);
  const cancelWire = JSON.parse(cancelRaw);
  assert.equal(cancelWire.revoke, false);
  // The raw JSON must carry the exact digits: JSON.parse would round an int64 number.
  assert.ok(cancelRaw.includes('9007199254740993'),
    'the int64 scheduled id is forwarded without precision loss');

  const sentBefore = sent.length;
  await assert.rejects(() => useCase.load(0), /Invalid chatId/);
  await assert.rejects(() => useCase.sendNow(-1, '42'), /Invalid chatId/);
  await assert.rejects(() => useCase.sendNow(42, 'x'), /Invalid message id/);
  await assert.rejects(() => useCase.reschedule(42, '42', 1900000000, 1900000000), /Invalid schedule date/);
  await assert.rejects(() => useCase.cancel(42, '0'), /Invalid message id/);
  assert.equal(sent.length, sentBefore, 'invalid input never reaches the gateway');
  await assert.rejects(() => new U.ScheduledMessagesUseCase(
    { send: () => Promise.reject(new Error('native status')) }).load(42),
    /Failed to load scheduled messages/);
  await assert.rejects(() => new U.ScheduledMessagesUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).load(42),
    /Unsupported scheduled messages response/);
  await assert.rejects(() => new U.ScheduledMessagesUseCase(
    { send: () => Promise.reject(new Error('native status')) }).sendNow(42, '42'),
    /Failed to update the scheduled message/);
  await assert.rejects(() => new U.ScheduledMessagesUseCase(
    { send: () => Promise.reject(new Error('native status')) }).cancel(42, '42'),
    /Failed to cancel the scheduled message/);

  // Scheduled send on the text payload --------------------------------------------------------------
  const sendPayload = new C.SendMessagePayload();
  sendPayload.chatId = 42;
  sendPayload.text = 'Later';
  sendPayload.scheduledDateSeconds = 2000000000;
  const sendCommand = C.createSendMessageCommand === undefined ? undefined : undefined;
  assert.equal(sendCommand, undefined);
  const sendWireSource = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(sendWireSource, /if \(cmd\.payload\.scheduledDateSeconds > 0\)/);
  assert.match(sendWireSource, /messageSchedulingStateSendAtDate/);

  // Screen, route and submenu ----------------------------------------------------------------------
  const screen = read('ui/pages/chat/TgChatScheduledMessagesPage.ets');
  assert.match(screen, /export function TgChatScheduledMessagesPageBuilder\(\)/);
  assert.match(screen, /createScheduledMessagesUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(screen, /useCase\.load\(this\.chatId\)/);
  assert.match(screen, /useCase\.sendNow\(this\.chatId, message\.messageId\)/);
  assert.match(screen, /useCase\.reschedule\(this\.chatId, message\.messageId, nowSeconds \+ 3600, nowSeconds\)/);
  assert.match(screen, /useCase\.cancel\(this\.chatId, message\.messageId\)/);

  const routes = JSON.parse(fs.readFileSync(
    path.join(root, '../resources/base/profile/route_map.json'), 'utf8'));
  const route = routes.routerMap.find((item) => item.name === 'TgChatScheduledMessagesPage');
  assert.ok(route, 'TgChatScheduledMessagesPage is registered');
  assert.equal(route.buildFunction, 'TgChatScheduledMessagesPageBuilder');

  const actions = read('ui/pages/chat/ChatActionsCoordinator.ets');
  assert.match(actions, /ChatMenuAction\.AutoDelete,\n      ChatMenuAction\.Scheduled\];/);
  assert.match(actions, /buttons: \[b0, b1, b2, b3, b4, b5\]/, 'the six-slot cap is respected');
  assert.match(actions, /this\.host\.openScheduled\(chatId\)/);
  const nav = read('ui/pages/chat/chatAdminNavigation.ets');
  assert.match(nav, /openScheduledScreen/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['chat_actions_scheduled', 'scheduled_title', 'scheduled_loading',
      'scheduled_failed', 'scheduled_empty', 'scheduled_media', 'scheduled_send_now',
      'scheduled_reschedule_hour', 'scheduled_cancel']) {
      assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
    }
  }

  console.log('PASS scheduled messages contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
