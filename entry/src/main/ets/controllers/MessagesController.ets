// MessagesController — state management and TDLib API calls
// Parsing/mapping logic extracted to TdMessageParser.ets
// TDLib types extracted to models/TdTypes.ets

import { TDLibClient, TDLibError } from '../services/TDLibClient';
import { handleTdlibError } from '../services/AppError';
import { NotificationCenter, EventId } from './NotificationCenter';
import { NotificationService } from '../services/NotificationService';
import { Chat } from '../models/Chat';
import { Message } from '../models/Message';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  tdType,
  TdMessage,
  TdMessageContent,
  TdMessageSender,
  TdMessages,
  TdChat,
  TdChatPosition,
  TdNotificationSettings,
  TdChatAction,
  TdUpdateNewChat,
  TdUpdateChatLastMessage,
  TdUpdateChatPosition,
  TdUpdateNewMessage,
  TdUpdateMessageContent,
  TdUpdateChatReadInbox,
  TdUpdateChatNotificationSettings,
  TdUpdateChatAction
} from '../models/TdTypes';
import {
  parseMessage,
  applyContent,
  extractTextPreview,
  parseChat,
  updateChatPositions
} from './TdMessageParser';

export class MessagesController {
  private static instance: MessagesController | null = null;

  private chatsById: Map<number, Chat> = new Map();
  private sortedDialogs: Chat[] = [];
  private messagesByChat: Map<number, Message[]> = new Map();
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
      .getChatHistory(chatId, fromMessageId, limit) as unknown as TdMessages;
    const rawMessages: TdMessage[] | undefined = result.messages;
    const parsed: Message[] = [];

