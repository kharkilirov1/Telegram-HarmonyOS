import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { NotificationService } from '../services/NotificationService';
import { Chat } from '../models/Chat';
import { Message, MessageContentType } from '../models/Message';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'MessagesController';
const DOMAIN = 0x0001;

// --- TDLib response interfaces for ArkTS strict typing ---

interface TdObject {
  '@type': string;
}

interface TdMessageSender extends TdObject {
  user_id?: number;
  chat_id?: number;
}

interface TdFormattedText {
  '@type': string;
  text: string;
}

interface TdFile extends TdObject {
  id: number;
  local?: TdLocalFile;
}

interface TdLocalFile {
  path: string;
  is_downloading_completed: boolean;
}

interface TdPhoto extends TdObject {
  sizes?: TdPhotoSize[];
}

interface TdPhotoSize extends TdObject {
  photo?: TdFile;
  width?: number;
  height?: number;
}

interface TdMessageContent extends TdObject {
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

interface TdVideo extends TdObject {
  duration: number;
  video?: TdFile;
}

interface TdDocument extends TdObject {
  file_name: string;
  document?: TdFile;
}

interface TdVoiceNote extends TdObject {
  duration: number;
  waveform: string;
}

interface TdVideoNote extends TdObject {
  duration: number;
  length: number;
  video?: TdFile;
}

interface TdSticker extends TdObject {
  emoji: string;
  sticker?: TdFile;
}

interface TdPollOption {
  text?: TdFormattedText;
  voter_count: number;
  vote_percentage: number;
  is_chosen: boolean;
}

interface TdPollType extends TdObject {
  allow_multiple_answers?: boolean;
  correct_option_id?: number;
}

interface TdPoll extends TdObject {
  id: string;
  question?: TdFormattedText;
  options?: TdPollOption[];
  total_voter_count: number;
  is_closed: boolean;
  is_anonymous: boolean;
  type?: TdPollType;
}

interface TdReplyTo extends TdObject {
  message_id?: number;
}

interface TdForwardInfo {
  origin?: TdMessageOrigin;
}

interface TdMessageOrigin extends TdObject {
  sender_name?: string;
}

interface TdSchedulingState extends TdObject {
  send_date?: number;
}

interface TdSelfDestructType extends TdObject {
  self_destruct_time?: number;
}

interface TdChatPosition extends TdObject {
  list?: TdObject;
  order?: string;
  is_pinned?: boolean;
}

interface TdChatType extends TdObject {
  is_channel?: boolean;
}

interface TdNotificationSettings extends TdObject {
  mute_for?: number;
}

interface TdChatAction extends TdObject {
  // empty - identified by @type
}

// --- TDLib raw message ---
interface TdMessage extends TdObject {
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
interface TdChat extends TdObject {
  id: number;
  title: string;
  last_message?: TdMessage;
  positions?: TdChatPosition[];
  notification_settings?: TdNotificationSettings;
  unread_count?: number;
  type?: TdChatType;
}

// --- TDLib update interfaces ---
interface TdUpdateNewChat extends TdObject {
  chat?: TdChat;
}

interface TdUpdateChatLastMessage extends TdObject {
  chat_id: number;
  last_message?: TdMessage;
  positions?: TdChatPosition[];
}

interface TdUpdateChatPosition extends TdObject {
  chat_id: number;
  position?: TdChatPosition;
}

interface TdUpdateNewMessage extends TdObject {
  message?: TdMessage;
}

interface TdUpdateMessageContent extends TdObject {
  chat_id: number;
  message_id: number;
  new_content?: TdMessageContent;
}

interface TdUpdateChatReadInbox extends TdObject {
  chat_id: number;
  unread_count: number;
}

interface TdUpdateChatNotificationSettings extends TdObject {
  chat_id: number;
  notification_settings?: TdNotificationSettings;
}

interface TdUpdateChatAction extends TdObject {
  chat_id: number;
  action?: TdChatAction;
}

// --- TDLib response wrappers ---
interface TdMessages extends TdObject {
  messages?: TdMessage[];
}

// --- Safe accessor helpers ---

function safeNumber(value: object | undefined | null): number {
  if (value === undefined || value === null) return 0;
  if (typeof value === 'number') return value as number;
  return 0;
}

function safeString(value: object | undefined | null): string {
  if (value === undefined || value === null) return '';
  if (typeof value === 'string') return value as string;
  return '';
}

function safeBool(value: object | undefined | null): boolean {
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
    await TDLibClient.getInstance().send('deleteMessages', {
      chat_id: chatId,
      message_ids: [messageId],
      revoke: true
    });

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

    const pollType: object = isQuiz
      ? { '@type': 'pollTypeQuiz', correct_option_id: correctOptionId }
      : { '@type': 'pollTypeRegular', allow_multiple_answers: false };

    await TDLibClient.getInstance().send('sendMessage', {
      chat_id: chatId,
      input_message_content: {
        '@type': 'inputMessagePoll',
        question: { '@type': 'formattedText', text: question },
        options: options.map((o: string): object => ({ '@type': 'formattedText', text: o })),
        is_anonymous: isAnonymous,
        type: pollType
      }
    });
  }

  async sendScheduledMessage(chatId: number, text: string, sendDate: number,
    replyToMessageId: number = 0): Promise<void> {
    const replyTo: object | undefined = replyToMessageId > 0
      ? { '@type': 'inputMessageReplyToMessage', message_id: replyToMessageId }
      : undefined;

    await TDLibClient.getInstance().send('sendMessage', {
      chat_id: chatId,
      reply_to: replyTo,
      input_message_content: {
        '@type': 'inputMessageText',
        text: { '@type': 'formattedText', text: text }
      },
      scheduling_state: {
        '@type': 'messageSchedulingStateSendAtDate',
        send_date: sendDate
      }
    });
  }

