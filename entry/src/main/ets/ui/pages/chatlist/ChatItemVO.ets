// ChatItemVO — View Object for chat list cell rendering
// Built from AppState Chat model, contains only data needed for UI

import { AppState, Chat, Message } from '../../../core/model/AppState';
import { compareInt64 } from '../../../core/utils/tdAccessors';
import { getString } from '../../../core/utils/AppResource';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { fileUri } from '@kit.CoreFileKit';

// Convert sandbox path to file:// URI for Image component
function toFileUri(path: string): string {
  if (path.length === 0) return '';
  try {
    return fileUri.getUriFromPath(path);
  } catch (_e) {
    return '';
  }
}

const AVATAR_COLORS: Resource[] = [
  TgUiTokens.AVATAR_COLOR_1,
  TgUiTokens.AVATAR_COLOR_2,
  TgUiTokens.AVATAR_COLOR_3,
  TgUiTokens.AVATAR_COLOR_4,
  TgUiTokens.AVATAR_COLOR_5,
  TgUiTokens.AVATAR_COLOR_6,
  TgUiTokens.AVATAR_COLOR_7,
  TgUiTokens.AVATAR_COLOR_8
];

export class ChatItemVO {
  chatId: number = 0;
  title: string = '';
  initials: string = '';
  avatarColor: Resource = TgUiTokens.AVATAR_COLOR_5;
  avatarImagePath: string = '';
  avatarOnline: boolean = false;
  isVerified: boolean = false;
  lastMessage: string = '';
  formattedTime: string = '';
  unreadCount: number = 0;
  isPinned: boolean = false;
  isLastPinned: boolean = false;
  isMuted: boolean = false;
  sendStatus: 'none' | 'pending' | 'sent' | 'read' | 'failed' = 'none';
  isGroup: boolean = false;
  isTyping: boolean = false;
  typingText: string = '';
  isDraft: boolean = false;
  hasMention: boolean = false;
  isScam: boolean = false;
  isFake: boolean = false;
  isSecret: boolean = false;
  previewPrefix: string = '';
  previewPrefixStyle: 'none' | 'draft' | 'author' = 'none';
}

export function shouldShowAvatarOnline(status: string, isBot: boolean): boolean {
  return status === 'online' && !isBot;
}

function resolvePrivateTitle(firstName: string, lastName: string, username: string, phoneNumber: string): string {
  const fullName = (firstName + ' ' + lastName).trim();
  if (fullName.length > 0) {
    return fullName;
  }
  if (username.length > 0) {
    return '@' + username;
  }
  if (phoneNumber.length > 0) {
    return phoneNumber;
  }
  return '';
}

function getInitials(title: string): string {
  if (!title) return '?';
  const trimmed = title.trim();
  if (trimmed.length === 0) return '?';

  // Split by spaces, take first char of first and last word
  const spaceIdx = trimmed.indexOf(' ');
  if (spaceIdx > 0 && spaceIdx < trimmed.length - 1) {
    return (trimmed.charAt(0) + trimmed.charAt(spaceIdx + 1)).toUpperCase();
  }
  return trimmed.charAt(0).toUpperCase();
}

function getAvatarColor(chatId: number): Resource {
  const idx = Math.abs(chatId) % AVATAR_COLORS.length;
  return AVATAR_COLORS[idx];
}

function padTwo(n: number): string {
  return n < 10 ? '0' + n.toString() : n.toString();
}

function localizedString(resourceId: number, fallback: string): string {
  const localized = getString(resourceId);
  return localized.length > 0 ? localized : fallback;
}

export type ChatPreviewKind = 'photo' | 'album' | 'video' | 'gif' | 'videoNote' | 'voice' | 'file' | 'audio' |
  'sticker' | 'location' | 'contact' | 'poll' | 'unsupported' | 'message' | 'joinedGroup' | 'leftGroup' |
  'pinnedMessage' | 'chatUpdated' | 'joinedTelegram' | 'serviceMessage' | 'typing' | 'recordingVideo' |
  'sendingVideo' | 'recordingVoice' | 'sendingVoice' | 'sendingPhoto' | 'sendingFile' | 'choosingSticker' |
  'recordingVideoNote' | 'sendingVideoNote';

