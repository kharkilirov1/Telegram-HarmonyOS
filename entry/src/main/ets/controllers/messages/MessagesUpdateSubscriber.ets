import { TDLibClient } from '../../services/TDLibClient';
import { NotificationCenter, EventId } from '../NotificationCenter';
import { NotificationService } from '../../services/NotificationService';
import { Chat } from '../../models/Chat';
import { Message } from '../../models/Message';
import {
  TdChat,
  TdChatPosition,
  TdFile,
  TdLocalFile,
  TdMessage,
  TdMessageContent,
  TdMessageSender,
  tdType
} from '../../models/TdTypes';
import {
  TdChatPhoto,
  TdUser,
  parseUpdateChatAction,
  parseUpdateChatLastMessage,
  parseUpdateChatIsMarkedAsUnread,
  parseUpdateChatNotificationSettings,
  parseUpdateChatPhoto,
  parseUpdateChatPosition,
  parseUpdateChatReadInbox,
  parseUpdateChatTitle,
  parseUpdateDeleteMessages,
  parseUpdateMessageContent,
  parseUpdateMessageInteractionInfo,
  parseUpdateNewChat,
  parseUpdateNewMessage,
  parseUpdateUser,
  parseUpdateUserStatus
} from './TdUpdateParser';
import { ChatActionState, applyInteractionInfo as mapInteractionInfo, mapChatActionState } from './MessageMapper';
import { removeMessages, sortDialogs as reduceSortDialogs, upsertIncomingMessage } from './MessageStateReducer';

export interface MessagesUpdateSubscriberDeps {
  client: TDLibClient;
  chatsById: Map<number, Chat>;
  sortedDialogs: Chat[];
  messagesByChat: Map<number, Message[]>;
  parseChat: (raw: TdChat) => Chat;
  extractTextPreview: (raw: TdMessage) => string;
  getUserDisplayName: (userId: number) => string;
  loadUserIfMissing: (userId: number) => void;
  updateChatPositions: (chat: Chat, positions: TdChatPosition[]) => void;
  upsertUser: (rawUser: TdUser) => number;
  applyUserStatus: (userId: number, status: Record<string, unknown>) => void;
  parseMessage: (raw: TdMessage) => Message;
  applyContent: (msg: Message, content: TdMessageContent) => void;
}

