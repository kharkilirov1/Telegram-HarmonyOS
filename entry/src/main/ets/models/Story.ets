// Story model — based on TDLib story objects
// Reference: Telegram iOS StoryItemV2, Android TL_stories

@ObservedV2
export class Story {
  @Trace id: number;
  @Trace chatId: number;
  @Trace date: number;
  @Trace expirationDate: number;
  @Trace isOutgoing: boolean;
  @Trace isPinned: boolean;

  // Content
  @Trace contentType: StoryContentType;
  @Trace photoUrl: string;
  @Trace videoUrl: string;
  @Trace caption: string;

  // View state
  @Trace isViewed: boolean;

  constructor(
    id: number = 0,
    chatId: number = 0,
    date: number = 0,
    expirationDate: number = 0,
    isOutgoing: boolean = false,
    isPinned: boolean = false,
    contentType: StoryContentType = StoryContentType.PHOTO,
    photoUrl: string = '',
    videoUrl: string = '',
    caption: string = '',
    isViewed: boolean = false
  ) {
    this.id = id;
    this.chatId = chatId;
    this.date = date;
    this.expirationDate = expirationDate;
    this.isOutgoing = isOutgoing;
    this.isPinned = isPinned;
    this.contentType = contentType;
    this.photoUrl = photoUrl;
    this.videoUrl = videoUrl;
    this.caption = caption;
    this.isViewed = isViewed;
  }
}

export enum StoryContentType {
  PHOTO = 'photo',
  VIDEO = 'video'
}

// Active stories for a chat (circle in the chat list)
@ObservedV2
export class ChatActiveStories {
  @Trace chatId: number;
  @Trace chatTitle: string;
  @Trace chatPhotoUrl: string;
  @Trace chatInitial: string;
  @Trace storyIds: number[];
  @Trace maxReadStoryId: number;
  @Trace hasUnread: boolean;
  @Trace order: string;

  constructor(
    chatId: number = 0,
    chatTitle: string = '',
    chatPhotoUrl: string = '',
    chatInitial: string = '',
    storyIds: number[] = [],
    maxReadStoryId: number = 0,
    order: string = '0'
  ) {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
    this.chatPhotoUrl = chatPhotoUrl;
    this.chatInitial = chatInitial;
    this.storyIds = storyIds;
    this.maxReadStoryId = maxReadStoryId;
    this.hasUnread = storyIds.length > 0 && storyIds[storyIds.length - 1] > maxReadStoryId;
    this.order = order;
  }
}
