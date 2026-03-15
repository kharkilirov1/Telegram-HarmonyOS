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
  content.caption = dto.caption;

  content.photoPath = dto.photoPath;
  content.photoThumbPath = dto.photoThumbPath;
  content.photoFileId = dto.photoFileId;
  content.photoThumbFileId = dto.photoThumbFileId;
  content.photoWidth = dto.photoWidth;
  content.photoHeight = dto.photoHeight;

  content.videoPath = dto.videoPath;
  content.videoThumbPath = dto.videoThumbPath;
  content.videoFileId = dto.videoFileId;
  content.videoThumbFileId = dto.videoThumbFileId;
  content.videoDuration = dto.videoDuration;
  content.videoWidth = dto.videoWidth;
  content.videoHeight = dto.videoHeight;

  content.documentPath = dto.documentPath;
  content.documentFileId = dto.documentFileId;
  content.fileName = dto.fileName;
  content.fileSize = dto.fileSize;
  content.mimeType = dto.mimeType;

  content.audioPath = dto.audioPath;
  content.audioFileId = dto.audioFileId;
  content.audioDuration = dto.audioDuration;
  content.audioTitle = dto.audioTitle;
  content.audioPerformer = dto.audioPerformer;

  content.voicePath = dto.voicePath;
  content.voiceFileId = dto.voiceFileId;
  content.voiceDuration = dto.voiceDuration;
  content.voiceWaveform = dto.voiceWaveform;
  content.isVoiceListened = dto.isVoiceListened;

  content.stickerPath = dto.stickerPath;
  content.stickerFileId = dto.stickerFileId;
  content.stickerEmoji = dto.stickerEmoji;
  content.stickerWidth = dto.stickerWidth;
  content.stickerHeight = dto.stickerHeight;
  content.isAnimatedSticker = dto.isAnimatedSticker;
  content.isVideoSticker = dto.isVideoSticker;
  content.isPremiumSticker = dto.isPremiumSticker;

  content.animationPath = dto.animationPath;
  content.animationFileId = dto.animationFileId;
  content.animationDuration = dto.animationDuration;
  content.animationWidth = dto.animationWidth;
  content.animationHeight = dto.animationHeight;

  content.videoNotePath = dto.videoNotePath;
  content.videoNoteFileId = dto.videoNoteFileId;
  content.videoNoteDuration = dto.videoNoteDuration;
  content.videoNoteLength = dto.videoNoteLength;
  return content;
}

// Create Message (AppState) from MessageDto
function messageFromDto(dto: MessageDto): Message {
  const message = new Message();
  message.id = dto.id;
  message.chatId = dto.chatId;
  message.senderId = dto.senderId;
  message.senderChatId = dto.senderChatId;
  message.mediaAlbumId = dto.mediaAlbumId;
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
  clone.mediaAlbumId = msg.mediaAlbumId;
  const clonedContent = new MessageContent();
  clonedContent.type = msg.content.type;
  clonedContent.text = msg.content.text;
  clonedContent.caption = msg.content.caption;
  clonedContent.photoPath = msg.content.photoPath;
  clonedContent.photoThumbPath = msg.content.photoThumbPath;
  clonedContent.photoFileId = msg.content.photoFileId;
  clonedContent.photoThumbFileId = msg.content.photoThumbFileId;
  clonedContent.photoWidth = msg.content.photoWidth;
  clonedContent.photoHeight = msg.content.photoHeight;
  clonedContent.videoPath = msg.content.videoPath;
  clonedContent.videoThumbPath = msg.content.videoThumbPath;
  clonedContent.videoFileId = msg.content.videoFileId;
  clonedContent.videoThumbFileId = msg.content.videoThumbFileId;
  clonedContent.videoDuration = msg.content.videoDuration;
  clonedContent.videoWidth = msg.content.videoWidth;
  clonedContent.videoHeight = msg.content.videoHeight;
  clonedContent.documentPath = msg.content.documentPath;
  clonedContent.documentFileId = msg.content.documentFileId;
  clonedContent.fileName = msg.content.fileName;
  clonedContent.fileSize = msg.content.fileSize;
  clonedContent.mimeType = msg.content.mimeType;
  clonedContent.audioPath = msg.content.audioPath;
  clonedContent.audioFileId = msg.content.audioFileId;
  clonedContent.audioDuration = msg.content.audioDuration;
  clonedContent.audioTitle = msg.content.audioTitle;
  clonedContent.audioPerformer = msg.content.audioPerformer;
  clonedContent.voicePath = msg.content.voicePath;
  clonedContent.voiceFileId = msg.content.voiceFileId;
  clonedContent.voiceDuration = msg.content.voiceDuration;
  clonedContent.voiceWaveform = msg.content.voiceWaveform;
  clonedContent.isVoiceListened = msg.content.isVoiceListened;
  clonedContent.stickerPath = msg.content.stickerPath;
  clonedContent.stickerFileId = msg.content.stickerFileId;
  clonedContent.stickerEmoji = msg.content.stickerEmoji;
  clonedContent.stickerWidth = msg.content.stickerWidth;
  clonedContent.stickerHeight = msg.content.stickerHeight;
  clonedContent.isAnimatedSticker = msg.content.isAnimatedSticker;
  clonedContent.isVideoSticker = msg.content.isVideoSticker;
  clonedContent.isPremiumSticker = msg.content.isPremiumSticker;
  clonedContent.animationPath = msg.content.animationPath;
  clonedContent.animationFileId = msg.content.animationFileId;
  clonedContent.animationDuration = msg.content.animationDuration;
  clonedContent.animationWidth = msg.content.animationWidth;
  clonedContent.animationHeight = msg.content.animationHeight;
  clonedContent.videoNotePath = msg.content.videoNotePath;
  clonedContent.videoNoteFileId = msg.content.videoNoteFileId;
  clonedContent.videoNoteDuration = msg.content.videoNoteDuration;
  clonedContent.videoNoteLength = msg.content.videoNoteLength;
  clone.content = clonedContent;
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
