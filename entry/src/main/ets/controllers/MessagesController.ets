import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { Chat } from '../models/Chat';
import { Message } from '../models/Message';
import { TdUser } from './messages/TdUpdateParser';
import {
  applyContent as parseTdMessageContent,
  extractTextPreview as parseTdPreview,
  parseChat as parseTdChat,
  parseMessage as parseTdMessage,
  updateChatPositions as parseTdUpdateChatPositions
} from './TdMessageParser';
import { subscribeToTdUpdates } from './messages/MessagesUpdateSubscriber';
import {
  CachedUser,
  applyUserStatus as reduceApplyUserStatus,
  getUserDisplayName as reduceGetUserDisplayName,
  registerPrivateChatUser as reduceRegisterPrivateChatUser,
  upsertUser as reduceUpsertUser
} from './messages/UserStateReducer';
import {
  searchChatMessages as requestSearchChatMessages,
  sendGifMessage as requestSendGifMessage,
  sendPoll as requestSendPoll,
  sendScheduledMessage as requestSendScheduledMessage,
  sendStickerMessage as requestSendStickerMessage,
  sendVoiceMessage as requestSendVoiceMessage,
  setDraft as requestSetDraft
} from './messages/MessageRequestService';
import {
  TdChat,
  TdChatPosition,
  TdChatType,
  TdMessage,
  TdMessageContent,
  TdMessageSender,
  safeNumber,
  tdType
} from '../models/TdTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'MessagesController';
const DOMAIN = 0x0001;

// --- TDLib response wrappers ---
interface TdMessages {
  messages?: TdMessage[];
}

export class MessagesController {
  private static instance: MessagesController | null = null;

  private chatsById: Map<number, Chat> = new Map();
  private sortedDialogs: Chat[] = [];
  private messagesByChat: Map<number, Message[]> = new Map();
  private usersById: Map<number, CachedUser> = new Map();
  private privateChatUserByChatId: Map<number, number> = new Map();
  private privateChatIdsByUserId: Map<number, Set<number>> = new Map();
  private pendingUserLoads: Set<number> = new Set();
  private dialogsLoading: boolean = false;
  private dialogsEndReached: boolean = false;

  private constructor() {
    this.subscribeToUpdates();
  }

  static getInstance(): MessagesController {
    if (!MessagesController.instance) {
      MessagesController.instance = new MessagesController();
    }
    return MessagesController.instance;
  }

  // --- Public read API ---

  getChat(chatId: number): Chat | undefined {
    return this.chatsById.get(chatId);
  }

  getSortedDialogs(): Chat[] {
    return this.sortedDialogs;
  }

  getMessages(chatId: number): Message[] {
    return this.messagesByChat.get(chatId) || [];
  }

  getPrivateChatUserId(chatId: number): number {
    return this.privateChatUserByChatId.get(chatId) || 0;
  }

  isDialogsLoading(): boolean {
    return this.dialogsLoading;
  }

  // --- Public action API ---

  async loadDialogs(limit: number = 30): Promise<void> {
    if (this.dialogsLoading || this.dialogsEndReached) return;
    this.dialogsLoading = true;
    try {
      await TDLibClient.getInstance().loadChats(limit);
    } finally {
      this.dialogsLoading = false;
    }
  }

  async loadMessages(chatId: number, fromMessageId: number = 0,
    limit: number = 50): Promise<Message[]> {
    const result: TdMessages = await TDLibClient.getInstance()
      .getChatHistory(chatId, fromMessageId, limit) as TdMessages;
    const rawMessages: TdMessage[] | undefined = result.messages;
    const parsed: Message[] = [];

    if (rawMessages) {
      for (const raw of rawMessages) {
        const msg = this.parseMessage(raw);
        parsed.push(msg);
      }
      // Cache
      const existing = this.messagesByChat.get(chatId) || [];
      const existingIds = new Set(existing.map((m: Message): number => m.id));
      for (const msg of parsed) {
        if (!existingIds.has(msg.id)) {
          existing.push(msg);
        }
      }
      existing.sort((a: Message, b: Message): number => a.id - b.id);
      this.messagesByChat.set(chatId, existing);
    }

    return parsed;
  }

