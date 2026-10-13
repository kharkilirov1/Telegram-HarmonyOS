// infra/td/gateway/TdGateway.ets
//
// TDLib native bridge. Получает raw JSON из NAPI callback и
// маршрутизирует его в responses/updates через MainThreadDispatcher.
// Детали переключения потоков инкапсулированы в native (thread-safe function)
// и в dispatcher слое.
//
// Референс: iOS Telegram — MtProtoKit + SwiftSignalKit Queue.mainQueue()

import { AppError, AppErrorKind, classifyTdlibError } from '../../../core/model/AppError';
import { TdObject } from '../../../models/TdTypes';
import { getMainThreadDispatcher, MainThreadDispatcher } from '../../threading/MainThreadDispatcher';
import { hilog } from '@kit.PerformanceAnalysisKit';
import tdlib from 'libtdlib_napi.so';

const DOMAIN = 0x0002;
const TAG = 'TdGateway';
const DEFAULT_REQUEST_TIMEOUT_MS = 30000;

const METHOD_TIMEOUT_MAP: Record<string, number> = {
  'getChats': 15000,
  'loadChats': 15000,
  'getChatHistory': 15000,
  'searchCallMessages': 15000,
  'getChat': 15000,
  'sendMessage': 30000,
  'downloadFile': 120000,
  'close': 10000,
};

export function getMethodTimeout(method: string): number {
  return METHOD_TIMEOUT_MAP[method] ?? DEFAULT_REQUEST_TIMEOUT_MS;
}

class Logger {
  static info(msg: string) {
    hilog.info(DOMAIN, TAG, '%{public}s', msg);
  }
  static warn(msg: string) {
    hilog.warn(DOMAIN, TAG, '%{public}s', msg);
  }
  static error(msg: string, err?: string) {
    hilog.error(DOMAIN, TAG, '%{public}s %{public}s', msg, err ? err : '');
  }
}

type GatewayState = 'idle' | 'initializing' | 'ready' | 'closed' | 'recovering' | 'failed' | 'destroying';

interface QueuedTdBatch {
  json: string;
  generation: number;
}

export interface ClientRecoveryHooks {
  beforeRestart: () => Promise<void>;
  afterRestart: () => void;
  onFailure: (error: AppError) => void;
}

export interface GatewayStats {
  state: GatewayState;
  pendingRequests: number;
  timeouts: number;
}

export interface TdGateway {
  send(method: string, params?: TdObject): Promise<TdObject>;
  /**
   * Отправить запрос с автоматическим retry при transient ошибках.
   * Huawei Best Practice: retry с exponential backoff.
   */
  sendWithRetry(method: string, params?: TdObject, maxRetries?: number, baseDelayMs?: number): Promise<TdObject>;
  subscribeUpdates(handler: (update: TdObject) => void): () => void;
  initialize(): Promise<void>;
  setClientRecoveryHooks(hooks?: ClientRecoveryHooks): void;
  getClientGeneration(): number;
  retryClosedClient(): Promise<void>;
  destroy(): Promise<void>;
  getState(): GatewayState;
  getGatewayStats(): GatewayStats;
  isReady(): boolean;
  /** Backpressure: очередь update-батчей перегружена (шторм ресинка). */
  isDrainCongested(): boolean;
}

class PendingRequest {
  resolve: (value: TdObject) => void;
  reject: (error: AppError) => void;
  timeoutId: number;

  constructor(resolve: (value: TdObject) => void, reject: (error: AppError) => void, timeoutId: number) {
    this.resolve = resolve;
    this.reject = reject;
    this.timeoutId = timeoutId;
  }
}

export class TdGatewayImpl implements TdGateway {
  private static instance: TdGatewayImpl | null = null;

