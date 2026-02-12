export interface MessageReaction {
  emoji: string;
  count: number;
  isMine: boolean;
}

export interface PollOption {
  text: string;
  voterCount: number;
  votePercentage: number;
  isChosen: boolean;
}

@ObservedV2
export class Message {
  @Trace id: number;
  @Trace chatId: number;
  @Trace senderId: number;
  @Trace senderName: string;
  @Trace senderPhotoUrl: string | null;
  @Trace text: string;
  @Trace date: number;
  @Trace isOutgoing: boolean;
  @Trace isRead: boolean;
  @Trace replyToMessageId: number;
  @Trace replyPreviewText: string;
  @Trace replyPreviewSenderName: string;
  @Trace forwardedFrom: string;

  // Content
  @Trace contentType: MessageContentType;
  @Trace photoUrl: string | null;
  @Trace videoUrl: string | null;
  @Trace fileId: number;
  @Trace filePath: string | null;
  @Trace fileSize: number;
  @Trace photoFileId: number;
  @Trace fileName: string | null;
  @Trace voiceDuration: number;
  @Trace voiceWaveform: number[];
  @Trace videoDuration: number;
  @Trace stickerUrl: string | null;
  @Trace stickerFileId: number;

  // Video note (round video)
  @Trace videoNoteLength: number;
  @Trace videoNoteDuration: number;
  @Trace videoNoteFileId: number;

  // Poll
  @Trace pollId: string;
  @Trace pollQuestion: string;
  @Trace pollOptions: PollOption[];
  @Trace pollTotalVoterCount: number;
  @Trace pollIsClosed: boolean;
  @Trace pollIsAnonymous: boolean;
  @Trace pollType: string; // 'regular' | 'quiz'

  // Album
  @Trace mediaAlbumId: string;

  // Scheduling
  @Trace schedulingState: number; // 0 = none, timestamp = scheduled date
  @Trace selfDestructIn: number; // seconds, 0 = no self-destruct

  // View-once
  @Trace isViewOnce: boolean;

  // Spoiler
  @Trace hasSpoiler: boolean;

  // Contact
  @Trace contactFirstName: string;
  @Trace contactLastName: string;
  @Trace contactPhone: string;
  @Trace contactUserId: number;

  // Location
  @Trace locationLatitude: number;
  @Trace locationLongitude: number;
  @Trace locationLivePeriod: number; // 0 = static, >0 = live seconds

  // Audio (music)
  @Trace audioTitle: string;
  @Trace audioPerformer: string;
  @Trace audioDuration: number;
  @Trace audioFileId: number;

  // Call
  @Trace callDuration: number;
  @Trace callIsVideo: boolean;
  @Trace callDiscardReason: string; // 'missed' | 'declined' | 'hangup' | ''

  // Dice
  @Trace diceEmoji: string;
  @Trace diceValue: number;

  // Venue
  @Trace venueTitle: string;
  @Trace venueAddress: string;

  // Web page preview
  @Trace webPageUrl: string;
  @Trace webPageTitle: string;
  @Trace webPageDescription: string;
  @Trace webPageSiteName: string;

  // Edit indicator
  @Trace isEdited: boolean;
  @Trace editDate: number;

  // Reactions
  @Trace reactions: MessageReaction[];

  // Send state: '' = confirmed, 'sending' = pending, 'failed' = send failed
  @Trace sendState: string;

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
    this.videoUrl = null;
    this.fileId = 0;
    this.filePath = null;
    this.fileSize = 0;
    this.photoFileId = 0;
    this.fileName = fileName;
    this.voiceDuration = 0;
    this.voiceWaveform = [];
    this.videoDuration = 0;
    this.stickerUrl = null;
    this.stickerFileId = 0;
    this.videoNoteLength = 0;
    this.videoNoteDuration = 0;
    this.videoNoteFileId = 0;
    this.pollId = '';
    this.pollQuestion = '';
    this.pollOptions = [];
    this.pollTotalVoterCount = 0;
    this.pollIsClosed = false;
    this.pollIsAnonymous = true;
    this.pollType = 'regular';
    this.mediaAlbumId = '';
    this.schedulingState = 0;
    this.selfDestructIn = 0;
    this.isViewOnce = false;
    this.hasSpoiler = false;
    this.contactFirstName = '';
    this.contactLastName = '';
    this.contactPhone = '';
    this.contactUserId = 0;
    this.locationLatitude = 0;
    this.locationLongitude = 0;
    this.locationLivePeriod = 0;
    this.audioTitle = '';
    this.audioPerformer = '';
    this.audioDuration = 0;
    this.audioFileId = 0;
    this.callDuration = 0;
    this.callIsVideo = false;
    this.callDiscardReason = '';
    this.diceEmoji = '';
    this.diceValue = 0;
    this.venueTitle = '';
    this.venueAddress = '';
    this.webPageUrl = '';
    this.webPageTitle = '';
    this.webPageDescription = '';
    this.webPageSiteName = '';
    this.isEdited = false;
    this.editDate = 0;
    this.reactions = [];
    this.sendState = '';
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
  VIDEO_NOTE = 'video_note',
  POLL = 'poll',
  CONTACT = 'contact',
  LOCATION = 'location',
  LIVE_LOCATION = 'live_location',
  AUDIO = 'audio',
  CALL = 'call',
  DICE = 'dice',
  VENUE = 'venue',
  GAME = 'game',
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
