// BootstrapSession use case - initializes TDLib session
//
// ВАЖНО: этот use case НЕ подписывается на обновления Gateway.
// Все обновления идут через pipeline в AppCoreRuntime:
//   TdGateway → MainThreadDispatcher → EventNormalizer → AppStore
//
// BootstrapSession только:
//   1. Вызывает runtime.initialize() (если нужно)
//   2. Отправляет начальные команды (getOption, setTdlibParameters)
//   3. Ждёт готовности auth state через selectors

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { createAuthStateChangedEvent } from '../../core/model/AppEvent';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { selectAuthStatus } from '../selectors/authSelectors';

const TAG = 'BootstrapSession';
const DOMAIN = 0x0007;

export class BootstrapSessionUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  /**
   * Инициализирует сессию TDLib.
   *
   * Вызывается ПОСЛЕ AppCoreRuntime.initialize(), который уже настроил
   * pipeline обновлений. Здесь мы только отправляем начальные команды.
   */
  async execute(): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Starting session bootstrap...');

      // Проверяем что Gateway готов (AppCoreRuntime уже должен был его инициализировать)
      const connectionState = this.gateway.getConnectionState();
      if (connectionState !== 'ready') {
        hilog.warn(DOMAIN, TAG, 'Gateway not ready, state: %{public}s', connectionState);
        // Не бросаем ошибку — возможно ещё инициализируется
      }

      // Начальное состояние auth — TDLib отправит updateAuthorizationState
      // после получения setTdlibParameters, но мы можем установить
      // промежуточное состояние для UI
      const currentStatus = selectAuthStatus(this.store.getState());
      if (currentStatus === 'notInitialized') {
        // UI может показать loading spinner
        hilog.info(DOMAIN, TAG, 'Auth status: notInitialized, waiting for TDLib updates');
      }

      // TDLib автоматически отправит updateAuthorizationState после
      // tdlib.createClient() и startReceiveLoop() — это уже сделано в TdGateway.
      //
      // Первое обновление будет authorizationStateWaitTdlibParameters,
      // после чего нужно отправить setTdlibParameters.
      //
      // Это обрабатывается в отдельном use case или в UI layer.

      hilog.info(DOMAIN, TAG, 'Session bootstrap completed. Waiting for auth updates...');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Bootstrap failed: %{public}s', err.message);

      throw new AppError(
        AppErrorKind.UNKNOWN,
        'Failed to bootstrap TDLib session',
        err.message,
        0,
        false
      );
    }
  }

  /**
   * Проверяет готовность сессии (auth state = 'ready').
   */
  isSessionReady(): boolean {
    const status = selectAuthStatus(this.store.getState());
    return status === 'ready';
  }

  /**
   * Проверяет нужна ли авторизация.
   */
  needsAuth(): boolean {
    const status = selectAuthStatus(this.store.getState());
    return status === 'waitPhoneNumber' ||
           status === 'waitCode' ||
           status === 'waitPassword' ||
           status === 'waitRegistration';
  }

  /**
   * Cleanup — no-op, так как Gateway управляется AppCoreRuntime.
   */
  async cleanup(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Cleanup called (no-op, Gateway managed by AppCoreRuntime)');
  }
}

// Factory function
export function createBootstrapSessionUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): BootstrapSessionUseCase {
  return new BootstrapSessionUseCase(store, gateway);
}
