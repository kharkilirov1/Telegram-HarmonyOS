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
import { getTdGatewayAdapter, resetTdGatewayAdapter } from '../../infra/td/adapter/TdGatewayAdapter';
import { getMainThreadDispatcher } from '../../infra/threading/MainThreadDispatcher';
import { EventNormalizer, getEventNormalizer, NormalizerStats } from '../../core/events/EventNormalizer';
import { AppStore } from '../../core/store/AppStore';
import { appReducer } from '../../core/reducers/index';
import { AnyAppEvent, createChatUpdatedEvent } from '../../core/model/AppEvent';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject, tdGetProperty, safeString } from '../../models/TdTypes';
import { initAppStoreBridge, resetAppStoreBridge } from '../bridge/AppStoreBridge';
import { setAuthSideEffectStore, startAuthSideEffect, stopAuthSideEffect } from '../../core/sideeffects/AuthSideEffect';
import { LoadChatHistoryUseCase, createLoadChatHistoryUseCase } from '../../domain/usecases/loadChatHistory';
import { resetLoadChatsUseCase } from '../../domain/usecases/loadChats';
import { createDownloadAvatarsUseCase, resetDownloadAvatarsUseCase } from '../../domain/usecases/downloadAvatars';
import { createDownloadMessageMediaUseCase, resetDownloadMessageMediaUseCase } from '../../domain/usecases/downloadMessageMedia';
import { ChatUpdateDto, extractLastMessage } from '../../core/model/dto/ChatDto';
import { tdGetNumber, tdGetObject, tdGetString } from '../../core/utils/tdAccessors';
import { resetMessageCacheManager } from '../../core/utils/MessageLruCache';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'AppCoreRuntime';

export class PipelineStats {
  isRunning: boolean = false;
  gatewayReady: boolean = false;
  normalizerStats: NormalizerStats = new NormalizerStats();
  dispatcherDispatched: number = 0;
  dispatcherDropped: number = 0;
  dispatcherHandlerErrors: number = 0;
}

export class AppCoreRuntime {
  private gateway: TdGateway;
  private normalizer: EventNormalizer;
  private store: AppStore;
  private liveHistoryHydrator: LoadChatHistoryUseCase;

  private isRunning: boolean = false;
  private lifecycleToken: number = 0;
  private unsubscribeGateway?: () => void;

  constructor() {
    this.gateway = getTdGateway();
    this.normalizer = getEventNormalizer();
    this.store = new AppStore(appReducer);
    this.liveHistoryHydrator = createLoadChatHistoryUseCase(this.store, getTdGatewayAdapter());
  }

  private refreshGatewayReferences(): void {
    this.gateway = getTdGateway();
    this.liveHistoryHydrator = createLoadChatHistoryUseCase(this.store, getTdGatewayAdapter());
  }

