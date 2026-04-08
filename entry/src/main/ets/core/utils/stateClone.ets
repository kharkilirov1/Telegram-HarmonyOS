// State cloning utilities - immutable state updates
// Shared across all reducers to eliminate code duplication
// Includes selective cloning for performance optimization

import {
  AppState,
  AuthState,
  ConnectionState,
  ChatsState,
  MessagesState,
  FilesState,
  AccentColorsState,
  AccentColorDefinition,
  UsersState,
  Chat,
  ChatLastMessage,
  Message,
  PendingMessage,
  User,
  FileTransfer
} from '../model/AppState';

/**
 * Clone AuthState immutably
 */
export function cloneAuthState(auth: AuthState): AuthState {
  const newAuth = new AuthState();
  newAuth.status = auth.status;
  newAuth.userId = auth.userId;
  newAuth.phoneNumber = auth.phoneNumber;
  newAuth.codeType = auth.codeType;
  newAuth.codeLength = auth.codeLength;
  newAuth.codeTimeout = auth.codeTimeout;
  newAuth.nextCodeType = auth.nextCodeType;
  newAuth.passwordHint = auth.passwordHint;
  newAuth.qrCodeLink = auth.qrCodeLink;
  newAuth.error = auth.error;
  return newAuth;
}

/**
 * Clone ConnectionState immutably
 */
export function cloneConnectionState(connection: ConnectionState): ConnectionState {
  const newConnection = new ConnectionState();
  newConnection.status = connection.status;
  newConnection.lastUpdated = connection.lastUpdated;
  return newConnection;
}

/**
 * Clone ChatsState immutably
 */
export function cloneChatsState(chats: ChatsState): ChatsState {
  const newChats = new ChatsState();
  // Clone maps and arrays
  newChats.chats = new Map<number, Chat>();
  chats.chats.forEach((chat: Chat, chatId: number) => {
    newChats.chats.set(chatId, chat);
  });
  newChats.orderedChatIds = chats.orderedChatIds.slice();
  newChats.typingActions = chats.typingActions; // shallow share — cloned in reducer when modified
  newChats.isLoading = chats.isLoading;
  newChats.hasMore = chats.hasMore;
  newChats.loadPhase = chats.loadPhase;
  return newChats;
}

/**
 * Clone MessagesState immutably
 * Uses string keys for MessageId (int64 stored as string)
 */
export function cloneMessagesState(messages: MessagesState): MessagesState {
  const newMessages = new MessagesState();
  // Share inner maps by reference — reducer creates new Map only for the modified chat.
  // This preserves reference identity for unchanged chats, enabling selector memoization.
  newMessages.messages = new Map<number, Map<string, Message>>(messages.messages);
  newMessages.pendingMessages = new Map<string, PendingMessage>(messages.pendingMessages);
  return newMessages;
}

/**
 * Clone FilesState immutably
 */
export function cloneFilesState(files: FilesState): FilesState {
  const newFiles = new FilesState();
  newFiles.transfers = new Map<number, FileTransfer>(files.transfers);
  return newFiles;
}

export function cloneAccentColorsState(accentColors: AccentColorsState): AccentColorsState {
  const newAccentColors = new AccentColorsState();
  newAccentColors.colors = new Map<number, AccentColorDefinition>();
  accentColors.colors.forEach((value: AccentColorDefinition, key: number) => {
    const color = new AccentColorDefinition();
    color.id = value.id;
    color.builtInAccentColorId = value.builtInAccentColorId;
    color.lightThemeColors = value.lightThemeColors.slice();
    color.darkThemeColors = value.darkThemeColors.slice();
    color.minChannelChatBoostLevel = value.minChannelChatBoostLevel;
    newAccentColors.colors.set(key, color);
  });
  newAccentColors.availableAccentColorIds = accentColors.availableAccentColorIds.slice();
  return newAccentColors;
}

/**
 * Clone UsersState immutably
 */
export function cloneUsersState(users: UsersState): UsersState {
  const newUsers = new UsersState();
  newUsers.users = new Map<number, User>(users.users);
  return newUsers;
}

/**
 * Clone a single Chat immutably
 */
