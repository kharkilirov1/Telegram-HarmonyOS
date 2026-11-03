// Chat folders reducer — replaces the mirrored folder list on updateChatFolders.
//
// TDLib always sends the complete vector, so no incremental diff is needed: one clone of the
// ChatFoldersState, then the folders/position/tags are replaced.

import { AppState, ChatFolderInfo, ChatFoldersState, ReducerAction } from '../model/AppState';
import { ChatFoldersUpdatedEvent, ChatListUnreadCountUpdatedEvent } from '../model/AppEvent';
import { cloneStateForChats } from '../utils/stateClone';

export function cloneChatFolder(folder: ChatFolderInfo): ChatFolderInfo {
  const copy = new ChatFolderInfo();
  copy.id = folder.id;
  copy.title = folder.title;
  copy.iconName = folder.iconName;
  copy.colorId = folder.colorId;
  copy.isShareable = folder.isShareable;
  return copy;
}

export function applyChatFoldersUpdated(state: AppState, event: ChatFoldersUpdatedEvent): AppState {
  const filters = new ChatFoldersState();
  for (const folder of event.folders) {
    filters.folders.push(cloneChatFolder(folder));
  }
  filters.mainChatListPosition = event.mainChatListPosition;
  filters.areTagsEnabled = event.areTagsEnabled;
  const next = cloneStateForChats(state);
  next.chatFilters = filters;
  return next;
}

export function applyUnreadChatCount(state: AppState, event: ChatListUnreadCountUpdatedEvent): AppState {
  const next = cloneStateForChats(state);
  const filters = new ChatFoldersState();
  for (const folder of next.chatFilters.folders) {
    filters.folders.push(cloneChatFolder(folder));
  }
  filters.mainChatListPosition = next.chatFilters.mainChatListPosition;
  filters.areTagsEnabled = next.chatFilters.areTagsEnabled;
  next.chatFilters.unreadByList.forEach((count: number, key: string): void => {
    filters.unreadByList.set(key, count);
  });
  filters.unreadByList.set(event.listKey, event.unreadCount);
  next.chatFilters = filters;
  return next;
}

export function chatFoldersReducer(state: AppState, action: ReducerAction): AppState {
  if (state === undefined || action === undefined) {
    return state;
  }
  if (action.type === 'chatFoldersUpdated') {
    return applyChatFoldersUpdated(state, action as ChatFoldersUpdatedEvent);
  }
  if (action.type === 'chatListUnreadCountUpdated') {
    return applyUnreadChatCount(state, action as ChatListUnreadCountUpdatedEvent);
  }
  return state;
}
