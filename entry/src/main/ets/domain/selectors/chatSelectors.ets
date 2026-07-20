// Chat selectors - pure functions for selecting chat data from state
// Used by UI components to get derived chat data

import { AppState, Chat, ChatType } from '../../core/model/AppState';
import { ChatId } from '../../core/model/EntityId';

// Basic selectors
export const selectChatsState = (state: AppState) => state.chats;

export const selectChatsMap = (state: AppState) => state.chats.chats;

export const selectOrderedChatIds = (state: AppState) => state.chats.orderedChatIds;

export const selectIsChatsLoading = (state: AppState) => state.chats.isLoading;

export const selectHasMoreChats = (state: AppState) => state.chats.hasMore;

// Chat by ID selector
export const selectChatById = (chatId: ChatId) => (state: AppState): Chat | undefined => {
  return state.chats.chats.get(chatId);
};

// Memoization entries — cache by source Map reference (immutable state pattern)
class ChatListMemoEntry {
  source?: Map<ChatId, Chat>;
  result: Chat[] = [];
}

const orderedChatsMemo: ChatListMemoEntry = new ChatListMemoEntry();
const pinnedChatsMemo: ChatListMemoEntry = new ChatListMemoEntry();
const unpinnedChatsMemo: ChatListMemoEntry = new ChatListMemoEntry();

// Ordered chats list (for UI rendering)
export const selectOrderedChats = (state: AppState): Chat[] => {
  const chats = state.chats.chats;
  const orderedChatIds = state.chats.orderedChatIds;

  if (orderedChatsMemo.source === chats) {
    return orderedChatsMemo.result;
  }

  const result: Chat[] = [];
  for (const chatId of orderedChatIds) {
    const chat = chats.get(chatId);
    if (chat) {
      result.push(chat);
    }
  }

  orderedChatsMemo.source = chats;
  orderedChatsMemo.result = result;
  return result;
};

// Pinned chats selector
export const selectPinnedChats = (state: AppState): Chat[] => {
  const chats = state.chats.chats;

  if (pinnedChatsMemo.source === chats) {
    return pinnedChatsMemo.result;
  }

  const orderedChatIds = state.chats.orderedChatIds;
  const result: Chat[] = [];
  for (const chatId of orderedChatIds) {
    const chat = chats.get(chatId);
    if (chat && chat.isPinned) {
      result.push(chat);
    }
  }

  pinnedChatsMemo.source = chats;
  pinnedChatsMemo.result = result;
  return result;
};

// Unpinned chats selector
export const selectUnpinnedChats = (state: AppState): Chat[] => {
  const chats = state.chats.chats;

  if (unpinnedChatsMemo.source === chats) {
    return unpinnedChatsMemo.result;
  }

  const orderedChatIds = state.chats.orderedChatIds;
  const result: Chat[] = [];
  for (const chatId of orderedChatIds) {
    const chat = chats.get(chatId);
    if (chat && !chat.isPinned) {
      result.push(chat);
    }
  }

  unpinnedChatsMemo.source = chats;
  unpinnedChatsMemo.result = result;
  return result;
};

// Unread counts (memoized by chat-map reference)
let unreadCountMemoSource: Map<ChatId, Chat> | undefined = undefined;
let unreadCountMemoResult: number = -1;

export const selectTotalUnreadCount = (state: AppState): number => {
  if (state.chats.mainUnreadMessageCount >= 0) {
    return state.chats.mainUnreadMessageCount;
  }

  const chats = state.chats.chats;
  if (unreadCountMemoSource === chats && unreadCountMemoResult >= 0) {
    return unreadCountMemoResult;
  }
  let total = 0;
  for (const chatId of state.chats.orderedChatIds) {
    const chat = chats.get(chatId);
    if (chat !== undefined) {
      total += chat.unreadCount;
    }
  }
  unreadCountMemoSource = chats;
  unreadCountMemoResult = total;
  return total;
};

export const selectUnreadCountByChatId = (chatId: ChatId) => (state: AppState): number => {
  const chat = state.chats.chats.get(chatId);
  return chat ? chat.unreadCount : 0;
};

// Search selectors
export const selectChatsBySearchQuery = (query: string) => (state: AppState): Chat[] => {
  const normalizedQuery = query.toLowerCase().trim();
  if (!normalizedQuery) {
    return selectOrderedChats(state);
  }

  const result: Chat[] = [];
  const chats = state.chats.chats;
  const orderedChatIds = state.chats.orderedChatIds;

  for (const chatId of orderedChatIds) {
    const chat = chats.get(chatId);
    if (!chat) {
      continue;
    }
    const title = chat.title.toLowerCase();
    if (title.includes(normalizedQuery)) {
      result.push(chat);
      continue;
    }
    if (chat.lastMessage && chat.lastMessage.text.toLowerCase().includes(normalizedQuery)) {
      result.push(chat);
    }
  }

  return result;
};

// Filter by chat type
export const selectChatsByType = (type: ChatType) => (state: AppState): Chat[] => {
  const result: Chat[] = [];

  for (const chat of state.chats.chats.values()) {
    if (chat.type === type) {
      result.push(chat);
    }
  }

  return result;
};

// DTO for chat list UI
export class ChatListForUI {
  pinned: Chat[] = [];
  unpinned: Chat[] = [];
  totalUnread: number = 0;
  isLoading: boolean = false;
  hasMore: boolean = true;
  totalCount: number = 0;
}

// Combined selectors for UI
export const selectChatListForUI = (state: AppState): ChatListForUI => {
  const pinned = selectPinnedChats(state);
  const unpinned = selectUnpinnedChats(state);
  const totalUnread = selectTotalUnreadCount(state);

  const result = new ChatListForUI();
  result.pinned = pinned;
  result.unpinned = unpinned;
  result.totalUnread = totalUnread;
  result.isLoading = state.chats.isLoading;
  result.hasMore = state.chats.hasMore;
  result.totalCount = pinned.length + unpinned.length;
  return result;
};

// DTO for specific chat UI
export class ChatForUI {
  id: ChatId = 0;
  type: ChatType = 'private';
  title: string = '';
  peerUserId: number = 0;
  unreadCount: number = 0;
  isPinned: boolean = false;
  isMuted: boolean = false;
  isVerified: boolean = false;
}

// Selector for specific chat UI
export const selectChatForUI = (chatId: ChatId) => (state: AppState): ChatForUI | null => {
  const chat = state.chats.chats.get(chatId);
  if (!chat) {
    return null;
  }

  const result = new ChatForUI();
  result.id = chat.id;
  result.type = chat.type;
  result.title = chat.title;
  result.peerUserId = chat.peerUserId;
  result.unreadCount = chat.unreadCount;
  result.isPinned = chat.isPinned;
  result.isMuted = chat.muteForSeconds > 0;
  if (chat.peerUserId > 0) {
    const peerUser = state.users.users.get(chat.peerUserId);
    result.isVerified = peerUser !== undefined && peerUser.isVerified;
  } else {
    result.isVerified = false;
  }
  return result;
};

// Memoized selector for chat list (non-generic for ArkTS)
export function createMemoizedChatListSelector(): (state: AppState) => ChatListForUI {
  let lastState: AppState | null = null;
  let lastResult: ChatListForUI | null = null;

  return (state: AppState): ChatListForUI => {
    if (lastState === state && lastResult !== null) {
      return lastResult;
    }

    lastState = state;
    lastResult = selectChatListForUI(state);
    return lastResult;
  };
}
