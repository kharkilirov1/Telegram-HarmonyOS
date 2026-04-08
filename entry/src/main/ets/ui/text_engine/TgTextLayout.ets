// TgTextLayout — Public facade for the text layout engine.
// Two-phase API: prepare(text, style) → layout(prepared, maxWidth)
//
// Usage:
//   const engine = TgTextLayout.getInstance(uiContext)
//   const prepared = engine.prepare("Hello World!", style)
//   const result = engine.layout(prepared, 280) // ~0.02ms
//   console.log(result.height, result.lineCount, result.lastLineWidth)

import { TextStyleKey, PreparedText, LayoutResult, SegmentBreakKind, buildStyleKey } from './TextTypes'
import { TokenizeResult, tokenizeWithChunks, isSimplePath, normalizeWhitespace } from './Segmenter'
import { measureSegments, clearMeasureCache, getMeasureCacheStats, MeasureCacheStats } from './TextMeasurer'
import { layoutLines } from './LineBreaker'
import {
  getCachedPrepared, cachePrepared,
  getCachedLayout, cacheLayout,
  clearLayoutCaches, getLayoutCacheStats, LayoutCacheStats
} from './LayoutCache'

/**
 * TgTextLayout — the main entry point for text measurement and layout.
 *
 * Lifecycle:
 *   - Get instance via TgTextLayout.getInstance(uiContext) in component context
 *   - prepare() is called once per unique (text, style) pair
 *   - layout() is called for each width — pure arithmetic, cached
 *   - Call resetOnRuntimeShutdown() in AppCoreRuntime teardown
 */
export class TgTextLayout {
  private uiContext: UIContext

  private constructor(uiContext: UIContext) {
    this.uiContext = uiContext
  }

  // ── Singleton per UIContext ──

  private static instance: TgTextLayout | null = null

  /**
   * Get or create a TgTextLayout singleton for the given UIContext.
   * Call from component context where getUIContext() is available.
   * On multi-window: last UIContext wins (acceptable for single-window Telegram).
   */
  static getInstance(uiContext: UIContext): TgTextLayout {
    if (TgTextLayout.instance === null) {
      TgTextLayout.instance = new TgTextLayout(uiContext)
    } else {
      // Update UIContext reference (may change across ability lifecycle)
      TgTextLayout.instance.uiContext = uiContext
    }
    return TgTextLayout.instance
  }

  // ── Phase 1: prepare() ──

  /**
   * Prepare text for layout. Expensive operation (~0.5-2ms):
   * - Normalizes whitespace
   * - Tokenizes into segments (words, CJK chars, emoji, punctuation, spaces)
   * - Measures each segment width via MeasureUtils
   * - Caches result for future layout() calls
   *
   * @param text — raw message text
   * @param style — text style (fontSize, lineHeight, fontWeight)
   * @returns PreparedText for use with layout()
   */
  prepare(text: string, style: TextStyleKey): PreparedText {
    if (text.length === 0) {
      return this.buildEmptyPrepared(style)
    }

    const normalized = normalizeWhitespace(text)
    const styleKey = buildStyleKey(style)

    // Check cache
    const cached = getCachedPrepared(normalized, styleKey)
    if (cached !== undefined) return cached

    // Tokenize
    const tokenResult: TokenizeResult = tokenizeWithChunks(normalized)
    const tokenSegments = tokenResult.segments
    const chunks = tokenResult.chunks

    // Extract parallel arrays (SoA layout)
    const segTexts: string[] = new Array<string>(tokenSegments.length)
    const segKinds: SegmentBreakKind[] = new Array<SegmentBreakKind>(tokenSegments.length)
    const segWordLike: boolean[] = new Array<boolean>(tokenSegments.length)

    for (let i = 0; i < tokenSegments.length; i++) {
      segTexts[i] = tokenSegments[i].text
      segKinds[i] = tokenSegments[i].kind
      segWordLike[i] = tokenSegments[i].isWordLike
    }

    // Measure widths
    const widths = measureSegments(this.uiContext, segTexts, style)

    // Compute total width
    let totalWidth = 0
    for (let i = 0; i < widths.length; i++) {
      totalWidth += widths[i]
    }

    const prepared: PreparedText = {
      text: normalized,
      styleKey,
      segments: segTexts,
      widths,
      kinds: segKinds,
      isWordLike: segWordLike,
      totalWidth,
      chunks,
      lineHeight: style.lineHeight,
      hasSimplePath: isSimplePath(tokenSegments),
    }

    cachePrepared(normalized, styleKey, prepared)
    return prepared
  }

