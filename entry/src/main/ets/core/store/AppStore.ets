// Application store with serial dispatch queue
// Single source of truth, single writer
// All state mutations go through this store

import { AppState, ReducerAction, createInitialAppState } from '../model/AppState';
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

  // A scope is an AppStore-compatible view, never another state writer/queue.
  // On the root this is the live epoch; on a view it is the captured epoch.
  private generation: number = 0;
  private scopeRoot: AppStore | null = null;
  private scopedListeners: Set<StateListener> = new Set();
  private scopeInvalidationListeners: Set<() => void> = new Set();

  // Serial dispatch queue
  private pendingPromise: Promise<void> = Promise.resolve();
  private isDispatching: boolean = false;

  constructor(reducer: Reducer, initialState?: AppState, devMode: boolean = true) {
    this.reducer = reducer;
    this.state = initialState || createInitialAppState();
    this.devMode = devMode;

    if (this.devMode) {
      assertInvariants(this.state, this.devMode);
    }
  }

  getState(): AppState {
    if (this.scopeRoot) {
      return this.isScopeCurrent() ? this.scopeRoot.getState() : createInitialAppState();
    }
    return this.state;
  }

  createScope(): AppStore {
    const scope = new AppStore(this.reducer, undefined, false);
    scope.scopeRoot = this.scopeRoot || this;
    // In particular, createScope() on a stale view must not capture a newer epoch.
    scope.generation = this.generation;
    return scope;
  }

  // Account-bound UI cleanup must distinguish a revoked scope from a valid
  // account whose chat was removed. An empty getState() is not that signal.
  isScopeCurrent(): boolean {
    return this.scopeRoot === null || this.generation === this.scopeRoot.generation;
  }

  /** Revoke account views and queued events synchronously, preserving root observers. */
  invalidateScopes(): void {
    if (this.scopeRoot) {
      if (this.isScopeCurrent()) this.scopeRoot.invalidateScopes();
      return;
    }
    this.generation++;
    // Release old account callbacks as well as suppressing their delivery.
    for (const listener of this.scopedListeners) {
      this.listeners.delete(listener);
    }
    this.scopedListeners.clear();
    // Snapshot after revocation. Registrations made by callbacks belong to the
    // new epoch; removing before delivery makes reentry and cancellation safe.
    const snapshot: (() => void)[] = Array.from(this.scopeInvalidationListeners);
    for (const listener of snapshot) {
      if (!this.scopeInvalidationListeners.delete(listener)) continue;
      listener();
    }
  }

  /** One-shot synchronous revocation observer, epoch-bound even on the root. */
  subscribeScopeInvalidation(listener: () => void): () => void {
    // A distinct wrapper gives each registration its own cancellation handle.
    const observer = (): void => {
      try {
        listener();
      } catch (error) {
        try {
          hilog.error(DOMAIN, TAG, 'Scope invalidation listener error: %{public}s', String(error));
        } catch (_) {
          // Diagnostics must not interrupt delivery to the remaining observers.
        }
      }
    };
    // Never delegate stale registration to the root: that would capture B.
    if (!this.isScopeCurrent()) {
      observer();
      return (): void => {};
    }
    const root = this.scopeRoot || this;
    root.scopeInvalidationListeners.add(observer);
    return (): void => {
      root.scopeInvalidationListeners.delete(observer);
    };
  }

  /**
   * Dispatch event через serial queue.
   * Huawei Best Practice: не выбрасывать ошибки в Promise chain,
   * чтобы не блокировать последующие dispatch'ы.
   */
  dispatch(event: AnyAppEvent, shouldProcess?: () => boolean): Promise<void> {
    if (this.scopeRoot) {
      return this.isScopeCurrent() ? this.scopeRoot.dispatch(event, shouldProcess) : Promise.resolve();
    }
    const generation = this.generation;
    this.pendingPromise = this.pendingPromise.then(() => {
      // Lifecycle may change while this event is waiting behind another batch.
      if (generation !== this.generation) return;
      if (shouldProcess && !shouldProcess()) return;
      // A caller-supplied guard may itself cross a lifecycle boundary.
      if (generation !== this.generation) return;
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
  dispatchBatch(events: AnyAppEvent[], shouldProcess?: () => boolean): Promise<void> {
    if (this.scopeRoot) {
      return this.isScopeCurrent() ? this.scopeRoot.dispatchBatch(events, shouldProcess) : Promise.resolve();
    }
    if (events.length === 0) {
      return this.pendingPromise;
    }
    if (events.length === 1) {
      return this.dispatch(events[0], shouldProcess);
    }

    const generation = this.generation;
    this.pendingPromise = this.pendingPromise.then(() => {
      if (generation !== this.generation) return;
      if (shouldProcess && !shouldProcess()) return;
      if (generation !== this.generation) return;
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
    if (this.scopeRoot) {
      if (!this.isScopeCurrent()) return (): void => {};
      const root = this.scopeRoot;
      const scopedListener: StateListener = (state: AppState, prevState: AppState): void => {
        if (this.isScopeCurrent()) listener(state, prevState);
      };
      root.scopedListeners.add(scopedListener);
      const unsubscribe = root.subscribe(scopedListener);
      return (): void => {
        root.scopedListeners.delete(scopedListener);
        unsubscribe();
      };
    }
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private notifyListeners(newState: AppState, prevState: AppState): void {
    // Snapshot — Set может измениться если listener вызовет subscribe/unsubscribe.
    // Re-check active membership so a listener removed by an earlier callback in
    // the same notification cycle does not receive a stale delivery.
    const listenersSnapshot: StateListener[] = Array.from(this.listeners);
    const generation = this.generation;
    for (const listener of listenersSnapshot) {
      // A preceding observer can reset synchronously and deliver the clear first.
      if (generation !== this.generation) break;
      if (!this.listeners.has(listener)) {
        continue;
      }
      try {
        listener(newState, prevState);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Listener error: %{public}s', String(error));
      }
    }
  }

  select<T>(selector: (state: AppState) => T): T {
    return selector(this.getState());
  }

  replaceReducer(newReducer: Reducer): void {
    if (this.scopeRoot) {
      if (this.isScopeCurrent()) this.scopeRoot.replaceReducer(newReducer);
      return;
    }
    this.reducer = newReducer;
  }

  resetState(): void {
    if (this.scopeRoot) {
      if (this.isScopeCurrent()) this.scopeRoot.resetState();
      return;
    }
    this.invalidateScopes();
    this.clearState();
  }

  /** Account barrier: revoke now, clear behind pending work on the existing queue. */
  resetStateQueued(): Promise<void> {
    if (this.scopeRoot) {
      return this.isScopeCurrent() ? this.scopeRoot.resetStateQueued() : Promise.resolve();
    }
    this.invalidateScopes();
    // Do not call resetState() here: it would revoke scopes created after enqueue.
    const reset = this.pendingPromise.then(() => { this.clearState(); });
    this.pendingPromise = reset.catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Error resetting state: %{public}s', String(error));
    });
    // The barrier caller must see a failure, while subsequent queue work can recover.
    return reset;
  }

  private clearState(): void {
    const prevState = this.state;
    this.state = createInitialAppState();
    if (this.devMode) {
      assertInvariants(this.state, this.devMode);
    }
    this.notifyListeners(this.state, prevState);
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
