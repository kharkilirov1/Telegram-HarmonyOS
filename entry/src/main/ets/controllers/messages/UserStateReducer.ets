import { Chat } from '../../models/Chat';
import { Message } from '../../models/Message';
import { safeNumber, tdType } from '../../models/TdTypes';
import { TdUser } from './TdUpdateParser';

export interface CachedUser {
  id: number;
  firstName: string;
  lastName: string;
  username: string;
  isOnline: boolean;
  lastSeenDate: number;
}

export function getUserDisplayName(usersById: Map<number, CachedUser>, userId: number): string {
  const user: CachedUser | undefined = usersById.get(userId);
  if (!user) return '';

  const fullName: string = `${user.firstName} ${user.lastName}`.trim();
  if (fullName.length > 0) {
    return fullName;
  }
  if (user.username.length > 0) {
    return `@${user.username}`;
  }
  return '';
}

export function upsertUser(
  rawUser: TdUser,
  usersById: Map<number, CachedUser>,
  messagesByChat: Map<number, Message[]>,
  chatsById: Map<number, Chat>,
  privateChatIdsByUserId: Map<number, Set<number>>
): number {
  const userId: number = rawUser.id || 0;
  if (userId === 0) return 0;

  const existing: CachedUser | undefined = usersById.get(userId);
  const usernames = rawUser.usernames;

  let username: string = rawUser.username || '';
  if (username.length === 0 && usernames) {
    username = usernames.editable_username || '';
    if (username.length === 0) {
      const active: string[] | undefined = usernames.active_usernames;
      if (active && active.length > 0) {
        username = active[0];
      }
    }
  }
  if (username.length === 0 && existing) {
    username = existing.username;
  }

  const user: CachedUser = {
    id: userId,
    firstName: rawUser.first_name || (existing ? existing.firstName : ''),
    lastName: rawUser.last_name || (existing ? existing.lastName : ''),
    username: username,
    isOnline: existing ? existing.isOnline : false,
    lastSeenDate: existing ? existing.lastSeenDate : 0
  };

  const status: Record<string, Object> | undefined = rawUser.status;
  if (status) {
    applyStatusToUser(user, status);
  }

  usersById.set(userId, user);
  refreshUserPresentation(userId, usersById, messagesByChat, chatsById, privateChatIdsByUserId);
  return userId;
}

export function applyUserStatus(
  userId: number,
  status: Record<string, Object>,
  usersById: Map<number, CachedUser>,
  messagesByChat: Map<number, Message[]>,
  chatsById: Map<number, Chat>,
  privateChatIdsByUserId: Map<number, Set<number>>
): void {
  let user: CachedUser | undefined = usersById.get(userId);
  if (!user) {
    user = {
      id: userId,
      firstName: '',
      lastName: '',
      username: '',
      isOnline: false,
      lastSeenDate: 0
    };
  }

  applyStatusToUser(user, status);
  usersById.set(userId, user);
  refreshUserPresentation(userId, usersById, messagesByChat, chatsById, privateChatIdsByUserId);
}

export function registerPrivateChatUser(
  chatId: number,
  userId: number,
  privateChatUserByChatId: Map<number, number>,
  privateChatIdsByUserId: Map<number, Set<number>>
): void {
  if (chatId === 0 || userId === 0) return;

  const previousUserId: number | undefined = privateChatUserByChatId.get(chatId);
  if (previousUserId && previousUserId !== userId) {
    const oldSet: Set<number> | undefined = privateChatIdsByUserId.get(previousUserId);
    if (oldSet) {
      oldSet.delete(chatId);
    }
  }

  privateChatUserByChatId.set(chatId, userId);
  let set: Set<number> | undefined = privateChatIdsByUserId.get(userId);
  if (!set) {
    set = new Set<number>();
    privateChatIdsByUserId.set(userId, set);
  }
  set.add(chatId);
}

function applyStatusToUser(user: CachedUser, status: Record<string, Object>): void {
  const statusType: string = tdType(status);
  if (statusType === 'userStatusOnline') {
    user.isOnline = true;
    return;
  }

  user.isOnline = false;
  if (statusType === 'userStatusOffline') {
    user.lastSeenDate = safeNumber(status['was_online']);
  } else {
    user.lastSeenDate = 0;
  }
}

function refreshUserPresentation(
  userId: number,
  usersById: Map<number, CachedUser>,
  messagesByChat: Map<number, Message[]>,
  chatsById: Map<number, Chat>,
  privateChatIdsByUserId: Map<number, Set<number>>
): void {
  const user: CachedUser | undefined = usersById.get(userId);
  if (!user) return;

  const displayName: string = getUserDisplayName(usersById, userId);

  messagesByChat.forEach((messages: Message[]) => {
    for (const message of messages) {
      if (message.senderId === userId) {
        message.senderName = displayName;
      }
    }
  });

  chatsById.forEach((chat: Chat) => {
    if (chat.lastMessageSenderId === userId) {
      chat.lastMessageSenderName = displayName;
    }
  });

  const privateChats: Set<number> | undefined = privateChatIdsByUserId.get(userId);
  if (!privateChats) return;

  for (const chatId of privateChats) {
    const privateChat: Chat | undefined = chatsById.get(chatId);
    if (!privateChat) continue;
    if (displayName.length > 0) {
      privateChat.title = displayName;
    }
    privateChat.isUserOnline = user.isOnline;
    privateChat.lastSeenDate = user.lastSeenDate;
  }
}
