// Dialog selectors - pure functions for selecting chat/dialog data from state
// Used by UI components to get derived chat data

import { AppState } from '../../core/model/AppState';
import { Chat, ChatId } from '../../core/model/AppState';

// Basic selectors
export const selectDialogsState = (state: AppState) => state.dialogs;

export const selectChatsMap = (state: AppState) => state.dialogs.chats;

export const selectOrderedChatIds = (state: AppState) => state.dialogs.orderedChatIds;

export const selectIsDialogsLoading = (state: AppState) => state.dialogs.isLoading;

export const selectHasMoreDialogs = (state: AppState) => state.dialogs.hasMore;

// Chat by ID selector
export const selectChatById = (chatId: ChatId) => (state: AppState): Chat | undefined => {
  return state.dialogs.chats.get(chatId);
};

// Ordered chats list (for UI rendering)
export const selectOrderedChats = (state: AppState): Chat[] => {
  const { chats, orderedChatIds } = state.dialogs;
  const result: Chat[] = [];
  
  for (const chatId of orderedChatIds) {
    const chat = chats.get(chatId);
    if (chat) {
      result.push(chat);
    }
  }
  
  return result;
};

// Pinned chats selector
export const selectPinnedChats = (state: AppState): Chat[] => {
  const { chats, orderedChatIds } = state.dialogs;
  const result: Chat[] = [];
  
  for (const chatId of orderedChatIds) {
    const chat = chats.get(chatId);
    if (chat && chat.isPinned) {
      result.push(chat);
    }
  }
  
  return result;
};

// Unpinned chats selector
export const selectUnpinnedChats = (state: AppState): Chat[] => {
  const { chats, orderedChatIds } = state.dialogs;
  const result: Chat[] = [];
  
  for (const chatId of orderedChatIds) {
    const chat = chats.get(chatId);
    if (chat && !chat.isPinned) {
      result.push(chat);
    }
  }
  
  return result;
};

// Unread counts
export const selectTotalUnreadCount = (state: AppState): number => {
  let total = 0;
  
  for (const chat of state.dialogs.chats.values()) {
    total += chat.unreadCount;
  }
  
  return total;
};

export const selectUnreadCountByChatId = (chatId: ChatId) => (state: AppState): number => {
  const chat = state.dialogs.chats.get(chatId);
  return chat ? chat.unreadCount : 0;
};

// Search selectors
export const selectChatsBySearchQuery = (query: string) => (state: AppState): Chat[] => {
  const normalizedQuery = query.toLowerCase().trim();
  if (!normalizedQuery) {
    return selectOrderedChats(state);
  }
  
  const result: Chat[] = [];
  
  for (const chat of state.dialogs.chats.values()) {
    if (chat.title.toLowerCase().includes(normalizedQuery)) {
      result.push(chat);
    }
  }
  
  return result;
};

// Filter by chat type
export const selectChatsByType = (type: Chat['type']) => (state: AppState): Chat[] => {
  const result: Chat[] = [];
  
  for (const chat of state.dialogs.chats.values()) {
    if (chat.type === type) {
      result.push(chat);
    }
  }
  
  return result;
};

// DTO for dialog list UI
export class DialogListForUI {
  pinned: Chat[] = [];
  unpinned: Chat[] = [];
  totalUnread: number = 0;
  isLoading: boolean = false;
  hasMore: boolean = true;
  totalCount: number = 0;
}

// Combined selectors for UI
export const selectDialogListForUI = (state: AppState): DialogListForUI => {
  const pinned = selectPinnedChats(state);
  const unpinned = selectUnpinnedChats(state);
  const totalUnread = selectTotalUnreadCount(state);

  const result = new DialogListForUI();
  result.pinned = pinned;
  result.unpinned = unpinned;
  result.totalUnread = totalUnread;
  result.isLoading = state.dialogs.isLoading;
  result.hasMore = state.dialogs.hasMore;
  result.totalCount = pinned.length + unpinned.length;
  return result;
};

// DTO for specific chat UI
export class ChatForUI {
  id: ChatId = 0;
  type: Chat['type'] = 'private';
  title: string = '';
  unreadCount: number = 0;
  isPinned: boolean = false;
  isMuted: boolean = false;
  isVerified: boolean = false;
}

// Selector for specific chat UI
export const selectChatForUI = (chatId: ChatId) => (state: AppState): ChatForUI | null => {
  const chat = state.dialogs.chats.get(chatId);
  if (!chat) {
    return null;
  }

  const result = new ChatForUI();
  result.id = chat.id;
  result.type = chat.type;
  result.title = chat.title;
  result.unreadCount = chat.unreadCount;
  result.isPinned = chat.isPinned;
  result.isMuted = false; // TODO: Add to Chat type
  result.isVerified = false; // TODO: Add to Chat type
  return result;
};

// Memoized selector for dialog list (non-generic for ArkTS)
export function createMemoizedDialogListSelector(): (state: AppState) => DialogListForUI {
  let lastState: AppState | null = null;
  let lastResult: DialogListForUI | null = null;

  return (state: AppState): DialogListForUI => {
    if (lastState === state && lastResult !== null) {
      return lastResult;
    }

    lastState = state;
    lastResult = selectDialogListForUI(state);
    return lastResult;
  };
}