  private clientId: number = 0;
  private state: GatewayState = 'idle';
  // Adapters can be constructed before initial initialize: generation starts at 0.
  private clientGeneration: number = 0;
  private recoveryHooks?: ClientRecoveryHooks;
  private recoveryPromise?: Promise<void>;
  private shutdownPromise?: Promise<void>;
  private autoRecoveryUsed: boolean = false;
  private bootstrapConfirmedGeneration: number = -1;
  private receiveLoopStarted: boolean = false;
  private receiveLoopGeneration: number = 0;
  private destroyClosedObserved: boolean = false;
  private clientRetirementPending: boolean = false;
  private updateHandlers: Set<(update: TdObject) => void> = new Set();
  private pendingRequests: Map<string, PendingRequest> = new Map();
  private requestCounter: number = 0;
  private timeoutCount: number = 0;
  private pendingBatchQueue: QueuedTdBatch[] = [];
  private drainItems: Object[] = [];
  private drainItemsGeneration: number = -1;
  private drainIndex: number = 0;
  private drainScheduled: boolean = false;
  private drainTimerId: number = -1;
  private static readonly DRAIN_BUDGET_MS = 8;
  // Нулевые/малые фиксированные задержки ненадёжны: ohos loop handler прокачивает
  // дозревшие таймеры внутри одного uv_timer_task, и цепочка слайсов сливается в
  // непрерывную блокировку main thread (THREAD_BLOCK_6S). Следующий слайс
  // планируется с задержкой >= фактической длительности предыдущего (пейсинг):
  // дрейн занимает не более ~50% времени main thread при любом размере элементов.
  private static readonly DRAIN_YIELD_MS = 2;
  // Эскалация пауз при шторме (P4-d, freeze 2026-07-08): пейсинга elapsed×1 мало —
  // watcher/history/ArkUI-таймеры дозревают в паузе и продлевают ту же uv-фазу,
  // main thread остаётся CPU-bound 6+ секунд. Подряд идущие «горячие» слайсы
  // (упёрлись в бюджет) удлиняют паузу мультипликативно до жёсткого потолка,
  // гарантируя watchdog/vsync окна даже при непрерывном притоке батчей.
  private drainHotStreak: number = 0;
  private static readonly DRAIN_BACKOFF_CAP_MS = 250;

  private constructor() {}

  static getInstance(): TdGatewayImpl {
    if (!TdGatewayImpl.instance) {
      TdGatewayImpl.instance = new TdGatewayImpl();
    }
    return TdGatewayImpl.instance;
  }

  getState(): GatewayState {
    return this.state;
  }

  setClientRecoveryHooks(hooks?: ClientRecoveryHooks): void {
    this.recoveryHooks = hooks;
  }

  getClientGeneration(): number {
    return this.clientGeneration;
  }

  isReady(): boolean {
    return this.state === 'ready';
  }

  getGatewayStats(): GatewayStats {
    return {
      state: this.state,
      pendingRequests: this.pendingRequests.size,
      timeouts: this.timeoutCount
    };
  }

  async initialize(): Promise<void> {
    if (this.state === 'destroying') {
      throw this.clientInvalidatedError();
    }
    if (this.state === 'closed' || this.state === 'recovering' || this.state === 'failed') {
      await this.retryClosedClient();
      return;
    }
    if (this.state !== 'idle') {
      Logger.warn(`initialize() called in state: ${this.state}. Ignoring.`);
      return;
    }

    this.state = 'initializing';
    try {
      // Настраиваем MainThreadDispatcher ДО запуска receive loop.
      // dispatcher.subscribeResponses получает JSON ответы, где мы
      // безопасно resolve/reject pending requests.
      const dispatcher = getMainThreadDispatcher();
      const loopGeneration = ++this.receiveLoopGeneration;

      dispatcher.subscribeResponses((responseJson: string) => {
        if (loopGeneration !== this.receiveLoopGeneration) return;
        // Это выполняется в dispatcher-пайплайне ArkTS.
        this.handleResponseOnMainThread(responseJson);
      });

      // Запускаем нативный receive loop.
      // Мы НЕ смешиваем бизнес-логику с callback слоем:
      // только определяем тип payload и передаём в dispatcher.
      // NAPI receive loop отправляет батчи — JSON-массив: [obj1, obj2, ...]
      // Батчи ставятся в очередь и осушаются слайсами с бюджетом времени,
      // с yield через setTimeout(0) между слайсами (см. drainSlice) — иначе
      // холодный старт блокирует main thread (THREAD_BLOCK_6S).
      // Own even a partially started receiver before entering the native boundary.
      // Do not allocate a TDLib ID until its receive path is available.
      this.receiveLoopStarted = true;
      tdlib.startReceiveLoop((batchJson: string) => {
        if (loopGeneration !== this.receiveLoopGeneration) return;
        try {
          this.enqueueBatch(batchJson, dispatcher);
        } catch (error) {
          Logger.error('Error in receive loop relay', String(error));
        }
      });

      this.clientId = tdlib.createClient();
      if (!Number.isInteger(this.clientId) || this.clientId <= 0) {
        this.clientId = 0;
        throw new Error('Invalid native client ID');
      }
      Logger.info(`Created native client with ID: ${this.clientId}`);
      this.state = 'ready';
      Logger.info('Gateway initialized with MainThreadDispatcher bridge');
    } catch (error) {
      await this.cleanupAfterInitializeFailure();
      const err = error as Error;
      throw new AppError(AppErrorKind.NETWORK, `TDLib init failed: ${err.message}`, '', 0, true);
    }
  }

