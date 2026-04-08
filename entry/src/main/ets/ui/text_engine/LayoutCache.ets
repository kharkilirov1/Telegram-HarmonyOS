// LayoutCache — Two-level LRU cache for text layout results.
// Level 1: PreparedText cache (key: text + style)
// Level 2: LayoutResult cache (key: preparedKey + maxWidth)

import { PreparedText, LayoutResult } from './TextTypes'

/**
 * Simple LRU cache using Map insertion order.
 * Map preserves insertion order — oldest entries are first.
 */
class LruMap<K, V> {
  private map: Map<K, V> = new Map()
  private readonly maxSize: number

  constructor(maxSize: number) {
    this.maxSize = maxSize
  }

  get(key: K): V | undefined {
    const value = this.map.get(key)
    if (value !== undefined) {
      // Move to end (most recently used)
      this.map.delete(key)
      this.map.set(key, value)
    }
    return value
  }

  set(key: K, value: V): void {
    // If key exists, remove to refresh position
    if (this.map.has(key)) {
      this.map.delete(key)
    }
    this.map.set(key, value)

    // Evict oldest if over capacity
    if (this.map.size > this.maxSize) {
      // Map.keys().next() may not work in all ArkTS runtimes — use forEach+break
      let evicted = false
      this.map.forEach((_v: V, k: K) => {
        if (!evicted) {
          this.map.delete(k)
          evicted = true
        }
      })
    }
  }

  has(key: K): boolean {
    return this.map.has(key)
  }

  delete(key: K): boolean {
    return this.map.delete(key)
  }

  clear(): void {
    this.map.clear()
  }

  get size(): number {
    return this.map.size
  }
}

// ── Cache instances ──

const DEFAULT_PREPARED_CACHE_SIZE = 5000
const DEFAULT_LAYOUT_CACHE_SIZE = 10000

const preparedCache: LruMap<string, PreparedText> = new LruMap(DEFAULT_PREPARED_CACHE_SIZE)
const layoutCache: LruMap<string, LayoutResult> = new LruMap(DEFAULT_LAYOUT_CACHE_SIZE)

// ── Prepared text cache ──

/**
 * Build cache key for PreparedText: text content + style key.
 */
function buildPreparedKey(text: string, styleKey: string): string {
  return `${styleKey}::${text}`
}

/**
 * Get cached PreparedText or undefined.
 */
export function getCachedPrepared(text: string, styleKey: string): PreparedText | undefined {
  return preparedCache.get(buildPreparedKey(text, styleKey))
}

/**
 * Store PreparedText in cache.
 */
export function cachePrepared(text: string, styleKey: string, prepared: PreparedText): void {
  preparedCache.set(buildPreparedKey(text, styleKey), prepared)
}

// ── Layout result cache ──

/**
 * Build cache key for LayoutResult: prepared key + max width.
 * Width is rounded to 0.5vp to improve cache hit rate without visible difference.
 */
function buildLayoutKey(text: string, styleKey: string, maxWidth: number): string {
  const roundedWidth = Math.round(maxWidth * 2) / 2 // 0.5vp precision
  return `${styleKey}::${text}::${roundedWidth}`
}

/**
 * Get cached LayoutResult or undefined.
 */
export function getCachedLayout(text: string, styleKey: string, maxWidth: number): LayoutResult | undefined {
  return layoutCache.get(buildLayoutKey(text, styleKey, maxWidth))
}

/**
 * Store LayoutResult in cache.
 */
export function cacheLayout(text: string, styleKey: string, maxWidth: number, result: LayoutResult): void {
  layoutCache.set(buildLayoutKey(text, styleKey, maxWidth), result)
}

// ── Cache management ──

/**
 * Clear all caches. Call on runtime reset or memory pressure.
 */
export function clearLayoutCaches(): void {
  preparedCache.clear()
  layoutCache.clear()
}

/**
 * Get cache statistics for debugging.
 */
export class LayoutCacheStats {
  prepared: number = 0
  layout: number = 0
}

export function getLayoutCacheStats(): LayoutCacheStats {
  const stats: LayoutCacheStats = new LayoutCacheStats()
  stats.prepared = preparedCache.size
  stats.layout = layoutCache.size
  return stats
}
