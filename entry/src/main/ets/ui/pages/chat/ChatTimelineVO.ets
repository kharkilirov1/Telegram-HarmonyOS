import { AppState, Chat, Message, User } from '../../../core/model/AppState';
import { selectChatMessagesForChatView } from '../../../domain/selectors/messageSelectors';
import { compareInt64 } from '../../../core/utils/tdAccessors';
import { getString } from '../../../core/utils/AppResource';
import { TgMessageSendStatus } from '../../tg_ui/atoms/TgMessageMeta';

export type ChatTimelineEntryKind = 'date' | 'unread' | 'message';

export class ChatMessageRowVO {
  messageId: string = '0';
  text: string = '';
  isOutgoing: boolean = false;
  isEmojiOnly: boolean = false;
  timeText: string = '';
  sendStatus: TgMessageSendStatus = TgMessageSendStatus.None;
  forceBreakAll: boolean = false;

  showReplySnippet: boolean = false;
  replyAuthor: string = '';
  replyPreview: string = '';
  replyIsOutgoing: boolean = false;
  replyIsQuote: boolean = false;

  // Content routing (C.1-7)
  contentType: string = 'text';
  caption: string = '';

  // Photo
  photoPath: string = '';
  photoWidth: number = 0;
  photoHeight: number = 0;

  // Video / Animation
  videoThumbPath: string = '';
  videoPath: string = '';
  videoDuration: number = 0;
  videoWidth: number = 0;
  videoHeight: number = 0;

  // Document / Audio
  fileName: string = '';
  fileSize: number = 0;
  mimeType: string = '';

  // Voice
  voiceDuration: number = 0;
  voiceWaveform: string = '';
  isVoiceListened: boolean = false;

  // Sticker
  stickerPath: string = '';
  stickerWidth: number = 0;
  stickerHeight: number = 0;
  isAnimatedSticker: boolean = false;
  isVideoSticker: boolean = false;
}

export class ChatTimelineEntryVO {
  key: string = '';
  kind: ChatTimelineEntryKind = 'message';
  dateText: string = '';
  unreadText: string = '';
  message: ChatMessageRowVO = new ChatMessageRowVO();
}

function localizedString(resourceId: number, fallback: string): string {
  const value = getString(resourceId);
  return value.length > 0 ? value : fallback;
}

export class ChatTimelineBuildResult {
  chatId: number = 0;
  chatTitle: string = '';
  unreadEntryIndex: number = -1;
  entries: ChatTimelineEntryVO[] = [];
}