  private cleanupAfterInitializeFailure(): Promise<void> {
    // Before receiver success there is no client ID. If later setup failed after
    // allocation, the same shutdown path must retain that ID until Closed.
    return this.beginShutdown(false);
  }

  retryClosedClient(): Promise<void> {
    if (this.state === 'destroying' || this.state === 'idle') {
      return Promise.reject(this.clientInvalidatedError());
    }
    if (this.recoveryPromise) return this.recoveryPromise;
    if (this.state === 'ready') return Promise.resolve();
    if (this.state !== 'closed' && this.state !== 'failed') {
      return Promise.reject(this.clientInvalidatedError());
    }
    return this.startClientRecovery(true);
  }

  private clientInvalidatedError(): AppError {
    return new AppError(AppErrorKind.NETWORK, 'TDLib client is no longer active', '', 0, false);
  }

  private rejectPending(error: AppError): void {
    for (const entry of this.pendingRequests.entries()) {
      clearTimeout(entry[1].timeoutId);
      entry[1].reject(error);
    }
    this.pendingRequests.clear();
  }

  private startClientRecovery(allowRestart: boolean): Promise<void> {
    const generation = this.clientGeneration;
    const hooks = this.recoveryHooks;
    this.state = 'recovering';
    // Publish single-flight before calling user hooks: beforeRestart runs synchronously.
    let resolveFlight: () => void = (): void => {};
    let rejectFlight: (error: AppError) => void = (_error: AppError): void => {};
    const flight = new Promise<void>((resolve, reject) => {
      resolveFlight = resolve;
      rejectFlight = reject;
    });
    this.recoveryPromise = flight;
    this.recoverClient(generation, hooks, allowRestart).then(() => {
      if (this.recoveryPromise === flight) this.recoveryPromise = undefined;
      resolveFlight();
    }).catch((error: AppError) => {
      if (this.recoveryPromise === flight) this.recoveryPromise = undefined;
      rejectFlight(error);
    });
    return flight;
  }

  private isRecoveryCurrent(generation: number, hooks?: ClientRecoveryHooks): boolean {
    return generation === this.clientGeneration && this.receiveLoopStarted &&
      this.state !== 'destroying' && this.state !== 'idle' && this.recoveryHooks === hooks;
  }

  private async recoverClient(generation: number, hooks: ClientRecoveryHooks | undefined,
    allowRestart: boolean): Promise<void> {
    try {
      // No await before this invocation: runtime must stop side effects and scopes
      // in the same dispatch stack, including when the automatic budget is exhausted.
      if (hooks) await hooks.beforeRestart();
      if (!this.isRecoveryCurrent(generation, hooks)) {
        if (generation === this.clientGeneration && this.state === 'recovering') this.state = 'closed';
        return;
      }
      if (!allowRestart) throw new Error('Automatic TDLib client recovery exhausted');
      // A failed bootstrap may still own a live client. Retry it, never orphan it.
      if (this.clientId <= 0) this.clientId = tdlib.createClient();
      if (!Number.isInteger(this.clientId) || this.clientId <= 0) {
        this.clientId = 0;
        throw new Error('Invalid native client ID');
      }
      this.state = 'ready';
      if (hooks) hooks.afterRestart();
      if (!this.isRecoveryCurrent(generation, hooks) || !this.isReady()) return;
      // TDLib emits nothing until the first request. afterRestart may already send
      // parameters; this harmless query also covers runtimes without such a hook.
      // Never await its response: bootstrap depends on this same receive pipeline.
      this.send('getAuthorizationState').catch((error: AppError) => {
        if (this.isRecoveryCurrent(generation, hooks) && this.isReady() &&
          this.bootstrapConfirmedGeneration !== generation) {
          this.reportRecoveryFailure(error.message, hooks);
        }
      });
    } catch (error) {
      if (!this.isRecoveryCurrent(generation, hooks)) {
        if (generation === this.clientGeneration && this.state === 'recovering') this.state = 'closed';
        return;
      }
      const failure = this.reportRecoveryFailure(String(error), hooks);
      throw failure;
    }
  }

  private reportRecoveryFailure(errorMessage: string, hooks?: ClientRecoveryHooks): AppError {
    // Failure can happen after afterRestart created scoped adapters. Retiring those
    // scopes also prevents a sleeping retry from reviving when this live ID is retried.
    if (this.clientId > 0) this.clientGeneration++;
    this.state = 'failed';
    // Public Closed may already be queued: TDLib will never emit it twice after
    // releasing that ID. Preserve it across generation change and rearm its timer.
    // Batch provenance suppresses stale ordinary updates even if retry reaches ready.
    this.rearmBatchDrain(getMainThreadDispatcher());
    this.rejectPending(this.clientInvalidatedError());
    const failure = new AppError(AppErrorKind.NETWORK, 'TDLib recovery failed. Retry to reconnect.',
      errorMessage, 0, true);
    if (hooks) {
      try {
        hooks.onFailure(failure);
      } catch (hookError) {
        Logger.warn(`Recovery failure observer failed: ${String(hookError)}`);
      }
    }
    return failure;
  }

