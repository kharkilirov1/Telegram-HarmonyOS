// I6: one story's full content for the viewer. TDLib answers with a story object; the normalizer parses
// it into the store, so the viewer reads a DTO instead of TDLib shapes.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createGetStoryCommand } from '../../core/model/AppCommand';
import { getEventNormalizer } from '../../core/events/EventNormalizer';
import { AppStore } from '../../core/store/AppStore';
import { StoryFullDto, storyContentKey } from '../../core/model/dto/StoryDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0006;
const TAG = 'LoadStory';

export class LoadStoryUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private inFlightKeys: Set<string> = new Set<string>();

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  cached(posterChatId: number, storyId: number): StoryFullDto | undefined {
    return this.store.getState().chats.storyContentsByKey.get(storyContentKey(posterChatId, storyId));
  }

  isInFlight(posterChatId: number, storyId: number): boolean {
    return this.inFlightKeys.has(storyContentKey(posterChatId, storyId));
  }

  // Returns the parsed story, or undefined when TDLib could not provide it. The store is updated too,
  // so the viewer keeps the content when it re-opens.
  async execute(posterChatId: number, storyId: number): Promise<StoryFullDto | undefined> {
    if (posterChatId === 0 || storyId <= 0) {
      return undefined;
    }
    const cached = this.cached(posterChatId, storyId);
    if (cached !== undefined) {
      return cached;
    }
    const key = storyContentKey(posterChatId, storyId);
    if (this.inFlightKeys.has(key)) {
      return undefined;
    }
    this.inFlightKeys.add(key);
    try {
      const response = await this.gateway.send(createGetStoryCommand(posterChatId, storyId));
      const story = response as TdObject;
      if (!(story instanceof TdObject)) {
        return undefined;
      }
      const events = getEventNormalizer().normalize(story);
      if (events.length > 0) {
        await this.store.dispatchBatch(events);
      }
      return this.cached(posterChatId, storyId);
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Unable to load story %{public}d: %{public}s', storyId, String(error));
      return undefined;
    } finally {
      this.inFlightKeys.delete(key);
    }
  }
}

export function createLoadStoryUseCase(store: AppStore, gateway: TdGatewayPort): LoadStoryUseCase {
  return new LoadStoryUseCase(store, gateway);
}
