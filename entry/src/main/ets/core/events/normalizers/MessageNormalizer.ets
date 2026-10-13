// MessageNormalizer — handles all message-related TDLib updates
// Extracted from EventNormalizer to prevent god-file growth

import {
  AnyAppEvent,
  MessageUpdatedEvent,
  MessageContentUpdatedEvent,
  MessageSendSucceededEvent,
  MessageSendFailedEvent,
  MessagesDeletedEvent,
  createNewMessageEvent
} from '../../model/AppEvent';
import { createMessageDtoFromTd, getMessageChatId, getMessageId, parseMessageContent } from '../../model/dto/MessageDto';
import { TdObject } from '../../../models/TdTypes';
import {
  tdGetNumber, tdGetString, tdGetInt64, tdGetBoolean,
  tdGetObject, tdGetArray, tdGetStringArray
} from '../../utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'MessageNormalizer';

function handleNewMessage(events: AnyAppEvent[], update: TdObject): void {
  const message = tdGetObject(update, 'message');
  const chatId = getMessageChatId(message);
  const messageId = getMessageId(message);
  if (!chatId || messageId === '0') return;

  try {
    const messageDto = createMessageDtoFromTd(message);
    events.push(createNewMessageEvent(chatId, messageId, messageDto));
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'Failed to parse newMessage: %{public}s', String(error));
  }
}

function handleMessageContent(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  const messageId = tdGetInt64(update, 'message_id');
  if (!chatId || messageId === '0') return;

  const newContentObj = tdGetObject(update, 'new_content');
  const contentDto = parseMessageContent(newContentObj);

  const event = new MessageContentUpdatedEvent();
  event.chatId = chatId;
  event.messageId = messageId;
  event.newContent = contentDto;
  event.timestamp = Date.now();
  events.push(event);
}

function handleMessageEdited(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  const messageId = tdGetInt64(update, 'message_id');
  if (!chatId || messageId === '0') return;

  const event = new MessageUpdatedEvent();
  event.chatId = chatId;
  event.messageId = messageId;
  event.updates.editDate = tdGetNumber(update, 'edit_date');
  event.timestamp = Date.now();
  events.push(event);
}

function handleMessageSendSucceeded(events: AnyAppEvent[], update: TdObject): void {
  const message = tdGetObject(update, 'message');
  const oldMessageId = getMessageId(update, 'old_message_id');
  const chatId = getMessageChatId(message);
  if (!chatId || oldMessageId === '0' || getMessageId(message) === '0') return;

  try {
    const messageDto = createMessageDtoFromTd(message);

    const event = new MessageSendSucceededEvent();
    event.chatId = chatId;
    event.oldMessageId = oldMessageId;
    event.message = messageDto;
    event.timestamp = Date.now();
    events.push(event);
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'Failed to parse messageSendSucceeded: %{public}s', String(error));
  }
}

function handleMessageSendFailed(events: AnyAppEvent[], update: TdObject): void {
  const message = tdGetObject(update, 'message');
  const oldMessageId = getMessageId(update, 'old_message_id');
  const chatId = getMessageChatId(message);
  const messageId = getMessageId(message);
  if (!chatId || oldMessageId === '0' || messageId === '0') return;

  const error = update.getTopLevelObjectStrict('error');
  const code = error?.getTopLevelNumberStrict('code');
  const errorCode = code !== undefined && Number.isSafeInteger(code) ? code : 0;
  // No error-message accessor is called for code 406, including nested DTO state.
  const errorMessage = code !== undefined && Number.isSafeInteger(code) && errorCode !== 406
    ? (error?.getTopLevelStringStrict('message') ?? '') : '';

  try {
    const messageDto = createMessageDtoFromTd(message, errorCode === 406);
    const event = new MessageSendFailedEvent();
    event.chatId = chatId;
    event.oldMessageId = oldMessageId;
    event.messageId = messageId;
    event.message = messageDto;
    event.errorCode = errorCode;
    event.errorMessage = errorMessage;
    event.timestamp = Date.now();
    events.push(event);
  } catch (error) {
    // Do not log raw parsing exceptions from a message carrying a sending error.
    hilog.error(DOMAIN, TAG, 'Failed to parse messageSendFailed');
  }
}

function handleMessagesHistory(events: AnyAppEvent[], update: TdObject): void {
  // Response to getChatHistory: {"@type":"messages","total_count":N,"messages":[...]}
  const messages = tdGetArray(update, 'messages');
  for (let i = 0; i < messages.length; i++) {
    const msg = messages[i];
    const chatId = getMessageChatId(msg);
    const messageId = getMessageId(msg);
    if (!chatId || messageId === '0') continue;

    try {
      const dto = createMessageDtoFromTd(msg);
      events.push(createNewMessageEvent(chatId, messageId, dto));
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to parse history message: %{public}s', String(error));
    }
  }
}

function handleDeleteMessages(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const isPermanent = tdGetBoolean(update, 'is_permanent');
  const fromCache = tdGetBoolean(update, 'from_cache');

  const messageIds = tdGetStringArray(update, 'message_ids').filter((id: string) => id !== '0' && id !== '');
  if (messageIds.length === 0) return;

  const event = new MessagesDeletedEvent();
  event.chatId = chatId;
  event.messageIds = messageIds;
  event.isPermanent = isPermanent;
  event.fromCache = fromCache;
  event.timestamp = Date.now();
  events.push(event);
}

export function registerMessageHandlers(
  handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void>
): void {
  handlers.set('updateNewMessage', handleNewMessage);
  handlers.set('updateMessageContent', handleMessageContent);
  handlers.set('updateMessageEdited', handleMessageEdited);
  handlers.set('updateMessageSendSucceeded', handleMessageSendSucceeded);
  handlers.set('updateMessageSendFailed', handleMessageSendFailed);
  handlers.set('updateDeleteMessages', handleDeleteMessages);
  handlers.set('messages', handleMessagesHistory);
}
