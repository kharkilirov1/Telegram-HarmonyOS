// Application events - normalized events from TDLib updates
// These are domain-specific events that reducers understand

import { ChatId, UserId, MessageId } from './EntityId';
import { ChatDto, ChatUpdateDto } from './dto/ChatDto';
import { MessageDto, MessageUpdateDto, MessageContentDto } from './dto/MessageDto';
import { UserDto, UserUpdateDto } from './dto/UserDto';

// Base event class
export class AppEvent {
  type: string = '';
  timestamp: number = 0;
}

// Type definitions for event states
export type AuthState = 'waitPhoneNumber' | 'waitCode' | 'waitPassword' | 'waitRegistration' |
  'waitTdlibParameters' | 'waitQrCode' | 'ready' | 'loggingOut' | 'closing' | 'closed';
export type ConnectionState = 'updating' | 'ready' | 'connecting' | 'waitingForNetwork';

// --- Auth events ---

export class AuthStateChangedEvent extends AppEvent {
  type: string = 'authStateChanged';
  state: AuthState = 'waitPhoneNumber';
  userId: UserId = 0;
  phoneNumber: string = '';
  codeType: string = '';
  codeLength: number = 0;
  codeTimeout: number = -1;
  nextCodeType: string = '';
  passwordHint: string = '';
  qrCodeLink: string = '';
}

// Fired after getMe() resolves — sets the current user's ID
export class MyUserResolvedEvent extends AppEvent {
  type: string = 'myUserResolved';
  userId: UserId = 0;
}

// --- Connection events ---

export class ConnectionStateChangedEvent extends AppEvent {
  type: string = 'connectionStateChanged';
  state: ConnectionState = 'connecting';
}

// --- Chat events ---

export class NewChatEvent extends AppEvent {
  type: string = 'newChat';
  chatId: ChatId = 0;
  chatData: ChatDto = new ChatDto();
}

export class ChatUpdatedEvent extends AppEvent {
  type: string = 'chatUpdated';
  chatId: ChatId = 0;
  updates: ChatUpdateDto = new ChatUpdateDto();
}

export class ChatReadInboxEvent extends AppEvent {
  type: string = 'chatReadInbox';
  chatId: ChatId = 0;
  unreadCount: number = 0;
  lastReadInboxMessageId: MessageId = '0';
}

export class ChatReadOutboxEvent extends AppEvent {
  type: string = 'chatReadOutbox';
  chatId: ChatId = 0;
  lastReadOutboxMessageId: MessageId = '0';
}

export class ChatsLoadStateChangedEvent extends AppEvent {
  type: string = 'chatsLoadStateChanged';
  isLoading: boolean = false;
  hasMore: boolean = true;
  phase: string = 'idle';
}

// --- Message events ---

export class NewMessageEvent extends AppEvent {
  type: string = 'newMessage';
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  messageData: MessageDto = new MessageDto();
}

export class MessageUpdatedEvent extends AppEvent {
  type: string = 'messageUpdated';
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  updates: MessageUpdateDto = new MessageUpdateDto();
}

export class MessageContentUpdatedEvent extends AppEvent {
  type: string = 'messageContentUpdated';
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  newContent: MessageContentDto = new MessageContentDto();
}

export class MessageSendSucceededEvent extends AppEvent {
  type: string = 'messageSendSucceeded';
  chatId: ChatId = 0;
  oldMessageId: MessageId = '0';
  message: MessageDto = new MessageDto();
}

export class MessageSendFailedEvent extends AppEvent {
  type: string = 'messageSendFailed';
  chatId: ChatId = 0;
  oldMessageId: MessageId = '0';
  messageId: MessageId = '0';
  errorCode: number = 0;
  errorMessage: string = '';
}

export class MessagesDeletedEvent extends AppEvent {
  type: string = 'messagesDeleted';
  chatId: ChatId = 0;
  messageIds: MessageId[] = [];
  isPermanent: boolean = false;
  fromCache: boolean = false;
}

// --- User events ---

