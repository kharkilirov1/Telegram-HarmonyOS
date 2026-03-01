// ChatItemVO — View Object for chat list cell rendering
// Built from AppState Chat model, contains only data needed for UI

import { AppState, Chat } from '../../../core/model/AppState';
import { compareInt64 } from '../../../core/utils/tdAccessors';

const AVATAR_COLORS: Resource[] = [
  $r('app.color.sender_color_1'),
  $r('app.color.sender_color_2'),
  $r('app.color.sender_color_3'),
  $r('app.color.sender_color_4'),
  $r('app.color.sender_color_5'),
  $r('app.color.sender_color_6'),
  $r('app.color.sender_color_7'),
  $r('app.color.sender_color_8')
];

export class ChatItemVO {
  chatId: number = 0;
  title: string = '';
  initials: string = '';
  avatarColor: Resource = $r('app.color.sender_color_5');
  avatarImagePath: string = '';
  avatarOnline: boolean = false;
  lastMessage: string = '';
  formattedTime: string = '';
  unreadCount: number = 0;
  isPinned: boolean = false;
  isMuted: boolean = false;
  sendStatus: 'none' | 'pending' | 'sent' | 'read' | 'failed' = 'none';
  isGroup: boolean = false;
}

function resolvePrivateTitle(firstName: string, lastName: string, username: string): string {
  const fullName = (firstName + ' ' + lastName).trim();
  if (fullName.length > 0) {
    return fullName;
  }
  if (username.length > 0) {
    return '@' + username;
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
    return 'Вчера';
  }
  if (diffDays < 7) {
    const days: string[] = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    return days[msgDate.getDay()];
  }
  // Older: dd.MM.yy
  return padTwo(msgDate.getDate()) + '.' + padTwo(msgDate.getMonth() + 1) + '.' +
    padTwo(msgDate.getFullYear() % 100);
}

function resolveSendStatusForChat(chat: Chat, state: AppState): 'none' | 'pending' | 'sent' | 'read' | 'failed' {
  if (!chat.lastMessage) {
    return 'none';
  }

  const chatMessages = state.messages.messages.get(chat.id);
  if (!chatMessages) {
    return 'none';
  }

  const lastMessage = chatMessages.get(chat.lastMessage.id);
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
  vo.avatarImagePath = chat.photoSmall;
  vo.unreadCount = chat.unreadCount;
  vo.isPinned = chat.isPinned;
  vo.isMuted = chat.muteForSeconds > 0;
  vo.isGroup = chat.type === 'group' || chat.type === 'supergroup' || chat.type === 'channel';
  vo.sendStatus = resolveSendStatusForChat(chat, state);

  if (chat.peerUserId > 0) {
    const user = state.users.users.get(chat.peerUserId);
    if (user) {
      const privateTitle = resolvePrivateTitle(user.firstName, user.lastName, user.username);
      if (privateTitle.length > 0) {
        vo.title = privateTitle;
      }
      vo.avatarOnline = user.status === 'online';
      if (vo.avatarImagePath.length === 0 && user.photoSmall.length > 0) {
        vo.avatarImagePath = user.photoSmall;
      }
    }
  }

  if (!vo.title || vo.title.trim().length === 0) {
    vo.title = 'Unknown';
  }
  vo.initials = getInitials(vo.title);

  if (chat.lastMessage) {
    vo.lastMessage = chat.lastMessage.text;
    vo.formattedTime = formatMessageTime(chat.lastMessage.timestamp);
  }

  return vo;
}
