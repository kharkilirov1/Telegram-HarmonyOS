import { AppState, Chat, FileTransfer, Message, MessageQuoteEntity, TextEntity, User } from '../../../core/model/AppState';
import { selectChatMessagesForChatView } from '../../../domain/selectors/messageSelectors';
import { compareInt64 } from '../../../core/utils/tdAccessors';
import { getString } from '../../../core/utils/AppResource';
import { TgMessageSendStatus } from '../../tg_ui/atoms/TgMessageMeta';
import { fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'ChatTimelineVO';

// Convert sandbox path to file:// URI for ArkUI Image/Video components
function toFileUri(path: string): string {
  if (path.length === 0) return '';
  try {
    return fileUri.getUriFromPath(path);
  } catch (_e) {
    return '';
  }
}

export type ChatTimelineEntryKind = 'date' | 'unread' | 'message' | 'service';

// Telegram peer-name fallback palette (iOS default single-color set).
const SENDER_NAME_COLORS: string[] = [
  '#cc5049', '#d67722', '#955cdb', '#40a920',
  '#309eba', '#368ad1', '#c7508b'
];

function resolveAccentColorHex(accentColorId: number): string {
  if (accentColorId < 0) {
    return '';
  }
  return SENDER_NAME_COLORS[Math.abs(accentColorId) % SENDER_NAME_COLORS.length];
}

function hexFromRgbInt(rgb: number): string {
  const normalized = Math.max(0, Math.min(0xffffff, rgb >>> 0));
  return '#' + normalized.toString(16).padStart(6, '0');
}

function resolveAccentColorHexFromState(accentColorId: number, state: AppState): string {
  if (accentColorId < 0) {
    return '';
  }

  if (accentColorId >= 0 && accentColorId < SENDER_NAME_COLORS.length) {
    return resolveAccentColorHex(accentColorId);
  }

  const accentColor = state.accentColors.colors.get(accentColorId);
  if (!accentColor) {
    return '';
  }

  if (accentColor.builtInAccentColorId >= 0 && accentColor.builtInAccentColorId < SENDER_NAME_COLORS.length) {
    return resolveAccentColorHex(accentColor.builtInAccentColorId);
  }

  if (accentColor.darkThemeColors.length > 0) {
    return hexFromRgbInt(accentColor.darkThemeColors[0]);
  }

  if (accentColor.lightThemeColors.length > 0) {
    return hexFromRgbInt(accentColor.lightThemeColors[0]);
  }

  return '';
}

export function senderNameColor(senderId: number, state: AppState, senderChatId: number = 0): string {
  if (senderId > 0) {
    const senderUser = state.users.users.get(senderId);
    if (senderUser && senderUser.accentColorId >= 0) {
      const exactUserAccent = resolveAccentColorHexFromState(senderUser.accentColorId, state);
      if (exactUserAccent.length > 0) {
        return exactUserAccent;
      }
    }
  }

  if (senderChatId !== 0) {
    const senderChat = state.chats.chats.get(senderChatId);
    if (senderChat && senderChat.accentColorId >= 0) {
      const exactChatAccent = resolveAccentColorHexFromState(senderChat.accentColorId, state);
      if (exactChatAccent.length > 0) {
        return exactChatAccent;
      }
    }
  }

  return SENDER_NAME_COLORS[Math.abs(senderId > 0 ? senderId : senderChatId) % SENDER_NAME_COLORS.length];
}

export class PollOptionVO {
  text: string = '';
  voterCount: number = 0;
  votePercentage: number = 0;
  isChosen: boolean = false;
}

export class ChatMessageRowVO {
  messageId: string = '0';
  text: string = '';
  isOutgoing: boolean = false;
  isEmojiOnly: boolean = false;
  timeText: string = '';
  sendStatus: TgMessageSendStatus = TgMessageSendStatus.None;
  forceBreakAll: boolean = false;
  quoteOffsets: number[] = [];
  quoteLengths: number[] = [];
  quoteCollapsedFlags: boolean[] = [];

  // Sender name (group chats — incoming messages only)
  senderName: string = '';
  senderColorHex: string = '';
  showSenderName: boolean = false;

  showReplySnippet: boolean = false;
  replyAuthor: string = '';
  replyAuthorColorHex: string = '';
  replyPreview: string = '';
  replyIsOutgoing: boolean = false;
  replyIsQuote: boolean = false;
  replyHasThumbnail: boolean = false;
  replyThumbnailSrc: string = '';

  // Content routing (C.1-7)
  contentType: string = 'text';
  caption: string = '';
  captionQuoteOffsets: number[] = [];
  captionQuoteLengths: number[] = [];
  captionQuoteCollapsedFlags: boolean[] = [];

  // Rich text entities (bold, italic, code, links, mentions, etc.)
  textEntities: TextEntity[] = [];
  captionEntities: TextEntity[] = [];

  // Photo
  photoPath: string = '';
  photoMinithumb: string = ''; // data:image/jpeg;base64,... для blur-превью
  photoFileId: number = 0;
  hasLocalPhoto: boolean = false;
  isPhotoDownloading: boolean = false;
  photoDownloadProgress: number = -1;
  photoWidth: number = 0;
  photoHeight: number = 0;
  albumPhotoPaths: string[] = [];
  albumPhotoMinithumbs: string[] = [];
  albumPhotoFileIds: number[] = [];
  albumPhotoHasLocal: boolean[] = [];
  albumPhotoDownloading: boolean[] = [];
  albumPhotoDownloadProgress: number[] = [];
  albumPhotoWidths: number[] = [];
  albumPhotoHeights: number[] = [];

  // Video / Animation
  videoThumbPath: string = '';
  videoMinithumb: string = ''; // data:image/jpeg;base64,... для blur-превью
  videoPath: string = '';
  videoDuration: number = 0;
  isShortVideo: boolean = false;
  videoWidth: number = 0;
  videoHeight: number = 0;
  isVideoDownloading: boolean = false;
  videoDownloadProgress: number = -1;

  // Document / Audio
  documentPath: string = '';
  documentFileId: number = 0;
  isDocumentDownloading: boolean = false;
  documentDownloadProgress: number = -1;
  audioPath: string = '';
  audioFileId: number = 0;
  isAudioDownloading: boolean = false;
  audioDownloadProgress: number = -1;
  audioDuration: number = 0;
  audioTitle: string = '';
  audioPerformer: string = '';
  fileName: string = '';
  fileSize: number = 0;
  mimeType: string = '';

  // Voice
  voicePath: string = '';
  voiceFileId: number = 0;
  isVoiceDownloading: boolean = false;
  voiceDownloadProgress: number = -1;
  voiceDuration: number = 0;
  voiceWaveform: string = '';
  isVoiceListened: boolean = false;

  // On-demand download fileIds (documents, full video, audio)
  videoFileId: number = 0;

  // Sticker
  stickerPath: string = '';
  stickerThumbnailPath: string = '';
  stickerEmoji: string = '';
  stickerWidth: number = 0;
  stickerHeight: number = 0;
  isAnimatedSticker: boolean = false;
  isVideoSticker: boolean = false;

  // Contact
  contactFirstName: string = '';
  contactLastName: string = '';
  contactPhoneNumber: string = '';
  contactUserId: number = 0;

  // Location
  locationLatitude: number = 0;
  locationLongitude: number = 0;
  locationVenueTitle: string = '';
  locationVenueAddress: string = '';

  // Poll
  pollQuestion: string = '';
  pollTotalVoterCount: number = 0;
  pollIsClosed: boolean = false;
  pollIsAnonymous: boolean = true;
  pollType: string = 'regular';
  pollOptions: PollOptionVO[] = [];

  // Avatar (group chats, incoming messages)
  reserveAvatarLane: boolean = false;
  showAvatar: boolean = false;
  avatarImageSrc: string = '';
  avatarInitials: string = '';
  avatarColorIndex: number = 0;

  // Spacing: same sender = tight (iOS 2pt), different sender = loose (iOS 8pt)
  topSpacing: number = 8;
  groupingFlags: string = 'none';
}

export class ChatTimelineEntryVO {
  key: string = '';
  // Identity WITHOUT the render stamp: diff paths (same-order/append/prepend
  // detection) must treat a media-state change as the SAME row, while the
  // LazyForEach keyGenerator uses `key` (with stamp) so the item is rebuilt —
  // LazyForEach only rebuilds an item when its key changes (docs: Data Updates).
  stableKey: string = '';
  kind: ChatTimelineEntryKind = 'message';
  dateText: string = '';
  unreadText: string = '';
  serviceText: string = '';
  message: ChatMessageRowVO = new ChatMessageRowVO();
  // Search-hit flash: rows are plain VOs, so a repaint needs flag + key bump +
  // notifyDataChange; the flag resets when the builder recreates the entry
  searchFlash: boolean = false;
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

function serviceUserName(userId: number, state: AppState): string {
  const user = state.users.users.get(userId);
  return userDisplayName(user);
}

// Human-readable text for chat-event (service) messages, iOS-style centered line.
// Templates come from string.json with {name}/{target}/{title} placeholders.
function buildServiceMessageText(message: Message, state: AppState): string {
  const content = message.content;
  const actor = resolveSenderName(message, state);
  switch (content.serviceType) {
    case 'messageChatAddMembers': {
      const ids = content.serviceUserIds;
      const names = ids.map((id: number): string => serviceUserName(id, state)).join(', ');
      if (ids.length === 1 && ids[0] === message.senderId) {
        return localizedString($r('app.string.service_joined_group').id, '{name} joined the group')
          .replace('{name}', names);
      }
      return localizedString($r('app.string.service_added_members').id, '{name} added {target}')
        .replace('{name}', actor).replace('{target}', names);
    }
    case 'messageChatJoinByLink':
    case 'messageChatJoinByRequest':
      return localizedString($r('app.string.service_joined_by_link').id, '{name} joined the group via invite link')
        .replace('{name}', actor);
    case 'messageChatDeleteMember': {
      const removedId = content.serviceUserIds.length > 0 ? content.serviceUserIds[0] : 0;
      if (removedId === message.senderId || removedId === 0) {
        return localizedString($r('app.string.service_left_group').id, '{name} left the group')
          .replace('{name}', actor);
      }
      return localizedString($r('app.string.service_removed_member').id, '{name} removed {target}')
        .replace('{name}', actor).replace('{target}', serviceUserName(removedId, state));
    }
    case 'messageChatChangeTitle':
      return localizedString($r('app.string.service_title_changed').id, 'Chat name changed to "{title}"')
        .replace('{title}', content.serviceTitle);
    case 'messageBasicGroupChatCreate':
    case 'messageSupergroupChatCreate':
      return localizedString($r('app.string.service_group_created').id, 'Group "{title}" created')
        .replace('{title}', content.serviceTitle);
    case 'messageChatChangePhoto':
      return localizedString($r('app.string.service_photo_changed').id, '{name} changed the chat photo')
        .replace('{name}', actor);
    case 'messageChatDeletePhoto':
      return localizedString($r('app.string.service_photo_deleted').id, '{name} removed the chat photo')
        .replace('{name}', actor);
    case 'messagePinMessage':
      return localizedString($r('app.string.service_pinned_message').id, '{name} pinned a message')
        .replace('{name}', actor);
    case 'messageContactRegistered':
      return localizedString($r('app.string.service_contact_registered').id, '{name} joined Telegram')
        .replace('{name}', actor);
    case 'messageVideoChatStarted':
      return localizedString($r('app.string.service_video_chat_started').id, 'Video chat started');
    case 'messageVideoChatEnded':
      return localizedString($r('app.string.service_video_chat_ended').id, 'Video chat ended');
    default:
      return content.serviceType.length > 0 ? `[${content.serviceType}]` : '[Service]';
  }
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

function resolveReplyPreview(messageById: Map<string, Message>, replyToMessageId: string, replyQuoteText: string = ''): string {
  const trimmedQuote = replyQuoteText.trim();
  if (trimmedQuote.length > 0) {
    return trimmedQuote;
  }
  if (replyToMessageId === '0') {
    return '';
  }
  const replyMessage = messageById.get(replyToMessageId);
  if (!replyMessage) {
    return localizedString($r('app.string.message_action').id, 'Message');
  }
  const content = replyMessage.content;
  const text = content.text.trim();
  const caption = content.caption.trim();
  switch (content.type) {
    case 'text':
      return text.length > 0 ? text : localizedString($r('app.string.message_action').id, 'Message');
    case 'photo':
      return caption.length > 0 ? caption : localizedString($r('app.string.photo').id, 'Photo');
    case 'video':
      return caption.length > 0 ? caption : localizedString($r('app.string.video').id, 'Video');
    case 'animation':
      return caption.length > 0 ? caption : localizedString($r('app.string.gif').id, 'GIF');
    case 'voice':
      return localizedString($r('app.string.voice_message').id, 'Voice message');
    case 'videoNote':
      return localizedString($r('app.string.video_note').id, 'Video message');
    case 'sticker':
      return localizedString($r('app.string.sticker').id, 'Sticker');
    case 'audio':
      return content.audioTitle.trim().length > 0
        ? content.audioTitle.trim()
        : 'Audio';
    case 'document':
      return content.fileName.trim().length > 0
        ? content.fileName.trim()
        : localizedString($r('app.string.file_label').id, 'File');
    default:
      if (text.length > 0) {
        return text;
      }
      if (caption.length > 0) {
        return caption;
      }
      return localizedString($r('app.string.message_action').id, 'Message');
  }
}

function resolveReplyThumbnailSrc(messageById: Map<string, Message>, replyToMessageId: string): string {
  if (replyToMessageId === '0') {
    return '';
  }
  const replyMessage = messageById.get(replyToMessageId);
  if (!replyMessage) {
    return '';
  }
  const content = replyMessage.content;
  switch (content.type) {
    case 'photo':
      return toFileUri(content.photoPath.length > 0 ? content.photoPath : content.photoThumbPath);
    case 'video':
      return toFileUri(content.videoThumbPath.length > 0 ? content.videoThumbPath : content.videoPath);
    case 'animation':
      return toFileUri(content.videoThumbPath.length > 0 ? content.videoThumbPath : content.animationPath);
    case 'videoNote':
      return toFileUri(content.videoThumbPath.length > 0 ? content.videoThumbPath : content.videoNotePath);
    default:
      return '';
  }
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

class QuoteRangeVO {
  offset: number = 0;
  length: number = 0;
  isCollapsed: boolean = false;
}

function buildQuoteRanges(text: string, entities: MessageQuoteEntity[]): QuoteRangeVO[] {
  if (text.length === 0 || entities.length === 0) {
    return [];
  }

  const normalized: QuoteRangeVO[] = [];
  for (const entity of entities) {
    const start = Math.max(0, Math.min(text.length, entity.offset));
    const end = Math.max(start, Math.min(text.length, entity.offset + entity.length));
    if (end <= start) {
      continue;
    }
    const range = new QuoteRangeVO();
    range.offset = start;
    range.length = end - start;
    range.isCollapsed = entity.isCollapsed;
    normalized.push(range);
  }

  normalized.sort((a, b) => a.offset - b.offset);
  const merged: QuoteRangeVO[] = [];
  for (const range of normalized) {
    if (merged.length === 0) {
      merged.push(range);
      continue;
    }
    const last = merged[merged.length - 1];
    const lastEnd = last.offset + last.length;
    const rangeEnd = range.offset + range.length;
    if (range.offset <= lastEnd) {
      last.length = Math.max(lastEnd, rangeEnd) - last.offset;
      last.isCollapsed = last.isCollapsed || range.isCollapsed;
    } else {
      merged.push(range);
    }
  }

  return merged;
}

// WordBreak.BREAK_WORD already wraps overflowing long tokens char-by-char while
// keeping whole words intact (SDK enums.d.ts). BREAK_ALL is only better when the
// text is essentially one solid token (hash/link pasted alone) — applying it to
// mixed prose breaks ordinary words mid-word (witnessed in the File chat).
function shouldForceBreakAll(text: string): boolean {
  const trimmed = text.trim();
  if (trimmed.length === 0) {
    return false;
  }
  let longest = 0;
  const words = trimmed.split(/[\s\n]+/);
  for (const word of words) {
    if (word.length > longest) {
      longest = word.length;
    }
  }
  return longest > 24 && longest >= trimmed.length * 0.8;
}

function resolveTransfer(fileId: number, state: AppState): FileTransfer | undefined {
  if (fileId <= 0) {
    return undefined;
  }
  return state.files.transfers.get(fileId);
}

function completedTransferPath(fileId: number, state: AppState): string {
  if (fileId <= 0) {
    return '';
  }
  const transfer = state.files.transfers.get(fileId);
  if (transfer !== undefined && transfer.isDownloadingCompleted && transfer.localPath.length > 0) {
    return transfer.localPath;
  }
  return '';
}

// Живое обновление медиа: fileDownloaded не всегда матчится в контент по fileId
// (TDLib пере-нумерует file id между постановкой и завершением). files.transfers
// заполняется на каждый updateFile, а files.aliases связывает стабильный
// remote.unique_id со всеми известными fileId. Пустой контент-путь добираем:
// сначала прямо по fileId, затем по любому алиасу uniqueId — страница
// перерисовывается по transfers.
export function resolveContentPath(contentPath: string, fileId: number, state: AppState,
  uniqueId: string = ''): string {
  if (contentPath.length > 0) {
    return contentPath;
  }
  const direct = completedTransferPath(fileId, state);
  if (direct.length > 0) {
    return direct;
  }
  if (uniqueId.length > 0) {
    const aliasIds = state.files.aliases.get(uniqueId);
    if (aliasIds !== undefined) {
      for (const aliasId of aliasIds) {
        const aliased = completedTransferPath(aliasId, state);
        if (aliased.length > 0) {
          return aliased;
        }
      }
    }
  }
  return contentPath;
}

function resolveTransferTotalSize(transfer: FileTransfer | undefined): number {
  if (!transfer) {
    return 0;
  }
  const knownDownloaded = Math.max(
    transfer.downloadedSize,
    transfer.downloadOffset + transfer.downloadedPrefixSize
  );
  return Math.max(transfer.size, transfer.expectedSize, knownDownloaded);
}

function resolveTransferProgress(transfer: FileTransfer | undefined): number {
  if (!transfer) {
    return -1;
  }
  const total = resolveTransferTotalSize(transfer);
  if (total <= 0) {
    return -1;
  }
  const downloaded = Math.max(
    transfer.downloadedSize,
    transfer.downloadOffset + transfer.downloadedPrefixSize
  );
  return Math.max(0, Math.min(1, downloaded / total));
}

function isTransferActive(transfer: FileTransfer | undefined): boolean {
  return transfer !== undefined && transfer.isDownloadingActive && !transfer.isDownloadingCompleted;
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

// Channels are deliberately NOT group chats here: channel posts carry no sender
// name/avatar lane (iOS), and their consecutive grouping runs through the
// else-branch via effectiveSenderId (senderChatId-aware). With 'channel' included,
// the first post after every unread/date reset used to show a stray channel name.
function isGroupChat(chat: Chat): boolean {
  return chat.type === 'group' || chat.type === 'supergroup';
}

function shouldReserveAvatarLane(chat: Chat): boolean {
  return chat.type === 'group' || chat.type === 'supergroup';
}

function isTightlyGroupedWithPrevious(entry: ChatTimelineEntryVO): boolean {
  return entry.kind === 'message' && entry.message.topSpacing <= 2;
}

function updateBubbleGroupingFlags(entries: ChatTimelineEntryVO[]): void {
  for (let index = 0; index < entries.length; index++) {
    const entry = entries[index];
    if (entry.kind !== 'message') {
      continue;
    }

    const nextEntry = index + 1 < entries.length ? entries[index + 1] : undefined;
    const hasPrevious = isTightlyGroupedWithPrevious(entry);
    const hasNext = nextEntry !== undefined && isTightlyGroupedWithPrevious(nextEntry);

    if (hasPrevious && hasNext) {
      entry.message.groupingFlags = 'middle';
    } else if (hasNext) {
      entry.message.groupingFlags = 'top';
    } else if (hasPrevious) {
      entry.message.groupingFlags = 'bottom';
    } else {
      entry.message.groupingFlags = 'none';
    }
  }
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
  if (content.type !== 'text' && content.caption.trim().length > 0 && content.quoteEntities.length > 0) {
    const captionQuoteRanges = buildQuoteRanges(row.caption, content.quoteEntities);
    row.captionQuoteOffsets = captionQuoteRanges.map((range) => range.offset);
    row.captionQuoteLengths = captionQuoteRanges.map((range) => range.length);
    row.captionQuoteCollapsedFlags = captionQuoteRanges.map((range) => range.isCollapsed);
  }
  row.textEntities = content.textEntities;
  row.captionEntities = content.captionEntities;
  row.isEmojiOnly = content.type === 'text' && isEmojiOnlyText(row.text);
  row.forceBreakAll = content.type === 'text' && shouldForceBreakAll(row.text);
  if (content.type === 'text' && content.quoteEntities.length > 0) {
    const quoteRanges = buildQuoteRanges(row.text, content.quoteEntities);
    row.quoteOffsets = quoteRanges.map((range) => range.offset);
    row.quoteLengths = quoteRanges.map((range) => range.length);
    row.quoteCollapsedFlags = quoteRanges.map((range) => range.isCollapsed);
  }

  // Sender name for group chats (incoming only, hide if same sender as previous)
  if (isGroupChat(chat) && !message.isOutgoing) {
    const currentSenderId = message.senderId > 0 ? message.senderId : message.senderChatId;
    row.senderName = resolveSenderName(message, state);
    row.senderColorHex = senderNameColor(message.senderId, state, message.senderChatId);
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
    // Private chat, channel post, or outgoing: group consecutive messages from same sender.
    // Must mirror the prevSenderId update in the build loop (sender chats — channels /
    // anonymous admins — have senderId=0 and are tracked by senderChatId there).
    const effectiveSenderId = message.isOutgoing ? -2
      : (message.senderId > 0 ? message.senderId
        : (message.senderChatId !== 0 ? message.senderChatId : -3));
    row.topSpacing = (prevSenderId === effectiveSenderId) ? 2 : 8;
  }

  // Photo — convert sandbox path to file:// URI
  const photoTransfer = resolveTransfer(content.photoFileId, state);
  const resolvedPhotoFull = resolveContentPath(content.photoPath, content.photoFileId, state, content.photoUniqueId);
  const rawPhotoPath = resolvedPhotoFull.length > 0 ? resolvedPhotoFull
    : resolveContentPath(content.photoThumbPath, content.photoThumbFileId, state, content.photoThumbUniqueId);
  row.photoPath = toFileUri(rawPhotoPath);
  row.photoMinithumb = content.photoMinithumb.length > 0
    ? 'data:image/jpeg;base64,' + content.photoMinithumb : '';
  row.photoFileId = content.photoFileId;
  row.hasLocalPhoto = resolvedPhotoFull.length > 0;
  row.isPhotoDownloading = isTransferActive(photoTransfer);
  row.photoDownloadProgress = resolveTransferProgress(photoTransfer);
  row.photoWidth = content.photoWidth;
  row.photoHeight = content.photoHeight;

  // Video — thumbnail as file:// URI, full video path for playback
  const videoTransfer = resolveTransfer(content.videoFileId, state);
  const resolvedVideoThumb = resolveContentPath(content.videoThumbPath, content.videoThumbFileId, state, content.videoThumbUniqueId);
  const rawVideoThumb = resolvedVideoThumb.length > 0 ? resolvedVideoThumb : content.videoPath;
  row.videoThumbPath = toFileUri(rawVideoThumb);
  row.videoMinithumb = content.videoMinithumb.length > 0
    ? 'data:image/jpeg;base64,' + content.videoMinithumb : '';
  row.videoPath = toFileUri(resolveContentPath(content.videoPath, content.videoFileId, state, content.videoUniqueId));
  row.videoDuration = content.videoDuration;
  row.isShortVideo = content.videoDuration > 0 && content.videoDuration <= 30;
  row.videoWidth = content.videoWidth;
  row.videoHeight = content.videoHeight;
  row.videoFileId = content.videoFileId;
  row.isVideoDownloading = isTransferActive(videoTransfer);
  row.videoDownloadProgress = resolveTransferProgress(videoTransfer);

  // Animation → video fields (router sends animation to TgVideoBubble)
  if (content.type === 'animation') {
    const animationTransfer = resolveTransfer(content.animationFileId, state);
    const rawAnimThumb = content.videoThumbPath.length > 0 ? content.videoThumbPath : content.animationPath;
    row.videoThumbPath = toFileUri(rawAnimThumb);
    row.videoMinithumb = content.videoMinithumb.length > 0
      ? 'data:image/jpeg;base64,' + content.videoMinithumb : '';
    row.videoPath = toFileUri(resolveContentPath(content.animationPath, content.animationFileId, state, content.animationUniqueId));
    row.videoDuration = content.animationDuration;
    row.isShortVideo = true; // GIFs always inline
    row.videoWidth = content.animationWidth;
    row.videoHeight = content.animationHeight;
    row.videoFileId = content.animationFileId;
    row.isVideoDownloading = isTransferActive(animationTransfer);
    row.videoDownloadProgress = resolveTransferProgress(animationTransfer);
  }

  // Video note → video fields (router sends videoNote to TgVideoBubble)
  if (content.type === 'videoNote') {
    const videoNoteTransfer = resolveTransfer(content.videoNoteFileId, state);
    const rawVideoNoteThumb = content.videoThumbPath.length > 0 ? content.videoThumbPath : content.videoNotePath;
    row.videoThumbPath = toFileUri(rawVideoNoteThumb);
    row.videoMinithumb = content.videoMinithumb.length > 0
      ? 'data:image/jpeg;base64,' + content.videoMinithumb : '';
    row.videoPath = toFileUri(resolveContentPath(content.videoNotePath, content.videoNoteFileId, state, content.videoNoteUniqueId));
    row.videoDuration = content.videoNoteDuration;
    row.videoWidth = content.videoNoteLength;
    row.videoHeight = content.videoNoteLength;
    row.videoFileId = content.videoNoteFileId;
    row.isVideoDownloading = isTransferActive(videoNoteTransfer);
    row.videoDownloadProgress = resolveTransferProgress(videoNoteTransfer);
  }

  // Document
  const documentTransfer = resolveTransfer(content.documentFileId, state);
  row.documentPath = toFileUri(resolveContentPath(content.documentPath, content.documentFileId, state, content.documentUniqueId));
  row.documentFileId = content.documentFileId;
  row.isDocumentDownloading = isTransferActive(documentTransfer);
  row.documentDownloadProgress = resolveTransferProgress(documentTransfer);
  row.fileName = content.fileName;
  row.fileSize = content.fileSize;
  row.mimeType = content.mimeType;

  // Audio / music
  if (content.type === 'audio') {
    const audioTransfer = resolveTransfer(content.audioFileId, state);
    row.audioPath = resolveContentPath(content.audioPath, content.audioFileId, state, content.audioUniqueId);
    row.audioFileId = content.audioFileId;
    row.isAudioDownloading = isTransferActive(audioTransfer);
    row.audioDownloadProgress = resolveTransferProgress(audioTransfer);
    row.audioDuration = content.audioDuration;
    row.audioTitle = content.audioTitle;
    row.audioPerformer = content.audioPerformer;
    row.fileName = content.audioTitle.length > 0 ? content.audioTitle : content.fileName;
  }

  // Voice — convert path for playback
  const voiceTransfer = resolveTransfer(content.voiceFileId, state);
  row.voicePath = resolveContentPath(content.voicePath, content.voiceFileId, state, content.voiceUniqueId);
  row.voiceFileId = content.voiceFileId;
  row.isVoiceDownloading = isTransferActive(voiceTransfer);
  row.voiceDownloadProgress = resolveTransferProgress(voiceTransfer);
  row.voiceDuration = content.voiceDuration;
  row.voiceWaveform = content.voiceWaveform;
  row.isVoiceListened = content.isVoiceListened;

  // Sticker — convert path
  row.stickerPath = toFileUri(resolveContentPath(content.stickerPath, content.stickerFileId, state, content.stickerUniqueId));
  row.stickerThumbnailPath = toFileUri(content.stickerThumbnailPath);
  row.stickerEmoji = content.stickerEmoji;
  row.stickerWidth = content.stickerWidth;
  row.stickerHeight = content.stickerHeight;
  row.isAnimatedSticker = content.isAnimatedSticker;
  row.isVideoSticker = content.isVideoSticker;

  // Contact
  row.contactFirstName = content.contactFirstName;
  row.contactLastName = content.contactLastName;
  row.contactPhoneNumber = content.contactPhoneNumber;
  row.contactUserId = content.contactUserId;

  // Location
  row.locationLatitude = content.locationLatitude;
  row.locationLongitude = content.locationLongitude;
  row.locationVenueTitle = content.locationVenueTitle;
  row.locationVenueAddress = content.locationVenueAddress;

  // Poll
  row.pollQuestion = content.pollQuestion;
  row.pollTotalVoterCount = content.pollTotalVoterCount;
  row.pollIsClosed = content.pollIsClosed;
  row.pollIsAnonymous = content.pollIsAnonymous;
  row.pollType = content.pollType;
  row.pollOptions = content.pollOptions.map((o) => {
    const vo = new PollOptionVO();
    vo.text = o.text;
    vo.voterCount = o.voterCount;
    vo.votePercentage = o.votePercentage;
    vo.isChosen = o.isChosen;
    return vo;
  });

  if (message.replyToMessageId !== '0') {
    row.showReplySnippet = true;
    row.replyPreview = resolveReplyPreview(messageById, message.replyToMessageId, message.replyQuoteText);
    row.replyThumbnailSrc = resolveReplyThumbnailSrc(messageById, message.replyToMessageId);
    row.replyHasThumbnail = row.replyThumbnailSrc.length > 0;
    const replyMessage = messageById.get(message.replyToMessageId);
    if (replyMessage) {
      row.replyAuthor = resolveSenderName(replyMessage, state);
      row.replyAuthorColorHex = senderNameColor(replyMessage.senderId, state, replyMessage.senderChatId);
      row.replyIsOutgoing = replyMessage.isOutgoing;
      row.replyIsQuote = message.replyIsQuote;
    } else {
      row.replyAuthor = 'Reply';
      row.replyAuthorColorHex = '';
      row.replyIsOutgoing = false;
      row.replyIsQuote = false;
      row.replyHasThumbnail = false;
      row.replyThumbnailSrc = '';
    }
  }

  const entry = new ChatTimelineEntryVO();
  entry.kind = 'message';
  entry.stableKey = 'msg_' + message.id;
  // editDate in the key: an edited message must rebuild its row (lesson 84 —
  // text alone is not in the media stamp, so the key would not change)
  entry.key = entry.stableKey + '_s' + mediaRenderStamp(row).toString()
    + '_e' + message.editDate.toString();
  entry.message = row;
  return entry;
}

// Compact fingerprint of the row's mutable media state. Baked into the
// LazyForEach key: a completed download (path appears) or a progress step
// changes the key, forcing the item rebuild that actually refreshes the
// @ComponentV2 row (@Param values are frozen otherwise).
function mediaRenderStamp(row: ChatMessageRowVO): number {
  let albumFilled = 0;
  for (const p of row.albumPhotoPaths) {
    if (p.length > 0) {
      albumFilled++;
    }
  }
  const progressBuckets =
    Math.max(0, Math.floor(row.photoDownloadProgress * 10)) +
    Math.max(0, Math.floor(row.videoDownloadProgress * 10)) +
    Math.max(0, Math.floor(row.documentDownloadProgress * 10)) +
    Math.max(0, Math.floor(row.audioDownloadProgress * 10)) +
    Math.max(0, Math.floor(row.voiceDownloadProgress * 10));
  return (row.photoPath.length > 0 ? 1 : 0)
    + (row.videoPath.length > 0 ? 2 : 0)
    + (row.videoThumbPath.length > 0 ? 4 : 0)
    + (row.stickerPath.length > 0 ? 8 : 0)
    + (row.documentPath.length > 0 ? 16 : 0)
    + (row.audioPath.length > 0 ? 32 : 0)
    + (row.voicePath.length > 0 ? 64 : 0)
    + (row.hasLocalPhoto ? 128 : 0)
    + (row.isPhotoDownloading ? 256 : 0)
    + (row.isVideoDownloading ? 512 : 0)
    + (row.isDocumentDownloading ? 1024 : 0)
    + (row.isAudioDownloading ? 2048 : 0)
    + (row.isVoiceDownloading ? 4096 : 0)
    + albumFilled * 8192
    + progressBuckets * 131072;
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
  entry.message.albumPhotoMinithumbs = [];
  entry.message.albumPhotoFileIds = [];
  entry.message.albumPhotoHasLocal = [];
  entry.message.albumPhotoDownloading = [];
  entry.message.albumPhotoDownloadProgress = [];
  entry.message.albumPhotoWidths = [];
  entry.message.albumPhotoHeights = [];

  for (const message of albumMessages) {
    const content = message.content;
    const photoTransfer = resolveTransfer(content.photoFileId, state);
    const resolvedFull = resolveContentPath(content.photoPath, content.photoFileId, state, content.photoUniqueId);
    const rawPhotoPath = resolvedFull.length > 0 ? resolvedFull
      : resolveContentPath(content.photoThumbPath, content.photoThumbFileId, state, content.photoThumbUniqueId);
    const photoUri = toFileUri(rawPhotoPath);
    entry.message.albumPhotoPaths.push(photoUri);
    entry.message.albumPhotoMinithumbs.push(content.photoMinithumb.length > 0
      ? 'data:image/jpeg;base64,' + content.photoMinithumb : '');
    entry.message.albumPhotoFileIds.push(content.photoFileId);
    entry.message.albumPhotoHasLocal.push(resolvedFull.length > 0);
    entry.message.albumPhotoDownloading.push(isTransferActive(photoTransfer));
    entry.message.albumPhotoDownloadProgress.push(resolveTransferProgress(photoTransfer));
    entry.message.albumPhotoWidths.push(content.photoWidth);
    entry.message.albumPhotoHeights.push(content.photoHeight);
  }

  if (entry.message.albumPhotoPaths.length <= 1) {
    entry.message.contentType = 'photo';
    entry.message.photoPath = entry.message.albumPhotoPaths.length > 0 ? entry.message.albumPhotoPaths[0] : '';
    entry.message.photoFileId = entry.message.albumPhotoFileIds.length > 0 ? entry.message.albumPhotoFileIds[0] : 0;
    entry.message.hasLocalPhoto = entry.message.albumPhotoHasLocal.length > 0 ? entry.message.albumPhotoHasLocal[0] : false;
    entry.message.isPhotoDownloading = entry.message.albumPhotoDownloading.length > 0 ? entry.message.albumPhotoDownloading[0] : false;
    entry.message.photoDownloadProgress = entry.message.albumPhotoDownloadProgress.length > 0 ? entry.message.albumPhotoDownloadProgress[0] : -1;
    entry.message.photoWidth = entry.message.albumPhotoWidths.length > 0 ? entry.message.albumPhotoWidths[0] : 0;
    entry.message.photoHeight = entry.message.albumPhotoHeights.length > 0 ? entry.message.albumPhotoHeights[0] : 0;
  }

  // Album media fields were filled after buildMessageEntry computed the key —
  // recompute so the render stamp reflects the album paths/progress
  entry.key = entry.stableKey + '_s' + mediaRenderStamp(entry.message).toString()
    + '_e' + primaryMessage.editDate.toString();

  return entry;
}

export function buildChatTimeline(chatId: number, state: AppState, stickyLastReadMessageId: string = ''): ChatTimelineBuildResult {
  const result = new ChatTimelineBuildResult();
  result.chatId = chatId;

  const chat = state.chats.chats.get(chatId);
  if (!chat) {
    return result;
  }
  result.chatTitle = (chat.type === 'private' || chat.type === 'secret') ? resolvePrivateChatTitle(chat, state) : chat.title;

  const messages = selectChatMessagesForChatView(chatId)(state);
  const messageMap = state.messages.messages.get(chatId) || new Map<string, Message>();
  const unreadStartIndex = firstUnreadIncomingIndex(messages, chat, stickyLastReadMessageId);
  if (unreadStartIndex < 0 && (stickyLastReadMessageId.length > 0 || chat.unreadCount > 0) && messages.length > 0) {
    hilog.debug(DOMAIN, TAG,
      'unread divider skipped: sticky=%{public}s lastRead=%{public}s unread=%{public}d msgs=%{public}d first=%{public}s last=%{public}s',
      stickyLastReadMessageId, chat.lastReadInboxMessageId, chat.unreadCount, messages.length,
      messages[0].id, messages[messages.length - 1].id);
  }

  let previousDay = '';
  let prevSenderId = -1;
  // iOS merges consecutive messages only within a 10-minute window
  // (ChatMessageItemImpl.swift: abs(lhs - rhs) < 10 * 60 && sameAuthor)
  const SENDER_GROUP_MERGE_WINDOW_SEC = 600;
  let prevTimestamp = 0;
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
      dateEntry.stableKey = dateEntry.key;
      dateEntry.dateText = formatDateSeparatorLabel(message.timestamp);
      result.entries.push(dateEntry);
    }

    if (unreadStartIndex >= index && unreadStartIndex < index + groupCount) {
      prevSenderId = -1; // Reset sender after unread marker
      const unreadEntry = new ChatTimelineEntryVO();
      unreadEntry.kind = 'unread';
      unreadEntry.key = 'unread_before_' + message.id;
      unreadEntry.stableKey = unreadEntry.key;
      unreadEntry.unreadText = localizedString($r('app.string.unread').id, 'Unread');
      result.unreadEntryIndex = result.entries.length;
      result.entries.push(unreadEntry);
    }

    // Per-entry diagnostic log REMOVED (served the sticker/poll hunt): it fired
    // per message per rebuild — with a global `hilog -b D` that becomes a writev
    // storm and a THREAD_BLOCK_6S kill (6th freeze, 2026-07-08 17:49). Never
    // re-add per-entry logging; use targeted one-shot logs instead.

    if (prevTimestamp > 0 && message.timestamp - prevTimestamp >= SENDER_GROUP_MERGE_WINDOW_SEC) {
      prevSenderId = -1; // Time gap breaks the sender group (iOS 10-minute window)
    }

    // TDLib itself reports messageUnsupported for content newer than our tdlib
    // build — show it as a centered service line, not a bracketed bubble
    const isUnsupported = message.content.type === 'unknown'
      && message.content.text === '[messageUnsupported]';
    if (message.content.type === 'service' || isUnsupported) {
      const serviceEntry = new ChatTimelineEntryVO();
      serviceEntry.kind = 'service';
      serviceEntry.key = 'svc_' + message.id;
      serviceEntry.stableKey = serviceEntry.key;
      serviceEntry.serviceText = isUnsupported
        ? localizedString($r('app.string.service_unsupported').id, 'Unsupported message')
        : buildServiceMessageText(message, state);
      result.entries.push(serviceEntry);
      prevSenderId = -1; // Service line breaks the sender group (iOS pattern)
      prevTimestamp = message.timestamp;
      index += groupCount;
      continue;
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
    prevTimestamp = message.timestamp;
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

  updateBubbleGroupingFlags(result.entries);

  return result;
}
