// Files reducer — handles file download events
// When a file download completes, scans users and chats for matching fileId
// and updates the local photo path.

import { AppState, ReducerAction } from '../model/AppState';
import { FileDownloadedEvent } from '../model/AppEvent';
import { cloneAppState, cloneUser, cloneChat } from '../utils/stateClone';

export function filesReducer(state: AppState, action: ReducerAction): AppState {
  if (action.type !== 'fileDownloaded') {
    return state;
  }

  const event = action as FileDownloadedEvent;
  if (!event.fileId || !event.localPath || !event.isComplete) {
    return state;
  }

  const fileId = event.fileId;
  const localPath = event.localPath;

  // Pre-scan: check if any user or chat actually needs this file
  let needsUpdate = false;

  state.users.users.forEach((user) => {
    if (user.photoSmallFileId === fileId && user.photoSmall !== localPath) {
      needsUpdate = true;
    }
  });

  if (!needsUpdate) {
    state.chats.chats.forEach((chat) => {
      if (chat.photoSmallFileId === fileId && chat.photoSmall !== localPath) {
        needsUpdate = true;
      }
    });
  }

  if (!needsUpdate) {
    return state;
  }

  // Clone state and apply updates
  const newState = cloneAppState(state);

  newState.users.users.forEach((user, userId) => {
    if (user.photoSmallFileId === fileId && user.photoSmall !== localPath) {
      const updatedUser = cloneUser(user);
      updatedUser.photoSmall = localPath;
      newState.users.users.set(userId, updatedUser);
    }
  });

  newState.chats.chats.forEach((chat, chatId) => {
    if (chat.photoSmallFileId === fileId && chat.photoSmall !== localPath) {
      const updatedChat = cloneChat(chat);
      updatedChat.photoSmall = localPath;
      newState.chats.chats.set(chatId, updatedChat);
    }
  });

  newState.version = state.version + 1;
  newState.lastEvent = action;
  return newState;
}
