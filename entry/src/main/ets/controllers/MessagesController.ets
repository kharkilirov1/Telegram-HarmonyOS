import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { NotificationService } from '../services/NotificationService';
import { Chat } from '../models/Chat';
import { Message, MessageContentType } from '../models/Message';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'MessagesController';
const DOMAIN = 0x0001;

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
    const result = await TDLibClient.getInstance()
      .getChatHistory(chatId, fromMessageId, limit) as Record<string, object>;
    const rawMessages = result['messages'] as Record<string, object>[];
    const parsed: Message[] = [];

    if (rawMessages) {
      for (const raw of rawMessages) {
        const msg = this.parseMessage(raw);
        parsed.push(msg);
      }
      // Cache
      const existing = this.messagesByChat.get(chatId) || [];
      const existingIds = new Set(existing.map(m => m.id));
      for (const msg of parsed) {
        if (!existingIds.has(msg.id)) {
          existing.push(msg);
        }
      }
      existing.sort((a, b) => a.id - b.id);
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
      const idx = messages.findIndex(m => m.id === messageId);
      if (idx >= 0) {
        messages.splice(idx, 1);
      }
    }

    NotificationCenter.getInstance().post(
      EventId.MESSAGE_DELETED,
      { chatId: chatId, messageId: messageId } as Record<string, Object>
    );
  }

  async sendPoll(chatId: number, question: string, options: string[],
    isAnonymous: boolean = true, isQuiz: boolean = false,
    correctOptionId: number = -1): Promise<void> {

    const pollType: Record<string, object> = isQuiz
      ? { '@type': 'pollTypeQuiz', correct_option_id: correctOptionId }
      : { '@type': 'pollTypeRegular', allow_multiple_answers: false };

    await TDLibClient.getInstance().send('sendMessage', {
      chat_id: chatId,
      input_message_content: {
        '@type': 'inputMessagePoll',
        question: { '@type': 'formattedText', text: question },
        options: options.map(o => ({ '@type': 'formattedText', text: o })),
        is_anonymous: isAnonymous,
        type: pollType
      }
    });
  }

  async sendScheduledMessage(chatId: number, text: string, sendDate: number,
    replyToMessageId: number = 0): Promise<void> {
    const params: Record<string, object> = {
      chat_id: chatId,
      reply_to: replyToMessageId > 0
        ? { '@type': 'inputMessageReplyToMessage', message_id: replyToMessageId }
        : undefined,
      input_message_content: {
        '@type': 'inputMessageText',
        text: { '@type': 'formattedText', text: text }
      },
      scheduling_state: {
        '@type': 'messageSchedulingStateSendAtDate',
        send_date: sendDate
      }
    } as Record<string, object>;
    await TDLibClient.getInstance().send('sendMessage', params);
  }

  async votePoll(chatId: number, messageId: number, optionIds: number[]): Promise<void> {
    await TDLibClient.getInstance().send('setPollAnswer', {
      chat_id: chatId,
      message_id: messageId,
      option_ids: optionIds
    });
  }

  async getScheduledMessages(chatId: number): Promise<Message[]> {
    const result = await TDLibClient.getInstance().send('getChatScheduledMessages', {
      chat_id: chatId
    }) as Record<string, object>;
    const rawMessages = result['messages'] as Record<string, object>[];
    if (!rawMessages) return [];
    return rawMessages.map(raw => this.parseMessage(raw));
  }

  // --- Per-chat search ---

  async searchChatMessages(chatId: number, query: string, fromMessageId: number = 0,
    limit: number = 50): Promise<Message[]> {
    try {
      const result = await TDLibClient.getInstance().send('searchChatMessages', {
        chat_id: chatId,
        query: query,
        sender_id: null,
        from_message_id: fromMessageId,
        offset: 0,
        limit: limit,
        filter: null,
        message_thread_id: 0
      }) as Record<string, object>;
      const rawMessages = result['messages'] as Record<string, object>[];
      if (!rawMessages) return [];
      return rawMessages.map(raw => this.parseMessage(raw));
    } catch {
      return [];
    }
  }

  // --- Drafts ---

  async setDraft(chatId: number, text: string, replyToMessageId: number = 0): Promise<void> {
    if (text.length === 0 && replyToMessageId === 0) {
      await TDLibClient.getInstance().send('setChatDraftMessage', {
        chat_id: chatId,
        draft_message: null
      });
    } else {
      await TDLibClient.getInstance().send('setChatDraftMessage', {
        chat_id: chatId,
        draft_message: {
          '@type': 'draftMessage',
          reply_to: replyToMessageId > 0
            ? { '@type': 'inputMessageReplyToMessage', message_id: replyToMessageId }
            : undefined,
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
      const data = update as Record<string, object>;
      const rawChat = data['chat'] as Record<string, object>;
      if (!rawChat) return;

      const chat = this.parseChat(rawChat);
      this.chatsById.set(chat.id, chat);
      this.sortedDialogs.push(chat);
      this.sortDialogs();

      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatLastMessage', (update: object) => {
      const data = update as Record<string, object>;
      const chatId = data['chat_id'] as number;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const rawMsg = data['last_message'] as Record<string, object>;
      if (rawMsg) {
        chat.lastMessage = this.extractTextPreview(rawMsg);
        chat.lastMessageDate = rawMsg['date'] as number || 0;

        const senderId = rawMsg['sender_id'] as Record<string, object>;
        if (senderId && senderId['@type'] === 'messageSenderUser') {
          chat.lastMessageSenderId = senderId['user_id'] as number || 0;
        }
      }

      // Update positions if provided
      const positions = data['positions'] as Record<string, object>[];
      if (positions) {
        this.updateChatPositions(chat, positions);
      }

      this.sortDialogs();
      NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
    });

    client.on('updateChatPosition', (update: object) => {
      const data = update as Record<string, object>;
      const chatId = data['chat_id'] as number;
      const chat = this.chatsById.get(chatId);
      if (!chat) return;

      const position = data['position'] as Record<string, object>;
      if (position) {
        this.updateChatPositions(chat, [position]);
        this.sortDialogs();
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateNewMessage', (update: object) => {
      const data = update as Record<string, object>;
      const rawMsg = data['message'] as Record<string, object>;
      if (!rawMsg) return;

      const msg = this.parseMessage(rawMsg);
      const chatMessages = this.messagesByChat.get(msg.chatId) || [];

      // Avoid duplicates
      if (!chatMessages.find(m => m.id === msg.id)) {
        chatMessages.push(msg);
        chatMessages.sort((a, b) => a.id - b.id);
        this.messagesByChat.set(msg.chatId, chatMessages);
      }

      NotificationCenter.getInstance().post(
        EventId.NEW_MESSAGE,
        { chatId: msg.chatId, message: msg } as Record<string, Object>
      );

      // Trigger push notification for incoming messages
      if (!msg.isOutgoing) {
        const chat = this.chatsById.get(msg.chatId);
        if (chat && !chat.isMuted) {
          NotificationService.getInstance().showMessageNotification(
            chat.title,
            msg.senderName || chat.title,
            this.extractTextPreview({ content: { '@type': 'messageText', text: { text: msg.text } } } as Record<string, object>),
            msg.chatId
          );
        }
      }
    });

    client.on('updateMessageContent', (update: object) => {
      const data = update as Record<string, object>;
      const chatId = data['chat_id'] as number;
      const messageId = data['message_id'] as number;
      const newContent = data['new_content'] as Record<string, object>;

      const messages = this.messagesByChat.get(chatId);
      if (messages && newContent) {
        const msg = messages.find(m => m.id === messageId);
        if (msg) {
          this.applyContent(msg, newContent);
          NotificationCenter.getInstance().post(
            EventId.MESSAGE_EDITED,
            { chatId: chatId, messageId: messageId } as Record<string, Object>
          );
        }
      }
    });

    client.on('updateChatReadInbox', (update: object) => {
      const data = update as Record<string, object>;
      const chatId = data['chat_id'] as number;
      const unreadCount = data['unread_count'] as number;
      const chat = this.chatsById.get(chatId);
      if (chat) {
        chat.unreadCount = unreadCount || 0;
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateChatNotificationSettings', (update: object) => {
      const data = update as Record<string, object>;
      const chatId = data['chat_id'] as number;
      const settings = data['notification_settings'] as Record<string, object>;
      const chat = this.chatsById.get(chatId);
      if (chat && settings) {
        const muteFor = settings['mute_for'] as number || 0;
        chat.isMuted = muteFor > 0;
        NotificationCenter.getInstance().post(EventId.DIALOGS_UPDATED);
      }
    });

    client.on('updateChatAction', (update: object) => {
      const data = update as Record<string, object>;
      const chatId = data['chat_id'] as number;
      const action = data['action'] as Record<string, string>;
      const chat = this.chatsById.get(chatId);

      if (chat && action) {
        const actionType = action['@type'] || '';
        if (actionType === 'chatActionTyping') {
          chat.isTyping = true;
          chat.typingDescription = 'typing...';

          // Auto-clear after 5 seconds
          setTimeout(() => {
            chat.isTyping = false;
            chat.typingDescription = '';
            NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED,
              { chatId: chatId } as Record<string, Object>);
          }, 5000);
        } else if (actionType === 'chatActionCancel') {
          chat.isTyping = false;
          chat.typingDescription = '';
        }

        NotificationCenter.getInstance().post(EventId.CHAT_ACTION_UPDATED,
          { chatId: chatId } as Record<string, Object>);
      }
    });
  }

  // --- Parsing helpers ---

  private parseChat(raw: Record<string, object>): Chat {
    const lastMsg = raw['last_message'] as Record<string, object>;
    const positions = raw['positions'] as Record<string, object>[];
    const notifSettings = raw['notification_settings'] as Record<string, object>;

    const chat = new Chat(
      raw['id'] as number || 0,
      raw['title'] as string || '',
      lastMsg ? this.extractTextPreview(lastMsg) : '',
      lastMsg ? (lastMsg['date'] as number || 0) : 0,
      raw['unread_count'] as number || 0,
      null,
      false,
      false,
      false
    );

    // Determine type
    const chatType = raw['type'] as Record<string, string>;
    if (chatType) {
      const t = chatType['@type'] || '';
      chat.isGroup = t === 'chatTypeSupergroup' || t === 'chatTypeBasicGroup';
      chat.isChannel = t === 'chatTypeSupergroup' &&
        (chatType['is_channel'] as unknown as boolean === true);
    }

    // Mute status
    if (notifSettings) {
      const muteFor = notifSettings['mute_for'] as number || 0;
      chat.isMuted = muteFor > 0;
    }

    // Positions / pinned / order
    if (positions) {
      this.updateChatPositions(chat, positions);
    }

    return chat;
  }

  private updateChatPositions(chat: Chat, positions: Record<string, object>[]): void {
    for (const pos of positions) {
      const list = pos['list'] as Record<string, string>;
      if (list && list['@type'] === 'chatListMain') {
        chat.order = (pos['order'] as string) || '0';
        chat.isPinned = (pos['is_pinned'] as unknown as boolean) || false;
      }
    }
  }

  parseMessage(raw: Record<string, object>): Message {
    const content = raw['content'] as Record<string, object>;
    const senderId = raw['sender_id'] as Record<string, object>;

    const msg = new Message(
      raw['id'] as number || 0,
      raw['chat_id'] as number || 0,
      (senderId?.['user_id'] as number) || 0,
      '',
      '',
      raw['date'] as number || 0,
      raw['is_outgoing'] as boolean || false,
      false,
      0,
      MessageContentType.TEXT,
      null,
      null
    );

    // Reply
    const replyTo = raw['reply_to'] as Record<string, object>;
    if (replyTo && replyTo['@type'] === 'messageReplyToMessage') {
      msg.replyToMessageId = replyTo['message_id'] as number || 0;
    }

    // Forward
    const forwardInfo = raw['forward_info'] as Record<string, object>;
    if (forwardInfo) {
      const origin = forwardInfo['origin'] as Record<string, object>;
      if (origin) {
        msg.forwardedFrom = (origin['sender_name'] as string) || '';
      }
    }

    // Media album grouping
    const albumId = raw['media_album_id'] as string;
    if (albumId && albumId !== '0') {
      msg.mediaAlbumId = albumId;
    }

    // Scheduling state
    const scheduling = raw['scheduling_state'] as Record<string, object>;
    if (scheduling) {
      const schedType = scheduling['@type'] as string;
      if (schedType === 'messageSchedulingStateSendAtDate') {
        msg.schedulingState = (scheduling['send_date'] as number) || 0;
      }
    }

    // Self-destruct
    const selfDestruct = raw['self_destruct_type'] as Record<string, object>;
    if (selfDestruct) {
      msg.selfDestructIn = (selfDestruct['self_destruct_time'] as number) || 0;
      // View-once: self-destruct type with specific timer
      const sdType = (selfDestruct['@type'] as string) || '';
      if (sdType === 'messageSelfDestructTypeImmediately') {
        msg.isViewOnce = true;
      }
    }

    // Spoiler (has_spoiler flag on photo/video content)
    if (content) {
      const hasSpoiler = content['has_spoiler'] as boolean;
      if (hasSpoiler) {
        msg.hasSpoiler = true;
      }
      this.applyContent(msg, content);
    }

    return msg;
  }

  private applyContent(msg: Message, content: Record<string, object>): void {
    const type = (content['@type'] as string) || '';

    switch (type) {
      case 'messageText': {
        msg.contentType = MessageContentType.TEXT;
        const textObj = content['text'] as Record<string, string>;
        msg.text = textObj?.['text'] || '';
        break;
      }
      case 'messagePhoto': {
        msg.contentType = MessageContentType.PHOTO;
        const caption = content['caption'] as Record<string, string>;
        msg.text = caption?.['text'] || '';
        break;
      }
      case 'messageVideo': {
        msg.contentType = MessageContentType.VIDEO;
        const video = content['video'] as Record<string, object>;
        msg.videoDuration = (video?.['duration'] as number) || 0;
        const caption2 = content['caption'] as Record<string, string>;
        msg.text = caption2?.['text'] || '';
        break;
      }
      case 'messageDocument': {
        msg.contentType = MessageContentType.DOCUMENT;
        const doc = content['document'] as Record<string, string>;
        msg.fileName = doc?.['file_name'] || 'Document';
        const caption3 = content['caption'] as Record<string, string>;
        msg.text = caption3?.['text'] || '';
        break;
      }
      case 'messageVoiceNote': {
        msg.contentType = MessageContentType.VOICE;
        const voice = content['voice_note'] as Record<string, object>;
        msg.voiceDuration = (voice?.['duration'] as number) || 0;
        const waveform = voice?.['waveform'] as string;
        if (waveform) {
          msg.voiceWaveform = this.decodeWaveform(waveform);
        }
        break;
      }
      case 'messageSticker': {
        msg.contentType = MessageContentType.STICKER;
        const sticker = content['sticker'] as Record<string, string>;
        msg.text = sticker?.['emoji'] || '';
        break;
      }
      case 'messageAnimation': {
        msg.contentType = MessageContentType.ANIMATION;
        msg.text = 'GIF';
        break;
      }
      case 'messageVideoNote': {
        msg.contentType = MessageContentType.VIDEO_NOTE;
        const videoNote = content['video_note'] as Record<string, object>;
        msg.videoNoteDuration = (videoNote?.['duration'] as number) || 0;
        msg.videoNoteLength = (videoNote?.['length'] as number) || 240;
        const vnFile = videoNote?.['video'] as Record<string, object>;
        if (vnFile) {
          msg.videoNoteFileId = (vnFile['id'] as number) || 0;
        }
        break;
      }
      case 'messagePoll': {
        msg.contentType = MessageContentType.POLL;
        const poll = content['poll'] as Record<string, object>;
        if (poll) {
          msg.pollId = (poll['id'] as string) || '';
          msg.pollQuestion = ((poll['question'] as Record<string, string>)?.['text']) || '';
          msg.pollTotalVoterCount = (poll['total_voter_count'] as number) || 0;
          msg.pollIsClosed = (poll['is_closed'] as boolean) || false;
          msg.pollIsAnonymous = (poll['is_anonymous'] as boolean) || true;

          const pollType = poll['type'] as Record<string, object>;
          msg.pollType = pollType?.['@type'] === 'pollTypeQuiz' ? 'quiz' : 'regular';

          const options = poll['options'] as Record<string, object>[];
          if (options) {
            msg.pollOptions = options.map(opt => ({
              text: ((opt['text'] as Record<string, string>)?.['text']) || '',
              voterCount: (opt['voter_count'] as number) || 0,
              votePercentage: (opt['vote_percentage'] as number) || 0,
              isChosen: (opt['is_chosen'] as boolean) || false
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

  private extractTextPreview(rawMsg: Record<string, object>): string {
    const content = rawMsg['content'] as Record<string, object>;
    if (!content) return '';

    const type = (content['@type'] as string) || '';
    switch (type) {
      case 'messageText': {
        const textObj = content['text'] as Record<string, string>;
        return textObj?.['text'] || '';
      }
      case 'messagePhoto': return 'Photo';
      case 'messageVideo': return 'Video';
      case 'messageDocument': {
        const doc = content['document'] as Record<string, string>;
        return doc?.['file_name'] || 'Document';
      }
      case 'messageVoiceNote': return 'Voice message';
      case 'messageSticker': {
        const sticker = content['sticker'] as Record<string, string>;
        return `${sticker?.['emoji'] || ''} Sticker`;
      }
      case 'messageAnimation': return 'GIF';
      case 'messageVideoNote': return 'Video message';
      case 'messagePoll': {
        const poll = content['poll'] as Record<string, object>;
        const question = (poll?.['question'] as Record<string, string>)?.['text'] || '';
        return `📊 ${question}`;
      }
      default: return type.replace('message', '');
    }
  }

  private decodeWaveform(base64: string): number[] {
    // TDLib sends waveform as base64-encoded packed 5-bit amplitude values
    // Each 5 bits encode a value 0-31, normalized to 0.0-1.0
    try {
      const raw = this.base64ToBytes(base64);
      if (raw.length === 0) return this.fallbackWaveform();

      const result: number[] = [];
      let bitIndex = 0;
      const totalBits = raw.length * 8;

      while (bitIndex + 5 <= totalBits) {
        const byteOffset = Math.floor(bitIndex / 8);
        const bitOffset = bitIndex % 8;

        let value: number;
        if (bitOffset <= 3) {
          value = (raw[byteOffset] >> bitOffset) & 0x1F;
        } else {
          const bitsFromFirst = 8 - bitOffset;
          const bitsFromSecond = 5 - bitsFromFirst;
          value = ((raw[byteOffset] >> bitOffset) & ((1 << bitsFromFirst) - 1))
            | (((raw[byteOffset + 1] || 0) & ((1 << bitsFromSecond) - 1)) << bitsFromFirst);
        }

        result.push(value / 31.0);
        bitIndex += 5;
      }

      return result.length > 0 ? result : this.fallbackWaveform();
    } catch {
      return this.fallbackWaveform();
    }
  }

  private base64ToBytes(base64: string): number[] {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const bytes: number[] = [];
    let buffer = 0;
    let bitsCollected = 0;

    for (let i = 0; i < base64.length; i++) {
      const c = base64.charAt(i);
      if (c === '=') break;
      const idx = chars.indexOf(c);
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
    for (let i = 0; i < 32; i++) {
      result.push(0.3);
    }
    return result;
  }

  private sortDialogs(): void {
    this.sortedDialogs.sort((a, b) => {
      // TDLib order handles pinned + date sorting
      if (a.order > b.order) return -1;
      if (a.order < b.order) return 1;
      return 0;
    });
  }
}
