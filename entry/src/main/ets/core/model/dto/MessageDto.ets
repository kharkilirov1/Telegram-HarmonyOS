// Message DTO - domain data transfer object for messages
// ArkTS compliant - uses TdObject wrapper class

import { ChatId, MessageId, UserId } from '../EntityId';
import { TdObject, tdGetString, tdGetNumber, tdGetBoolean, tdGetInt64, tdGetObject, tdGetArray, tdGetNumberArray, tdHasKeys } from '../../utils/tdAccessors';

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
  SERVICE = 'service',
  UNKNOWN = 'unknown'
}

export class MessageQuoteEntityDto {
  offset: number = 0;
  length: number = 0;
  isCollapsed: boolean = false;
}

export class TextEntityDto {
  offset: number = 0;
  length: number = 0;
  type: string = '';
  url: string = '';
  userId: number = 0;
  language: string = '';
}

export class MessageContentDto {
  type: MessageContentType = MessageContentType.TEXT;
  text: string = '';
  caption: string = '';
  quoteEntities: MessageQuoteEntityDto[] = [];
  textEntities: TextEntityDto[] = [];
  captionEntities: TextEntityDto[] = [];

  // TDLib messageText.link_preview (legacy fallback: messageText.web_page)
  linkPreviewUrl: string = '';
  linkPreviewDisplayUrl: string = '';
  linkPreviewSiteName: string = '';
  linkPreviewTitle: string = '';
  linkPreviewDescription: string = '';
  linkPreviewAuthor: string = '';
  linkPreviewType: string = '';
  linkPreviewShowLargeMedia: boolean = false;
  linkPreviewShowMediaAboveDescription: boolean = false;
  linkPreviewShowAboveText: boolean = false;
  linkPreviewPhotoPath: string = '';
  linkPreviewPhotoThumbPath: string = '';
  linkPreviewPhotoFileId: number = 0;
  linkPreviewPhotoThumbFileId: number = 0;
  linkPreviewPhotoWidth: number = 0;
  linkPreviewPhotoHeight: number = 0;
  linkPreviewPhotoMinithumb: string = '';
  linkPreviewPhotoUniqueId: string = '';
  linkPreviewPhotoThumbUniqueId: string = '';

  // Service messages (chat events): raw TDLib @type + payload for VO-side text resolve
  serviceType: string = '';
  serviceUserIds: number[] = [];
  serviceTitle: string = '';

  photoPath: string = '';
  photoThumbPath: string = '';
  photoFileId: number = 0;
  photoThumbFileId: number = 0;
  photoWidth: number = 0;
  photoHeight: number = 0;
  photoMinithumb: string = '';
  photoUniqueId: string = '';
  photoThumbUniqueId: string = '';
  videoUniqueId: string = '';
  videoThumbUniqueId: string = '';
  documentUniqueId: string = '';
  audioUniqueId: string = '';
  voiceUniqueId: string = '';
  stickerUniqueId: string = '';
  stickerThumbUniqueId: string = '';
  animationUniqueId: string = '';
  videoNoteUniqueId: string = '';

  videoPath: string = '';
  videoThumbPath: string = '';
  videoMinithumb: string = '';
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
  audioCoverPath: string = '';
  audioCoverFileId: number = 0;
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
  stickerThumbnailPath: string = '';
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

  // Contact
  contactFirstName: string = '';
  contactLastName: string = '';
  contactPhoneNumber: string = '';
  contactUserId: number = 0;

  // Location
  locationLatitude: number = 0;
  locationLongitude: number = 0;
  locationVenueTitle: string = '';
  locationVenueAddress: string = '';

  // Poll
  pollQuestion: string = '';
  pollTotalVoterCount: number = 0;
  pollIsClosed: boolean = false;
  pollIsAnonymous: boolean = true;
  pollType: string = 'regular';
  pollOptions: PollOptionDto[] = [];
}

export class PollOptionDto {
  text: string = '';
  voterCount: number = 0;
  votePercentage: number = 0;
  isChosen: boolean = false;
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
  replyToChatId: ChatId = 0;
  replyToMessageId: MessageId = '0';
  replyIsQuote: boolean = false;
  replyQuoteText: string = '';
  replyQuoteOffset: number = -1;
}

function extractCaption(contentObj: TdObject): string {
  const captionObj = tdGetObject(contentObj, 'caption');
  return tdGetString(captionObj, 'text');
}

