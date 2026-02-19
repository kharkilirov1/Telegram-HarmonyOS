// Dialogs reducer - handles chat/dialog events
// Pure function, no side effects
// Uses real data from DTOs instead of hardcoded values
// Maintains orderedChatIds sorted by TDLib order (descending); order=0 → removed from list

import { AppState, Chat, ChatLastMessage, ReducerAction } from '../model/AppState';
import {
  NewChatEvent,
  ChatUpdatedEvent,
  ChatReadInboxEvent,
  ChatReadOutboxEvent
} from '../model/AppEvent';
import { ChatDto, ChatType as DtoChatType } from '../model/dto/ChatDto';
import { compareInt64 } from '../utils/tdAccessors';
import { cloneStateForDialogs, cloneChat } from '../utils/stateClone';

// Events this reducer handles
function isDialogEvent(type: string): boolean {
  return type === 'newChat' || type === 'chatUpdated' ||
    type === 'chatReadInbox' || type === 'chatReadOutbox';
}

// Map DTO ChatType enum to AppState ChatType string
function mapChatType(dtoType: DtoChatType): 'private' | 'group' | 'supergroup' | 'channel' {
  switch (dtoType) {
    case DtoChatType.PRIVATE: return 'private';
    case DtoChatType.GROUP: return 'group';
    case DtoChatType.SUPERGROUP: return 'supergroup';
    case DtoChatType.CHANNEL: return 'channel';
    default: return 'private';
  }
}

// Create Chat (AppState) from ChatDto
function chatFromDto(dto: ChatDto): Chat {
  const chat = new Chat();
  chat.id = dto.id;
  chat.type = mapChatType(dto.type);
  chat.title = dto.title;
  chat.unreadCount = dto.unreadCount;
  chat.isPinned = dto.isPinned;
  chat.order = dto.order;

  if (dto.photo) {
    chat.photoSmall = dto.photo.small;
  }

  if (dto.lastMessage) {
    const lm = new ChatLastMessage();
    lm.id = dto.lastMessage.id;
    lm.text = dto.lastMessage.text;
    lm.timestamp = dto.lastMessage.timestamp;
    chat.lastMessage = lm;
  }

  return chat;
}

// Rebuild orderedChatIds from chats map, sorted by order descending.
// Chats with order='0' are excluded (TDLib convention: not in chatListMain).
function rebuildOrderedChatIds(chats: Map<number, Chat>): number[] {
  const entries: Chat[] = [];
  chats.forEach((chat: Chat) => {
    if (chat.order !== '0') {
      entries.push(chat);
    }
  });

  // Sort descending by order (higher order = more recent / higher priority)
  entries.sort((a: Chat, b: Chat): number => {
    const cmp = compareInt64(b.order, a.order); // b first = descending
    if (cmp !== 0) return cmp;
    // Stable tiebreak by chatId descending
    return b.id > a.id ? 1 : (b.id < a.id ? -1 : 0);
  });

  const result: number[] = [];
  for (const chat of entries) {
    result.push(chat.id);
  }
  return result;
}

export function dialogsReducer(state: AppState, action: ReducerAction): AppState {
  if (!isDialogEvent(action.type)) {
    return state;
  }

  const newState = cloneStateForDialogs(state);
  let orderChanged = false;

  switch (action.type) {
    case 'newChat': {
      const event = action as NewChatEvent;
      const existing = newState.dialogs.chats.get(event.chatId);

      // Create chat from REAL DTO data (includes order from positions)
      const chat = chatFromDto(event.chatData);

      if (existing) {
        // Placeholder may already have fields from earlier updateChatTitle/Photo/Position.
        // DTO fields win when they carry real data; keep placeholder fields that DTO lacks.
        if (!chat.title && existing.title) {
          chat.title = existing.title;
        }
        if (!chat.photoSmall && existing.photoSmall) {
          chat.photoSmall = existing.photoSmall;
        }
        if (!chat.lastMessage && existing.lastMessage) {
          chat.lastMessage = existing.lastMessage;
        }
        if (chat.order === '0' && existing.order !== '0') {
          chat.order = existing.order;
        }
        if (!chat.isPinned && existing.isPinned) {
          chat.isPinned = existing.isPinned;
        }
      }

      newState.dialogs.chats.set(event.chatId, chat);
      orderChanged = true;
      break;
    }

    case 'chatUpdated': {
      const event = action as ChatUpdatedEvent;
      const existingChat = newState.dialogs.chats.get(event.chatId);

      if (!existingChat) {
        // Chat not in store yet — can happen if updateChatTitle arrives before updateNewChat.
        // Create a minimal placeholder; updateNewChat will fill it properly later.
        const placeholder = new Chat();
        placeholder.id = event.chatId;
        if (event.updates.title !== undefined) {
          placeholder.title = event.updates.title;
        }
        if (event.updates.order !== undefined) {
          placeholder.order = event.updates.order;
        }
        if (event.updates.isPinned !== undefined) {
          placeholder.isPinned = event.updates.isPinned;
        }
        newState.dialogs.chats.set(event.chatId, placeholder);
        orderChanged = true;
        break;
      }

      // Apply partial updates from ChatUpdateDto
      const updatedChat = cloneChat(existingChat);

      if (event.updates.title !== undefined) {
        updatedChat.title = event.updates.title;
      }
      if (event.updates.unreadCount !== undefined) {
        updatedChat.unreadCount = event.updates.unreadCount;
      }
      if (event.updates.isPinned !== undefined) {
        updatedChat.isPinned = event.updates.isPinned;
      }
      if (event.updates.photo !== undefined) {
        updatedChat.photoSmall = event.updates.photo.small;
      }
      if (event.updates.lastMessage !== undefined) {
        const lm = new ChatLastMessage();
        lm.id = event.updates.lastMessage.id;
        lm.text = event.updates.lastMessage.text;
        lm.timestamp = event.updates.lastMessage.timestamp;
        updatedChat.lastMessage = lm;
      }
      if (event.updates.order !== undefined) {
        orderChanged = existingChat.order !== event.updates.order;
        updatedChat.order = event.updates.order;
      }

      newState.dialogs.chats.set(event.chatId, updatedChat);
      break;
    }

    case 'chatReadInbox': {
      const event = action as ChatReadInboxEvent;
      const existingChat = newState.dialogs.chats.get(event.chatId);

      if (existingChat) {
        const updatedChat = cloneChat(existingChat);
        updatedChat.unreadCount = event.unreadCount;
        newState.dialogs.chats.set(event.chatId, updatedChat);
      }
      break;
    }

    case 'chatReadOutbox': {
      const event = action as ChatReadOutboxEvent;
      // Mark outgoing messages as read up to lastReadOutboxMessageId
      // For now, store the info; message-level isRead is updated in messagesReducer
      // This event is tracked for future use (e.g. read receipts in UI)
      break;
    }
  }

  // Rebuild sorted order only when order actually changed
  if (orderChanged) {
    newState.dialogs.orderedChatIds = rebuildOrderedChatIds(newState.dialogs.chats);
  }

  newState.version = state.version + 1;
  newState.lastEvent = action;
  return newState;
}
