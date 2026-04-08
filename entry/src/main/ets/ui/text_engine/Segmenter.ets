// Segmenter — Text tokenization engine.
// Ported from Pretext (chenglou/pretext) analysis.ts.
// Custom tokenizer for ArkTS (Intl.Segmenter not available in ArkTS type system).

import { TextSegment, SegmentBreakKind, HardBreakChunk } from './TextTypes'
import { charIsCJK, isLeftSticky, isForwardSticky, isLineStartProhibited } from './CjkDetector'

// ── Whitespace normalization ──
//
// Telegram text layout must preserve author-intended hard line breaks.
// We therefore normalize horizontal whitespace per line, but keep '\n'
// boundaries intact (including consecutive blank lines).

const NEEDS_NORMALIZE_RE: RegExp = /[\t\r\f]| {2,}|^ | $|\n/

function normalizeLineWhitespace(line: string): string {
  if (line.length === 0) {
    return ''
  }

  let result: string = line
    .replace(/[\t\r\f]/g, ' ')
    .replace(/ {2,}/g, ' ')

  if (result.length > 0 && result.charCodeAt(0) === 0x20) {
    result = result.slice(1)
  }
  if (result.length > 0 && result.charCodeAt(result.length - 1) === 0x20) {
    result = result.slice(0, -1)
  }
  return result
}

export function normalizeWhitespace(text: string): string {
  if (!NEEDS_NORMALIZE_RE.test(text)) return text

  const normalizedNewlines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n')
  const lines = normalizedNewlines.split('\n')
  for (let i = 0; i < lines.length; i++) {
    lines[i] = normalizeLineWhitespace(lines[i])
  }
  return lines.join('\n')
}

// ── Segment break classification (Pretext 1:1) ──

function classifyChar(ch: string): SegmentBreakKind {
  if (ch === ' ') return 'space'
  if (ch === '\t') return 'tab'
  if (ch === '\n') return 'hard-break'
  if (ch === '\u00A0' || ch === '\u202F' || ch === '\u2060' || ch === '\uFEFF') return 'glue'
  if (ch === '\u200B') return 'zero-width-break'
  if (ch === '\u00AD') return 'soft-hyphen'
  return 'text'
}

// ── Emoji detection ──

function isEmojiCodePoint(cp: number): boolean {
  return (
    (cp >= 0x1F600 && cp <= 0x1F64F) ||
    (cp >= 0x1F300 && cp <= 0x1F5FF) ||
    (cp >= 0x1F680 && cp <= 0x1F6FF) ||
    (cp >= 0x1F700 && cp <= 0x1F77F) ||
    (cp >= 0x1F780 && cp <= 0x1F7FF) ||
    (cp >= 0x1F800 && cp <= 0x1F8FF) ||
    (cp >= 0x1F900 && cp <= 0x1F9FF) ||
    (cp >= 0x1FA00 && cp <= 0x1FA6F) ||
    (cp >= 0x1FA70 && cp <= 0x1FAFF) ||
    (cp >= 0x2600 && cp <= 0x26FF) ||
    (cp >= 0x2700 && cp <= 0x27BF) ||
    (cp >= 0xFE00 && cp <= 0xFE0F) ||
    (cp >= 0xE0020 && cp <= 0xE007F) ||
    cp === 0x200D ||
    cp === 0x20E3 ||
    (cp >= 0x1F1E0 && cp <= 0x1F1FF)
  )
}

class EmojiClusterResult {
  cluster: string = ''
  nextIndex: number = 0
}

function collectEmojiCluster(text: string, startIdx: number): EmojiClusterResult {
  let i: number = startIdx
  let cluster: string = ''
  const res: EmojiClusterResult = new EmojiClusterResult()

  while (i < text.length) {
    const cpVal: number | undefined = text.codePointAt(i)
    if (cpVal === undefined) break
    const cp: number = cpVal
    const charLen: number = cp > 0xFFFF ? 2 : 1

    if (cluster.length === 0) {
      cluster = text.substring(i, i + charLen)
      i += charLen
    } else {
      if (
        cp === 0x200D ||
        cp === 0xFE0F || cp === 0xFE0E ||
        cp === 0x20E3 ||
        (cp >= 0x1F3FB && cp <= 0x1F3FF) ||
        (cp >= 0x1F1E0 && cp <= 0x1F1FF) ||
        (cp >= 0xE0020 && cp <= 0xE007F)
      ) {
        cluster += text.substring(i, i + charLen)
        i += charLen
      } else if (isEmojiCodePoint(cp) && i > 0 && text.codePointAt(i - 1) === 0x200D) {
        cluster += text.substring(i, i + charLen)
        i += charLen
      } else {
        break
      }
    }
  }

  res.cluster = cluster
  res.nextIndex = i
  return res
}

// ── Custom tokenizer ──

function makeSegment(segText: string, kind: SegmentBreakKind, isWordLike: boolean): TextSegment {
  const seg: TextSegment = { text: segText, kind: kind, isWordLike: isWordLike }
  return seg
}

