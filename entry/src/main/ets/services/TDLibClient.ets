import { hilog } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { TELEGRAM_API_ID, TELEGRAM_API_HASH } from './ConfigLocal';
import { SecurityService, SecurityMode } from './SecurityService';
import { TdFallbackRegistry } from './TdFallbackRegistry';
import { classifyTdlibError } from './AppError';
import { TdObject } from '../models/TdTypes';

// Error message prefixes — shared with AppError for classification
export const ERR_TDLIB_INIT_TIMEOUT = 'TDLIB_INIT_TIMEOUT';
export const ERR_TDLIB_CLIENT_DESTROYED = 'TDLIB_CLIENT_DESTROYED';

// Native NAPI module
import tdlib from 'libtdlib_napi.so';

// --- TDLib runtime info from native layer ---
interface TdlibInfo {
  mode: string;   // "REAL" | "STUB"
  tdlibDir: string;
  soname: string;
}

// Offload heavy JSON parsing to TaskPool worker thread
@Concurrent
function parseJsonInBackground(jsonStr: string): Object {
  return JSON.parse(jsonStr) as Object;
}

const TAG = 'TDLibClient';
const DOMAIN = 0x0001;

// Default timeout for TDLib requests (30 seconds)
const REQUEST_TIMEOUT_MS = 30000;

// Default timeout for waitForReady() initialization barrier (30 seconds)
const INIT_TIMEOUT_MS = 30000;

