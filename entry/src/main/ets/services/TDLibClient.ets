import { hilog } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
import { TELEGRAM_API_ID, TELEGRAM_API_HASH } from './ConfigLocal.example';
import { TdFallbackRegistry } from './TdFallbackRegistry';
import { classifyTdlibError } from './AppError';
import { TdObject } from '../models/TdTypes';

// Native NAPI module
import tdlib from 'libtdlib_napi.so';

// Offload heavy JSON parsing to TaskPool worker thread
@Concurrent
function parseJsonInBackground(jsonStr: string): Object {
  return JSON.parse(jsonStr) as Object;
}

const TAG = 'TDLibClient';
const DOMAIN = 0x0001;

// Default timeout for TDLib requests (30 seconds)
const REQUEST_TIMEOUT_MS = 30000;
export const ERR_TDLIB_INIT_TIMEOUT: string = 'TDLIB_INIT_TIMEOUT';
export const ERR_TDLIB_CLIENT_DESTROYED: string = 'TDLIB_CLIENT_DESTROYED';

// --- Lifecycle state machine ---
export enum ClientState {
  Idle = 'Idle',
  Initializing = 'Initializing',
  Ready = 'Ready',
  Stopping = 'Stopping',
  Stopped = 'Stopped'
}

// --- Unified error class for TDLib errors ---
export class TDLibError extends Error {
  code: number;
  tdMessage: string;

  constructor(code: number, message: string) {
    super(`TDLib error ${code}: ${message}`);
    this.code = code;
    this.tdMessage = message;
  }

  /**
   * Classify this error and get a user-facing AppError.
   * Usage: catch (e) { if (e instanceof TDLibError) showAppError(e.classify()); }
   */
  classify(): import('./AppError').AppError {
    return classifyTdlibError(this.code, this.tdMessage);
  }
}

// --- Log levels ---
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  NONE = 4
}

type TDLibUpdateHandler = (update: TdObject) => void;

interface PendingRequest {
  resolve: (response: TdObject) => void;
  reject: (code: number, message: string) => void;
  method: string;
  timerId: number;
}

export class TDLibClient {
  private static instance: TDLibClient | null = null;
  private clientId: number = 0;
  private requestId: number = 0;
  private handlers: Map<string, TDLibUpdateHandler[]> = new Map();
  private pendingRequests: Map<number, PendingRequest> = new Map();
  private _state: ClientState = ClientState.Idle;
  private _logLevel: LogLevel = LogLevel.INFO;

  private constructor() {}

  static getInstance(): TDLibClient {
    if (TDLibClient.instance === null) {
      TDLibClient.instance = new TDLibClient();
    }
    return TDLibClient.instance;
  }

  get state(): ClientState {
    return this._state;
  }

  setLogLevel(level: LogLevel): void {
    this._logLevel = level;
  }

  initialize(): void {
    if (this._state !== ClientState.Idle && this._state !== ClientState.Stopped) {
      this.logWarn('initialize() called in invalid state: %{public}s', this._state);
      return;
    }

    // Validate API credentials before starting
    if (TELEGRAM_API_ID === 0 || TELEGRAM_API_HASH.length === 0) {
      this.logError('API credentials not configured. Copy ConfigLocal.example.ets → ConfigLocal.ets and fill in your values from https://my.telegram.org/apps');
    }

    this._state = ClientState.Initializing;
    this.clientId = tdlib.createClient();
    this.logInfo('Client created with id: %{public}d', this.clientId);

    // Start receiving updates from TDLib on a background thread
    tdlib.startReceiveLoop((responseJson: string) => {
      if (this._state === ClientState.Stopped) return;
      this.handleResponse(responseJson);
    });

    // Send TDLib parameters
    this.sendTdlibParameters();
    this._state = ClientState.Ready;
  }

  destroy(): void {
    if (this._state === ClientState.Stopped) return;
    this._state = ClientState.Stopping;

    // Reject all pending requests
    this.pendingRequests.forEach((pending: PendingRequest) => {
      clearTimeout(pending.timerId);
      pending.reject(0, ERR_TDLIB_CLIENT_DESTROYED);
    });
    this.pendingRequests.clear();

    // Clear all event handlers
    this.handlers.clear();

    tdlib.stopReceiveLoop();
    this._state = ClientState.Stopped;
    this.logInfo('Client destroyed, all pending requests rejected');
  }

