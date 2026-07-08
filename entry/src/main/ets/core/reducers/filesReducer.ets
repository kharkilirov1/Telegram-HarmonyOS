// Files reducer — handles file transfer state + file download completion events
// Keeps a fileId -> transfer-state map for UI download indicators and,
// when a file completes, scans users/chats/messages to apply the local path.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppState, FileTransfer, Message, MessageContent, MessageQuoteEntity, ReducerAction } from '../model/AppState';
import { FileDownloadedEvent, FileTransferUpdatedEvent } from '../model/AppEvent';
import { cloneAppState, cloneChat, cloneStateForFiles, cloneUser } from '../utils/stateClone';

const DOMAIN = 0x0004;
const TAG = 'FilesReducer';

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

// TDLib renumbers file ids between message parse and download completion, so a
// completed download may relate to a message only through remote.unique_id
// (P4-c). Without this the pre-scan below skips the transfers write for fast
// downloads (they emit no interim transfer updates) and the open chat never
// live-refreshes — the path only appears after reopening the chat.
function contentMatchesUniqueId(content: MessageContent, uniqueId: string): boolean {
  if (uniqueId.length === 0) {
    return false;
  }
  return content.photoUniqueId === uniqueId ||
    content.photoThumbUniqueId === uniqueId ||
    content.videoUniqueId === uniqueId ||
    content.videoThumbUniqueId === uniqueId ||
    content.documentUniqueId === uniqueId ||
    content.audioUniqueId === uniqueId ||
    content.voiceUniqueId === uniqueId ||
    content.stickerUniqueId === uniqueId ||
    content.stickerThumbUniqueId === uniqueId ||
    content.animationUniqueId === uniqueId ||
    content.videoNoteUniqueId === uniqueId;
}

function applyFilePathToContent(content: MessageContent, fileId: number, localPath: string): MessageContent {
  // Clone content and update matching path fields
  const c = new MessageContent();
  c.type = content.type;
  c.text = content.text;
  c.caption = content.caption;
  c.quoteEntities = content.quoteEntities.map((entity) => {
    const cloneEntity = new MessageQuoteEntity();
    cloneEntity.offset = entity.offset;
    cloneEntity.length = entity.length;
    cloneEntity.isCollapsed = entity.isCollapsed;
    return cloneEntity;
  });

  c.photoPath = content.photoFileId === fileId ? localPath : content.photoPath;
  c.photoThumbPath = content.photoThumbFileId === fileId ? localPath : content.photoThumbPath;
  c.photoFileId = content.photoFileId;
  c.photoThumbFileId = content.photoThumbFileId;
  c.photoWidth = content.photoWidth;
  c.photoHeight = content.photoHeight;
  c.photoMinithumb = content.photoMinithumb;

  c.videoPath = content.videoFileId === fileId ? localPath : content.videoPath;
  c.videoThumbPath = content.videoThumbFileId === fileId ? localPath : content.videoThumbPath;
  c.videoMinithumb = content.videoMinithumb;
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
  c.stickerThumbnailPath = content.stickerThumbnailPath;

  c.animationPath = content.animationFileId === fileId ? localPath : content.animationPath;
  c.animationFileId = content.animationFileId;
  c.animationDuration = content.animationDuration;
  c.animationWidth = content.animationWidth;
  c.animationHeight = content.animationHeight;

  c.videoNotePath = content.videoNoteFileId === fileId ? localPath : content.videoNotePath;
  c.videoNoteFileId = content.videoNoteFileId;
  c.videoNoteDuration = content.videoNoteDuration;
  c.videoNoteLength = content.videoNoteLength;

  // remote.unique_id fields — dropping them here broke alias resolution for
  // any later renumbered download of the same message (runtime saw uid=0)
  c.photoUniqueId = content.photoUniqueId;
  c.photoThumbUniqueId = content.photoThumbUniqueId;
  c.videoUniqueId = content.videoUniqueId;
  c.videoThumbUniqueId = content.videoThumbUniqueId;
  c.documentUniqueId = content.documentUniqueId;
  c.audioUniqueId = content.audioUniqueId;
  c.voiceUniqueId = content.voiceUniqueId;
  c.stickerUniqueId = content.stickerUniqueId;
  c.stickerThumbUniqueId = content.stickerThumbUniqueId;
  c.animationUniqueId = content.animationUniqueId;
  c.videoNoteUniqueId = content.videoNoteUniqueId;

  return c;
}

function cloneMessageWithContent(msg: Message, newContent: MessageContent): Message {
  const clone = new Message();
  clone.id = msg.id;
  clone.chatId = msg.chatId;
  clone.senderId = msg.senderId;
  clone.senderChatId = msg.senderChatId;
  clone.mediaAlbumId = msg.mediaAlbumId;
  clone.content = newContent;
  clone.timestamp = msg.timestamp;
  clone.isOutgoing = msg.isOutgoing;
  clone.isRead = msg.isRead;
  clone.isPending = msg.isPending;
  clone.editDate = msg.editDate;
  clone.replyToMessageId = msg.replyToMessageId;
  clone.replyIsQuote = msg.replyIsQuote;
  clone.replyQuoteText = msg.replyQuoteText;
  clone.replyQuoteOffset = msg.replyQuoteOffset;
  clone.sendStatus = msg.sendStatus;
  clone.sendErrorCode = msg.sendErrorCode;
  clone.sendErrorMessage = msg.sendErrorMessage;
  return clone;
}

