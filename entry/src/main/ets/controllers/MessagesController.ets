import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { NotificationService } from '../services/NotificationService';
import { Chat } from '../models/Chat';
import { Message, MessageContentType, MessageReaction } from '../models/Message';
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

interface TdChatPhoto {
  small?: TdFile;
  big?: TdFile;
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

// --- TDLib update interfaces ---
interface TdUpdateNewChat {
  chat?: TdChat;
}

interface TdUpdateChatLastMessage {
  chat_id?: number;
  last_message?: TdMessage;
  positions?: TdChatPosition[];
}

interface TdUpdateChatPosition {
  chat_id?: number;
  position?: TdChatPosition;
}

interface TdUpdateChatTitle {
  chat_id?: number;
  title?: string;
}

interface TdUpdateChatPhoto {
  chat_id?: number;
  photo?: TdChatPhoto;
}

interface TdUpdateDeleteMessages {
  chat_id?: number;
  message_ids?: number[];
}

interface TdUpdateNewMessage {
  message?: TdMessage;
}

interface TdUpdateMessageContent {
  chat_id?: number;
  message_id?: number;
  new_content?: TdMessageContent;
}

interface TdUpdateChatReadInbox {
  chat_id?: number;
  unread_count?: number;
}

interface TdUpdateChatNotificationSettings {
  chat_id?: number;
  notification_settings?: TdNotificationSettings;
}

interface TdUpdateChatAction {
  chat_id?: number;
  action?: TdChatAction;
}

interface ChatActionState {
  isActive: boolean;
  description: string;
}

interface TdUsernames {
  editable_username?: string;
  active_usernames?: string[];
}

interface TdUser {
  id?: number;
  first_name?: string;
  last_name?: string;
  username?: string;
  usernames?: TdUsernames;
  status?: Record<string, Object>;
}

interface TdUpdateUser {
  user?: TdUser;
}

interface TdUpdateUserStatus {
  user_id?: number;
  status?: Record<string, Object>;
}

interface TdMessageReactionInfo {
  reaction?: Record<string, Object>;
  total_count?: number;
  is_chosen?: boolean;
}

interface TdMessageInteractionInfo {
  reactions?: TdMessageReactionInfo[];
}

interface TdUpdateMessageInteractionInfo {
  chat_id?: number;
  message_id?: number;
  interaction_info?: TdMessageInteractionInfo;
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
      const data: TdUpdateNewChat = update as TdUpdateNewChat;
      const rawChat: TdChat | undefined = data.chat;
      if (!rawChat) return;

      const chat = this.parseChat(rawChat);
      this.chatsById.set(chat.id, chat);
      this.sortedDialogs.push(chat);
      this.sortDialogs();

      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatLastMessage', (update: Record<string, Object>) => {
      const data: TdUpdateChatLastMessage = update as TdUpdateChatLastMessage;
      const chatId: number = data.chat_id || 0;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const rawMsg: TdMessage | undefined = data.last_message;
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
      const positions: TdChatPosition[] | undefined = data.positions;
      if (positions) {
        this.updateChatPositions(chat, positions);
      }

