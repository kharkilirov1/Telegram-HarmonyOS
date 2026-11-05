// D16: prefetch loop for message custom emoji. Collects ids from message entities, resolves them through
// the resolver and fills the process-wide path cache that the pure row builder reads.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TextEntity } from '../../core/model/AppState';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { CustomEmojiResolverUseCase, createCustomEmojiResolverUseCase } from './customEmojiResolver';
import { customEmojiPathCache } from './customEmojiPathCache';

const DOMAIN = 0x00D2;
const TAG = 'CustomEmojiPrefetch';

export const CUSTOM_EMOJI_PREFETCH_LIMIT = 64;

// Ids used by the given entities, in first-seen order, without ids already resolved.
export function collectPendingCustomEmojiIds(entityLists: TextEntity[][]): string[] {
  const ids: string[] = [];
  for (const entities of entityLists) {
    for (const entity of entities) {
      if (entity.type !== 'customEmoji') {
        continue;
      }
      const id = entity.customEmojiId;
      if (id.length === 0 || id === '0' || customEmojiPathCache.hasPath(id) || ids.includes(id)) {
        continue;
      }
      ids.push(id);
      if (ids.length >= CUSTOM_EMOJI_PREFETCH_LIMIT) {
        return ids;
      }
    }
  }
  return ids;
}

export class CustomEmojiPrefetchCoordinator {
  private gateway: TdGatewayPort;
  private resolver?: CustomEmojiResolverUseCase;
  private inFlight: Set<string> = new Set<string>();

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  private useCase(): CustomEmojiResolverUseCase {
    if (this.resolver === undefined) {
      this.resolver = createCustomEmojiResolverUseCase(this.gateway);
    }
    return this.resolver;
  }

  // Resolves the entity ids that have no file yet and caches their URIs. Returns how many were filled.
  async prefetch(entityLists: TextEntity[][]): Promise<number> {
    const requested = collectPendingCustomEmojiIds(entityLists);
    const ids = requested.filter((id) => !this.inFlight.has(id));
    if (ids.length === 0) {
      return 0;
    }
    for (const id of ids) {
      this.inFlight.add(id);
    }
    let filled = 0;
    try {
      const resolved = await this.useCase().resolve(ids);
      for (const [id, sticker] of resolved) {
        const path = sticker.localPath.length > 0 ? sticker.localPath : sticker.thumbnailPath;
        if (path.length === 0) {
          continue;
        }
        customEmojiPathCache.setPath(id, path);
        filled += 1;
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Prefetch failed: %{public}s', String(error));
    } finally {
      for (const id of ids) {
        this.inFlight.delete(id);
      }
    }
    return filled;
  }

  // A file update means the cached URI may now exist.
  invalidate(customEmojiId: string): void {
    customEmojiPathCache.clear();
    this.resolver?.invalidate(customEmojiId);
  }
}
