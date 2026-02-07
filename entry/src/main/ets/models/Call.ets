@ObservedV2
export class Call {
  @Trace id: number;
  @Trace chatId: number;
  @Trace userId: number;
  @Trace userName: string;
  @Trace userPhotoUrl: string | null;
  @Trace isOutgoing: boolean;
  @Trace isVideo: boolean;
  @Trace duration: number;
  @Trace date: number;
  @Trace discardReason: CallDiscardReason;

  constructor(
    id: number = 0,
    chatId: number = 0,
    userId: number = 0,
    userName: string = '',
    userPhotoUrl: string | null = null,
    isOutgoing: boolean = false,
    isVideo: boolean = false,
    duration: number = 0,
    date: number = 0,
    discardReason: CallDiscardReason = CallDiscardReason.MISSED
  ) {
    this.id = id;
    this.chatId = chatId;
    this.userId = userId;
    this.userName = userName;
    this.userPhotoUrl = userPhotoUrl;
    this.isOutgoing = isOutgoing;
    this.isVideo = isVideo;
    this.duration = duration;
    this.date = date;
    this.discardReason = discardReason;
  }

  get isMissed(): boolean {
    return this.discardReason === CallDiscardReason.MISSED ||
      this.discardReason === CallDiscardReason.DECLINED;
  }
}

export enum CallDiscardReason {
  EMPTY = 'empty',
  MISSED = 'missed',
  DECLINED = 'declined',
  DISCONNECTED = 'disconnected',
  HUNG_UP = 'hungUp'
}
