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
import { AppState, AuthStatus, ConnectionStatus } from '../../core/model/AppState';
import { authUIState, chatsUIState, navigationUIState } from '../../core/model/UIStateModels';
import { selectTotalUnreadCount } from '../../domain/selectors/chatSelectors';
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
  static readonly CHATS_HAS_MORE: string = 'tg_chatsHasMore';
  static readonly CHATS_LOAD_PHASE: string = 'tg_chatsLoadPhase';
  static readonly TOTAL_UNREAD_COUNT: string = 'tg_totalUnreadCount';

  // Active chat navigation context (UI-only)
  static readonly ACTIVE_CHAT_ID: string = 'tg_activeChatId';
  static readonly ACTIVE_CHAT_TITLE: string = 'tg_activeChatTitle';
  static readonly CHAT_SCREEN_VISIBLE: string = 'tg_chatScreenVisible';
  static readonly CHAT_NAV_LOCK_UNTIL: string = 'tg_chatNavLockUntil';
  static readonly MAIN_TAB_INDEX: string = 'tg_mainTabIndex';

  // Code info (for login flow)
  static readonly CODE_TYPE: string = 'tg_codeType';
  static readonly CODE_LENGTH: string = 'tg_codeLength';
  static readonly CODE_TIMEOUT: string = 'tg_codeTimeout';
  static readonly CODE_NEXT_TYPE: string = 'tg_codeNextType';
  static readonly PASSWORD_HINT: string = 'tg_passwordHint';
  static readonly QR_CODE_LINK: string = 'tg_qrCodeLink';

  // UI effects / glass quality policy
  static readonly GLASS_MODE: string = 'tg_glassMode'; // auto | high | fallback
}

// ─── Bridge Class ───

export class AppStoreBridge {
  private store: AppStore;
  private unsubscribe: (() => void) | null = null;
  private isInitialized: boolean = false;
  private subscriptionSerial: number = 0;

  constructor(store: AppStore) {
    this.store = store;
  }

  private isCurrentBridgeSubscription(subscriptionSerial: number, unsubscribe: (() => void) | null): boolean {
    return this.isInitialized &&
      this.subscriptionSerial === subscriptionSerial &&
      this.unsubscribe === unsubscribe;
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
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
    this.subscriptionSerial += 1;
    const subscriptionSerial: number = this.subscriptionSerial;
    let activeUnsubscribe: (() => void) | null = null;
    activeUnsubscribe = this.store.subscribe((newState: AppState, _prevState: AppState) => {
      if (!this.isCurrentBridgeSubscription(subscriptionSerial, activeUnsubscribe)) {
        return;
      }
      this.syncToStorage(newState);
    });
    this.unsubscribe = activeUnsubscribe;

    this.isInitialized = true;
    hilog.info(DOMAIN, TAG, 'AppStorage bridge initialized');
  }

  /**
   * Отписывается от AppStore.
   * Вызывать при shutdown приложения.
   */
  destroy(): void {
    this.subscriptionSerial += 1;
    const activeUnsubscribe = this.unsubscribe;
    this.unsubscribe = null;
    this.isInitialized = false;
    if (activeUnsubscribe) {
      activeUnsubscribe();
    }
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
    AppStorage.setOrCreate<boolean>(StorageKeys.CHATS_HAS_MORE, true);
    AppStorage.setOrCreate<string>(StorageKeys.CHATS_LOAD_PHASE, 'idle');
    AppStorage.setOrCreate<number>(StorageKeys.TOTAL_UNREAD_COUNT, 0);
    AppStorage.setOrCreate<number>(StorageKeys.ACTIVE_CHAT_ID, 0);
    AppStorage.setOrCreate<string>(StorageKeys.ACTIVE_CHAT_TITLE, '');
    AppStorage.setOrCreate<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    AppStorage.setOrCreate<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, 0);
    AppStorage.setOrCreate<number>(StorageKeys.MAIN_TAB_INDEX, 2);

    // QR code
    AppStorage.setOrCreate<string>(StorageKeys.QR_CODE_LINK, '');

    // Code info
    AppStorage.setOrCreate<string>(StorageKeys.CODE_TYPE, 'sms');
    AppStorage.setOrCreate<number>(StorageKeys.CODE_LENGTH, 5);
    AppStorage.setOrCreate<number>(StorageKeys.CODE_TIMEOUT, 60);
    AppStorage.setOrCreate<string>(StorageKeys.CODE_NEXT_TYPE, 'call');
    AppStorage.setOrCreate<string>(StorageKeys.PASSWORD_HINT, '');

    // UI effects policy
    AppStorage.setOrCreate<string>(StorageKeys.GLASS_MODE, 'auto');

    // ── Init @ObservedV2 navigation model defaults ──
    navigationUIState.mainTabIndex = 2;
    navigationUIState.chatScreenVisible = false;
    navigationUIState.glassMode = 'auto';

