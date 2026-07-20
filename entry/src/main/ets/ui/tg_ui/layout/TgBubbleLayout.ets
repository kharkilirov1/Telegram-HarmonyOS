// TgBubbleLayout — Pure computation of text bubble dimensions.
// Telegram iOS two-pass algorithm: measure → decide meta → shrink-wrap → height.
// No ArkUI component dependencies — pure functions + engine calls.

import { TgTextLayout } from '../../text_engine/TgTextLayout'
import { TextStyleKey } from '../../text_engine/TextTypes'
import { TextBubbleLayout, BubbleLayoutInput } from './TgBubbleLayoutTypes'
import { TgUiTokens } from '../tokens/TgUiTokens'
import { composeMessageMetaText } from '../utils/TgMessageMetaText'

// ── Style keys (cached) ──

function textStyle(): TextStyleKey {
  return {
    fontSize: TgUiTokens.MSG_TEXT_SIZE,
    lineHeight: TgUiTokens.MSG_TEXT_LINE_HEIGHT,
    fontWeight: TgUiTokens.MSG_TEXT_WEIGHT,
  }
}

function emojiStyle(): TextStyleKey {
  return {
    fontSize: TgUiTokens.MSG_EMOJI_ONLY_SIZE,
    lineHeight: TgUiTokens.MSG_EMOJI_ONLY_LINE_HEIGHT,
    fontWeight: TgUiTokens.MSG_TEXT_WEIGHT,
  }
}

function senderStyle(): TextStyleKey {
  return {
    fontSize: TgUiTokens.MSG_SENDER_NAME_SIZE,
    lineHeight: TgUiTokens.MSG_SENDER_LINE_HEIGHT,
    fontWeight: FontWeight.Bold,
  }
}

function metaStyle(): TextStyleKey {
  return {
    fontSize: TgUiTokens.MSG_META_SIZE,
    lineHeight: TgUiTokens.MSG_META_ROW_HEIGHT,
    fontWeight: FontWeight.Regular,
  }
}

function replyTitleStyle(): TextStyleKey {
  return {
    fontSize: TgUiTokens.REPLY_SNIPPET_TITLE_SIZE,
    lineHeight: TgUiTokens.REPLY_SNIPPET_TITLE_LINE_HEIGHT,
    fontWeight: TgUiTokens.REPLY_SNIPPET_TITLE_WEIGHT,
  }
}

function replyPreviewStyle(): TextStyleKey {
  return {
    fontSize: TgUiTokens.REPLY_SNIPPET_PREVIEW_SIZE,
    lineHeight: TgUiTokens.REPLY_SNIPPET_PREVIEW_LINE_HEIGHT,
    fontWeight: FontWeight.Regular,
  }
}

function quoteTextStyle(): TextStyleKey {
  return {
    fontSize: TgUiTokens.MSG_QUOTE_TEXT_SIZE,
    lineHeight: TgUiTokens.MSG_QUOTE_TEXT_LINE_HEIGHT,
    fontWeight: FontWeight.Regular,
  }
}

interface BubbleTextSegment {
  text: string
  isQuote: boolean
  isCollapsed: boolean
  isLast: boolean
}

interface BubbleSegmentMeasurement {
  width: number
  lastLineWidth: number
  height: number
  isQuote: boolean
}

interface QuoteRange {
  start: number
  end: number
  isCollapsed: boolean
}

function buildQuoteRanges(input: BubbleLayoutInput): QuoteRange[] {
  const count = Math.min(input.quoteOffsets.length, input.quoteLengths.length)
  if (count === 0 || input.text.length === 0) {
    return []
  }

  const ranges: QuoteRange[] = []
  for (let i = 0; i < count; i++) {
    const rawStart = input.quoteOffsets[i]
    const rawLength = input.quoteLengths[i]
    if (rawLength <= 0) {
      continue
    }
    const start = Math.max(0, Math.min(input.text.length, rawStart))
    const end = Math.max(start, Math.min(input.text.length, start + rawLength))
    if (end <= start) {
      continue
    }
    ranges.push({
      start,
      end,
      isCollapsed: i < input.quoteCollapsedFlags.length ? input.quoteCollapsedFlags[i] : false,
    })
  }

  ranges.sort((a: QuoteRange, b: QuoteRange) => a.start - b.start)

  const merged: QuoteRange[] = []
  for (let i = 0; i < ranges.length; i++) {
    const range = ranges[i]
    if (merged.length === 0) {
      merged.push(range)
      continue
    }
    const prev = merged[merged.length - 1]
    if (range.start <= prev.end) {
      prev.end = Math.max(prev.end, range.end)
      prev.isCollapsed = prev.isCollapsed || range.isCollapsed
    } else {
      merged.push(range)
    }
  }

  return merged
}

