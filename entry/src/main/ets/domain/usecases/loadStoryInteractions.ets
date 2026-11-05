// I6: the viewers list of an owned story. TDLib pages with an opaque offset, so the use case keeps the
// cursor and refuses to fall back to the first page when a caller asks for the next one.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createGetStoryInteractionsCommand, GetStoryInteractionsPayload } from '../../core/model/AppCommand';
import { parseStoryInteractions } from '../../core/events/normalizers/StoryNormalizer';
import { StoryInteractionsPageDto } from '../../core/model/dto/StoryDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00B6;
const TAG = 'LoadStoryInteractions';
export const STORY_INTERACTIONS_PAGE_SIZE = 20;

export class LoadStoryInteractionsUseCase {
  private gateway: TdGatewayPort;
  private loading: boolean = false;
  private offsets: Map<number, string> = new Map<number, string>();
  private exhausted: Set<number> = new Set<number>();

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  isLoading(): boolean {
    return this.loading;
  }

  hasMore(storyId: number): boolean {
    return !this.exhausted.has(storyId);
  }

  reset(storyId: number): void {
    this.offsets.delete(storyId);
    this.exhausted.delete(storyId);
  }

  // Returns an empty page when the query fails, so the screen shows its empty state instead of hanging.
  async load(storyId: number, limit: number = STORY_INTERACTIONS_PAGE_SIZE,
    searchQuery: string = ''): Promise<StoryInteractionsPageDto> {
    const empty = new StoryInteractionsPageDto();
    if (storyId <= 0 || this.loading || this.exhausted.has(storyId)) {
      return empty;
    }
    this.loading = true;
    try {
      const payload = new GetStoryInteractionsPayload();
      payload.storyId = storyId;
      payload.query = searchQuery;
      payload.offset = this.offsets.get(storyId) !== undefined ? this.offsets.get(storyId) as string : '';
      payload.limit = limit;
      const response = await this.gateway.send(createGetStoryInteractionsCommand(payload)) as TdObject;
      if (!(response instanceof TdObject)) {
        return empty;
      }
      const page = parseStoryInteractions(response);
      if (page.nextOffset.length === 0) {
        this.exhausted.add(storyId);
      } else {
        this.offsets.set(storyId, page.nextOffset);
      }
      return page;
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Story interactions settled with an error: %{public}s', String(error));
      return empty;
    } finally {
      this.loading = false;
    }
  }
}

export function createLoadStoryInteractionsUseCase(
  gateway: TdGatewayPort): LoadStoryInteractionsUseCase {
  return new LoadStoryInteractionsUseCase(gateway);
}