  async sendTextMessage(chatId: number, text: string, replyToMessageId: number = 0): Promise<void> {
    await TDLibClient.getInstance().sendMessage(chatId, text, replyToMessageId);
  }

  async markMessagesAsRead(chatId: number, messageIds: number[]): Promise<void> {
    if (messageIds.length === 0) return;
    await TDLibClient.getInstance().viewMessages(chatId, messageIds);
  }

  async sendPhoto(chatId: number, filePath: string, caption: string = '',
    replyToMessageId: number = 0): Promise<void> {
    await TDLibClient.getInstance().sendPhoto(chatId, filePath, caption, replyToMessageId);
  }

  async sendDocument(chatId: number, filePath: string, caption: string = '',
    replyToMessageId: number = 0): Promise<void> {
    await TDLibClient.getInstance().sendDocument(chatId, filePath, caption, replyToMessageId);
  }

  async sendVideoMessage(chatId: number, filePath: string, caption: string = '',
    duration: number = 0, replyToMessageId: number = 0): Promise<void> {
    await TDLibClient.getInstance().sendVideo(chatId, filePath, caption, duration, replyToMessageId);
  }

  async deleteMessage(chatId: number, messageId: number): Promise<void> {
    const deleteParams: Record<string, Object> = {};
    deleteParams['chat_id'] = chatId;
    deleteParams['message_ids'] = [messageId];
    deleteParams['revoke'] = true;
    await TDLibClient.getInstance().send('deleteMessages', deleteParams);

    // Remove from local cache
    const messages = this.messagesByChat.get(chatId);
    if (messages) {
      const idx = messages.findIndex((m: Message): boolean => m.id === messageId);
      if (idx >= 0) {
        messages.splice(idx, 1);
      }
    }

    const eventArgs: Record<string, Object> = {};
    eventArgs['chatId'] = chatId;
    eventArgs['messageId'] = messageId;
    NotificationCenter.getInstance().post(EventId.MESSAGE_DELETED, eventArgs);
  }

  async sendPoll(chatId: number, question: string, options: string[],
    isAnonymous: boolean = true, isQuiz: boolean = false,
    correctOptionId: number = -1): Promise<void> {
    await requestSendPoll(chatId, question, options, isAnonymous, isQuiz, correctOptionId);
  }

  async sendScheduledMessage(chatId: number, text: string, sendDate: number,
    replyToMessageId: number = 0): Promise<void> {
    await requestSendScheduledMessage(chatId, text, sendDate, replyToMessageId);
  }

  async editMessageText(chatId: number, messageId: number, text: string): Promise<void> {
    await TDLibClient.getInstance().editMessageText(chatId, messageId, text);

    const messages = this.messagesByChat.get(chatId);
    if (messages) {
      const msg = messages.find((m: Message): boolean => m.id === messageId);
      if (msg) {
        msg.text = text;
      }
    }

    const eventArgs: Record<string, Object> = {};
    eventArgs['chatId'] = chatId;
    eventArgs['messageId'] = messageId;
    NotificationCenter.getInstance().post(EventId.MESSAGE_EDITED, eventArgs);
  }

  async sendGifMessage(chatId: number, gifId: number): Promise<void> {
    await requestSendGifMessage(chatId, gifId);
  }

  async sendStickerMessage(chatId: number, emoji: string, stickerId: number = 0): Promise<void> {
    await requestSendStickerMessage(chatId, emoji, stickerId);
  }

  async sendVoiceMessage(chatId: number, duration: number, filePath: string = '',
    replyToMessageId: number = 0): Promise<void> {
    await requestSendVoiceMessage(chatId, duration, filePath, replyToMessageId);
  }

