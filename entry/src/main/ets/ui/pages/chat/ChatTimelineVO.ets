import { AppState, Chat, Message, User } from '../../../core/model/AppState';
import { selectChatMessagesForChatView } from '../../../domain/selectors/messageSelectors';
import { compareInt64 } from '../../../core/utils/tdAccessors';
import { getString } from '../../../core/utils/AppResource';
import { TgMessageSendStatus } from '../../tg_ui/atoms/TgMessageMeta';
import { fileUri } from '@kit.CoreFileKit';

// Convert sandbox path to file:// URI for ArkUI Image/Video components
function toFileUri(path: string): string {
  if (path.length === 0) return '';
  try {
    return fileUri.getUriFromPath(path);
  } catch (_e) {
    return '';
  }
}

export type ChatTimelineEntryKind = 'date' | 'unread' | 'message';

// Sender name colors (Telegram iOS style — 8 colors by userId)
const SENDER_NAME_COLORS: string[] = [
  '#c03d33', '#4fad2d', '#d09306', '#168acd',
  '#8544d6', '#cd4073', '#2996ad', '#ce671b'
];

export function senderNameColor(senderId: number): string {
  return SENDER_NAME_COLORS[Math.abs(senderId) % SENDER_NAME_COLORS.length];
}

export class ChatMessageRowVO {
  messageId: string = '0';
  text: string = '';
  isOutgoing: boolean = false;
  isEmojiOnly: boolean = false;
  timeText: string = '';
  sendStatus: TgMessageSendStatus = TgMessageSendStatus.None;
  forceBreakAll: boolean = false;

  // Sender name (group chats — incoming messages only)
  senderName: string = '';
  senderColorHex: string = '';
  showSenderName: boolean = false;

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
  albumPhotoPaths: string[] = [];
  albumPhotoWidths: number[] = [];
  albumPhotoHeights: number[] = [];

  // Video / Animation
  videoThumbPath: string = '';
  videoPath: string = '';
  videoDuration: number = 0;
  videoWidth: number = 0;
  videoHeight: number = 0;

  // Document / Audio
  documentPath: string = '';
  documentFileId: number = 0;
  audioPath: string = '';
  audioFileId: number = 0;
  fileName: string = '';
  fileSize: number = 0;
  mimeType: string = '';

  // Voice
  voicePath: string = '';
  voiceFileId: number = 0;
  voiceDuration: number = 0;
  voiceWaveform: string = '';
  isVoiceListened: boolean = false;

  // On-demand download fileIds (documents, full video, audio)
  videoFileId: number = 0;

  // Sticker
  stickerPath: string = '';
  stickerWidth: number = 0;
  stickerHeight: number = 0;
  isAnimatedSticker: boolean = false;
  isVideoSticker: boolean = false;

  // Avatar (group chats, incoming messages)
  reserveAvatarLane: boolean = false;
  showAvatar: boolean = false;
  avatarImageSrc: string = '';
  avatarInitials: string = '';
  avatarColorIndex: number = 0;

