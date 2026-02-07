@Observed
export class Chat {
  id: number;
  title: string;
  lastMessage: string;
  lastMessageDate: number;
  unreadCount: number;
  photo: string | null;
  isGroup: boolean;
  isChannel: boolean;
  isPinned: boolean;

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
    this.unreadCount = unreadCount;
    this.photo = photo;
    this.isGroup = isGroup;
    this.isChannel = isChannel;
    this.isPinned = isPinned;
  }
}
