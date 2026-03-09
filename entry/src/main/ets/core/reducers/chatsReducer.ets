// Chats reducer - handles chat events
// Pure function, no side effects
// Uses real data from DTOs instead of hardcoded values
// Maintains orderedChatIds sorted by TDLib order (descending); order=0 → removed from list

import { AppState, Chat, ChatLastMessage, ChatTypingInfo, ReducerAction } from '../model/AppState';
import {
  NewChatEvent,
  ChatUpdatedEvent,
  ChatReadInboxEvent,
  ChatReadOutboxEvent,
  ChatsLoadStateChangedEvent,
  ChatActionEvent,
  ChatFullInfoEvent
} from '../model/AppEvent';
import { ChatDto, ChatType as DtoChatType } from '../model/dto/ChatDto';
import { compareInt64 } from '../utils/tdAccessors';
import { cloneStateForChats, cloneChat } from '../utils/stateClone';

// Events this reducer handles
function isChatEvent(type: string): boolean {
  return type === 'newChat' || type === 'chatUpdated' ||
    type === 'chatReadInbox' || type === 'chatReadOutbox' ||
    type === 'chatsLoadStateChanged' || type === 'chatAction' || type === 'chatFullInfo';
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
  chat.peerUserId = dto.peerUserId;
  chat.title = dto.title;
  chat.unreadCount = dto.unreadCount;
  chat.muteForSeconds = dto.muteFor;
  chat.lastReadOutboxMessageId = dto.lastReadOutboxMessageId;
  chat.lastReadInboxMessageId = dto.lastReadInboxMessageId;
  chat.draftText = dto.draftText;
  chat.draftReplyToMessageId = dto.draftReplyToMessageId;
  chat.isPinned = dto.isPinned;
  chat.order = dto.order;
  chat.supergroupId = dto.supergroupId;

  if (dto.photo) {
    chat.photoSmall = dto.photo.small;
    chat.photoSmallFileId = dto.photo.smallFileId;
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
// Chats with real order sort first; chats with order='0' (position unknown) go to the end.
function rebuildOrderedChatIds(chats: Map<number, Chat>): number[] {
  const withOrder: Chat[] = [];
  const noOrder: Chat[] = [];
  chats.forEach((chat: Chat) => {
    if (chat.order !== '0') {
      withOrder.push(chat);
    } else {
      noOrder.push(chat);
    }
  });

  // Sort chats with order descending (higher order = more recent)
  withOrder.sort((a: Chat, b: Chat): number => {
    const cmp = compareInt64(b.order, a.order);
    if (cmp !== 0) return cmp;
    return b.id > a.id ? 1 : (b.id < a.id ? -1 : 0);
  });

  // Sort chats without order by chatId descending (fallback)
  noOrder.sort((a: Chat, b: Chat): number => {
    return b.id > a.id ? 1 : (b.id < a.id ? -1 : 0);
  });

  const result: number[] = [];
  for (const chat of withOrder) {
    result.push(chat.id);
  }
  for (const chat of noOrder) {
    result.push(chat.id);
  }
  return result;
}

export function chatsReducer(state: AppState, action: ReducerAction): AppState {
  if (!isChatEvent(action.type)) {
    return state;
  }

  const newState = cloneStateForChats(state);
  let orderChanged = false;

  switch (action.type) {
    case 'newChat': {
      const event = action as NewChatEvent;
      const existing = newState.chats.chats.get(event.chatId);

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
        if (!chat.peerUserId && existing.peerUserId) {
          chat.peerUserId = existing.peerUserId;
        }
        if (!chat.muteForSeconds && existing.muteForSeconds) {
          chat.muteForSeconds = existing.muteForSeconds;
        }
        if (chat.lastReadOutboxMessageId === '0' && existing.lastReadOutboxMessageId !== '0') {
          chat.lastReadOutboxMessageId = existing.lastReadOutboxMessageId;
        }
        if (chat.lastReadInboxMessageId === '0' && existing.lastReadInboxMessageId !== '0') {
          chat.lastReadInboxMessageId = existing.lastReadInboxMessageId;
        }
        if (chat.draftText.length === 0 && existing.draftText.length > 0) {
          chat.draftText = existing.draftText;
        }
        if (chat.draftReplyToMessageId === '0' && existing.draftReplyToMessageId !== '0') {
          chat.draftReplyToMessageId = existing.draftReplyToMessageId;
        }
        if (chat.order === '0' && existing.order !== '0') {
          chat.order = existing.order;
        }
        if (!chat.isPinned && existing.isPinned) {
          chat.isPinned = existing.isPinned;
        }
      }

      newState.chats.chats.set(event.chatId, chat);
      orderChanged = true;
      break;
    }

    case 'chatUpdated': {
      const event = action as ChatUpdatedEvent;
      const existingChat = newState.chats.chats.get(event.chatId);

      if (!existingChat) {
        // Chat not in store yet — can happen if updateChatTitle arrives before updateNewChat.
        // Create a minimal placeholder; updateNewChat will fill it properly later.
        const placeholder = new Chat();
        placeholder.id = event.chatId;
        if (event.updates.title !== undefined) {
          const nextTitle = event.updates.title.trim();
          if (nextTitle.length > 0) {
            placeholder.title = event.updates.title;
          }
        }
        if (event.updates.order !== undefined) {
          placeholder.order = event.updates.order;
        }
        if (event.updates.isPinned !== undefined) {
          placeholder.isPinned = event.updates.isPinned;
        }
        if (event.updates.draftText !== undefined) {
          placeholder.draftText = event.updates.draftText;
        }
        if (event.updates.draftReplyToMessageId !== undefined) {
          placeholder.draftReplyToMessageId = event.updates.draftReplyToMessageId;
        }
        newState.chats.chats.set(event.chatId, placeholder);
        orderChanged = true;
        break;
      }

      // Apply partial updates from ChatUpdateDto
      const updatedChat = cloneChat(existingChat);

      if (event.updates.title !== undefined) {
        const nextTitle = event.updates.title.trim();
        if (nextTitle.length > 0 || updatedChat.title.trim().length === 0) {
          updatedChat.title = event.updates.title;
        }
      }
      if (event.updates.peerUserId !== undefined) {
        updatedChat.peerUserId = event.updates.peerUserId;
      }
      if (event.updates.unreadCount !== undefined) {
        updatedChat.unreadCount = event.updates.unreadCount;
      }
      if (event.updates.muteFor !== undefined) {
        updatedChat.muteForSeconds = event.updates.muteFor;
      }
      if (event.updates.lastReadOutboxMessageId !== undefined) {
        updatedChat.lastReadOutboxMessageId = event.updates.lastReadOutboxMessageId;
      }
      if (event.updates.lastReadInboxMessageId !== undefined) {
        updatedChat.lastReadInboxMessageId = event.updates.lastReadInboxMessageId;
      }
      if (event.updates.draftText !== undefined) {
        updatedChat.draftText = event.updates.draftText;
      }
      if (event.updates.draftReplyToMessageId !== undefined) {
        updatedChat.draftReplyToMessageId = event.updates.draftReplyToMessageId;
      }
      if (event.updates.isPinned !== undefined) {
        updatedChat.isPinned = event.updates.isPinned;
      }
      if (event.updates.photo !== undefined) {
        updatedChat.photoSmall = event.updates.photo.small;
        updatedChat.photoSmallFileId = event.updates.photo.smallFileId;
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

      newState.chats.chats.set(event.chatId, updatedChat);
      break;
    }

    case 'chatReadInbox': {
      const event = action as ChatReadInboxEvent;
      const existingChat = newState.chats.chats.get(event.chatId);

      if (existingChat) {
        const updatedChat = cloneChat(existingChat);
        updatedChat.unreadCount = event.unreadCount;
        updatedChat.lastReadInboxMessageId = event.lastReadInboxMessageId;
        newState.chats.chats.set(event.chatId, updatedChat);
      }
      break;
    }

    case 'chatReadOutbox': {
      const event = action as ChatReadOutboxEvent;
      const existingChat = newState.chats.chats.get(event.chatId);
      if (!existingChat) {
        break;
      }
      const updatedChat = cloneChat(existingChat);
      updatedChat.lastReadOutboxMessageId = event.lastReadOutboxMessageId;
      newState.chats.chats.set(event.chatId, updatedChat);
      break;
    }

    case 'chatsLoadStateChanged': {
      const event = action as ChatsLoadStateChangedEvent;
      newState.chats.isLoading = event.isLoading;
      newState.chats.hasMore = event.hasMore;
      if (event.phase === 'bootstrap' || event.phase === 'pagination' || event.phase === 'idle') {
        newState.chats.loadPhase = event.phase;
      } else {
        newState.chats.loadPhase = 'idle';
      }
      break;
    }

    case 'chatAction': {
      const event = action as ChatActionEvent;
      // Clone the typing map
      newState.chats.typingActions = new Map<number, ChatTypingInfo>(state.chats.typingActions);
      if (event.actionType === 'cancel') {
        newState.chats.typingActions.delete(event.chatId);
      } else {
        const info = new ChatTypingInfo();
        info.senderUserId = event.senderUserId;
        info.actionType = event.actionType;
        info.timestamp = event.timestamp;
        newState.chats.typingActions.set(event.chatId, info);
      }
      break;
    }

    case 'chatFullInfo': {
      const event = action as ChatFullInfoEvent;
      const existingChat = newState.chats.chats.get(event.chatId);
      if (!existingChat) break;
      const updatedChat = cloneChat(existingChat);
      updatedChat.description = event.description;
      updatedChat.memberCount = event.memberCount;
      newState.chats.chats.set(event.chatId, updatedChat);
      break;
    }
  }

  // Rebuild sorted order only when order actually changed
  if (orderChanged) {
    newState.chats.orderedChatIds = rebuildOrderedChatIds(newState.chats.chats);
  }

  newState.version = state.version + 1;
  newState.lastEvent = action;
  return newState;
}