  // Send a request and get a promise for the response
  async send(method: string, inputParams?: TdObject): Promise<TdObject> {
    if (this._state !== ClientState.Ready && this._state !== ClientState.Initializing) {
      throw new TDLibError(0, `Cannot send '${method}' in state '${this._state}'`);
    }

    const id: number = ++this.requestId;
    let request: TdObject;
    if (inputParams !== undefined) {
      request = inputParams;
    } else {
      request = {};
    }
    request['@type'] = method;
    request['@extra'] = id;

    return new Promise<TdObject>((resolve, reject) => {
      // Set timeout to auto-reject hanging requests
      const timerId: number = setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new TDLibError(0, `${ERR_TDLIB_INIT_TIMEOUT}: Request '${method}' timed out after ${REQUEST_TIMEOUT_MS}ms`));
        }
      }, REQUEST_TIMEOUT_MS) as number;

      const pending: PendingRequest = {
        resolve,
        reject: (code: number, message: string): void => {
          reject(new TDLibError(code, message));
        },
        method,
        timerId
      };
      this.pendingRequests.set(id, pending);
      tdlib.send(this.clientId, JSON.stringify(request));
      this.logDebug('Sent: %{public}s', method);
    });
  }

  // Subscribe to TDLib update types
  on(updateType: string, handler: TDLibUpdateHandler): void {
    const existing: TDLibUpdateHandler[] = this.handlers.get(updateType) || [];
    existing.push(handler);
    this.handlers.set(updateType, existing);
  }

  // Remove subscription
  off(updateType: string, handler: TDLibUpdateHandler): void {
    const existing: TDLibUpdateHandler[] = this.handlers.get(updateType) || [];
    const index: number = existing.indexOf(handler);
    if (index >= 0) {
      existing.splice(index, 1);
      this.handlers.set(updateType, existing);
    }
  }

  // --- Auth methods (mirroring iOS Telegram patterns) ---

  async setPhoneNumber(phoneNumber: string): Promise<TdObject> {
    const settings: TdObject = {};
    settings['@type'] = 'phoneNumberAuthenticationSettings';
    settings['allow_flash_call'] = false;
    settings['allow_missed_call'] = false;
    settings['is_current_phone_number'] = false;
    settings['allow_sms_retriever_api'] = false;
    const params: TdObject = {};
    params['phone_number'] = phoneNumber;
    params['settings'] = settings;
    return this.send('setAuthenticationPhoneNumber', params);
  }

  async checkAuthCode(code: string): Promise<TdObject> {
    const params: TdObject = {};
    params['code'] = code;
    return this.send('checkAuthenticationCode', params);
  }

  async checkAuthPassword(password: string): Promise<TdObject> {
    const params: TdObject = {};
    params['password'] = password;
    return this.send('checkAuthenticationPassword', params);
  }

  async resendAuthCode(): Promise<TdObject> {
    return this.send('resendAuthenticationCode');
  }

  // --- Chat methods ---

  async loadChats(limit: number = 20): Promise<TdObject> {
    const chatList: TdObject = {};
    chatList['@type'] = 'chatListMain';
    const params: TdObject = {};
    params['chat_list'] = chatList;
    params['limit'] = limit;
    return this.send('loadChats', params);
  }

  async getChat(chatId: number): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    return this.send('getChat', params);
  }

  async getChatHistory(chatId: number, fromMessageId: number = 0,
    limit: number = 50): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['from_message_id'] = fromMessageId;
    params['offset'] = 0;
    params['limit'] = limit;
    params['only_local'] = false;
    return this.send('getChatHistory', params);
  }

  // --- Contact methods ---

  async getContacts(): Promise<TdObject> {
    return this.send('getContacts');
  }

  async searchContacts(query: string, limit: number = 50): Promise<TdObject> {
    const params: TdObject = {};
    params['query'] = query;
    params['limit'] = limit;
    return this.send('searchContacts', params);
  }

  async getUser(userId: number): Promise<TdObject> {
    const params: TdObject = {};
    params['user_id'] = userId;
    return this.send('getUser', params);
  }

  // --- Create chat ---

  async createPrivateChat(userId: number): Promise<TdObject> {
    const params: TdObject = {};
    params['user_id'] = userId;
    params['force'] = false;
    return this.send('createPrivateChat', params);
  }

  // --- Search ---

  async searchMessages(query: string, limit: number = 50): Promise<TdObject> {
    const chatList: TdObject = {};
    chatList['@type'] = 'chatListMain';
    const params: TdObject = {};
    params['chat_list'] = chatList;
    params['query'] = query;
    params['offset'] = '';
    params['offset_chat_id'] = 0;
    params['offset_message_id'] = 0;
    params['limit'] = limit;
    return this.send('searchMessages', params);
  }

  // --- Message methods ---

  async editMessageText(chatId: number, messageId: number, text: string): Promise<TdObject> {
    const formattedText: TdObject = {};
    formattedText['@type'] = 'formattedText';
    formattedText['text'] = text;
    const inputContent: TdObject = {};
    inputContent['@type'] = 'inputMessageText';
    inputContent['text'] = formattedText;
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['message_id'] = messageId;
    params['input_message_content'] = inputContent;
    return this.send('editMessageText', params);
  }

  async sendMessage(chatId: number, text: string, replyToMessageId: number = 0): Promise<TdObject> {
    const formattedText: TdObject = {};
    formattedText['@type'] = 'formattedText';
    formattedText['text'] = text;
    const inputContent: TdObject = {};
    inputContent['@type'] = 'inputMessageText';
    inputContent['text'] = formattedText;
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['input_message_content'] = inputContent;

    if (replyToMessageId > 0) {
      const replyTo: TdObject = {};
      replyTo['@type'] = 'inputMessageReplyToMessage';
      replyTo['message_id'] = replyToMessageId;
      params['reply_to'] = replyTo;
    }

    return this.send('sendMessage', params);
  }

  // --- View messages (mark as read) ---

  async viewMessages(chatId: number, messageIds: number[]): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['message_ids'] = messageIds;
    params['force_read'] = true;
    return this.send('viewMessages', params);
  }

  async addMessageReaction(chatId: number, messageId: number, emoji: string): Promise<TdObject> {
    const reactionType: TdObject = {};
    reactionType['@type'] = 'reactionTypeEmoji';
    reactionType['emoji'] = emoji;
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['message_id'] = messageId;
    params['reaction_type'] = reactionType;
    params['is_big'] = false;
    params['update_recent_reactions'] = true;
    return this.send('addMessageReaction', params);
  }

  async removeMessageReaction(chatId: number, messageId: number, emoji: string): Promise<TdObject> {
    const reactionType: TdObject = {};
    reactionType['@type'] = 'reactionTypeEmoji';
    reactionType['emoji'] = emoji;
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['message_id'] = messageId;
    params['reaction_type'] = reactionType;
    return this.send('removeMessageReaction', params);
  }

  async getChatPinnedMessage(chatId: number): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    return this.send('getChatPinnedMessage', params);
  }

  // --- Send photo ---

  async sendPhoto(chatId: number, filePath: string, caption: string = '',
    replyToMessageId: number = 0): Promise<TdObject> {
    const inputFile: TdObject = {};
    inputFile['@type'] = 'inputFileLocal';
    inputFile['path'] = filePath;
    const formattedCaption: TdObject = {};
    formattedCaption['@type'] = 'formattedText';
    formattedCaption['text'] = caption;
    const inputContent: TdObject = {};
    inputContent['@type'] = 'inputMessagePhoto';
    inputContent['photo'] = inputFile;
    inputContent['caption'] = formattedCaption;
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['input_message_content'] = inputContent;
    if (replyToMessageId > 0) {
      const replyTo: TdObject = {};
      replyTo['@type'] = 'inputMessageReplyToMessage';
      replyTo['message_id'] = replyToMessageId;
      params['reply_to'] = replyTo;
    }
    return this.send('sendMessage', params);
  }

  // --- Send document ---

  async sendDocument(chatId: number, filePath: string, caption: string = '',
    replyToMessageId: number = 0): Promise<TdObject> {
    const inputFile: TdObject = {};
    inputFile['@type'] = 'inputFileLocal';
    inputFile['path'] = filePath;
    const formattedCaption: TdObject = {};
    formattedCaption['@type'] = 'formattedText';
    formattedCaption['text'] = caption;
    const inputContent: TdObject = {};
    inputContent['@type'] = 'inputMessageDocument';
    inputContent['document'] = inputFile;
    inputContent['caption'] = formattedCaption;
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['input_message_content'] = inputContent;
    if (replyToMessageId > 0) {
      const replyTo: TdObject = {};
      replyTo['@type'] = 'inputMessageReplyToMessage';
      replyTo['message_id'] = replyToMessageId;
      params['reply_to'] = replyTo;
    }
    return this.send('sendMessage', params);
  }

  // --- Delete chat ---

  async deleteChat(chatId: number): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['remove_from_chat_list'] = true;
    params['revoke'] = false;
    return this.send('deleteChatHistory', params);
  }

  // --- Toggle mute ---

  async setChatNotificationSettings(chatId: number, muteFor: number): Promise<TdObject> {
    const settings: TdObject = {};
    settings['@type'] = 'chatNotificationSettings';
    settings['use_default_mute_for'] = false;
    settings['mute_for'] = muteFor;
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['notification_settings'] = settings;
    return this.send('setChatNotificationSettings', params);
  }

  // --- Pin/unpin chat ---

  async toggleChatIsPinned(chatId: number, isPinned: boolean): Promise<TdObject> {
    const chatList: TdObject = {};
    chatList['@type'] = 'chatListMain';
    const params: TdObject = {};
    params['chat_list'] = chatList;
    params['chat_id'] = chatId;
    params['is_pinned'] = isPinned;
    return this.send('toggleChatIsPinned', params);
  }

  // --- Read all in chat ---

  async openChat(chatId: number): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    return this.send('openChat', params);
  }

  async toggleChatIsMarkedAsUnread(chatId: number, isMarkedAsUnread: boolean): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['is_marked_as_unread'] = isMarkedAsUnread;
    return this.send('toggleChatIsMarkedAsUnread', params);
  }

  async closeChat(chatId: number): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    return this.send('closeChat', params);
  }

  // --- Send video ---

  async sendVideo(chatId: number, filePath: string, caption: string = '',
    duration: number = 0, replyToMessageId: number = 0): Promise<TdObject> {
    const inputFile: TdObject = {};
    inputFile['@type'] = 'inputFileLocal';
    inputFile['path'] = filePath;
    const formattedCaption: TdObject = {};
    formattedCaption['@type'] = 'formattedText';
    formattedCaption['text'] = caption;
    const inputContent: TdObject = {};
    inputContent['@type'] = 'inputMessageVideo';
    inputContent['video'] = inputFile;
    inputContent['caption'] = formattedCaption;
    inputContent['duration'] = duration;
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['input_message_content'] = inputContent;
    if (replyToMessageId > 0) {
      const replyTo: TdObject = {};
      replyTo['@type'] = 'inputMessageReplyToMessage';
      replyTo['message_id'] = replyToMessageId;
      params['reply_to'] = replyTo;
    }
    return this.send('sendMessage', params);
  }

  // --- Private methods ---

  private sendTdlibParameters(): void {
    const params: TdObject = {};
    params['database_directory'] = '/data/storage/el2/base/tdlib';
    params['files_directory'] = '/data/storage/el2/base/tdlib/files';
    params['use_file_database'] = true;
    params['use_chat_info_database'] = true;
    params['use_message_database'] = true;
    params['use_secret_chats'] = true;
    params['api_id'] = TELEGRAM_API_ID;
    params['api_hash'] = TELEGRAM_API_HASH;
    params['system_language_code'] = 'en';
    params['device_model'] = 'HarmonyOS Device';
    params['system_version'] = 'HarmonyOS 6.0';
    params['application_version'] = '1.0.0';
    this.send('setTdlibParameters', params);
  }

  private async handleResponse(responseJson: string): Promise<void> {
    try {
      // Parse JSON off the main thread via TaskPool
      const task: taskpool.Task = new taskpool.Task(parseJsonInBackground, responseJson);
      const response: TdObject = (await taskpool.execute(task)) as TdObject;

      const type: string = (response['@type'] as string) || '';
      const extra: number = (response['@extra'] as number) || 0;

      this.logDebug('Received: %{public}s', type);

      // Resolve or reject pending request promise
      if (extra !== undefined && this.pendingRequests.has(extra)) {
        const pending = this.pendingRequests.get(extra);
        this.pendingRequests.delete(extra);
        if (pending) {
          clearTimeout(pending.timerId);
          // Reject on TDLib error responses
          if (type === 'error') {
            const code = (response['code'] as number) || 0;
            const msg = (response['message'] as string) || 'Unknown error';
            this.logWarn('Request %{public}s failed: [%{public}d] %{public}s', pending.method, code, msg);
            pending.reject(code, msg);
          } else {
            pending.resolve(response);
          }
        }
      }

      // Do not propagate error responses as updates
      if (type === 'error') return;

      // Notify update handlers
      const handlers: TDLibUpdateHandler[] = this.handlers.get(type) || [];
      for (const handler of handlers) {
        handler(response);
      }

      // Also notify wildcard handlers
      const wildcardHandlers: TDLibUpdateHandler[] = this.handlers.get('*') || [];
      for (const handler of wildcardHandlers) {
        handler(response);
      }

      // Track unhandled update types for telemetry
      if (handlers.length === 0 && wildcardHandlers.length === 0 && type.startsWith('update')) {
        TdFallbackRegistry.getInstance().recordUnhandled(type, 'update');
      }
    } catch (e) {
      this.logError('Failed to parse response: %{public}s', String(e));
    }
  }

  // --- Logging helpers ---

  private logDebug(format: string, ...args: Object[]): void {
    if (this._logLevel <= LogLevel.DEBUG) {
      hilog.debug(DOMAIN, TAG, format, ...args);
    }
  }

  private logInfo(format: string, ...args: Object[]): void {
    if (this._logLevel <= LogLevel.INFO) {
      hilog.info(DOMAIN, TAG, format, ...args);
    }
  }

  private logWarn(format: string, ...args: Object[]): void {
    if (this._logLevel <= LogLevel.WARN) {
      hilog.warn(DOMAIN, TAG, format, ...args);
    }
  }

  private logError(format: string, ...args: Object[]): void {
    if (this._logLevel <= LogLevel.ERROR) {
      hilog.error(DOMAIN, TAG, format, ...args);
    }
  }
}

