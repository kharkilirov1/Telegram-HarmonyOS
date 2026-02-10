import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { NotificationService } from '../services/NotificationService';
import { Chat } from '../models/Chat';
import { Message, MessageContentType, MessageReaction } from '../models/Message';
import {
  TdChatPhoto,
  TdMessageInteractionInfo,
  TdMessageReactionInfo,
  TdUser,
  parseUpdateChatAction,
  parseUpdateChatLastMessage,
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
} from './messages/TdUpdateParser';
import {
  applyContent as parseTdMessageContent,
  extractTextPreview as parseTdPreview,
  parseChat as parseTdChat,
  parseMessage as parseTdMessage,
  updateChatPositions as parseTdUpdateChatPositions
} from './TdMessageParser';
import {
  TdChat as TdModelChat,
  TdChatPosition as TdModelChatPosition,
  TdMessage as TdModelMessage,
  TdMessageContent as TdModelMessageContent
} from '../models/TdTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'MessagesController';
const DOMAIN = 0x0001;

// --- TDLib response interfaces for ArkTS strict typing ---

function tdType(obj: Record<string, Object>): string {
  return (obj['@type'] as string) || '';
}

interface PollOptionDisplay {
  text: string;
  voterCount: number;
  votePercentage: number;
  isChosen: boolean;
}

interface TdMessageSender {
  user_id?: number;
  chat_id?: number;
}

interface TdFormattedText {
  text: string;
}

interface TdFile {
  id: number;
  local?: TdLocalFile;
}

interface TdLocalFile {
  path: string;
  is_downloading_completed: boolean;
}

interface TdPhoto {
  sizes?: TdPhotoSize[];
}

interface TdPhotoSize {
  photo?: TdFile;
  width?: number;
  height?: number;
}

interface TdMessageContent {
  text?: TdFormattedText;
  caption?: TdFormattedText;
  photo?: TdPhoto;
  video?: TdVideo;
  document?: TdDocument;
  voice_note?: TdVoiceNote;
  video_note?: TdVideoNote;
  sticker?: TdSticker;
  poll?: TdPoll;
  has_spoiler?: boolean;
}

interface TdVideo {
  duration: number;
  video?: TdFile;
}

interface TdDocument {
  file_name: string;
  document?: TdFile;
}

interface TdVoiceNote {
  duration: number;
  waveform: string;
}

interface TdVideoNote {
  duration: number;
  length: number;
  video?: TdFile;
}

interface TdSticker {
  emoji: string;
  sticker?: TdFile;
}

interface TdPollOption {
  text?: TdFormattedText;
  voter_count: number;
  vote_percentage: number;
  is_chosen: boolean;
}

interface TdPollType {
  allow_multiple_answers?: boolean;
  correct_option_id?: number;
}

interface TdPoll {
  id: string;
  question?: TdFormattedText;
  options?: TdPollOption[];
  total_voter_count: number;
  is_closed: boolean;
  is_anonymous: boolean;
  type?: TdPollType;
}

interface TdReplyTo {
  message_id?: number;
}

interface TdForwardInfo {
  origin?: TdMessageOrigin;
}

interface TdMessageOrigin {
  sender_name?: string;
}

interface TdSchedulingState {
  send_date?: number;
}

interface TdSelfDestructType {
  self_destruct_time?: number;
}

interface TdChatPosition {
  list?: Record<string, Object>;
  order?: string;
  is_pinned?: boolean;
}

interface TdChatType {
  is_channel?: boolean;
}

interface TdNotificationSettings {
  mute_for?: number;
}

interface TdChatAction {
  // empty - identified by @type
}

// --- TDLib raw message ---
interface TdMessage {
  id: number;
  chat_id: number;
  sender_id?: TdMessageSender;
  content?: TdMessageContent;
  date: number;
  is_outgoing: boolean;
  reply_to?: TdReplyTo;
  forward_info?: TdForwardInfo;
  media_album_id?: string;
  scheduling_state?: TdSchedulingState;
  self_destruct_type?: TdSelfDestructType;
}

