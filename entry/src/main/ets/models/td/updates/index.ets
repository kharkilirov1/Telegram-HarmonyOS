// TDLib update types
// Real-time updates from TDLib

import { TdChat } from '../chats';
import { TdMessage, TdMessageContent } from '../messages';
import { TdChatPosition, TdNotificationSettings, TdChatAction } from '../chats';

export interface TdUpdateNewChat {
  chat?: TdChat;
}

export interface TdUpdateChatLastMessage {
  chat_id: number;
  last_message?: TdMessage;
  positions?: TdChatPosition[];
}

export interface TdUpdateChatPosition {
  chat_id: number;
  position?: TdChatPosition;
}

export interface TdUpdateNewMessage {
  message?: TdMessage;
}

export interface TdUpdateMessageContent {
  chat_id: number;
  message_id: number;
  new_content?: TdMessageContent;
}

export interface TdUpdateChatReadInbox {
  chat_id: number;
  unread_count: number;
}

export interface TdUpdateChatNotificationSettings {
  chat_id: number;
  notification_settings?: TdNotificationSettings;
}

export interface TdUpdateChatAction {
  chat_id: number;
  action?: TdChatAction;
}