// I1: local notifications for incoming messages. iOS posts a notification when a message arrives while
// the app is in the background and the chat is not the one on screen; muted chats stay silent.
// The decision and the text are pure functions so the bridge stays a thin platform adapter.

import { AppState } from '../../core/model/AppState';
import { NewMessageEvent } from '../../core/model/AppEvent';
import { MessageDto } from '../../core/model/dto/MessageDto';

export const NOTIFICATION_BODY_MAX_LENGTH = 160;
export const NOTIFICATION_MEDIA_BODY = 'New message';

export class MessageNotificationContent {
  chatId: number = 0;
  title: string = '';
  body: string = '';
}

function truncate(value: string, limit: number): string {
  const trimmed = value.trim();
  return trimmed.length > limit ? trimmed.substring(0, limit) + '…' : trimmed;
}

// Pure gate: background only, incoming only, and never for the chat on screen.
export function shouldPublishMessageNotification(state: AppState, event: NewMessageEvent,
  appForeground: boolean, activeChatId: number): boolean {
  if (appForeground) {
    return false;
  }
  const message = event.messageData;
  if (message.isOutgoing || message.chatId === activeChatId) {
    return false;
  }
  if (message.chatId !== event.chatId || message.chatId === 0) {
    return false;
  }
  const chat = state.chats.chats.get(message.chatId);
  if (chat === undefined || chat.muteForSeconds > 0) {
    return false;
  }
  return true;
}

// Pure text builder: chat title as the notification title, sender plus preview as the body.
export function buildMessageNotificationContent(state: AppState, event: NewMessageEvent): MessageNotificationContent {
  const content = new MessageNotificationContent();
  const message: MessageDto = event.messageData;
  content.chatId = message.chatId;
  const chat = state.chats.chats.get(message.chatId);
  content.title = chat !== undefined && chat.title.length > 0 ? chat.title : 'Telegram';

  const sender = message.senderId > 0 ? state.users.users.get(message.senderId) : undefined;
  const senderName = sender !== undefined
    ? (sender.firstName + (sender.lastName.length > 0 ? ' ' + sender.lastName : '')).trim()
    : '';
  const text = message.content.text.length > 0 ? message.content.text : message.content.caption;
  const preview = text.trim().length > 0 ? text : NOTIFICATION_MEDIA_BODY;
  const body = senderName.length > 0 ? senderName + ': ' + preview : preview;
  content.body = truncate(body, NOTIFICATION_BODY_MAX_LENGTH);
  return content;
}
