// TextTypes — Core type definitions for the text layout engine.
// Ported from Pretext (chenglou/pretext) analysis.ts + layout.ts types.

/**
 * Segment break classification — determines line-break behavior.
 * Maps 1:1 to Pretext SegmentBreakKind.
 */
export type SegmentBreakKind =
  | 'text'
  | 'space'
  | 'preserved-space'
  | 'tab'
  | 'glue'            // NBSP, word joiner — non-breaking
  | 'zero-width-break'
  | 'soft-hyphen'
  | 'hard-break'

/**
 * A single text segment after tokenization.
 */
export interface TextSegment {
  text: string
  kind: SegmentBreakKind
  isWordLike: boolean
}

/**
 * Style key for text measurement — determines cache identity.
 * All sizes in fp (ArkUI convention since API 12).
 */
export interface TextStyleKey {
  fontSize: number
  lineHeight: number
  fontWeight: number | FontWeight
  fontFamily?: string        // default 'HarmonyOS Sans'
  letterSpacing?: number     // default 0
  wordBreak?: WordBreak
}

/**
 * Prepared text — result of prepare() phase.
 * Contains pre-measured segment widths for fast layout().
 * Structure-of-Arrays for cache efficiency (Pretext pattern).
 */
export interface PreparedText {
  readonly text: string
  readonly styleKey: string           // cache identity
  readonly segments: string[]         // segment text
  readonly widths: number[]           // segment width in vp
  readonly kinds: SegmentBreakKind[]  // segment break kind
  readonly isWordLike: boolean[]      // is word-like segment
  readonly totalWidth: number         // sum of all widths (single-line width)
  readonly chunks: HardBreakChunk[]   // hard-break separated chunks
  readonly lineHeight: number         // line height in vp
  readonly hasSimplePath: boolean     // fast path: no tabs, soft-hyphens, overflow-wrap
}

/**
 * Hard-break chunk — a run of segments between \n boundaries.
 */
export interface HardBreakChunk {
  startIndex: number
  endIndex: number   // exclusive
}

/**
 * Layout result — output of layout() phase.
 */
export interface LayoutResult {
  readonly lineCount: number
  readonly height: number          // total height in vp
  readonly lines: LayoutLine[]
  readonly maxLineWidth: number    // width of the widest line
  readonly lastLineWidth: number   // width of the last line (for inline meta placement)
}

/**
 * A single laid-out line.
 */
export interface LayoutLine {
  readonly startIndex: number      // first segment index
  readonly endIndex: number        // exclusive segment index
  readonly width: number           // line content width in vp
  readonly lineNumber: number      // 0-based
}

/**
 * Build a cache-safe style key string.
 */
export function buildStyleKey(style: TextStyleKey): string {
  const fw = typeof style.fontWeight === 'number' ? style.fontWeight : fontWeightToNumber(style.fontWeight)
  return `${style.fontSize}|${style.lineHeight}|${fw}|${style.fontFamily ?? 'HarmonyOS Sans'}|${style.letterSpacing ?? 0}`
}

function fontWeightToNumber(fw: FontWeight): number {
  switch (fw) {
    case FontWeight.Lighter: return 100
    case FontWeight.Normal: return 400
    case FontWeight.Regular: return 400
    case FontWeight.Medium: return 500
    case FontWeight.Bold: return 700
    case FontWeight.Bolder: return 900
    default: return 400
  }
}
