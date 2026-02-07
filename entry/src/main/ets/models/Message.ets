@Observed
export class Message {
  id: number;
  chatId: number;
  senderId: number;
  senderName: string;
  senderPhotoUrl: string | null;
  text: string;
  date: number;
  isOutgoing: boolean;
  isRead: boolean;
  replyToMessageId: number;
  replyPreviewText: string;
  replyPreviewSenderName: string;
  forwardedFrom: string;

  // Content
  contentType: MessageContentType;
  photoUrl: string | null;
  photoFileId: number;
  fileName: string | null;
  voiceDuration: number;
  voiceWaveform: number[];
  videoDuration: number;
  stickerUrl: string | null;
  stickerFileId: number;

  constructor(
    id: number = 0,
    chatId: number = 0,
    senderId: number = 0,
    senderName: string = '',
    text: string = '',
    date: number = 0,
    isOutgoing: boolean = false,
    isRead: boolean = false,
    replyToMessageId: number = 0,
    contentType: MessageContentType = MessageContentType.TEXT,
    photoUrl: string | null = null,
    fileName: string | null = null
  ) {
    this.id = id;
    this.chatId = chatId;
    this.senderId = senderId;
    this.senderName = senderName;
    this.senderPhotoUrl = null;
    this.text = text;
    this.date = date;
    this.isOutgoing = isOutgoing;
    this.isRead = isRead;
    this.replyToMessageId = replyToMessageId;
    this.replyPreviewText = '';
    this.replyPreviewSenderName = '';
    this.forwardedFrom = '';
    this.contentType = contentType;
    this.photoUrl = photoUrl;
    this.photoFileId = 0;
    this.fileName = fileName;
    this.voiceDuration = 0;
    this.voiceWaveform = [];
    this.videoDuration = 0;
    this.stickerUrl = null;
    this.stickerFileId = 0;
  }
}

export enum MessageContentType {
  TEXT = 'text',
  PHOTO = 'photo',
  VIDEO = 'video',
  DOCUMENT = 'document',
  VOICE = 'voice',
  STICKER = 'sticker',
  ANIMATION = 'animation',
  UNSUPPORTED = 'unsupported'
}

export class GroupedMessage {
  message: Message;
  isFirstInGroup: boolean;
  isLastInGroup: boolean;

  constructor(message: Message, isFirst: boolean, isLast: boolean) {
    this.message = message;
    this.isFirstInGroup = isFirst;
    this.isLastInGroup = isLast;
  }
}

export class MessageDateGroup {
  dateLabel: string;
  messages: GroupedMessage[];

  constructor(dateLabel: string, messages: GroupedMessage[]) {
    this.dateLabel = dateLabel;
    this.messages = messages;
  }
}
