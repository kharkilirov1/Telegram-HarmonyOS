import { describe, it, expect } from '@ohos/hypium';

/**
 * Unit tests for FileController — LRU cache mechanism and file path management.
 * Tests the caching algorithm with standalone copies of private methods.
 */

// Standalone LRU cache implementation mirroring FileController internals
class TestLRUCache {
  private pathCache: Map<number, string> = new Map();
  private cacheOrder: number[] = [];
  private maxCacheSize: number;

  constructor(maxSize: number = 500) {
    this.maxCacheSize = maxSize;
  }

  getFilePath(fileId: number): string | null {
    const path = this.pathCache.get(fileId);
    if (path) {
      this.touchLRU(fileId);
      return path;
    }
    return null;
  }

  addToCache(fileId: number, path: string): void {
    if (this.cacheOrder.length >= this.maxCacheSize) {
      const evictId = this.cacheOrder.shift()!;
      this.pathCache.delete(evictId);
    }
    this.pathCache.set(fileId, path);
    this.cacheOrder.push(fileId);
  }

  getCacheSize(): number {
    return this.pathCache.size;
  }

  getOrderLength(): number {
    return this.cacheOrder.length;
  }

  private touchLRU(fileId: number): void {
    const idx = this.cacheOrder.indexOf(fileId);
    if (idx >= 0) {
      this.cacheOrder.splice(idx, 1);
      this.cacheOrder.push(fileId);
    }
  }

  // Expose order for testing
  getOrder(): number[] {
    return [...this.cacheOrder];
  }
}

export default function fileControllerTest() {
  describe('FileController', () => {

    // -----------------------------------------------------------------------
    // LRU cache — basic operations
    // -----------------------------------------------------------------------
    describe('LRU cache basics', () => {

      it('should return null for uncached file', 0, () => {
        const cache = new TestLRUCache();
        expect(cache.getFilePath(999)).assertEqual(null);
      });

      it('should cache and retrieve a file path', 0, () => {
        const cache = new TestLRUCache();
        cache.addToCache(1, '/data/files/photo.jpg');
        expect(cache.getFilePath(1)).assertEqual('/data/files/photo.jpg');
      });

      it('should cache multiple files', 0, () => {
        const cache = new TestLRUCache();
        cache.addToCache(1, '/path/a.jpg');
        cache.addToCache(2, '/path/b.jpg');
        cache.addToCache(3, '/path/c.jpg');

        expect(cache.getFilePath(1)).assertEqual('/path/a.jpg');
        expect(cache.getFilePath(2)).assertEqual('/path/b.jpg');
        expect(cache.getFilePath(3)).assertEqual('/path/c.jpg');
        expect(cache.getCacheSize()).assertEqual(3);
      });

      it('should overwrite existing entry with same fileId', 0, () => {
        const cache = new TestLRUCache();
        cache.addToCache(1, '/path/old.jpg');
        cache.addToCache(1, '/path/new.jpg');
        expect(cache.getFilePath(1)).assertEqual('/path/new.jpg');
      });
    });

    // -----------------------------------------------------------------------
    // LRU eviction
    // -----------------------------------------------------------------------
    describe('LRU eviction', () => {

      it('should evict oldest entry when cache is full', 0, () => {
        const cache = new TestLRUCache(3);
        cache.addToCache(1, '/path/1.jpg');
        cache.addToCache(2, '/path/2.jpg');
        cache.addToCache(3, '/path/3.jpg');
        // Cache is full, adding 4 should evict 1
        cache.addToCache(4, '/path/4.jpg');

        expect(cache.getFilePath(1)).assertEqual(null);
        expect(cache.getFilePath(2)).assertEqual('/path/2.jpg');
        expect(cache.getFilePath(3)).assertEqual('/path/3.jpg');
        expect(cache.getFilePath(4)).assertEqual('/path/4.jpg');
      });

      it('should evict multiple entries sequentially', 0, () => {
        const cache = new TestLRUCache(2);
        cache.addToCache(1, '/path/1.jpg');
        cache.addToCache(2, '/path/2.jpg');
        cache.addToCache(3, '/path/3.jpg'); // evicts 1
        cache.addToCache(4, '/path/4.jpg'); // evicts 2

        expect(cache.getFilePath(1)).assertEqual(null);
        expect(cache.getFilePath(2)).assertEqual(null);
        expect(cache.getFilePath(3)).assertEqual('/path/3.jpg');
        expect(cache.getFilePath(4)).assertEqual('/path/4.jpg');
      });

      it('should keep cache at max size after evictions', 0, () => {
        const cache = new TestLRUCache(2);
        cache.addToCache(1, '/path/1.jpg');
        cache.addToCache(2, '/path/2.jpg');
        cache.addToCache(3, '/path/3.jpg');

        expect(cache.getCacheSize()).assertEqual(2);
      });
    });

    // -----------------------------------------------------------------------
    // LRU touch (access refreshes position)
    // -----------------------------------------------------------------------
    describe('LRU touch ordering', () => {

      it('should move accessed item to end of eviction order', 0, () => {
        const cache = new TestLRUCache(3);
        cache.addToCache(1, '/path/1.jpg');
        cache.addToCache(2, '/path/2.jpg');
        cache.addToCache(3, '/path/3.jpg');

        // Access file 1 — it should move to the back
        cache.getFilePath(1);

        const order = cache.getOrder();
        expect(order[0]).assertEqual(2);
        expect(order[1]).assertEqual(3);
        expect(order[2]).assertEqual(1);
      });

      it('should evict least-recently-used after touch', 0, () => {
        const cache = new TestLRUCache(3);
        cache.addToCache(1, '/path/1.jpg');
        cache.addToCache(2, '/path/2.jpg');
        cache.addToCache(3, '/path/3.jpg');

        // Touch file 1, making file 2 the LRU
        cache.getFilePath(1);

        // Adding 4 should now evict 2 (the LRU), not 1
        cache.addToCache(4, '/path/4.jpg');
        expect(cache.getFilePath(1)).assertEqual('/path/1.jpg');
        expect(cache.getFilePath(2)).assertEqual(null);
        expect(cache.getFilePath(3)).assertEqual('/path/3.jpg');
        expect(cache.getFilePath(4)).assertEqual('/path/4.jpg');
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------
    describe('edge cases', () => {

      it('should handle cache size of 1', 0, () => {
        const cache = new TestLRUCache(1);
        cache.addToCache(1, '/path/1.jpg');
        expect(cache.getFilePath(1)).assertEqual('/path/1.jpg');

        cache.addToCache(2, '/path/2.jpg');
        expect(cache.getFilePath(1)).assertEqual(null);
        expect(cache.getFilePath(2)).assertEqual('/path/2.jpg');
      });

      it('should handle empty paths', 0, () => {
        const cache = new TestLRUCache();
        cache.addToCache(1, '');
        // Empty string is falsy but still a valid cached value
        expect(cache.getCacheSize()).assertEqual(1);
      });
    });
  });
}
