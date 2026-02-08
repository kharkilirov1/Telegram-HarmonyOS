import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { NotificationService } from '../services/NotificationService';
import { Chat } from '../models/Chat';
import { Message, MessageContentType } from '../models/Message';
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

// --- TDLib update interfaces ---
interface TdUpdateNewChat {
  chat?: TdChat;
}

interface TdUpdateChatLastMessage {
  chat_id: number;
  last_message?: TdMessage;
  positions?: TdChatPosition[];
}

interface TdUpdateChatPosition {
  chat_id: number;
  position?: TdChatPosition;
}

interface TdUpdateNewMessage {
  message?: TdMessage;
}

interface TdUpdateMessageContent {
  chat_id: number;
  message_id: number;
  new_content?: TdMessageContent;
}

interface TdUpdateChatReadInbox {
  chat_id: number;
  unread_count: number;
}

interface TdUpdateChatNotificationSettings {
  chat_id: number;
  notification_settings?: TdNotificationSettings;
}

interface TdUpdateChatAction {
  chat_id: number;
  action?: TdChatAction;
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

  async deleteMessage(chatId: number, messageId: number): Promise<void> {
    const deleteParams: Record<string, Object> = {
      chat_id: chatId,
      message_ids: [messageId],
      revoke: true
    };
    await TDLibClient.getInstance().send('deleteMessages', deleteParams);

    // Remove from local cache
    const messages = this.messagesByChat.get(chatId);
    if (messages) {
      const idx = messages.findIndex((m: Message): boolean => m.id === messageId);
      if (idx >= 0) {
        messages.splice(idx, 1);
      }
    }

    const eventArgs: Record<string, Object> = { chatId: chatId, messageId: messageId };
    NotificationCenter.getInstance().post(EventId.MESSAGE_DELETED, eventArgs);
  }

  async sendPoll(chatId: number, question: string, options: string[],
    isAnonymous: boolean = true, isQuiz: boolean = false,
    correctOptionId: number = -1): Promise<void> {

    let pollTypeRecord: Record<string, Object>;
    if (isQuiz) {
      pollTypeRecord = { '@type': 'pollTypeQuiz', correct_option_id: correctOptionId };
    } else {
      pollTypeRecord = { '@type': 'pollTypeRegular', allow_multiple_answers: false };
    }

    const formattedQuestion: Record<string, Object> = { '@type': 'formattedText', text: question };
    const formattedOptions: Record<string, Object>[] = options.map((o: string): Record<string, Object> => {
      const opt: Record<string, Object> = { '@type': 'formattedText', text: o };
      return opt;
    });
    const inputMessageContent: Record<string, Object> = {
      '@type': 'inputMessagePoll',
      question: formattedQuestion,
      options: formattedOptions,
      is_anonymous: isAnonymous,
      type: pollTypeRecord
    };
    const sendPollParams: Record<string, Object> = {
      chat_id: chatId,
      input_message_content: inputMessageContent
    };
    await TDLibClient.getInstance().send('sendMessage', sendPollParams);
  }

  async sendScheduledMessage(chatId: number, text: string, sendDate: number,
    replyToMessageId: number = 0): Promise<void> {
    let replyToParam: Record<string, Object> | undefined = undefined;
    if (replyToMessageId > 0) {
      replyToParam = { '@type': 'inputMessageReplyToMessage', message_id: replyToMessageId };
    }

    const formattedText: Record<string, Object> = { '@type': 'formattedText', text: text };
    const inputContent: Record<string, Object> = {
      '@type': 'inputMessageText',
      text: formattedText
    };
    const schedulingState: Record<string, Object> = {
      '@type': 'messageSchedulingStateSendAtDate',
      send_date: sendDate
    };
    const sendScheduledParams: Record<string, Object> = {
      chat_id: chatId,
      reply_to: replyToParam as Object,
      input_message_content: inputContent,
      scheduling_state: schedulingState
    };
    await TDLibClient.getInstance().send('sendMessage', sendScheduledParams);
  }