function buildTextSegments(input: BubbleLayoutInput): BubbleTextSegment[] {
  const ranges = buildQuoteRanges(input)
  if (ranges.length === 0) {
    return [{ text: input.text, isQuote: false, isCollapsed: false, isLast: true }]
  }

  const segments: BubbleTextSegment[] = []
  let cursor = 0

  for (let i = 0; i < ranges.length; i++) {
    const range = ranges[i]
    if (range.start > cursor) {
      const plainText = input.text.substring(cursor, range.start)
      if (plainText.length > 0) {
        segments.push({
          text: plainText,
          isQuote: false,
          isCollapsed: false,
          isLast: false,
        })
      }
    }

    const quoteText = input.text.substring(range.start, range.end)
    if (quoteText.length > 0) {
      segments.push({
        text: quoteText,
        isQuote: true,
        isCollapsed: range.isCollapsed,
        isLast: false,
      })
    }
    cursor = range.end
  }

  if (cursor < input.text.length) {
    const tailText = input.text.substring(cursor)
    if (tailText.length > 0) {
      segments.push({
        text: tailText,
        isQuote: false,
        isCollapsed: false,
        isLast: false,
      })
    }
  }

  if (segments.length === 0) {
    return [{ text: input.text, isQuote: false, isCollapsed: false, isLast: true }]
  }

  segments[segments.length - 1].isLast = true
  return segments
}

function measureTextSegments(engine: TgTextLayout, input: BubbleLayoutInput, maxContentWidth: number): BubbleSegmentMeasurement[] {
  const segments = buildTextSegments(input)
  const measurements: BubbleSegmentMeasurement[] = []

  const plainStyle = input.isEmojiOnly ? emojiStyle() : textStyle()
  const quoteStyleKey = quoteTextStyle()
  const quoteInnerMaxWidth = Math.max(
    1,
    maxContentWidth
      - TgUiTokens.MSG_QUOTE_BAR_WIDTH
      - TgUiTokens.MSG_QUOTE_BAR_GAP
      - TgUiTokens.MSG_QUOTE_PADDING_H
  )

  for (let i = 0; i < segments.length; i++) {
    const segment = segments[i]
    const text = segment.text.length > 0 ? segment.text : ' '
    if (segment.isQuote) {
      const innerLayout = engine.measureText(text, quoteStyleKey, quoteInnerMaxWidth)
      const visualWidth = Math.min(
        maxContentWidth,
        innerLayout.maxLineWidth
          + TgUiTokens.MSG_QUOTE_BAR_WIDTH
          + TgUiTokens.MSG_QUOTE_BAR_GAP
          + TgUiTokens.MSG_QUOTE_PADDING_H
      )
      measurements.push({
        width: visualWidth,
        lastLineWidth: visualWidth,
        height: innerLayout.height + TgUiTokens.MSG_QUOTE_PADDING_V * 2,
        isQuote: true,
      })
    } else {
      const layout = engine.measureText(text, plainStyle, maxContentWidth)
      measurements.push({
        width: layout.maxLineWidth,
        lastLineWidth: layout.lastLineWidth,
        height: layout.height,
        isQuote: false,
      })
    }
  }

  return measurements
}

// ── Meta width measurement ──

export function measureMetaWidth(engine: TgTextLayout, timeText: string, hasStatus: boolean,
  editedText: string = ''): number {
  const metaText = composeMessageMetaText(editedText, timeText)
  if (metaText.length === 0) return TgUiTokens.MSG_META_MIN_WIDTH

  // Measure the same localized edited + time string rendered by TgMessageMeta.
  const timeLayout = engine.measureText(metaText, metaStyle(), 999)
  let width = timeLayout.maxLineWidth

  // Add status icon space for outgoing
  if (hasStatus) {
    width += TgUiTokens.MSG_META_ICON_GAP + TgUiTokens.MSG_META_ICON_SIZE
  }

  return Math.max(width, TgUiTokens.MSG_META_MIN_WIDTH)
}