    if (rawMessages) {
      for (const raw of rawMessages) {
        const msg = parseMessage(raw);
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

    let pollTypeRecord: Record<string, Object> = {};
    if (isQuiz) {
      pollTypeRecord['@type'] = 'pollTypeQuiz';
      pollTypeRecord['correct_option_id'] = correctOptionId;
    } else {
      pollTypeRecord['@type'] = 'pollTypeRegular';
      pollTypeRecord['allow_multiple_answers'] = false;
    }

    const formattedQuestion: Record<string, Object> = {};
    formattedQuestion['@type'] = 'formattedText';
    formattedQuestion['text'] = question;
    const formattedOptions: Record<string, Object>[] = options.map((o: string): Record<string, Object> => {
      const opt: Record<string, Object> = {};
      opt['@type'] = 'formattedText';
      opt['text'] = o;
      return opt;
    });
    const inputMessageContent: Record<string, Object> = {};
    inputMessageContent['@type'] = 'inputMessagePoll';
    inputMessageContent['question'] = formattedQuestion;
    inputMessageContent['options'] = formattedOptions;
    inputMessageContent['is_anonymous'] = isAnonymous;
    inputMessageContent['type'] = pollTypeRecord;
    const sendPollParams: Record<string, Object> = {};
    sendPollParams['chat_id'] = chatId;
    sendPollParams['input_message_content'] = inputMessageContent;
    await TDLibClient.getInstance().send('sendMessage', sendPollParams);
  }

  async sendScheduledMessage(chatId: number, text: string, sendDate: number,
    replyToMessageId: number = 0): Promise<void> {
    let replyToParam: Record<string, Object> | undefined = undefined;
    if (replyToMessageId > 0) {
      replyToParam = {};
      replyToParam['@type'] = 'inputMessageReplyToMessage';
      replyToParam['message_id'] = replyToMessageId;
    }

    const formattedText: Record<string, Object> = {};
    formattedText['@type'] = 'formattedText';
    formattedText['text'] = text;
    const inputContent: Record<string, Object> = {};
    inputContent['@type'] = 'inputMessageText';
    inputContent['text'] = formattedText;
    const schedulingState: Record<string, Object> = {};
    schedulingState['@type'] = 'messageSchedulingStateSendAtDate';
    schedulingState['send_date'] = sendDate;
    const sendScheduledParams: Record<string, Object> = {};
    sendScheduledParams['chat_id'] = chatId;
    if (replyToParam !== undefined) {
      sendScheduledParams['reply_to'] = replyToParam;
    }
    sendScheduledParams['input_message_content'] = inputContent;
    sendScheduledParams['scheduling_state'] = schedulingState;
    await TDLibClient.getInstance().send('sendMessage', sendScheduledParams);
  }

  async editMessageText(chatId: number, messageId: number, text: string): Promise<void> {
    await TDLibClient.getInstance().editMessageText(chatId, messageId, text);
    // Update local cache
    const messages = this.messagesByChat.get(chatId);
    if (messages) {
      const msg = messages.find((m: Message): boolean => m.id === messageId);
      if (msg) {
        msg.text = text;
      }
    }
    const editedEventArgs: Record<string, Object> = {};
    editedEventArgs['chatId'] = chatId;
    editedEventArgs['messageId'] = messageId;
    NotificationCenter.getInstance().post(EventId.MESSAGE_EDITED, editedEventArgs);
  }

  async sendGifMessage(chatId: number, gifId: number): Promise<void> {
    const animation: Record<string, Object> = {};
    animation['@type'] = 'inputFileId';
    animation['id'] = gifId;
    const gifContent: Record<string, Object> = {};
    gifContent['@type'] = 'inputMessageAnimation';
    gifContent['animation'] = animation;
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['input_message_content'] = gifContent;
    await TDLibClient.getInstance().send('sendMessage', params);
  }

  async sendStickerMessage(chatId: number, emoji: string, stickerId: number = 0): Promise<void> {
    const sticker: Record<string, Object> = {};
    sticker['@type'] = 'inputFileId';
    sticker['id'] = stickerId;
    const stickerContent: Record<string, Object> = {};
    stickerContent['@type'] = 'inputMessageSticker';
    stickerContent['sticker'] = sticker;
    stickerContent['emoji'] = emoji;
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['input_message_content'] = stickerContent;
    await TDLibClient.getInstance().send('sendMessage', params);
  }

  async sendVoiceMessage(chatId: number, duration: number, filePath: string = '',
    replyToMessageId: number = 0): Promise<void> {
    const voiceNote: Record<string, Object> = {};
    voiceNote['@type'] = 'inputFileLocal';
    voiceNote['path'] = filePath;
    const voiceContent: Record<string, Object> = {};
    voiceContent['@type'] = 'inputMessageVoiceNote';
    voiceContent['voice_note'] = voiceNote;
    voiceContent['duration'] = duration;
    voiceContent['waveform'] = '';
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    if (replyToMessageId > 0) {
      const replyTo: Record<string, Object> = {};
      replyTo['@type'] = 'inputMessageReplyToMessage';
      replyTo['message_id'] = replyToMessageId;
      params['reply_to'] = replyTo;
    }
    params['input_message_content'] = voiceContent;
    await TDLibClient.getInstance().send('sendMessage', params);
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
    const result: TdMessages = await TDLibClient.getInstance().send('getChatScheduledMessages', scheduledParams) as unknown as TdMessages;
    const rawMessages: TdMessage[] | undefined = result.messages;
    if (!rawMessages) return [];
    return rawMessages.map((raw: TdMessage): Message => parseMessage(raw));
  }

  // --- Per-chat search ---

  async searchChatMessages(chatId: number, query: string, fromMessageId: number = 0,
    limit: number = 50, senderId: number = 0, filter: string = ''): Promise<Message[]> {
    try {
      // Build sender_id parameter for TDLib
      let senderParam: Record<string, Object> | undefined = undefined;
      if (senderId > 0) {
        senderParam = {};
        senderParam['@type'] = 'messageSenderUser';
        senderParam['user_id'] = senderId;
      }

      // Map filter string to TDLib searchMessagesFilter type
      let filterParam: Record<string, Object> | undefined = undefined;
      switch (filter) {
        case 'photo':
          filterParam = {};
          filterParam['@type'] = 'searchMessagesFilterPhoto';
          break;
        case 'video':
          filterParam = {};
          filterParam['@type'] = 'searchMessagesFilterVideo';
          break;
        case 'document':
          filterParam = {};
          filterParam['@type'] = 'searchMessagesFilterDocument';
          break;
        case 'url':
          filterParam = {};
          filterParam['@type'] = 'searchMessagesFilterUrl';
          break;
        default:
          break;
      }

      const searchParams: Record<string, Object> = {};
      searchParams['chat_id'] = chatId;
      searchParams['query'] = query;
      if (senderParam !== undefined) {
        searchParams['sender_id'] = senderParam;
      }
      searchParams['from_message_id'] = fromMessageId;
      searchParams['offset'] = 0;
      searchParams['limit'] = limit;
      if (filterParam !== undefined) {
        searchParams['filter'] = filterParam;
      }
      searchParams['message_thread_id'] = 0;
      const result: TdMessages = await TDLibClient.getInstance().send('searchChatMessages', searchParams) as unknown as TdMessages;
      const rawMessages: TdMessage[] | undefined = result.messages;
      if (!rawMessages) return [];
      return rawMessages.map((raw: TdMessage): Message => parseMessage(raw));
    } catch (e) {
      if (e instanceof TDLibError) {
        handleTdlibError(e.code, e.tdMessage);
      }
      hilog.warn(0x0001, 'MessagesController', 'searchChatMessages failed for chat %{public}d', chatId);
      return [];
    }
  }

  // --- Drafts ---

  async setDraft(chatId: number, text: string, replyToMessageId: number = 0): Promise<void> {
    if (text.length === 0 && replyToMessageId === 0) {
      const clearDraftParams: Record<string, Object> = {};
      clearDraftParams['chat_id'] = chatId;
      await TDLibClient.getInstance().send('setChatDraftMessage', clearDraftParams);
    } else {
      let draftReplyTo: Record<string, Object> | undefined = undefined;
      if (replyToMessageId > 0) {
        draftReplyTo = {};
        draftReplyTo['@type'] = 'inputMessageReplyToMessage';
        draftReplyTo['message_id'] = replyToMessageId;
      }

      const draftFormattedText: Record<string, Object> = {};
      draftFormattedText['@type'] = 'formattedText';
      draftFormattedText['text'] = text;
      const draftInputMessageText: Record<string, Object> = {};
      draftInputMessageText['@type'] = 'inputMessageText';
      draftInputMessageText['text'] = draftFormattedText;
      const draftMessage: Record<string, Object> = {};
      draftMessage['@type'] = 'draftMessage';
      if (draftReplyTo !== undefined) {
        draftMessage['reply_to'] = draftReplyTo;
      }
      draftMessage['input_message_text'] = draftInputMessageText;
      const setDraftParams: Record<string, Object> = {};
      setDraftParams['chat_id'] = chatId;
      setDraftParams['draft_message'] = draftMessage;
      await TDLibClient.getInstance().send('setChatDraftMessage', setDraftParams);
    }
  }

  // --- TDLib update subscriptions ---

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateNewChat', (update: Record<string, Object>) => {
      const data: TdUpdateNewChat = update as unknown as TdUpdateNewChat;
      const rawChat: TdChat | undefined = data.chat;
      if (!rawChat) return;

      const chat = parseChat(rawChat);
      this.chatsById.set(chat.id, chat);
      this.sortedDialogs.push(chat);
      this.sortDialogs();

      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatLastMessage', (update: Record<string, Object>) => {
      const data: TdUpdateChatLastMessage = update as unknown as TdUpdateChatLastMessage;
      const chatId: number = data.chat_id || 0;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const rawMsg: TdMessage | undefined = data.last_message;
      if (rawMsg) {
        chat.lastMessage = extractTextPreview(rawMsg);
        chat.lastMessageDate = rawMsg.date || 0;

        const sender: TdMessageSender | undefined = rawMsg.sender_id;
        if (sender && tdType(sender as unknown as Record<string, Object>) === 'messageSenderUser') {
          chat.lastMessageSenderId = sender.user_id || 0;
        }
      }

      // Update positions if provided
      const positions: TdChatPosition[] | undefined = data.positions;
      if (positions) {
        updateChatPositions(chat, positions);
      }

      this.sortDialogs();
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatPosition', (update: Record<string, Object>) => {
      const data: TdUpdateChatPosition = update as unknown as TdUpdateChatPosition;
      const chatId: number = data.chat_id || 0;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const position: TdChatPosition | undefined = data.position;
      if (position) {
        updateChatPositions(chat, [position]);
        this.sortDialogs();
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateNewMessage', (update: Record<string, Object>) => {
      const data: TdUpdateNewMessage = update as unknown as TdUpdateNewMessage;
      const rawMsg: TdMessage | undefined = data.message;
      if (!rawMsg) return;

      const msg = parseMessage(rawMsg);
      const chatMessages = this.messagesByChat.get(msg.chatId) || [];

      // Avoid duplicates
      if (!chatMessages.find((m: Message): boolean => m.id === msg.id)) {
        chatMessages.push(msg);
        chatMessages.sort((a: Message, b: Message): number => a.id - b.id);
        this.messagesByChat.set(msg.chatId, chatMessages);
      }

      const newMsgEventArgs: Record<string, Object> = {};
      newMsgEventArgs['chatId'] = msg.chatId;
      newMsgEventArgs['message'] = msg;
      NotificationCenter.getInstance().post(EventId.NEW_MESSAGE, newMsgEventArgs);

      // Trigger push notification for incoming messages
      if (!msg.isOutgoing) {
        const chat = this.chatsById.get(msg.chatId);
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
      const data: TdUpdateMessageContent = update as unknown as TdUpdateMessageContent;
      const chatId: number = data.chat_id || 0;
      const messageId: number = data.message_id || 0;
      const newContent: TdMessageContent | undefined = data.new_content;

      const messages = this.messagesByChat.get(chatId);
      if (messages && newContent) {
        const msg = messages.find((m: Message): boolean => m.id === messageId);
        if (msg) {
          applyContent(msg, newContent);
          const editedEventArgs: Record<string, Object> = {};
          editedEventArgs['chatId'] = chatId;
          editedEventArgs['messageId'] = messageId;
          NotificationCenter.getInstance().post(EventId.MESSAGE_EDITED, editedEventArgs);
        }
      }
    });

    client.on('updateChatReadInbox', (update: Record<string, Object>) => {
      const data: TdUpdateChatReadInbox = update as unknown as TdUpdateChatReadInbox;
      const chatId: number = data.chat_id || 0;
      const unreadCount: number = data.unread_count || 0;
      const chat = this.chatsById.get(chatId);
      if (chat) {
        chat.unreadCount = unreadCount;
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateChatNotificationSettings', (update: Record<string, Object>) => {
      const data: TdUpdateChatNotificationSettings = update as unknown as TdUpdateChatNotificationSettings;
      const chatId: number = data.chat_id || 0;
      const settings: TdNotificationSettings | undefined = data.notification_settings;
      const chat = this.chatsById.get(chatId);
      if (chat && settings) {
        const muteFor: number = settings.mute_for || 0;
        chat.isMuted = muteFor > 0;
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateChatAction', (update: Record<string, Object>) => {
      const data: TdUpdateChatAction = update as unknown as TdUpdateChatAction;
      const chatId: number = data.chat_id || 0;
      const action: TdChatAction | undefined = data.action;
      const chat = this.chatsById.get(chatId);

      if (chat && action) {
        const actionType: string = tdType(action as unknown as Record<string, Object>);
        if (actionType === 'chatActionTyping') {
          chat.isTyping = true;
          chat.typingDescription = 'typing...';

          // Auto-clear after 5 seconds
          setTimeout(() => {
            chat.isTyping = false;
            chat.typingDescription = '';
            const timeoutEventArgs: Record<string, Object> = {};
            timeoutEventArgs['chatId'] = chatId;
            NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED, timeoutEventArgs);
          }, 5000);
        } else if (actionType === 'chatActionCancel') {
          chat.isTyping = false;
          chat.typingDescription = '';
        }

        const actionEventArgs: Record<string, Object> = {};
        actionEventArgs['chatId'] = chatId;
        NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED, actionEventArgs);
      }
    });
  }

  private sortDialogs(): void {
    this.sortedDialogs.sort((a: Chat, b: Chat): number => {
      if (a.order > b.order) return -1;
      if (a.order < b.order) return 1;
      return 0;
    });
  }
}
