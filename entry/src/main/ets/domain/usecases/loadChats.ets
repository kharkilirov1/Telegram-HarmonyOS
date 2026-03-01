// LoadChats use case - loads chat list from TDLib
// Business logic for loading and paginating chats

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { createLoadChatsCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { selectHasMoreChats } from '../selectors/chatSelectors';

const TAG = 'LoadChats';
const DOMAIN = 0x0006;

export class LoadChatsUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private isLoading: boolean = false;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  // Main entry point - loads initial or more chats
  async execute(limit: number = 20): Promise<void> {
    if (this.isLoading) {
      hilog.info(DOMAIN, TAG, 'Already loading, skipping');
      return;
    }

    // Check if we have more chats to load (from store state)
    const state = this.store.getState();
    if (!selectHasMoreChats(state)) {
      hilog.info(DOMAIN, TAG, 'No more chats to load');
      return;
    }

    try {
      this.isLoading = true;
      hilog.info(DOMAIN, TAG, 'Loading chats, limit: %{public}d', limit);

      // Send loadChats command to TDLib
      const command = createLoadChatsCommand(limit);
      const response = await this.gateway.send(command);

      hilog.info(DOMAIN, TAG, 'Chats load command sent');

      // Note: Actual chats will come via updateNewChat events
      // This use case just triggers the loading

    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to load chats: %{public}s', err.message);

      throw new AppError(
        AppErrorKind.NETWORK,
        'Failed to load chats',
        err.message,
        0,
        true
      );
    } finally {
      this.isLoading = false;
    }
  }

  // Load initial chats (first page)
  async loadInitial(): Promise<void> {
    return this.execute(50); // Larger limit for initial load
  }

  // Load more chats (pagination)
  async loadMore(): Promise<void> {
    return this.execute(20);
  }

  // Check if loading
  isLoadingInProgress(): boolean {
    return this.isLoading;
  }

  // Refresh chats (reload)
  async refresh(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Refreshing chats');
    return this.loadInitial();
  }
}

// Factory function
export function createLoadChatsUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): LoadChatsUseCase {
  return new LoadChatsUseCase(store, gateway);
}
