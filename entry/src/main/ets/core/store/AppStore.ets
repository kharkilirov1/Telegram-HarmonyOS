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
      this.processEvent(event);
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Error processing event %{public}s: %{public}s',
        event.type, String(error));
    });

    return this.pendingPromise;
  }

  /**
   * Dispatch batch of events — single notification at the end.
   * Use for getChatHistory (50+ messages) to avoid 50 separate notify cycles.
   */
  dispatchBatch(events: AnyAppEvent[]): Promise<void> {
    if (events.length === 0) {
      return this.pendingPromise;
    }
    if (events.length === 1) {
      return this.dispatch(events[0]);
    }

    this.pendingPromise = this.pendingPromise.then(() => {
      this.processEventBatch(events);
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Error processing batch (%{public}d events): %{public}s',
        events.length, String(error));
    });

    return this.pendingPromise;
  }

  private processEvent(event: AnyAppEvent): void {
    if (this.isDispatching) {
      throw new Error('[AppStore] Recursive dispatch detected');
    }

    const prevState = this.state;
    try {
      this.isDispatching = true;
      this.state = this.reducer(prevState, event);

      if (this.devMode) {
        assertInvariants(this.state, this.devMode);
      }
    } finally {
      this.isDispatching = false;
    }

    this.notifyListeners(this.state, prevState);
  }

  private processEventBatch(events: AnyAppEvent[]): void {
    if (this.isDispatching) {
      throw new Error('[AppStore] Recursive dispatch detected');
    }

    const prevState = this.state;
    try {
      this.isDispatching = true;
      for (const event of events) {
        this.state = this.reducer(this.state, event);
      }

      if (this.devMode) {
        assertInvariants(this.state, this.devMode);
      }
    } finally {
      this.isDispatching = false;
    }

    this.notifyListeners(this.state, prevState);
  }

  subscribe(listener: StateListener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private notifyListeners(newState: AppState, prevState: AppState): void {
    // Snapshot — Set может измениться если listener вызовет subscribe/unsubscribe
    const listenersSnapshot: StateListener[] = Array.from(this.listeners);
    for (const listener of listenersSnapshot) {
      try {
        listener(newState, prevState);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Listener error: %{public}s', String(error));
      }
    }
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
