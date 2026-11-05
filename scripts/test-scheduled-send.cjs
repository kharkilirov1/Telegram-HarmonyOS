// D21: holding Send with text schedules the message instead of sending it now.
// The menu owner lives on ChatComposerController, reached through a page-contract bridge, so the
// already-full ChatScreenSession does not need another delegate line.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const etsRoot = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(etsRoot, relative), 'utf8').replaceAll('\r\n', '\n');

function checkChain() {
  // Params and command carry the schedule date.
  const params = read('domain/usecases/sendMessage.ets');
  assert.match(params, /scheduledDateSeconds: number = 0;/);
  assert.match(params, /params\.scheduledDateSeconds\n      \);/);
  const command = read('core/model/AppCommand.ets');
  assert.match(command, /scheduledDateSeconds: number = 0\n\): SendMessageCommand \{/);
  assert.match(command, /cmd\.payload\.scheduledDateSeconds = scheduledDateSeconds;/);

  // The text sender keeps dice for immediate sends only.
  const textSend = read('ui/pages/chat/ChatTextSendController.ets');
  assert.match(textSend, /handleSend\(text: string, host: ChatTextSendHost, scheduledDateSeconds: number = 0\): void \{/);
  assert.match(textSend, /params\.scheduledDateSeconds = scheduledDateSeconds;/);
  assert.match(textSend, /if \(diceEmoji\.length > 0 && scheduledDateSeconds === 0 && host\.getReplyToMessageId\(\) === '0'\) \{/);

  // The menu owner: controller method with two presets wired into the same send path.
  const composer = read('ui/pages/chat/ChatComposerController.ets');
  const menuOwner = read('ui/pages/chat/ChatScheduledSendMenu.ets');
  assert.match(composer, /openScheduledSendMenu\(text: string, host: ChatComposerControllerHost\): void \{/);
  assert.match(menuOwner, /export function schedulePresets\(nowMs: number\): number\[\] \{/);
  assert.match(menuOwner, /tomorrow\.setHours\(9, 0, 0, 0\);/);
  assert.match(menuOwner, /showActionMenu\(\{/);
  assert.match(menuOwner, /send\(trimmed, seconds\);/);

  // Custom date and time: system dialogs, past dates rejected.
  assert.match(menuOwner, /export function pickScheduledDate\(context: UIContext, text: string, send: SendScheduledText\): void \{/);
  assert.match(menuOwner, /showDatePickerDialog\(\{/);
  assert.match(menuOwner, /showTimePickerDialog\(\{/);
  assert.match(menuOwner, /useMilitaryTime: true,/);
  assert.match(menuOwner, /if \(seconds > Math\.floor\(Date\.now\(\) \/ 1000\)\) \{/);
  assert.match(menuOwner, /buttons: \[b0, b1, b2\]/);
  assert.match(menuOwner, /schedule_send_custom/);

  // Bridge: bindings call the controller directly (no Session delegate line).
  const bindings = read('ui/pages/chat/ChatScreenViewBindings.ets');
  assert.match(bindings, /openScheduledSendMenu\(text: string\): void \{ this\.session\.composerCtrl\.openScheduledSendMenu\(text, this\.session\); \}/);
  const ports = read('ui/pages/chat/ChatScreenViewPorts.ets');
  assert.match(ports, /openScheduledSendMenu\(text: string\): void;/);

  // Atom + dock: a hold with a send intent reports the text.
  const atom = read('ui/tg_ui/atoms/TgComposerInput.ets');
  assert.match(atom, /@Event onSendLongPress: \(text: string\) => void/);
  assert.match(atom, /if \(this\.hasSendIntent\(\)\) \{\n      const trimmed = this\.text\.trim\(\);/);
  const dock = read('ui/pages/chat/TgChatComposerDock.ets');
  assert.match(dock, /onSendLongPress: \(text: string\): void => \{/);
  assert.match(dock, /this\.bindings\.openScheduledSendMenu\(text\);/);

  // Gate registration keeps the bridge honest.
  const gate = fs.readFileSync(path.join(__dirname, 'test-chat-screen-decomposition.cjs'), 'utf8');
  assert.match(gate, /openScheduledSendMenu: \['composerCtrl', 'openScheduledSendMenu', 'ChatComposerController'\]/);


  // Scheduled list: the same picker reschedules an existing message.
  const listPage = read('ui/pages/chat/TgChatScheduledMessagesPage.ets');
  assert.match(listPage, /type ScheduledRowAction = 'sendNow' \| 'rescheduleHour' \| 'rescheduleCustom' \| 'cancel';/);
  assert.match(listPage, /const actions: ScheduledRowAction\[\] = \['sendNow', 'rescheduleHour', 'rescheduleCustom', 'cancel'\];/);
  assert.match(listPage, /buttons: \[b0, b1, b2, b3\]/);
  assert.match(listPage, /if \(action === 'rescheduleCustom'\) \{/);
  assert.match(listPage, /pickScheduledDate\(this\.getUIContext\(\), message\.text,/);
  assert.match(listPage, /useCase\.reschedule\(this\.chatId, message\.messageId, seconds, nowSeconds\)/);
  assert.match(listPage, /scheduled_reschedule_custom/);

  console.log('PASS scheduled send contract');
}

checkChain();