  async toggleMessageReaction(chatId: number, messageId: number, emoji: string, isAdding: boolean): Promise<void> {
    if (isAdding) {
      await TDLibClient.getInstance().addMessageReaction(chatId, messageId, emoji);
    } else {
      await TDLibClient.getInstance().removeMessageReaction(chatId, messageId, emoji);
    }
  }

  async getChatPinnedMessage(chatId: number): Promise<Message | null> {
    try {
      const result = await TDLibClient.getInstance().getChatPinnedMessage(chatId);
      const type = (result['@type'] as string) || '';
      if (type === 'message') {
        const rawPinnedMessage = result as Object as TdMessage;
        return this.parseMessage(rawPinnedMessage);
      }
    } catch (_e) {
      // No pinned message or error — return null
    }
    return null;
  }

  async votePoll(chatId: number, messageId: number, optionIds: number[]): Promise<void> {
    const voteParams: Record<string, Object> = {};
    voteParams['chat_id'] = chatId;
    voteParams['message_id'] = messageId;
    voteParams['option_ids'] = optionIds;
    await TDLibClient.getInstance().send('setPollAnswer', voteParams);
  }

  async getScheduledMessages(chatId: number): Promise<Message[]> {
    const scheduledParams: Record<string, Object> = {};
    scheduledParams['chat_id'] = chatId;
    const result: TdMessages = await TDLibClient.getInstance().send('getChatScheduledMessages', scheduledParams) as TdMessages;
    const rawMessages: TdMessage[] | undefined = result.messages;
    if (!rawMessages) return [];
    return rawMessages.map((raw: TdMessage): Message => this.parseMessage(raw));
  }

  // --- Per-chat search ---

  async searchChatMessages(chatId: number, query: string, fromMessageId: number = 0,
    limit: number = 50, senderId: number = 0, filter: string = ''): Promise<Message[]> {
    try {
      const rawMessages: TdMessage[] = await requestSearchChatMessages(
        chatId,
        query,
        fromMessageId,
        limit,
        senderId,
        filter
      );
      return rawMessages.map((raw: TdMessage): Message => this.parseMessage(raw));
    } catch (_e) {
      return [];
    }
  }

  // --- Drafts ---

  async setDraft(chatId: number, text: string, replyToMessageId: number = 0): Promise<void> {
    await requestSetDraft(chatId, text, replyToMessageId);
  }

  // --- TDLib update subscriptions ---

  private subscribeToUpdates(): void {
    subscribeToTdUpdates({
      client: TDLibClient.getInstance(),
      chatsById: this.chatsById,
      sortedDialogs: this.sortedDialogs,
      messagesByChat: this.messagesByChat,
      parseChat: (raw: TdChat): Chat => this.parseChat(raw),
      extractTextPreview: (raw: TdMessage): string => this.extractTextPreview(raw),
      getUserDisplayName: (userId: number): string => reduceGetUserDisplayName(this.usersById, userId),
      loadUserIfMissing: (userId: number): void => {
        void this.loadUserIfMissing(userId);
      },
      updateChatPositions: (chat: Chat, positions: TdChatPosition[]): void => this.updateChatPositions(chat, positions),
      upsertUser: (rawUser: TdUser): number =>
        reduceUpsertUser(rawUser, this.usersById, this.messagesByChat, this.chatsById, this.privateChatIdsByUserId),
      applyUserStatus: (userId: number, status: Record<string, Object>): void =>
        reduceApplyUserStatus(userId, status, this.usersById, this.messagesByChat, this.chatsById, this.privateChatIdsByUserId),
      parseMessage: (raw: TdMessage): Message => this.parseMessage(raw),
      applyContent: (msg: Message, content: TdMessageContent): void => this.applyContent(msg, content)
    });
  }

