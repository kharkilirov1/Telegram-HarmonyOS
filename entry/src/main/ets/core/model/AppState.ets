// Application state - single source of truth
// All UI data comes from this state via selectors

import { ChatId, UserId, MessageId } from './EntityId';
import { AnyAppEvent } from './AppEvent';

// Type definitions
export type AuthStatus = 'notInitialized' | 'waitTdlibParameters' | 'waitPhoneNumber' | 'waitCode' | 'waitPassword' | 'waitRegistration' | 'waitQrCode' | 'ready' | 'loggingOut' | 'closing' | 'closed';
export type ConnectionStatus = 'updating' | 'ready' | 'connecting' | 'waitingForNetwork';
export type ChatType = 'private' | 'secret' | 'group' | 'supergroup' | 'channel';
export type ChatsLoadPhase = 'idle' | 'bootstrap' | 'pagination';
export type MessageContentType = 'text' | 'photo' | 'video' | 'document' | 'audio' | 'voice' | 'sticker' | 'location' | 'contact' | 'poll' | 'animation' | 'videoNote' | 'unknown';
export type MessageSendStatus = 'none' | 'pending' | 'sent' | 'failed';
export type UserStatusType = 'online' | 'offline' | 'recently' | 'lastWeek' | 'lastMonth' | 'longTimeAgo';

// Auth state
export class AuthState {
  status: AuthStatus = 'notInitialized';
  userId: UserId = 0;
  phoneNumber: string = '';
  codeType: string = 'sms';
  codeLength: number = 5;
  codeTimeout: number = 60;
  nextCodeType: string = 'call';
  passwordHint: string = '';
  qrCodeLink: string = '';
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

// Chat state
export class Chat {
  id: ChatId = 0;
  type: ChatType = 'private';
  peerUserId: UserId = 0; // for private/secret chats
  accentColorId: number = -1;
  title: string = '';
  unreadCount: number = 0;
  unreadMentionCount: number = 0;
  muteForSeconds: number = 0;
  lastReadOutboxMessageId: MessageId = '0';
  lastReadInboxMessageId: MessageId = '0';
  lastMessage?: ChatLastMessage;
  draftText: string = '';
  draftReplyToMessageId: MessageId = '0';
  isPinned: boolean = false;
  photoSmall: string = '';
  photoSmallFileId: number = 0;
  order: string = '0'; // TDLib int64 sort key as string; '0' = not in chatListMain
  memberCount: number = 0;
  description: string = '';
  supergroupId: number = 0; // TDLib supergroup_id for fetching full info
  inviteLink: string = '';
  administratorCount: number = 0;
}

// Typing indicator per chat
export class ChatTypingInfo {
  senderUserId: UserId = 0;
  actionType: string = 'typing'; // 'typing', 'recordingVideo', 'uploadingPhoto', etc.
  timestamp: number = 0;
}

export class ChatsState {
  chats: Map<ChatId, Chat> = new Map<ChatId, Chat>();
  orderedChatIds: ChatId[] = [];
  typingActions: Map<ChatId, ChatTypingInfo> = new Map<ChatId, ChatTypingInfo>();
  isLoading: boolean = false;
  hasMore: boolean = true;
  loadPhase: ChatsLoadPhase = 'idle';
}

export class MessageQuoteEntity {
  offset: number = 0;
  length: number = 0;
  isCollapsed: boolean = false;
}

// Rich text entity from TDLib formattedText.entities
export class TextEntity {
  offset: number = 0;
  length: number = 0;
  type: string = ''; // bold, italic, underline, strikethrough, code, pre, url, textUrl, mention, mentionName, hashtag, cashtag, botCommand, emailAddress, phoneNumber, spoiler, customEmoji, blockQuote, expandableBlockQuote
  url: string = ''; // for textUrl type
  userId: number = 0; // for mentionName type
  language: string = ''; // for preCode type
}

// Message content
export class MessageContent {
  type: MessageContentType = 'text';
  text: string = '';
  caption: string = '';
  quoteEntities: MessageQuoteEntity[] = [];
  textEntities: TextEntity[] = [];
  captionEntities: TextEntity[] = [];

  // Photo
  photoPath: string = '';
  photoThumbPath: string = '';
  photoFileId: number = 0;
  photoThumbFileId: number = 0;
  photoWidth: number = 0;
  photoHeight: number = 0;
  photoMinithumb: string = ''; // base64 JPEG из TDLib minithumbnail — мгновенный blur-превью