// --- TDLib database paths (single source of truth) ---
const TDLIB_DB_DIR = '/data/storage/el2/base/tdlib';
const TDLIB_FILES_DIR = '/data/storage/el2/base/tdlib/files';
// --- Encryption schema versioning ---
// Each version writes a marker file .enc_key_v<N> in the DB directory.
// The migration dispatcher reads the current version and runs necessary upgrades.
const DB_ENC_SCHEMA_DIR = '/data/storage/el2/base/tdlib';
const DB_ENC_MARKER_PREFIX = '.enc_key_v';
// Current encryption schema version. Bump when key derivation or DB encryption changes.
const DB_ENC_CURRENT_VERSION = 1;

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

  // Ready barrier: resolved when initialize() completes successfully.
  // Callers that need to wait for init can `await TDLibClient.getInstance().waitForReady()`.
  private _readyResolve: (() => void) | null = null;
  private _readyReject: ((reason: Error) => void) | null = null;
  private _readyPromise: Promise<void>;

  // True when running REAL TDLib with SOFTWARE_FALLBACK encryption.
  // Production builds should treat this as a degraded state.
  private _degradedSecurity: boolean = false;

  private constructor() {
    this._readyPromise = new Promise<void>((resolve, reject) => {
      this._readyResolve = resolve;
      this._readyReject = reject;
    });
    // Prevent unhandled rejection if destroy() rejects the barrier with no waiters
    this._readyPromise.catch(() => {});
  }

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

  /**
   * Returns a promise that resolves when the client reaches Ready state.
   * Safe to call multiple times — returns the same promise.
   * Use this when code outside TelegramAbilityStage needs to ensure
   * the client is initialized before sending requests.
   *
   * Example: `await TDLibClient.getInstance().waitForReady();`
   */
  waitForReady(timeoutMs: number = INIT_TIMEOUT_MS): Promise<void> {
    if (this._state === ClientState.Ready) {
      return Promise.resolve();
    }
    if (this._state === ClientState.Stopped || this._state === ClientState.Stopping) {
      return Promise.reject(
        new TDLibError(0, `${ERR_TDLIB_CLIENT_DESTROYED}: client is not running`));
    }

    return new Promise<void>((resolve, reject) => {
      let settled = false;

      const timerId = setTimeout(() => {
        if (settled) return;
        settled = true;
        const security = SecurityService.getInstance();
        this.logError(
          '%{public}s: state=%{public}s, elapsedMs=%{public}d, secMode=%{public}s, tdlibMode=%{public}s',
          ERR_TDLIB_INIT_TIMEOUT, this._state, timeoutMs, security.mode, this.tdlibMode);
        reject(new TDLibError(0,
          `${ERR_TDLIB_INIT_TIMEOUT}: initialization did not complete within ${timeoutMs}ms ` +
          `(state=${this._state}, secMode=${security.mode}, tdlibMode=${this.tdlibMode})`));
      }, timeoutMs);

      this._readyPromise.then(() => {
        if (settled) return;
        settled = true;
        clearTimeout(timerId);
        resolve();
      }).catch((err: Error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timerId);
        reject(err);
      });
    });
  }

  /** Cached TDLib mode from native layer. Set once during initialize(). */
  private _tdlibInfo: TdlibInfo | null = null;

  /** Returns "REAL" or "STUB" after initialize(). */
  get tdlibMode(): string {
    return this._tdlibInfo?.mode ?? 'UNKNOWN';
  }

  /**
   * True when REAL TDLib is running with SOFTWARE_FALLBACK encryption.
   * This means the database encryption key is NOT hardware-backed.
   * UI/monitoring should surface this prominently in production builds.
   */
  get isDegradedSecurity(): boolean {
    return this._degradedSecurity;
  }

  async initialize(): Promise<void> {
    if (this._state !== ClientState.Idle && this._state !== ClientState.Stopped) {
      this.logWarn('initialize() called in invalid state: %{public}s', this._state);
      return;
    }

    this._degradedSecurity = false;

    // --- Query native layer for TDLib build info (REAL vs STUB) ---
    try {
      const infoJson: string = tdlib.getTdlibInfo();
      this._tdlibInfo = JSON.parse(infoJson) as TdlibInfo;
    } catch (e) {
      this._tdlibInfo = { mode: 'UNKNOWN', tdlibDir: '', soname: '' };
      this.logError('Failed to query TDLib info: %{public}s', String(e));
    }

    this.logInfo('┌─ TDLib Client Init ─────────────────────────');
    this.logInfo('│ TDLIB_MODE:  %{public}s', this._tdlibInfo!.mode);
    this.logInfo('│ TDLIB_DIR:   %{public}s', this._tdlibInfo!.tdlibDir);
    this.logInfo('│ SONAME:      %{public}s', this._tdlibInfo!.soname);
    this.logInfo('│ API_ID:      %{public}s', TELEGRAM_API_ID > 0 ? 'configured' : 'NOT SET');
    this.logInfo('│ API_HASH:    %{public}s', TELEGRAM_API_HASH.length > 0 ? 'configured' : 'NOT SET');
    this.logInfo('│ DB_PATH:     %{public}s', TDLIB_DB_DIR);
    this.logInfo('│ SEC_MODE:    (pending — resolved after HUKS init)');

    // Validate API credentials
    if (TELEGRAM_API_ID === 0 || TELEGRAM_API_HASH.length === 0) {
      this.logError('API credentials not configured. Copy ConfigLocal.example.ets → ConfigLocal.ets and fill in your values from https://my.telegram.org/apps');
      if (this._tdlibInfo!.mode === 'REAL') {
        // In REAL mode without credentials, TDLib will fail immediately — warn loudly
        this.logError('REAL TDLib mode requires valid API credentials. Init will likely fail.');
      }
    }

    // Warn if STUB mode with real credentials — possible misconfiguration
    if (this._tdlibInfo!.mode === 'STUB' && TELEGRAM_API_ID > 0) {
      this.logWarn('STUB mode active but API credentials are set. Requests will NOT reach Telegram servers.');
    }

    this._state = ClientState.Initializing;
    this.clientId = tdlib.createClient();
    this.logInfo('Client created with id: %{public}d', this.clientId);

    // Initialize SecurityService for database encryption key
    const security = SecurityService.getInstance();
    await security.initialize();
    const dbEncKey = security.getDatabaseEncryptionKey();
    this.logInfo('│ SEC_MODE:    %{public}s (resolved)', security.mode);
    this.logInfo('└──────────────────────────────────────────────');
    if (dbEncKey.length === 0) {
      this.logWarn('Database encryption key is empty — TDLib database will be unencrypted');
    }

    // Release/profile guard: SOFTWARE_FALLBACK in REAL mode = degraded production
    if (security.mode === SecurityMode.SOFTWARE_FALLBACK && this._tdlibInfo!.mode === 'REAL') {
      this._degradedSecurity = true;
      this.logError('┌─ DEGRADED SECURITY ─────────────────────────────');
      this.logError('│ REAL TDLib mode with SOFTWARE_FALLBACK encryption.');
      this.logError('│ Database encryption key is NOT hardware-backed (HUKS unavailable).');
      this.logError('│ This build is NOT production-safe for sensitive data.');
      this.logError('│ Ensure the device supports HUKS (TEE/Secure Element)');
      this.logError('│ or accept degraded security for this deployment.');
      this.logError('└──────────────────────────────────────────────────');
    } else if (security.mode === SecurityMode.SOFTWARE_FALLBACK) {
      // STUB mode — expected in dev/emulator, just log info
      this.logInfo('SOFTWARE_FALLBACK in STUB mode — acceptable for development');
    }

    // Guard: ensure DB is compatible with the current encryption scheme.
    // Must run BEFORE startReceiveLoop/sendTdlibParameters.
    this.ensureDbEncryptionMigration();

    // Start receiving updates from TDLib on a background thread
    tdlib.startReceiveLoop((responseJson: string) => {
      if (this._state === ClientState.Stopped) return;
      this.handleResponse(responseJson);
    });

    // Send TDLib parameters (single source of truth)
    this.sendTdlibParameters(dbEncKey);
    this._state = ClientState.Ready;

    // Signal the ready barrier — unblocks any waitForReady() callers
    if (this._readyResolve) {
      this._readyResolve();
    }
  }

  destroy(): void {
    if (this._state === ClientState.Stopped || this._state === ClientState.Stopping) {
      this.logWarn('destroy() called in state %{public}s, ignoring', this._state);
      return;
    }

    this._state = ClientState.Stopping;
    const pendingCount = this.pendingRequests.size;
    this.logInfo('Destroying client, rejecting %{public}d pending request(s)', pendingCount);

    // Reject all pending requests with explicit per-request reason
    this.pendingRequests.forEach((pending: PendingRequest, id: number) => {
      clearTimeout(pending.timerId);
      this.logDebug('Rejecting pending #%{public}d (%{public}s)', id, pending.method);
      pending.reject(0, `Client destroyed while '${pending.method}' was pending`);
    });
    this.pendingRequests.clear();

    // Clear all event handlers
    this.handlers.clear();

    tdlib.stopReceiveLoop();
    this._state = ClientState.Stopped;

    // Reject any pending waitForReady() callers before resetting the barrier
    if (this._readyReject) {
      this._readyReject(
        new TDLibError(0, `${ERR_TDLIB_CLIENT_DESTROYED}: client was destroyed during initialization`));
      this._readyReject = null;
      this._readyResolve = null;
    }

    // Reset the ready barrier for potential re-initialization
    this._readyPromise = new Promise<void>((resolve, reject) => {
      this._readyResolve = resolve;
      this._readyReject = reject;
    });
    this._readyPromise.catch(() => {});

    this.logInfo('Client destroyed');
  }

  // Send a request and get a promise for the response.
  // Rejects immediately if the client is not in a sendable state.
  async send(method: string, inputParams?: TdObject): Promise<TdObject> {
    // Snapshot state to avoid TOCTOU race with destroy()
    const currentState = this._state;
    if (currentState !== ClientState.Ready && currentState !== ClientState.Initializing) {
      throw new TDLibError(0, `Cannot send '${method}' in state '${currentState}'`);
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
      // Double-check: state may have changed to Stopping between the check above and now
      if (this._state === ClientState.Stopping || this._state === ClientState.Stopped) {
        reject(new TDLibError(0, `Cannot send '${method}': client is shutting down`));
        return;
      }

      // Set timeout to auto-reject hanging requests
      const timerId: number = setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          this.logWarn('Request #%{public}d (%{public}s) timed out', id, method);
          reject(new TDLibError(0, `Request '${method}' timed out after ${REQUEST_TIMEOUT_MS}ms`));
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
      this.logDebug('Sent: %{public}s (#%{public}d)', method, id);
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

  // --- Reactions ---

  async addMessageReaction(chatId: number, messageId: number, emoji: string, isBig: boolean = false): Promise<TdObject> {
    const reactionType: TdObject = {};
    reactionType['@type'] = 'reactionTypeEmoji';
    reactionType['emoji'] = emoji;
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['message_id'] = messageId;
    params['reaction_type'] = reactionType;
    params['is_big'] = isBig;
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

  // --- Pinned message ---

  async getChatPinnedMessage(chatId: number): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    return this.send('getChatPinnedMessage', params);
  }

  // --- View messages (mark as read) ---

  async viewMessages(chatId: number, messageIds: number[]): Promise<TdObject> {
    const params: TdObject = {};
    params['chat_id'] = chatId;
    params['message_ids'] = messageIds;
    params['force_read'] = true;
    return this.send('viewMessages', params);
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

  /**
   * Versioned DB encryption migration dispatcher.
   *
   * Reads the current schema version from marker files (.enc_key_v<N>)
   * and runs the necessary upgrade steps to reach DB_ENC_CURRENT_VERSION.
   *
   * Version history:
   *   v0 (implicit) — no marker, no encryption key. Legacy unencrypted DB.
   *   v1            — first encrypted DB via SecurityService + HUKS/fallback.
   *   v2+           — reserved for future key-derivation changes.
   *
   * Extension point: add a case to the switch below for v1→v2, v2→v3, etc.
   * Each migration runs exactly once and writes the new marker before proceeding.
   *
   * Rollback: delete .enc_key_v<N> markers and pass an empty encryption key
   * in sendTdlibParameters().
   */
  private ensureDbEncryptionMigration(): void {
    const currentVersion = this.readEncSchemaVersion();
    const targetVersion = DB_ENC_CURRENT_VERSION;

    if (currentVersion >= targetVersion) {
      this.logDebug('DB encryption schema v%{public}d — up to date', currentVersion);
      return;
    }

    this.logInfo('DB encryption schema: v%{public}d → v%{public}d', currentVersion, targetVersion);

    // Run each migration step sequentially
    for (let from = currentVersion; from < targetVersion; from++) {
      switch (from) {
        case 0:
          this.migrateEncV0toV1();
          break;
        // Extension point: future migrations
        // case 1:
        //   this.migrateEncV1toV2();
        //   break;
        default:
          this.logError('Unknown encryption schema version %{public}d — aborting migration', from);
          throw new Error(`Unknown encryption schema version ${from}: cannot migrate`);
      }
    }
  }

  /**
   * Detect the current encryption schema version by scanning for marker files.
   * Returns 0 if no marker exists (legacy or fresh install).
   */
  private readEncSchemaVersion(): number {
    // Scan from highest plausible version down to find the current one
    for (let v = DB_ENC_CURRENT_VERSION; v >= 1; v--) {
      const markerPath = `${DB_ENC_SCHEMA_DIR}/${DB_ENC_MARKER_PREFIX}${v}`;
      try {
        const exists = fileIo.accessSync(markerPath);
        if (exists) {
          return v;
        }
      } catch (_e) {
        // Marker doesn't exist — try lower version
      }
    }
    return 0; // No marker found → v0 (legacy or fresh install)
  }

  /**
   * Write a schema version marker file.
   */
  private writeEncSchemaMarker(version: number): void {
    const markerPath = `${DB_ENC_SCHEMA_DIR}/${DB_ENC_MARKER_PREFIX}${version}`;
    try {
      const fd = fileIo.openSync(markerPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(fd.fd, `v${version}`);
      fileIo.closeSync(fd);
      this.logInfo('DB encryption marker written: v%{public}d', version);
    } catch (e) {
      this.logError('Failed to write migration marker v%{public}d: %{public}s',
        version, String(e));
    }
  }

  /**
   * Migration v0 → v1: legacy unencrypted DB to first encrypted schema.
   *
   * If an existing DB directory is present without a v1 marker,
   * it was created without encryption and must be reset.
   */
  private migrateEncV0toV1(): void {
    let dbDirExists = false;
    try {
      const stat = fileIo.statSync(TDLIB_DB_DIR);
      dbDirExists = stat.isDirectory();
    } catch (_e) {
      // Directory doesn't exist → fresh install, no migration needed
    }

    if (dbDirExists) {
      this.logWarn('┌─ DB ENCRYPTION MIGRATION v0→v1 ─────────────────');
      this.logWarn('│ Found existing TDLib database without encryption marker.');
      this.logWarn('│ Removing old unencrypted database for safe re-creation.');
      this.logWarn('│ User will need to re-authenticate after this one-time reset.');
      this.logWarn('└────────────────────────────────────────────────');

      try {
        this.removeDirRecursive(TDLIB_DB_DIR);
        this.logInfo('Old DB directory removed: %{public}s', TDLIB_DB_DIR);
      } catch (e) {
        this.logError('Failed to remove old DB directory: %{public}s', String(e));
      }
    }

    // Ensure the DB directory exists
    try {
      fileIo.mkdirSync(TDLIB_DB_DIR, true);
    } catch (_e) {
      // May already exist — harmless
    }

    this.writeEncSchemaMarker(1);
  }

  /**
   * SINGLE SOURCE OF TRUTH for TDLib parameters.
   * All TDLib config values are set here and nowhere else.
   * @param dbEncryptionKey - base64-encoded database encryption key from SecurityService
   */
  private sendTdlibParameters(dbEncryptionKey: string): void {
    const dbDir = TDLIB_DB_DIR;
    const filesDir = TDLIB_FILES_DIR;

    const params: TdObject = {};
    params['database_directory'] = dbDir;
    params['files_directory'] = filesDir;
    params['database_encryption_key'] = dbEncryptionKey;
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

    this.logInfo('TDLib params: db=%{public}s, files=%{public}s, enc_key=%{public}s',
      dbDir, filesDir, dbEncryptionKey.length > 0 ? 'set(' + dbEncryptionKey.length + ' chars)' : 'EMPTY');

    this.send('setTdlibParameters', params);
  }

  private async handleResponse(responseJson: string): Promise<void> {
    // Guard: discard responses that arrive after destroy began
    if (this._state === ClientState.Stopped) return;

    try {
      // Parse JSON off the main thread via TaskPool
      const task: taskpool.Task = new taskpool.Task(parseJsonInBackground, responseJson);
      const response: TdObject = (await taskpool.execute(task)) as TdObject;

      // Re-check after async gap: state may have changed during JSON parsing
      if (this._state === ClientState.Stopped) {
        this.logDebug('Discarding response after destroy: %{public}s',
          (response['@type'] as string) || 'unknown');
        return;
      }

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

  private removeDirRecursive(dirPath: string): void {
    const entries = fileIo.listFileSync(dirPath);
    for (const name of entries) {
      const full = `${dirPath}/${name}`;
      const stat = fileIo.statSync(full);
      if (stat.isDirectory()) {
        this.removeDirRecursive(full);
      } else {
        fileIo.unlinkSync(full);
      }
    }
    fileIo.rmdirSync(dirPath);
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
