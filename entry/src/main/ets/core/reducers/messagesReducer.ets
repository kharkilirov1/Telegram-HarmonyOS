// Messages reducer - handles message events
// Pure function, no side effects
// Uses real data from DTOs instead of hardcoded values

import { AppState, Message, MessageContent, MessageSendStatus, ReducerAction } from '../model/AppState';
import {
  NewMessageEvent,
  MessageUpdatedEvent,
  MessageContentUpdatedEvent,
  MessageSendSucceededEvent,
  MessageSendFailedEvent,
  MessagesDeletedEvent
} from '../model/AppEvent';
import { MessageDto, MessageContentDto } from '../model/dto/MessageDto';
import { cloneStateForMessages } from '../utils/stateClone';

// Events this reducer handles
function isMessageEvent(type: string): boolean {
  return type === 'newMessage' || type === 'messageUpdated' ||
    type === 'messageContentUpdated' || type === 'messageSendSucceeded' ||
    type === 'messageSendFailed' || type === 'messagesDeleted';
}

// Convert MessageContentDto → MessageContent (AppState)
function contentFromDto(dto: MessageContentDto): MessageContent {
  const content = new MessageContent();
  // Map enum to string type
  content.type = dto.type as 'text' | 'photo' | 'video' | 'document' | 'audio' |
    'voice' | 'sticker' | 'location' | 'contact' | 'poll' | 'animation' | 'videoNote' | 'unknown';
  content.text = dto.text;
  return content;
}

// Create Message (AppState) from MessageDto
function messageFromDto(dto: MessageDto): Message {
  const message = new Message();
  message.id = dto.id;
  message.chatId = dto.chatId;
  message.senderId = dto.senderId;
  message.senderChatId = dto.senderChatId;
  message.content = contentFromDto(dto.content);
  message.timestamp = dto.timestamp;
  message.isOutgoing = dto.isOutgoing;
  message.isRead = dto.isRead;
  message.isPending = dto.isPending;
  message.editDate = dto.editDate;
  message.replyToMessageId = dto.replyToMessageId;
  message.sendStatus = dto.isPending ? 'pending' : 'none';
  return message;
}

// Clone a single message immutably
function cloneMessage(msg: Message): Message {
  const clone = new Message();
  clone.id = msg.id;
  clone.chatId = msg.chatId;
  clone.senderId = msg.senderId;
  clone.senderChatId = msg.senderChatId;
  clone.content = msg.content;
  clone.timestamp = msg.timestamp;
  clone.isOutgoing = msg.isOutgoing;
  clone.isRead = msg.isRead;
  clone.isPending = msg.isPending;
  clone.editDate = msg.editDate;
  clone.replyToMessageId = msg.replyToMessageId;
  clone.sendStatus = msg.sendStatus;
  clone.sendErrorCode = msg.sendErrorCode;
  clone.sendErrorMessage = msg.sendErrorMessage;
  return clone;
}

// Get or create chat messages map
function getChatMessages(state: AppState, chatId: number): Map<string, Message> {
  const existing = state.messages.messages.get(chatId);
  if (existing) {
    return new Map<string, Message>(existing);
  }
  return new Map<string, Message>();
}

export function messagesReducer(state: AppState, action: ReducerAction): AppState {
  if (!isMessageEvent(action.type)) {
    return state;
  }

  const newState = cloneStateForMessages(state);

  switch (action.type) {
    case 'newMessage': {
      const event = action as NewMessageEvent;

      // Create message from REAL DTO data
      const message = messageFromDto(event.messageData);

      const chatMessages = getChatMessages(newState, event.chatId);
      chatMessages.set(event.messageId, message);
      newState.messages.messages.set(event.chatId, chatMessages);
      break;
    }

    case 'messageUpdated': {
      const event = action as MessageUpdatedEvent;
      const chatMessages = newState.messages.messages.get(event.chatId);
      if (!chatMessages) break;

      const existing = chatMessages.get(event.messageId);
      if (!existing) break;

      // Clone and apply partial updates
      const updated = cloneMessage(existing);

      if (event.updates.content !== undefined) {
        updated.content = contentFromDto(event.updates.content);
      }
      if (event.updates.isRead !== undefined) {
        updated.isRead = event.updates.isRead;
      }
      if (event.updates.editDate !== undefined) {
        updated.editDate = event.updates.editDate;
      }

      const newChatMessages = new Map<string, Message>(chatMessages);
      newChatMessages.set(event.messageId, updated);
      newState.messages.messages.set(event.chatId, newChatMessages);
      break;
    }

    case 'messageContentUpdated': {
      const event = action as MessageContentUpdatedEvent;
      const chatMessages = newState.messages.messages.get(event.chatId);
      if (!chatMessages) break;

      const existing = chatMessages.get(event.messageId);
      if (!existing) break;

      // Clone message with new content
      const updated = cloneMessage(existing);
      updated.content = contentFromDto(event.newContent);

      const newChatMessages = new Map<string, Message>(chatMessages);
      newChatMessages.set(event.messageId, updated);
      newState.messages.messages.set(event.chatId, newChatMessages);
      break;
    }

    case 'messageSendSucceeded': {
      const event = action as MessageSendSucceededEvent;

      // Remove old (pending) message, insert confirmed message with server ID
      const chatMessages = getChatMessages(newState, event.chatId);
      chatMessages.delete(event.oldMessageId);

      const confirmedMessage = messageFromDto(event.message);
      confirmedMessage.isPending = false;
      confirmedMessage.sendStatus = 'sent';
      chatMessages.set(confirmedMessage.id, confirmedMessage);

      newState.messages.messages.set(event.chatId, chatMessages);
      break;
    }

    case 'messageSendFailed': {
      const event = action as MessageSendFailedEvent;

      // Mark the old pending message as failed (keep it so user can retry)
      const chatMessages = newState.messages.messages.get(event.chatId);
      if (!chatMessages) break;

      const pending = chatMessages.get(event.oldMessageId);
      if (!pending) break;

      const failedMessage = cloneMessage(pending);
      failedMessage.isPending = false;
      failedMessage.sendStatus = 'failed';
      failedMessage.sendErrorCode = event.errorCode;
      failedMessage.sendErrorMessage = event.errorMessage;

      const newChatMessages = new Map<string, Message>(chatMessages);
      newChatMessages.set(event.oldMessageId, failedMessage);
      newState.messages.messages.set(event.chatId, newChatMessages);
      break;
    }

    case 'messagesDeleted': {
      const event = action as MessagesDeletedEvent;

      // Only process permanent deletes (non-cache)
      if (!event.isPermanent) break;

      const chatMessages = newState.messages.messages.get(event.chatId);
      if (!chatMessages) break;

      const newChatMessages = new Map<string, Message>(chatMessages);
      let changed = false;
      for (const messageId of event.messageIds) {
        if (newChatMessages.has(messageId)) {
          newChatMessages.delete(messageId);
          changed = true;
        }
      }

      if (changed) {
        if (newChatMessages.size > 0) {
          newState.messages.messages.set(event.chatId, newChatMessages);
        } else {
          // No messages left for this chat — remove the empty map
          newState.messages.messages.delete(event.chatId);
        }
      }
      break;
    }
  }

  newState.version = state.version + 1;
  newState.lastEvent = action;
  return newState;
}
