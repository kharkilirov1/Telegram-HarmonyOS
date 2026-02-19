// State cloning utilities - immutable state updates
// Shared across all reducers to eliminate code duplication
// Includes selective cloning for performance optimization

import {
  AppState,
  AuthState,
  ConnectionState,
  DialogsState,
  MessagesState,
  UsersState,
  Chat,
  ChatLastMessage,
  Message,
  PendingMessage,
  User
} from '../model/AppState';

/**
 * Clone AuthState immutably
 */
export function cloneAuthState(auth: AuthState): AuthState {
  const newAuth = new AuthState();
  newAuth.status = auth.status;
  newAuth.userId = auth.userId;
  newAuth.phoneNumber = auth.phoneNumber;
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
 * Clone DialogsState immutably
 */
export function cloneDialogsState(dialogs: DialogsState): DialogsState {
  const newDialogs = new DialogsState();
  // Clone maps and arrays
  newDialogs.chats = new Map<number, Chat>();
  dialogs.chats.forEach((chat: Chat, chatId: number) => {
    newDialogs.chats.set(chatId, chat);
  });
  newDialogs.orderedChatIds = dialogs.orderedChatIds.slice();
  newDialogs.isLoading = dialogs.isLoading;
  newDialogs.hasMore = dialogs.hasMore;
  return newDialogs;
}

/**
 * Clone MessagesState immutably
 * Uses string keys for MessageId (int64 stored as string)
 */
export function cloneMessagesState(messages: MessagesState): MessagesState {
  const newMessages = new MessagesState();
  // Clone nested maps - use string keys for MessageId
  newMessages.messages = new Map<number, Map<string, Message>>();
  messages.messages.forEach((messageMap: Map<string, Message>, chatId: number) => {
    newMessages.messages.set(chatId, new Map<string, Message>(messageMap));
  });
  newMessages.pendingMessages = new Map<string, PendingMessage>(messages.pendingMessages);
  return newMessages;
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
  newChat.title = chat.title;
  newChat.unreadCount = chat.unreadCount;
  newChat.isPinned = chat.isPinned;
  newChat.photoSmall = chat.photoSmall;
  newChat.order = chat.order;
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
  newUser.phoneNumber = user.phoneNumber;
  newUser.photoSmall = user.photoSmall;
  newUser.photoBig = user.photoBig;
  newUser.status = user.status;
  newUser.isContact = user.isContact;
  newUser.isVerified = user.isVerified;
  newUser.isPremium = user.isPremium;
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
  newState.dialogs = cloneDialogsState(state.dialogs);
  newState.messages = cloneMessagesState(state.messages);
  newState.users = cloneUsersState(state.users);
  newState.lastEvent = state.lastEvent;
  newState.version = state.version;
  return newState;
}

// --- Selective clones — deep-copy only the slice being modified ---
// Other slices are shared by reference (safe because reducers are pure)

/**
 * Clone state for authReducer - only auth slice is modified
 */
export function cloneStateForAuth(state: AppState): AppState {
  const newState = new AppState();
  newState.auth = cloneAuthState(state.auth);
  newState.connection = cloneConnectionState(state.connection);
  newState.dialogs = state.dialogs;       // shared — not modified by authReducer
  newState.messages = state.messages;      // shared
  newState.users = state.users;            // shared
  newState.lastEvent = state.lastEvent;
  newState.version = state.version;
  return newState;
}

/**
 * Clone state for dialogsReducer - only dialogs slice is modified
 */
export function cloneStateForDialogs(state: AppState): AppState {
  const newState = new AppState();
  newState.auth = state.auth;              // shared
  newState.connection = state.connection;  // shared
  newState.dialogs = cloneDialogsState(state.dialogs);
  newState.messages = state.messages;      // shared
  newState.users = state.users;            // shared
  newState.lastEvent = state.lastEvent;
  newState.version = state.version;
  return newState;
}

/**
 * Clone state for messagesReducer - only messages slice is modified
 */
export function cloneStateForMessages(state: AppState): AppState {
  const newState = new AppState();
  newState.auth = state.auth;              // shared
  newState.connection = state.connection;  // shared
  newState.dialogs = state.dialogs;        // shared
  newState.messages = cloneMessagesState(state.messages);
  newState.users = state.users;            // shared
  newState.lastEvent = state.lastEvent;
  newState.version = state.version;
  return newState;
}

/**
 * Clone state for usersReducer - only users slice is modified
 */
export function cloneStateForUsers(state: AppState): AppState {
  const newState = new AppState();
  newState.auth = state.auth;              // shared
  newState.connection = state.connection;  // shared
  newState.dialogs = state.dialogs;        // shared
  newState.messages = state.messages;      // shared
  newState.users = cloneUsersState(state.users);
  newState.lastEvent = state.lastEvent;
  newState.version = state.version;
  return newState;
}
