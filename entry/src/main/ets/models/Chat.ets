@ObservedV2
export class Chat {
  @Trace id: number;
  @Trace title: string;
  @Trace lastMessage: string;
  @Trace lastMessageDate: number;
  @Trace lastMessageSenderId: number;
  @Trace lastMessageSenderName: string;
  @Trace unreadCount: number;
  @Trace photo: string | null;
  @Trace photoFileId: number;
  @Trace isGroup: boolean;
  @Trace isChannel: boolean;
  @Trace isPinned: boolean;
  @Trace isMuted: boolean;
  @Trace isTyping: boolean;
  @Trace typingDescription: string;
  @Trace isUserOnline: boolean;
  @Trace order: string;

  constructor(
    id: number = 0,
    title: string = '',
    lastMessage: string = '',
    lastMessageDate: number = 0,
    unreadCount: number = 0,
    photo: string | null = null,
    isGroup: boolean = false,
    isChannel: boolean = false,
    isPinned: boolean = false
  ) {
    this.id = id;
    this.title = title;
    this.lastMessage = lastMessage;
    this.lastMessageDate = lastMessageDate;
    this.lastMessageSenderId = 0;
    this.lastMessageSenderName = '';
    this.unreadCount = unreadCount;
    this.photo = photo;
    this.photoFileId = 0;
    this.isGroup = isGroup;
    this.isChannel = isChannel;
    this.isPinned = isPinned;
    this.isMuted = false;
    this.isTyping = false;
    this.typingDescription = '';
    this.isUserOnline = false;
    this.order = '0';
  }
}
