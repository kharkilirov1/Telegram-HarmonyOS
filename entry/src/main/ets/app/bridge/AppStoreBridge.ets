// AppStoreBridge — мост между AppStore (domain) и AppStorage (UI)
//
// Huawei рекомендует использовать AppStorage для UI state sharing.
// Наш AppStore содержит domain logic (reducers, events).
// Этот мост синхронизирует изменения AppStore → AppStorage,
// позволяя UI использовать @StorageLink/@StorageProp декораторы.
//
// Документация:
// - https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-appstorage
// - AppStorage.setOrCreate() для инициализации
// - @StorageLink для двусторонней связи в UI
// - @StorageProp для односторонней связи в UI

import { AppStore } from '../../core/store/AppStore';
import { AppState, AuthStatus, ConnectionStatus, Chat } from '../../core/model/AppState';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AppStoreBridge';
const DOMAIN = 0x0011;

// ─── Storage Keys ───
// Используем константы для ключей чтобы избежать опечаток

export class StorageKeys {
  // Auth
  static readonly AUTH_STATUS: string = 'tg_authStatus';
  static readonly AUTH_PHONE: string = 'tg_authPhone';
  static readonly AUTH_USER_ID: string = 'tg_authUserId';
  static readonly AUTH_ERROR: string = 'tg_authError';

  // Connection
  static readonly CONNECTION_STATUS: string = 'tg_connectionStatus';
  static readonly IS_CONNECTED: string = 'tg_isConnected';

  // Chats
  static readonly CHATS_COUNT: string = 'tg_chatsCount';
  static readonly CHATS_IS_LOADING: string = 'tg_chatsIsLoading';
  static readonly TOTAL_UNREAD_COUNT: string = 'tg_totalUnreadCount';

  // Active chat navigation context (UI-only)
  static readonly ACTIVE_CHAT_ID: string = 'tg_activeChatId';
  static readonly ACTIVE_CHAT_TITLE: string = 'tg_activeChatTitle';
  static readonly CHAT_SCREEN_VISIBLE: string = 'tg_chatScreenVisible';
  static readonly MAIN_TAB_INDEX: string = 'tg_mainTabIndex';

  // Code info (for login flow)
  static readonly CODE_TYPE: string = 'tg_codeType';
  static readonly CODE_LENGTH: string = 'tg_codeLength';
  static readonly CODE_TIMEOUT: string = 'tg_codeTimeout';
  static readonly CODE_NEXT_TYPE: string = 'tg_codeNextType';
  static readonly PASSWORD_HINT: string = 'tg_passwordHint';

  // UI effects / glass quality policy
  static readonly GLASS_MODE: string = 'tg_glassMode'; // auto | high | fallback
}

// ─── Bridge Class ───

export class AppStoreBridge {
  private store: AppStore;
  private unsubscribe: (() => void) | null = null;
  private isInitialized: boolean = false;

  constructor(store: AppStore) {
    this.store = store;
  }

  /**
   * Инициализирует AppStorage с начальными значениями
   * и подписывается на изменения AppStore.
   *
   * Вызывать после AppCoreRuntime.initialize()
   */
  initialize(): void {
    if (this.isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Bridge already initialized');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Initializing AppStorage bridge...');

    // 1. Установить начальные значения в AppStorage
    this.initializeStorage();

    // 2. Синхронизировать текущее состояние
    const currentState = this.store.getState();
    this.syncToStorage(currentState);

    // 3. Подписаться на изменения AppStore
    this.unsubscribe = this.store.subscribe((newState: AppState, _prevState: AppState) => {
      this.syncToStorage(newState);
    });

    this.isInitialized = true;
    hilog.info(DOMAIN, TAG, 'AppStorage bridge initialized');
  }

  /**
   * Отписывается от AppStore.
   * Вызывать при shutdown приложения.
   */
  destroy(): void {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
    this.isInitialized = false;
    hilog.info(DOMAIN, TAG, 'AppStorage bridge destroyed');
  }