  async send(method: string, params: TdObject = new TdObject()): Promise<TdObject> {
    if (!method || method.length === 0) {
      throw new AppError(AppErrorKind.UNKNOWN, 'Cannot send: method is empty', '', 0, false);
    }

    // Strict state routing
    if (method === 'close') {
      if (this.state !== 'destroying' && this.state !== 'ready') {
        throw new AppError(AppErrorKind.NETWORK, 'Cannot close in current state', '', 0, false);
      }
      if (this.clientId <= 0) {
        const okResult = new TdObject();
        return okResult;
      }
    } else if (this.state !== 'ready') {
      throw new AppError(AppErrorKind.NETWORK, `Cannot send ${method}, state is ${this.state}`, '', 0, false);
    }

    if (this.clientId <= 0) {
      throw new AppError(AppErrorKind.NETWORK, `Cannot send ${method}: invalid clientId`, '', 0, false);
    }

    // An explicit user logout/wrong-number reset starts a new incident even before Ready.
    if (method === 'logOut') this.autoRecoveryUsed = false;
    const generation = this.clientGeneration;

    return new Promise((resolve: (value: TdObject) => void, reject: (error: AppError) => void) => {
      this.requestCounter = (this.requestCounter + 1) % Number.MAX_SAFE_INTEGER;
      const requestId: string = `req_${Date.now()}_${this.requestCounter}`;

      const request = new TdObject();
      if (params) {
        request.copyFrom(params);
      }
      request.setString('@type', method);
      request.setString('@extra', requestId);

      const timeoutMs: number = getMethodTimeout(method);

      const timeoutId: number = setTimeout(() => {
        if (generation !== this.clientGeneration) return;
        if (this.pendingRequests.has(requestId)) {
          this.timeoutCount++;
          this.pendingRequests.delete(requestId);
          reject(new AppError(AppErrorKind.NETWORK, `Request ${method} timed out after ${timeoutMs}ms`, '', 0, true));
        }
      }, timeoutMs);

      this.pendingRequests.set(requestId, new PendingRequest(resolve, reject, timeoutId));

      try {
        tdlib.send(this.clientId, request.toJSON());
      } catch (e) {
        clearTimeout(timeoutId);
        this.pendingRequests.delete(requestId);
        const errorMsg = String(e);
        reject(new AppError(AppErrorKind.UNKNOWN, `Native send failed for ${method}`, errorMsg, 0, true));
      }
    });
  }

  subscribeUpdates(handler: (update: TdObject) => void): () => void {
    this.updateHandlers.add(handler);
    return () => {
      this.updateHandlers.delete(handler);
    };
  }

  /**
   * Отправить запрос с автоматическим retry при transient ошибках.
   * Huawei Best Practice: retry с exponential backoff для network resilience.
   *
   * @param method - TDLib метод
   * @param params - параметры запроса
   * @param maxRetries - максимальное количество попыток (по умолчанию 3)
   * @param baseDelayMs - базовая задержка между попытками (по умолчанию 1000ms)
   */
  async sendWithRetry(
    method: string,
    params: TdObject = new TdObject(),
    maxRetries: number = 3,
    baseDelayMs: number = 1000
  ): Promise<TdObject> {
    let lastError: AppError | null = null;
    const generation = this.clientGeneration;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      if (generation !== this.clientGeneration) throw this.clientInvalidatedError();
      try {
        const response = await this.send(method, params);
        if (generation !== this.clientGeneration) throw this.clientInvalidatedError();
        return response;
      } catch (error) {
        const appError = error as AppError;
        lastError = appError;

        // Проверяем, можно ли повторить запрос
        if (!appError.retryable) {
          throw appError;
        }

        // Последняя попытка — не ждём
        if (attempt === maxRetries - 1) {
          break;
        }

        // Exponential backoff: 1s, 2s, 4s...
        const delayMs = baseDelayMs * Math.pow(2, attempt);
        Logger.warn(`Retry ${attempt + 1}/${maxRetries} for ${method} after ${delayMs}ms`);

        await this.delay(delayMs);
        if (generation !== this.clientGeneration) throw this.clientInvalidatedError();
      }
    }

