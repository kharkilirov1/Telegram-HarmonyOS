@Observed
export class Chat {
  id: number;
  title: string;
  lastMessage: string;
  lastMessageDate: number;
  lastMessageSenderId: number;
  lastMessageSenderName: string;
  unreadCount: number;
  photo: string | null;
  photoFileId: number;
  isGroup: boolean;
  isChannel: boolean;
  isPinned: boolean;
  isMuted: boolean;
  isTyping: boolean;
  typingDescription: string;
  isUserOnline: boolean;
  order: string;

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
