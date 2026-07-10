// AuthSideEffect — автоматическая инициализация TDLib параметров
// Подписывается на Gateway updates, при authorizationStateWaitTdlibParameters
// автоматически отправляет setTdlibParameters с api_id, api_hash, путями БД
//
// Референс: iOS Telegram — AuthStateController + Config

import { TdGateway, getTdGateway } from '../../infra/td/gateway/TdGateway';
import { getTdGatewayAdapter } from '../../infra/td/adapter/TdGatewayAdapter';
import { TdObject } from '../../models/td/common';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppContext } from '../../core/utils/AppResource';
import { AppError } from '../model/AppError';
import { AppStore } from '../store/AppStore';
import { createMyUserResolvedEvent } from '../model/AppEvent';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { TELEGRAM_API_HASH, TELEGRAM_API_ID, USE_TEST_DC } from '../../services/ConfigLocal';
import { createLoadChatsUseCase } from '../../domain/usecases/loadChats';
import { createGetChatCommand, createOpenChatCommand, createSetTdlibOnlineCommand } from '../model/AppCommand';

const DOMAIN = 0x0004;
const TAG = 'AuthSideEffect';
// Telegram service notifications (login codes, security alerts) live in the
// chat with user 777000. Once it goes idle it drops out of the top-N loadChats
// window, TDLib stops pushing its updateNewMessage, and login codes never reach
// the store — so a re-login on another device shows an empty code screen.
const TELEGRAM_SERVICE_CHAT_ID: number = 777000;

type AuthorizationState =
  | 'authorizationStateClosed'
  | 'authorizationStateClosing'
  | 'authorizationStateLoggingOut'
  | 'authorizationStateReady'
  | 'authorizationStateWaitCode'
  | 'authorizationStateWaitEncryptionKey'
  | 'authorizationStateWaitPassword'
  | 'authorizationStateWaitPhoneNumber'
  | 'authorizationStateWaitTdlibParameters';

// Store reference — устанавливается из AppCoreRuntime перед start()
let storeRef: AppStore | null = null;

export function setAuthSideEffectStore(store: AppStore): void {
  storeRef = store;
}

class AuthSideEffect {
  private gateway: TdGateway;
  private unsubscribe: (() => void) | undefined;
  private isRunning: boolean = false;
  private tdlibParamsInFlight: boolean = false;
  private tdlibParamsAccepted: boolean = false;
  private didHandleReady: boolean = false;
  private lifecycleToken: number = 0;

  constructor() {
    this.gateway = getTdGateway();
  }