// ── Reply width measurement ──

export function measureReplyWidth(
  engine: TgTextLayout,
  author: string,
  preview: string,
  hasThumbnail: boolean,
  maxWidth: number
): number {
  if (author.length === 0 && preview.length === 0) return 0

  const innerMaxWidth = maxWidth
    - TgUiTokens.REPLY_SNIPPET_BAR_WIDTH
    - TgUiTokens.REPLY_SNIPPET_BAR_GAP
    - TgUiTokens.REPLY_SNIPPET_PADDING_H * 2
    - (hasThumbnail ? TgUiTokens.REPLY_SNIPPET_THUMB_SIZE + TgUiTokens.SPACE_8 : 0)

  let contentWidth = 0

  if (author.length > 0) {
    const authorLayout = engine.measureText(author, replyTitleStyle(), innerMaxWidth)
    contentWidth = Math.max(contentWidth, authorLayout.maxLineWidth)
  }

  if (preview.length > 0) {
    const previewLayout = engine.measureText(preview, replyPreviewStyle(), innerMaxWidth)
    contentWidth = Math.max(contentWidth, previewLayout.maxLineWidth)
  }

  return TgUiTokens.REPLY_SNIPPET_BAR_WIDTH
    + TgUiTokens.REPLY_SNIPPET_BAR_GAP
    + TgUiTokens.REPLY_SNIPPET_PADDING_H
    + contentWidth
    + TgUiTokens.REPLY_SNIPPET_PADDING_H
    + (hasThumbnail ? TgUiTokens.REPLY_SNIPPET_THUMB_SIZE + TgUiTokens.SPACE_8 : 0)
}

function measureReplyHeight(): number {
  return TgUiTokens.REPLY_SNIPPET_PADDING_V * 2
    + TgUiTokens.REPLY_SNIPPET_TITLE_LINE_HEIGHT
    + TgUiTokens.REPLY_SNIPPET_PREVIEW_LINE_HEIGHT
}

// ── Main computation ──

/**
 * Compute exact dimensions for a text message bubble.
 * Pure function — no side effects, no ArkUI dependencies.
 *
 * Algorithm (Telegram iOS style):
 *   1. Measure text → get height, line count, last line width, max line width
 *   2. Measure sender name, reply snippet, meta
 *   3. Decide meta placement: inline if fits on last line, else separate row
 *   4. Shrink-wrap: bubble width = max(all content widths) + padding
 *   5. Total height = sum of all vertical sections + padding
 */
