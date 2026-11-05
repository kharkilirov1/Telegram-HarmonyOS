// D16: custom emoji reactions inside the reaction picker. The picker already receives opaque keys
// (`emoji:👍` / `custom:<id>`); this module keeps the resolved files for the custom ones so the atom can
// draw an image instead of the fallback glyph, and prefetches them when the picker opens.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TextEntity } from '../../../core/model/AppState';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { CustomEmojiPrefetchCoordinator } from '../../../domain/usecases/customEmojiPrefetch';
import { customEmojiPathCache } from '../../../domain/usecases/customEmojiPathCache';

const DOMAIN = 0x00D4;
const TAG = 'ReactionPickerEmoji';

export const REACTION_KEY_CUSTOM_PREFIX = 'custom:';

// Ids of the custom reactions in a picker key list, in first-seen order.
export function customReactionIds(keys: string[]): string[] {
  const ids: string[] = [];
  for (const key of keys) {
    if (!key.startsWith(REACTION_KEY_CUSTOM_PREFIX)) {
      continue;
    }
    const id = key.substring(REACTION_KEY_CUSTOM_PREFIX.length);
    if (id.length === 0 || id === '0' || ids.includes(id)) {
      continue;
    }
    ids.push(id);
  }
  return ids;
}

// Observed so the picker re-renders when a file lands; a plain Map would change silently.
@ObservedV2
export class ReactionPickerEmojiState {
  @Trace paths: Map<string, string> = new Map<string, string>();
  @Trace revision: number = 0;

  pathFor(key: string): string {
    const path = this.paths.get(key);
    return path !== undefined ? path : '';
  }
}

export const reactionPickerEmojiState: ReactionPickerEmojiState = new ReactionPickerEmojiState();

let prefetchCoordinator: CustomEmojiPrefetchCoordinator | undefined;
let inFlight: Set<string> = new Set<string>();

function coordinator(): CustomEmojiPrefetchCoordinator {
  if (prefetchCoordinator === undefined) {
    prefetchCoordinator = new CustomEmojiPrefetchCoordinator(getTdGatewayAdapter());
  }
  return prefetchCoordinator;
}

// Resolves the custom reactions that have no file yet; returns how many were filled.
export async function prefetchReactionPickerEmoji(keys: string[]): Promise<number> {
  const ids = customReactionIds(keys).filter((id: string) => !inFlight.has(id) &&
    customEmojiPathCache.getPath(id).length === 0);
  if (ids.length === 0) {
    syncPickerPaths(keys);
    return 0;
  }
  for (const id of ids) {
    inFlight.add(id);
  }
  try {
    const entities: TextEntity[][] = [];
    for (const id of ids) {
      const entity = new TextEntity();
      entity.type = 'customEmoji';
      entity.customEmojiId = id;
      entities.push([entity]);
    }
    const filled = await coordinator().prefetch(entities);
    syncPickerPaths(keys);
    return filled;
  } catch (error) {
    hilog.warn(DOMAIN, TAG, 'Reaction picker prefetch failed: %{public}s', String(error));
    return 0;
  } finally {
    for (const id of ids) {
      inFlight.delete(id);
    }
  }
}

// Copies the process cache into the observed picker state.
export function syncPickerPaths(keys: string[]): void {
  const next: Map<string, string> = new Map<string, string>();
  for (const key of keys) {
    const id = key.startsWith(REACTION_KEY_CUSTOM_PREFIX)
      ? key.substring(REACTION_KEY_CUSTOM_PREFIX.length)
      : '';
    if (id.length === 0) {
      continue;
    }
    const path = customEmojiPathCache.getPath(id);
    if (path.length > 0) {
      next.set(key, path);
    }
  }
  reactionPickerEmojiState.paths = next;
  reactionPickerEmojiState.revision = reactionPickerEmojiState.revision + 1;
}

export function resetReactionPickerEmojiState(): void {
  inFlight = new Set<string>();
  reactionPickerEmojiState.paths = new Map<string, string>();
  reactionPickerEmojiState.revision = 0;
}
