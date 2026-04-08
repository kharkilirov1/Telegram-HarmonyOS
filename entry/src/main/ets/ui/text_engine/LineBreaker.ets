// LineBreaker — Greedy line-break algorithm.
// Ported from Pretext (chenglou/pretext) line-break.ts.
// Pure arithmetic — no API calls, no measurement. O(n) complexity.

import { SegmentBreakKind, PreparedText, LayoutResult, LayoutLine, HardBreakChunk } from './TextTypes'

/**
 * Can this segment kind serve as a line break point?
 */
function canBreakAfter(kind: SegmentBreakKind): boolean {
  return kind === 'space' ||
    kind === 'preserved-space' ||
    kind === 'tab' ||
    kind === 'zero-width-break' ||
    kind === 'soft-hyphen'
}

/**
 * Is this segment trailing whitespace (hangs past line edge)?
 */
function isTrailingWhitespace(kind: SegmentBreakKind): boolean {
  return kind === 'space' || kind === 'preserved-space' || kind === 'tab'
}

/**
 * Layout prepared text into lines for a given max width.
 * Returns layout result with line count, total height, per-line info.
 *
 * This is the hot path — called on every width change.
 * Pure arithmetic, no API calls.
 */
export function layoutLines(prepared: PreparedText, maxWidth: number): LayoutResult {
  if (prepared.segments.length === 0) {
    return {
      lineCount: 1,
      height: prepared.lineHeight,
      lines: [{ startIndex: 0, endIndex: 0, width: 0, lineNumber: 0 }],
      maxLineWidth: 0,
      lastLineWidth: 0
    }
  }

  // Single-line fast path
  if (prepared.totalWidth <= maxWidth && prepared.chunks.length <= 1) {
    return {
      lineCount: 1,
      height: prepared.lineHeight,
      lines: [{ startIndex: 0, endIndex: prepared.segments.length, width: prepared.totalWidth, lineNumber: 0 }],
      maxLineWidth: prepared.totalWidth,
      lastLineWidth: prepared.totalWidth
    }
  }

  const lines: LayoutLine[] = []
  let maxLineWidth = 0

  // Process each hard-break chunk independently
  for (let ci = 0; ci < prepared.chunks.length; ci++) {
    const chunk = prepared.chunks[ci]
    layoutChunk(prepared, chunk, maxWidth, lines)
  }

  // Compute max line width
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].width > maxLineWidth) maxLineWidth = lines[i].width
  }

  // Ensure at least one line
  if (lines.length === 0) {
    lines.push({ startIndex: 0, endIndex: prepared.segments.length, width: 0, lineNumber: 0 })
  }

  const lastLineWidth = lines[lines.length - 1].width

  return {
    lineCount: lines.length,
    height: lines.length * prepared.lineHeight,
    lines,
    maxLineWidth,
    lastLineWidth
  }
}

/**
 * Layout a single hard-break chunk using greedy line breaking.
 */
function layoutChunk(
  prepared: PreparedText,
  chunk: HardBreakChunk,
  maxWidth: number,
  lines: LayoutLine[]
): void {
  const widths: number[] = prepared.widths
  const kinds: SegmentBreakKind[] = prepared.kinds

  // Empty chunk (e.g., trailing newline) — still produces a line
  if (chunk.startIndex >= chunk.endIndex) {
    lines.push({
      startIndex: chunk.startIndex,
      endIndex: chunk.endIndex,
      width: 0,
      lineNumber: lines.length
    })
    return
  }

  let lineStart = chunk.startIndex
  let lineWidth = 0           // content width (excluding trailing whitespace)
  let lineWidthWithTrailing = 0
  let lastBreakPoint = -1
  let lastBreakWidth = 0
  let lastBreakWidthWithTrailing = 0

  for (let i = chunk.startIndex; i < chunk.endIndex; i++) {
    const segWidth = widths[i]
    const segKind = kinds[i]
    const trailing = isTrailingWhitespace(segKind)

    const newWidth = trailing ? lineWidthWithTrailing + segWidth : lineWidthWithTrailing + segWidth

    // Check overflow — trailing whitespace hangs past edge (CSS behavior)
    const fitWidth = trailing ? lineWidth : lineWidthWithTrailing + segWidth

    if (fitWidth > maxWidth && lineStart < i) {
      // Overflow — break at last valid point
      if (lastBreakPoint >= 0) {
        // Break at last break point
        lines.push({
          startIndex: lineStart,
          endIndex: lastBreakPoint + 1,
          width: lastBreakWidth,
          lineNumber: lines.length
        })
        lineStart = lastBreakPoint + 1
        // Recalculate width from new start
        lineWidth = 0
        lineWidthWithTrailing = 0
        for (let j = lineStart; j <= i; j++) {
          if (isTrailingWhitespace(kinds[j])) {
            lineWidthWithTrailing += widths[j]
          } else {
            lineWidthWithTrailing += widths[j]
            lineWidth = lineWidthWithTrailing
          }
        }
        lastBreakPoint = -1
        lastBreakWidth = 0
        lastBreakWidthWithTrailing = 0

        // Re-check break point for current position
        if (canBreakAfter(segKind)) {
          lastBreakPoint = i
          lastBreakWidth = lineWidth
          lastBreakWidthWithTrailing = lineWidthWithTrailing
        }
        continue
      } else {
        // No break point — force break before current segment
        lines.push({
          startIndex: lineStart,
          endIndex: i,
          width: lineWidth,
          lineNumber: lines.length
        })
        lineStart = i
        lineWidth = trailing ? 0 : segWidth
        lineWidthWithTrailing = segWidth
        lastBreakPoint = -1
        lastBreakWidth = 0
        lastBreakWidthWithTrailing = 0

        if (canBreakAfter(segKind)) {
          lastBreakPoint = i
          lastBreakWidth = lineWidth
          lastBreakWidthWithTrailing = lineWidthWithTrailing
        }
        continue
      }
    }

    // Segment fits
    lineWidthWithTrailing = newWidth
    if (!trailing) {
      lineWidth = lineWidthWithTrailing
    }

    if (canBreakAfter(segKind)) {
      lastBreakPoint = i
      lastBreakWidth = lineWidth
      lastBreakWidthWithTrailing = lineWidthWithTrailing
    }
  }

  // Final line of chunk
  lines.push({
    startIndex: lineStart,
    endIndex: chunk.endIndex,
    width: lineWidth,
    lineNumber: lines.length
  })
}

/**
 * Quick measurement — returns only line count and height.
 * Slightly faster than full layoutLines() when line details aren't needed.
 */
export function measureHeight(prepared: PreparedText, maxWidth: number): number {
  if (prepared.segments.length === 0) return prepared.lineHeight
  if (prepared.totalWidth <= maxWidth && prepared.chunks.length <= 1) return prepared.lineHeight

  const result = layoutLines(prepared, maxWidth)
  return result.height
}

/**
 * Get the width of the last line — useful for inline meta placement.
 */
export function getLastLineWidth(prepared: PreparedText, maxWidth: number): number {
  if (prepared.segments.length === 0) return 0
  if (prepared.totalWidth <= maxWidth && prepared.chunks.length <= 1) return prepared.totalWidth

  const result = layoutLines(prepared, maxWidth)
  return result.lastLineWidth
}