  /**
   * Инициализирует ключи в AppStorage с дефолтными значениями.
   */
  private initializeStorage(): void {
    // Auth
    AppStorage.setOrCreate<string>(StorageKeys.AUTH_STATUS, 'notInitialized');
    AppStorage.setOrCreate<string>(StorageKeys.AUTH_PHONE, '');
    AppStorage.setOrCreate<number>(StorageKeys.AUTH_USER_ID, 0);
    AppStorage.setOrCreate<string>(StorageKeys.AUTH_ERROR, '');

    // Connection
    AppStorage.setOrCreate<string>(StorageKeys.CONNECTION_STATUS, 'connecting');
    AppStorage.setOrCreate<boolean>(StorageKeys.IS_CONNECTED, false);

    // Chats
    AppStorage.setOrCreate<number>(StorageKeys.CHATS_COUNT, 0);
    AppStorage.setOrCreate<boolean>(StorageKeys.CHATS_IS_LOADING, false);
    AppStorage.setOrCreate<number>(StorageKeys.TOTAL_UNREAD_COUNT, 0);
    AppStorage.setOrCreate<number>(StorageKeys.ACTIVE_CHAT_ID, 0);
    AppStorage.setOrCreate<string>(StorageKeys.ACTIVE_CHAT_TITLE, '');
    AppStorage.setOrCreate<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    AppStorage.setOrCreate<number>(StorageKeys.MAIN_TAB_INDEX, 2);

    // Code info
    AppStorage.setOrCreate<string>(StorageKeys.CODE_TYPE, 'sms');
    AppStorage.setOrCreate<number>(StorageKeys.CODE_LENGTH, 5);
    AppStorage.setOrCreate<number>(StorageKeys.CODE_TIMEOUT, 60);
    AppStorage.setOrCreate<string>(StorageKeys.CODE_NEXT_TYPE, 'call');
    AppStorage.setOrCreate<string>(StorageKeys.PASSWORD_HINT, '');

    // UI effects policy
    AppStorage.setOrCreate<string>(StorageKeys.GLASS_MODE, 'auto');

    hilog.info(DOMAIN, TAG, 'AppStorage keys initialized');
  }

  /**
   * Синхронизирует состояние AppStore → AppStorage.
   * Вызывается при каждом изменении AppStore.
   */
  private syncToStorage(state: AppState): void {
    // Auth
    AppStorage.set<string>(StorageKeys.AUTH_STATUS, state.auth.status);
    AppStorage.set<string>(StorageKeys.AUTH_PHONE, state.auth.phoneNumber);
    AppStorage.set<number>(StorageKeys.AUTH_USER_ID, state.auth.userId);
    AppStorage.set<string>(StorageKeys.AUTH_ERROR, state.auth.error);

    // Connection
    AppStorage.set<string>(StorageKeys.CONNECTION_STATUS, state.connection.status);
    AppStorage.set<boolean>(StorageKeys.IS_CONNECTED, state.connection.status === 'ready');

    // Chats
    AppStorage.set<number>(StorageKeys.CHATS_COUNT, state.chats.chats.size);
    AppStorage.set<boolean>(StorageKeys.CHATS_IS_LOADING, state.chats.isLoading);

    // Total unread count across all chats
    let totalUnread = 0;
    state.chats.chats.forEach((chat: Chat) => {
      totalUnread += chat.unreadCount;
    });
    AppStorage.set<number>(StorageKeys.TOTAL_UNREAD_COUNT, totalUnread);

    // Auth code metadata (waitCode / waitPassword)
    AppStorage.set<string>(StorageKeys.CODE_TYPE, state.auth.codeType);
    AppStorage.set<number>(StorageKeys.CODE_LENGTH, state.auth.codeLength);
    AppStorage.set<number>(StorageKeys.CODE_TIMEOUT, state.auth.codeTimeout);
    AppStorage.set<string>(StorageKeys.CODE_NEXT_TYPE, state.auth.nextCodeType);
    AppStorage.set<string>(StorageKeys.PASSWORD_HINT, state.auth.passwordHint);
  }

  /**
   * Ручное обновление code info (вызывается из LoginController).
   */
  updateCodeInfo(codeType: string, codeLength: number, timeout: number, nextType: string = 'call'): void {
    AppStorage.set<string>(StorageKeys.CODE_TYPE, codeType);
    AppStorage.set<number>(StorageKeys.CODE_LENGTH, codeLength);
    AppStorage.set<number>(StorageKeys.CODE_TIMEOUT, timeout);
    AppStorage.set<string>(StorageKeys.CODE_NEXT_TYPE, nextType);
  }

  /**
   * Ручное обновление password hint.
   */
  updatePasswordHint(hint: string): void {
    AppStorage.set<string>(StorageKeys.PASSWORD_HINT, hint);
  }
}

// ─── Singleton ───

let bridgeInstance: AppStoreBridge | null = null;

export function initAppStoreBridge(store: AppStore): AppStoreBridge {
  if (bridgeInstance) {
    hilog.warn(DOMAIN, TAG, 'Bridge already initialized — returning existing instance');
    return bridgeInstance;
  }
  bridgeInstance = new AppStoreBridge(store);
  bridgeInstance.initialize();
  return bridgeInstance;
}

export function getAppStoreBridge(): AppStoreBridge | null {
  return bridgeInstance;
}

export function resetAppStoreBridge(): void {
  if (bridgeInstance) {
    bridgeInstance.destroy();
    bridgeInstance = null;
  }
}
