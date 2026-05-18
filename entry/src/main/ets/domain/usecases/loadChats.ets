// LoadChats use case - loads chat list from TDLib
// Business logic for loading and paginating chats

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { createLoadChatsCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { ChatsLoadPhase } from '../../core/model/AppState';
import { createChatsLoadStateChangedEvent } from '../../core/model/AppEvent';
import { selectHasMoreChats, selectIsChatsLoading } from '../selectors/chatSelectors';

const TAG = 'LoadChats';
const DOMAIN = 0x0006;
const CHAT_GROWTH_WAIT_TIMEOUT_MS = 1800;
const NO_PROGRESS_COOLDOWN_MS = 1500;

export class LoadChatsUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private cooldownUntilMs: number = 0;
  private isActive: boolean = true;
  private lifecycleToken: number = 0;
  private waitCancelers: (() => void)[] = [];

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  cancel(): void {
    if (!this.isActive) {
      return;
    }
    this.isActive = false;
    this.lifecycleToken++;
    this.cooldownUntilMs = 0;

    const cancelers: (() => void)[] = this.waitCancelers.slice();
    this.waitCancelers = [];
    cancelers.forEach((cancelWait: () => void): void => {
      cancelWait();
    });
  }

  private isCurrentRun(token: number): boolean {
    return this.isActive && token === this.lifecycleToken;
  }

  private async waitForChatCountGrowth(baselineCount: number, token: number): Promise<number> {
    if (!this.isCurrentRun(token)) {
      return baselineCount;
    }

    return new Promise<number>((resolve: (value: number) => void) => {
      let settled: boolean = false;
      let unsubscribe: (() => void) | undefined = undefined;
      let timerId: number = -1;
      let cancelWait: (() => void) | undefined = undefined;

      const finish = (count: number): void => {
        if (settled) {
          return;
        }
        settled = true;
        if (cancelWait !== undefined) {
          const cancelIndex: number = this.waitCancelers.indexOf(cancelWait);
          if (cancelIndex >= 0) {
            this.waitCancelers.splice(cancelIndex, 1);
          }
          cancelWait = undefined;
        }
        if (unsubscribe !== undefined) {
          unsubscribe();
          unsubscribe = undefined;
        }
        if (timerId !== -1) {
          clearTimeout(timerId);
          timerId = -1;
        }
        resolve(count);
      };

      cancelWait = (): void => {
        finish(this.store.getState().chats.orderedChatIds.length);
      };
      this.waitCancelers.push(cancelWait);

      unsubscribe = this.store.subscribe((newState, prevState) => {
        if (!this.isCurrentRun(token)) {
          finish(newState.chats.orderedChatIds.length);
          return;
        }
        if (newState.chats === prevState.chats) {
          return;
        }
        const nextCount = newState.chats.orderedChatIds.length;
        if (nextCount > baselineCount) {
          finish(nextCount);
        }
      });

      timerId = setTimeout(() => {
        finish(this.store.getState().chats.orderedChatIds.length);
      }, CHAT_GROWTH_WAIT_TIMEOUT_MS) as number;

      if (!this.isCurrentRun(token)) {
        finish(this.store.getState().chats.orderedChatIds.length);
        return;
      }

      const immediateCount = this.store.getState().chats.orderedChatIds.length;
      if (immediateCount > baselineCount) {
        finish(immediateCount);
      }
    });
  }

  // Main entry point - loads initial or more chats
  async execute(limit: number = 20, phase: ChatsLoadPhase = 'pagination'): Promise<void> {
    const token: number = this.lifecycleToken;
    if (!this.isCurrentRun(token)) {
      return;
    }

    if (selectIsChatsLoading(this.store.getState())) {
      hilog.info(DOMAIN, TAG, 'Already loading, skipping');
      return;
    }

    // Check if we have more chats to load (from store state)
    const state = this.store.getState();
    if (!selectHasMoreChats(state)) {
      hilog.info(DOMAIN, TAG, 'No more chats to load');
      return;
    }
    if (Date.now() < this.cooldownUntilMs) {
      hilog.info(DOMAIN, TAG, 'LoadChats cooldown active, skipping');
      return;
    }

    let nextHasMore: boolean = state.chats.hasMore;
    try {
      await this.store.dispatch(createChatsLoadStateChangedEvent(true, nextHasMore, phase));
      if (!this.isCurrentRun(token)) {
        return;
      }
      const baselineCount = state.chats.orderedChatIds.length;
      hilog.info(DOMAIN, TAG, 'Loading chats, limit: %{public}d', limit);

      // Send loadChats command to TDLib
      const command = createLoadChatsCommand(limit);
      await this.gateway.send(command);
      if (!this.isCurrentRun(token)) {
        return;
      }

      hilog.info(DOMAIN, TAG, 'Chats load command sent');
      const observedCount = await this.waitForChatCountGrowth(baselineCount, token);
      if (!this.isCurrentRun(token)) {
        return;
      }
      if (observedCount > baselineCount) {
        this.cooldownUntilMs = 0;
        hilog.info(DOMAIN, TAG, 'Chats list grew by %{public}d', observedCount - baselineCount);
      } else {
        this.cooldownUntilMs = Date.now() + NO_PROGRESS_COOLDOWN_MS;
        hilog.info(DOMAIN, TAG, 'No chat growth observed after loadChats, entering cooldown');
      }

    } catch (error) {
      if (!this.isCurrentRun(token)) {
        return;
      }
      const err = error as AppError;
      if (err.tdlibCode === 404) {
        nextHasMore = false;
        this.cooldownUntilMs = 0;
        hilog.info(DOMAIN, TAG, 'Reached end of dialogs list (TDLib 404)');
        return;
      }
      hilog.error(DOMAIN, TAG, 'Failed to load chats: %{public}s', err.message);

      throw new AppError(
        err.kind || AppErrorKind.NETWORK,
        'Failed to load chats',
        err.message,
        err.tdlibCode || 0,
        err.retryable !== false
      );
    } finally {
      if (!this.isCurrentRun(token)) {
        return;
      }
      await this.store.dispatch(createChatsLoadStateChangedEvent(false, nextHasMore, 'idle'));
    }
  }

  async warmup(): Promise<void> {
    return this.execute(60, 'bootstrap');
  }

  // Load initial chats (first page)
  async loadInitial(): Promise<void> {
    return this.execute(50, 'bootstrap'); // Larger limit for initial load
  }

  // Load more chats (pagination)
  async loadMore(): Promise<void> {
    return this.execute(20, 'pagination');
  }

  // Check if loading
  isLoadingInProgress(): boolean {
    if (!this.isActive) {
      return false;
    }
    return selectIsChatsLoading(this.store.getState());
  }

  hasMoreChats(): boolean {
    if (!this.isActive) {
      return false;
    }
    return selectHasMoreChats(this.store.getState());
  }

  // Refresh chats (reload)
  async refresh(): Promise<void> {
    const token: number = this.lifecycleToken;
    if (!this.isCurrentRun(token)) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'Refreshing chats');
    this.cooldownUntilMs = 0;
    await this.store.dispatch(createChatsLoadStateChangedEvent(false, true, 'idle'));
    if (!this.isCurrentRun(token)) {
      return;
    }
    return this.loadInitial();
  }
}

// Factory function
export function createLoadChatsUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): LoadChatsUseCase {
  if (loadChatsUseCaseInstance === null) {
    loadChatsUseCaseInstance = new LoadChatsUseCase(store, gateway);
  }
  return loadChatsUseCaseInstance;
}

let loadChatsUseCaseInstance: LoadChatsUseCase | null = null;

export function resetLoadChatsUseCase(): void {
  if (loadChatsUseCaseInstance !== null) {
    loadChatsUseCaseInstance.cancel();
  }
  loadChatsUseCaseInstance = null;
}
