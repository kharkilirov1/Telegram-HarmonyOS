// Chat folder selector — turns the mirrored TDLib folder list into the tab strip the chat list shows.
//
// iOS keeps the main chat list in the user-ordered strip (updateChatFolders.main_chat_list_position),
// so the "All chats" tab is not always first. A position outside the folder count clamps to the end.

import { AppState, ChatFolderInfo } from '../model/AppState';

export const CHAT_FOLDER_ALL_ID: number = 0;

export class ChatFolderTab {
  id: number = CHAT_FOLDER_ALL_ID;
  title: string = '';
  // true for the synthetic "All chats" tab that TDLib does not list as a folder.
  isAllChats: boolean = false;
}

export function selectChatFolderTabs(state: AppState): ChatFolderTab[] {
  const filters = state.chatFilters;
  const tabs: ChatFolderTab[] = [];
  const allTab = new ChatFolderTab();
  allTab.id = CHAT_FOLDER_ALL_ID;
  allTab.isAllChats = true;

  const rawPosition = filters.mainChatListPosition;
  const clamped = rawPosition < 0 ? 0 : (rawPosition > filters.folders.length ? filters.folders.length : rawPosition);
  for (let index: number = 0; index < filters.folders.length; index += 1) {
    if (index === clamped) {
      tabs.push(allTab);
    }
    const folder: ChatFolderInfo = filters.folders[index];
    const tab = new ChatFolderTab();
    tab.id = folder.id;
    tab.title = folder.title;
    tabs.push(tab);
  }
  if (clamped >= filters.folders.length) {
    tabs.push(allTab);
  }
  return tabs;
}
