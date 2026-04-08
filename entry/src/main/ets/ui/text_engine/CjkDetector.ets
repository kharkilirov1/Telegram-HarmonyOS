// CjkDetector — CJK code point detection + kinsoku (line-break prohibition) tables.
// Ported 1:1 from Pretext (chenglou/pretext) analysis.ts.

/**
 * Check if a Unicode code point is CJK (Chinese/Japanese/Korean).
 * Covers CJK Unified Ideographs, all extensions (A-I), Compatibility,
 * Hiragana, Katakana, Hangul, CJK Symbols, Halfwidth/Fullwidth forms.
 */
export function isCJKCodePoint(cp: number): boolean {
  return (
    (cp >= 0x4E00 && cp <= 0x9FFF) ||
    (cp >= 0x3400 && cp <= 0x4DBF) ||
    (cp >= 0x20000 && cp <= 0x2A6DF) ||
    (cp >= 0x2A700 && cp <= 0x2B73F) ||
    (cp >= 0x2B740 && cp <= 0x2B81F) ||
    (cp >= 0x2B820 && cp <= 0x2CEAF) ||
    (cp >= 0x2CEB0 && cp <= 0x2EBEF) ||
    (cp >= 0x2EBF0 && cp <= 0x2EE5D) ||
    (cp >= 0x2F800 && cp <= 0x2FA1F) ||
    (cp >= 0x30000 && cp <= 0x3134F) ||
    (cp >= 0x31350 && cp <= 0x323AF) ||
    (cp >= 0x323B0 && cp <= 0x33479) ||
    (cp >= 0xF900 && cp <= 0xFAFF) ||
    (cp >= 0x3000 && cp <= 0x303F) ||
    (cp >= 0x3040 && cp <= 0x309F) ||
    (cp >= 0x30A0 && cp <= 0x30FF) ||
    (cp >= 0xAC00 && cp <= 0xD7AF) ||
    (cp >= 0xFF00 && cp <= 0xFFEF)
  )
}

/**
 * Check if a string contains any CJK characters.
 * Handles surrogate pairs for characters outside the BMP.
 * Early exit optimization: code points < 0x3000 skip the full check.
 */
export function containsCJK(s: string): boolean {
  for (let i = 0; i < s.length; i++) {
    const first = s.charCodeAt(i)
    if (first < 0x3000) continue
    if (isCJKCodePoint(first)) return true
    if (first >= 0xD800 && first <= 0xDBFF && i + 1 < s.length) {
      const second = s.charCodeAt(i + 1)
      if (second >= 0xDC00 && second <= 0xDFFF) {
        const cp = ((first - 0xD800) << 10) + (second - 0xDC00) + 0x10000
        if (isCJKCodePoint(cp)) return true
        i++
      }
    }
  }
  return false
}

/**
 * Check if a single character (possibly multi-code-unit) is CJK.
 */
export function charIsCJK(ch: string): boolean {
  if (ch.length === 0) return false
  const cp = ch.codePointAt(0)
  if (cp === undefined) return false
  return isCJKCodePoint(cp)
}

// ── Kinsoku tables (Pretext analysis.ts) ──

/** Characters prohibited at line start (closing brackets, commas, etc.) */
export const kinsokuStart: Set<string> = new Set([
  '\uFF0C', '\uFF0E', '\uFF01', '\uFF1A', '\uFF1B', '\uFF1F',
  '\u3001', '\u3002', '\u30FB',
  '\uFF09', '\u3015', '\u3009', '\u300B', '\u300D', '\u300F',
  '\u3011', '\u3017', '\u3019', '\u301B',
  '\u30FC', '\u3005', '\u303B',
  '\u309D', '\u309E', '\u30FD', '\u30FE',
])

/** Characters prohibited at line end (opening brackets, quotes) */
export const kinsokuEnd: Set<string> = new Set([
  '"', '(', '[', '{',
  '\u201C', '\u2018', '\u00AB', '\u2039',
  '\uFF08', '\u3014', '\u3008', '\u300A', '\u300C', '\u300E',
  '\u3010', '\u3016', '\u3018', '\u301A',
])

/** Punctuation that sticks to the left (previous word) */
export const leftStickyPunctuation: Set<string> = new Set([
  '.', ',', '!', '?', ':', ';',
  '\u060C', '\u061B', '\u061F',
  '\u0964', '\u0965',
  '\u104A', '\u104B', '\u104C', '\u104D', '\u104F',
  ')', ']', '}', '%', '"',
  '\u201D', '\u2019', '\u00BB', '\u203A',
  '\u2026',
])

/** Punctuation that sticks forward (to next word) */
export const forwardStickyGlue: Set<string> = new Set(["'", '\u2019'])

/**
 * Check if a segment consists entirely of left-sticky punctuation.
 */
export function isLeftSticky(seg: string): boolean {
  for (let i = 0; i < seg.length; i++) {
    if (!leftStickyPunctuation.has(seg[i])) return false
  }
  return seg.length > 0
}

/**
 * Check if a segment consists entirely of forward-sticky or kinsokuEnd characters.
 */
export function isForwardSticky(seg: string): boolean {
  for (let i = 0; i < seg.length; i++) {
    if (!kinsokuEnd.has(seg[i]) && !forwardStickyGlue.has(seg[i])) return false
  }
  return seg.length > 0
}

/**
 * Check if a segment is prohibited at line start (kinsokuStart + leftSticky).
 */
export function isLineStartProhibited(seg: string): boolean {
  for (let i = 0; i < seg.length; i++) {
    if (!kinsokuStart.has(seg[i]) && !leftStickyPunctuation.has(seg[i])) return false
  }
  return seg.length > 0
}