  // Spacing: same sender = tight (iOS 2pt), different sender = loose (iOS 8pt)
  topSpacing: number = 8;
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

function computeAvatarInitials(name: string): string {
  const trimmed = name.trim();
  if (trimmed.length === 0) return '';
  const parts = trimmed.split(' ');
  if (parts.length >= 2 && parts[1].length > 0) {
    return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
  }
  return trimmed.charAt(0).toUpperCase();
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

function isPhotoAlbumCandidate(message: Message): boolean {
  return message.mediaAlbumId !== '0' && message.content.type === 'photo';
}

function countPhotoAlbumItems(messages: Message[], startIndex: number): number {
  if (startIndex < 0 || startIndex >= messages.length) {
    return 0;
  }
  const first = messages[startIndex];
  if (!isPhotoAlbumCandidate(first)) {
    return 0;
  }

  let count = 1;
  for (let i = startIndex + 1; i < messages.length; i++) {
    const next = messages[i];
    if (next.mediaAlbumId !== first.mediaAlbumId ||
      next.senderId !== first.senderId ||
      next.senderChatId !== first.senderChatId ||
      next.isOutgoing !== first.isOutgoing ||
      next.content.type !== 'photo') {
      break;
    }
    count++;
  }
  return count;
}

function resolveAlbumCaption(messages: Message[]): string {
  for (const message of messages) {
    const caption = message.content.caption.trim();
    if (caption.length > 0) {
      return caption;
    }
  }
  return '';
}

function firstUnreadIncomingIndex(messages: Message[], chat: Chat, stickyLastReadId: string = ''): number {
  // Use sticky ID if provided (survives markChatRead resetting unreadCount to 0).
  // Fall back to live chat data only when no sticky ID is available.
  const lastReadInbox = stickyLastReadId.length > 0 && stickyLastReadId !== '0'
    ? stickyLastReadId
    : chat.lastReadInboxMessageId;
  const hasUnread = stickyLastReadId.length > 0 && stickyLastReadId !== '0'
    ? true
    : chat.unreadCount > 0;

  if (!hasUnread) {
    return -1;
  }

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

function isGroupChat(chat: Chat): boolean {
  return chat.type === 'group' || chat.type === 'supergroup' || chat.type === 'channel';
}

function shouldReserveAvatarLane(chat: Chat): boolean {
  return chat.type === 'group' || chat.type === 'supergroup';
}

function buildMessageEntry(message: Message, chat: Chat, state: AppState, messageById: Map<string, Message>,
  prevSenderId: number = -1): ChatTimelineEntryVO {
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

  // Sender name for group chats (incoming only, hide if same sender as previous)
  if (isGroupChat(chat) && !message.isOutgoing) {
    const currentSenderId = message.senderId > 0 ? message.senderId : message.senderChatId;
    row.senderName = resolveSenderName(message, state);
    row.senderColorHex = senderNameColor(currentSenderId);
    row.reserveAvatarLane = shouldReserveAvatarLane(chat);
    // Show sender name only if different from previous message's sender
    row.showSenderName = prevSenderId !== currentSenderId;
    // iOS: same sender = 2pt spacing, different sender = 8pt
    row.topSpacing = (prevSenderId === currentSenderId) ? 2 : 8;

    // Avatar data (showAvatar set later in post-processing — last in sender group)
    row.avatarColorIndex = Math.abs(currentSenderId) % 8;
    if (message.senderId > 0) {
      const senderUser = state.users.users.get(message.senderId);
      if (senderUser) {
        row.avatarImageSrc = senderUser.photoSmall.length > 0 ? toFileUri(senderUser.photoSmall) : '';
        row.avatarInitials = computeAvatarInitials(userDisplayName(senderUser));
      }
    } else if (message.senderChatId !== 0) {
      const senderChat = state.chats.chats.get(message.senderChatId);
      if (senderChat) {
        row.avatarImageSrc = senderChat.photoSmall.length > 0 ? toFileUri(senderChat.photoSmall) : '';
        row.avatarInitials = computeAvatarInitials(senderChat.title);
      }
    }
  } else {
    // Private chat or outgoing: group consecutive messages from same direction
    const effectiveSenderId = message.isOutgoing ? -2 : (message.senderId > 0 ? message.senderId : -3);
    row.topSpacing = (prevSenderId === effectiveSenderId) ? 2 : 8;
  }

  // Photo — convert sandbox path to file:// URI
  const rawPhotoPath = content.photoPath.length > 0 ? content.photoPath : content.photoThumbPath;
  row.photoPath = toFileUri(rawPhotoPath);
  row.photoWidth = content.photoWidth;
  row.photoHeight = content.photoHeight;

  // Video — thumbnail as file:// URI, full video path for playback
  const rawVideoThumb = content.videoThumbPath.length > 0 ? content.videoThumbPath : content.videoPath;
  row.videoThumbPath = toFileUri(rawVideoThumb);
  row.videoPath = toFileUri(content.videoPath);
  row.videoDuration = content.videoDuration;
  row.videoWidth = content.videoWidth;
  row.videoHeight = content.videoHeight;
  row.videoFileId = content.videoFileId;

  // Animation → video fields (router sends animation to TgVideoBubble)
  if (content.type === 'animation') {
    const rawAnimThumb = content.videoThumbPath.length > 0 ? content.videoThumbPath : content.animationPath;
    row.videoThumbPath = toFileUri(rawAnimThumb);
    row.videoPath = toFileUri(content.animationPath);
    row.videoDuration = content.animationDuration;
    row.videoWidth = content.animationWidth;
    row.videoHeight = content.animationHeight;
    row.videoFileId = content.animationFileId;
  }

  // Video note → video fields (router sends videoNote to TgVideoBubble)
  if (content.type === 'videoNote') {
    const rawVideoNoteThumb = content.videoThumbPath.length > 0 ? content.videoThumbPath : content.videoNotePath;
    row.videoThumbPath = toFileUri(rawVideoNoteThumb);
    row.videoPath = toFileUri(content.videoNotePath);
    row.videoDuration = content.videoNoteDuration;
    row.videoWidth = content.videoNoteLength;
    row.videoHeight = content.videoNoteLength;
    row.videoFileId = content.videoNoteFileId;
  }

  // Document
  row.documentPath = toFileUri(content.documentPath);
  row.documentFileId = content.documentFileId;
  row.fileName = content.fileName;
  row.fileSize = content.fileSize;
  row.mimeType = content.mimeType;

  // Audio → document fields (router sends audio to TgDocumentRow)
  if (content.type === 'audio') {
    row.audioPath = toFileUri(content.audioPath);
    row.audioFileId = content.audioFileId;
    row.fileName = content.audioTitle.length > 0 ? content.audioTitle : content.fileName;
  }

  // Voice — convert path for playback
  row.voicePath = content.voicePath;
  row.voiceFileId = content.voiceFileId;
  row.voiceDuration = content.voiceDuration;
  row.voiceWaveform = content.voiceWaveform;
  row.isVoiceListened = content.isVoiceListened;

  // Sticker — convert path
  row.stickerPath = toFileUri(content.stickerPath);
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
  entry.key = 'msg_' + message.id;
  entry.message = row;
  return entry;
}

function buildPhotoAlbumEntry(albumMessages: Message[], chat: Chat, state: AppState,
  messageById: Map<string, Message>, prevSenderId: number = -1): ChatTimelineEntryVO {
  const primaryMessage = albumMessages[0];
  const entry = buildMessageEntry(primaryMessage, chat, state, messageById, prevSenderId);
  entry.message.contentType = 'photoAlbum';
  entry.message.caption = resolveAlbumCaption(albumMessages);
  entry.message.text = entry.message.caption.length > 0 ? entry.message.caption : '[Photo album]';
  entry.message.photoPath = '';
  entry.message.photoWidth = 0;
  entry.message.photoHeight = 0;
  entry.message.albumPhotoPaths = [];
  entry.message.albumPhotoWidths = [];
  entry.message.albumPhotoHeights = [];

  for (const message of albumMessages) {
    const content = message.content;
    const rawPhotoPath = content.photoPath.length > 0 ? content.photoPath : content.photoThumbPath;
    const photoUri = toFileUri(rawPhotoPath);
    entry.message.albumPhotoPaths.push(photoUri);
    entry.message.albumPhotoWidths.push(content.photoWidth);
    entry.message.albumPhotoHeights.push(content.photoHeight);
  }

  if (entry.message.albumPhotoPaths.length <= 1) {
    entry.message.contentType = 'photo';
    entry.message.photoPath = entry.message.albumPhotoPaths.length > 0 ? entry.message.albumPhotoPaths[0] : '';
    entry.message.photoWidth = entry.message.albumPhotoWidths.length > 0 ? entry.message.albumPhotoWidths[0] : 0;
    entry.message.photoHeight = entry.message.albumPhotoHeights.length > 0 ? entry.message.albumPhotoHeights[0] : 0;
  }

  return entry;
}

export function buildChatTimeline(chatId: number, state: AppState, stickyLastReadMessageId: string = ''): ChatTimelineBuildResult {
  const result = new ChatTimelineBuildResult();
  result.chatId = chatId;

  const chat = state.chats.chats.get(chatId);
  if (!chat) {
    return result;
  }
  result.chatTitle = chat.type === 'private' ? resolvePrivateChatTitle(chat, state) : chat.title;

  const messages = selectChatMessagesForChatView(chatId)(state);
  const messageMap = state.messages.messages.get(chatId) || new Map<string, Message>();
  const unreadStartIndex = firstUnreadIncomingIndex(messages, chat, stickyLastReadMessageId);

  let previousDay = '';
  let prevSenderId = -1;
  let index = 0;
  while (index < messages.length) {
    const message = messages[index];
    const albumCount = countPhotoAlbumItems(messages, index);
    const groupCount = albumCount > 1 ? albumCount : 1;
    const groupMessages = albumCount > 1
      ? messages.slice(index, index + groupCount)
      : [message];

    const currentDay = dayKey(message.timestamp);
    if (currentDay !== previousDay) {
      previousDay = currentDay;
      prevSenderId = -1; // Reset sender after date separator
      const dateEntry = new ChatTimelineEntryVO();
      dateEntry.kind = 'date';
      dateEntry.key = 'date_' + currentDay;
      dateEntry.dateText = formatDateSeparatorLabel(message.timestamp);
      result.entries.push(dateEntry);
    }

    if (unreadStartIndex >= index && unreadStartIndex < index + groupCount) {
      prevSenderId = -1; // Reset sender after unread marker
      const unreadEntry = new ChatTimelineEntryVO();
      unreadEntry.kind = 'unread';
      unreadEntry.key = 'unread_before_' + message.id;
      unreadEntry.unreadText = localizedString($r('app.string.unread').id, 'Unread');
      result.unreadEntryIndex = result.entries.length;
      result.entries.push(unreadEntry);
    }

    if (albumCount > 1) {
      result.entries.push(buildPhotoAlbumEntry(groupMessages, chat, state, messageMap, prevSenderId));
    } else {
      result.entries.push(buildMessageEntry(message, chat, state, messageMap, prevSenderId));
    }

    // Track sender for consecutive message grouping
    if (message.isOutgoing) {
      prevSenderId = -2; // All outgoing = same virtual sender
    } else {
      prevSenderId = message.senderId > 0 ? message.senderId : message.senderChatId;
    }
    index += groupCount;
  }

  // Post-processing: mark showAvatar on the LAST incoming message in each sender group (iOS pattern)
  if (isGroupChat(chat)) {
    for (let j = 0; j < result.entries.length; j++) {
      const entry = result.entries[j];
      if (entry.kind !== 'message' || entry.message.isOutgoing) continue;
      if (!entry.message.reserveAvatarLane) {
        entry.message.showAvatar = false;
        continue;
      }

      // Check if next message is from a different sender or is not a message
      const nextEntry = j + 1 < result.entries.length ? result.entries[j + 1] : undefined;
      const isLastInGroup = !nextEntry
        || nextEntry.kind !== 'message'
        || nextEntry.message.isOutgoing
        || nextEntry.message.showSenderName; // different sender triggers showSenderName

      entry.message.showAvatar = isLastInGroup;
    }
  }

  return result;
}
