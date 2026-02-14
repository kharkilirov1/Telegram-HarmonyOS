import { formatLastSeen } from '../../../components/Common/AvatarWithStatus';
import { MessagesController } from '../../../controllers/MessagesController';
import { Chat } from '../../../models/Chat';
import { Message } from '../../../models/Message';

export interface ChatInfoSnapshot {
  title: string;
  isGroup: boolean;
  isChannel: boolean;
  photo: string | null;
  initial: string;
  lastSeenText: string;
  isOnline: boolean;
}

export interface InitialMessagesLoadResult {
  messages: Message[];
  endReachedOlder: boolean;
  pinnedMessage: Message | null;
}

export interface OlderMessagesLoadResult {
  messages: Message[];
  endReachedOlder: boolean;
}

export function buildChatInfoSnapshot(chat: Chat, _groupMembersTemplate: string): ChatInfoSnapshot {
  const lastSeenText = (chat.isGroup || chat.isChannel)
    ? ''
    : formatLastSeen(chat.isUserOnline, chat.lastSeenDate);

  return {
    title: chat.title,
    isGroup: chat.isGroup,
    isChannel: chat.isChannel,
    photo: chat.photo,
    initial: chat.title.length > 0 ? chat.title.charAt(0) : '?',
    lastSeenText: lastSeenText,
    isOnline: !chat.isGroup && !chat.isChannel && chat.isUserOnline
  };
}

export async function loadInitialMessages(chatId: number, limit: number = 50): Promise<InitialMessagesLoadResult> {
  const result = await Promise.all([
    MessagesController.getInstance().loadMessages(chatId, 0, limit),
    MessagesController.getInstance().getChatPinnedMessage(chatId)
  ]);
  const msgs: Message[] = result[0];
  const pinnedMessage: Message | null = result[1];
  const messages: Message[] = msgs.reverse();
  const endReachedOlder = msgs.length < limit;

  return {
    messages: messages,
    endReachedOlder: endReachedOlder,
    pinnedMessage: pinnedMessage
  };
}

export async function loadOlderMessages(
  chatId: number,
  currentMessages: Message[],
  limit: number = 50
): Promise<OlderMessagesLoadResult> {
  if (currentMessages.length === 0) {
    return { messages: currentMessages, endReachedOlder: true };
  }

  const oldestId = currentMessages[0].id;
  const older = await MessagesController.getInstance().loadMessages(chatId, oldestId, limit);
  const endReachedOlder = older.length < limit;

  if (older.length === 0) {
    return { messages: currentMessages, endReachedOlder: endReachedOlder };
  }

  return {
    messages: [...older.reverse(), ...currentMessages],
    endReachedOlder: endReachedOlder
  };
}
