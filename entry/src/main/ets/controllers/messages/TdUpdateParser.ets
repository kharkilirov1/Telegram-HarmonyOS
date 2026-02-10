import {
  TdChat,
  TdChatAction,
  TdChatPosition,
  TdFile,
  TdMessage,
  TdMessageContent,
  TdNotificationSettings,
  safeNumber
} from '../../models/TdTypes';

function toRecord(value: Object | undefined | null): Record<string, Object> | undefined {
  if (value === undefined || value === null) return undefined;
  return value as Record<string, Object>;
}

export interface TdChatPhoto {
  small?: TdFile;
  big?: TdFile;
}

export interface TdUsernames {
  editable_username?: string;
  active_usernames?: string[];
}

export interface TdUser {
  id?: number;
  first_name?: string;
  last_name?: string;
  username?: string;
  usernames?: TdUsernames;
  status?: Record<string, Object>;
}

export interface TdMessageReactionInfo {
  reaction?: Record<string, Object>;
  total_count?: number;
  is_chosen?: boolean;
}

export interface TdMessageInteractionInfo {
  reactions?: TdMessageReactionInfo[];
}

export interface ParsedUpdateNewChat {
  chat: TdChat;
}

export interface ParsedUpdateChatLastMessage {
  chatId: number;
  lastMessage?: TdMessage;
  positions?: TdChatPosition[];
}

export interface ParsedUpdateChatPosition {
  chatId: number;
  position: TdChatPosition;
}

export interface ParsedUpdateChatTitle {
  chatId: number;
  title: string;
}

export interface ParsedUpdateChatPhoto {
  chatId: number;
  photo?: TdChatPhoto;
}

export interface ParsedUpdateUser {
  user: TdUser;
}

export interface ParsedUpdateUserStatus {
  userId: number;
  status: Record<string, Object>;
}

export interface ParsedUpdateNewMessage {
  message: TdMessage;
}

export interface ParsedUpdateMessageContent {
  chatId: number;
  messageId: number;
  newContent: TdMessageContent;
}

export interface ParsedUpdateMessageInteractionInfo {
  chatId: number;
  messageId: number;
  interactionInfo: TdMessageInteractionInfo;
}

export interface ParsedUpdateDeleteMessages {
  chatId: number;
  messageIds: number[];
}

export interface ParsedUpdateChatReadInbox {
  chatId: number;
  unreadCount: number;
}

export interface ParsedUpdateChatNotificationSettings {
  chatId: number;
  settings: TdNotificationSettings;
}

export interface ParsedUpdateChatAction {
  chatId: number;
  action: TdChatAction;
}

export function parseUpdateNewChat(update: Record<string, Object>): ParsedUpdateNewChat | undefined {
  const chat = update['chat'] as TdChat | undefined;
  if (!chat) return undefined;
  return { chat: chat };
}

export function parseUpdateChatLastMessage(update: Record<string, Object>): ParsedUpdateChatLastMessage | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  if (chatId === 0) return undefined;
  const lastMessage = update['last_message'] as TdMessage | undefined;
  const positions = update['positions'] as TdChatPosition[] | undefined;
  return { chatId: chatId, lastMessage: lastMessage, positions: positions };
}

export function parseUpdateChatPosition(update: Record<string, Object>): ParsedUpdateChatPosition | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  if (chatId === 0) return undefined;
  const position = update['position'] as TdChatPosition | undefined;
  if (!position) return undefined;
  return { chatId: chatId, position: position };
}

export function parseUpdateChatTitle(update: Record<string, Object>): ParsedUpdateChatTitle | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  if (chatId === 0) return undefined;
  const title = (update['title'] as string) || '';
  return { chatId: chatId, title: title };
}

export function parseUpdateChatPhoto(update: Record<string, Object>): ParsedUpdateChatPhoto | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  if (chatId === 0) return undefined;
  const photo = update['photo'] as TdChatPhoto | undefined;
  return { chatId: chatId, photo: photo };
}

export function parseUpdateUser(update: Record<string, Object>): ParsedUpdateUser | undefined {
  const user = update['user'] as TdUser | undefined;
  if (!user) return undefined;
  return { user: user };
}

export function parseUpdateUserStatus(update: Record<string, Object>): ParsedUpdateUserStatus | undefined {
  const userId: number = safeNumber(update['user_id']);
  if (userId === 0) return undefined;
  const status = toRecord(update['status']);
  if (!status) return undefined;
  return { userId: userId, status: status };
}

export function parseUpdateNewMessage(update: Record<string, Object>): ParsedUpdateNewMessage | undefined {
  const message = update['message'] as TdMessage | undefined;
  if (!message) return undefined;
  return { message: message };
}

export function parseUpdateMessageContent(update: Record<string, Object>): ParsedUpdateMessageContent | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  const messageId: number = safeNumber(update['message_id']);
  if (chatId === 0 || messageId === 0) return undefined;
  const newContent = update['new_content'] as TdMessageContent | undefined;
  if (!newContent) return undefined;
  return { chatId: chatId, messageId: messageId, newContent: newContent };
}

export function parseUpdateMessageInteractionInfo(update: Record<string, Object>): ParsedUpdateMessageInteractionInfo | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  const messageId: number = safeNumber(update['message_id']);
  if (chatId === 0 || messageId === 0) return undefined;
  const interactionInfo = update['interaction_info'] as TdMessageInteractionInfo | undefined;
  if (!interactionInfo) return undefined;
  return { chatId: chatId, messageId: messageId, interactionInfo: interactionInfo };
}

export function parseUpdateDeleteMessages(update: Record<string, Object>): ParsedUpdateDeleteMessages | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  if (chatId === 0) return undefined;
  const rawIds = update['message_ids'] as number[] | undefined;
  if (!rawIds || rawIds.length === 0) return undefined;

  const messageIds: number[] = [];
  for (const value of rawIds) {
    messageIds.push(value);
  }

  if (messageIds.length === 0) return undefined;
  return { chatId: chatId, messageIds: messageIds };
}

export function parseUpdateChatReadInbox(update: Record<string, Object>): ParsedUpdateChatReadInbox | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  if (chatId === 0) return undefined;
  const unreadCount: number = safeNumber(update['unread_count']);
  return { chatId: chatId, unreadCount: unreadCount };
}

export function parseUpdateChatNotificationSettings(update: Record<string, Object>): ParsedUpdateChatNotificationSettings | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  if (chatId === 0) return undefined;
  const settings = update['notification_settings'] as TdNotificationSettings | undefined;
  if (!settings) return undefined;
  return { chatId: chatId, settings: settings };
}

export function parseUpdateChatAction(update: Record<string, Object>): ParsedUpdateChatAction | undefined {
  const chatId: number = safeNumber(update['chat_id']);
  if (chatId === 0) return undefined;
  const actionRecord = toRecord(update['action']);
  if (!actionRecord) return undefined;
  const action = actionRecord as TdChatAction;
  return { chatId: chatId, action: action };
}
