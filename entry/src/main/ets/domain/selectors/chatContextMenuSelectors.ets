// Chat list context menu model — which actions a long-press on a chat row offers.
//
// Grounded in Telegram iOS ChatContextMenus.swift (order): mark read/unread → archive/unarchive →
// pin/unpin → mute/unmute → delete (destructive). The menu is a pure function of the chat so the
// page only renders and dispatches; every action delegates to an existing use case.

import { AppState, Chat, ChatFolderInfo, isSavedMessagesChat } from '../../core/model/AppState';

export enum ChatContextAction {
  MarkRead = 0,
  MarkUnread = 1,
  Archive = 2,
  Unarchive = 3,
  Pin = 4,
  Unpin = 5,
  Mute = 6,
  Unmute = 7,
  Delete = 8
}

export class ChatContextMenuEntry {
  action: ChatContextAction = ChatContextAction.MarkRead;
  // Draws the label and icon in the destructive color (iOS: only delete).
  destructive: boolean = false;
}

function entry(action: ChatContextAction, destructive: boolean = false): ChatContextMenuEntry {
  const item = new ChatContextMenuEntry();
  item.action = action;
  item.destructive = destructive;
  return item;
}

export function selectChatContextMenuEntries(chat: Chat | undefined, selfUserId: number): ChatContextMenuEntry[] {
  const entries: ChatContextMenuEntry[] = [];
  if (chat === undefined || chat.id === 0) {
    return entries;
  }
  // iOS never offers list management for Saved Messages: the peer is the account itself.
  if (isSavedMessagesChat(chat, selfUserId)) {
    return entries;
  }

  entries.push(chat.unreadCount > 0 || chat.unreadMentionCount > 0 || chat.isMarkedAsUnread
    ? entry(ChatContextAction.MarkRead)
    : entry(ChatContextAction.MarkUnread));

  entries.push(chat.archiveOrder !== '0'
    ? entry(ChatContextAction.Unarchive)
    : entry(ChatContextAction.Archive));

  entries.push(chat.isPinned
    ? entry(ChatContextAction.Unpin)
    : entry(ChatContextAction.Pin));

  entries.push(chat.muteForSeconds > 0
    ? entry(ChatContextAction.Unmute)
    : entry(ChatContextAction.Mute));

  entries.push(entry(ChatContextAction.Delete, true));
  return entries;
}

export function chatContextActionIcon(action: ChatContextAction): string {
  switch (action) {
    case ChatContextAction.MarkRead:
      return 'ic_eye';
    case ChatContextAction.MarkUnread:
      return 'ic_eye_off';
    case ChatContextAction.Archive:
      return 'ic_archive';
    case ChatContextAction.Unarchive:
      return 'ic_folder';
    case ChatContextAction.Pin:
    case ChatContextAction.Unpin:
      return 'ic_pin';
    case ChatContextAction.Mute:
      return 'ic_mute';
    case ChatContextAction.Unmute:
      return 'ic_unmute';
    case ChatContextAction.Delete:
      return 'ic_delete';
    default:
      return 'ic_info';
  }
}

export class ChatFolderTarget {
  folderId: number = 0;
  title: string = '';
}

// Folders this chat is not in yet. TDLib exposes addChatToList for folders but no removal in this
// version, so the menu only ever offers "add" targets.
export function selectAddToFolderTargets(state: AppState, chatId: number): ChatFolderTarget[] {
  const targets: ChatFolderTarget[] = [];
  const chat = state.chats.chats.get(chatId);
  if (chat === undefined || chatId === 0) {
    return targets;
  }
  for (const folder of state.chatFilters.folders) {
    if (folder.id <= 0 || chat.folderOrders.has(folder.id)) {
      continue;
    }
    const target = new ChatFolderTarget();
    target.folderId = folder.id;
    target.title = folder.title.length > 0 ? folder.title : 'Folder';
    targets.push(target);
  }
  return targets;
}
