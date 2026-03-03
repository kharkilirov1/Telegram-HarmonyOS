// AuthSideEffect — автоматическая инициализация TDLib параметров
// Подписывается на Gateway updates, при authorizationStateWaitTdlibParameters
// автоматически отправляет setTdlibParameters с api_id, api_hash, путями БД
//
// Референс: iOS Telegram — AuthStateController + Config

import { TdGateway, getTdGateway } from '../../infra/td/gateway/TdGateway';
import { TdObject } from '../../models/td/common';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppContext } from '../../core/utils/AppResource';
import { AppError } from '../model/AppError';
import { AppStore } from '../store/AppStore';
import { createMyUserResolvedEvent } from '../model/AppEvent';
import { common } from '@kit.AbilityKit';
import { TELEGRAM_API_HASH, TELEGRAM_API_ID } from '../../services/ConfigLocal';

const DOMAIN = 0x0004;
const TAG = 'AuthSideEffect';

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

  constructor() {
    this.gateway = getTdGateway();
  }

  start(): void {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'AuthSideEffect already running');
      return;
    }

    this.isRunning = true;
    this.tdlibParamsInFlight = false;
    this.tdlibParamsAccepted = false;
    this.didHandleReady = false;
    this.unsubscribe = this.gateway.subscribeUpdates((update: TdObject): void => {
      const type: string = update.getType();
      hilog.info(DOMAIN, TAG, 'Gateway update: ' + type);
      this.handleUpdate(update);
    });

    hilog.info(DOMAIN, TAG, 'AuthSideEffect started');

    // Сразу отправляем setTdlibParameters как первый запрос.
    // TDLib не шлёт никаких обновлений до первого запроса — это его пробуждает.
    this.sendTdlibParameters();
  }

  stop(): void {
    if (!this.isRunning) {
      return;
    }

    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }

    this.isRunning = false;
    hilog.info(DOMAIN, TAG, 'AuthSideEffect stopped');
  }

  private handleUpdate(update: TdObject): void {
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
      this.sendTdlibParameters();
    } else if (authState === 'authorizationStateReady') {
      if (!this.didHandleReady) {
        this.didHandleReady = true;
        this.onAuthReady();
      }
    }
  }

  private async onAuthReady(): Promise<void> {
    await this.resolveCurrentUser();
    this.loadInitialChats();
  }

  private async loadInitialChats(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Loading initial chats...');

    const BATCH_SIZE = 100;
    const MAX_BATCHES = 20; // safety limit: 100*20 = 2000 chats max

    for (let batch = 0; batch < MAX_BATCHES; batch++) {
      try {
        const params: TdObject = new TdObject();
        params.setString('_chat_list_json', '{"@type":"chatListMain"}');
        params.setNumber('limit', BATCH_SIZE);

        await this.gateway.send('loadChats', params);
        hilog.info(DOMAIN, TAG, 'loadChats batch %{public}d ok', batch + 1);
      } catch (error) {
        const err = error as AppError;
        if (err.tdlibCode === 404) {
          hilog.info(DOMAIN, TAG, 'All chats loaded after %{public}d batches', batch + 1);
        } else {
          hilog.error(DOMAIN, TAG, 'loadChats error: code=%{public}d msg=%{public}s', err.tdlibCode, err.message);
        }
        break;
      }
    }
  }

  private async resolveCurrentUser(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Auth ready, resolving current user via getMe...');

    try {
      const response: TdObject = await this.gateway.send('getMe', new TdObject());
      const responseType: string = response.getType();

      if (responseType === 'user') {
        const userId: number = response.getNumber('id');
        hilog.info(DOMAIN, TAG, 'getMe resolved: userId=' + userId);

        if (!storeRef) {
          hilog.error(DOMAIN, TAG, 'getMe: storeRef is null — call setAuthSideEffectStore() before start()');
          return;
        }
        if (!userId || userId <= 0) {
          hilog.error(DOMAIN, TAG, 'getMe: invalid userId=' + userId);
          return;
        }
        await storeRef.dispatch(createMyUserResolvedEvent(userId));
        hilog.info(DOMAIN, TAG, 'myUserResolved dispatched');
      } else if (responseType === 'error') {
        const code: number = response.getNumber('code');
        const message: string = response.getString('message');
        hilog.error(DOMAIN, TAG, 'getMe error: code=' + code + ' message=' + message);
      }
    } catch (error) {
      const err = error as AppError;
      hilog.error(DOMAIN, TAG, 'getMe failed: ' + err.message + ' | tdlib: ' + err.technicalMessage + ' | code: ' + err.tdlibCode);
    }
  }

  private async sendTdlibParameters(): Promise<void> {
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
    params.setString('device_model', 'HarmonyOS Device');
    params.setString('system_version', 'HarmonyOS 4.0'); // или Next
    params.setString('application_version', '1.0.0');

    try {
      const response: TdObject = await this.gateway.send('setTdlibParameters', params);
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
      const err = error as AppError;
      if (err.tdlibCode === 400 && err.technicalMessage.toLowerCase().indexOf('unexpected settdlibparameters') >= 0) {
        this.tdlibParamsAccepted = true;
        hilog.info(DOMAIN, TAG, 'Duplicate setTdlibParameters ignored (already accepted by TDLib)');
      }
      hilog.error(DOMAIN, TAG, 'setTdlibParameters failed: ' + err.message + ' | tdlib: ' + err.technicalMessage + ' | code: ' + err.tdlibCode);
    } finally {
      this.tdlibParamsInFlight = false;
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
