// Message DTO - domain data transfer object for messages
// ArkTS compliant - uses TdObject wrapper class

import { ChatId, MessageId, UserId } from '../EntityId';
import { TdObject, tdGetString, tdGetNumber, tdGetBoolean, tdGetInt64, tdGetObject, tdGetArray, tdHasKeys } from '../../utils/tdAccessors';

export enum MessageContentType {
  TEXT = 'text',
  PHOTO = 'photo',
  VIDEO = 'video',
  DOCUMENT = 'document',
  AUDIO = 'audio',
  VOICE = 'voice',
  STICKER = 'sticker',
  LOCATION = 'location',
  CONTACT = 'contact',
  POLL = 'poll',
  ANIMATION = 'animation',
  VIDEO_NOTE = 'videoNote',
  UNKNOWN = 'unknown'
}

export class MessageContentDto {
  type: MessageContentType = MessageContentType.TEXT;
  text: string = '';
  caption: string = '';

  photoPath: string = '';
  photoThumbPath: string = '';
  photoFileId: number = 0;
  photoThumbFileId: number = 0;
  photoWidth: number = 0;
  photoHeight: number = 0;

  videoPath: string = '';
  videoThumbPath: string = '';
  videoFileId: number = 0;
  videoThumbFileId: number = 0;
  videoDuration: number = 0;
  videoWidth: number = 0;
  videoHeight: number = 0;

  documentPath: string = '';
  documentFileId: number = 0;
  fileName: string = '';
  fileSize: number = 0;
  mimeType: string = '';

  audioPath: string = '';
  audioFileId: number = 0;
  audioDuration: number = 0;
  audioTitle: string = '';
  audioPerformer: string = '';

  voicePath: string = '';
  voiceFileId: number = 0;
  voiceDuration: number = 0;
  voiceWaveform: string = '';
  isVoiceListened: boolean = false;

  stickerPath: string = '';
  stickerFileId: number = 0;
  stickerEmoji: string = '';
  stickerWidth: number = 0;
  stickerHeight: number = 0;
  isAnimatedSticker: boolean = false;
  isVideoSticker: boolean = false;
  isPremiumSticker: boolean = false;

  animationPath: string = '';
  animationFileId: number = 0;
  animationDuration: number = 0;
  animationWidth: number = 0;
  animationHeight: number = 0;

  videoNotePath: string = '';
  videoNoteFileId: number = 0;
  videoNoteDuration: number = 0;
  videoNoteLength: number = 0;
}

export class MessageDto {
  id: MessageId = '0';
  chatId: ChatId = 0;
  senderId: UserId = 0;
  senderChatId: ChatId = 0;
  mediaAlbumId: MessageId = '0';
  content: MessageContentDto = new MessageContentDto();
  timestamp: number = 0;
  isOutgoing: boolean = false;
  isRead: boolean = false;
  isPending: boolean = false;
  editDate: number = 0;
  replyToMessageId: MessageId = '0';
}

function extractCaption(contentObj: TdObject): string {
  const captionObj = tdGetObject(contentObj, 'caption');
  return tdGetString(captionObj, 'text');
}

function extractLocalFilePath(fileObj: TdObject): string {
  const localObj = tdGetObject(fileObj, 'local');
  // Only return path if download is fully complete — partial paths break ArkUI Image
  const isComplete = tdGetBoolean(localObj, 'is_downloading_completed');
  if (!isComplete) return '';
  return tdGetString(localObj, 'path');
}

function extractFileId(fileObj: TdObject): number {
  // Use getTopLevelNumber to avoid nested remote.id (string) shadowing numeric file id
  return fileObj.getTopLevelNumber('id');
}

function extractThumbnailPath(parentObj: TdObject): string {
  const thumbnailObj = tdGetObject(parentObj, 'thumbnail');
  const fileObj = tdGetObject(thumbnailObj, 'file');
  return extractLocalFilePath(fileObj);
}

function extractThumbnailFileId(parentObj: TdObject): number {
  const thumbnailObj = tdGetObject(parentObj, 'thumbnail');
  const fileObj = tdGetObject(thumbnailObj, 'file');
  return extractFileId(fileObj);
}

class PhotoFileInfo {
  path: string = '';
  fileId: number = 0;
}

