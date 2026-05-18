// MainThreadDispatcher — точка маршрутизации входящих JSON от TDLib.
//
// Актуальная модель:
// - C++ NAPI использует thread-safe function и передаёт callback в ArkTS.
// - Для ArkTS слой получает данные как "безопасные для main-thread обработки".
// - Этот класс разделяет поток данных на:
//   1) responses (@extra)  2) updates (обычные апдейты)
//
// Цель: единая точка подписки/статистики и отсутствие прямой связки
// между TdGateway и верхними слоями приложения.

import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'MainThreadDispatcher';
const DOMAIN = 0x000B;

// Тип колбэка для обработки обновлений на main thread
export type MainThreadHandler = (data: string) => void;

export class MainThreadDispatcher {
  private updateHandler: MainThreadHandler | null = null;
  private responseHandler: MainThreadHandler | null = null;
  private isSubscribed: boolean = false;
  private dispatchedCount: number = 0;
  private droppedCount: number = 0;
  private handlerErrorCount: number = 0;

  /**
   * Подписаться на обновления TDLib, доставляемые на main thread.
   * Вызывать из main thread (например, из AppCoreRuntime.initialize).
   */
  subscribeUpdates(handler: MainThreadHandler): void {
    this.updateHandler = handler;
    this.ensureSubscribed();
    hilog.info(DOMAIN, TAG, 'Subscribed to TDLib updates on main thread');
  }

  /**
   * Подписаться на ответы TDLib (request-response), доставляемые на main thread.
   */
  subscribeResponses(handler: MainThreadHandler): void {
    this.responseHandler = handler;
    this.ensureSubscribed();
    hilog.info(DOMAIN, TAG, 'Subscribed to TDLib responses on main thread');
  }

  /**
   * Отправить raw JSON обновление из любого потока → main thread.
   * Вызывается из TdGateway внутри нативного колбэка.
   * В ArkTS N-API колбэки уже приходят на Main Thread.
   */
  dispatchUpdate(rawJson: string): void {
    this.dispatchedCount++;
    const handler = this.updateHandler;
    if (handler) {
      try {
        handler(rawJson);
      } catch (error) {
        this.handlerErrorCount++;
        hilog.error(DOMAIN, TAG, 'Update handler failed, total handler errors: %{public}d, error: %{public}s',
          this.handlerErrorCount, String(error));
      }
    } else {
      this.droppedCount++;
      hilog.warn(DOMAIN, TAG, 'Update dropped (handler not attached yet), total dropped: %{public}d',
        this.droppedCount);
    }
  }

  /**
   * Отправить raw JSON ответ (на request) из любого потока → main thread.
   */
  dispatchResponse(rawJson: string): void {
    this.dispatchedCount++;
    const handler = this.responseHandler;
    if (handler) {
      try {
        handler(rawJson);
      } catch (error) {
        this.handlerErrorCount++;
        hilog.error(DOMAIN, TAG, 'Response handler failed, total handler errors: %{public}d, error: %{public}s',
          this.handlerErrorCount, String(error));
      }
    } else {
      this.droppedCount++;
      hilog.warn(DOMAIN, TAG, 'Response dropped (handler not attached yet), total dropped: %{public}d',
        this.droppedCount);
    }
  }

  /**
   * Отписаться от всех событий. Вызывать при shutdown.
   */
  unsubscribe(): void {
    this.updateHandler = null;
    this.responseHandler = null;
    this.isSubscribed = false;
    hilog.info(DOMAIN, TAG,
      'Unsubscribed from all events. Stats: dispatched=%{public}d, dropped=%{public}d, handlerErrors=%{public}d',
      this.dispatchedCount, this.droppedCount, this.handlerErrorCount);
  }

  getStats(): DispatcherStats {
    const stats = new DispatcherStats();
    stats.dispatched = this.dispatchedCount;
    stats.dropped = this.droppedCount;
    stats.handlerErrors = this.handlerErrorCount;
    stats.isSubscribed = this.isSubscribed;
    return stats;
  }

  // --- Private ---

  private ensureSubscribed(): void {
    if (this.isSubscribed) {
      return;
    }
    this.isSubscribed = true;
    hilog.info(DOMAIN, TAG, 'Dispatcher subscriptions established');
  }
}

export class DispatcherStats {
  dispatched: number = 0;
  dropped: number = 0;
  handlerErrors: number = 0;
  isSubscribed: boolean = false;
}

// Singleton
let dispatcherInstance: MainThreadDispatcher | null = null;

export function getMainThreadDispatcher(): MainThreadDispatcher {
  if (!dispatcherInstance) {
    dispatcherInstance = new MainThreadDispatcher();
  }
  return dispatcherInstance;
}
