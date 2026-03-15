// Files reducer — handles file download events
// When a file download completes, scans users, chats, and message content
// for matching fileId and updates the local file path.

import { AppState, Message, MessageContent, ReducerAction } from '../model/AppState';
import { FileDownloadedEvent } from '../model/AppEvent';
import { cloneAppState, cloneUser, cloneChat } from '../utils/stateClone';

function contentMatchesFileId(content: MessageContent, fileId: number): boolean {
  return content.photoFileId === fileId ||
    content.photoThumbFileId === fileId ||
    content.videoFileId === fileId ||
    content.videoThumbFileId === fileId ||
    content.documentFileId === fileId ||
    content.audioFileId === fileId ||
    content.voiceFileId === fileId ||
    content.stickerFileId === fileId ||
    content.animationFileId === fileId ||
    content.videoNoteFileId === fileId;
}

function applyFilePathToContent(content: MessageContent, fileId: number, localPath: string): MessageContent {
  // Clone content and update matching path fields
  const c = new MessageContent();
  c.type = content.type;
  c.text = content.text;
  c.caption = content.caption;

  c.photoPath = content.photoFileId === fileId ? localPath : content.photoPath;
  c.photoThumbPath = content.photoThumbFileId === fileId ? localPath : content.photoThumbPath;
  c.photoFileId = content.photoFileId;
  c.photoThumbFileId = content.photoThumbFileId;
  c.photoWidth = content.photoWidth;
  c.photoHeight = content.photoHeight;

  c.videoPath = content.videoFileId === fileId ? localPath : content.videoPath;
  c.videoThumbPath = content.videoThumbFileId === fileId ? localPath : content.videoThumbPath;
  c.videoFileId = content.videoFileId;
  c.videoThumbFileId = content.videoThumbFileId;
  c.videoDuration = content.videoDuration;
  c.videoWidth = content.videoWidth;
  c.videoHeight = content.videoHeight;

  c.documentPath = content.documentFileId === fileId ? localPath : content.documentPath;
  c.documentFileId = content.documentFileId;
  c.fileName = content.fileName;
  c.fileSize = content.fileSize;
  c.mimeType = content.mimeType;

  c.audioPath = content.audioFileId === fileId ? localPath : content.audioPath;
  c.audioFileId = content.audioFileId;
  c.audioDuration = content.audioDuration;
  c.audioTitle = content.audioTitle;
  c.audioPerformer = content.audioPerformer;

  c.voicePath = content.voiceFileId === fileId ? localPath : content.voicePath;
  c.voiceFileId = content.voiceFileId;
  c.voiceDuration = content.voiceDuration;
  c.voiceWaveform = content.voiceWaveform;
  c.isVoiceListened = content.isVoiceListened;

  c.stickerPath = content.stickerFileId === fileId ? localPath : content.stickerPath;
  c.stickerFileId = content.stickerFileId;
  c.stickerEmoji = content.stickerEmoji;
  c.stickerWidth = content.stickerWidth;
  c.stickerHeight = content.stickerHeight;
  c.isAnimatedSticker = content.isAnimatedSticker;
  c.isVideoSticker = content.isVideoSticker;
  c.isPremiumSticker = content.isPremiumSticker;

  c.animationPath = content.animationFileId === fileId ? localPath : content.animationPath;
  c.animationFileId = content.animationFileId;
  c.animationDuration = content.animationDuration;
  c.animationWidth = content.animationWidth;
  c.animationHeight = content.animationHeight;

  c.videoNotePath = content.videoNoteFileId === fileId ? localPath : content.videoNotePath;
  c.videoNoteFileId = content.videoNoteFileId;
  c.videoNoteDuration = content.videoNoteDuration;
  c.videoNoteLength = content.videoNoteLength;

  return c;
}

function cloneMessageWithContent(msg: Message, newContent: MessageContent): Message {
  const clone = new Message();
  clone.id = msg.id;
  clone.chatId = msg.chatId;
  clone.senderId = msg.senderId;
  clone.senderChatId = msg.senderChatId;
  clone.content = newContent;
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

  // Pre-scan: check if any user, chat, or message needs this file
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

  // Scan messages for matching fileId
  let messageNeedsUpdate = false;
  if (!needsUpdate) {
    state.messages.messages.forEach((chatMessages) => {
      if (messageNeedsUpdate) return;
      chatMessages.forEach((message) => {
        if (messageNeedsUpdate) return;
        if (contentMatchesFileId(message.content, fileId)) {
          messageNeedsUpdate = true;
        }
      });
    });
    needsUpdate = messageNeedsUpdate;
  } else {
    // Also check messages since we're already updating
    state.messages.messages.forEach((chatMessages) => {
      if (messageNeedsUpdate) return;
      chatMessages.forEach((message) => {
        if (messageNeedsUpdate) return;
        if (contentMatchesFileId(message.content, fileId)) {
          messageNeedsUpdate = true;
        }
      });
    });
  }

  if (!needsUpdate) {
    return state;
  }

  // Clone state and apply updates
  const newState = cloneAppState(state);

  // Update user avatars
  newState.users.users.forEach((user, userId) => {
    if (user.photoSmallFileId === fileId && user.photoSmall !== localPath) {
      const updatedUser = cloneUser(user);
      updatedUser.photoSmall = localPath;
      newState.users.users.set(userId, updatedUser);
    }
  });

  // Update chat avatars
  newState.chats.chats.forEach((chat, chatId) => {
    if (chat.photoSmallFileId === fileId && chat.photoSmall !== localPath) {
      const updatedChat = cloneChat(chat);
      updatedChat.photoSmall = localPath;
      newState.chats.chats.set(chatId, updatedChat);
    }
  });

  // Update message content paths
  if (messageNeedsUpdate) {
    newState.messages.messages.forEach((chatMessages, chatId) => {
      let chatChanged = false;
      const newChatMessages = new Map<string, Message>(chatMessages);
      chatMessages.forEach((message, messageId) => {
        if (contentMatchesFileId(message.content, fileId)) {
          const newContent = applyFilePathToContent(message.content, fileId, localPath);
          newChatMessages.set(messageId, cloneMessageWithContent(message, newContent));
          chatChanged = true;
        }
      });
      if (chatChanged) {
        newState.messages.messages.set(chatId, newChatMessages);
      }
    });
  }

  newState.version = state.version + 1;
  newState.lastEvent = action;
  return newState;
}