    // Все попытки исчерпаны
    throw lastError || new AppError(
      AppErrorKind.NETWORK,
      `All ${maxRetries} retries failed for ${method}`,
      '',
      0,
      false
    );
  }

  /**
   * Вспомогательный метод для задержки.
   */
  private delay(ms: number): Promise<void> {
    return new Promise((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  destroy(): Promise<void> {
    if (this.shutdownPromise) return this.shutdownPromise;
    if (this.state === 'idle') return Promise.resolve();
    return this.beginShutdown(true);
  }

  private beginShutdown(graceful: boolean): Promise<void> {
    if (this.shutdownPromise) return this.shutdownPromise;
    // Publish before running synchronous invalidation/native callbacks, including
    // startup rollback. All callers observe the entire shutdown, not an early no-op.
    let resolveFlight: () => void = (): void => {};
    let rejectFlight: (error: AppError) => void = (_error: AppError): void => {};
    const flight = new Promise<void>((resolve, reject) => {
      resolveFlight = resolve;
      rejectFlight = reject;
    });
    this.shutdownPromise = flight;
    this.shutdownPipeline(graceful).then(() => {
      if (this.shutdownPromise === flight) this.shutdownPromise = undefined;
      resolveFlight();
    }).catch((error: AppError) => {
      if (this.shutdownPromise === flight) this.shutdownPromise = undefined;
      rejectFlight(error);
      // Closed can arrive after a close timeout but before this rejection handler.
      this.finishLateClientRetirement();
    });
    return flight;
  }

  private async shutdownPipeline(graceful: boolean): Promise<void> {
    const retryStop = this.state === 'destroying';
    const mustStopReceive = graceful || this.receiveLoopStarted || this.clientId > 0;
    this.state = 'destroying';
    if (!retryStop) {
      this.clientGeneration++;
      this.destroyClosedObserved = false;
    }
    const hasClientToClose = this.clientId > 0 && !this.destroyClosedObserved;
    this.rejectPending(this.clientInvalidatedError());
    Logger.info('Initiating graceful shutdown...');

    const dispatcher = getMainThreadDispatcher();
    // Replace any scheduled old-generation drain, keeping queued Closed/response
    // envelopes. Dropping that queue or leaving its stale timer strands shutdown.
    this.recoveryPromise = undefined;
    this.rearmBatchDrain(dispatcher);

    if (hasClientToClose) {
      this.clientRetirementPending = true;
      let closeWaitSettled = false;
      let closeWaitTimeoutId: number = -1;
      let resolveCloseWait: (value: boolean) => void = (_value: boolean): void => {};
      const closeStatePromise = new Promise<boolean>((resolve: (value: boolean) => void) => {
        resolveCloseWait = resolve;
      });
      let closeStateHandler: (update: TdObject) => void = (_update: TdObject): void => {};

      const finishCloseWait = (observedClosedState: boolean): void => {
        if (closeWaitSettled) {
          return;
        }
        closeWaitSettled = true;
        if (closeWaitTimeoutId !== -1) {
          clearTimeout(closeWaitTimeoutId);
          closeWaitTimeoutId = -1;
        }
        this.updateHandlers.delete(closeStateHandler);
        resolveCloseWait(observedClosedState);
      };

      closeStateHandler = (update: TdObject): void => {
        if (update.getType() !== 'updateAuthorizationState') {
          return;
        }
        const authState = update.getObject('authorization_state');
        if (authState && authState.getType() === 'authorizationStateClosed') {
          finishCloseWait(true);
        }
      };

      // Register the temporary closed-state observer before sending close().
      // TDLib can deliver authorizationStateClosed before the close response is
      // resolved, and registering afterwards turns a successful close into a
      // misleading timeout.
      this.updateHandlers.add(closeStateHandler);

      let closeOk = false;
      const closeResponse = this.send('close')
        .then((): void => { closeOk = true; })
        .catch((err: Error): void => Logger.warn(`TDLib close command rejected: ${err.message}`));
      // Public Closed is authoritative even if the close response never arrives.
      // Both branches have rejection handlers; no abandoned request Promise.
      await Promise.race([closeResponse, closeStatePromise.then((): void => {})]);
      if (this.destroyClosedObserved) {
        finishCloseWait(true);
      } else if (closeOk) {
        Logger.info('Waiting for TDLib to flush database and close...');
        if (!closeWaitSettled) {
          closeWaitTimeoutId = setTimeout(() => {
            Logger.warn('TDLib close wait timed out');
            finishCloseWait(false);
          }, 5000) as number;
        }
        const closedStateObserved = await closeStatePromise;
        if (closedStateObserved) {
          Logger.info('TDLib closed gracefully');
        }
      } else {
        finishCloseWait(false);
      }
      if (!this.destroyClosedObserved) {
        // Do not lose the ID or stop its only consumer on an unknown close result.
        // A later Closed uses the private shutdown route even after app detach.
        throw new AppError(AppErrorKind.NETWORK, 'TDLib client is still closing. Retry shutdown.',
          'authorizationStateClosed was not observed', 0, true);
      }
    }

    // From here only native stop can fail. Do not automatically retry that failure.
    this.clientRetirementPending = false;
    // Detach dispatcher only after the close command/closed-state wait has had a
    // chance to receive response/update callbacks during the destroying state.
    dispatcher.unsubscribe();
    this.receiveLoopGeneration++;
    this.receiveLoopStarted = false;

    // Revoke queued work and subscribers before awaiting the native stop barrier.
    // A rejected stop remains destroying; destroy() can retry stop without close.
    this.resetBatchDrain();

    const shutdownError = new AppError(AppErrorKind.NETWORK, 'Gateway destroyed', '', 0, false);
    for (const entry of this.pendingRequests.entries()) {
      const req = entry[1];
      clearTimeout(req.timeoutId);
      req.reject(shutdownError);
    }
    this.pendingRequests.clear();
    this.updateHandlers.clear();

    if (mustStopReceive) {
      try {
        await tdlib.stopReceiveLoop();
      } catch (error) {
        Logger.warn(`TDLib stopReceiveLoop failed during shutdown: ${String(error)}`);
        throw new AppError(AppErrorKind.NETWORK, 'TDLib receive loop stop failed. Retry shutdown.',
          String(error), 0, true);
      }
    }

    this.clientId = 0;
    this.state = 'idle';
    if (graceful) TdGatewayImpl.instance = null;
    Logger.info('Gateway destroyed completely');
  }

  private finishLateClientRetirement(): void {
    if (this.state !== 'destroying' || !this.clientRetirementPending ||
      !this.destroyClosedObserved || this.shutdownPromise) return;
    this.beginShutdown(true).catch((error: AppError) => {
      Logger.warn(`Late TDLib retirement stop failed: ${error.message}`);
    });
  }

  // --- Обработка в dispatcher-пайплайне ---

  /**
   * Вызывается через MainThreadDispatcher.
   * Обрабатывает ответы на запросы (JSON с @extra).
   */
  private handleResponseOnMainThread(responseJson: string): void {
    if (!this.isCurrentEnvelopeJson(responseJson)) return;
    let rawObject: TdObject;
    try {
      rawObject = TdObject.fromJSON(responseJson);
    } catch {
      Logger.error('Malformed JSON response');
      return;
    }

    const requestId: string = rawObject.getString('@extra');

    if (requestId) {
      if (this.pendingRequests.has(requestId)) {
        this.resolvePendingRequest(requestId, rawObject);
      } else {
        Logger.warn(`Stale response ignored for missing request: ${requestId}`);
      }
      return;
    }

    // Ответ без @extra — трактуем как обновление
    this.broadcastUpdate(rawObject);
  }

  /**
   * Вызывается из AppCoreRuntime через MainThreadDispatcher.subscribeUpdates.
   * Обновления уже в едином dispatcher-пайплайне.
   */
  handleUpdateOnMainThread(rawJson: string): void {
    if (!this.isCurrentEnvelopeJson(rawJson)) return;

    let update: TdObject;
    try {
      update = TdObject.fromJSON(rawJson);
    } catch {
      Logger.error('Malformed JSON update');
      return;
    }

    const updateType: string = update.getType();
    if (!updateType) {
      Logger.warn('Update without @type');
      return;
    }

    this.broadcastUpdate(update);
  }

  private resolvePendingRequest(requestId: string, response: TdObject): void {
    const pending = this.pendingRequests.get(requestId);
    if (!pending) return;

    clearTimeout(pending.timeoutId);
    this.pendingRequests.delete(requestId);

    const responseType = response.getType();
    if (responseType === 'error') {
      const code: number = response.getNumber('code');
      const message: string = code === 406 ? '' : response.getString('message');
      pending.reject(classifyTdlibError(code, message));
    } else {
      pending.resolve(response);
    }
  }

  private broadcastUpdate(update: TdObject): void {
    const authState = update.getType() === 'updateAuthorizationState' ? update.getObject('authorization_state') : null;
    const closed = authState !== null && authState !== undefined && authState.getType() === 'authorizationStateClosed';
    if (this.state === 'destroying') {
      // Shutdown still needs Closed and the close response, but no account updates.
      if (!closed || this.destroyClosedObserved) return;
      this.destroyClosedObserved = true;
    } else if (closed) {
      this.state = 'closed';
      this.clientId = 0;
      this.clientGeneration++;
      this.rejectPending(this.clientInvalidatedError());
      this.resetBatchDrain();
    } else if (authState) {
      const authType = authState.getType();
      if (this.isLiveAuthorizationState(authType)) {
        // This current-client native update supersedes the optional bootstrap probe.
        // Its delayed rejection/timeout must not invalidate a working login/account.
        this.bootstrapConfirmedGeneration = this.clientGeneration;
      }
      if (authType === 'authorizationStateReady') this.autoRecoveryUsed = false;
    }
    const generation = this.clientGeneration;
    // Безопасно — мы на main thread
    const handlersSnapshot: ((update: TdObject) => void)[] = Array.from(this.updateHandlers);
    for (const handler of handlersSnapshot) {
      if (generation !== this.clientGeneration) break;
      if (!this.updateHandlers.has(handler)) {
        continue;
      }
      try {
        handler(update);
      } catch (e) {
        Logger.error('Error in update handler', String(e));
      }
    }
    if (closed && this.state === 'closed' && generation === this.clientGeneration && this.recoveryHooks) {
      const allowRestart = !this.autoRecoveryUsed;
      this.autoRecoveryUsed = true;
      this.startClientRecovery(allowRestart).catch((error: AppError) => {
        Logger.warn(`Client recovery stopped: ${error.message}`);
      });
    }
    if (closed) this.finishLateClientRetirement();
  }

  private isLiveAuthorizationState(authType: string): boolean {
    // Explicit allowlist from td_api.tl: real initialization/login progress, not
    // LoggingOut/Closing/Closed or an unknown future state. This does NOT renew
    // the recovery budget: only native Ready or an explicit logOut can do that.
    switch (authType) {
      case 'authorizationStateWaitTdlibParameters':
      case 'authorizationStateWaitPhoneNumber':
      case 'authorizationStateWaitPremiumPurchase':
      case 'authorizationStateWaitEmailAddress':
      case 'authorizationStateWaitEmailCode':
      case 'authorizationStateWaitCode':
      case 'authorizationStateWaitOtherDeviceConfirmation':
      case 'authorizationStateWaitRegistration':
      case 'authorizationStateWaitPassword':
      case 'authorizationStateReady':
        return true;
      default:
        return false;
    }
  }

  private isCurrentEnvelope(obj: Record<string, Object>): boolean {
    if (this.clientId <= 0 || obj === null || obj === undefined || typeof obj !== 'object' ||
      Array.isArray(obj) || obj['@client_id'] !== this.clientId) return false;
    if (this.state === 'ready' || this.state === 'destroying') return true;
    // A failed bootstrap still owns a live native client. Its eventual Closed must
    // retire that ID even while a manual retry is awaiting the account barrier.
    if (this.state !== 'failed' && this.state !== 'recovering') return false;
    return this.isClosedEnvelope(obj);
  }

  private isClosedEnvelope(obj: Record<string, Object>): boolean {
    const authState = obj['authorization_state'] as Record<string, Object>;
    return obj['@type'] === 'updateAuthorizationState' && authState !== null && authState !== undefined &&
      typeof authState === 'object' && authState['@type'] === 'authorizationStateClosed';
  }

  private isCurrentEnvelopeJson(rawJson: string): boolean {
    try {
      // TdObject's lazy field access can find nested values: identity must be top-level.
      return this.isCurrentEnvelope(JSON.parse(rawJson) as Record<string, Object>);
    } catch {
      return false;
    }
  }

  /**
   * Парсит батч JSON-массив из NAPI и диспатчит каждый элемент.
   * NAPI receive loop шлёт: [obj1, obj2, ...] — один callback вместо N.
   */
  // Очередь батчей + инкрементальный дрейн. NAPI thread-safe function может
  // доставить несколько батчей по 50 ответов за один uv-тик; синхронная
  // обработка блокировала main thread (THREAD_BLOCK_6S на холодном старте).
  // Дрейн работает и в состоянии 'destroying' — close-flow ждёт
  // authorizationStateClosed через тот же конвейер.
  private enqueueBatch(batchJson: string, dispatcher: MainThreadDispatcher): void {
    if (this.clientId <= 0 || this.state === 'idle' || this.state === 'initializing' || this.state === 'closed') return;
    const batch: QueuedTdBatch = { json: batchJson, generation: this.clientGeneration };
    this.pendingBatchQueue.push(batch);
    this.scheduleDrain(dispatcher);
  }

  private rearmBatchDrain(dispatcher: MainThreadDispatcher): void {
    if (this.drainTimerId !== -1) clearTimeout(this.drainTimerId);
    this.drainTimerId = -1;
    this.drainScheduled = false;
    if (this.drainIndex < this.drainItems.length || this.pendingBatchQueue.length > 0) {
      this.scheduleDrain(dispatcher);
    }
  }

  private scheduleDrain(dispatcher: MainThreadDispatcher,
    delayMs: number = TdGatewayImpl.DRAIN_YIELD_MS): void {
    if (this.drainScheduled) {
      return;
    }
    this.drainScheduled = true;
    const generation = this.clientGeneration;
    this.drainTimerId = setTimeout(() => {
      if (generation !== this.clientGeneration) {
        // Destroy keeps queued close-flow envelopes, but invalidates old timer callbacks.
        return;
      }
      this.drainTimerId = -1;
      this.drainScheduled = false;
      this.drainSlice(dispatcher);
    }, delayMs) as number;
  }

  private drainSlice(dispatcher: MainThreadDispatcher): void {
    const sliceStart = Date.now();
    while (Date.now() - sliceStart < TdGatewayImpl.DRAIN_BUDGET_MS) {
      if (this.drainIndex >= this.drainItems.length) {
        this.drainItems = [];
        this.drainIndex = 0;
        const nextBatch = this.pendingBatchQueue.shift();
        if (nextBatch === undefined) {
          this.drainHotStreak = 0;
          return;
        }
        this.loadBatchForDrain(nextBatch, dispatcher);
        continue;
      }
      const obj = this.drainItems[this.drainIndex] as Record<string, Object>;
      this.drainIndex++;
      this.dispatchItem(obj, dispatcher, this.drainItemsGeneration);
    }
    if (this.drainIndex < this.drainItems.length || this.pendingBatchQueue.length > 0) {
      const elapsed = Date.now() - sliceStart;
      this.drainHotStreak++;
      const backoff = Math.min(
        TdGatewayImpl.DRAIN_BACKOFF_CAP_MS,
        elapsed * (1 + this.drainHotStreak)
      );
      this.scheduleDrain(dispatcher, Math.max(TdGatewayImpl.DRAIN_YIELD_MS, backoff));
    } else {
      this.drainHotStreak = 0;
    }
  }

  /**
   * Сигнал шторма для фоновых потребителей main thread (media watcher и т.п.):
   * очередь батчей непуста или дрейн подряд упирается в бюджет.
   */
  isDrainCongested(): boolean {
    return this.pendingBatchQueue.length > 0 || this.drainHotStreak > 0;
  }

  private loadBatchForDrain(batch: QueuedTdBatch, dispatcher: MainThreadDispatcher): void {
    let parsed: Object;
    try {
      parsed = JSON.parse(batch.json) as Object;
    } catch {
      Logger.error('Malformed batch JSON');
      return;
    }
    if (Array.isArray(parsed)) {
      this.drainItems = parsed as Object[];
      this.drainItemsGeneration = batch.generation;
      this.drainIndex = 0;
      return;
    }
    // Same identity validation for the single-object NAPI fallback.
    this.dispatchItem(parsed as Record<string, Object>, dispatcher, batch.generation);
  }

  private dispatchItem(obj: Record<string, Object>, dispatcher: MainThreadDispatcher, generation: number): void {
    if (!this.isCurrentEnvelope(obj)) return;
    if (generation !== this.clientGeneration && !this.isClosedEnvelope(obj)) return;
    const rawJson = JSON.stringify(obj);
    // Check @extra directly on parsed object — avoids double-parse
    const hasExtra = obj !== null && obj !== undefined && obj['@extra'] !== undefined;
    if (this.state === 'destroying') {
      // Runtime can unsubscribe its dispatcher after a failed shutdown. Keep only
      // this owner's close responses/Closed on the already-main-thread NAPI path;
      // broadcastUpdate still rejects non-Closed account updates while destroying.
      if (hasExtra) this.handleResponseOnMainThread(rawJson);
      else this.handleUpdateOnMainThread(rawJson);
      return;
    }
    if (hasExtra) {
      dispatcher.dispatchResponse(rawJson);
    } else {
      dispatcher.dispatchUpdate(rawJson);
    }
  }

  private resetBatchDrain(): void {
    if (this.drainTimerId !== -1) {
      clearTimeout(this.drainTimerId);
      this.drainTimerId = -1;
    }
    this.drainScheduled = false;
    this.pendingBatchQueue = [];
    this.drainItems = [];
    this.drainItemsGeneration = -1;
    this.drainIndex = 0;
    this.drainHotStreak = 0;
  }

}

export function getTdGateway(): TdGateway {
  return TdGatewayImpl.getInstance();
}
