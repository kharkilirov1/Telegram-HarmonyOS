@Observed
export class Message {
  id: number;
  chatId: number;
  senderId: number;
  senderName: string;
  text: string;
  date: number;
  isOutgoing: boolean;
  isRead: boolean;
  replyToMessageId: number;

  // Content type
  contentType: MessageContentType;
  photoUrl: string | null;
  fileName: string | null;

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
    this.text = text;
    this.date = date;
    this.isOutgoing = isOutgoing;
    this.isRead = isRead;
    this.replyToMessageId = replyToMessageId;
    this.contentType = contentType;
    this.photoUrl = photoUrl;
    this.fileName = fileName;
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
