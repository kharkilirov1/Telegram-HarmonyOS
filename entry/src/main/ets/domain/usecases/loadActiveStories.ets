// Loads the TDLib main story list and hydrates story-poster chats for UI avatars.

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  createGetChatCommand,
  createLoadActiveStoriesCommand
} from '../../core/model/AppCommand';
import { getEventNormalizer } from '../../core/events/EventNormalizer';
import { AppStore } from '../../core/store/AppStore';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0006;
const TAG = 'LoadActiveStories';

export class LoadActiveStoriesUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private loading: boolean = false;
  private inFlightChatIds: Set<number> = new Set<number>();

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  isLoadingInProgress(): boolean {
    return this.loading;
  }

  async execute(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      await this.gateway.send(createLoadActiveStoriesCommand());
    } finally {
      this.loading = false;
    }
  }

  async hydrateChatsIfMissing(chatIds: number[]): Promise<void> {
    for (const chatId of chatIds) {
      if (chatId === 0 || this.store.getState().chats.chats.has(chatId) || this.inFlightChatIds.has(chatId)) {
        continue;
      }
      this.inFlightChatIds.add(chatId);
      try {
        const response = await this.gateway.send(createGetChatCommand(chatId));
        const normalized = response as TdObject;
        if (!(normalized instanceof TdObject)) {
          continue;
        }
        const events = getEventNormalizer().normalize(normalized);
        if (events.length > 0) {
          await this.store.dispatchBatch(events);
        }
      } catch (error) {
        hilog.info(DOMAIN, TAG, 'Unable to hydrate story chat %{public}d: %{public}s', chatId, String(error));
      } finally {
        this.inFlightChatIds.delete(chatId);
      }
    }
  }
}

export function createLoadActiveStoriesUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): LoadActiveStoriesUseCase {
  return new LoadActiveStoriesUseCase(store, gateway);
}