  // ── Phase 2: layout() ──

  /**
   * Layout prepared text for a given max width. Fast operation (~0.02ms):
   * - Pure arithmetic — no API calls
   * - Returns line count, height, per-line info, last line width
   * - Cached by (text, style, maxWidth) triple
   *
   * @param prepared — result of prepare()
   * @param maxWidth — maximum line width in vp
   * @returns LayoutResult with height, lineCount, lines, lastLineWidth
   */
  layout(prepared: PreparedText, maxWidth: number): LayoutResult {
    // Check cache
    const cached = getCachedLayout(prepared.text, prepared.styleKey, maxWidth)
    if (cached !== undefined) return cached

    const result = layoutLines(prepared, maxWidth)

    cacheLayout(prepared.text, prepared.styleKey, maxWidth, result)
    return result
  }

  // ── Convenience methods ──

  /**
   * One-shot: prepare + layout in one call.
   * Use when you don't need to re-layout at different widths.
   */
  measureText(text: string, style: TextStyleKey, maxWidth: number): LayoutResult {
    const prepared = this.prepare(text, style)
    return this.layout(prepared, maxWidth)
  }

  /**
   * Quick height measurement — prepare + layout, return only height.
   */
  measureTextHeight(text: string, style: TextStyleKey, maxWidth: number): number {
    const prepared = this.prepare(text, style)
    return this.layout(prepared, maxWidth).height
  }

  /**
   * Get last line width — for inline meta (time + status) placement.
   * Returns the width of the last line content. If meta fits on the same line,
   * no extra line is needed.
   */
  getLastLineWidth(text: string, style: TextStyleKey, maxWidth: number): number {
    const prepared = this.prepare(text, style)
    return this.layout(prepared, maxWidth).lastLineWidth
  }

  /**
   * Check if inline meta fits on the last line.
   * @param metaWidth — width of the meta element (time + status) in vp
   * @param metaPadding — minimum gap between text and meta in vp
   */
  metaFitsInline(text: string, style: TextStyleKey, maxWidth: number, metaWidth: number, metaPadding: number = 4): boolean {
    const lastLineW = this.getLastLineWidth(text, style, maxWidth)
    return (lastLineW + metaPadding + metaWidth) <= maxWidth
  }

  // ── Internal ──

  private buildEmptyPrepared(style: TextStyleKey): PreparedText {
    return {
      text: '',
      styleKey: buildStyleKey(style),
      segments: [],
      widths: [],
      kinds: [],
      isWordLike: [],
      totalWidth: 0,
      chunks: [{ startIndex: 0, endIndex: 0 }],
      lineHeight: style.lineHeight,
      hasSimplePath: true,
    }
  }

  // ── Cache management ──

  /**
   * Clear all caches. Call on runtime reset or memory pressure.
   */
  static resetOnRuntimeShutdown(): void {
    clearLayoutCaches()
    clearMeasureCache()
    TgTextLayout.instance = null
  }

  /**
   * Get combined cache statistics for debugging.
   */
  static getMeasureCacheStats(): MeasureCacheStats {
    return getMeasureCacheStats()
  }

  static getLayoutCacheStats(): LayoutCacheStats {
    return getLayoutCacheStats()
  }
}
