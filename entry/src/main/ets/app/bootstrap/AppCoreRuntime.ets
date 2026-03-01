// AppCoreRuntime - orchestrates the complete event pipeline
// Gateway → MainThreadDispatcher → Normalizer → Store
//
// THREADING MODEL (аналог iOS Telegram):
//   1. TDLib native thread → raw JSON
//   2. MainThreadDispatcher → доставка в обработчики ArkTS
//   3. EventNormalizer → typed AppEvent[]
//   4. AppStore.dispatch() → reducers → new state
//   5. UI subscribers (main thread) → re-render
//
// Гарантия: шаги 3-5 ВСЕГДА выполняются на main thread.

import { TdGateway, getTdGateway, TdGatewayImpl } from '../../infra/td/gateway/TdGateway';
import { getMainThreadDispatcher } from '../../infra/threading/MainThreadDispatcher';
import { EventNormalizer, getEventNormalizer, NormalizerStats } from '../../core/events/EventNormalizer';
import { AppStore } from '../../core/store/AppStore';
import { appReducer } from '../../core/reducers/index';
import { AnyAppEvent } from '../../core/model/AppEvent';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject, tdGetProperty, safeString } from '../../models/TdTypes';
import { initAppStoreBridge, resetAppStoreBridge } from '../bridge/AppStoreBridge';
import { setAuthSideEffectStore, startAuthSideEffect, stopAuthSideEffect } from '../../core/sideeffects/AuthSideEffect';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'AppCoreRuntime';

export class PipelineStats {
  isRunning: boolean = false;
  gatewayReady: boolean = false;
  normalizerStats: NormalizerStats = new NormalizerStats();
  dispatcherDispatched: number = 0;
}

export class AppCoreRuntime {
  private gateway: TdGateway;
  private normalizer: EventNormalizer;
  private store: AppStore;

  private isRunning: boolean = false;
  private unsubscribeGateway?: () => void;
  private pendingDispatch: Promise<void> = Promise.resolve();

  constructor() {
    this.gateway = getTdGateway();
    this.normalizer = getEventNormalizer();
    this.store = new AppStore(appReducer);
  }

  async initialize(): Promise<void> {
    if (this.isRunning) {
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Initializing pipeline...');

      // 1. Подключаем MainThreadDispatcher для обновлений.
      //    subscribeUpdates вызывается ДО gateway.initialize(),
      //    чтобы не пропустить первые обновления.
      const dispatcher = getMainThreadDispatcher();
      dispatcher.subscribeUpdates((rawJson: string) => {
        // Это выполняется на MAIN THREAD — безопасно для Normalizer + Store
        const gatewayImpl = TdGatewayImpl.getInstance();
        gatewayImpl.handleUpdateOnMainThread(rawJson);
      });

      // 2. Подписываемся на parsed обновления из Gateway (уже на main thread)
      this.setupPipeline();

      // 3. Инициализируем Gateway (запустит receive loop)
      await this.gateway.initialize();
      hilog.info(DOMAIN, TAG, 'Gateway initialized');

      // 4. AppStoreBridge: Store → AppStorage (UI reads via @StorageLink)
      initAppStoreBridge(this.store);
      hilog.info(DOMAIN, TAG, 'AppStoreBridge initialized');

      // 5. AuthSideEffect: auto-send TDLib params + resolve user
      setAuthSideEffectStore(this.store);
      startAuthSideEffect();
      hilog.info(DOMAIN, TAG, 'AuthSideEffect started');

      this.isRunning = true;
      hilog.info(DOMAIN, TAG, 'Pipeline ready. Threading: TDLib→Dispatcher→Normalizer→Store');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to initialize: %{public}s', err.message);
      throw new AppError(
        AppErrorKind.UNKNOWN,
        'Failed to initialize AppCore pipeline',
        err.message,
        0,
        false
      );
    }
  }

  private setupPipeline(): void {
    // Gateway.subscribeUpdates — хэндлер вызывается на main thread
    // (потому что Gateway.broadcastUpdate вызывается из handleUpdateOnMainThread)
    this.unsubscribeGateway = this.gateway.subscribeUpdates((rawUpdate: TdObject) => {
      this.handleUpdate(rawUpdate);
    });
    hilog.info(DOMAIN, TAG, 'Pipeline wiring established');
  }

  private async handleUpdate(rawUpdate: TdObject): Promise<void> {
    if (!this.isRunning) return;

    try {
      const events = this.normalizer.normalize(rawUpdate);
      if (events.length === 0) return;

      await this.dispatchEvents(events);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Error processing update: %{public}s', err.message);
    }
  }

  private async dispatchEvents(events: AnyAppEvent[]): Promise<void> {
    // Serial dispatch queue — события обрабатываются строго по порядку
    const currentDispatch = this.pendingDispatch.then(async () => {
      try {
        for (const event of events) {
          await this.store.dispatch(event);
        }
      } catch (error) {
        const err = error as Error;
        hilog.error(DOMAIN, TAG, 'Error dispatching: %{public}s', err.message);
      }
    });

    this.pendingDispatch = currentDispatch;
    await currentDispatch;
  }

  getStore(): AppStore {
    return this.store;
  }

  getGateway(): TdGateway {
    return this.gateway;
  }

  isPipelineRunning(): boolean {
    return this.isRunning;
  }

  getPipelineStats(): PipelineStats {
    const stats = new PipelineStats();
    stats.isRunning = this.isRunning;
    stats.gatewayReady = this.gateway.isReady();
    stats.normalizerStats = this.normalizer.getStats();
    const dispatcherStats = getMainThreadDispatcher().getStats();
    stats.dispatcherDispatched = dispatcherStats.dispatched;
    return stats;
  }

  async shutdown(): Promise<void> {
    if (!this.isRunning) return;

    hilog.info(DOMAIN, TAG, 'Shutting down pipeline...');

    stopAuthSideEffect();
    resetAppStoreBridge();

    if (this.unsubscribeGateway) {
      this.unsubscribeGateway();
      this.unsubscribeGateway = undefined;
    }

    await this.gateway.destroy();
    this.isRunning = false;

    hilog.info(DOMAIN, TAG, 'Pipeline shut down');
  }
}

// Singleton с thread-safe reset (Huawei рекомендация: избегать race conditions)
let runtimeInstance: AppCoreRuntime | null = null;
let isResetting: boolean = false;

export function getAppCoreRuntime(): AppCoreRuntime {
  if (isResetting) {
    throw new AppError(
      AppErrorKind.UNKNOWN,
      'AppCoreRuntime is being reset, cannot access',
      'Race condition prevented',
      0,
      true
    );
  }
  if (!runtimeInstance) {
    runtimeInstance = new AppCoreRuntime();
  }
  return runtimeInstance;
}

/**
 * Безопасный сброс singleton с ожиданием shutdown.
 * Huawei Best Practice: всегда await асинхронные операции перед обнулением ресурсов.
 */
export async function resetAppCoreRuntime(): Promise<void> {
  if (isResetting) {
    hilog.warn(DOMAIN, TAG, 'resetAppCoreRuntime already in progress, ignoring');
    return;
  }

  isResetting = true;
  try {
    if (runtimeInstance) {
      await runtimeInstance.shutdown();
    }
  } finally {
    runtimeInstance = null;
    isResetting = false;
  }
}