function extractPhotoMain(photoObj: TdObject): PhotoFileInfo {
  const sizes = tdGetArray(photoObj, 'sizes');
  const result = new PhotoFileInfo();
  let bestArea = 0;
  for (const size of sizes) {
    const fileObj = tdGetObject(size, 'photo');
    const width = tdGetNumber(size, 'width');
    const height = tdGetNumber(size, 'height');
    const area = width * height;
    if (area >= bestArea) {
      bestArea = area;
      result.path = extractLocalFilePath(fileObj);
      result.fileId = extractFileId(fileObj);
    }
  }
  return result;
}

function extractPhotoThumb(photoObj: TdObject): PhotoFileInfo {
  const sizes = tdGetArray(photoObj, 'sizes');
  const result = new PhotoFileInfo();
  // Pick smallest size as thumbnail
  let smallestArea = Number.MAX_VALUE;
  for (const size of sizes) {
    const fileObj = tdGetObject(size, 'photo');
    const width = tdGetNumber(size, 'width');
    const height = tdGetNumber(size, 'height');
    const area = width * height;
    if (area > 0 && area < smallestArea) {
      smallestArea = area;
      result.path = extractLocalFilePath(fileObj);
      result.fileId = extractFileId(fileObj);
    }
  }
  return result;
}

class PhotoDimensions {
  width: number = 0;
  height: number = 0;
}

function extractPhotoDimensions(photoObj: TdObject): PhotoDimensions {
  const sizes = tdGetArray(photoObj, 'sizes');
  const result = new PhotoDimensions();
  let bestArea = 0;
  for (const size of sizes) {
    const width = tdGetNumber(size, 'width');
    const height = tdGetNumber(size, 'height');
    const area = width * height;
    if (area >= bestArea) {
      bestArea = area;
      result.width = width;
      result.height = height;
    }
  }
  return result;
}

// Helper to create DTO from raw TDLib message object
export function createMessageDtoFromTd(tdMessage: TdObject): MessageDto {
  const content = tdGetObject(tdMessage, 'content');
  const parsedContent = parseMessageContent(content);

  let senderId: UserId = 0;
  let senderChatId: ChatId = 0;
  const sender = tdGetObject(tdMessage, 'sender_id');
  const senderType = tdGetString(sender, '@type');
  if (senderType === 'messageSenderUser') {
    senderId = tdGetNumber(sender, 'user_id');
  } else if (senderType === 'messageSenderChat') {
    senderChatId = tdGetNumber(sender, 'chat_id');
  }

  const messageDto = new MessageDto();
  messageDto.id = tdGetInt64(tdMessage, 'id');
  messageDto.chatId = tdGetNumber(tdMessage, 'chat_id');
  messageDto.senderId = senderId;
  messageDto.senderChatId = senderChatId;
  messageDto.mediaAlbumId = tdGetInt64(tdMessage, 'media_album_id');

  messageDto.content = parsedContent;

  const tdDate = tdGetNumber(tdMessage, 'date');
  messageDto.timestamp = tdDate > 0 ? tdDate : Math.floor(Date.now() / 1000);
  messageDto.isOutgoing = tdGetBoolean(tdMessage, 'is_outgoing');
  messageDto.isRead = tdGetBoolean(tdMessage, 'is_read');
  messageDto.replyToMessageId = tdGetInt64(tdMessage, 'reply_to_message_id');

  return messageDto;
}

