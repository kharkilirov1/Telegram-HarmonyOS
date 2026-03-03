// Message selectors - pure functions for selecting message data from state
// Used by UI components to get derived message data

import { AppState } from '../../core/model/AppState';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { Message } from '../../core/model/AppState';
import { compareInt64 } from '../../core/utils/tdAccessors';

// Basic selectors
export const selectMessagesState = (state: AppState) => state.messages;

export const selectMessagesMap = (state: AppState) => state.messages.messages;

export const selectPendingMessages = (state: AppState) => state.messages.pendingMessages;

// Messages by chat ID
export const selectChatMessagesMap = (chatId: ChatId) => (state: AppState) => {
  return state.messages.messages.get(chatId);
};

/**
 * Сообщения чата, отсортированные по timestamp (newest first).
 * Используется для списка диалогов (последнее сообщение сверху).
 */
export const selectChatMessages = (chatId: ChatId) => (state: AppState): Message[] => {
  const chatMessages = state.messages.messages.get(chatId);
  if (!chatMessages) {
    return [];
  }

  // Convert Map to array and sort by timestamp (newest first)
  const messages = Array.from(chatMessages.values());
  return messages.sort((a: Message, b: Message): number => {
    if (a.timestamp !== b.timestamp) {
      return b.timestamp - a.timestamp;
    }
    return compareInt64(b.id, a.id);
  });
};

/**
 * Сообщения чата для chat view (oldest first).
 * Подтверждённые сообщения сортируются по id (int64 string comparison).
 * Pending/failed сообщения добавляются в конец.
 */
export const selectChatMessagesForChatView = (chatId: ChatId) => (state: AppState): Message[] => {
  const chatMessages = state.messages.messages.get(chatId);
  if (!chatMessages) {
    return [];
  }

  const all = Array.from(chatMessages.values());

  // Разделяем подтверждённые и pending/failed
  const confirmed: Message[] = [];
  const pending: Message[] = [];

  for (const msg of all) {
    if (msg.sendStatus === 'pending' || msg.sendStatus === 'failed') {
      pending.push(msg);
    } else {
      confirmed.push(msg);
    }
  }

  // Подтверждённые сортируем по времени (oldest first), при равенстве — по id.
  confirmed.sort((a: Message, b: Message): number => {
    if (a.timestamp !== b.timestamp) {
      return a.timestamp - b.timestamp;
    }
    return compareInt64(a.id, b.id);
  });

  // Pending сортируем по timestamp (oldest first)
  pending.sort((a: Message, b: Message): number => a.timestamp - b.timestamp);

  // Confirmed + Pending в конце
  return confirmed.concat(pending);
};

// Specific message by ID
export const selectMessageById = (chatId: ChatId, messageId: MessageId) => (state: AppState): Message | undefined => {
  const chatMessages = state.messages.messages.get(chatId);
  return chatMessages?.get(messageId);
};

// Latest message in chat
export const selectLatestMessage = (chatId: ChatId) => (state: AppState): Message | undefined => {
  const messages = selectChatMessages(chatId)(state);
  return messages.length > 0 ? messages[0] : undefined;
};

// Unread messages in chat
export const selectUnreadMessages = (chatId: ChatId) => (state: AppState): Message[] => {
  const messages = selectChatMessages(chatId)(state);
  return messages.filter(msg => !msg.isRead && !msg.isOutgoing);
};

export const selectUnreadMessagesCount = (chatId: ChatId) => (state: AppState): number => {
  return selectUnreadMessages(chatId)(state).length;
};

// Pending messages in chat
export const selectPendingMessagesInChat = (chatId: ChatId) => (state: AppState): Message[] => {
  const messages = selectChatMessages(chatId)(state);
  return messages.filter(msg => msg.isPending === true);
};

// Messages by sender
export const selectMessagesBySender = (chatId: ChatId, senderId: number) => (state: AppState): Message[] => {
  const messages = selectChatMessages(chatId)(state);
  return messages.filter(msg => msg.senderId === senderId);
};

// Search messages in chat
export const selectMessagesBySearchQuery = (chatId: ChatId, query: string) => (state: AppState): Message[] => {
  const normalizedQuery = query.toLowerCase().trim();
  if (!normalizedQuery) {
    return selectChatMessages(chatId)(state);
  }
  
  const messages = selectChatMessages(chatId)(state);
  return messages.filter(msg => {
    const text = msg.content.text || '';
    return text.toLowerCase().includes(normalizedQuery);
  });
};