export function cloneChat(chat: Chat): Chat {
  const newChat = new Chat();
  newChat.id = chat.id;
  newChat.type = chat.type;
  newChat.peerUserId = chat.peerUserId;
  newChat.accentColorId = chat.accentColorId;
  newChat.title = chat.title;
  newChat.unreadCount = chat.unreadCount;
  newChat.unreadMentionCount = chat.unreadMentionCount;
  newChat.muteForSeconds = chat.muteForSeconds;
  newChat.lastReadOutboxMessageId = chat.lastReadOutboxMessageId;
  newChat.lastReadInboxMessageId = chat.lastReadInboxMessageId;
  newChat.draftText = chat.draftText;
  newChat.draftReplyToMessageId = chat.draftReplyToMessageId;
  newChat.isPinned = chat.isPinned;
  newChat.photoSmall = chat.photoSmall;
  newChat.photoSmallFileId = chat.photoSmallFileId;
  newChat.order = chat.order;
  newChat.memberCount = chat.memberCount;
  newChat.description = chat.description;
  newChat.supergroupId = chat.supergroupId;
  newChat.inviteLink = chat.inviteLink;
  newChat.administratorCount = chat.administratorCount;
  if (chat.lastMessage) {
    const lm = new ChatLastMessage();
    lm.id = chat.lastMessage.id;
    lm.text = chat.lastMessage.text;
    lm.timestamp = chat.lastMessage.timestamp;
    newChat.lastMessage = lm;
  }
  return newChat;
}

/**
 * Clone a single User immutably
 */
export function cloneUser(user: User): User {
  const newUser = new User();
  newUser.id = user.id;
  newUser.firstName = user.firstName;
  newUser.lastName = user.lastName;
  newUser.username = user.username;
  newUser.accentColorId = user.accentColorId;
  newUser.phoneNumber = user.phoneNumber;
  newUser.photoSmall = user.photoSmall;
  newUser.photoBig = user.photoBig;
  newUser.photoSmallFileId = user.photoSmallFileId;
  newUser.status = user.status;
  newUser.isContact = user.isContact;
  newUser.isVerified = user.isVerified;
  newUser.isScam = user.isScam;
  newUser.isFake = user.isFake;
  newUser.isPremium = user.isPremium;
  newUser.bio = user.bio;
  return newUser;
}

/**
 * Create a new AppState with all substates cloned
 * Useful for reducer initialization
 */
export function cloneAppState(state: AppState): AppState {
  const newState = new AppState();
  newState.auth = cloneAuthState(state.auth);
  newState.connection = cloneConnectionState(state.connection);
  newState.chats = cloneChatsState(state.chats);
  newState.messages = cloneMessagesState(state.messages);
  newState.files = cloneFilesState(state.files);
  newState.accentColors = cloneAccentColorsState(state.accentColors);
  newState.users = cloneUsersState(state.users);
  newState.lastEvent = state.lastEvent;
  newState.version = state.version;
  return newState;
}

// --- Selective clones — deep-copy only the slice being modified ---
// Other slices are shared by reference (safe because reducers are pure)

/**
 * Shallow-clone AppState: all slices shared by reference.
 * Each cloneStateFor* then replaces only the slice it modifies.
 * Adding a new state slice only requires updating this function.
 */
function shallowCloneAppState(state: AppState): AppState {
  const s = new AppState();
  s.auth = state.auth;
  s.connection = state.connection;
  s.chats = state.chats;
  s.messages = state.messages;
  s.files = state.files;
  s.accentColors = state.accentColors;
  s.users = state.users;
  s.lastEvent = state.lastEvent;
  s.version = state.version;
  return s;
}

export function cloneStateForAuth(state: AppState): AppState {
  const s = shallowCloneAppState(state);
  s.auth = cloneAuthState(state.auth);
  s.connection = cloneConnectionState(state.connection);
  return s;
}

export function cloneStateForChats(state: AppState): AppState {
  const s = shallowCloneAppState(state);
  s.chats = cloneChatsState(state.chats);
  return s;
}

export function cloneStateForMessages(state: AppState): AppState {
  const s = shallowCloneAppState(state);
  s.messages = cloneMessagesState(state.messages);
  return s;
}

export function cloneStateForFiles(state: AppState): AppState {
  const s = shallowCloneAppState(state);
  s.files = cloneFilesState(state.files);
  return s;
}

export function cloneStateForUsers(state: AppState): AppState {
  const s = shallowCloneAppState(state);
  s.users = cloneUsersState(state.users);
  return s;
}

export function cloneStateForAccentColors(state: AppState): AppState {
  const s = shallowCloneAppState(state);
  s.accentColors = cloneAccentColorsState(state.accentColors);
  return s;
}