// Parse message content from TDLib object
export function parseMessageContent(contentObj: TdObject): MessageContentDto {
  const contentDto = new MessageContentDto();

  if (!tdHasKeys(contentObj)) {
    return contentDto;
  }

  const contentType = tdGetString(contentObj, '@type');

  switch (contentType) {
    case 'messageText': {
      const textObj = tdGetObject(contentObj, 'text');
      contentDto.type = MessageContentType.TEXT;
      contentDto.text = tdGetString(textObj, 'text');
      contentDto.caption = '';
      break;
    }
    case 'messagePhoto': {
      const caption = extractCaption(contentObj);
      const photoObj = tdGetObject(contentObj, 'photo');
      const dimensions = extractPhotoDimensions(photoObj);
      const photoMain = extractPhotoMain(photoObj);
      const photoThumb = extractPhotoThumb(photoObj);
      contentDto.type = MessageContentType.PHOTO;
      contentDto.caption = caption;
      contentDto.text = caption.length > 0 ? caption : '[Photo]';
      contentDto.photoPath = photoMain.path;
      contentDto.photoFileId = photoMain.fileId;
      contentDto.photoThumbPath = photoThumb.path;
      contentDto.photoThumbFileId = photoThumb.fileId;
      contentDto.photoWidth = dimensions.width;
      contentDto.photoHeight = dimensions.height;
      break;
    }
    case 'messageVideo': {
      const caption = extractCaption(contentObj);
      const videoObj = tdGetObject(contentObj, 'video');
      const videoFile = tdGetObject(videoObj, 'video');
      contentDto.type = MessageContentType.VIDEO;
      contentDto.caption = caption;
      contentDto.text = caption.length > 0 ? caption : '[Video]';
      contentDto.videoPath = extractLocalFilePath(videoFile);
      contentDto.videoFileId = extractFileId(videoFile);
      contentDto.videoThumbPath = extractThumbnailPath(videoObj);
      contentDto.videoThumbFileId = extractThumbnailFileId(videoObj);
      contentDto.videoDuration = tdGetNumber(videoObj, 'duration');
      contentDto.videoWidth = tdGetNumber(videoObj, 'width');
      contentDto.videoHeight = tdGetNumber(videoObj, 'height');
      contentDto.fileName = tdGetString(videoObj, 'file_name');
      contentDto.mimeType = tdGetString(videoObj, 'mime_type');
      contentDto.fileSize = tdGetNumber(videoFile, 'size');
      break;
    }
    case 'messageDocument': {
      const caption = extractCaption(contentObj);
      const documentObj = tdGetObject(contentObj, 'document');
      const documentFile = tdGetObject(documentObj, 'document');
      contentDto.type = MessageContentType.DOCUMENT;
      contentDto.caption = caption;
      contentDto.text = caption.length > 0 ? caption : '[File]';
      contentDto.documentPath = extractLocalFilePath(documentFile);
      contentDto.documentFileId = extractFileId(documentFile);
      contentDto.fileName = tdGetString(documentObj, 'file_name');
      contentDto.fileSize = tdGetNumber(documentFile, 'size');
      contentDto.mimeType = tdGetString(documentObj, 'mime_type');
      break;
    }
    case 'messageAudio': {
      const caption = extractCaption(contentObj);
      const audioObj = tdGetObject(contentObj, 'audio');
      const audioFile = tdGetObject(audioObj, 'audio');
      contentDto.type = MessageContentType.AUDIO;
      contentDto.caption = caption;
      contentDto.text = caption.length > 0 ? caption : '[Audio]';
      contentDto.audioPath = extractLocalFilePath(audioFile);
      contentDto.audioFileId = extractFileId(audioFile);
      contentDto.audioDuration = tdGetNumber(audioObj, 'duration');
      contentDto.audioTitle = tdGetString(audioObj, 'title');
      contentDto.audioPerformer = tdGetString(audioObj, 'performer');
      contentDto.fileName = tdGetString(audioObj, 'file_name');
      contentDto.fileSize = tdGetNumber(audioFile, 'size');
      contentDto.mimeType = tdGetString(audioObj, 'mime_type');
      break;
    }
    case 'messageVoiceNote': {
      const caption = extractCaption(contentObj);
      const voiceObj = tdGetObject(contentObj, 'voice_note');
      const voiceFile = tdGetObject(voiceObj, 'voice');
      contentDto.type = MessageContentType.VOICE;
      contentDto.caption = caption;
      contentDto.text = caption.length > 0 ? caption : '[Voice message]';
      contentDto.voicePath = extractLocalFilePath(voiceFile);
      contentDto.voiceFileId = extractFileId(voiceFile);
      contentDto.voiceDuration = tdGetNumber(voiceObj, 'duration');
      contentDto.voiceWaveform = tdGetString(voiceObj, 'waveform');
      contentDto.isVoiceListened = tdGetBoolean(contentObj, 'is_listened');
      break;
    }
    case 'messageSticker': {
      const stickerObj = tdGetObject(contentObj, 'sticker');
      const stickerFile = tdGetObject(stickerObj, 'sticker');
      const formatObj = tdGetObject(stickerObj, 'format');
      const formatType = tdGetString(formatObj, '@type');
      contentDto.type = MessageContentType.STICKER;
      contentDto.stickerPath = extractLocalFilePath(stickerFile);
      contentDto.stickerFileId = extractFileId(stickerFile);
      contentDto.stickerEmoji = tdGetString(stickerObj, 'emoji');
      contentDto.stickerWidth = tdGetNumber(stickerObj, 'width');
      contentDto.stickerHeight = tdGetNumber(stickerObj, 'height');
      contentDto.isAnimatedSticker = formatType === 'stickerFormatTgs';
      contentDto.isVideoSticker = formatType === 'stickerFormatWebm';
      contentDto.isPremiumSticker = tdGetBoolean(stickerObj, 'is_premium');
      contentDto.text = contentDto.stickerEmoji.length > 0 ? contentDto.stickerEmoji : '[Sticker]';
      break;
    }
    case 'messageLocation':
      contentDto.type = MessageContentType.LOCATION;
      contentDto.text = '[Location]';
      break;
    case 'messageContact':
      contentDto.type = MessageContentType.CONTACT;
      contentDto.text = '[Contact]';
      break;
    case 'messagePoll':
      contentDto.type = MessageContentType.POLL;
      contentDto.text = '[Poll]';
      break;
    case 'messageAnimation': {
      const caption = extractCaption(contentObj);
      const animationObj = tdGetObject(contentObj, 'animation');
      const animationFile = tdGetObject(animationObj, 'animation');
      contentDto.type = MessageContentType.ANIMATION;
      contentDto.caption = caption;
      contentDto.text = caption.length > 0 ? caption : '[GIF]';
      contentDto.animationPath = extractLocalFilePath(animationFile);
      contentDto.animationFileId = extractFileId(animationFile);
      contentDto.videoThumbPath = extractThumbnailPath(animationObj);
      contentDto.videoThumbFileId = extractThumbnailFileId(animationObj);
      contentDto.animationDuration = tdGetNumber(animationObj, 'duration');
      contentDto.animationWidth = tdGetNumber(animationObj, 'width');
      contentDto.animationHeight = tdGetNumber(animationObj, 'height');
      contentDto.fileName = tdGetString(animationObj, 'file_name');
      contentDto.fileSize = tdGetNumber(animationFile, 'size');
      contentDto.mimeType = tdGetString(animationObj, 'mime_type');
      break;
    }
    case 'messageVideoNote': {
      const videoNoteObj = tdGetObject(contentObj, 'video_note');
      const videoNoteFile = tdGetObject(videoNoteObj, 'video');
      contentDto.type = MessageContentType.VIDEO_NOTE;
      contentDto.text = '[Video message]';
      contentDto.videoNotePath = extractLocalFilePath(videoNoteFile);
      contentDto.videoNoteFileId = extractFileId(videoNoteFile);
      contentDto.videoThumbPath = extractThumbnailPath(videoNoteObj);
      contentDto.videoThumbFileId = extractThumbnailFileId(videoNoteObj);
      contentDto.videoNoteDuration = tdGetNumber(videoNoteObj, 'duration');
      contentDto.videoNoteLength = tdGetNumber(videoNoteObj, 'length');
      break;
    }
    default:
      contentDto.type = MessageContentType.UNKNOWN;
      contentDto.text = contentType.length > 0 ? `[${contentType}]` : '[Unsupported]';
  }

  return contentDto;
}

// Helper for partial updates (messageUpdated event)
export class MessageUpdateDto {
  content?: MessageContentDto;
  isRead?: boolean;
  editDate?: number;
}

export function applyMessageUpdate(message: MessageDto, update: MessageUpdateDto): MessageDto {
  const updatedMessage = new MessageDto();
  updatedMessage.id = message.id;
  updatedMessage.chatId = message.chatId;
  updatedMessage.senderId = message.senderId;
  updatedMessage.senderChatId = message.senderChatId;
  updatedMessage.mediaAlbumId = message.mediaAlbumId;
  updatedMessage.content = message.content;
  updatedMessage.timestamp = message.timestamp;
  updatedMessage.isOutgoing = message.isOutgoing;
  updatedMessage.isRead = message.isRead;
  updatedMessage.isPending = message.isPending;
  updatedMessage.editDate = message.editDate;
  updatedMessage.replyToMessageId = message.replyToMessageId;

  if (update.content !== undefined) {
    updatedMessage.content = update.content;
  }
  if (update.isRead !== undefined) {
    updatedMessage.isRead = update.isRead;
  }
  if (update.editDate !== undefined) {
    updatedMessage.editDate = update.editDate;
  }

  return updatedMessage;
}