export function computeTextBubbleLayout(engine: TgTextLayout, input: BubbleLayoutInput): TextBubbleLayout {
  const PAD_H = TgUiTokens.BUBBLE_PADDING_H
  const PAD_V = TgUiTokens.BUBBLE_PADDING_V
  const META_INLINE_PAD = TgUiTokens.MSG_META_INLINE_PAD

  // Effective container width (minus avatar inset)
  const effectiveContainer = input.containerWidth - input.avatarInset
  const maxBubbleWidth = TgUiTokens.resolveBubbleMaxWidth(effectiveContainer, input.maxWidthRatio)
  const maxContentWidth = maxBubbleWidth - PAD_H * 2

  if (maxContentWidth <= 0) {
    return emptyLayout()
  }

  // ── Pass 1: Measure all content ──

  const style = input.isEmojiOnly ? emojiStyle() : textStyle()
  let prepared = engine.prepare(input.text, style)
  const textLayout = engine.layout(prepared, maxContentWidth)
  const segmentMeasurements = measureTextSegments(engine, input, maxContentWidth)

  let textWidth = textLayout.maxLineWidth
  let lastLineWidth = textLayout.lastLineWidth
  let textHeight = textLayout.height
  const quoteSegmentHeights: number[] = []
  const quoteSegmentWidths: number[] = []

  if (segmentMeasurements.length > 0) {
    let measuredHeight = 0
    let measuredWidth = 0
    for (let i = 0; i < segmentMeasurements.length; i++) {
      const measurement = segmentMeasurements[i]
      if (i > 0) {
        measuredHeight += TgUiTokens.MSG_QUOTE_SEGMENT_GAP
      }
      measuredHeight += measurement.height
      measuredWidth = Math.max(measuredWidth, measurement.width)
      if (measurement.isQuote) {
        quoteSegmentHeights.push(measurement.height)
        quoteSegmentWidths.push(measurement.width)
      }
      if (i === segmentMeasurements.length - 1) {
        lastLineWidth = measurement.lastLineWidth
      }
    }
    textWidth = measuredWidth
    textHeight = measuredHeight
  }

  // Sender name
  let senderW = 0
  let senderH = 0
  if (input.senderName.length > 0) {
    const senderLayout = engine.measureText(input.senderName, senderStyle(), maxContentWidth)
    senderW = senderLayout.maxLineWidth
    senderH = TgUiTokens.MSG_SENDER_LINE_HEIGHT + TgUiTokens.SPACE_2
  }

  // Reply snippet
  let replyW = 0
  let replyH = 0
  if (input.replyAuthor.length > 0 || input.replyPreview.length > 0) {
    replyW = measureReplyWidth(engine, input.replyAuthor, input.replyPreview, input.replyHasThumbnail, maxContentWidth)
    replyH = measureReplyHeight() + TgUiTokens.SPACE_4
  }

  // Meta
  const metaW = measureMetaWidth(engine, input.timeText, input.hasStatus, input.editedText ?? '')

  // ── Pass 2: Decide meta placement ──

  let metaInline: boolean
  let extraMetaH: number

  if (input.forceSeparateMeta || input.text.length === 0) {
    // Empty text — meta on its own line
    metaInline = false
    extraMetaH = TgUiTokens.MSG_META_ROW_HEIGHT
  } else if (lastLineWidth + META_INLINE_PAD + metaW <= maxContentWidth) {
    metaInline = true
    extraMetaH = 0
  } else {
    metaInline = false
    extraMetaH = TgUiTokens.MSG_META_ROW_HEIGHT
  }

  // ── Pass 3: Shrink-wrap width ──

  let contentW = textWidth

  // Embedded content (for example a Telegram link preview) can establish a
  // readable minimum without replacing the text engine's shrink-wrap logic.
  contentW = Math.max(contentW, input.minimumContentWidth)

  // Sender name can force bubble wider
  contentW = Math.max(contentW, senderW)

  // Reply can force bubble wider
  contentW = Math.max(contentW, replyW)

  // Meta placement affects width
  if (metaInline) {
    // Last line + meta must fit
    const lastLineWithMeta = lastLineWidth + META_INLINE_PAD + metaW
    contentW = Math.max(contentW, lastLineWithMeta)
  } else {
    contentW = Math.max(contentW, metaW)
  }

  // Clamp to max
  contentW = Math.min(contentW, maxContentWidth)

  // Ensure minimum width for very short messages
  contentW = Math.max(contentW, metaW)

  const bubbleW = contentW + PAD_H * 2

  // ── Pass 4: Total height ──

  const totalH = PAD_V
    + senderH
    + replyH
    + textHeight
    + extraMetaH
    + PAD_V

  return {
    bubbleWidth: bubbleW,
    totalHeight: totalH,
    contentWidth: contentW,
    textHeight,
    lineCount: textLayout.lineCount,
    lastLineWidth,
    maxLineWidth: textWidth,
    prepared,
    metaInline,
    extraMetaHeight: extraMetaH,
    metaWidth: metaW,
    senderWidth: senderW,
    senderHeight: senderH,
    replyWidth: replyW,
    replyHeight: replyH,
    quoteSegmentHeights,
    quoteSegmentWidths,
  }
}

function emptyLayout(): TextBubbleLayout {
  return {
    bubbleWidth: TgUiTokens.MSG_META_MIN_WIDTH + TgUiTokens.BUBBLE_PADDING_H * 2,
    totalHeight: TgUiTokens.BUBBLE_PADDING_V * 2 + TgUiTokens.MSG_META_ROW_HEIGHT,
    contentWidth: TgUiTokens.MSG_META_MIN_WIDTH,
    textHeight: 0,
    lineCount: 0,
    lastLineWidth: 0,
    maxLineWidth: 0,
    prepared: null,
    metaInline: false,
    extraMetaHeight: TgUiTokens.MSG_META_ROW_HEIGHT,
    metaWidth: TgUiTokens.MSG_META_MIN_WIDTH,
    senderWidth: 0,
    senderHeight: 0,
    replyWidth: 0,
    replyHeight: 0,
    quoteSegmentHeights: [],
    quoteSegmentWidths: [],
  }
}
