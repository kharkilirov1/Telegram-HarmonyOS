import { hilog } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
import { TELEGRAM_API_ID, TELEGRAM_API_HASH } from './ConfigLocal';

// Native NAPI module
import tdlib from 'libtdlib_napi.so';

// Offload heavy JSON parsing to TaskPool worker thread
@Concurrent
function parseJsonInBackground(jsonStr: string): Object {
  return JSON.parse(jsonStr) as Object;
}

const TAG = 'TDLibClient';
const DOMAIN = 0x0001;

type TDLibUpdateHandler = (update: Record<string, Object>) => void;

export class TDLibClient {
  private static instance: TDLibClient | null = null;
  private clientId: number = 0;
  private requestId: number = 0;
  private handlers: Map<string, TDLibUpdateHandler[]> = new Map();
  private pendingRequests: Map<number, (response: Record<string, Object>) => void> = new Map();

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
  async send(method: string, inputParams?: Record<string, Object>): Promise<Record<string, Object>> {
    const id: number = ++this.requestId;
    let request: Record<string, Object>;
    if (inputParams !== undefined) {
      request = inputParams;
    } else {
      request = {};
    }
    request['@type'] = method;
    request['@extra'] = id;

    return new Promise<Record<string, Object>>((resolve) => {
      this.pendingRequests.set(id, resolve);
      tdlib.send(this.clientId, JSON.stringify(request));
      hilog.info(DOMAIN, TAG, 'Sent: %{public}s', method);
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

  async setPhoneNumber(phoneNumber: string): Promise<Record<string, Object>> {
    const settings: Record<string, Object> = {};
    settings['@type'] = 'phoneNumberAuthenticationSettings';
    settings['allow_flash_call'] = false;
    settings['allow_missed_call'] = false;
    settings['is_current_phone_number'] = false;
    settings['allow_sms_retriever_api'] = false;
    const params: Record<string, Object> = {};
    params['phone_number'] = phoneNumber;
    params['settings'] = settings;
    return this.send('setAuthenticationPhoneNumber', params);
  }

  async checkAuthCode(code: string): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['code'] = code;
    return this.send('checkAuthenticationCode', params);
  }

  async checkAuthPassword(password: string): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['password'] = password;
    return this.send('checkAuthenticationPassword', params);
  }

  // --- Chat methods ---

  async loadChats(limit: number = 20): Promise<Record<string, Object>> {
    const chatList: Record<string, Object> = {};
    chatList['@type'] = 'chatListMain';
    const params: Record<string, Object> = {};
    params['chat_list'] = chatList;
    params['limit'] = limit;
    return this.send('loadChats', params);
  }

  async getChat(chatId: number): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    return this.send('getChat', params);
  }

  async getChatHistory(chatId: number, fromMessageId: number = 0,
    limit: number = 50): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['from_message_id'] = fromMessageId;
    params['offset'] = 0;
    params['limit'] = limit;
    params['only_local'] = false;
    return this.send('getChatHistory', params);
  }

  // --- Contact methods ---

  async getContacts(): Promise<Record<string, Object>> {
    return this.send('getContacts');
  }

  async searchContacts(query: string, limit: number = 50): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['query'] = query;
    params['limit'] = limit;
    return this.send('searchContacts', params);
  }

  async getUser(userId: number): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['user_id'] = userId;
    return this.send('getUser', params);
  }

  // --- Create chat ---

  async createPrivateChat(userId: number): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['user_id'] = userId;
    params['force'] = false;
    return this.send('createPrivateChat', params);
  }

  // --- Search ---

  async searchMessages(query: string, limit: number = 50): Promise<Record<string, Object>> {
    const chatList: Record<string, Object> = {};
    chatList['@type'] = 'chatListMain';
    const params: Record<string, Object> = {};
    params['chat_list'] = chatList;
    params['query'] = query;
    params['offset'] = '';
    params['offset_chat_id'] = 0;
    params['offset_message_id'] = 0;
    params['limit'] = limit;
    return this.send('searchMessages', params);
  }

  // --- Message methods ---

  async editMessageText(chatId: number, messageId: number, text: string): Promise<Record<string, Object>> {
    const formattedText: Record<string, Object> = {};
    formattedText['@type'] = 'formattedText';
    formattedText['text'] = text;
    const inputContent: Record<string, Object> = {};
    inputContent['@type'] = 'inputMessageText';
    inputContent['text'] = formattedText;
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['message_id'] = messageId;
    params['input_message_content'] = inputContent;
    return this.send('editMessageText', params);
  }

  async sendMessage(chatId: number, text: string, replyToMessageId: number = 0): Promise<Record<string, Object>> {
    const formattedText: Record<string, Object> = {};
    formattedText['@type'] = 'formattedText';
    formattedText['text'] = text;
    const inputContent: Record<string, Object> = {};
    inputContent['@type'] = 'inputMessageText';
    inputContent['text'] = formattedText;
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['input_message_content'] = inputContent;

    if (replyToMessageId > 0) {
      const replyTo: Record<string, Object> = {};
      replyTo['@type'] = 'inputMessageReplyToMessage';
      replyTo['message_id'] = replyToMessageId;
      params['reply_to'] = replyTo;
    }

    return this.send('sendMessage', params);
  }

  // --- Private methods ---

  private sendTdlibParameters(): void {
    const params: Record<string, Object> = {};
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
      const response: Record<string, Object> = (await taskpool.execute(task)) as Record<string, Object>;

      const type: string = (response['@type'] as string) || '';
      const extra: number = (response['@extra'] as number) || 0;

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
      const handlers: TDLibUpdateHandler[] = this.handlers.get(type) || [];
      for (const handler of handlers) {
        handler(response);
      }

      // Also notify wildcard handlers
      const wildcardHandlers: TDLibUpdateHandler[] = this.handlers.get('*') || [];
      for (const handler of wildcardHandlers) {
        handler(response);
      }
    } catch (_e) {
      hilog.error(DOMAIN, TAG, 'Failed to parse response: %{public}s', responseJson);
    }
  }
}
