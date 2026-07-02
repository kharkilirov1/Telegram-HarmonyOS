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

type GatewayState = 'idle' | 'initializing' | 'ready' | 'destroying';

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
  destroy(): Promise<void>;
  getState(): GatewayState;
  getGatewayStats(): GatewayStats;
  isReady(): boolean;
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
  private updateHandlers: Set<(update: TdObject) => void> = new Set();
  private pendingRequests: Map<string, PendingRequest> = new Map();
  private requestCounter: number = 0;
  private timeoutCount: number = 0;
  private pendingBatchQueue: string[] = [];
  private drainItems: Object[] = [];
  private drainIndex: number = 0;
  private drainScheduled: boolean = false;
  private drainTimerId: number = -1;
  private static readonly DRAIN_BUDGET_MS = 8;
  // 0ms нельзя: нулевой таймер, взведённый из таймерного колбэка, дозревает в той же
  // uv-таймерной фазе — цепочка слайсов сливается в один uv_timer_task и блокирует
  // main thread (THREAD_BLOCK_6S на пост-логиновом шторме). 1ms уводит слайс в
  // следующий оборот цикла, где watchdog/vsync получают ход.
  private static readonly DRAIN_YIELD_MS = 1;

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
    if (this.state !== 'idle') {
      Logger.warn(`initialize() called in state: ${this.state}. Ignoring.`);
      return;
    }

    this.state = 'initializing';
    try {
      this.clientId = tdlib.createClient();
      Logger.info(`Created native client with ID: ${this.clientId}`);

      // Настраиваем MainThreadDispatcher ДО запуска receive loop.
      // dispatcher.subscribeResponses получает JSON ответы, где мы
      // безопасно resolve/reject pending requests.
      const dispatcher = getMainThreadDispatcher();

      dispatcher.subscribeResponses((responseJson: string) => {
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
      tdlib.startReceiveLoop((batchJson: string) => {
        try {
          this.enqueueBatch(batchJson, dispatcher);
        } catch (error) {
          Logger.error('Error in receive loop relay', String(error));
        }
      });

      this.state = 'ready';
      Logger.info('Gateway initialized with MainThreadDispatcher bridge');
    } catch (error) {
      this.cleanupAfterInitializeFailure();
      const err = error as Error;
      throw new AppError(AppErrorKind.NETWORK, `TDLib init failed: ${err.message}`, '', 0, true);
    }
  }

  private cleanupAfterInitializeFailure(): void {
    getMainThreadDispatcher().unsubscribe();
    this.resetBatchDrain();
    try {
      if (this.clientId > 0) {
        tdlib.stopReceiveLoop();
      }
    } catch (cleanupError) {
      Logger.warn(`TDLib stopReceiveLoop failed after initialize failure: ${String(cleanupError)}`);
    }
    const initError = new AppError(AppErrorKind.NETWORK, 'Gateway initialize failed', '', 0, true);
    for (const entry of this.pendingRequests.entries()) {
      const req = entry[1];
      clearTimeout(req.timeoutId);
      req.reject(initError);
    }
    this.pendingRequests.clear();
    this.updateHandlers.clear();
    this.clientId = 0;
    this.state = 'idle';
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

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await this.send(method, params);
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

  async destroy(): Promise<void> {
    if (this.state === 'destroying' || this.state === 'idle') return;

    const wasReady = this.state === 'ready';
    this.state = 'destroying';
    Logger.info('Initiating graceful shutdown...');

    const dispatcher = getMainThreadDispatcher();

    if (wasReady && this.clientId > 0) {
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
      await this.send('close')
        .then((): void => { closeOk = true; })
        .catch((err: Error): void => Logger.warn(`TDLib close command rejected: ${err.message}`));
      if (closeOk) {
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
    }

    // Detach dispatcher only after the close command/closed-state wait has had a
    // chance to receive response/update callbacks during the destroying state.
    dispatcher.unsubscribe();

    try {
      tdlib.stopReceiveLoop();
    } catch (error) {
      Logger.warn(`TDLib stopReceiveLoop failed during destroy: ${String(error)}`);
    }

    this.resetBatchDrain();

    const shutdownError = new AppError(AppErrorKind.NETWORK, 'Gateway destroyed', '', 0, true);
    for (const entry of this.pendingRequests.entries()) {
      const req = entry[1];
      clearTimeout(req.timeoutId);
      req.reject(shutdownError);
    }
    this.pendingRequests.clear();
    this.updateHandlers.clear();

    this.clientId = 0;
    this.state = 'idle';
    TdGatewayImpl.instance = null;
    Logger.info('Gateway destroyed completely');
  }

  // --- Обработка в dispatcher-пайплайне ---

  /**
   * Вызывается через MainThreadDispatcher.
   * Обрабатывает ответы на запросы (JSON с @extra).
   */
  private handleResponseOnMainThread(responseJson: string): void {
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
    if (this.state !== 'ready' && this.state !== 'destroying') return;

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
      const message: string = response.getString('message');
      pending.reject(classifyTdlibError(code, message));
    } else {
      pending.resolve(response);
    }
  }

  private broadcastUpdate(update: TdObject): void {
    // Безопасно — мы на main thread
    const handlersSnapshot: ((update: TdObject) => void)[] = Array.from(this.updateHandlers);
    for (const handler of handlersSnapshot) {
      if (!this.updateHandlers.has(handler)) {
        continue;
      }
      try {
        handler(update);
      } catch (e) {
        Logger.error('Error in update handler', String(e));
      }
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
    this.pendingBatchQueue.push(batchJson);
    this.scheduleDrain(dispatcher);
  }

  private scheduleDrain(dispatcher: MainThreadDispatcher): void {
    if (this.drainScheduled) {
      return;
    }
    this.drainScheduled = true;
    this.drainTimerId = setTimeout(() => {
      this.drainTimerId = -1;
      this.drainScheduled = false;
      this.drainSlice(dispatcher);
    }, TdGatewayImpl.DRAIN_YIELD_MS) as number;
  }

  private drainSlice(dispatcher: MainThreadDispatcher): void {
    const sliceStart = Date.now();
    while (Date.now() - sliceStart < TdGatewayImpl.DRAIN_BUDGET_MS) {
      if (this.drainIndex >= this.drainItems.length) {
        this.drainItems = [];
        this.drainIndex = 0;
        const nextBatch = this.pendingBatchQueue.shift();
        if (nextBatch === undefined) {
          return;
        }
        this.loadBatchForDrain(nextBatch, dispatcher);
        continue;
      }
      const obj = this.drainItems[this.drainIndex] as Record<string, Object>;
      this.drainIndex++;
      this.dispatchItem(obj, dispatcher);
    }
    if (this.drainIndex < this.drainItems.length || this.pendingBatchQueue.length > 0) {
      this.scheduleDrain(dispatcher);
    }
  }

  private loadBatchForDrain(batchJson: string, dispatcher: MainThreadDispatcher): void {
    let parsed: Object;
    try {
      parsed = JSON.parse(batchJson) as Object;
    } catch {
      Logger.error('Malformed batch JSON');
      return;
    }
    if (Array.isArray(parsed)) {
      this.drainItems = parsed as Object[];
      this.drainIndex = 0;
      return;
    }
    // Fallback: одиночный объект вместо массива (не должно случаться с батчевым NAPI)
    if (this.isResponseJson(batchJson)) {
      dispatcher.dispatchResponse(batchJson);
    } else {
      dispatcher.dispatchUpdate(batchJson);
    }
  }

  private dispatchItem(obj: Record<string, Object>, dispatcher: MainThreadDispatcher): void {
    const rawJson = JSON.stringify(obj);
    // Check @extra directly on parsed object — avoids double-parse
    const hasExtra = obj !== null && obj !== undefined && obj['@extra'] !== undefined;
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
    this.drainIndex = 0;
  }

  /**
   * Проверяет, является ли JSON ответом на запрос (содержит @extra на верхнем уровне).
   * Используем безопасный парсинг вместо строковых проверок для предотвращения ложных срабатываний.
   */
  private isResponseJson(rawJson: string): boolean {
    try {
      const jsonObj: Record<string, object> = JSON.parse(rawJson);
      return jsonObj && typeof jsonObj === 'object' && jsonObj['@extra'] !== undefined;
    } catch {
      // Если JSON некорректный, используем fallback проверку
      return rawJson.includes('"@extra"');
    }
  }
}

export function getTdGateway(): TdGateway {
  return TdGatewayImpl.getInstance();
}