  async votePoll(chatId: number, messageId: number, optionIds: number[]): Promise<void> {
    await TDLibClient.getInstance().send('setPollAnswer', {
      chat_id: chatId,
      message_id: messageId,
      option_ids: optionIds
    });
  }

  async getScheduledMessages(chatId: number): Promise<Message[]> {
    const result: TdMessages = await TDLibClient.getInstance().send('getChatScheduledMessages', {
      chat_id: chatId
    }) as TdMessages;
    const rawMessages: TdMessage[] | undefined = result.messages;
    if (!rawMessages) return [];
    return rawMessages.map((raw: TdMessage): Message => this.parseMessage(raw));
  }

  // --- Per-chat search ---

  async searchChatMessages(chatId: number, query: string, fromMessageId: number = 0,
    limit: number = 50, senderId: number = 0, filter: string = ''): Promise<Message[]> {
    try {
      // Build sender_id parameter for TDLib
      const senderParam: object | undefined = senderId > 0
        ? { '@type': 'messageSenderUser', user_id: senderId }
        : undefined;

      // Map filter string to TDLib searchMessagesFilter type
      let filterParam: object | undefined = undefined;
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

      const result: TdMessages = await TDLibClient.getInstance().send('searchChatMessages', {
        chat_id: chatId,
        query: query,
        sender_id: senderParam,
        from_message_id: fromMessageId,
        offset: 0,
        limit: limit,
        filter: filterParam,
        message_thread_id: 0
      }) as TdMessages;
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
      await TDLibClient.getInstance().send('setChatDraftMessage', {
        chat_id: chatId,
        draft_message: undefined
      });
    } else {
      const replyTo: object | undefined = replyToMessageId > 0
        ? { '@type': 'inputMessageReplyToMessage', message_id: replyToMessageId }
        : undefined;

      await TDLibClient.getInstance().send('setChatDraftMessage', {
        chat_id: chatId,
        draft_message: {
          '@type': 'draftMessage',
          reply_to: replyTo,
          input_message_text: {
            '@type': 'inputMessageText',
            text: { '@type': 'formattedText', text: text }
          }
        }
      });
    }
  }

  // --- TDLib update subscriptions ---

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateNewChat', (update: object) => {
      const data: TdUpdateNewChat = update as TdUpdateNewChat;
      const rawChat: TdChat | undefined = data.chat;
      if (!rawChat) return;

      const chat = this.parseChat(rawChat);
      this.chatsById.set(chat.id, chat);
      this.sortedDialogs.push(chat);
      this.sortDialogs();

      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatLastMessage', (update: object) => {
      const data: TdUpdateChatLastMessage = update as TdUpdateChatLastMessage;
      const chatId: number = data.chat_id || 0;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const rawMsg: TdMessage | undefined = data.last_message;
      if (rawMsg) {
        chat.lastMessage = this.extractTextPreview(rawMsg);
        chat.lastMessageDate = rawMsg.date || 0;

        const sender: TdMessageSender | undefined = rawMsg.sender_id;
        if (sender && sender['@type'] === 'messageSenderUser') {
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

    client.on('updateChatPosition', (update: object) => {
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

    client.on('updateNewMessage', (update: object) => {
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

    client.on('updateMessageContent', (update: object) => {
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

    client.on('updateChatReadInbox', (update: object) => {
      const data: TdUpdateChatReadInbox = update as TdUpdateChatReadInbox;
      const chatId: number = data.chat_id || 0;
      const unreadCount: number = data.unread_count || 0;
      const chat = this.chatsById.get(chatId);
      if (chat) {
        chat.unreadCount = unreadCount;
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateChatNotificationSettings', (update: object) => {
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

    client.on('updateChatAction', (update: object) => {
      const data: TdUpdateChatAction = update as TdUpdateChatAction;
      const chatId: number = data.chat_id || 0;
      const action: TdChatAction | undefined = data.action;
      const chat = this.chatsById.get(chatId);

      if (chat && action) {
        const actionType: string = action['@type'] || '';
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
      const t: string = chatType['@type'] || '';
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
      const list: TdObject | undefined = pos.list;
      if (list && list['@type'] === 'chatListMain') {
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
    if (replyTo && replyTo['@type'] === 'messageReplyToMessage') {
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
      const schedType: string = scheduling['@type'] || '';
      if (schedType === 'messageSchedulingStateSendAtDate') {
        msg.schedulingState = scheduling.send_date || 0;
      }
    }

    // Self-destruct
    const selfDestruct: TdSelfDestructType | undefined = raw.self_destruct_type;
    if (selfDestruct) {
      msg.selfDestructIn = selfDestruct.self_destruct_time || 0;
      const sdType: string = selfDestruct['@type'] || '';
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
    const type: string = content['@type'] || '';

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
          msg.pollType = pt?.['@type'] === 'pollTypeQuiz' ? 'quiz' : 'regular';

          const opts: TdPollOption[] | undefined = poll.options;
          if (opts) {
            msg.pollOptions = opts.map((opt: TdPollOption) => ({
              text: opt.text?.text || '',
              voterCount: opt.voter_count || 0,
              votePercentage: opt.vote_percentage || 0,
              isChosen: opt.is_chosen || false
            }));
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

    const type: string = content['@type'] || '';
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