// Message thread (replies)
export const selectMessageThread = (chatId: ChatId, rootMessageId: MessageId) => (state: AppState): Message[] => {
  const messages = selectChatMessages(chatId)(state);
  const thread: Message[] = [];
  
  // Find root message
  const rootMessage = messages.find(msg => msg.id === rootMessageId);
  if (rootMessage) {
    thread.push(rootMessage);
  }
  
  // Find replies (messages with replyToMessageId = rootMessageId)
  const replies = messages.filter(msg => msg.replyToMessageId === rootMessageId);
  thread.push(...replies);
  
  return thread;
};

// DTO for chat messages UI
export class ChatMessagesForUI {
  messages: Message[] = [];
  unreadCount: number = 0;
  pendingCount: number = 0;
  hasMessages: boolean = false;
  latestMessage: Message | null = null;
  isLoading: boolean = false;
}

/**
 * Combined selector for chat view UI.
 * Использует oldest-first сортировку для отображения в чате.
 */
export const selectChatMessagesForUI = (chatId: ChatId) => (state: AppState): ChatMessagesForUI => {
  // Для chat view используем oldest-first
  const messages = selectChatMessagesForChatView(chatId)(state);
  const unreadCount = selectUnreadMessagesCount(chatId)(state);
  const pendingMessages = messages.filter((m: Message) =>
    m.sendStatus === 'pending' || m.sendStatus === 'failed');
  const pendingCount = pendingMessages.length;

  // Latest message для preview (newest first)
  const newestFirst = selectChatMessages(chatId)(state);

  const result = new ChatMessagesForUI();
  result.messages = messages;
  result.unreadCount = unreadCount;
  result.pendingCount = pendingCount;
  result.hasMessages = messages.length > 0;
  result.latestMessage = newestFirst.length > 0 ? newestFirst[0] : null;
  result.isLoading = false;
  return result;
};

// DTO for message bubble UI
export class MessageForUI {
  id: MessageId = '0';
  chatId: ChatId = 0;
  senderId: number = 0;
  contentType: string = 'text';
  contentText: string = '';
  timestamp: number = 0;
  isOutgoing: boolean = false;
  isRead: boolean = false;
  showSenderInfo: boolean = false;
  groupWithNext: boolean = false;
  isFirstInGroup: boolean = false;
  isLastInGroup: boolean = false;
}

// Selector for message bubble UI
export const selectMessageForUI = (chatId: ChatId, messageId: MessageId) => (state: AppState): MessageForUI | null => {
  const message = selectMessageById(chatId, messageId)(state);
  if (!message) {
    return null;
  }

  const chatMessages = selectChatMessages(chatId)(state);
  const messageIndex = chatMessages.findIndex(msg => msg.id === messageId);
  const prevMessage = messageIndex > 0 ? chatMessages[messageIndex - 1] : null;
  const nextMessage = messageIndex < chatMessages.length - 1 ? chatMessages[messageIndex + 1] : null;

  // Determine if we should show sender info
  const showSenderInfo = !prevMessage ||
                        prevMessage.senderId !== message.senderId ||
                        (message.timestamp - prevMessage.timestamp) > 300000; // 5 minutes

  // Determine if we should group with next message
  const groupWithNextVal = nextMessage !== null &&
                       nextMessage.senderId === message.senderId &&
                       (nextMessage.timestamp - message.timestamp) < 300000;

  const result = new MessageForUI();
  result.id = message.id;
  result.chatId = message.chatId;
  result.senderId = message.senderId;
  result.contentType = message.content.type;
  result.contentText = message.content.text;
  result.timestamp = message.timestamp;
  result.isOutgoing = message.isOutgoing;
  result.isRead = message.isRead;
  result.showSenderInfo = showSenderInfo;
  result.groupWithNext = groupWithNextVal;
  result.isFirstInGroup = showSenderInfo;
  result.isLastInGroup = !groupWithNextVal;
  return result;
};

// Memoized selector for chat messages (non-generic for ArkTS)
export function createMemoizedChatMessagesSelector(chatId: ChatId): (state: AppState) => ChatMessagesForUI {
  let lastState: AppState | null = null;
  let lastResult: ChatMessagesForUI | null = null;

  return (state: AppState): ChatMessagesForUI => {
    if (lastState === state && lastResult !== null) {
      return lastResult;
    }

    lastState = state;
    lastResult = selectChatMessagesForUI(chatId)(state);
    return lastResult;
  };
}