function extractCaptionQuoteEntities(contentObj: TdObject): MessageQuoteEntityDto[] {
  const captionObj = tdGetObject(contentObj, 'caption');
  return extractQuoteEntities(captionObj);
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

function extractQuoteEntities(formattedTextObj: TdObject): MessageQuoteEntityDto[] {
  const result: MessageQuoteEntityDto[] = [];
  if (!tdHasKeys(formattedTextObj)) {
    return result;
  }

  const entities = tdGetArray(formattedTextObj, 'entities');
  for (const entity of entities) {
    const offset = tdGetNumber(entity, 'offset');
    const length = tdGetNumber(entity, 'length');
    if (length <= 0) {
      continue;
    }

    const typeObj = tdGetObject(entity, 'type');
    const typeName = tdGetString(typeObj, '@type');
    if (typeName !== 'textEntityTypeBlockQuote' && typeName !== 'textEntityTypeExpandableBlockQuote') {
      continue;
    }

    const quote = new MessageQuoteEntityDto();
    quote.offset = Math.max(0, offset);
    quote.length = Math.max(0, length);
    quote.isCollapsed = typeName === 'textEntityTypeExpandableBlockQuote' ||
      tdGetBoolean(typeObj, 'is_collapsed') ||
      tdGetBoolean(typeObj, 'collapsed');
    result.push(quote);
  }

  return result;
}

// Map TDLib entity type name → short type string
function mapEntityType(typeName: string): string {
  switch (typeName) {
    case 'textEntityTypeBold': return 'bold';
    case 'textEntityTypeItalic': return 'italic';
    case 'textEntityTypeUnderline': return 'underline';
    case 'textEntityTypeStrikethrough': return 'strikethrough';
    case 'textEntityTypeCode': return 'code';
    case 'textEntityTypePre': return 'pre';
    case 'textEntityTypePreCode': return 'preCode';
    case 'textEntityTypeUrl': return 'url';
    case 'textEntityTypeTextUrl': return 'textUrl';
    case 'textEntityTypeEmailAddress': return 'emailAddress';
    case 'textEntityTypePhoneNumber': return 'phoneNumber';
    case 'textEntityTypeMention': return 'mention';
    case 'textEntityTypeMentionName': return 'mentionName';
    case 'textEntityTypeHashtag': return 'hashtag';
    case 'textEntityTypeCashtag': return 'cashtag';
    case 'textEntityTypeBotCommand': return 'botCommand';
    case 'textEntityTypeSpoiler': return 'spoiler';
    case 'textEntityTypeCustomEmoji': return 'customEmoji';
    default: return '';
  }
}

function extractTextEntities(formattedTextObj: TdObject): TextEntityDto[] {
  const result: TextEntityDto[] = [];
  if (!tdHasKeys(formattedTextObj)) {
    return result;
  }

  const entities = tdGetArray(formattedTextObj, 'entities');
  for (const entity of entities) {
    const offset = tdGetNumber(entity, 'offset');
    const length = tdGetNumber(entity, 'length');
    if (length <= 0) {
      continue;
    }

    const typeObj = tdGetObject(entity, 'type');
    const typeName = tdGetString(typeObj, '@type');
    const mapped = mapEntityType(typeName);
    if (mapped.length === 0) {
      continue; // skip blockQuote types (handled by extractQuoteEntities) and unknown
    }

    const dto = new TextEntityDto();
    dto.offset = Math.max(0, offset);
    dto.length = Math.max(0, length);
    dto.type = mapped;
    if (mapped === 'textUrl') {
      dto.url = tdGetString(typeObj, 'url');
    } else if (mapped === 'mentionName') {
      dto.userId = tdGetNumber(typeObj, 'user_id');
    } else if (mapped === 'preCode') {
      dto.language = tdGetString(typeObj, 'language');
    }
    result.push(dto);
  }

  return result;
}

function extractCaptionTextEntities(contentObj: TdObject): TextEntityDto[] {
  const captionObj = tdGetObject(contentObj, 'caption');
  return extractTextEntities(captionObj);
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

function extractThumbnailUniqueId(parentObj: TdObject): string {
  const thumbnailObj = tdGetObject(parentObj, 'thumbnail');
  return extractRemoteUniqueId(tdGetObject(thumbnailObj, 'file'));
}

class PhotoFileInfo {
  path: string = '';
  fileId: number = 0;
  uniqueId: string = '';
}

// TDLib remote.unique_id — стабильный ключ файла: file id пере-нумеруется
// между сессиями/запросами, unique_id — нет (канон для алиасинга transfers).
function extractRemoteUniqueId(fileObj: TdObject): string {
  return tdGetString(tdGetObject(fileObj, 'remote'), 'unique_id');
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
      result.uniqueId = extractRemoteUniqueId(fileObj);
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
      result.uniqueId = extractRemoteUniqueId(fileObj);
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

function extractLinkPreview(contentObj: TdObject): TdObject {
  const current = tdGetObject(contentObj, 'link_preview');
  if (tdHasKeys(current)) {
    return current;
  }
  // Compatibility with the older model surface still present under models/td.
  return tdGetObject(contentObj, 'web_page');
}

function extractLinkPreviewPhoto(linkPreviewObj: TdObject): TdObject {
  const typeObj = tdGetObject(linkPreviewObj, 'type');
  const photoObj = tdGetObject(typeObj, 'photo');
  if (tdHasKeys(photoObj)) {
    return photoObj;
  }
  // Embedded player link-preview types expose their poster as a photo thumbnail.
  return tdGetObject(typeObj, 'thumbnail');
}

function applyLinkPreview(contentDto: MessageContentDto, contentObj: TdObject): void {
  const linkPreviewObj = extractLinkPreview(contentObj);
  if (!tdHasKeys(linkPreviewObj)) {
    return;
  }

  const typeObj = tdGetObject(linkPreviewObj, 'type');
  const descriptionObj = tdGetObject(linkPreviewObj, 'description');
  const photoObj = extractLinkPreviewPhoto(linkPreviewObj);
  const photoMain = extractPhotoMain(photoObj);
  const photoThumb = extractPhotoThumb(photoObj);
  const dimensions = extractPhotoDimensions(photoObj);

  contentDto.linkPreviewUrl = tdGetString(linkPreviewObj, 'url');
  contentDto.linkPreviewDisplayUrl = tdGetString(linkPreviewObj, 'display_url');
  contentDto.linkPreviewSiteName = tdGetString(linkPreviewObj, 'site_name');
  contentDto.linkPreviewTitle = tdGetString(linkPreviewObj, 'title');
  contentDto.linkPreviewDescription = tdGetString(descriptionObj, 'text');
  contentDto.linkPreviewAuthor = tdGetString(linkPreviewObj, 'author');
  contentDto.linkPreviewType = tdGetString(typeObj, '@type');
  contentDto.linkPreviewShowLargeMedia = tdGetBoolean(linkPreviewObj, 'show_large_media');
  contentDto.linkPreviewShowMediaAboveDescription = tdGetBoolean(linkPreviewObj, 'show_media_above_description');
  contentDto.linkPreviewShowAboveText = tdGetBoolean(linkPreviewObj, 'show_above_text');
  contentDto.linkPreviewPhotoPath = photoMain.path;
  contentDto.linkPreviewPhotoThumbPath = photoThumb.path;
  contentDto.linkPreviewPhotoFileId = photoMain.fileId;
  contentDto.linkPreviewPhotoThumbFileId = photoThumb.fileId;
  contentDto.linkPreviewPhotoWidth = dimensions.width;
  contentDto.linkPreviewPhotoHeight = dimensions.height;
  contentDto.linkPreviewPhotoMinithumb = tdGetString(tdGetObject(photoObj, 'minithumbnail'), 'data');
  contentDto.linkPreviewPhotoUniqueId = photoMain.uniqueId;
  contentDto.linkPreviewPhotoThumbUniqueId = photoThumb.uniqueId;
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
  messageDto.editDate = tdGetNumber(tdMessage, 'edit_date');

  const replyTo = tdGetObject(tdMessage, 'reply_to');
  const nestedReplyMessageId = tdGetInt64(replyTo, 'message_id');
  const directReplyMessageId = tdGetInt64(tdMessage, 'reply_to_message_id');
  messageDto.replyToMessageId = nestedReplyMessageId !== '0' ? nestedReplyMessageId : directReplyMessageId;
  if (messageDto.replyToMessageId !== '0') {
    const nestedReplyChatId = tdGetNumber(replyTo, 'chat_id');
    messageDto.replyToChatId = nestedReplyChatId !== 0 ? nestedReplyChatId : messageDto.chatId;
  }

  const quoteObj = tdGetObject(replyTo, 'quote');
  const quoteObjText = tdGetString(quoteObj, 'text');
  const quoteText = tdGetString(replyTo, 'quote_text');
  const resolvedQuoteText = quoteText.length > 0 ? quoteText : quoteObjText;
  // Current TDLib carries the position inside textQuote (`quote.position`,
  // omitted when 0); legacy payloads used a flat `quote_offset`. Position 0
  // is a valid quote start and must not collapse to the -1 sentinel.
  const legacyQuoteOffset = tdGetNumber(replyTo, 'quote_offset');
  const quotePosition = tdHasKeys(quoteObj)
    ? tdGetNumber(quoteObj, 'position')
    : (legacyQuoteOffset > 0 ? legacyQuoteOffset : -1);
  messageDto.replyQuoteText = resolvedQuoteText;
  messageDto.replyQuoteOffset = resolvedQuoteText.length > 0 ? quotePosition : -1;
  messageDto.replyIsQuote = tdGetBoolean(replyTo, 'quote') || tdHasKeys(quoteObj) || resolvedQuoteText.length > 0;

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
      contentDto.quoteEntities = extractQuoteEntities(textObj);
      contentDto.textEntities = extractTextEntities(textObj);
      applyLinkPreview(contentDto, contentObj);
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
      contentDto.quoteEntities = extractCaptionQuoteEntities(contentObj);
      contentDto.captionEntities = extractCaptionTextEntities(contentObj);
      contentDto.text = caption.length > 0 ? caption : '[Photo]';
      contentDto.photoPath = photoMain.path;
      contentDto.photoFileId = photoMain.fileId;
      contentDto.photoThumbPath = photoThumb.path;
      contentDto.photoThumbFileId = photoThumb.fileId;
      contentDto.photoWidth = dimensions.width;
      contentDto.photoHeight = dimensions.height;
      contentDto.photoMinithumb = tdGetString(tdGetObject(photoObj, 'minithumbnail'), 'data');
      contentDto.photoUniqueId = photoMain.uniqueId;
      contentDto.photoThumbUniqueId = photoThumb.uniqueId;
      break;
    }
    case 'messageVideo': {
      const caption = extractCaption(contentObj);
      const videoObj = tdGetObject(contentObj, 'video');
      const videoFile = tdGetObject(videoObj, 'video');
      contentDto.type = MessageContentType.VIDEO;
      contentDto.caption = caption;
      contentDto.quoteEntities = extractCaptionQuoteEntities(contentObj);
      contentDto.captionEntities = extractCaptionTextEntities(contentObj);
      contentDto.text = caption.length > 0 ? caption : '[Video]';
      contentDto.videoPath = extractLocalFilePath(videoFile);
      contentDto.videoFileId = extractFileId(videoFile);
      contentDto.videoThumbPath = extractThumbnailPath(videoObj);
      contentDto.videoMinithumb = tdGetString(tdGetObject(videoObj, 'minithumbnail'), 'data');
      contentDto.videoThumbFileId = extractThumbnailFileId(videoObj);
      contentDto.videoUniqueId = extractRemoteUniqueId(videoFile);
      contentDto.videoThumbUniqueId = extractThumbnailUniqueId(videoObj);
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
      contentDto.quoteEntities = extractCaptionQuoteEntities(contentObj);
      contentDto.captionEntities = extractCaptionTextEntities(contentObj);
      contentDto.text = caption.length > 0 ? caption : '[File]';
      contentDto.documentPath = extractLocalFilePath(documentFile);
      contentDto.documentFileId = extractFileId(documentFile);
      contentDto.documentUniqueId = extractRemoteUniqueId(documentFile);
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
      contentDto.quoteEntities = extractCaptionQuoteEntities(contentObj);
      contentDto.captionEntities = extractCaptionTextEntities(contentObj);
      contentDto.text = caption.length > 0 ? caption : '[Audio]';
      contentDto.audioPath = extractLocalFilePath(audioFile);
      const coverFile = tdGetObject(tdGetObject(audioObj, 'album_cover_thumbnail'), 'file');
      contentDto.audioCoverPath = extractLocalFilePath(coverFile);
      contentDto.audioCoverFileId = extractFileId(coverFile);
      contentDto.audioFileId = extractFileId(audioFile);
      contentDto.audioUniqueId = extractRemoteUniqueId(audioFile);
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
      contentDto.quoteEntities = extractCaptionQuoteEntities(contentObj);
      contentDto.captionEntities = extractCaptionTextEntities(contentObj);
      contentDto.text = caption.length > 0 ? caption : '[Voice message]';
      contentDto.voicePath = extractLocalFilePath(voiceFile);
      contentDto.voiceFileId = extractFileId(voiceFile);
      contentDto.voiceUniqueId = extractRemoteUniqueId(voiceFile);
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
      contentDto.stickerThumbnailPath = extractThumbnailPath(stickerObj);
      contentDto.stickerFileId = extractFileId(stickerFile);
      contentDto.stickerUniqueId = extractRemoteUniqueId(stickerFile);
      contentDto.stickerThumbUniqueId = extractThumbnailUniqueId(stickerObj);
      contentDto.stickerEmoji = tdGetString(stickerObj, 'emoji');
      contentDto.stickerWidth = tdGetNumber(stickerObj, 'width');
      contentDto.stickerHeight = tdGetNumber(stickerObj, 'height');
      contentDto.isAnimatedSticker = formatType === 'stickerFormatTgs';
      contentDto.isVideoSticker = formatType === 'stickerFormatWebm';
      contentDto.isPremiumSticker = tdGetBoolean(stickerObj, 'is_premium');
      contentDto.text = contentDto.stickerEmoji.length > 0 ? contentDto.stickerEmoji : '[Sticker]';
      break;
    }
    case 'messageLocation': {
      contentDto.type = MessageContentType.LOCATION;
      const loc = tdGetObject(contentObj, 'location');
      contentDto.locationLatitude = tdGetNumber(loc, 'latitude');
      contentDto.locationLongitude = tdGetNumber(loc, 'longitude');
      contentDto.text = '[Location]';
      break;
    }
    case 'messageVenue': {
      contentDto.type = MessageContentType.LOCATION;
      const venue = tdGetObject(contentObj, 'venue');
      const venueLoc = tdGetObject(venue, 'location');
      contentDto.locationLatitude = tdGetNumber(venueLoc, 'latitude');
      contentDto.locationLongitude = tdGetNumber(venueLoc, 'longitude');
      contentDto.locationVenueTitle = tdGetString(venue, 'title');
      contentDto.locationVenueAddress = tdGetString(venue, 'address');
      contentDto.text = contentDto.locationVenueTitle.length > 0 ? contentDto.locationVenueTitle : '[Venue]';
      break;
    }
    case 'messageContact': {
      contentDto.type = MessageContentType.CONTACT;
      const contact = tdGetObject(contentObj, 'contact');
      contentDto.contactFirstName = tdGetString(contact, 'first_name');
      contentDto.contactLastName = tdGetString(contact, 'last_name');
      contentDto.contactPhoneNumber = tdGetString(contact, 'phone_number');
      contentDto.contactUserId = tdGetNumber(contact, 'user_id');
      const contactName = (contentDto.contactFirstName + ' ' + contentDto.contactLastName).trim();
      contentDto.text = contactName.length > 0 ? contactName : contentDto.contactPhoneNumber;
      break;
    }
    case 'messagePoll': {
      contentDto.type = MessageContentType.POLL;
      const poll = tdGetObject(contentObj, 'poll');
      const questionObj = tdGetObject(poll, 'question');
      contentDto.pollQuestion = tdGetString(questionObj, 'text');
      contentDto.pollTotalVoterCount = tdGetNumber(poll, 'total_voter_count');
      contentDto.pollIsClosed = tdGetBoolean(poll, 'is_closed');
      contentDto.pollIsAnonymous = tdGetBoolean(poll, 'is_anonymous');
      const pollTypeObj = tdGetObject(poll, 'type');
      const pollTypeStr = tdGetString(pollTypeObj, '@type');
      contentDto.pollType = pollTypeStr === 'pollTypeQuiz' ? 'quiz' : 'regular';
      contentDto.text = contentDto.pollQuestion.length > 0 ? contentDto.pollQuestion : '[Poll]';
      // Parse options
      const options = tdGetArray(poll, 'options');
      for (let i = 0; i < options.length; i++) {
        const opt = options[i];
        const optDto = new PollOptionDto();
        const optTextObj = tdGetObject(opt, 'text');
        optDto.text = tdGetString(optTextObj, 'text');
        optDto.voterCount = tdGetNumber(opt, 'voter_count');
        optDto.votePercentage = tdGetNumber(opt, 'vote_percentage');
        optDto.isChosen = tdGetBoolean(opt, 'is_chosen');
        contentDto.pollOptions.push(optDto);
      }
      break;
    }
    case 'messageAnimation': {
      const caption = extractCaption(contentObj);
      const animationObj = tdGetObject(contentObj, 'animation');
      const animationFile = tdGetObject(animationObj, 'animation');
      contentDto.type = MessageContentType.ANIMATION;
      contentDto.caption = caption;
      contentDto.quoteEntities = extractCaptionQuoteEntities(contentObj);
      contentDto.captionEntities = extractCaptionTextEntities(contentObj);
      contentDto.text = caption.length > 0 ? caption : '[GIF]';
      contentDto.animationPath = extractLocalFilePath(animationFile);
      contentDto.animationFileId = extractFileId(animationFile);
      contentDto.animationUniqueId = extractRemoteUniqueId(animationFile);
      contentDto.videoThumbPath = extractThumbnailPath(animationObj);
      contentDto.videoMinithumb = tdGetString(tdGetObject(animationObj, 'minithumbnail'), 'data');
      contentDto.videoThumbFileId = extractThumbnailFileId(animationObj);
      contentDto.videoThumbUniqueId = extractThumbnailUniqueId(animationObj);
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
      contentDto.videoNoteUniqueId = extractRemoteUniqueId(videoNoteFile);
      contentDto.videoThumbPath = extractThumbnailPath(videoNoteObj);
      contentDto.videoMinithumb = tdGetString(tdGetObject(videoNoteObj, 'minithumbnail'), 'data');
      contentDto.videoThumbFileId = extractThumbnailFileId(videoNoteObj);
      contentDto.videoThumbUniqueId = extractThumbnailUniqueId(videoNoteObj);
      contentDto.videoNoteDuration = tdGetNumber(videoNoteObj, 'duration');
      contentDto.videoNoteLength = tdGetNumber(videoNoteObj, 'length');
      break;
    }
    case 'messageChatAddMembers': {
      contentDto.type = MessageContentType.SERVICE;
      contentDto.serviceType = contentType;
      contentDto.serviceUserIds = tdGetNumberArray(contentObj, 'member_user_ids');
      contentDto.text = `[${contentType}]`;
      break;
    }
    case 'messageChatDeleteMember': {
      contentDto.type = MessageContentType.SERVICE;
      contentDto.serviceType = contentType;
      contentDto.serviceUserIds = [tdGetNumber(contentObj, 'user_id')];
      contentDto.text = `[${contentType}]`;
      break;
    }
    case 'messageChatChangeTitle':
    case 'messageBasicGroupChatCreate':
    case 'messageSupergroupChatCreate': {
      contentDto.type = MessageContentType.SERVICE;
      contentDto.serviceType = contentType;
      contentDto.serviceTitle = tdGetString(contentObj, 'title');
      if (contentType === 'messageBasicGroupChatCreate') {
        contentDto.serviceUserIds = tdGetNumberArray(contentObj, 'member_user_ids');
      }
      contentDto.text = `[${contentType}]`;
      break;
    }
    case 'messageChatJoinByLink':
    case 'messageChatJoinByRequest':
    case 'messageChatChangePhoto':
    case 'messageChatDeletePhoto':
    case 'messagePinMessage':
    case 'messageContactRegistered':
    case 'messageVideoChatStarted':
    case 'messageVideoChatEnded': {
      contentDto.type = MessageContentType.SERVICE;
      contentDto.serviceType = contentType;
      contentDto.text = `[${contentType}]`;
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
  updatedMessage.replyToChatId = message.replyToChatId;
  updatedMessage.replyToMessageId = message.replyToMessageId;
  updatedMessage.replyIsQuote = message.replyIsQuote;
  updatedMessage.replyQuoteText = message.replyQuoteText;
  updatedMessage.replyQuoteOffset = message.replyQuoteOffset;

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