export function subscribeToTdUpdates(deps: MessagesUpdateSubscriberDeps): void {
  const client = deps.client;

  client.on('updateNewChat', (update: Record<string, unknown>) => {
    const parsed = parseUpdateNewChat(update);
    if (!parsed) return;
    const rawChat = parsed.chat as TdChat;

    const chat = deps.parseChat(rawChat);
    deps.chatsById.set(chat.id, chat);
    deps.sortedDialogs.push(chat);
    reduceSortDialogs(deps.sortedDialogs);

    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatLastMessage', (update: Record<string, unknown>) => {
    const parsed = parseUpdateChatLastMessage(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const chat = deps.chatsById.get(chatId);
    if (!chat) return;

    const rawMsg = parsed.lastMessage as TdMessage | undefined;
    if (rawMsg) {
      chat.lastMessage = deps.extractTextPreview(rawMsg);
      chat.lastMessageDate = rawMsg.date || 0;

      const sender: TdMessageSender | undefined = rawMsg.sender_id;
      if (sender && tdType(sender as Record<string, unknown>) === 'messageSenderUser') {
        const senderUserId: number = sender.user_id || 0;
        chat.lastMessageSenderId = senderUserId;
        chat.lastMessageSenderName = deps.getUserDisplayName(senderUserId);
        if (senderUserId > 0 && chat.lastMessageSenderName.length === 0) {
          deps.loadUserIfMissing(senderUserId);
        }
      }
    }

    const positions = parsed.positions;
    if (positions) {
      deps.updateChatPositions(chat, positions);
    }

    reduceSortDialogs(deps.sortedDialogs);
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatPosition', (update: Record<string, unknown>) => {
    const parsed = parseUpdateChatPosition(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const chat = deps.chatsById.get(chatId);
    if (!chat) return;

    deps.updateChatPositions(chat, [parsed.position]);
    reduceSortDialogs(deps.sortedDialogs);
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatTitle', (update: Record<string, unknown>) => {
    const parsed = parseUpdateChatTitle(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const chat = deps.chatsById.get(chatId);
    if (!chat) return;

    const title: string = parsed.title;
    if (title.length === 0 || chat.title === title) return;

    chat.title = title;
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatPhoto', (update: Record<string, unknown>) => {
    const parsed = parseUpdateChatPhoto(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const chat = deps.chatsById.get(chatId);
    if (!chat) return;

    const photo = parsed.photo as TdChatPhoto | undefined;
    const small = photo?.small as TdFile | undefined;
    if (!small) {
      chat.photo = null;
      chat.photoFileId = 0;
    } else {
      chat.photoFileId = small.id || 0;
      const local: TdLocalFile | undefined = small.local;
      if (local && local.is_downloading_completed && local.path.length > 0) {
        chat.photo = local.path;
      }
    }

    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateUser', (update: Record<string, unknown>) => {
    const parsed = parseUpdateUser(update);
    if (!parsed) return;
    const rawUser = parsed.user;

    const userId: number = deps.upsertUser(rawUser);
    if (userId === 0) return;

    const eventArgs: Record<string, unknown> = {};
    eventArgs['userId'] = userId;
    NotificationCenter.getInstance().post(EventId.USER_INFO_UPDATED, eventArgs);
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateUserStatus', (update: Record<string, unknown>) => {
    const parsed = parseUpdateUserStatus(update);
    if (!parsed) return;
    const userId: number = parsed.userId;
    const status: Record<string, unknown> = parsed.status;

    deps.applyUserStatus(userId, status);

    const eventArgs: Record<string, unknown> = {};
    eventArgs['userId'] = userId;
    NotificationCenter.getInstance().post(EventId.USER_STATUS_UPDATED, eventArgs);
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateNewMessage', (update: Record<string, unknown>) => {
    const parsed = parseUpdateNewMessage(update);
    if (!parsed) return;
    const rawMsg = parsed.message as TdMessage;

    const msg = deps.parseMessage(rawMsg);
    const chatMessages: Message[] = deps.messagesByChat.get(msg.chatId) || [];
    const nextMessages: Message[] = upsertIncomingMessage(chatMessages, msg);
    deps.messagesByChat.set(msg.chatId, nextMessages);

    const eventArgs: Record<string, unknown> = {};
    eventArgs['chatId'] = msg.chatId;
    eventArgs['message'] = msg;
    NotificationCenter.getInstance().post(EventId.NEW_MESSAGE, eventArgs);

    if (!msg.isOutgoing) {
      const chat = deps.chatsById.get(msg.chatId);
      if (chat && !chat.isMuted) {
        NotificationService.getInstance().showMessageNotification(
          chat.title,
          msg.senderName || chat.title,
          msg.text || '',
          msg.chatId
        );
      }
    }
  });

  client.on('updateMessageContent', (update: Record<string, unknown>) => {
    const parsed = parseUpdateMessageContent(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const messageId: number = parsed.messageId;
    const newContent = parsed.newContent as TdMessageContent;

    const messages = deps.messagesByChat.get(chatId);
    if (messages) {
      const msg = messages.find((m: Message): boolean => m.id === messageId);
      if (msg) {
        deps.applyContent(msg, newContent);
        const eventArgs: Record<string, unknown> = {};
        eventArgs['chatId'] = chatId;
        eventArgs['messageId'] = messageId;
        NotificationCenter.getInstance().post(EventId.MESSAGE_EDITED, eventArgs);
      }
    }
  });

  client.on('updateMessageInteractionInfo', (update: Record<string, unknown>) => {
    const parsed = parseUpdateMessageInteractionInfo(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const messageId: number = parsed.messageId;
    const info = parsed.interactionInfo;

    const messages = deps.messagesByChat.get(chatId);
    if (!messages) return;

    const msg = messages.find((m: Message): boolean => m.id === messageId);
    if (!msg) return;

    mapInteractionInfo(msg, info);

    const eventArgs: Record<string, unknown> = {};
    eventArgs['chatId'] = chatId;
    eventArgs['messageId'] = messageId;
    NotificationCenter.getInstance().post(EventId.MESSAGE_EDITED, eventArgs);
  });

  client.on('updateDeleteMessages', (update: Record<string, unknown>) => {
    const parsed = parseUpdateDeleteMessages(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const deletedIds = parsed.messageIds;

    const messages = deps.messagesByChat.get(chatId);
    if (messages) {
      const filtered: Message[] = removeMessages(messages, deletedIds);
      deps.messagesByChat.set(chatId, filtered);
    }

    for (const messageId of deletedIds) {
      const eventArgs: Record<string, unknown> = {};
      eventArgs['chatId'] = chatId;
      eventArgs['messageId'] = messageId;
      NotificationCenter.getInstance().post(EventId.MESSAGE_DELETED, eventArgs);
    }

    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatReadInbox', (update: Record<string, unknown>) => {
    const parsed = parseUpdateChatReadInbox(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const unreadCount: number = parsed.unreadCount;
    const chat = deps.chatsById.get(chatId);
    if (chat) {
      chat.unreadCount = unreadCount;
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    }
  });

  client.on('updateChatNotificationSettings', (update: Record<string, unknown>) => {
    const parsed = parseUpdateChatNotificationSettings(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const settings = parsed.settings;
    const chat = deps.chatsById.get(chatId);
    if (chat) {
      const muteFor: number = settings.mute_for || 0;
      chat.isMuted = muteFor > 0;
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    }
  });

  client.on('updateChatIsMarkedAsUnread', (update: Record<string, unknown>) => {
    const parsed = parseUpdateChatIsMarkedAsUnread(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const chat = deps.chatsById.get(chatId);
    if (!chat) return;
    chat.isMarkedAsUnread = parsed.isMarkedAsUnread;
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatAction', (update: Record<string, unknown>) => {
    const parsed = parseUpdateChatAction(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const action = parsed.action;
    const chat = deps.chatsById.get(chatId);

    if (chat) {
      const actionType: string = tdType(action as Record<string, unknown>);
      const chatActionState: ChatActionState = mapChatActionState(actionType);
      if (chatActionState.isActive) {
        chat.isTyping = true;
        chat.typingDescription = chatActionState.description;

        setTimeout(() => {
          if (!chat.isTyping) return;
          chat.isTyping = false;
          chat.typingDescription = '';
          const eventArgs: Record<string, unknown> = {};
          eventArgs['chatId'] = chatId;
          NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED, eventArgs);
        }, 5000);
      } else {
        chat.isTyping = false;
        chat.typingDescription = '';
      }

      const eventArgs: Record<string, unknown> = {};
      eventArgs['chatId'] = chatId;
      NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED, eventArgs);
    }
  });
}