  async initialize(): Promise<void> {
    if (this.isRunning) {
      return;
    }

    this.lifecycleToken++;
    const runtimeToken: number = this.lifecycleToken;

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
      this.setupPipeline(runtimeToken);

      // 3. Устанавливаем isRunning ДО gateway.initialize() —
      //    иначе ранние updates от receive loop дропаются в handleUpdate()
      this.isRunning = true;

      // 4. Инициализируем Gateway (запустит receive loop)
      await this.gateway.initialize();
      if (!this.isCurrentRun(runtimeToken)) {
        hilog.info(DOMAIN, TAG, 'Gateway initialize continuation ignored after runtime reset');
        return;
      }
      hilog.info(DOMAIN, TAG, 'Gateway initialized');

      // 5. AppStoreBridge: Store → AppStorage (UI reads via @StorageLink)
      initAppStoreBridge(this.store);
      hilog.info(DOMAIN, TAG, 'AppStoreBridge initialized');

      // 6. AuthSideEffect: auto-send TDLib params + resolve user
      setAuthSideEffectStore(this.store);
      startAuthSideEffect();
      hilog.info(DOMAIN, TAG, 'AuthSideEffect started');

      // 7. Avatar download watcher
      const avatarUseCase = createDownloadAvatarsUseCase(this.store, getTdGatewayAdapter());
      avatarUseCase.start();
      hilog.info(DOMAIN, TAG, 'DownloadAvatars watcher started');

      // 8. Message media download watcher
      const mediaUseCase = createDownloadMessageMediaUseCase(this.store, getTdGatewayAdapter());
      mediaUseCase.start();
      hilog.info(DOMAIN, TAG, 'DownloadMessageMedia watcher started');

      hilog.info(DOMAIN, TAG, 'Pipeline ready. Threading: TDLib→Dispatcher→Normalizer→Store');
    } catch (error) {
      if (!this.isCurrentInitializeRun(runtimeToken)) {
        hilog.info(DOMAIN, TAG, 'Initialize failure ignored after runtime reset: %{public}s', String(error));
        return;
      }
      this.isRunning = false;
      this.lifecycleToken++;
      stopAuthSideEffect();
      resetAppStoreBridge();
      resetDownloadAvatarsUseCase();
      resetDownloadMessageMediaUseCase();
      resetMessageCacheManager();
      LoadChatHistoryUseCase.resetState();
      resetLoadChatsUseCase();
      if (this.unsubscribeGateway) {
        this.unsubscribeGateway();
        this.unsubscribeGateway = undefined;
      }
      try {
        await this.gateway.destroy();
      } catch (cleanupError) {
        hilog.warn(DOMAIN, TAG, 'Gateway cleanup after initialize failure failed: %{public}s',
          String(cleanupError));
      } finally {
        resetTdGatewayAdapter();
        getMainThreadDispatcher().unsubscribe();
        this.refreshGatewayReferences();
      }
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

  private isCurrentRun(token: number): boolean {
    return this.isRunning && token === this.lifecycleToken;
  }

  private isCurrentInitializeRun(token: number): boolean {
    return token === this.lifecycleToken;
  }

  private setupPipeline(runtimeToken: number): void {
    // Gateway.subscribeUpdates — хэндлер вызывается на main thread
    // (потому что Gateway.broadcastUpdate вызывается из handleUpdateOnMainThread)
    this.unsubscribeGateway = this.gateway.subscribeUpdates((rawUpdate: TdObject) => {
      if (!this.isCurrentRun(runtimeToken)) {
        return;
      }
      this.handleUpdate(rawUpdate, runtimeToken);
    });
    hilog.info(DOMAIN, TAG, 'Pipeline wiring established');
  }

  private async handleUpdate(rawUpdate: TdObject, runtimeToken: number): Promise<void> {
    if (!this.isCurrentRun(runtimeToken)) return;

    try {
      await this.hydrateMissingUsersForLiveMessage(rawUpdate);
      if (!this.isCurrentRun(runtimeToken)) return;
      const events = this.normalizer.normalize(rawUpdate);
      if (events.length === 0) return;

      this.appendSyntheticChatUpdateForLiveMessage(rawUpdate, events);
      if (!this.isCurrentRun(runtimeToken)) return;
      await this.dispatchEvents(events, runtimeToken);
    } catch (error) {
      if (!this.isCurrentRun(runtimeToken)) return;
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Error processing update: %{public}s', err.message);
    }
  }

  private async hydrateMissingUsersForLiveMessage(rawUpdate: TdObject): Promise<void> {
    const updateType = rawUpdate.getType();
    if (updateType !== 'updateNewMessage' && updateType !== 'updateMessageSendSucceeded') {
      return;
    }

    const message = tdGetObject(rawUpdate, 'message');
    const sender = tdGetObject(message, 'sender_id');
    if (tdGetString(sender, '@type') !== 'messageSenderUser') {
      return;
    }

    const senderId = tdGetNumber(sender, 'user_id');
    if (senderId <= 0) {
      return;
    }

    await this.liveHistoryHydrator.hydrateUsersIfMissing([senderId]);
  }

  private appendSyntheticChatUpdateForLiveMessage(rawUpdate: TdObject, events: AnyAppEvent[]): void {
    const updateType = rawUpdate.getType();
    if (updateType !== 'updateNewMessage' && updateType !== 'updateMessageSendSucceeded') {
      return;
    }

    const message = tdGetObject(rawUpdate, 'message');
    const chatId = tdGetNumber(message, 'chat_id');
    if (!chatId) {
      return;
    }

    const updates = new ChatUpdateDto();
    updates.lastMessage = extractLastMessage(message);
    events.push(createChatUpdatedEvent(chatId, updates));
  }

  private async dispatchEvents(events: AnyAppEvent[], runtimeToken: number): Promise<void> {
    if (!this.isCurrentRun(runtimeToken)) return;
    try {
      await this.store.dispatchBatch(events);
    } catch (error) {
      if (!this.isCurrentRun(runtimeToken)) return;
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Error dispatching batch: %{public}s', err.message);
    }
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
    stats.dispatcherDropped = dispatcherStats.dropped;
    stats.dispatcherHandlerErrors = dispatcherStats.handlerErrors;
    return stats;
  }

  async shutdown(): Promise<void> {
    if (!this.isRunning) return;

    hilog.info(DOMAIN, TAG, 'Shutting down pipeline...');
    this.isRunning = false;
    this.lifecycleToken++;

    stopAuthSideEffect();
    resetAppStoreBridge();
    resetDownloadAvatarsUseCase();
    resetDownloadMessageMediaUseCase();
    resetMessageCacheManager();

    // Clear static use-case caches — prevents stale "already fetched" flags
    // when a new runtime + store is created after reset
    LoadChatHistoryUseCase.resetState();
    resetLoadChatsUseCase();

    if (this.unsubscribeGateway) {
      this.unsubscribeGateway();
      this.unsubscribeGateway = undefined;
    }

    // Detach dispatcher handlers after gateway shutdown so close-response/closed-state
    // updates can still reach TdGateway while destroy() is waiting for them.
    // Keep this in finally so a failed destroy cannot leave raw handlers attached.
    try {
      await this.gateway.destroy();
    } finally {
      resetTdGatewayAdapter();
      getMainThreadDispatcher().unsubscribe();
      this.refreshGatewayReferences();
    }
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