// Явный интерфейс для частичного обновления пользователя
export interface UserUpdateFields {
  firstName?: string;
  lastName?: string;
  username?: string;
  phoneNumber?: string;
  photo?: UserPhotoFields;
  status?: string;
  isContact?: boolean;
  isVerified?: boolean;
  isPremium?: boolean;
}

export interface UserPhotoFields {
  small: string;
  big: string;
  smallFileId?: number;
}

export class UserUpdatedEvent extends AppEvent {
  type: string = 'userUpdated';
  userId: UserId = 0;
  userData: UserDto = new UserDto();
  // Partial update fields
  updates?: UserUpdateFields;
}

export class UserStatusChangedEvent extends AppEvent {
  type: string = 'userStatusChanged';
  userId: UserId = 0;
  status: string = 'offline';
}

// --- Chat action events (typing indicators) ---

export class ChatActionEvent extends AppEvent {
  type: string = 'chatAction';
  chatId: ChatId = 0;
  senderUserId: UserId = 0;
  actionType: string = ''; // 'typing', 'cancel', 'recordingVideo', 'uploadingPhoto', etc.
}

// --- Full info events (profile screen) ---

export class UserFullInfoEvent extends AppEvent {
  type: string = 'userFullInfo';
  userId: UserId = 0;
  bio: string = '';
}

export class ChatFullInfoEvent extends AppEvent {
  type: string = 'chatFullInfo';
  chatId: ChatId = 0;
  description: string = '';
  memberCount: number = 0;
  inviteLink: string = '';
  administratorCount: number = 0;
}

// --- File events ---

export class FileDownloadedEvent extends AppEvent {
  type: string = 'fileDownloaded';
  fileId: number = 0;
  localPath: string = '';
  isComplete: boolean = false;
}

// --- Unified type for all events ---

export type AnyAppEvent =
  | AuthStateChangedEvent
  | MyUserResolvedEvent
  | ConnectionStateChangedEvent
  | NewChatEvent
  | ChatUpdatedEvent
  | ChatReadInboxEvent
  | ChatReadOutboxEvent
  | ChatsLoadStateChangedEvent
  | NewMessageEvent
  | MessageUpdatedEvent
  | MessageContentUpdatedEvent
  | MessageSendSucceededEvent
  | MessageSendFailedEvent
  | MessagesDeletedEvent
  | UserUpdatedEvent
  | UserStatusChangedEvent
  | ChatActionEvent
  | UserFullInfoEvent
  | ChatFullInfoEvent
  | FileDownloadedEvent;

// --- Factory helpers ---

export function createAuthStateChangedEvent(
  state: AuthState,
  userId?: UserId
): AuthStateChangedEvent {
  const event = new AuthStateChangedEvent();
  event.state = state;
  event.userId = userId || 0;
  event.timestamp = Date.now();
  return event;
}

export function createMyUserResolvedEvent(userId: UserId): MyUserResolvedEvent {
  const event = new MyUserResolvedEvent();
  event.userId = userId;
  event.timestamp = Date.now();
  return event;
}

export function createNewMessageEvent(
  chatId: ChatId,
  messageId: MessageId,
  messageData: MessageDto
): NewMessageEvent {
  const event = new NewMessageEvent();
  event.chatId = chatId;
  event.messageId = messageId;
  event.messageData = messageData;
  event.timestamp = Date.now();
  return event;
}

export function createNewChatEvent(
  chatId: ChatId,
  chatData: ChatDto
): NewChatEvent {
  const event = new NewChatEvent();
  event.chatId = chatId;
  event.chatData = chatData;
  event.timestamp = Date.now();
  return event;
}

export function createChatUpdatedEvent(
  chatId: ChatId,
  updates: ChatUpdateDto
): ChatUpdatedEvent {
  const event = new ChatUpdatedEvent();
  event.chatId = chatId;
  event.updates = updates;
  event.timestamp = Date.now();
  return event;
}

export function createChatsLoadStateChangedEvent(
  isLoading: boolean,
  hasMore: boolean,
  phase: string = 'idle'
): ChatsLoadStateChangedEvent {
  const event = new ChatsLoadStateChangedEvent();
  event.isLoading = isLoading;
  event.hasMore = hasMore;
  event.phase = phase;
  event.timestamp = Date.now();
  return event;
}
