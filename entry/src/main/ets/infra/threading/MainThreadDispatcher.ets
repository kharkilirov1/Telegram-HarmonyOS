// MainThreadDispatcher — аналог iOS Telegram `deliverOnMainQueue`
//
// Проблема: нативный tdlib.startReceiveLoop() вызывает колбэк из фонового потока.
// В HarmonyOS AppStorage / @State / UI работают ТОЛЬКО на main thread (Actor model).
//
// Решение: используем Emitter из @kit.BasicServicesKit как мост между потоками.
// Emitter гарантирует доставку на main thread (UI thread).
//
// Паттерн:
//   TDLib native thread → emitter.emit(eventId, data) → main thread → handler(data)
//
// Референс: iOS Telegram — SwiftSignalKit/Queue.swift + Signal_Dispatch.swift
//   там: Signal |> deliverOn(Queue.mainQueue())
//   у нас: MainThreadDispatcher.dispatch(data) → emitter → main thread handler

import { emitter } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'MainThreadDispatcher';
const DOMAIN = 0x000B;

// Уникальные ID событий для Emitter (строковые для HarmonyOS)
const TDLIB_UPDATE_EVENT_ID: string = 'tdlib_update_event';
const TDLIB_RESPONSE_EVENT_ID: string = 'tdlib_response_event';

// Тип колбэка для обработки обновлений на main thread
export type MainThreadHandler = (data: string) => void;

export class MainThreadDispatcher {
  private updateHandler: MainThreadHandler | null = null;
  private responseHandler: MainThreadHandler | null = null;
  private isSubscribed: boolean = false;
  private dispatchedCount: number = 0;
  private droppedCount: number = 0;

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
   * Вызывается из TdGateway внутри нативного колбэка (фоновый поток).
   * Emitter гарантирует доставку на main thread.
   */
  dispatchUpdate(rawJson: string): void {
    // Emitter требует объект с data.string для строковых событий
    emitter.emit(TDLIB_UPDATE_EVENT_ID, { data: rawJson });
    this.dispatchedCount++;
  }

  /**
   * Отправить raw JSON ответ (на request) из любого потока → main thread.
   */
  dispatchResponse(rawJson: string): void {
    emitter.emit(TDLIB_RESPONSE_EVENT_ID, { data: rawJson });
  }

  /**
   * Отписаться от всех событий. Вызывать при shutdown.
   */
  unsubscribe(): void {
    emitter.off(TDLIB_UPDATE_EVENT_ID);
    emitter.off(TDLIB_RESPONSE_EVENT_ID);
    this.updateHandler = null;
    this.responseHandler = null;
    this.isSubscribed = false;
    hilog.info(DOMAIN, TAG, 'Unsubscribed from all events. Stats: dispatched=%{public}d, dropped=%{public}d',
      this.dispatchedCount, this.droppedCount);
  }

  getStats(): DispatcherStats {
    const stats = new DispatcherStats();
    stats.dispatched = this.dispatchedCount;
    stats.dropped = this.droppedCount;
    stats.isSubscribed = this.isSubscribed;
    return stats;
  }

  // --- Private ---

  private ensureSubscribed(): void {
    if (this.isSubscribed) {
      return;
    }

    // Подписка на обновления — Emitter доставит на main thread
    emitter.on(TDLIB_UPDATE_EVENT_ID, (eventData: emitter.EventData) => {
      if (!this.updateHandler) {
        this.droppedCount++;
        return;
      }

      const data = eventData?.data;
      const json = typeof data === 'string' ? data : '';
      if (json) {
        this.updateHandler(json);
      }
    });

    // Подписка на ответы
    emitter.on(TDLIB_RESPONSE_EVENT_ID, (eventData: emitter.EventData) => {
      if (!this.responseHandler) {
        return;
      }

      const data = eventData?.data;
      const json = typeof data === 'string' ? data : '';
      if (json) {
        this.responseHandler(json);
      }
    });

    this.isSubscribed = true;
    hilog.info(DOMAIN, TAG, 'Emitter subscriptions established');
  }
}

export class DispatcherStats {
  dispatched: number = 0;
  dropped: number = 0;
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
