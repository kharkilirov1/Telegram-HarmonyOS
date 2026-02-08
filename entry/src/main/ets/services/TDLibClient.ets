import { AuthorizationState } from '../models/User';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
import { TELEGRAM_API_ID, TELEGRAM_API_HASH } from './Config.local';

// Native NAPI module
import tdlib from 'libtdlib_napi.so';

// Offload heavy JSON parsing to TaskPool worker thread
@Concurrent
function parseJsonInBackground(jsonStr: string): object {
  return JSON.parse(jsonStr);
}

const TAG = 'TDLibClient';
const DOMAIN = 0x0001;

type TDLibUpdateHandler = (update: object) => void;

export class TDLibClient {
  private static instance: TDLibClient | null = null;
  private clientId: number = 0;
  private requestId: number = 0;
  private handlers: Map<string, TDLibUpdateHandler[]> = new Map();
  private pendingRequests: Map<number, (response: object) => void> = new Map();

  private constructor() {}

  static getInstance(): TDLibClient {
    if (TDLibClient.instance === null) {
      TDLibClient.instance = new TDLibClient();
    }
    return TDLibClient.instance;
  }

  initialize(): void {
    this.clientId = tdlib.createClient();
    hilog.info(DOMAIN, TAG, 'Client created with id: %{public}d', this.clientId);

    // Start receiving updates from TDLib on a background thread
    tdlib.startReceiveLoop((responseJson: string) => {
      this.handleResponse(responseJson);
    });

    // Send TDLib parameters
    this.sendTdlibParameters();
  }

  destroy(): void {
    tdlib.stopReceiveLoop();
    hilog.info(DOMAIN, TAG, 'Client destroyed');
  }

  // Send a request and get a promise for the response
  async send(method: string, params: object = {}): Promise<object> {
    const id = ++this.requestId;
    const request = {
      '@type': method,
      '@extra': id,
      ...params
    };

    return new Promise<object>((resolve) => {
      this.pendingRequests.set(id, resolve);
      tdlib.send(this.clientId, JSON.stringify(request));
      hilog.info(DOMAIN, TAG, 'Sent: %{public}s', method);
    });
  }

  // Subscribe to TDLib update types
  on(updateType: string, handler: TDLibUpdateHandler): void {
    const existing = this.handlers.get(updateType) || [];
    existing.push(handler);
    this.handlers.set(updateType, existing);
  }

  // Remove subscription
  off(updateType: string, handler: TDLibUpdateHandler): void {
    const existing = this.handlers.get(updateType) || [];
    const index = existing.indexOf(handler);
    if (index >= 0) {
      existing.splice(index, 1);
      this.handlers.set(updateType, existing);
    }
  }

  // --- Auth methods (mirroring iOS Telegram patterns) ---

  async setPhoneNumber(phoneNumber: string): Promise<object> {
    return this.send('setAuthenticationPhoneNumber', {
      phone_number: phoneNumber,
      settings: {
        '@type': 'phoneNumberAuthenticationSettings',
        allow_flash_call: false,
        allow_missed_call: false,
        is_current_phone_number: false,
        allow_sms_retriever_api: false
      }
    });
  }

  async checkAuthCode(code: string): Promise<object> {
    return this.send('checkAuthenticationCode', { code: code });
  }

  async checkAuthPassword(password: string): Promise<object> {
    return this.send('checkAuthenticationPassword', { password: password });
  }

  // --- Chat methods ---

  async loadChats(limit: number = 20): Promise<object> {
    return this.send('loadChats', {
      chat_list: { '@type': 'chatListMain' },
      limit: limit
    });
  }

  async getChat(chatId: number): Promise<object> {
    return this.send('getChat', { chat_id: chatId });
  }

  async getChatHistory(chatId: number, fromMessageId: number = 0, limit: number = 50): Promise<object> {
    return this.send('getChatHistory', {
      chat_id: chatId,
      from_message_id: fromMessageId,
      offset: 0,
      limit: limit,
      only_local: false
    });
  }

  // --- Contact methods ---

  async getContacts(): Promise<object> {
    return this.send('getContacts');
  }

  async searchContacts(query: string, limit: number = 50): Promise<object> {
    return this.send('searchContacts', { query: query, limit: limit });
  }

  async getUser(userId: number): Promise<object> {
    return this.send('getUser', { user_id: userId });
  }

  // --- Create chat ---

  async createPrivateChat(userId: number): Promise<object> {
    return this.send('createPrivateChat', { user_id: userId, force: false });
  }

  // --- Search ---

  async searchMessages(query: string, limit: number = 50): Promise<object> {
    return this.send('searchMessages', {
      chat_list: { '@type': 'chatListMain' },
      query: query,
      offset: '',
      offset_chat_id: 0,
      offset_message_id: 0,
      limit: limit
    });
  }

  // --- Message methods ---

  async editMessageText(chatId: number, messageId: number, text: string): Promise<object> {
    return this.send('editMessageText', {
      chat_id: chatId,
      message_id: messageId,
      input_message_content: {
        '@type': 'inputMessageText',
        text: { '@type': 'formattedText', text: text }
      }
    });
  }

  async sendMessage(chatId: number, text: string, replyToMessageId: number = 0): Promise<object> {
    const params: Record<string, object | number> = {
      chat_id: chatId as number,
      input_message_content: {
        '@type': 'inputMessageText',
        text: {
          '@type': 'formattedText',
          text: text
        }
      } as object
    };

    if (replyToMessageId > 0) {
      params.reply_to = {
        '@type': 'inputMessageReplyToMessage',
        message_id: replyToMessageId
      } as object;
    }

    return this.send('sendMessage', params);
  }

  // --- Private methods ---

  private sendTdlibParameters(): void {
    this.send('setTdlibParameters', {
      database_directory: '/data/storage/el2/base/tdlib',
      files_directory: '/data/storage/el2/base/tdlib/files',
      use_file_database: true,
      use_chat_info_database: true,
      use_message_database: true,
      use_secret_chats: true,
      api_id: TELEGRAM_API_ID,
      api_hash: TELEGRAM_API_HASH,
      system_language_code: 'en',
      device_model: 'HarmonyOS Device',
      system_version: 'HarmonyOS 6.0',
      application_version: '1.0.0'
    });
  }

  private async handleResponse(responseJson: string): Promise<void> {
    try {
      // Parse JSON off the main thread via TaskPool
      const task = new taskpool.Task(parseJsonInBackground, responseJson);
      const response = await taskpool.execute(task) as Record<string, object>;

      const type = response['@type'] as string;
      const extra = response['@extra'] as number;

      hilog.info(DOMAIN, TAG, 'Received: %{public}s', type);

      // Resolve pending request promise if this is a response
      if (extra !== undefined && this.pendingRequests.has(extra)) {
        const resolve = this.pendingRequests.get(extra);
        this.pendingRequests.delete(extra);
        if (resolve) {
          resolve(response);
        }
      }

      // Notify update handlers
      const handlers = this.handlers.get(type) || [];
      for (const handler of handlers) {
        handler(response);
      }

      // Also notify wildcard handlers
      const wildcardHandlers = this.handlers.get('*') || [];
      for (const handler of wildcardHandlers) {
        handler(response);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse response: %{public}s', responseJson);
    }
  }
}
