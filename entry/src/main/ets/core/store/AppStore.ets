// Application store with serial dispatch queue
// Single source of truth, single writer
// All state mutations go through this store

import { AppState, initialAppState, ReducerAction } from '../model/AppState';
import { AnyAppEvent } from '../model/AppEvent';
import { assertInvariants } from '../invariants/assertInvariants';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'AppStore';

export type Reducer = (state: AppState, action: ReducerAction) => AppState;
export type StateListener = (state: AppState, prevState: AppState) => void;

export class AppStore {
  private state: AppState;
  private listeners: Set<StateListener> = new Set();
  private reducer: Reducer;
  private devMode: boolean;

  // Serial dispatch queue
  private pendingPromise: Promise<void> = Promise.resolve();
  private isDispatching: boolean = false;

  constructor(reducer: Reducer, initialState?: AppState, devMode: boolean = true) {
    this.reducer = reducer;
    this.state = initialState || initialAppState;
    this.devMode = devMode;

    if (this.devMode) {
      assertInvariants(this.state, this.devMode);
    }
  }

  getState(): AppState {
    return this.state;
  }

  /**
   * Dispatch event через serial queue.
   * Huawei Best Practice: не выбрасывать ошибки в Promise chain,
   * чтобы не блокировать последующие dispatch'ы.
   */
  dispatch(event: AnyAppEvent): Promise<void> {
    this.pendingPromise = this.pendingPromise.then(() => {
      return this.processEvent(event);
    }).catch((error: Error) => {
      // НЕ throw — логируем и продолжаем, чтобы не ломать serial queue
      hilog.error(DOMAIN, TAG, 'Error processing event %{public}s: %{public}s',
        event.type, String(error));
      // Опционально: можно emit error event для UI обработки
    });

    return this.pendingPromise;
  }

  private async processEvent(event: AnyAppEvent): Promise<void> {
    if (this.isDispatching) {
      throw new Error('[AppStore] Recursive dispatch detected');
    }

    try {
      this.isDispatching = true;

      const prevState = this.state;
      const newState = this.reducer(prevState, event);
      this.state = newState;

      if (this.devMode) {
        assertInvariants(newState, this.devMode);
      }

      this.notifyListeners(newState, prevState);
    } finally {
      this.isDispatching = false;
    }
  }

  subscribe(listener: StateListener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private notifyListeners(newState: AppState, prevState: AppState): void {
    Promise.resolve().then(() => {
      for (const listener of this.listeners) {
        try {
          listener(newState, prevState);
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'Listener error: %{public}s', String(error));
        }
      }
    });
  }

  select<T>(selector: (state: AppState) => T): T {
    return selector(this.state);
  }

  replaceReducer(newReducer: Reducer): void {
    this.reducer = newReducer;
  }

  resetState(): void {
    this.state = initialAppState;
    this.notifyListeners(this.state, this.state);
  }
}

// Default store instance (singleton)
let defaultStore: AppStore | null = null;

export function getDefaultStore(reducer: Reducer): AppStore {
  if (!defaultStore) {
    defaultStore = new AppStore(reducer);
  }
  return defaultStore;
}

export function resetDefaultStore(): void {
  defaultStore = null;
}