  private async loadUserIfMissing(userId: number): Promise<void> {
    if (userId === 0 || this.usersById.has(userId) || this.pendingUserLoads.has(userId)) {
      return;
    }

    this.pendingUserLoads.add(userId);
    try {
      const params: Record<string, Object> = {};
      params['user_id'] = userId;
      const raw = await TDLibClient.getInstance().send('getUser', params) as TdUser;
      const resolvedUserId: number = reduceUpsertUser(
        raw,
        this.usersById,
        this.messagesByChat,
        this.chatsById,
        this.privateChatIdsByUserId
      );
      if (resolvedUserId > 0) {
        const eventArgs: Record<string, Object> = {};
        eventArgs['userId'] = resolvedUserId;
        NotificationCenter.getInstance().post(EventId.USER_INFO_UPDATED, eventArgs);
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    } catch (e) {
      hilog.debug(DOMAIN, TAG, 'loadUserIfMissing failed for %{public}d: %{public}s', userId, String(e));
    } finally {
      this.pendingUserLoads.delete(userId);
    }
  }

  // --- Parsing helpers ---

  private parseChat(raw: TdChat): Chat {
    const chat: Chat = parseTdChat(raw);
    const lastMsg: TdMessage | undefined = raw.last_message;

    if (lastMsg) {
      const sender: TdMessageSender | undefined = lastMsg.sender_id;
      if (sender && tdType(sender as Record<string, Object>) === 'messageSenderUser') {
        const senderUserId: number = sender.user_id || 0;
        chat.lastMessageSenderId = senderUserId;
        chat.lastMessageSenderName = reduceGetUserDisplayName(this.usersById, senderUserId);
        if (senderUserId > 0 && chat.lastMessageSenderName.length === 0) {
          void this.loadUserIfMissing(senderUserId);
        }
      }
    }

    // Determine type
    const chatType: TdChatType | undefined = raw.type;
    if (chatType) {
      const chatTypeRecord: Record<string, Object> = chatType as Record<string, Object>;
      const t: string = tdType(chatTypeRecord);
      chat.isGroup = t === 'chatTypeSupergroup' || t === 'chatTypeBasicGroup';
      chat.isChannel = t === 'chatTypeSupergroup' && (chatType.is_channel === true);

      if (t === 'chatTypePrivate') {
        const privateUserId: number = safeNumber(chatTypeRecord['user_id']);
        if (privateUserId > 0) {
          reduceRegisterPrivateChatUser(chat.id, privateUserId, this.privateChatUserByChatId, this.privateChatIdsByUserId);
          const displayName: string = reduceGetUserDisplayName(this.usersById, privateUserId);
          if (displayName.length > 0) {
            chat.title = displayName;
          }

          const cachedUser: CachedUser | undefined = this.usersById.get(privateUserId);
          if (cachedUser) {
            chat.isBot = cachedUser.isBot;
            chat.isUserOnline = cachedUser.isOnline;
            chat.lastSeenDate = cachedUser.lastSeenDate;
          } else {
            chat.isBot = false;
            void this.loadUserIfMissing(privateUserId);
          }
        }
      }
    }

    return chat;
  }

  private updateChatPositions(chat: Chat, positions: TdChatPosition[]): void {
    parseTdUpdateChatPositions(chat, positions);
  }

  parseMessage(raw: TdMessage): Message {
    const msg: Message = parseTdMessage(raw);
    const sender: TdMessageSender | undefined = raw.sender_id;
    const senderUserId: number = sender?.user_id || 0;
    let senderName: string = senderUserId > 0 ? reduceGetUserDisplayName(this.usersById, senderUserId) : '';
    if (senderName.length === 0) {
      const senderChatId: number = sender?.chat_id || 0;
      const senderChat: Chat | undefined = this.chatsById.get(senderChatId);
      if (senderChat) {
        senderName = senderChat.title;
      }
    }
    if (senderUserId > 0 && senderName.length === 0) {
      void this.loadUserIfMissing(senderUserId);
    }

    msg.senderId = senderUserId;
    msg.senderName = senderName;

    return msg;
  }

  private applyContent(msg: Message, content: TdMessageContent): void {
    parseTdMessageContent(msg, content);
  }

  private extractTextPreview(rawMsg: TdMessage): string {
    return parseTdPreview(rawMsg);
  }
}
