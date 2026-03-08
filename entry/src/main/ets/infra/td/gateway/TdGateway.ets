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
import { getMainThreadDispatcher } from '../../threading/MainThreadDispatcher';
import { hilog } from '@kit.PerformanceAnalysisKit';
import tdlib from 'libtdlib_napi.so';

const DOMAIN = 0x0002;
const TAG = 'TdGateway';
const DEFAULT_REQUEST_TIMEOUT_MS = 30000;

// Явный интерфейс вместо Record (согласно рекомендациям Huawei)
interface MethodTimeout {
  getChats: number;
  sendMessage: number;
  downloadFile: number;
  close: number;
}

const METHOD_TIMEOUTS: MethodTimeout = {
  getChats: 15000,
  sendMessage: 30000,
  downloadFile: 120000,
  close: 10000
};

// Хелпер для получения таймаута — явная проверка свойства
function getMethodTimeout(method: string): number {
  if (method === 'getChats' || method === 'loadChats') return METHOD_TIMEOUTS.getChats;
  if (method === 'getChatHistory') return METHOD_TIMEOUTS.getChats;
  if (method === 'searchCallMessages' || method === 'getChat') return METHOD_TIMEOUTS.getChats;
  if (method === 'sendMessage') return METHOD_TIMEOUTS.sendMessage;
  if (method === 'downloadFile') return METHOD_TIMEOUTS.downloadFile;
  if (method === 'close') return METHOD_TIMEOUTS.close;
  return DEFAULT_REQUEST_TIMEOUT_MS;
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
      tdlib.startReceiveLoop((rawJson: string) => {
        try {
          // Huawei Best Practice: валидация JSON через parsing вместо string.includes
          // string.includes('@extra') может дать false positive если '@extra' в теле сообщения
          const isResponse = this.isResponseJson(rawJson);
          if (isResponse) {
            dispatcher.dispatchResponse(rawJson);
          } else {
            dispatcher.dispatchUpdate(rawJson);
          }
        } catch (error) {
          Logger.error('Error in receive loop relay', String(error));
        }
      });

      this.state = 'ready';
      Logger.info('Gateway initialized with MainThreadDispatcher bridge');
    } catch (error) {
      this.state = 'idle';
      const err = error as Error;
      throw new AppError(AppErrorKind.NETWORK, `TDLib init failed: ${err.message}`, '', 0, true);
    }
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

    // Отписываемся от dispatcher
    const dispatcher = getMainThreadDispatcher();
    dispatcher.unsubscribe();

    if (wasReady && this.clientId > 0) {
      let closeOk = false;
      await this.send('close')
        .then((): void => { closeOk = true; })
        .catch((err: Error): void => Logger.warn(`TDLib close command rejected: ${err.message}`));
      if (closeOk) {
        Logger.info('Waiting for TDLib to flush database and close...');
        await new Promise<void>((resolve) => {
          let settled = false;

          const handler = (update: TdObject): void => {
            if (update.getType() === 'updateAuthorizationState') {
              const authState = update.getObject('authorization_state');
              if (authState && authState.getType() === 'authorizationStateClosed') {
                if (!settled) {
                  settled = true;
                  clearTimeout(timeoutId);
                  this.updateHandlers.delete(handler);
                  resolve();
                }
              }
            }
          };

          this.updateHandlers.add(handler);

          const timeoutId = setTimeout(() => {
            if (!settled) {
              settled = true;
              this.updateHandlers.delete(handler);
              Logger.warn('TDLib close wait timed out');
              resolve();
            }
          }, 5000);
        });
        Logger.info('TDLib closed gracefully');
      }
    }

    tdlib.stopReceiveLoop();

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

    if (requestId && this.pendingRequests.has(requestId)) {
      this.resolvePendingRequest(requestId, rawObject);
    } else {
      // Ответ без @extra — трактуем как обновление
      this.broadcastUpdate(rawObject);
    }
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
    for (const handler of this.updateHandlers) {
      try {
        handler(update);
      } catch (e) {
        Logger.error('Error in update handler', String(e));
      }
    }
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