function localizedPreviewKind(kind: ChatPreviewKind): string {
  switch (kind) {
    case 'photo':
      return '📷 ' + localizedString($r('app.string.photo').id, 'Photo');
    case 'album':
      return '📷 ' + localizedString($r('app.string.chat_preview_album').id, 'Album');
    case 'video':
      return '📹 ' + localizedString($r('app.string.video').id, 'Video');
    case 'gif':
      return '🎬 ' + localizedString($r('app.string.gif').id, 'GIF');
    case 'videoNote':
      return '📹 ' + localizedString($r('app.string.video_note').id, 'Video message');
    case 'voice':
      return '🎤 ' + localizedString($r('app.string.voice_message').id, 'Voice message');
    case 'file':
      return '📎 ' + localizedString($r('app.string.file_label').id, 'File');
    case 'audio':
      return '🎵 ' + localizedString($r('app.string.chat_preview_audio').id, 'Audio');
    case 'sticker':
      return '🧩 ' + localizedString($r('app.string.sticker').id, 'Sticker');
    case 'location':
      return '📍 ' + localizedString($r('app.string.location_label').id, 'Location');
    case 'contact':
      return '👤 ' + localizedString($r('app.string.contact_label').id, 'Contact');
    case 'poll':
      return '📊 ' + localizedString($r('app.string.poll').id, 'Poll');
    case 'unsupported':
      return localizedString($r('app.string.service_unsupported').id, 'Unsupported message');
    case 'joinedGroup':
      return localizedString($r('app.string.chat_preview_joined_group').id, 'Joined the group');
    case 'leftGroup':
      return localizedString($r('app.string.chat_preview_left_group').id, 'Left the group');
    case 'pinnedMessage':
      return '📌 ' + localizedString($r('app.string.pinned_message').id, 'Pinned message');
    case 'chatUpdated':
      return localizedString($r('app.string.chat_preview_chat_updated').id, 'Chat updated');
    case 'joinedTelegram':
      return localizedString($r('app.string.chat_preview_joined_telegram').id, 'Joined Telegram');
    case 'serviceMessage':
      return localizedString($r('app.string.chat_preview_service_message').id, 'Service message');
    case 'recordingVideo':
      return localizedString($r('app.string.chat_preview_recording_video').id, 'recording video...');
    case 'sendingVideo':
      return localizedString($r('app.string.chat_preview_sending_video').id, 'sending video...');
    case 'recordingVoice':
      return localizedString($r('app.string.chat_preview_recording_voice').id, 'recording voice...');
    case 'sendingVoice':
      return localizedString($r('app.string.chat_preview_sending_voice').id, 'sending voice...');
    case 'sendingPhoto':
      return localizedString($r('app.string.chat_preview_sending_photo').id, 'sending photo...');
    case 'sendingFile':
      return localizedString($r('app.string.chat_preview_sending_file').id, 'sending file...');
    case 'choosingSticker':
      return localizedString($r('app.string.chat_preview_choosing_sticker').id, 'choosing sticker...');
    case 'recordingVideoNote':
      return localizedString($r('app.string.chat_preview_recording_video_note').id, 'recording video message...');
    case 'sendingVideoNote':
      return localizedString($r('app.string.chat_preview_sending_video_note').id, 'sending video message...');
    case 'typing':
      return localizedString($r('app.string.typing').id, 'typing') + '...';
    case 'message':
    default:
      return localizedString($r('app.string.message_placeholder').id, 'Message');
  }
}

export function chatPreviewKindFromTypingAction(actionType: string): ChatPreviewKind {
  switch (actionType) {
    case 'recordingVideo': return 'recordingVideo';
    case 'uploadingVideo': return 'sendingVideo';
    case 'recordingVoice': return 'recordingVoice';
    case 'uploadingVoice': return 'sendingVoice';
    case 'uploadingPhoto': return 'sendingPhoto';
    case 'uploadingDocument': return 'sendingFile';
    case 'choosingSticker': return 'choosingSticker';
    case 'recordingVideoNote': return 'recordingVideoNote';
    case 'uploadingVideoNote': return 'sendingVideoNote';
    case 'typing':
    default:
      return 'typing';
  }
}

