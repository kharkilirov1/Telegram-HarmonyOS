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

import { TdGateway, getTdGateway, TdGatewayImpl, ClientRecoveryHooks } from '../../infra/td/gateway/TdGateway';
import { getTdGatewayAdapter, resetTdGatewayAdapter } from '../../infra/td/adapter/TdGatewayAdapter';
import { getMainThreadDispatcher } from '../../infra/threading/MainThreadDispatcher';
import { EventNormalizer, getEventNormalizer, NormalizerStats } from '../../core/events/EventNormalizer';
import { AppStore } from '../../core/store/AppStore';
import { appReducer } from '../../core/reducers/index';
import { AnyAppEvent, createChatUpdatedEvent, createAuthStateChangedEvent } from '../../core/model/AppEvent';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject, tdGetProperty, safeString } from '../../models/TdTypes';
import { initAppStoreBridge, resetAppStoreBridge, resetAccountNavigationContext } from '../bridge/AppStoreBridge';
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
  private accountStore: AppStore;
  private accountToken: number = 0;
  private liveHistoryHydrator: LoadChatHistoryUseCase;

  private isRunning: boolean = false;
  private lifecycleToken: number = 0;
  private initializationTask?: Promise<void>;
  private shutdownTask?: Promise<void>;
  private unsubscribeGateway?: () => void;

  constructor() {
    this.gateway = getTdGateway();
    this.normalizer = getEventNormalizer();
    this.store = new AppStore(appReducer);
    this.accountStore = this.store.createScope();
    this.liveHistoryHydrator = createLoadChatHistoryUseCase(this.accountStore, getTdGatewayAdapter());
  }

  private refreshGatewayReferences(): void {
    this.gateway = getTdGateway();
    this.liveHistoryHydrator = createLoadChatHistoryUseCase(this.accountStore, getTdGatewayAdapter());
  }

  initialize(): Promise<void> {
    // Never start a new generation while the previous destroy/cleanup owns the dispatcher.
    if (this.shutdownTask) return this.shutdownTask.then((): Promise<void> => this.initialize());
    if (this.initializationTask) return this.initializationTask;
    if (this.isRunning) return Promise.resolve();
    // A rejected shutdown can still own a client/receiver. Only an explicit
    // shutdown retry (or late Closed retirement) may finish that old owner.
    if (this.gateway.getState() === 'destroying') {
      return Promise.reject(new AppError(AppErrorKind.NETWORK,
        'TDLib client retirement is still pending. Retry shutdown.', '', 0, true));
    }
    this.lifecycleToken++;
    const runtimeToken: number = this.lifecycleToken;
    // Assign the task before executing callbacks that can re-enter lifecycle methods.
    const task = Promise.resolve().then((): Promise<void> => this.initializePipeline(runtimeToken));
    this.initializationTask = task;
    const clearTask = (): void => {
      if (this.initializationTask === task) this.initializationTask = undefined;
    };
    task.then(clearTask, clearTask);
    return task;
  }

  private async initializePipeline(runtimeToken: number): Promise<void> {
    if (!this.isCurrentInitializeRun(runtimeToken)) return;
    try {
      // Reusing a stopped/failed runtime must not grant a new client access to account A.
      if (runtimeToken > 1) {
        const reset = this.store.resetStateQueued();
        resetAccountNavigationContext();
        await reset;
        if (!this.isCurrentInitializeRun(runtimeToken)) return;
      }
      this.accountStore = this.store.createScope();
      this.refreshGatewayReferences();
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
      const recoveryHooks: ClientRecoveryHooks = {
        beforeRestart: (): Promise<void> => this.prepareClientRestart(runtimeToken),
        afterRestart: (): void => this.completeClientRestart(runtimeToken),
        onFailure: (error: AppError): void => this.handleClientRestartFailure(error, runtimeToken)
      };
      this.gateway.setClientRecoveryHooks(recoveryHooks);

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
      setAuthSideEffectStore(this.accountStore);
      startAuthSideEffect();
      hilog.info(DOMAIN, TAG, 'AuthSideEffect started');

      // 7. Avatar download watcher
      const avatarUseCase = createDownloadAvatarsUseCase(this.accountStore, getTdGatewayAdapter());
      avatarUseCase.start();
      hilog.info(DOMAIN, TAG, 'DownloadAvatars watcher started');

      // 8. Message media download watcher
      const mediaUseCase = createDownloadMessageMediaUseCase(this.accountStore, getTdGatewayAdapter());
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
      this.accountToken++;
      this.store.invalidateScopes();
      this.gateway.setClientRecoveryHooks(undefined);
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

  private isCurrentAccountRun(runtimeToken: number, accountToken: number): boolean {
    return this.isCurrentRun(runtimeToken) && accountToken === this.accountToken;
  }

  private async prepareClientRestart(runtimeToken: number): Promise<void> {
    if (!this.isCurrentRun(runtimeToken)) {
      throw new AppError(AppErrorKind.NETWORK, 'Runtime stopped before client recovery');
    }
    // This prefix must stay synchronous: rejected old requests resume in microtasks.
    this.accountToken++;
    const accountToken = this.accountToken;
    stopAuthSideEffect();
    resetDownloadAvatarsUseCase();
    resetDownloadMessageMediaUseCase();
    resetMessageCacheManager();
    LoadChatHistoryUseCase.resetState();
    resetLoadChatsUseCase();
    resetTdGatewayAdapter();
    const reset = this.store.resetStateQueued();
    resetAccountNavigationContext();
    await reset;
    if (!this.isCurrentAccountRun(runtimeToken, accountToken)) {
      throw new AppError(AppErrorKind.NETWORK, 'Client recovery superseded');
    }
    this.accountStore = this.store.createScope();
    await this.accountStore.dispatch(createAuthStateChangedEvent('closed'));
  }

  private completeClientRestart(runtimeToken: number): void {
    if (!this.isCurrentRun(runtimeToken)) return;
    this.refreshGatewayReferences();
    setAuthSideEffectStore(this.accountStore);
    startAuthSideEffect();
    createDownloadAvatarsUseCase(this.accountStore, getTdGatewayAdapter()).start();
    createDownloadMessageMediaUseCase(this.accountStore, getTdGatewayAdapter()).start();
  }

  private handleClientRestartFailure(error: AppError, runtimeToken: number): void {
    if (!this.isCurrentRun(runtimeToken)) return;
    hilog.error(DOMAIN, TAG, 'TDLib recovery failed: %{public}s', error.message);
    // Failure is also an account boundary: revoke pending work now, not on a later retry.
    const reset = this.prepareClientRestart(runtimeToken);
    const accountToken = this.accountToken;
    reset.catch((resetError: Error): void => {
      hilog.error(DOMAIN, TAG, 'Recovery failure cleanup failed: %{public}s', String(resetError));
    }).then((): void => {
      if (!this.isCurrentAccountRun(runtimeToken, accountToken)) return;
      const event = createAuthStateChangedEvent('closed');
      // Keep technical/native details out of login UI and account state.
      event.error = 'TDLib client recovery failed';
      this.store.dispatch(event, (): boolean => this.isCurrentAccountRun(runtimeToken, accountToken));
    });
  }

  async retryClientRecovery(): Promise<void> {
    if (!this.isRunning) {
      throw new AppError(AppErrorKind.NETWORK, 'Runtime is not running');
    }
    await this.gateway.retryClosedClient();
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
    const accountToken = this.accountToken;
    const accountStore = this.accountStore;

    try {
      // Enqueue every raw update synchronously in TDLib receive order. Even a
      // cached-user hydration await lets a following edit overtake its message.
      const events = this.normalizer.normalize(rawUpdate);
      if (events.length === 0) return;

      this.appendSyntheticChatUpdateForLiveMessage(rawUpdate, events);
      if (!this.isCurrentRun(runtimeToken)) return;
      await this.dispatchEvents(events, runtimeToken, accountStore);
      if (!this.isCurrentAccountRun(runtimeToken, accountToken)) return;
      // Sender hydration is enrichment, not a prerequisite for message delivery.
      // The use case deduplicates requests and rejects stale lifecycle generations.
      await this.hydrateMissingUsersForLiveMessage(rawUpdate);
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

  private async dispatchEvents(events: AnyAppEvent[], runtimeToken: number, accountStore: AppStore): Promise<void> {
    if (!this.isCurrentRun(runtimeToken)) return;
    try {
      await accountStore.dispatchBatch(events, (): boolean => this.isCurrentRun(runtimeToken));
    } catch (error) {
      if (!this.isCurrentRun(runtimeToken)) return;
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Error dispatching batch: %{public}s', err.message);
    }
  }

  getStore(): AppStore {
    return this.accountStore;
  }

  // Only lifecycle subscribers (bridge/login root) may span account generations.
  // Commands, use cases and account UI must use the scoped getStore() instead.
  getLifecycleStore(): AppStore {
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

  shutdown(): Promise<void> {
    if (this.shutdownTask) return this.shutdownTask;
    if (!this.isRunning && !this.initializationTask && this.gateway.getState() === 'idle') {
      return Promise.resolve();
    }
    // Scope invalidation invokes observers synchronously; publish before reentry.
    let resolveTask: () => void = (): void => {};
    let rejectTask: (error: Error) => void = (_error: Error): void => {};
    const task = new Promise<void>((resolve, reject) => {
      resolveTask = resolve;
      rejectTask = reject;
    });
    this.shutdownTask = task;
    this.shutdownPipeline(this.initializationTask).then((): void => {
      if (this.shutdownTask === task) this.shutdownTask = undefined;
      resolveTask();
    }, (error: Error): void => {
      if (this.shutdownTask === task) this.shutdownTask = undefined;
      rejectTask(error);
    });
    return task;
  }

  private async shutdownPipeline(initializationTask?: Promise<void>): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Shutting down pipeline...');
    this.isRunning = false;
    this.lifecycleToken++;
    this.accountToken++;
    this.store.invalidateScopes();
    this.gateway.setClientRecoveryHooks(undefined);

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
      if (initializationTask) {
        // A cancelled initialize must finish (including its failure cleanup) before destroy.
        try { await initializationTask; } catch (_) { /* initialize reports its own failure */ }
      }
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
let resetTask: Promise<void> | undefined;

export function getAppCoreRuntime(): AppCoreRuntime {
  if (resetTask) {
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
export function resetAppCoreRuntime(): Promise<void> {
  if (resetTask) return resetTask;

  // Share completion/rejection, including reentry from synchronous invalidation.
  let resolveTask: () => void = (): void => {};
  let rejectTask: (error: Error) => void = (_error: Error): void => {};
  const task = new Promise<void>((resolve, reject) => {
    resolveTask = resolve;
    rejectTask = reject;
  });
  resetTask = task;
  const shutdown = runtimeInstance ? runtimeInstance.shutdown() : Promise.resolve();
  shutdown.then((): void => {
    runtimeInstance = null;
    resetTask = undefined;
    resolveTask();
  }, (error: Error): void => {
    // Preserve the stopped runtime as retirement owner until an explicit retry.
    resetTask = undefined;
    rejectTask(error);
  });
  return task;
}
