// LoadDialogs use case - loads chat list from TDLib
// Business logic for loading and paginating dialogs

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { createLoadChatsCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { selectHasMoreDialogs } from '../selectors/dialogSelectors';

const TAG = 'LoadDialogs';
const DOMAIN = 0x0006;

export class LoadDialogsUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private isLoading: boolean = false;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  // Main entry point - loads initial or more dialogs
  async execute(limit: number = 20): Promise<void> {
    if (this.isLoading) {
      hilog.info(DOMAIN, TAG, 'Already loading, skipping');
      return;
    }

    // Check if we have more dialogs to load (from store state)
    const state = this.store.getState();
    if (!selectHasMoreDialogs(state)) {
      hilog.info(DOMAIN, TAG, 'No more dialogs to load');
      return;
    }

    try {
      this.isLoading = true;
      hilog.info(DOMAIN, TAG, 'Loading dialogs, limit: %{public}d', limit);

      // Send loadChats command to TDLib
      const command = createLoadChatsCommand(limit);
      const response = await this.gateway.send(command);

      hilog.info(DOMAIN, TAG, 'Dialogs load command sent');

      // Note: Actual chats will come via updateNewChat events
      // This use case just triggers the loading

    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to load dialogs: %{public}s', err.message);

      throw new AppError(
        AppErrorKind.NETWORK,
        'Failed to load dialogs',
        err.message,
        0,
        true
      );
    } finally {
      this.isLoading = false;
    }
  }

  // Load initial dialogs (first page)
  async loadInitial(): Promise<void> {
    return this.execute(50); // Larger limit for initial load
  }

  // Load more dialogs (pagination)
  async loadMore(): Promise<void> {
    return this.execute(20);
  }

  // Check if loading
  isLoadingInProgress(): boolean {
    return this.isLoading;
  }

  // Refresh dialogs (reload)
  async refresh(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Refreshing dialogs');
    return this.loadInitial();
  }
}

// Factory function
export function createLoadDialogsUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): LoadDialogsUseCase {
  return new LoadDialogsUseCase(store, gateway);
}