function tokenizeCustom(text: string): TextSegment[] {
  const segments: TextSegment[] = []
  let i: number = 0

  while (i < text.length) {
    const cpVal: number | undefined = text.codePointAt(i)
    if (cpVal === undefined) break
    const cp: number = cpVal
    const charLen: number = cp > 0xFFFF ? 2 : 1

    const kind: SegmentBreakKind = classifyChar(text[i])
    if (kind !== 'text') {
      if (kind === 'space') {
        let end: number = i + 1
        while (end < text.length && text[end] === ' ') end++
        segments.push(makeSegment(text.substring(i, end), 'space', false))
        i = end
        continue
      }
      segments.push(makeSegment(text.substring(i, i + charLen), kind, false))
      i += charLen
      continue
    }

    if (isEmojiCodePoint(cp)) {
      const emojiResult: EmojiClusterResult = collectEmojiCluster(text, i)
      segments.push(makeSegment(emojiResult.cluster, 'text', false))
      i = emojiResult.nextIndex
      continue
    }

    if (charIsCJK(text.substring(i, i + charLen))) {
      segments.push(makeSegment(text.substring(i, i + charLen), 'text', true))
      i += charLen
      continue
    }

    if (isWordChar(cp)) {
      let end: number = i + charLen
      while (end < text.length) {
        const nextCpVal: number | undefined = text.codePointAt(end)
        if (nextCpVal === undefined) break
        const nextCp: number = nextCpVal
        const nextLen: number = nextCp > 0xFFFF ? 2 : 1
        if (nextCp === 0x27 || nextCp === 0x2019) {
          if (end + nextLen < text.length) {
            const afterVal: number | undefined = text.codePointAt(end + nextLen)
            if (afterVal !== undefined && isWordChar(afterVal)) {
              end += nextLen
              continue
            }
          }
        }
        if (!isWordChar(nextCp)) break
        end += nextLen
      }
      segments.push(makeSegment(text.substring(i, end), 'text', true))
      i = end
      continue
    }

    segments.push(makeSegment(text.substring(i, i + charLen), 'text', false))
    i += charLen
  }

  return segments
}

function isWordChar(cp: number): boolean {
  return (
    (cp >= 0x41 && cp <= 0x5A) ||
    (cp >= 0x61 && cp <= 0x7A) ||
    (cp >= 0x30 && cp <= 0x39) ||
    cp === 0x5F ||
    (cp >= 0xC0 && cp <= 0x024F) ||
    (cp >= 0x0400 && cp <= 0x04FF) ||
    (cp >= 0x0500 && cp <= 0x052F) ||
    (cp >= 0x0600 && cp <= 0x06FF) ||
    (cp >= 0x0900 && cp <= 0x097F) ||
    (cp >= 0x0980 && cp <= 0x09FF) ||
    (cp >= 0x0E00 && cp <= 0x0E7F) ||
    (cp >= 0x10A0 && cp <= 0x10FF) ||
    (cp >= 0x1100 && cp <= 0x11FF) ||
    (cp >= 0x0370 && cp <= 0x03FF)
  )
}

// ── Glue merge pass (Pretext kinsoku rules) ──

function applyGlueRules(segments: TextSegment[]): TextSegment[] {
  if (segments.length <= 1) return segments

  const result: TextSegment[] = []

  for (let i = 0; i < segments.length; i++) {
    const seg: TextSegment = segments[i]

    if (isForwardSticky(seg.text) && i + 1 < segments.length && segments[i + 1].kind === 'text') {
      const next: TextSegment = segments[i + 1]
      result.push(makeSegment(seg.text + next.text, 'text', next.isWordLike))
      i++
      continue
    }

    if (result.length > 0 && result[result.length - 1].kind === 'text') {
      if (isLeftSticky(seg.text) || isLineStartProhibited(seg.text)) {
        const prev: TextSegment = result[result.length - 1]
        result[result.length - 1] = makeSegment(prev.text + seg.text, 'text', prev.isWordLike)
        continue
      }
    }

    result.push(seg)
  }

  return result
}

// ── Hard-break chunk detection ──

function buildChunks(segments: TextSegment[]): HardBreakChunk[] {
  const chunks: HardBreakChunk[] = []
  let start: number = 0

  for (let i = 0; i < segments.length; i++) {
    if (segments[i].kind === 'hard-break') {
      const chunk: HardBreakChunk = { startIndex: start, endIndex: i }
      chunks.push(chunk)
      start = i + 1
    }
  }
  const lastChunk: HardBreakChunk = { startIndex: start, endIndex: segments.length }
  chunks.push(lastChunk)

  return chunks
}

// ── Public API ──

export function tokenize(text: string): TextSegment[] {
  if (text.length === 0) return []
  const raw: TextSegment[] = tokenizeCustom(text)
  return applyGlueRules(raw)
}

export class TokenizeResult {
  segments: TextSegment[] = []
  chunks: HardBreakChunk[] = []
}

export function tokenizeWithChunks(text: string): TokenizeResult {
  const segments: TextSegment[] = tokenize(text)
  const chunks: HardBreakChunk[] = buildChunks(segments)
  const result: TokenizeResult = new TokenizeResult()
  result.segments = segments
  result.chunks = chunks
  return result
}

export function isSimplePath(segments: TextSegment[]): boolean {
  for (let i = 0; i < segments.length; i++) {
    const k: SegmentBreakKind = segments[i].kind
    if (k === 'tab' || k === 'soft-hyphen' || k === 'hard-break') return false
  }
  return true
}
