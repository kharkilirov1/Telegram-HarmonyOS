// TgBubbleLayoutTypes — Computed bubble layout types.
// Pure data structures, no ArkUI dependencies.

import { PreparedText } from '../../text_engine/TextTypes'

/**
 * Pre-computed layout for a text message bubble.
 * All dimensions in vp. Computed by TgBubbleLayout, consumed by TgTextBubbleV3.
 */
export interface TextBubbleLayout {
  bubbleWidth: number
  totalHeight: number
  contentWidth: number

  // Text
  textHeight: number
  lineCount: number
  lastLineWidth: number
  maxLineWidth: number
  prepared: PreparedText | null

  // Meta placement
  metaInline: boolean
  extraMetaHeight: number
  metaWidth: number

  // Sender
  senderWidth: number
  senderHeight: number

  // Reply
  replyWidth: number
  replyHeight: number

  // Quote segments (parallel arrays)
  quoteSegmentHeights: number[]
  quoteSegmentWidths: number[]
}

/**
 * Input for bubble layout computation.
 */
export interface BubbleLayoutInput {
  text: string
  isOutgoing: boolean
  containerWidth: number
  maxWidthRatio: number
  avatarInset: number

  // Sender
  senderName: string

  // Reply
  replyAuthor: string
  replyPreview: string
  replyHasThumbnail: boolean

  // Meta
  timeText: string
  editedText?: string
  hasStatus: boolean

  // Content flags
  isEmojiOnly: boolean
  forceBreakAll: boolean
  minimumContentWidth: number
  forceSeparateMeta: boolean

  // Quotes
  quoteOffsets: number[]
  quoteLengths: number[]
  quoteCollapsedFlags: boolean[]
}

/**
 * Create a default empty layout input.
 */
export function defaultBubbleLayoutInput(): BubbleLayoutInput {
  return {
    text: '',
    isOutgoing: false,
    containerWidth: 360,
    maxWidthRatio: 0.75,
    avatarInset: 0,
    senderName: '',
    replyAuthor: '',
    replyPreview: '',
    replyHasThumbnail: false,
    timeText: '',
    editedText: '',
    hasStatus: false,
    isEmojiOnly: false,
    forceBreakAll: false,
    minimumContentWidth: 0,
    forceSeparateMeta: false,
    quoteOffsets: [],
    quoteLengths: [],
    quoteCollapsedFlags: [],
  }
}