function padTwo(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function formatMessageTime(timestampSec: number): string {
  if (timestampSec <= 0) {
    return '';
  }
  const date = new Date(timestampSec * 1000);
  return padTwo(date.getHours()) + ':' + padTwo(date.getMinutes());
}

function dayKey(timestampSec: number): string {
  const date = new Date(timestampSec * 1000);
  return date.getFullYear().toString() + '-' + padTwo(date.getMonth() + 1) + '-' + padTwo(date.getDate());
}

function formatDateSeparatorLabel(timestampSec: number): string {
  const messageDate = new Date(timestampSec * 1000);
  const now = new Date();

  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const messageDayStart = new Date(messageDate.getFullYear(), messageDate.getMonth(), messageDate.getDate()).getTime();
  const dayDiff = Math.floor((todayStart - messageDayStart) / 86400000);

  if (dayDiff === 0) {
    return localizedString($r('app.string.today').id, 'Today');
  }
  if (dayDiff === 1) {
    return localizedString($r('app.string.yesterday').id, 'Yesterday');
  }

  if (dayDiff > 1 && dayDiff < 7) {
    return weekdayShort(messageDate.getDay());
  }

  return padTwo(messageDate.getDate()) + ' ' + monthShort(messageDate.getMonth());
}

function weekdayShort(day: number): string {
  switch (day) {
    case 0:
      return localizedString($r('app.string.weekday_sun').id, 'Sun');
    case 1:
      return localizedString($r('app.string.weekday_mon').id, 'Mon');
    case 2:
      return localizedString($r('app.string.weekday_tue').id, 'Tue');
    case 3:
      return localizedString($r('app.string.weekday_wed').id, 'Wed');
    case 4:
      return localizedString($r('app.string.weekday_thu').id, 'Thu');
    case 5:
      return localizedString($r('app.string.weekday_fri').id, 'Fri');
    case 6:
      return localizedString($r('app.string.weekday_sat').id, 'Sat');
    default:
      return localizedString($r('app.string.weekday_sun').id, 'Sun');
  }
}

function monthShort(month: number): string {
  switch (month) {
    case 0:
      return localizedString($r('app.string.month_jan').id, 'Jan');
    case 1:
      return localizedString($r('app.string.month_feb').id, 'Feb');
    case 2:
      return localizedString($r('app.string.month_mar').id, 'Mar');
    case 3:
      return localizedString($r('app.string.month_apr').id, 'Apr');
    case 4:
      return localizedString($r('app.string.month_may').id, 'May');
    case 5:
      return localizedString($r('app.string.month_jun').id, 'Jun');
    case 6:
      return localizedString($r('app.string.month_jul').id, 'Jul');
    case 7:
      return localizedString($r('app.string.month_aug').id, 'Aug');
    case 8:
      return localizedString($r('app.string.month_sep').id, 'Sep');
    case 9:
      return localizedString($r('app.string.month_oct').id, 'Oct');
    case 10:
      return localizedString($r('app.string.month_nov').id, 'Nov');
    case 11:
      return localizedString($r('app.string.month_dec').id, 'Dec');
    default:
      return localizedString($r('app.string.month_jan').id, 'Jan');
  }
}

function userDisplayName(user: User | undefined): string {
  if (!user) {
    return 'Unknown';
  }
  const fullName = (user.firstName + ' ' + user.lastName).trim();
  if (fullName.length > 0) {
    return fullName;
  }
  if (user.username.length > 0) {
    return '@' + user.username;
  }
  return 'Unknown';
}

function resolvePrivateChatTitle(chat: Chat, state: AppState): string {
  if (chat.peerUserId <= 0) {
    return chat.title;
  }
  const user = state.users.users.get(chat.peerUserId);
  const privateTitle = userDisplayName(user);
  if (privateTitle !== 'Unknown') {
    return privateTitle;
  }
  return chat.title;
}

function resolveSenderName(message: Message, state: AppState): string {
  if (message.senderId > 0) {
    const senderUser = state.users.users.get(message.senderId);
    return userDisplayName(senderUser);
  }
  if (message.senderChatId !== 0) {
    const senderChat = state.chats.chats.get(message.senderChatId);
    if (senderChat && senderChat.title.length > 0) {
      return senderChat.title;
    }
  }
  return message.isOutgoing ? 'You' : 'Unknown';
}

function resolveReplyPreview(messageById: Map<string, Message>, replyToMessageId: string): string {
  if (replyToMessageId === '0') {
    return '';
  }
  const replyMessage = messageById.get(replyToMessageId);
  if (!replyMessage) {
    return 'Message';
  }
  const text = replyMessage.content.text.trim();
  return text.length > 0 ? text : '[Unsupported message]';
}

function resolveMessageSendStatus(message: Message, chat: Chat): TgMessageSendStatus {
  if (!message.isOutgoing) {
    return TgMessageSendStatus.None;
  }
  if (message.sendStatus === 'pending') {
    return TgMessageSendStatus.Sending;
  }
  if (message.sendStatus === 'failed') {
    return TgMessageSendStatus.Failed;
  }
  if (message.isRead) {
    return TgMessageSendStatus.Read;
  }
  if (chat.lastReadOutboxMessageId !== '0' && compareInt64(message.id, chat.lastReadOutboxMessageId) <= 0) {
    return TgMessageSendStatus.Read;
  }
  return TgMessageSendStatus.Sent;
}

function isEmojiOnlyText(text: string): boolean {
  const trimmed = text.trim();
  if (trimmed.length === 0 || trimmed.length > 8) {
    return false;
  }
  return !(/[A-Za-z0-9\u0400-\u04FF]/.test(trimmed));
}

function shouldForceBreakAll(text: string): boolean {
  const words = text.split(/[\s\n]+/);
  for (const word of words) {
    if (word.length > 24) {
      return true;
    }
  }
  return false;
}

function firstUnreadIncomingIndex(messages: Message[], chat: Chat): number {
  if (chat.unreadCount <= 0) {
    return -1;
  }

  const lastReadInbox = chat.lastReadInboxMessageId;
  for (let i = 0; i < messages.length; i++) {
    const message = messages[i];
    if (message.isOutgoing) {
      continue;
    }
    if (lastReadInbox === '0') {
      return i;
    }
    if (compareInt64(message.id, lastReadInbox) > 0) {
      return i;
    }
  }
  return -1;
}

function buildMessageEntry(message: Message, chat: Chat, state: AppState, messageById: Map<string, Message>,
  sequence: number): ChatTimelineEntryVO {
  const row = new ChatMessageRowVO();
  row.messageId = message.id;
  row.isOutgoing = message.isOutgoing;
  row.timeText = formatMessageTime(message.timestamp);
  row.sendStatus = resolveMessageSendStatus(message, chat);

  const content = message.content;
  row.contentType = content.type;
  row.text = content.text;
  row.caption = content.caption;
  row.isEmojiOnly = content.type === 'text' && isEmojiOnlyText(row.text);
  row.forceBreakAll = content.type === 'text' && shouldForceBreakAll(row.text);

  // Photo
  row.photoPath = content.photoPath.length > 0 ? content.photoPath : content.photoThumbPath;
  row.photoWidth = content.photoWidth;
  row.photoHeight = content.photoHeight;

  // Video
  row.videoThumbPath = content.videoThumbPath.length > 0 ? content.videoThumbPath : content.videoPath;
  row.videoPath = content.videoPath;
  row.videoDuration = content.videoDuration;
  row.videoWidth = content.videoWidth;
  row.videoHeight = content.videoHeight;

  // Animation → video fields (router sends animation to TgVideoBubble)
  if (content.type === 'animation') {
    row.videoThumbPath = content.videoThumbPath.length > 0 ? content.videoThumbPath : content.animationPath;
    row.videoPath = content.animationPath;
    row.videoDuration = content.animationDuration;
    row.videoWidth = content.animationWidth;
    row.videoHeight = content.animationHeight;
  }

  // Video note → video fields (router sends videoNote to TgVideoBubble)
  if (content.type === 'videoNote') {
    row.videoThumbPath = content.videoNotePath;
    row.videoPath = content.videoNotePath;
    row.videoDuration = content.videoNoteDuration;
    row.videoWidth = content.videoNoteLength;
    row.videoHeight = content.videoNoteLength;
  }

  // Document
  row.fileName = content.fileName;
  row.fileSize = content.fileSize;
  row.mimeType = content.mimeType;

  // Audio → document fields (router sends audio to TgDocumentRow)
  if (content.type === 'audio') {
    row.fileName = content.audioTitle.length > 0 ? content.audioTitle : content.fileName;
  }

  // Voice
  row.voiceDuration = content.voiceDuration;
  row.voiceWaveform = content.voiceWaveform;
  row.isVoiceListened = content.isVoiceListened;

  // Sticker
  row.stickerPath = content.stickerPath;
  row.stickerWidth = content.stickerWidth;
  row.stickerHeight = content.stickerHeight;
  row.isAnimatedSticker = content.isAnimatedSticker;
  row.isVideoSticker = content.isVideoSticker;

  if (message.replyToMessageId !== '0') {
    row.showReplySnippet = true;
    row.replyPreview = resolveReplyPreview(messageById, message.replyToMessageId);
    const replyMessage = messageById.get(message.replyToMessageId);
    if (replyMessage) {
      row.replyAuthor = resolveSenderName(replyMessage, state);
      row.replyIsOutgoing = replyMessage.isOutgoing;
      row.replyIsQuote = row.replyPreview.length > 80;
    } else {
      row.replyAuthor = 'Reply';
      row.replyIsOutgoing = false;
      row.replyIsQuote = false;
    }
  }

  const entry = new ChatTimelineEntryVO();
  entry.kind = 'message';
  entry.key = 'msg_' + message.id + '_' + sequence.toString();
  entry.message = row;
  return entry;
}

export function buildChatTimeline(chatId: number, state: AppState): ChatTimelineBuildResult {
  const result = new ChatTimelineBuildResult();
  result.chatId = chatId;

  const chat = state.chats.chats.get(chatId);
  if (!chat) {
    return result;
  }
  result.chatTitle = chat.type === 'private' ? resolvePrivateChatTitle(chat, state) : chat.title;

  const messages = selectChatMessagesForChatView(chatId)(state);
  const messageMap = state.messages.messages.get(chatId) || new Map<string, Message>();
  const unreadStartIndex = firstUnreadIncomingIndex(messages, chat);

  let previousDay = '';
  for (let i = 0; i < messages.length; i++) {
    const message = messages[i];
    const currentDay = dayKey(message.timestamp);
    if (currentDay !== previousDay) {
      previousDay = currentDay;
      const dateEntry = new ChatTimelineEntryVO();
      dateEntry.kind = 'date';
      dateEntry.key = 'date_' + currentDay + '_' + message.id;
      dateEntry.dateText = formatDateSeparatorLabel(message.timestamp);
      result.entries.push(dateEntry);
    }

    if (i === unreadStartIndex) {
      const unreadEntry = new ChatTimelineEntryVO();
      unreadEntry.kind = 'unread';
      unreadEntry.key = 'unread_before_' + message.id + '_' + i.toString();
      unreadEntry.unreadText = localizedString($r('app.string.unread').id, 'Unread');
      result.unreadEntryIndex = result.entries.length;
      result.entries.push(unreadEntry);
    }

    result.entries.push(buildMessageEntry(message, chat, state, messageMap, i));
  }

  return result;
}