      this.sortDialogs();
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatPosition', (update: Record<string, Object>) => {
      const data: TdUpdateChatPosition = update as TdUpdateChatPosition;
      const chatId: number = data.chat_id || 0;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const position: TdChatPosition | undefined = data.position;
      if (position) {
        this.updateChatPositions(chat, [position]);
        this.sortDialogs();
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateChatTitle', (update: Record<string, Object>) => {
      const data: TdUpdateChatTitle = update as TdUpdateChatTitle;
      const chatId: number = data.chat_id || 0;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const title: string = data.title || '';
      if (title.length === 0 || chat.title === title) return;

      chat.title = title;
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatPhoto', (update: Record<string, Object>) => {
      const data: TdUpdateChatPhoto = update as TdUpdateChatPhoto;
      const chatId: number = data.chat_id || 0;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const photo: TdChatPhoto | undefined = data.photo;
      const small: TdFile | undefined = photo?.small;
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
      const data: TdUpdateUser = update as TdUpdateUser;
      const rawUser: TdUser | undefined = data.user;
      if (!rawUser) return;

      const userId: number = this.upsertUser(rawUser);
      if (userId === 0) return;

      const eventArgs: Record<string, Object> = {};
      eventArgs['userId'] = userId;
      NotificationCenter.getInstance().post(EventId.USER_INFO_UPDATED, eventArgs);
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateUserStatus', (update: Record<string, Object>) => {
      const data: TdUpdateUserStatus = update as TdUpdateUserStatus;
      const userId: number = data.user_id || 0;
      const status: Record<string, Object> | undefined = data.status;
      if (userId === 0 || !status) return;

      this.applyUserStatus(userId, status);

      const eventArgs: Record<string, Object> = {};
      eventArgs['userId'] = userId;
      NotificationCenter.getInstance().post(EventId.USER_STATUS_UPDATED, eventArgs);
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateNewMessage', (update: Record<string, Object>) => {
      const data: TdUpdateNewMessage = update as TdUpdateNewMessage;
      const rawMsg: TdMessage | undefined = data.message;
      if (!rawMsg) return;

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
      const data: TdUpdateMessageContent = update as TdUpdateMessageContent;
      const chatId: number = data.chat_id || 0;
      const messageId: number = data.message_id || 0;
      const newContent: TdMessageContent | undefined = data.new_content;

      const messages = this.messagesByChat.get(chatId);
      if (messages && newContent) {
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
      const data: TdUpdateMessageInteractionInfo = update as TdUpdateMessageInteractionInfo;
      const chatId: number = data.chat_id || 0;
      const messageId: number = data.message_id || 0;
      const info: TdMessageInteractionInfo | undefined = data.interaction_info;
      if (chatId === 0 || messageId === 0 || !info) return;

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
      const data: TdUpdateDeleteMessages = update as TdUpdateDeleteMessages;
      const chatId: number = data.chat_id || 0;
      const deletedIds: number[] | undefined = data.message_ids;
      if (chatId === 0 || !deletedIds || deletedIds.length === 0) return;

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
      const data: TdUpdateChatReadInbox = update as TdUpdateChatReadInbox;
      const chatId: number = data.chat_id || 0;
      const unreadCount: number = data.unread_count || 0;
      const chat = this.chatsById.get(chatId);
      if (chat) {
        chat.unreadCount = unreadCount;
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateChatNotificationSettings', (update: Record<string, Object>) => {
      const data: TdUpdateChatNotificationSettings = update as TdUpdateChatNotificationSettings;
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
      const data: TdUpdateChatAction = update as TdUpdateChatAction;
      const chatId: number = data.chat_id || 0;
      const action: TdChatAction | undefined = data.action;
      const chat = this.chatsById.get(chatId);

      if (chat && action) {
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
    const usernames: TdUsernames | undefined = rawUser.usernames;

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
    const lastMsg: TdMessage | undefined = raw.last_message;
    const positions: TdChatPosition[] | undefined = raw.positions;
    const notifSettings: TdNotificationSettings | undefined = raw.notification_settings;

    const chat = new Chat(
      raw.id || 0,
      raw.title || '',
      lastMsg ? this.extractTextPreview(lastMsg) : '',
      lastMsg ? (lastMsg.date || 0) : 0,
      raw.unread_count || 0,
      null,
      false,
      false,
      false
    );

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

    // Mute status
    if (notifSettings) {
      const muteFor: number = notifSettings.mute_for || 0;
      chat.isMuted = muteFor > 0;
    }

    // Positions / pinned / order
    if (positions) {
      this.updateChatPositions(chat, positions);
    }

    return chat;
  }

  private updateChatPositions(chat: Chat, positions: TdChatPosition[]): void {
    for (const pos of positions) {
      const list: Record<string, Object> | undefined = pos.list;
      if (list && tdType(list) === 'chatListMain') {
        chat.order = pos.order || '0';
        chat.isPinned = pos.is_pinned || false;
      }
    }
  }

  parseMessage(raw: TdMessage): Message {
    const content: TdMessageContent | undefined = raw.content;
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

    const msg = new Message(
      raw.id || 0,
      raw.chat_id || 0,
      senderUserId,
      senderName,
      '',
      raw.date || 0,
      raw.is_outgoing || false,
      false,
      0,
      MessageContentType.TEXT,
      null,
      null
    );

    // Reply
    const replyTo: TdReplyTo | undefined = raw.reply_to;
    if (replyTo && tdType(replyTo as Record<string, Object>) === 'messageReplyToMessage') {
      msg.replyToMessageId = replyTo.message_id || 0;
    }

    // Forward
    const forwardInfo: TdForwardInfo | undefined = raw.forward_info;
    if (forwardInfo) {
      const origin: TdMessageOrigin | undefined = forwardInfo.origin;
      if (origin) {
        msg.forwardedFrom = origin.sender_name || '';
      }
    }

    // Media album grouping
    const albumId: string | undefined = raw.media_album_id;
    if (albumId && albumId !== '0') {
      msg.mediaAlbumId = albumId;
    }

    // Scheduling state
    const scheduling: TdSchedulingState | undefined = raw.scheduling_state;
    if (scheduling) {
      const schedType: string = tdType(scheduling as Record<string, Object>);
      if (schedType === 'messageSchedulingStateSendAtDate') {
        msg.schedulingState = scheduling.send_date || 0;
      }
    }

    // Self-destruct
    const selfDestruct: TdSelfDestructType | undefined = raw.self_destruct_type;
    if (selfDestruct) {
      msg.selfDestructIn = selfDestruct.self_destruct_time || 0;
      const sdType: string = tdType(selfDestruct as Record<string, Object>);
      if (sdType === 'messageSelfDestructTypeImmediately') {
        msg.isViewOnce = true;
      }
    }

    // Spoiler + content
    if (content) {
      if (content.has_spoiler === true) {
        msg.hasSpoiler = true;
      }
      this.applyContent(msg, content);
    }

    return msg;
  }

  private applyContent(msg: Message, content: TdMessageContent): void {
    const type: string = tdType(content as Record<string, Object>);

    switch (type) {
      case 'messageText': {
        msg.contentType = MessageContentType.TEXT;
        const textObj: TdFormattedText | undefined = content.text;
        msg.text = textObj?.text || '';
        break;
      }
      case 'messagePhoto': {
        msg.contentType = MessageContentType.PHOTO;
        const caption: TdFormattedText | undefined = content.caption;
        msg.text = caption?.text || '';
        break;
      }
      case 'messageVideo': {
        msg.contentType = MessageContentType.VIDEO;
        const video: TdVideo | undefined = content.video;
        msg.videoDuration = video?.duration || 0;
        const caption2: TdFormattedText | undefined = content.caption;
        msg.text = caption2?.text || '';
        break;
      }
      case 'messageDocument': {
        msg.contentType = MessageContentType.DOCUMENT;
        const doc: TdDocument | undefined = content.document;
        msg.fileName = doc?.file_name || 'Document';
        const caption3: TdFormattedText | undefined = content.caption;
        msg.text = caption3?.text || '';
        break;
      }
      case 'messageVoiceNote': {
        msg.contentType = MessageContentType.VOICE;
        const voice: TdVoiceNote | undefined = content.voice_note;
        msg.voiceDuration = voice?.duration || 0;
        const waveform: string | undefined = voice?.waveform;
        if (waveform) {
          msg.voiceWaveform = this.decodeWaveform(waveform);
        }
        break;
      }
      case 'messageSticker': {
        msg.contentType = MessageContentType.STICKER;
        const sticker: TdSticker | undefined = content.sticker;
        msg.text = sticker?.emoji || '';
        break;
      }
      case 'messageAnimation': {
        msg.contentType = MessageContentType.ANIMATION;
        msg.text = 'GIF';
        break;
      }
      case 'messageVideoNote': {
        msg.contentType = MessageContentType.VIDEO_NOTE;
        const videoNote: TdVideoNote | undefined = content.video_note;
        msg.videoNoteDuration = videoNote?.duration || 0;
        msg.videoNoteLength = videoNote?.length || 240;
        const vnFile: TdFile | undefined = videoNote?.video;
        if (vnFile) {
          msg.videoNoteFileId = vnFile.id || 0;
        }
        break;
      }
      case 'messagePoll': {
        msg.contentType = MessageContentType.POLL;
        const poll: TdPoll | undefined = content.poll;
        if (poll) {
          msg.pollId = poll.id || '';
          msg.pollQuestion = poll.question?.text || '';
          msg.pollTotalVoterCount = poll.total_voter_count || 0;
          msg.pollIsClosed = poll.is_closed || false;
          msg.pollIsAnonymous = poll.is_anonymous !== false;

          const pt: TdPollType | undefined = poll.type;
          msg.pollType = (pt ? tdType(pt as Record<string, Object>) : '') === 'pollTypeQuiz' ? 'quiz' : 'regular';

          const opts: TdPollOption[] | undefined = poll.options;
          if (opts) {
            msg.pollOptions = opts.map((opt: TdPollOption): PollOptionDisplay => {
              const displayOpt: PollOptionDisplay = {
                text: opt.text?.text || '',
                voterCount: opt.voter_count || 0,
                votePercentage: opt.vote_percentage || 0,
                isChosen: opt.is_chosen || false
              };
              return displayOpt;
            });
          }
        }
        break;
      }
      default: {
        const knownText: string | undefined = this.buildKnownContentText(type, content);
        if (knownText !== undefined) {
          msg.contentType = MessageContentType.TEXT;
          msg.text = knownText;
          break;
        }
        msg.contentType = MessageContentType.UNSUPPORTED;
        msg.text = `[${type.replace('message', '')}]`;
        break;
      }
    }
  }

  private extractTextPreview(rawMsg: TdMessage): string {
    const content: TdMessageContent | undefined = rawMsg.content;
    if (!content) return '';

    const type: string = tdType(content as Record<string, Object>);
    switch (type) {
      case 'messageText': {
        return content.text?.text || '';
      }
      case 'messagePhoto': return 'Photo';
      case 'messageVideo': return 'Video';
      case 'messageDocument': {
        return content.document?.file_name || 'Document';
      }
      case 'messageVoiceNote': return 'Voice message';
      case 'messageSticker': {
        return `${content.sticker?.emoji || ''} Sticker`;
      }
      case 'messageAnimation': return 'GIF';
      case 'messageVideoNote': return 'Video message';
      case 'messagePoll': {
        const question: string = content.poll?.question?.text || '';
        return `📊 ${question}`;
      }
      default: {
        const knownText: string | undefined = this.buildKnownContentText(type, content);
        if (knownText !== undefined) {
          return knownText;
        }
        return type.replace('message', '');
      }
    }
  }

  private buildKnownContentText(type: string, content: TdMessageContent): string | undefined {
    const payload: Record<string, Object> = content as Record<string, Object>;
    switch (type) {
      case 'messageContact': {
        const contact: Record<string, Object> | undefined = this.toRecord(payload['contact']);
        const firstName: string = safeString(contact?.['first_name']);
        const lastName: string = safeString(contact?.['last_name']);
        const phone: string = safeString(contact?.['phone_number']);
        const fullName: string = `${firstName} ${lastName}`.trim();
        if (fullName.length > 0 && phone.length > 0) return `👤 ${fullName} (${phone})`;
        if (fullName.length > 0) return `👤 ${fullName}`;
        if (phone.length > 0) return `👤 ${phone}`;
        return '👤 Contact';
      }
      case 'messageLocation': {
        const location: Record<string, Object> | undefined = this.toRecord(payload['location']);
        const latitude: number = safeNumber(location?.['latitude']);
        const longitude: number = safeNumber(location?.['longitude']);
        if (latitude !== 0 || longitude !== 0) {
          return `📍 ${latitude.toFixed(4)}, ${longitude.toFixed(4)}`;
        }
        return '📍 Location';
      }
      case 'messageLiveLocation': {
        const location: Record<string, Object> | undefined = this.toRecord(payload['location']);
        const latitude: number = safeNumber(location?.['latitude']);
        const longitude: number = safeNumber(location?.['longitude']);
        if (latitude !== 0 || longitude !== 0) {
          return `📡 Live location ${latitude.toFixed(4)}, ${longitude.toFixed(4)}`;
        }
        return '📡 Live location';
      }
      case 'messageVenue': {
        const venue: Record<string, Object> | undefined = this.toRecord(payload['venue']);
        const title: string = safeString(venue?.['title']);
        const address: string = safeString(venue?.['address']);
        if (title.length > 0 && address.length > 0) return `📍 ${title} - ${address}`;
        if (title.length > 0) return `📍 ${title}`;
        return '📍 Venue';
      }
      case 'messageGame': {
        const game: Record<string, Object> | undefined = this.toRecord(payload['game']);
        const title: string = safeString(game?.['title']);
        return title.length > 0 ? `🎮 ${title}` : '🎮 Game';
      }
      case 'messageInvoice': {
        const invoice: Record<string, Object> | undefined = this.toRecord(payload['invoice']);
        const title: string = safeString(invoice?.['title']);
        return title.length > 0 ? `💳 ${title}` : '💳 Invoice';
      }
      case 'messageCall': {
        return this.buildCallText(payload);
      }
      case 'messageDice': {
        const dice: Record<string, Object> | undefined = this.toRecord(payload['dice']);
        const emoji: string = safeString(dice?.['emoji']) || '🎲';
        const value: number = safeNumber(dice?.['value']);
        return value > 0 ? `${emoji} ${value}` : `${emoji} Dice`;
      }
      case 'messageProximityAlertTriggered': {
        const distance: number = safeNumber(payload['distance']);
        return distance > 0 ? `⚠️ Proximity alert (${distance} m)` : '⚠️ Proximity alert';
      }
      case 'messageScreenshotTaken': return '📷 Screenshot taken';
      case 'messageChatSetTtl': {
        const ttl: number = safeNumber(payload['ttl']);
        return ttl > 0 ? `🔒 Messages auto-delete in ${this.formatDuration(ttl)}` : '🔒 Auto-delete timer changed';
      }
      case 'messageChatChangeTitle': {
        const title: string = safeString(payload['title']);
        return title.length > 0 ? `✏️ Chat title changed to "${title}"` : '✏️ Chat title changed';
      }
      case 'messageChatChangePhoto': return '🖼️ Chat photo changed';
      case 'messageChatDeletePhoto': return '🗑️ Chat photo removed';
      case 'messageChatAddMembers': {
        const membersValue: Object | undefined = payload['member_user_ids'];
        if (Array.isArray(membersValue)) {
          const count: number = membersValue.length;
          if (count > 0) return `👥 Added ${count} member${count > 1 ? 's' : ''}`;
        }
        return '👥 Members added';
      }
      case 'messageChatJoinByLink': return '🔗 Joined via invite link';
      case 'messageChatDeleteMember': return '👤 Member removed';
      case 'messageChatUpgradeTo': return '⬆️ Group upgraded to supergroup';
      case 'messageChatUpgradeFrom': return '⬆️ Group upgraded';
      case 'messagePinMessage': return '📌 Message pinned';
      case 'messageGameScore': return '🏆 Game score updated';
      case 'messagePaymentSuccessful': return '✅ Payment successful';
      case 'messageContactRegistered': return '🎉 Contact joined Telegram';
      case 'messageCustomServiceAction': {
        const text: string = safeString(payload['text']);
        return text.length > 0 ? text : 'ℹ️ Service message';
      }
      case 'messageUnsupported': return 'Unsupported message';
      default: return undefined;
    }
  }

  private buildCallText(payload: Record<string, Object>): string {
    const call: Record<string, Object> | undefined = this.toRecord(payload['call']);
    const duration: number = safeNumber(call?.['duration']);
    const isVideo: boolean = safeBool(call?.['is_video']);
    const discardReason: Record<string, Object> | undefined = this.toRecord(call?.['discard_reason']);
    const reasonType: string = discardReason ? tdType(discardReason) : '';

    if (reasonType === 'callDiscardReasonMissed') {
      return isVideo ? '📹 Missed video call' : '📞 Missed call';
    }
    if (reasonType === 'callDiscardReasonDeclined') {
      return isVideo ? '📹 Declined video call' : '📞 Declined call';
    }
    if (duration > 0) {
      return `${isVideo ? '📹 Video call' : '📞 Call'} (${this.formatDuration(duration)})`;
    }
    return isVideo ? '📹 Video call' : '📞 Call';
  }

  private formatDuration(totalSeconds: number): string {
    if (totalSeconds <= 0) return '0s';
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const seconds: number = totalSeconds % 60;
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    if (minutes > 0) {
      return `${minutes}m ${seconds}s`;
    }
    return `${seconds}s`;
  }

  private toRecord(value: Object | undefined | null): Record<string, Object> | undefined {
    if (value === undefined || value === null) return undefined;
    return value as Record<string, Object>;
  }

  private decodeWaveform(base64: string): number[] {
    // TDLib sends waveform as base64-encoded packed 5-bit amplitude values
    // Each 5 bits encode a value 0-31, normalized to 0.0-1.0
    try {
      const raw: number[] = this.base64ToBytes(base64);
      if (raw.length === 0) return this.fallbackWaveform();

      const result: number[] = [];
      let bitIndex: number = 0;
      const totalBits: number = raw.length * 8;

      while (bitIndex + 5 <= totalBits) {
        const byteOffset: number = Math.floor(bitIndex / 8);
        const bitOffset: number = bitIndex % 8;

        let value: number;
        if (bitOffset <= 3) {
          value = (raw[byteOffset] >> bitOffset) & 0x1F;
        } else {
          const bitsFromFirst: number = 8 - bitOffset;
          const bitsFromSecond: number = 5 - bitsFromFirst;
          value = ((raw[byteOffset] >> bitOffset) & ((1 << bitsFromFirst) - 1))
            | (((raw[byteOffset + 1] || 0) & ((1 << bitsFromSecond) - 1)) << bitsFromFirst);
        }

        result.push(value / 31.0);
        bitIndex += 5;
      }

      return result.length > 0 ? result : this.fallbackWaveform();
    } catch (_e) {
      return this.fallbackWaveform();
    }
  }

  private base64ToBytes(base64: string): number[] {
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const bytes: number[] = [];
    let buffer: number = 0;
    let bitsCollected: number = 0;

    for (let i: number = 0; i < base64.length; i++) {
      const c: string = base64.charAt(i);
      if (c === '=') break;
      const idx: number = chars.indexOf(c);
      if (idx < 0) continue;

      buffer = (buffer << 6) | idx;
      bitsCollected += 6;

      while (bitsCollected >= 8) {
        bitsCollected -= 8;
        bytes.push((buffer >> bitsCollected) & 0xFF);
      }
    }

    return bytes;
  }

  private fallbackWaveform(): number[] {
    const result: number[] = [];
    for (let i: number = 0; i < 32; i++) {
      result.push(0.3);
    }
    return result;
  }

  private sortDialogs(): void {
    this.sortedDialogs.sort((a: Chat, b: Chat): number => {
      if (a.order > b.order) return -1;
      if (a.order < b.order) return 1;
      return 0;
    });
  }
}
