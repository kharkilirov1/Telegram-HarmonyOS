import { TDLibClient } from '../../services/TDLibClient';
import { NotificationCenter, EventId } from '../NotificationCenter';
import { FileController } from '../FileController';
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
  parseUpdateChatReadOutbox,
  parseUpdateChatTitle,
  parseUpdateDeleteMessages,
  parseUpdateMessageContent,
  parseUpdateMessageInteractionInfo,
  parseUpdateNewChat,
  parseUpdateNewMessage,
  parseUpdateUser,
  parseUpdateUserStatus,
  parseUpdateMessageSendSucceeded,
  parseUpdateMessageSendFailed,
  parseUpdateMessageIsPinned
} from './TdUpdateParser';
import { ChatActionState, applyInteractionInfo as mapInteractionInfo, mapChatActionState } from './MessageMapper';
import { removeMessages, replaceTemporaryMessage, sortDialogs as reduceSortDialogs, upsertIncomingMessage } from './MessageStateReducer';

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
  applyUserStatus: (userId: number, status: Record<string, Object>) => void;
  parseMessage: (raw: TdMessage) => Message;
  applyContent: (msg: Message, content: TdMessageContent) => void;
}

export function subscribeToTdUpdates(deps: MessagesUpdateSubscriberDeps): void {
  const client = deps.client;

  client.on('updateNewChat', (update: Record<string, Object>) => {
    const parsed = parseUpdateNewChat(update);
    if (!parsed) return;
    const rawChat = parsed.chat as TdChat;

    const chat = deps.parseChat(rawChat);
    deps.chatsById.set(chat.id, chat);
    deps.sortedDialogs.push(chat);
    reduceSortDialogs(deps.sortedDialogs);

    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatLastMessage', (update: Record<string, Object>) => {
    const parsed = parseUpdateChatLastMessage(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const chat = deps.chatsById.get(chatId);
    if (!chat) return;

    const rawMsg = parsed.lastMessage as TdMessage | undefined;
    if (rawMsg) {
      chat.lastMessage = deps.extractTextPreview(rawMsg);
      chat.lastMessageDate = rawMsg.date || 0;

      // Update outgoing/read flags for chat list checkmark indicators
      chat.lastMessageIsOutgoing = rawMsg.is_outgoing === true;
      const msgId: number = rawMsg.id || 0;
      chat.lastMessageIsRead = chat.lastMessageIsOutgoing
        && chat.lastReadOutboxMessageId > 0
        && msgId <= chat.lastReadOutboxMessageId;

      const sender: TdMessageSender | undefined = rawMsg.sender_id;
      if (sender && tdType(sender as Record<string, Object>) === 'messageSenderUser') {
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

  client.on('updateChatPosition', (update: Record<string, Object>) => {
    const parsed = parseUpdateChatPosition(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const chat = deps.chatsById.get(chatId);
    if (!chat) return;

    deps.updateChatPositions(chat, [parsed.position]);
    reduceSortDialogs(deps.sortedDialogs);
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatTitle', (update: Record<string, Object>) => {
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

  client.on('updateChatPhoto', (update: Record<string, Object>) => {
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
      } else if (chat.photoFileId > 0) {
        FileController.getInstance().requestFile(chat.photoFileId, 5, (path: string) => {
          if (path.length > 0) {
            chat.photo = path;
            NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
          }
        });
      }
    }

    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateUser', (update: Record<string, Object>) => {
    const parsed = parseUpdateUser(update);
    if (!parsed) return;
    const rawUser = parsed.user;

    const userId: number = deps.upsertUser(rawUser);
    if (userId === 0) return;

    const eventArgs: Record<string, Object> = {};
    eventArgs['userId'] = userId;
    NotificationCenter.getInstance().post(EventId.USER_INFO_UPDATED, eventArgs);
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateUserStatus', (update: Record<string, Object>) => {
    const parsed = parseUpdateUserStatus(update);
    if (!parsed) return;
    const userId: number = parsed.userId;
    const status: Record<string, Object> = parsed.status;

    deps.applyUserStatus(userId, status);

    const eventArgs: Record<string, Object> = {};
    eventArgs['userId'] = userId;
    NotificationCenter.getInstance().post(EventId.USER_STATUS_UPDATED, eventArgs);
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateNewMessage', (update: Record<string, Object>) => {
    const parsed = parseUpdateNewMessage(update);
    if (!parsed) return;
    const rawMsg = parsed.message as TdMessage;

    const msg = deps.parseMessage(rawMsg);
    const chatMessages: Message[] = deps.messagesByChat.get(msg.chatId) || [];
    const nextMessages: Message[] = upsertIncomingMessage(chatMessages, msg);
    deps.messagesByChat.set(msg.chatId, nextMessages);

    const eventArgs: Record<string, Object> = {};
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

  client.on('updateMessageContent', (update: Record<string, Object>) => {
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
        const eventArgs: Record<string, Object> = {};
        eventArgs['chatId'] = chatId;
        eventArgs['messageId'] = messageId;
        NotificationCenter.getInstance().post(EventId.MESSAGE_EDITED, eventArgs);
      }
    }
  });

  client.on('updateMessageInteractionInfo', (update: Record<string, Object>) => {
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

    const eventArgs: Record<string, Object> = {};
    eventArgs['chatId'] = chatId;
    eventArgs['messageId'] = messageId;
    NotificationCenter.getInstance().post(EventId.MESSAGE_EDITED, eventArgs);
  });

  client.on('updateDeleteMessages', (update: Record<string, Object>) => {
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
      const eventArgs: Record<string, Object> = {};
      eventArgs['chatId'] = chatId;
      eventArgs['messageId'] = messageId;
      NotificationCenter.getInstance().post(EventId.MESSAGE_DELETED, eventArgs);
    }

    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatReadInbox', (update: Record<string, Object>) => {
    const parsed = parseUpdateChatReadInbox(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const unreadCount: number = parsed.unreadCount;
    const chat = deps.chatsById.get(chatId);
    if (chat) {
      chat.unreadCount = unreadCount;
      chat.lastReadInboxMessageId = (update['last_read_inbox_message_id'] as number) || chat.lastReadInboxMessageId;
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    }
  });

  client.on('updateChatReadOutbox', (update: Record<string, Object>) => {
    const parsed = parseUpdateChatReadOutbox(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const lastReadId: number = parsed.lastReadOutboxMessageId;
    const chat = deps.chatsById.get(chatId);
    if (chat) {
      chat.lastReadOutboxMessageId = lastReadId;

      // Update chat list checkmark: if last message is outgoing and now read
      if (chat.lastMessageIsOutgoing && !chat.lastMessageIsRead) {
        chat.lastMessageIsRead = true;
      }

      // Mark outgoing messages as read up to this ID
      const messages = deps.messagesByChat.get(chatId);
      if (messages) {
        for (const msg of messages) {
          if (msg.isOutgoing && msg.id <= lastReadId) {
            msg.isRead = true;
          }
        }
      }

      const eventArgs: Record<string, Object> = {};
      eventArgs['chatId'] = chatId;
      NotificationCenter.getInstance().post(EventId.MESSAGES_READ, eventArgs);
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    }
  });

  client.on('updateChatNotificationSettings', (update: Record<string, Object>) => {
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

  client.on('updateChatIsMarkedAsUnread', (update: Record<string, Object>) => {
    const parsed = parseUpdateChatIsMarkedAsUnread(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const chat = deps.chatsById.get(chatId);
    if (!chat) return;
    chat.isMarkedAsUnread = parsed.isMarkedAsUnread;
    NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
  });

  client.on('updateChatAction', (update: Record<string, Object>) => {
    const parsed = parseUpdateChatAction(update);
    if (!parsed) return;
    const chatId: number = parsed.chatId;
    const action = parsed.action;
    const chat = deps.chatsById.get(chatId);

    if (chat) {
      const actionType: string = tdType(action as Record<string, Object>);
      const chatActionState: ChatActionState = mapChatActionState(actionType);
      if (chatActionState.isActive) {
        chat.isTyping = true;
        chat.typingDescription = chatActionState.description;

        setTimeout(() => {
          if (!chat.isTyping) return;
          chat.isTyping = false;
          chat.typingDescription = '';
          const eventArgs: Record<string, Object> = {};
          eventArgs['chatId'] = chatId;
          NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED, eventArgs);
        }, 5000);
      } else {
        chat.isTyping = false;
        chat.typingDescription = '';
      }

      const eventArgs: Record<string, Object> = {};
      eventArgs['chatId'] = chatId;
      NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED, eventArgs);
    }
  });

  // --- Message send lifecycle (critical for TDLib correctness) ---

  client.on('updateMessageSendSucceeded', (update: Record<string, Object>) => {
    const parsed = parseUpdateMessageSendSucceeded(update);
    if (!parsed) return;
    const rawMsg = parsed.message as TdMessage;
    const oldMessageId: number = parsed.oldMessageId;

    const confirmedMsg = deps.parseMessage(rawMsg);
    confirmedMsg.sendState = ''; // Confirmed
    const chatMessages: Message[] = deps.messagesByChat.get(confirmedMsg.chatId) || [];
    const nextMessages: Message[] = replaceTemporaryMessage(chatMessages, oldMessageId, confirmedMsg);
    deps.messagesByChat.set(confirmedMsg.chatId, nextMessages);

    const eventArgs: Record<string, Object> = {};
    eventArgs['chatId'] = confirmedMsg.chatId;
    eventArgs['oldMessageId'] = oldMessageId;
    eventArgs['newMessageId'] = confirmedMsg.id;
    NotificationCenter.getInstance().post(EventId.MESSAGE_SEND_SUCCEEDED, eventArgs);
  });

  client.on('updateMessageSendFailed', (update: Record<string, Object>) => {
    const parsed = parseUpdateMessageSendFailed(update);
    if (!parsed) return;
    const rawMsg = parsed.message as TdMessage;
    const oldMessageId: number = parsed.oldMessageId;

    // Update the temporary message to reflect the failure
    const chatId: number = rawMsg.chat_id || 0;
    const messages = deps.messagesByChat.get(chatId);
    if (messages) {
      const msg = messages.find((m: Message): boolean => m.id === oldMessageId);
      if (msg) {
        msg.id = rawMsg.id || oldMessageId;
        msg.sendState = 'failed'; // Mark as failed for UI retry indicator
      }
    }

    const eventArgs: Record<string, Object> = {};
    eventArgs['chatId'] = chatId;
    eventArgs['oldMessageId'] = oldMessageId;
    eventArgs['errorCode'] = parsed.errorCode;
    eventArgs['errorMessage'] = parsed.errorMessage;
    NotificationCenter.getInstance().post(EventId.MESSAGE_SEND_FAILED, eventArgs);
  });

  // --- Pinned message live updates ---

  client.on('updateMessageIsPinned', (update: Record<string, Object>) => {
    const parsed = parseUpdateMessageIsPinned(update);
    if (!parsed) return;

    const eventArgs: Record<string, Object> = {};
    eventArgs['chatId'] = parsed.chatId;
    eventArgs['messageId'] = parsed.messageId;
    eventArgs['isPinned'] = parsed.isPinned;
    NotificationCenter.getInstance().post(EventId.PINNED_MESSAGE_UPDATED, eventArgs);
  });
}

