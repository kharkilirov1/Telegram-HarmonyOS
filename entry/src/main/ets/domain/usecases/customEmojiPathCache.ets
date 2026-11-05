// D16: one process-wide map of resolved custom emoji files. The timeline row builder is pure and
// synchronous, so it reads this cache while the resolver prefetches asynchronously in the background.

import { fileUri } from '@kit.CoreFileKit';

class CustomEmojiPathCacheStore {
  private paths: Map<string, string> = new Map<string, string>();

  // Accepts a plain path or an already-formed URI and stores a URI the ImageSpan can consume.
  setPath(customEmojiId: string, path: string): void {
    if (customEmojiId.length === 0 || customEmojiId === '0' || path.length === 0) {
      return;
    }
    this.paths.set(customEmojiId, path.startsWith('file://') ? path : fileUri.getUriFromPath(path));
  }

  getPath(customEmojiId: string): string {
    const path = this.paths.get(customEmojiId);
    return path !== undefined ? path : '';
  }

  hasPath(customEmojiId: string): boolean {
    return this.paths.has(customEmojiId);
  }

  clear(): void {
    this.paths.clear();
  }

  size(): number {
    return this.paths.size;
  }
}

export const customEmojiPathCache: CustomEmojiPathCacheStore = new CustomEmojiPathCacheStore();