function typingActionLabel(actionType: string): string {
  return localizedPreviewKind(chatPreviewKindFromTypingAction(actionType));
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

function formatMessageTime(timestampSec: number): string {
  if (timestampSec === 0) return '';

  const msgDate = new Date(timestampSec * 1000);
  const now = new Date();

  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const msgDayStart = new Date(msgDate.getFullYear(), msgDate.getMonth(), msgDate.getDate()).getTime();
  const diffDays = Math.floor((todayStart - msgDayStart) / 86400000);

  if (diffDays === 0) {
    // Today: HH:mm
    return padTwo(msgDate.getHours()) + ':' + padTwo(msgDate.getMinutes());
  }
  if (diffDays === 1) {
    return localizedString($r('app.string.yesterday').id, 'Yesterday');
  }
  if (diffDays < 7) {
    return weekdayShort(msgDate.getDay());
  }
  // Older: dd.MM (same year) or dd.MM.yy (different year)
  if (msgDate.getFullYear() === now.getFullYear()) {
    return padTwo(msgDate.getDate()) + '.' + padTwo(msgDate.getMonth() + 1);
  }
  return padTwo(msgDate.getDate()) + '.' + padTwo(msgDate.getMonth() + 1) + '.' +
    padTwo(msgDate.getFullYear() % 100);
}

class LastMessageSnapshot {
  id: string = '0';
  text: string = '';
  timestamp: number = 0;
  senderId: number = 0;
  isOutgoing: boolean = false;
}

function collapsePreviewWhitespace(text: string): string {
  return text.replace(/\s+/g, ' ').trim();
}

function previewTextScore(text: string): number {
  const normalized = collapsePreviewWhitespace(text);
  if (normalized.length === 0) {
    return 0;
  }
  if (normalized.startsWith('[') && normalized.endsWith(']')) {
    return 1;
  }
  return 2;
}

function isSameMessageSnapshot(lhs: LastMessageSnapshot, rhs: LastMessageSnapshot): boolean {
  return lhs.timestamp === rhs.timestamp && lhs.id === rhs.id;
}

export function chatPreviewKindFromContentType(contentType: string): ChatPreviewKind {
  switch (contentType) {
    case 'photo': return 'photo';
    case 'video': return 'video';
    case 'document': return 'file';
    case 'audio': return 'audio';
    case 'voice': return 'voice';
    case 'sticker': return 'sticker';
    case 'animation': return 'gif';
    case 'videoNote': return 'videoNote';
    case 'location': return 'location';
    case 'contact': return 'contact';
    case 'poll': return 'poll';
    case 'unsupported': return 'unsupported';
    default:
      return 'message';
  }
}

function fallbackMessageTextForType(contentType: string): string {
  return localizedPreviewKind(chatPreviewKindFromContentType(contentType));
}

// ChatDto builds last-message previews as '[X]' (contentType minus the 'message'
// prefix) — map the known service/unsupported placeholders to human text here,
// on the UI layer, keeping the DTO locale-free.
// Telegram-style media previews ('[Photo]' → '📷 Photo')
export function chatPreviewKindFromBracket(text: string): ChatPreviewKind | '' {
  if (!text.startsWith('[') || !text.endsWith(']')) {
    return '';
  }
  const inner = text.substring(1, text.length - 1);
  switch (inner) {
    case 'Photo': return 'photo';
    case 'Photo album': return 'album';
    case 'Video': return 'video';
    case 'GIF': return 'gif';
    case 'Video message': return 'videoNote';
    case 'Voice message': return 'voice';
    case 'File': return 'file';
    case 'Audio': return 'audio';
    case 'Sticker': return 'sticker';
    case 'Location':
    case 'Venue':
      return 'location';
    case 'Poll': return 'poll';
    case 'Unsupported': return 'unsupported';
    default:
      return chatPreviewKindFromServiceType('message' + inner);
  }
}

export function humanizeBracketPreview(text: string): string {
  const kind = chatPreviewKindFromBracket(text);
  return kind.length > 0 ? localizedPreviewKind(kind as ChatPreviewKind) : text;
}

// Human preview for chat-event messages instead of the raw [messageX] placeholder
export function chatPreviewKindFromServiceType(serviceType: string): ChatPreviewKind | '' {
  switch (serviceType) {
    case 'messageChatAddMembers':
    case 'messageChatJoinByLink':
    case 'messageChatJoinByRequest':
      return 'joinedGroup';
    case 'messageChatDeleteMember':
      return 'leftGroup';
    case 'messagePinMessage':
      return 'pinnedMessage';
    case 'messageChatChangeTitle':
    case 'messageChatChangePhoto':
    case 'messageChatDeletePhoto':
      return 'chatUpdated';
    case 'messageContactRegistered':
      return 'joinedTelegram';
    default:
      return '';
  }
}

function serviceMessagePreview(serviceType: string): string {
  const kind = chatPreviewKindFromServiceType(serviceType);
  return localizedPreviewKind(kind.length > 0 ? kind as ChatPreviewKind : 'serviceMessage');
}

function snapshotFromMessage(message: Message): LastMessageSnapshot {
  const snapshot = new LastMessageSnapshot();
  snapshot.id = message.id;
  snapshot.timestamp = message.timestamp;
  snapshot.senderId = message.senderId;
  snapshot.isOutgoing = message.isOutgoing;
  const text = collapsePreviewWhitespace(message.content.text);
  if (message.content.type === 'service') {
    snapshot.text = serviceMessagePreview(message.content.serviceType);
  } else if (text === '[messageUnsupported]') {
    snapshot.text = fallbackMessageTextForType('unsupported');
  } else {
    snapshot.text = text.length > 0 ? text : fallbackMessageTextForType(message.content.type);
  }
  return snapshot;
}

function isSnapshotNewer(current: LastMessageSnapshot, next: LastMessageSnapshot): boolean {
  if (next.timestamp !== current.timestamp) {
    return next.timestamp > current.timestamp;
  }
  return compareInt64(next.id, current.id) > 0;
}

function resolveLastMessageSnapshot(chat: Chat, state: AppState): LastMessageSnapshot {
  const fromChat = new LastMessageSnapshot();
  if (chat.lastMessage) {
    fromChat.id = chat.lastMessage.id;
    fromChat.text = humanizeBracketPreview(collapsePreviewWhitespace(chat.lastMessage.text));
    fromChat.timestamp = chat.lastMessage.timestamp;
  }

  const chatMessages = state.messages.messages.get(chat.id);
  if (!chatMessages || chatMessages.size === 0) {
    return fromChat;
  }

  let newestFromMessages: LastMessageSnapshot | undefined = undefined;
  for (const message of chatMessages.values()) {
    const candidate = snapshotFromMessage(message);
    if (newestFromMessages === undefined || isSnapshotNewer(newestFromMessages, candidate)) {
      newestFromMessages = candidate;
    }
  }

  if (newestFromMessages === undefined) {
    return fromChat;
  }

  if (fromChat.timestamp === 0) {
    return newestFromMessages;
  }

  if (isSameMessageSnapshot(fromChat, newestFromMessages) &&
    previewTextScore(newestFromMessages.text) > previewTextScore(fromChat.text)) {
    return newestFromMessages;
  }

  return isSnapshotNewer(fromChat, newestFromMessages) ? newestFromMessages : fromChat;
}

function buildDraftPreview(chat: Chat): string {
  const normalizedDraft = collapsePreviewWhitespace(chat.draftText);
  if (normalizedDraft.length === 0) {
    return '';
  }
  return normalizedDraft;
}

function resolveSendStatusForChat(chat: Chat, state: AppState): 'none' | 'pending' | 'sent' | 'read' | 'failed' {
  const chatMessages = state.messages.messages.get(chat.id);
  if (!chatMessages || chatMessages.size === 0) {
    return 'none';
  }

  let lastMessage: Message | undefined = undefined;
  if (chat.lastMessage) {
    lastMessage = chatMessages.get(chat.lastMessage.id);
  }

  if (!lastMessage) {
    for (const message of chatMessages.values()) {
      if (!lastMessage) {
        lastMessage = message;
        continue;
      }
      if (message.timestamp > lastMessage.timestamp) {
        lastMessage = message;
        continue;
      }
      if (message.timestamp === lastMessage.timestamp && compareInt64(message.id, lastMessage.id) > 0) {
        lastMessage = message;
      }
    }
  }

  if (!lastMessage || !lastMessage.isOutgoing) {
    return 'none';
  }

  if (lastMessage.sendStatus === 'pending') {
    return 'pending';
  }

  if (lastMessage.sendStatus === 'failed') {
    return 'failed';
  }

  if (lastMessage.isRead) {
    return 'read';
  }

  if (chat.lastReadOutboxMessageId !== '0' && compareInt64(lastMessage.id, chat.lastReadOutboxMessageId) <= 0) {
    return 'read';
  }

  return 'sent';
}

export function buildChatItemVO(chat: Chat, state: AppState): ChatItemVO {
  const vo = new ChatItemVO();
  vo.chatId = chat.id;
  vo.title = chat.title;
  vo.avatarColor = getAvatarColor(chat.id);
  vo.avatarImagePath = toFileUri(chat.photoSmall);
  vo.unreadCount = chat.unreadCount;
  vo.isPinned = chat.isPinned;
  vo.isMuted = chat.muteForSeconds > 0;
  vo.isGroup = chat.type === 'group' || chat.type === 'supergroup' || chat.type === 'channel';
  vo.isSecret = chat.type === 'secret';
  vo.sendStatus = resolveSendStatusForChat(chat, state);
  vo.hasMention = chat.unreadMentionCount > 0;

  if (chat.peerUserId > 0) {
    const user = state.users.users.get(chat.peerUserId);
    if (user) {
      const privateTitle = resolvePrivateTitle(user.firstName, user.lastName, user.username, user.phoneNumber);
      if (privateTitle.length > 0) {
        vo.title = privateTitle;
      }
      vo.avatarOnline = shouldShowAvatarOnline(user.status, user.isBot);
      vo.isVerified = user.isVerified;
      vo.isScam = user.isScam;
      vo.isFake = user.isFake;
      if (vo.avatarImagePath.length === 0 && user.photoSmall.length > 0) {
        vo.avatarImagePath = toFileUri(user.photoSmall);
      }
    }
  }

  if (!vo.title || vo.title.trim().length === 0) {
    vo.title = 'Unknown';
  }
  vo.initials = getInitials(vo.title);

  const draftPreview = buildDraftPreview(chat);
  const lastMessageSnapshot = resolveLastMessageSnapshot(chat, state);
  if (draftPreview.length > 0) {
    vo.isDraft = true;
    vo.previewPrefix = localizedString($r('app.string.chat_draft_prefix').id, 'Draft: ').trim();
    vo.previewPrefixStyle = 'draft';
    vo.lastMessage = draftPreview;
  } else {
    if (lastMessageSnapshot.timestamp > 0) {
      const normalizedPreview = collapsePreviewWhitespace(lastMessageSnapshot.text);
      let previewText = normalizedPreview.length > 0 ? normalizedPreview : '[Message]';

      // P1: prepend sender name for group/channel chats
      if (vo.isGroup && lastMessageSnapshot.senderId > 0) {
        if (lastMessageSnapshot.isOutgoing) {
          const youPrefix = localizedString($r('app.string.chat_you_prefix').id, 'You');
          vo.previewPrefix = youPrefix + ':';
          vo.previewPrefixStyle = 'author';
        } else {
          const sender = state.users.users.get(lastMessageSnapshot.senderId);
          if (sender) {
            const senderName = sender.firstName.length > 0 ? sender.firstName : sender.username;
            if (senderName.length > 0) {
              vo.previewPrefix = senderName + ':';
              vo.previewPrefixStyle = 'author';
            }
          }
        }
      }

      vo.lastMessage = previewText;
      vo.formattedTime = formatMessageTime(lastMessageSnapshot.timestamp);
    }
  }

  if (vo.formattedTime.length === 0 && lastMessageSnapshot.timestamp > 0) {
    vo.formattedTime = formatMessageTime(lastMessageSnapshot.timestamp);
  }

  // Typing indicator — expires after 6 seconds
  const typingInfo = state.chats.typingActions.get(chat.id);
  if (typingInfo && (Date.now() - typingInfo.timestamp) < 6000) {
    vo.isTyping = true;
    vo.previewPrefix = '';
    vo.previewPrefixStyle = 'none';
    const actionLabel = typingActionLabel(typingInfo.actionType);
    if (vo.isGroup && typingInfo.senderUserId > 0) {
      const sender = state.users.users.get(typingInfo.senderUserId);
      const name = sender ? (sender.firstName.length > 0 ? sender.firstName : sender.username) : '';
      vo.typingText = name.length > 0 ? name + ' ' + actionLabel : actionLabel;
    } else {
      vo.typingText = actionLabel;
    }
  }

  return vo;
}