  // Video
  videoPath: string = '';
  videoThumbPath: string = '';
  videoFileId: number = 0;
  videoThumbFileId: number = 0;
  videoDuration: number = 0;
  videoWidth: number = 0;
  videoHeight: number = 0;

  // Document
  documentPath: string = '';
  documentFileId: number = 0;
  fileName: string = '';
  fileSize: number = 0;
  mimeType: string = '';

  // Audio
  audioPath: string = '';
  audioFileId: number = 0;
  audioDuration: number = 0;
  audioTitle: string = '';
  audioPerformer: string = '';

  // Voice note
  voicePath: string = '';
  voiceFileId: number = 0;
  voiceDuration: number = 0;
  voiceWaveform: string = '';
  isVoiceListened: boolean = false;

  // Sticker
  stickerPath: string = '';
  stickerFileId: number = 0;
  stickerEmoji: string = '';
  stickerWidth: number = 0;
  stickerHeight: number = 0;
  isAnimatedSticker: boolean = false;
  isVideoSticker: boolean = false;
  isPremiumSticker: boolean = false;

  // Animation
  animationPath: string = '';
  animationFileId: number = 0;
  animationDuration: number = 0;
  animationWidth: number = 0;
  animationHeight: number = 0;

  // Video note
  videoNotePath: string = '';
  videoNoteFileId: number = 0;
  videoNoteDuration: number = 0;
  videoNoteLength: number = 0;

  // Contact
  contactFirstName: string = '';
  contactLastName: string = '';
  contactPhoneNumber: string = '';
  contactUserId: number = 0;

  // Location
  locationLatitude: number = 0;
  locationLongitude: number = 0;
  locationVenueTitle: string = '';
  locationVenueAddress: string = '';

  // Poll
  pollQuestion: string = '';
  pollTotalVoterCount: number = 0;
  pollIsClosed: boolean = false;
  pollIsAnonymous: boolean = true;
  pollType: string = 'regular'; // 'regular' | 'quiz'
  pollOptions: PollOption[] = [];
}

export class PollOption {
  text: string = '';
  voterCount: number = 0;
  votePercentage: number = 0;
  isChosen: boolean = false;
}

// Message state - uses string for MessageId (int64)
export class Message {
  id: MessageId = '0';
  chatId: ChatId = 0;
  senderId: UserId = 0;
  senderChatId: ChatId = 0;
  mediaAlbumId: MessageId = '0';
  content: MessageContent = new MessageContent();
  timestamp: number = 0;
  isOutgoing: boolean = false;
  isRead: boolean = false;
  isPending: boolean = false;
  editDate: number = 0;
  replyToMessageId: MessageId = '0';
  replyIsQuote: boolean = false;
  replyQuoteText: string = '';
  replyQuoteOffset: number = -1;
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

// File transfer state
export class FileTransfer {
  fileId: number = 0;
  localPath: string = '';
  isDownloadingActive: boolean = false;
  isDownloadingCompleted: boolean = false;
  size: number = 0;
  expectedSize: number = 0;
  downloadOffset: number = 0;
  downloadedPrefixSize: number = 0;
  downloadedSize: number = 0;
}

export class FilesState {
  transfers: Map<number, FileTransfer> = new Map<number, FileTransfer>();
}

export class AccentColorDefinition {
  id: number = -1;
  builtInAccentColorId: number = -1;
  lightThemeColors: number[] = [];
  darkThemeColors: number[] = [];
  minChannelChatBoostLevel: number = 0;
}

export class AccentColorsState {
  colors: Map<number, AccentColorDefinition> = new Map<number, AccentColorDefinition>();
  availableAccentColorIds: number[] = [];
}

// User state
export class User {
  id: UserId = 0;
  firstName: string = '';
  lastName: string = '';
  username: string = '';
  accentColorId: number = -1;
  phoneNumber: string = '';
  photoSmall: string = '';
  photoBig: string = '';
  photoSmallFileId: number = 0;
  status: UserStatusType = 'offline';
  isContact: boolean = false;
  isVerified: boolean = false;
  isScam: boolean = false;
  isFake: boolean = false;
  isPremium: boolean = false;
  bio: string = '';
}

export class UsersState {
  users: Map<UserId, User> = new Map<UserId, User>();
}

// Root application state
export class AppState {
  auth: AuthState = new AuthState();
  connection: ConnectionState = new ConnectionState();
  chats: ChatsState = new ChatsState();
  messages: MessagesState = new MessagesState();
  files: FilesState = new FilesState();
  accentColors: AccentColorsState = new AccentColorsState();
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