function cloneFileTransfer(existing?: FileTransfer): FileTransfer {
  const next = new FileTransfer();
  if (!existing) {
    return next;
  }
  next.fileId = existing.fileId;
  next.localPath = existing.localPath;
  next.isDownloadingActive = existing.isDownloadingActive;
  next.isDownloadingCompleted = existing.isDownloadingCompleted;
  next.size = existing.size;
  next.expectedSize = existing.expectedSize;
  next.downloadOffset = existing.downloadOffset;
  next.downloadedPrefixSize = existing.downloadedPrefixSize;
  next.downloadedSize = existing.downloadedSize;
  return next;
}

function applyTransferEvent(existing: FileTransfer | undefined, event: FileTransferUpdatedEvent): FileTransfer {
  const next = cloneFileTransfer(existing);
  next.fileId = event.fileId;
  next.localPath = event.localPath;
  next.isDownloadingActive = event.isDownloadingActive;
  next.isDownloadingCompleted = event.isComplete;
  next.size = event.size;
  next.expectedSize = event.expectedSize;
  next.downloadOffset = event.downloadOffset;
  next.downloadedPrefixSize = event.downloadedPrefixSize;
  next.downloadedSize = event.downloadedSize;
  return next;
}

function sameTransfer(a: FileTransfer | undefined, b: FileTransfer): boolean {
  if (!a) {
    return false;
  }
  return a.fileId === b.fileId &&
    a.localPath === b.localPath &&
    a.isDownloadingActive === b.isDownloadingActive &&
    a.isDownloadingCompleted === b.isDownloadingCompleted &&
    a.size === b.size &&
    a.expectedSize === b.expectedSize &&
    a.downloadOffset === b.downloadOffset &&
    a.downloadedPrefixSize === b.downloadedPrefixSize &&
    a.downloadedSize === b.downloadedSize;
}

// Append-only реестр unique_id→fileId[]. Мутируем на месте: реестр шарится по
// ссылке между стейтами (см. cloneFilesState), монотонен и не участвует в
// diff-рендеринге (страница перерисовывается по transfers/version). Даёт
// resolveContentPath найти скачанный файл, когда TDLib выдал новый fileId.
function registerFileAlias(state: AppState, uniqueId: string, fileId: number): void {
  if (uniqueId.length === 0 || fileId <= 0) {
    return;
  }
  const existingIds = state.files.aliases.get(uniqueId);
  if (existingIds === undefined) {
    state.files.aliases.set(uniqueId, [fileId]);
  } else if (!existingIds.includes(fileId)) {
    existingIds.push(fileId);
  }
}

export function filesReducer(state: AppState, action: ReducerAction): AppState {
  if (action.type === 'fileTransferUpdated') {
    const event = action as FileTransferUpdatedEvent;
    if (!event.fileId) {
      return state;
    }
    registerFileAlias(state, event.uniqueId, event.fileId);

    const existing = state.files.transfers.get(event.fileId);
    const nextTransfer = applyTransferEvent(existing, event);
    if (sameTransfer(existing, nextTransfer)) {
      return state;
    }

    const newState = cloneStateForFiles(state);
    newState.files.transfers.set(event.fileId, nextTransfer);
    newState.version = state.version + 1;
    newState.lastEvent = action;
    return newState;
  }

  if (action.type !== 'fileDownloaded') {
    return state;
  }

  const event = action as FileDownloadedEvent;
  if (!event.fileId || !event.localPath || !event.isComplete) {
    return state;
  }

  const fileId = event.fileId;
  const localPath = event.localPath;
  registerFileAlias(state, event.uniqueId, fileId);

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

  // Scan messages for matching fileId (direct id or unique_id alias — TDLib
  // may have renumbered the id since the message was parsed)
  let messageNeedsUpdate = false;
  if (!needsUpdate) {
    state.messages.messages.forEach((chatMessages) => {
      if (messageNeedsUpdate) return;
      chatMessages.forEach((message) => {
        if (messageNeedsUpdate) return;
        if (contentMatchesFileId(message.content, fileId) ||
          contentMatchesUniqueId(message.content, event.uniqueId)) {
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
        if (contentMatchesFileId(message.content, fileId) ||
          contentMatchesUniqueId(message.content, event.uniqueId)) {
          messageNeedsUpdate = true;
        }
      });
    });
  }

  // ВНИМАНИЕ: не логировать здесь per-file на info — при медиа-штормах сотни
  // hilog-строк/с блокируют main thread внутри HiLogPrint (freeze 2026-07-03 13:29).
  hilog.debug(DOMAIN, TAG, 'fileDownloaded id=%{public}d uid=%{public}s needsUpdate=%{public}s',
    fileId, event.uniqueId, String(needsUpdate));

  if (!needsUpdate) {
    return state;
  }

  // Clone state and apply updates
  const newState = cloneAppState(state);

  const completedTransfer = cloneFileTransfer(newState.files.transfers.get(fileId));
  completedTransfer.fileId = fileId;
  completedTransfer.localPath = localPath;
  completedTransfer.isDownloadingActive = false;
  completedTransfer.isDownloadingCompleted = true;
  if (completedTransfer.size <= 0 && completedTransfer.expectedSize > 0) {
    completedTransfer.size = completedTransfer.expectedSize;
  }
  const effectiveSize = Math.max(completedTransfer.size, completedTransfer.expectedSize);
  if (effectiveSize > 0) {
    completedTransfer.downloadedPrefixSize = effectiveSize;
    completedTransfer.downloadedSize = effectiveSize;
  }
  newState.files.transfers.set(fileId, completedTransfer);

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