// --- TDLib raw chat ---
interface TdChat {
  id: number;
  title: string;
  last_message?: TdMessage;
  positions?: TdChatPosition[];
  notification_settings?: TdNotificationSettings;
  unread_count?: number;
  type?: TdChatType;
}

interface ChatActionState {
  isActive: boolean;
  description: string;
}

interface CachedUser {
  id: number;
  firstName: string;
  lastName: string;
  username: string;
  isOnline: boolean;
  lastSeenDate: number;
}

// --- TDLib response wrappers ---
interface TdMessages {
  messages?: TdMessage[];
}

// --- Safe accessor helpers ---

function safeNumber(value: Object | undefined | null): number {
  if (value === undefined || value === null) return 0;
  if (typeof value === 'number') return value as number;
  return 0;
}

function safeString(value: Object | undefined | null): string {
  if (value === undefined || value === null) return '';
  if (typeof value === 'string') return value as string;
  return '';
}

function safeBool(value: Object | undefined | null): boolean {
  if (value === undefined || value === null) return false;
  if (typeof value === 'boolean') return value as boolean;
  return false;
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
    if (replyToParam) {
      sendScheduledParams['reply_to'] = replyToParam;
    }
    sendScheduledParams['input_message_content'] = inputContent;
    sendScheduledParams['scheduling_state'] = schedulingState;
    await TDLibClient.getInstance().send('sendMessage', sendScheduledParams);
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
    const result: TdMessages = await TDLibClient.getInstance().send('getChatScheduledMessages', scheduledParams) as TdMessages;
    const rawMessages: TdMessage[] | undefined = result.messages;
    if (!rawMessages) return [];
    return rawMessages.map((raw: TdMessage): Message => this.parseMessage(raw));
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
      searchParams['from_message_id'] = fromMessageId;
      searchParams['offset'] = 0;
      searchParams['limit'] = limit;
      searchParams['message_thread_id'] = 0;
      if (senderParam) {
        searchParams['sender_id'] = senderParam;
      }
      if (filterParam) {
        searchParams['filter'] = filterParam;
      }
      const result: TdMessages = await TDLibClient.getInstance().send('searchChatMessages', searchParams) as TdMessages;
      const rawMessages: TdMessage[] | undefined = result.messages;
      if (!rawMessages) return [];
      return rawMessages.map((raw: TdMessage): Message => this.parseMessage(raw));
    } catch (_e) {
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
      if (draftReplyTo) {
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
      const parsed = parseUpdateNewChat(update);
      if (!parsed) return;
      const rawChat = parsed.chat as TdChat;

      const chat = this.parseChat(rawChat);
      this.chatsById.set(chat.id, chat);
      this.sortedDialogs.push(chat);
      this.sortDialogs();

      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatLastMessage', (update: Record<string, Object>) => {
      const parsed = parseUpdateChatLastMessage(update);
      if (!parsed) return;
      const chatId: number = parsed.chatId;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const rawMsg = parsed.lastMessage as TdMessage | undefined;
      if (rawMsg) {
        chat.lastMessage = this.extractTextPreview(rawMsg);
        chat.lastMessageDate = rawMsg.date || 0;

        const sender: TdMessageSender | undefined = rawMsg.sender_id;
        if (sender && tdType(sender as Record<string, Object>) === 'messageSenderUser') {
          const senderUserId: number = sender.user_id || 0;
          chat.lastMessageSenderId = senderUserId;
          chat.lastMessageSenderName = this.getUserDisplayName(senderUserId);
          if (senderUserId > 0 && chat.lastMessageSenderName.length === 0) {
            this.loadUserIfMissing(senderUserId);
          }
        }
      }

      // Update positions if provided
      const positions = parsed.positions;
      if (positions) {
        this.updateChatPositions(chat, positions);
      }

      this.sortDialogs();
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatPosition', (update: Record<string, Object>) => {
      const parsed = parseUpdateChatPosition(update);
      if (!parsed) return;
      const chatId: number = parsed.chatId;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      this.updateChatPositions(chat, [parsed.position]);
      this.sortDialogs();
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatTitle', (update: Record<string, Object>) => {
      const parsed = parseUpdateChatTitle(update);
      if (!parsed) return;
      const chatId: number = parsed.chatId;
      const chat = this.chatsById.get(chatId);
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
      const chat = this.chatsById.get(chatId);
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

    client.on('updateUser', (update: Record<string, Object>) => {
      const parsed = parseUpdateUser(update);
      if (!parsed) return;
      const rawUser = parsed.user;

      const userId: number = this.upsertUser(rawUser);
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

      this.applyUserStatus(userId, status);

      const eventArgs: Record<string, Object> = {};
      eventArgs['userId'] = userId;
      NotificationCenter.getInstance().post(EventId.USER_STATUS_UPDATED, eventArgs);
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateNewMessage', (update: Record<string, Object>) => {
      const parsed = parseUpdateNewMessage(update);
      if (!parsed) return;
      const rawMsg = parsed.message as TdMessage;

      const msg = this.parseMessage(rawMsg);
      const chatMessages = this.messagesByChat.get(msg.chatId) || [];

      // Avoid duplicates
      if (!chatMessages.find((m: Message): boolean => m.id === msg.id)) {
        chatMessages.push(msg);
        chatMessages.sort((a: Message, b: Message): number => a.id - b.id);
        this.messagesByChat.set(msg.chatId, chatMessages);
      }

      const eventArgs: Record<string, Object> = {};
      eventArgs['chatId'] = msg.chatId;
      eventArgs['message'] = msg;
      NotificationCenter.getInstance().post(EventId.NEW_MESSAGE, eventArgs);

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
      const parsed = parseUpdateMessageContent(update);
      if (!parsed) return;
      const chatId: number = parsed.chatId;
      const messageId: number = parsed.messageId;
      const newContent = parsed.newContent as TdMessageContent;

      const messages = this.messagesByChat.get(chatId);
      if (messages) {
        const msg = messages.find((m: Message): boolean => m.id === messageId);
        if (msg) {
          this.applyContent(msg, newContent);
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

      const messages = this.messagesByChat.get(chatId);
      if (!messages) return;

      const msg = messages.find((m: Message): boolean => m.id === messageId);
      if (!msg) return;

      this.applyInteractionInfo(msg, info);

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

      const messages = this.messagesByChat.get(chatId);
      if (messages) {
        const deletedSet: Set<number> = new Set(deletedIds);
        const filtered: Message[] = messages.filter((m: Message): boolean => !deletedSet.has(m.id));
        this.messagesByChat.set(chatId, filtered);
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
      const chat = this.chatsById.get(chatId);
      if (chat) {
        chat.unreadCount = unreadCount;
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateChatNotificationSettings', (update: Record<string, Object>) => {
      const parsed = parseUpdateChatNotificationSettings(update);
      if (!parsed) return;
      const chatId: number = parsed.chatId;
      const settings = parsed.settings;
      const chat = this.chatsById.get(chatId);
      if (chat) {
        const muteFor: number = settings.mute_for || 0;
        chat.isMuted = muteFor > 0;
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateChatAction', (update: Record<string, Object>) => {
      const parsed = parseUpdateChatAction(update);
      if (!parsed) return;
      const chatId: number = parsed.chatId;
      const action = parsed.action;
      const chat = this.chatsById.get(chatId);

      if (chat) {
        const actionType: string = tdType(action as Record<string, Object>);
        const chatActionState: ChatActionState = this.mapChatActionState(actionType);
        if (chatActionState.isActive) {
          chat.isTyping = true;
          chat.typingDescription = chatActionState.description;

          // Ephemeral action state; Telegram also clears typing-like indicators quickly.
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
  }

  private getUserDisplayName(userId: number): string {
    const user: CachedUser | undefined = this.usersById.get(userId);
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

  private upsertUser(rawUser: TdUser): number {
    const userId: number = rawUser.id || 0;
    if (userId === 0) return 0;

    const existing: CachedUser | undefined = this.usersById.get(userId);
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
      this.applyStatusToUser(user, status);
    }

    this.usersById.set(userId, user);
    this.refreshUserPresentation(userId);
    return userId;
  }

  private applyUserStatus(userId: number, status: Record<string, Object>): void {
    let user: CachedUser | undefined = this.usersById.get(userId);
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

    this.applyStatusToUser(user, status);
    this.usersById.set(userId, user);
    this.refreshUserPresentation(userId);
  }

  private applyStatusToUser(user: CachedUser, status: Record<string, Object>): void {
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

  private refreshUserPresentation(userId: number): void {
    const user: CachedUser | undefined = this.usersById.get(userId);
    if (!user) return;

    const displayName: string = this.getUserDisplayName(userId);

    this.messagesByChat.forEach((messages: Message[]) => {
      for (const message of messages) {
        if (message.senderId === userId) {
          message.senderName = displayName;
        }
      }
    });

    this.chatsById.forEach((chat: Chat) => {
      if (chat.lastMessageSenderId === userId) {
        chat.lastMessageSenderName = displayName;
      }
    });

    const privateChats: Set<number> | undefined = this.privateChatIdsByUserId.get(userId);
    if (!privateChats) return;

    for (const chatId of privateChats) {
      const privateChat: Chat | undefined = this.chatsById.get(chatId);
      if (!privateChat) continue;
      if (displayName.length > 0) {
        privateChat.title = displayName;
      }
      privateChat.isUserOnline = user.isOnline;
      privateChat.lastSeenDate = user.lastSeenDate;
    }
  }

  private registerPrivateChatUser(chatId: number, userId: number): void {
    if (chatId === 0 || userId === 0) return;

    const previousUserId: number | undefined = this.privateChatUserByChatId.get(chatId);
    if (previousUserId && previousUserId !== userId) {
      const oldSet: Set<number> | undefined = this.privateChatIdsByUserId.get(previousUserId);
      if (oldSet) {
        oldSet.delete(chatId);
      }
    }

    this.privateChatUserByChatId.set(chatId, userId);
    let set: Set<number> | undefined = this.privateChatIdsByUserId.get(userId);
    if (!set) {
      set = new Set<number>();
      this.privateChatIdsByUserId.set(userId, set);
    }
    set.add(chatId);
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
      const resolvedUserId: number = this.upsertUser(raw);
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

  private applyInteractionInfo(msg: Message, info: TdMessageInteractionInfo): void {
    const reactions: TdMessageReactionInfo[] | undefined = info.reactions;
    if (!reactions) return;

    const mappedReactions: MessageReaction[] = [];
    for (const reactionInfo of reactions) {
      const count: number = reactionInfo.total_count || 0;
      if (count <= 0) continue;

      const emoji: string = this.resolveReactionEmoji(reactionInfo.reaction);
      if (emoji.length === 0) continue;

      const mapped: MessageReaction = {
        emoji: emoji,
        count: count,
        isMine: reactionInfo.is_chosen === true
      };
      mappedReactions.push(mapped);
    }

    msg.reactions = mappedReactions;
  }

  private resolveReactionEmoji(reaction: Record<string, Object> | undefined): string {
    if (!reaction) return '';

    const reactionType: string = tdType(reaction);
    if (reactionType === 'reactionTypeEmoji') {
      return safeString(reaction['emoji']);
    }
    if (reactionType === 'reactionTypeCustomEmoji') {
      return '⭐';
    }
    if (reactionType === 'reactionTypePaid') {
      return '⭐';
    }
    return '';
  }

  private mapChatActionState(actionType: string): ChatActionState {
    switch (actionType) {
      case 'chatActionTyping':
        return { isActive: true, description: 'typing...' };
      case 'chatActionRecordingVoiceNote':
        return { isActive: true, description: 'recording voice...' };
      case 'chatActionUploadingVoiceNote':
        return { isActive: true, description: 'uploading voice...' };
      case 'chatActionRecordingVideoNote':
        return { isActive: true, description: 'recording video message...' };
      case 'chatActionUploadingVideoNote':
        return { isActive: true, description: 'uploading video message...' };
      case 'chatActionRecordingVideo':
        return { isActive: true, description: 'recording video...' };
      case 'chatActionUploadingVideo':
        return { isActive: true, description: 'uploading video...' };
      case 'chatActionUploadingPhoto':
        return { isActive: true, description: 'uploading photo...' };
      case 'chatActionUploadingDocument':
        return { isActive: true, description: 'uploading file...' };
      case 'chatActionChoosingSticker':
        return { isActive: true, description: 'choosing sticker...' };
      case 'chatActionChoosingLocation':
        return { isActive: true, description: 'choosing location...' };
      case 'chatActionChoosingContact':
        return { isActive: true, description: 'choosing contact...' };
      case 'chatActionStartPlayingGame':
        return { isActive: true, description: 'playing game...' };
      case 'chatActionWatchingAnimations':
        return { isActive: true, description: 'watching animations...' };
      case 'chatActionImportingMessages':
        return { isActive: true, description: 'importing messages...' };
      case 'chatActionCancel':
      default:
        return { isActive: false, description: '' };
    }
  }

  // --- Parsing helpers ---

  private parseChat(raw: TdChat): Chat {
    const chat: Chat = parseTdChat(raw as TdModelChat);
    const lastMsg: TdMessage | undefined = raw.last_message;

    if (lastMsg) {
      const sender: TdMessageSender | undefined = lastMsg.sender_id;
      if (sender && tdType(sender as Record<string, Object>) === 'messageSenderUser') {
        const senderUserId: number = sender.user_id || 0;
        chat.lastMessageSenderId = senderUserId;
        chat.lastMessageSenderName = this.getUserDisplayName(senderUserId);
        if (senderUserId > 0 && chat.lastMessageSenderName.length === 0) {
          this.loadUserIfMissing(senderUserId);
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
          this.registerPrivateChatUser(chat.id, privateUserId);
          const displayName: string = this.getUserDisplayName(privateUserId);
          if (displayName.length > 0) {
            chat.title = displayName;
          }

          const cachedUser: CachedUser | undefined = this.usersById.get(privateUserId);
          if (cachedUser) {
            chat.isUserOnline = cachedUser.isOnline;
            chat.lastSeenDate = cachedUser.lastSeenDate;
          } else {
            this.loadUserIfMissing(privateUserId);
          }
        }
      }
    }

    return chat;
  }

  private updateChatPositions(chat: Chat, positions: TdChatPosition[]): void {
    parseTdUpdateChatPositions(chat, positions as TdModelChatPosition[]);
  }

  parseMessage(raw: TdMessage): Message {
    const msg: Message = parseTdMessage(raw as TdModelMessage);
    const sender: TdMessageSender | undefined = raw.sender_id;
    const senderUserId: number = sender?.user_id || 0;
    let senderName: string = senderUserId > 0 ? this.getUserDisplayName(senderUserId) : '';
    if (senderName.length === 0) {
      const senderChatId: number = sender?.chat_id || 0;
      const senderChat: Chat | undefined = this.chatsById.get(senderChatId);
      if (senderChat) {
        senderName = senderChat.title;
      }
    }
    if (senderUserId > 0 && senderName.length === 0) {
      this.loadUserIfMissing(senderUserId);
    }

    msg.senderId = senderUserId;
    msg.senderName = senderName;

    return msg;
  }

  private applyContent(msg: Message, content: TdMessageContent): void {
    parseTdMessageContent(msg, content as TdModelMessageContent);
  }

  private extractTextPreview(rawMsg: TdMessage): string {
    return parseTdPreview(rawMsg as TdModelMessage);
  }

  private sortDialogs(): void {
    this.sortedDialogs.sort((a: Chat, b: Chat): number => {
      if (a.order > b.order) return -1;
      if (a.order < b.order) return 1;
      return 0;
    });
  }
}