  start(): void {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'AuthSideEffect already running');
      return;
    }

    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }

    this.isRunning = true;
    this.lifecycleToken++;
    this.tdlibParamsInFlight = false;
    this.tdlibParamsAccepted = false;
    this.didHandleReady = false;
    const token: number = this.lifecycleToken;
    let activeUnsubscribe: (() => void) | undefined = undefined;
    activeUnsubscribe = this.gateway.subscribeUpdates((update: TdObject): void => {
      if (!this.isCurrentSubscription(token, activeUnsubscribe)) {
        return;
      }
      this.handleUpdate(update, token);
    });
    this.unsubscribe = activeUnsubscribe;

    hilog.info(DOMAIN, TAG, 'AuthSideEffect started');

    // Сразу отправляем setTdlibParameters как первый запрос.
    // TDLib не шлёт никаких обновлений до первого запроса — это его пробуждает.
    this.sendTdlibParameters(token);
  }

  stop(): void {
    if (!this.isRunning) {
      return;
    }

    this.isRunning = false;
    this.lifecycleToken++;
    const activeUnsubscribe = this.unsubscribe;
    this.unsubscribe = undefined;
    if (activeUnsubscribe) {
      activeUnsubscribe();
    }
    this.tdlibParamsInFlight = false;
    this.tdlibParamsAccepted = false;
    this.didHandleReady = false;

    hilog.info(DOMAIN, TAG, 'AuthSideEffect stopped');
  }

  private isCurrentRun(token: number): boolean {
    return this.isRunning && token === this.lifecycleToken;
  }

  private isCurrentSubscription(token: number, unsubscribe: (() => void) | undefined): boolean {
    return this.isCurrentRun(token) && this.unsubscribe === unsubscribe;
  }

  private handleUpdate(update: TdObject, token: number): void {
    if (!this.isCurrentRun(token)) {
      return;
    }

    const type: string = update.getType();

    if (type !== 'updateAuthorizationState') {
      return;
    }

    const authStateObj: TdObject = update.getObject('authorization_state');
    if (!authStateObj.hasType()) {
      hilog.warn(DOMAIN, TAG, 'Authorization state without @type');
      return;
    }

    const authState: string = authStateObj.getType();
    hilog.info(DOMAIN, TAG, 'Auth state: ' + authState);

    if (authState === 'authorizationStateWaitTdlibParameters') {
      this.sendTdlibParameters(token);
    } else if (authState === 'authorizationStateClosed') {
      // TDLib closed (after logOut or restart). Reset flags so next
      // authorizationStateWaitTdlibParameters is handled correctly.
      this.tdlibParamsAccepted = false;
      this.tdlibParamsInFlight = false;
      this.didHandleReady = false;
      hilog.info(DOMAIN, TAG, 'TDLib closed — params/ready flags reset for re-initialization');
    } else if (authState === 'authorizationStateReady') {
      if (!this.didHandleReady) {
        this.didHandleReady = true;
        this.onAuthReady(token);
      }
    }
  }

  private async onAuthReady(token: number): Promise<void> {
    if (!this.isCurrentRun(token)) {
      return;
    }
    await this.resolveCurrentUser(token);
    if (!this.isCurrentRun(token)) {
      return;
    }
    await this.warmChatsCache(token);
    if (!this.isCurrentRun(token)) {
      return;
    }
    await this.ensureServiceChatKnown(token);
    await this.declareSessionOnline(token);
  }

  // Telegram delivers volatile updates (typing chat actions, live user
  // statuses) only to sessions that set the TDLib 'online' option — without
  // it the server treats this session as background and skips them entirely.
  private async declareSessionOnline(token: number): Promise<void> {
    if (!this.isCurrentRun(token)) {
      return;
    }
    try {
      await getTdGatewayAdapter().send(createSetTdlibOnlineCommand(true));
      hilog.info(DOMAIN, TAG, 'TDLib option online=true acknowledged');
    } catch (error) {
      const err = error as AppError;
      hilog.warn(DOMAIN, TAG, 'declareSessionOnline failed: %{public}s', err.message);
    }
  }

  // Subscribe to the Telegram service chat so its messages (login codes) are
  // delivered as updateNewMessage even after it drops out of the loaded window.
  private async ensureServiceChatKnown(token: number): Promise<void> {
    if (!this.isCurrentRun(token)) {
      return;
    }
    try {
      const adapter = getTdGatewayAdapter();
      // getChat makes the chat known to this client; openChat subscribes to its
      // live message stream (TDLib only pushes updateNewMessage for open chats
      // or chats inside a loaded list position).
      await adapter.send(createGetChatCommand(TELEGRAM_SERVICE_CHAT_ID));
      if (!this.isCurrentRun(token)) {
        return;
      }
      await adapter.send(createOpenChatCommand(TELEGRAM_SERVICE_CHAT_ID));
      hilog.info(DOMAIN, TAG, 'Service chat %{public}d subscribed for login-code delivery',
        TELEGRAM_SERVICE_CHAT_ID);
    } catch (error) {
      const err = error as AppError;
      hilog.warn(DOMAIN, TAG, 'ensureServiceChatKnown failed: %{public}s', err.message);
    }
  }

  private async warmChatsCache(token: number): Promise<void> {
    if (!this.isCurrentRun(token)) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'Warming chats cache with a single loadChats request...');

    const store: AppStore | null = storeRef;
    if (!store) {
      hilog.warn(DOMAIN, TAG, 'Chats warmup skipped: storeRef is null');
      return;
    }

    try {
      const loadChatsUseCase = createLoadChatsUseCase(store, getTdGatewayAdapter());
      await loadChatsUseCase.warmup();
      if (!this.isCurrentRun(token)) {
        return;
      }
      hilog.info(DOMAIN, TAG, 'Chats cache warmup finished via LoadChatsUseCase');
    } catch (error) {
      if (!this.isCurrentRun(token)) {
        return;
      }
      const err = error as AppError;
      if (err.tdlibCode === 404) {
        hilog.info(DOMAIN, TAG, 'Chats cache warmup reached end of dialogs immediately');
        return;
      }
      hilog.error(DOMAIN, TAG, 'Chats cache warmup failed: code=%{public}d msg=%{public}s', err.tdlibCode, err.message);
    }
  }

  private async resolveCurrentUser(token: number): Promise<void> {
    if (!this.isCurrentRun(token)) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'Auth ready, resolving current user via getMe...');

    try {
      const response: TdObject = await this.gateway.send('getMe', new TdObject());
      if (!this.isCurrentRun(token)) {
        return;
      }
      const responseType: string = response.getType();

      if (responseType === 'user') {
        const userId: number = response.getTopLevelNumber('id');
        hilog.info(DOMAIN, TAG, 'getMe resolved: userId=' + userId);

        const store: AppStore | null = storeRef;
        if (!store) {
          hilog.error(DOMAIN, TAG, 'getMe: storeRef is null — call setAuthSideEffectStore() before start()');
          return;
        }
        if (!userId || userId <= 0) {
          hilog.error(DOMAIN, TAG, 'getMe: invalid userId=' + userId);
          return;
        }
        await store.dispatch(createMyUserResolvedEvent(userId));
        if (!this.isCurrentRun(token)) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'myUserResolved dispatched');
      } else if (responseType === 'error') {
        const code: number = response.getNumber('code');
        const message: string = response.getString('message');
        hilog.error(DOMAIN, TAG, 'getMe error: code=' + code + ' message=' + message);
      }
    } catch (error) {
      if (!this.isCurrentRun(token)) {
        return;
      }
      const err = error as AppError;
      hilog.error(DOMAIN, TAG, 'getMe failed: ' + err.message + ' | tdlib: ' + err.technicalMessage + ' | code: ' + err.tdlibCode);
    }
  }

  private async sendTdlibParameters(token: number): Promise<void> {
    if (!this.isCurrentRun(token)) {
      return;
    }
    if (this.tdlibParamsAccepted) {
      return;
    }
    if (this.tdlibParamsInFlight) {
      return;
    }

    if (TELEGRAM_API_ID <= 0 || TELEGRAM_API_HASH.length === 0) {
      hilog.error(
        DOMAIN,
        TAG,
        'Missing Telegram API credentials. Fill entry/src/main/ets/services/ConfigLocal.ets'
      );
      return;
    }

    const context: common.UIAbilityContext | null = getAppContext();
    if (!context) {
      hilog.error(DOMAIN, TAG, 'AppContext not initialized');
      return;
    }

    const databaseDir: string = context.databaseDir;
    const filesDir: string = context.filesDir;

    if (!databaseDir || !filesDir) {
      hilog.error(DOMAIN, TAG, 'Invalid paths: databaseDir=%{public}s filesDir=%{public}s', databaseDir, filesDir);
      return;
    }

    this.tdlibParamsInFlight = true;
    hilog.info(DOMAIN, TAG, 'Sending setTdlibParameters...');

    const params: TdObject = new TdObject();
    params.setBool('use_test_dc', USE_TEST_DC);
    params.setNumber('api_id', TELEGRAM_API_ID);
    params.setString('api_hash', TELEGRAM_API_HASH);
    params.setString('database_directory', databaseDir);
    params.setString('files_directory', filesDir);
    params.setBool('use_file_database', true);
    params.setBool('use_chat_info_database', true);
    params.setBool('use_message_database', true);
    params.setBool('enable_storage_optimizer', true);
    params.setBool('ignore_file_names', false);

    let systemLanguageCode: string = 'en';
    try {
      const locale = Intl.DateTimeFormat().resolvedOptions().locale;
      if (locale && locale.length >= 2) {
        systemLanguageCode = locale.substring(0, 2);
      }
    } catch (_error) {
      systemLanguageCode = 'en';
    }

    // ВАЖНО: TDLib требует эти параметры как обязательные!
    // Без них setTdlibParameters падает с ошибкой 400.
    params.setString('system_language_code', systemLanguageCode);

    // Реальные данные устройства вместо хардкода
    const brand: string = deviceInfo.brand || 'HUAWEI';
    const marketName: string = deviceInfo.marketName || 'Unknown';
    const osFullName: string = deviceInfo.osFullName || 'HarmonyOS NEXT';
    const model: string = marketName.length > 0 ? `${brand} ${marketName}` : brand;

    params.setString('device_model', model);
    params.setString('system_version', osFullName);
    params.setString('application_version', '0.1.0');

    try {
      const response: TdObject = await this.gateway.send('setTdlibParameters', params);
      if (!this.isCurrentRun(token)) {
        return;
      }
      const responseType: string = response.getType();

      if (responseType === 'ok') {
        this.tdlibParamsAccepted = true;
        hilog.info(DOMAIN, TAG, 'setTdlibParameters accepted');
      } else if (responseType === 'error') {
        const code: number = response.getNumber('code');
        const message: string = response.getString('message');
        if (code === 400 && message.toLowerCase().indexOf('unexpected settdlibparameters') >= 0) {
          this.tdlibParamsAccepted = true;
          hilog.info(DOMAIN, TAG, 'Duplicate setTdlibParameters ignored (already accepted by TDLib)');
        }
        hilog.error(DOMAIN, TAG, 'setTdlibParameters error: code=' + code + ' message=' + message);
      }
    } catch (error) {
      if (!this.isCurrentRun(token)) {
        return;
      }
      const err = error as AppError;
      if (err.tdlibCode === 400 && err.technicalMessage.toLowerCase().indexOf('unexpected settdlibparameters') >= 0) {
        this.tdlibParamsAccepted = true;
        hilog.info(DOMAIN, TAG, 'Duplicate setTdlibParameters ignored (already accepted by TDLib)');
      }
      hilog.error(DOMAIN, TAG, 'setTdlibParameters failed: ' + err.message + ' | tdlib: ' + err.technicalMessage + ' | code: ' + err.tdlibCode);
    } finally {
      if (this.isCurrentRun(token)) {
        this.tdlibParamsInFlight = false;
      }
    }
  }
}

let authSideEffectInstance: AuthSideEffect | null = null;

export function getAuthSideEffect(): AuthSideEffect {
  if (!authSideEffectInstance) {
    authSideEffectInstance = new AuthSideEffect();
  }
  return authSideEffectInstance;
}

export function startAuthSideEffect(): void {
  const instance: AuthSideEffect = getAuthSideEffect();
  instance.start();
}

export function stopAuthSideEffect(): void {
  if (authSideEffectInstance) {
    authSideEffectInstance.stop();
  }
}
