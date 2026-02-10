import { formatLastSeen } from '../../../components/Common/AvatarWithStatus';
import { MessagesController } from '../../../controllers/MessagesController';
import { Chat } from '../../../models/Chat';
import { Message, MessageReaction } from '../../../models/Message';

export interface ChatInfoSnapshot {
  title: string;
  isGroup: boolean;
  isChannel: boolean;
  photo: string | null;
  initial: string;
  lastSeenText: string;
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

export function buildChatInfoSnapshot(chat: Chat, groupMembersTemplate: string): ChatInfoSnapshot {
  const lastSeenText = chat.isGroup
    ? groupMembersTemplate.replace('%s', chat.unreadCount.toString())
    : formatLastSeen(chat.isUserOnline, chat.lastSeenDate);

  return {
    title: chat.title,
    isGroup: chat.isGroup,
    isChannel: chat.isChannel,
    photo: chat.photo,
    initial: chat.title.length > 0 ? chat.title.charAt(0) : '?',
    lastSeenText: lastSeenText
  };
}

export async function loadInitialMessages(chatId: number, limit: number = 50): Promise<InitialMessagesLoadResult> {
  const msgs = await MessagesController.getInstance().loadMessages(chatId, 0, limit);
  const messages: Message[] = msgs.reverse();
  const endReachedOlder = msgs.length < limit;

  let pinnedMessage: Message | null = null;
  if (messages.length > 2) {
    const candidate = messages.find((m: Message) => !m.isOutgoing && m.text.length > 10);
    if (candidate) {
      pinnedMessage = candidate;
    }
  }

  // TODO: remove demo-only reactions once real TDLib reactions are wired everywhere.
  if (messages.length > 3) {
    const r1: MessageReaction = { emoji: '\u{1F44D}', count: 3, isMine: false };
    const r2: MessageReaction = { emoji: '\u{2764}\u{FE0F}', count: 1, isMine: true };
    messages[1].reactions = [r1, r2];
  }
  if (messages.length > 5) {
    const r3: MessageReaction = { emoji: '\u{1F602}', count: 2, isMine: false };
    messages[4].reactions = [r3];
  }

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