    hilog.info(DOMAIN, TAG, 'AppStorage keys initialized');
  }

  /**
   * Синхронизирует состояние AppStore → AppStorage.
   * Вызывается при каждом изменении AppStore.
   */
  private syncToStorage(state: AppState): void {
    // Auth — AppStorage (V1 fallback) + V2 синглтон
    AppStorage.set<string>(StorageKeys.AUTH_STATUS, state.auth.status);
    AppStorage.set<string>(StorageKeys.AUTH_PHONE, state.auth.phoneNumber);
    AppStorage.set<number>(StorageKeys.AUTH_USER_ID, state.auth.userId);
    AppStorage.set<string>(StorageKeys.AUTH_ERROR, state.auth.error);
    authUIState.authStatus = state.auth.status;
    authUIState.phone = state.auth.phoneNumber;

    // Connection — AppStorage (V1 fallback) + V2 синглтон
    AppStorage.set<string>(StorageKeys.CONNECTION_STATUS, state.connection.status);
    AppStorage.set<boolean>(StorageKeys.IS_CONNECTED, state.connection.status === 'ready');
    chatsUIState.connectionStatus = state.connection.status;

    // Chats — AppStorage (V1 fallback) + V2 синглтон
    AppStorage.set<number>(StorageKeys.CHATS_COUNT, state.chats.orderedChatIds.length);
    AppStorage.set<boolean>(StorageKeys.CHATS_IS_LOADING, state.chats.isLoading);
    AppStorage.set<boolean>(StorageKeys.CHATS_HAS_MORE, state.chats.hasMore);
    AppStorage.set<string>(StorageKeys.CHATS_LOAD_PHASE, state.chats.loadPhase);
    chatsUIState.chatsCount = state.chats.orderedChatIds.length;
    chatsUIState.chatsIsLoading = state.chats.isLoading;
    chatsUIState.chatsHasMore = state.chats.hasMore;
    chatsUIState.chatsLoadPhase = state.chats.loadPhase;

    // Telegram iOS root badge uses renderedTotalUnreadCount (messages, not chats).
    // Prefer TDLib's complete aggregate and fall back to loaded main-list rows
    // only until updateUnreadMessageCount arrives.
    const totalUnread = selectTotalUnreadCount(state);
    AppStorage.set<number>(StorageKeys.TOTAL_UNREAD_COUNT, totalUnread);

    // ── Sync @ObservedV2 models (для V2-компонентов) ──
    chatsUIState.connectionStatus = state.connection.status;
    chatsUIState.chatsCount = state.chats.orderedChatIds.length;
    chatsUIState.chatsIsLoading = state.chats.isLoading;
    chatsUIState.chatsHasMore = state.chats.hasMore;
    chatsUIState.chatsLoadPhase = state.chats.loadPhase;
    chatsUIState.totalUnreadCount = totalUnread;

    // QR code link
    AppStorage.set<string>(StorageKeys.QR_CODE_LINK, state.auth.qrCodeLink);

    // Auth code metadata (waitCode / waitPassword) — AppStorage (V1 fallback) + V2 синглтон
    AppStorage.set<string>(StorageKeys.CODE_TYPE, state.auth.codeType);
    AppStorage.set<number>(StorageKeys.CODE_LENGTH, state.auth.codeLength);
    AppStorage.set<number>(StorageKeys.CODE_TIMEOUT, state.auth.codeTimeout);
    AppStorage.set<string>(StorageKeys.CODE_NEXT_TYPE, state.auth.nextCodeType);
    AppStorage.set<string>(StorageKeys.PASSWORD_HINT, state.auth.passwordHint);
    authUIState.codeType = state.auth.codeType;
    authUIState.codeLength = state.auth.codeLength;
    authUIState.codeTimeout = state.auth.codeTimeout;
    authUIState.codeNextType = state.auth.nextCodeType;
    authUIState.passwordHint = state.auth.passwordHint;
  }

  /**
   * Ручное обновление code info (вызывается из LoginController).
   */
  updateCodeInfo(codeType: string, codeLength: number, timeout: number, nextType: string = 'call'): void {
    AppStorage.set<string>(StorageKeys.CODE_TYPE, codeType);
    AppStorage.set<number>(StorageKeys.CODE_LENGTH, codeLength);
    AppStorage.set<number>(StorageKeys.CODE_TIMEOUT, timeout);
    AppStorage.set<string>(StorageKeys.CODE_NEXT_TYPE, nextType);
    authUIState.codeType = codeType;
    authUIState.codeLength = codeLength;
    authUIState.codeTimeout = timeout;
    authUIState.codeNextType = nextType;
  }

  /**
   * Ручное обновление password hint.
   */
  updatePasswordHint(hint: string): void {
    AppStorage.set<string>(StorageKeys.PASSWORD_HINT, hint);
    authUIState.passwordHint = hint;
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
