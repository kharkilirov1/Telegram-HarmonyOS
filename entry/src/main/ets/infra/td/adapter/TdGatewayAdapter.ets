// TdGatewayAdapter - адаптер между TdGatewayPort (domain) и TdGateway (infra)
//
// Реализует TdGatewayPort для use cases:
//   - Конвертирует AnyAppCommand → TdObject через CommandSerializer
//   - Вызывает TdGateway.send(method, params)
//   - Возвращает результат как Object
//
// Обновления TDLib обрабатываются через AppCoreRuntime pipeline:
//   TdGateway → MainThreadDispatcher → EventNormalizer → AppStore
// Поэтому subscribeUpdates здесь не используется — use cases не подписываются напрямую.

import { TdGatewayPort, GatewayError, GatewayErrorCode } from '../../../domain/ports/TdGatewayPort';
import { TdGateway, getTdGateway } from '../gateway/TdGateway';
import { AnyAppCommand } from '../../../core/model/AppCommand';
import { AnyAppEvent } from '../../../core/model/AppEvent';
import { serializeCommand } from '../serialization/CommandSerializer';
import { TdObject } from '../../../models/TdTypes';
import { AppError, isSilentTdlibError, normalizeAppError } from '../../../core/model/AppError';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'TdGatewayAdapter';
const DOMAIN = 0x0002;

export class TdGatewayAdapter implements TdGatewayPort {
  private gateway: TdGateway;
  private clientGeneration: number;

  constructor() {
    this.gateway = getTdGateway();
    this.clientGeneration = this.gateway.getClientGeneration();
  }

  isCurrentClient(): boolean {
    return this.gateway === getTdGateway() &&
      this.clientGeneration === this.gateway.getClientGeneration();
  }

  private expiredClientError(requestRejected: boolean = false): GatewayError {
    const error = new GatewayError(GatewayErrorCode.NOT_INITIALIZED, 'TDLib client session has ended');
    error.retryable = false;
    error.requestRejected = requestRejected;
    return error;
  }

  async initialize(): Promise<void> {
    // Gateway инициализируется через AppCoreRuntime
    // Здесь просто проверяем состояние
    if (!this.gateway.isReady()) {
      hilog.warn(DOMAIN, TAG, 'Gateway not ready during adapter init');
      // Не бросаем ошибку — может быть в процессе инициализации
    }
  }

  async send(command: AnyAppCommand): Promise<Object> {
    if (!this.isCurrentClient()) {
      throw this.expiredClientError(true);
    }
    if (!this.gateway.isReady()) {
      throw new GatewayError(
        GatewayErrorCode.NOT_INITIALIZED,
        'Gateway not initialized'
      );
    }

    // Сериализуем команду
    const serialized = serializeCommand(command);

    if (!serialized.method) {
      throw new GatewayError(
        GatewayErrorCode.INVALID_COMMAND,
        `Unknown command type: ${command.type}`
      );
    }

    hilog.info(DOMAIN, TAG, 'Sending command: %{public}s', serialized.method);

    try {
      // Отправляем через gateway
      const result = await this.gateway.send(serialized.method, serialized.params);
      if (!this.isCurrentClient()) {
        throw this.expiredClientError();
      }
      return result as Object;
    } catch (error) {
      if (!this.isCurrentClient()) {
        throw this.expiredClientError();
      }
      if (isSilentTdlibError(error)) throw error as AppError;
      const err: AppError = normalizeAppError(error);
      hilog.error(DOMAIN, TAG, 'Command %{public}s failed: kind=%{public}s code=%{public}d',
        serialized.method, err.kind, err.tdlibCode);
      if (error instanceof AppError) {
        throw error;
      }
      throw new GatewayError(
        GatewayErrorCode.CONNECTION_FAILED,
        err.userMessage,
        serialized.method
      );
    }
  }

  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void {
    // ВАЖНО: Use cases НЕ должны подписываться на обновления напрямую.
    // Все обновления идут через pipeline в AppCoreRuntime:
    //   TdGateway → MainThreadDispatcher → EventNormalizer → AppStore
    //
    // Use cases читают состояние из Store через selectors.
    // Если use case хочет реагировать на изменения — он подписывается на Store.

    hilog.warn(DOMAIN, TAG,
      'subscribeUpdates called but updates go through AppCoreRuntime pipeline');

    // Возвращаем no-op unsubscribe
    return (): void => {};
  }

  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' {
    if (!this.isCurrentClient()) return 'connecting';
    const gatewayState = this.gateway.getState();

    switch (gatewayState) {
      case 'ready':
        return 'ready';
      case 'initializing':
        return 'connecting';
      case 'destroying':
      case 'idle':
      default:
        return 'connecting';
    }
  }

  isDrainCongested = (): boolean => {
    return this.gateway.isDrainCongested();
  };

  async destroy(): Promise<void> {
    // Gateway уничтожается через AppCoreRuntime.shutdown()
    hilog.info(DOMAIN, TAG, 'Adapter destroy called (no-op, use AppCoreRuntime.shutdown)');
  }
}

// Singleton
let adapterInstance: TdGatewayAdapter | null = null;

export function getTdGatewayAdapter(): TdGatewayPort {
  if (!adapterInstance || !adapterInstance.isCurrentClient()) {
    adapterInstance = new TdGatewayAdapter();
  }
  return adapterInstance;
}

export function resetTdGatewayAdapter(): void {
  adapterInstance = null;
}
