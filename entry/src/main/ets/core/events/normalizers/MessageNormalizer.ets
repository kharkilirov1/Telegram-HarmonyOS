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
import { createMessageDtoFromTd, parseMessageContent } from '../../model/dto/MessageDto';
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
  const chatId = tdGetNumber(message, 'chat_id');
  const messageId = tdGetInt64(message, 'id');
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
  const oldMessageId = tdGetInt64(update, 'old_message_id');
  const chatId = tdGetNumber(message, 'chat_id');
  if (!chatId || oldMessageId === '0') return;

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
  const oldMessageId = tdGetInt64(update, 'old_message_id');
  const chatId = tdGetNumber(message, 'chat_id');
  const messageId = tdGetInt64(message, 'id');
  if (!chatId || oldMessageId === '0') return;

  const errorObj = tdGetObject(update, 'error');
  const errorCode = tdGetNumber(errorObj, 'code');
  const errorMessage = tdGetString(errorObj, 'message');

  const event = new MessageSendFailedEvent();
  event.chatId = chatId;
  event.oldMessageId = oldMessageId;
  event.messageId = messageId;
  event.errorCode = errorCode;
  event.errorMessage = errorMessage;
  event.timestamp = Date.now();
  events.push(event);
}

function handleMessagesHistory(events: AnyAppEvent[], update: TdObject): void {
  // Response to getChatHistory: {"@type":"messages","total_count":N,"messages":[...]}
  const messages = tdGetArray(update, 'messages');
  for (let i = 0; i < messages.length; i++) {
    const msg = messages[i];
    const chatId = tdGetNumber(msg, 'chat_id');
    const messageId = tdGetInt64(msg, 'id');
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