  async votePoll(chatId: number, messageId: number, optionIds: number[]): Promise<void> {
    const voteParams: Record<string, Object> = {
      chat_id: chatId,
      message_id: messageId,
      option_ids: optionIds
    };
    await TDLibClient.getInstance().send('setPollAnswer', voteParams);
  }

  async getScheduledMessages(chatId: number): Promise<Message[]> {
    const scheduledParams: Record<string, Object> = {
      chat_id: chatId
    };
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
        senderParam = { '@type': 'messageSenderUser', user_id: senderId };
      }

      // Map filter string to TDLib searchMessagesFilter type
      let filterParam: Record<string, Object> | undefined = undefined;
      switch (filter) {
        case 'photo':
          filterParam = { '@type': 'searchMessagesFilterPhoto' };
          break;
        case 'video':
          filterParam = { '@type': 'searchMessagesFilterVideo' };
          break;
        case 'document':
          filterParam = { '@type': 'searchMessagesFilterDocument' };
          break;
        case 'url':
          filterParam = { '@type': 'searchMessagesFilterUrl' };
          break;
        default:
          break;
      }

      const searchParams: Record<string, Object> = {
        chat_id: chatId,
        query: query,
        sender_id: senderParam as Object,
        from_message_id: fromMessageId,
        offset: 0,
        limit: limit,
        filter: filterParam as Object,
        message_thread_id: 0
      };
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
      const clearDraftParams: Record<string, Object> = {
        chat_id: chatId,
        draft_message: undefined as Object
      };
      await TDLibClient.getInstance().send('setChatDraftMessage', clearDraftParams);
    } else {
      let draftReplyTo: Record<string, Object> | undefined = undefined;
      if (replyToMessageId > 0) {
        draftReplyTo = { '@type': 'inputMessageReplyToMessage', message_id: replyToMessageId };
      }

      const draftFormattedText: Record<string, Object> = { '@type': 'formattedText', text: text };
      const draftInputMessageText: Record<string, Object> = {
        '@type': 'inputMessageText',
        text: draftFormattedText
      };
      const draftMessage: Record<string, Object> = {
        '@type': 'draftMessage',
        reply_to: draftReplyTo as Object,
        input_message_text: draftInputMessageText
      };
      const setDraftParams: Record<string, Object> = {
        chat_id: chatId,
        draft_message: draftMessage
      };
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
          chat.lastMessageSenderId = sender.user_id || 0;
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

      const eventArgs: Record<string, Object> = { chatId: msg.chatId, message: msg };
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
          const eventArgs: Record<string, Object> = { chatId: chatId, messageId: messageId };
          NotificationCenter.getInstance().post(EventId.MESSAGE_EDITED, eventArgs);
        }
      }
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
        if (actionType === 'chatActionTyping') {
          chat.isTyping = true;
          chat.typingDescription = 'typing...';

          // Auto-clear after 5 seconds
          setTimeout(() => {
            chat.isTyping = false;
            chat.typingDescription = '';
            const eventArgs: Record<string, Object> = { chatId: chatId };
            NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED, eventArgs);
          }, 5000);
        } else if (actionType === 'chatActionCancel') {
          chat.isTyping = false;
          chat.typingDescription = '';
        }

        const eventArgs: Record<string, Object> = { chatId: chatId };
        NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED, eventArgs);
      }
    });
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

    // Determine type
    const chatType: TdChatType | undefined = raw.type;
    if (chatType) {
      const t: string = tdType(chatType as Record<string, Object>);
      chat.isGroup = t === 'chatTypeSupergroup' || t === 'chatTypeBasicGroup';
      chat.isChannel = t === 'chatTypeSupergroup' && (chatType.is_channel === true);
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

    const msg = new Message(
      raw.id || 0,
      raw.chat_id || 0,
      sender?.user_id || 0,
      '',
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
      default: return type.replace('message', '');
    }
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
