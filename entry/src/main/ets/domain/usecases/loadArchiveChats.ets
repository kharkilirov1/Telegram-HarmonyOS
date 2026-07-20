// Loads the TDLib archive list. Position updates are normalized into the shared
// chat store, but kept separate from chatListMain by ChatsState.archivedChatIds.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createLoadChatsCommand } from '../../core/model/AppCommand';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0006;
const TAG = 'LoadArchiveChats';
const ARCHIVE_GROWTH_WAIT_TIMEOUT_MS = 1800;

export class LoadArchiveChatsUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  private async waitForArchiveGrowth(baselineCount: number): Promise<number> {
    return new Promise<number>((resolve: (count: number) => void) => {
      let settled: boolean = false;
      let unsubscribe: (() => void) | undefined = undefined;
      let timerId: number = -1;
      const finish = (count: number): void => {
        if (settled) {
          return;
        }
        settled = true;
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

      unsubscribe = this.store.subscribe((newState, prevState) => {
        if (newState.chats === prevState.chats) {
          return;
        }
        const nextCount = newState.chats.archivedChatIds.length;
        if (nextCount > baselineCount) {
          finish(nextCount);
        }
      });
      timerId = setTimeout(() => {
        finish(this.store.getState().chats.archivedChatIds.length);
      }, ARCHIVE_GROWTH_WAIT_TIMEOUT_MS) as number;

      const immediateCount = this.store.getState().chats.archivedChatIds.length;
      if (immediateCount > baselineCount) {
        finish(immediateCount);
      }
    });
  }

  async execute(limit: number = 50): Promise<number> {
    const safeLimit = Math.max(1, Math.min(100, Math.floor(limit)));
    const baselineCount = this.store.getState().chats.archivedChatIds.length;
    hilog.info(DOMAIN, TAG, 'Loading archive chats, limit: %{public}d', safeLimit);
    await this.gateway.send(createLoadChatsCommand(safeLimit, 'archive'));
    const observedCount = await this.waitForArchiveGrowth(baselineCount);
    hilog.info(DOMAIN, TAG, 'Archive load settled at %{public}d chats', observedCount);
    return observedCount;
  }
}

export function createLoadArchiveChatsUseCase(store: AppStore, gateway: TdGatewayPort): LoadArchiveChatsUseCase {
  return new LoadArchiveChatsUseCase(store, gateway);
}
