// Application state - single source of truth
// All UI data comes from this state via selectors

import { ChatId, UserId, MessageId } from './EntityId';
import { AnyAppEvent } from './AppEvent';

// Type definitions
export type AuthStatus = 'notInitialized' | 'waitTdlibParameters' | 'waitPhoneNumber' | 'waitCode' | 'waitPassword' | 'waitRegistration' | 'ready' | 'loggingOut' | 'closing' | 'closed';
export type ConnectionStatus = 'updating' | 'ready' | 'connecting' | 'waitingForNetwork';
export type ChatType = 'private' | 'group' | 'supergroup' | 'channel';
export type MessageContentType = 'text' | 'photo' | 'video' | 'document' | 'audio' | 'voice' | 'sticker' | 'location' | 'contact' | 'poll' | 'animation' | 'videoNote' | 'unknown';
export type MessageSendStatus = 'none' | 'pending' | 'sent' | 'failed';
export type UserStatusType = 'online' | 'offline' | 'recently' | 'lastWeek' | 'lastMonth' | 'longTimeAgo';

// Auth state
export class AuthState {
  status: AuthStatus = 'notInitialized';
  userId: UserId = 0;
  phoneNumber: string = '';
  error: string = '';
}

// Connection state
export class ConnectionState {
  status: ConnectionStatus = 'connecting';
  lastUpdated: number = 0;
}

// Chat last message - uses string for MessageId (int64)
export class ChatLastMessage {
  id: MessageId = '0';
  text: string = '';
  timestamp: number = 0;
}

// Chat/Dialog state
export class Chat {
  id: ChatId = 0;
  type: ChatType = 'private';
  title: string = '';
  unreadCount: number = 0;
  lastMessage?: ChatLastMessage;
  isPinned: boolean = false;
  photoSmall: string = '';
  order: string = '0'; // TDLib int64 sort key as string; '0' = not in chatListMain
}

export class DialogsState {
  chats: Map<ChatId, Chat> = new Map<ChatId, Chat>();
  orderedChatIds: ChatId[] = [];
  isLoading: boolean = false;
  hasMore: boolean = true;
}

// Message content
export class MessageContent {
  type: MessageContentType = 'text';
  text: string = '';
}

// Message state - uses string for MessageId (int64)
export class Message {
  id: MessageId = '0';
  chatId: ChatId = 0;
  senderId: UserId = 0;
  senderChatId: ChatId = 0;
  content: MessageContent = new MessageContent();
  timestamp: number = 0;
  isOutgoing: boolean = false;
  isRead: boolean = false;
  isPending: boolean = false;
  editDate: number = 0;
  replyToMessageId: MessageId = '0';
  sendStatus: MessageSendStatus = 'none';
  sendErrorCode: number = 0;
  sendErrorMessage: string = '';
}

// Pending message
export class PendingMessage {
  chatId: ChatId = 0;
  text: string = '';
  timestamp: number = 0;
}

// Messages state - uses string keys for MessageId (int64)
export class MessagesState {
  messages: Map<ChatId, Map<MessageId, Message>> = new Map<ChatId, Map<MessageId, Message>>();
  pendingMessages: Map<string, PendingMessage> = new Map<string, PendingMessage>();
}

// User state
export class User {
  id: UserId = 0;
  firstName: string = '';
  lastName: string = '';
  username: string = '';
  phoneNumber: string = '';
  photoSmall: string = '';
  photoBig: string = '';
  status: UserStatusType = 'offline';
  isContact: boolean = false;
  isVerified: boolean = false;
  isPremium: boolean = false;
}

export class UsersState {
  users: Map<UserId, User> = new Map<UserId, User>();
}

// Root application state
export class AppState {
  auth: AuthState = new AuthState();
  connection: ConnectionState = new ConnectionState();
  dialogs: DialogsState = new DialogsState();
  messages: MessagesState = new MessagesState();
  users: UsersState = new UsersState();
  lastEvent?: AnyAppEvent;
  version: number = 1;
}

// Initial state
export function createInitialAppState(): AppState {
  const state = new AppState();
  state.auth.status = 'notInitialized';
  state.connection.status = 'connecting';
  state.connection.lastUpdated = Date.now();
  return state;
}

export const initialAppState: AppState = createInitialAppState();

// Note: For state cloning, use the explicit clone functions from ../utils/stateClone.ets
// Generic cloneState is removed because ArkTS doesn't support:
// - for...in loops
// - indexed access on objects
// - any/unknown types

// Type guard for reducer actions
export type ReducerAction = AnyAppEvent;
