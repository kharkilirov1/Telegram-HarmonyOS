// TgTextBodyV3 — Text rendering with optional quote segments.
// Engine-driven: receives explicit contentWidth, no auto-measurement.
// Simplified from TgMessageTextBodyV2 — no meta reserve text injection.

import { TgUiTokens } from '../tokens/TgUiTokens'
import { TextEntity } from '../../../core/model/AppState'

class RichSpan {
  text: string = '';
  isBold: boolean = false;
  isItalic: boolean = false;
  isUnderline: boolean = false;
  isStrikethrough: boolean = false;
  isCode: boolean = false;
  isLink: boolean = false;
}

function splitRichSpans(text: string, segStart: number, entities: TextEntity[]): RichSpan[] {
  if (entities.length === 0 || text.length === 0) {
    const s = new RichSpan(); s.text = text; return [s];
  }
  const segEnd = segStart + text.length;
  const points: number[] = [segStart];
  for (const e of entities) {
    const es = Math.max(segStart, e.offset);
    const ee = Math.min(segEnd, e.offset + e.length);
    if (es >= ee) continue;
    if (points[points.length - 1] !== es) points.push(es);
    if (points[points.length - 1] !== ee) points.push(ee);
  }
  if (points[points.length - 1] !== segEnd) points.push(segEnd);
  points.sort((a, b) => a - b);

  const result: RichSpan[] = [];
  for (let i = 0; i < points.length - 1; i++) {
    const rs = points[i]; const re = points[i + 1];
    const sub = text.substring(rs - segStart, re - segStart);
    if (sub.length === 0) continue;
    const span = new RichSpan(); span.text = sub;
    for (const e of entities) {
      if (e.offset < re && e.offset + e.length > rs) {
        switch (e.type) {
          case 'bold': span.isBold = true; break;
          case 'italic': span.isItalic = true; break;
          case 'underline': span.isUnderline = true; break;
          case 'strikethrough': span.isStrikethrough = true; break;
          case 'code': case 'pre': case 'preCode': span.isCode = true; break;
          case 'url': case 'textUrl': case 'mention': case 'mentionName':
          case 'emailAddress': case 'phoneNumber': case 'hashtag':
          case 'cashtag': case 'botCommand': span.isLink = true; break;
          default: break;
        }
      }
    }
    result.push(span);
  }
  return result;
}

/** A text body segment — either plain text or a quoted block. */
interface TextBodySegment {
  text: string
  startOffset: number
  isQuote: boolean
  isCollapsed: boolean
  isLast: boolean
}

class TgQuoteSegmentRange {
  start: number = 0
  end: number = 0
  collapsed: boolean = false
}

@ComponentV2
export struct TgTextBodyV3 {
  @Param text: string = ''
  @Param isOutgoing: boolean = false
  @Param contentWidth: number = 300
  @Param forceBreakAll: boolean = false

  // Quote data (parallel arrays)
  @Param quoteOffsets: number[] = []
  @Param quoteLengths: number[] = []
  @Param quoteCollapsedFlags: boolean[] = []
  @Param textEntities: TextEntity[] = []

  // Accent color for quote bar (sender color in groups)
  @Param quoteAccentHex: string = ''

  private hasQuotes(): boolean {
    return this.quoteOffsets.length > 0 && this.quoteLengths.length > 0
  }

  private buildSegments(): TextBodySegment[] {
    if (!this.hasQuotes()) {
      return [{ text: this.text, startOffset: 0, isQuote: false, isCollapsed: false, isLast: true }]
    }

    const ranges: TgQuoteSegmentRange[] = []
    const count = Math.min(this.quoteOffsets.length, this.quoteLengths.length)
    for (let i = 0; i < count; i++) {
      const rawStart = this.quoteOffsets[i]
      const rawLength = this.quoteLengths[i]
      if (rawLength <= 0) {
        continue
      }
      const start = Math.max(0, Math.min(this.text.length, rawStart))
      const end = Math.max(start, Math.min(this.text.length, start + rawLength))
      if (end <= start) {
        continue
      }
      const range = new TgQuoteSegmentRange()
      range.start = start
      range.end = end
      range.collapsed = i < this.quoteCollapsedFlags.length ? this.quoteCollapsedFlags[i] : false
      ranges.push(range)
    }

    ranges.sort((a, b) => a.start - b.start)

    const merged: TgQuoteSegmentRange[] = []
    for (let i = 0; i < ranges.length; i++) {
      const range = ranges[i]
      if (merged.length === 0) {
        merged.push(range)
        continue
      }
      const prev = merged[merged.length - 1]
      if (range.start <= prev.end) {
        prev.end = Math.max(prev.end, range.end)
        prev.collapsed = prev.collapsed || range.collapsed
      } else {
        merged.push(range)
      }
    }

    const segments: TextBodySegment[] = []
    let cursor = 0

    for (let i = 0; i < merged.length; i++) {
      const qStart = merged[i].start
      const qEnd = merged[i].end
      const collapsed = merged[i].collapsed

      // Plain text before quote
      if (qStart > cursor) {
        const plainText = this.text.substring(cursor, qStart)
        if (plainText.length === 0) {
          cursor = qStart
        } else {
        segments.push({
            text: plainText,
          startOffset: cursor,
          isQuote: false,
          isCollapsed: false,
          isLast: false
        })
        }
      }

      // Quote segment
      const quoteText = this.text.substring(qStart, qEnd)
      if (quoteText.length > 0) {
      segments.push({
          text: quoteText,
        startOffset: qStart,
        isQuote: true,
        isCollapsed: collapsed,
        isLast: false
      })
      }

      cursor = qEnd
    }

    // Trailing plain text
    if (cursor < this.text.length) {
      const tailText = this.text.substring(cursor)
      if (tailText.length > 0) {
      segments.push({
          text: tailText,
        startOffset: cursor,
        isQuote: false,
        isCollapsed: false,
        isLast: false
      })
      }
    }

    // Mark last segment
    if (segments.length === 0) {
      return [{ text: this.text.length > 0 ? this.text : ' ', startOffset: 0, isQuote: false, isCollapsed: false, isLast: true }]
    }
    segments[segments.length - 1].isLast = true

    return segments
  }

  private textColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.MSG_TEXT_OUTGOING : TgUiTokens.MSG_TEXT_INCOMING
  }

  private quoteBarColor(): ResourceColor {
    if (this.quoteAccentHex.length > 0) return this.quoteAccentHex
    return this.isOutgoing ? TgUiTokens.MSG_QUOTE_BAR_OUTGOING : TgUiTokens.MSG_QUOTE_BAR_INCOMING
  }

  private quoteBackground(): ResourceColor {
    if (this.quoteAccentHex.length > 0) {
      const alpha = this.isOutgoing ? '1A' : '1F' // ~10% / ~12%
      return this.quoteAccentHex + alpha
    }
    return this.isOutgoing
      ? TgUiTokens.MSG_QUOTE_BG_OUTGOING
      : TgUiTokens.MSG_QUOTE_BG_INCOMING
  }

  private linkColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.MSG_LINK_OUTGOING : TgUiTokens.MSG_LINK_INCOMING
  }

  private codeBg(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.MSG_CODE_BG_OUTGOING : TgUiTokens.MSG_CODE_BG_INCOMING
  }

  private hasEntities(segStart: number, segLen: number): boolean {
    for (const e of this.textEntities) {
      if (e.offset < segStart + segLen && e.offset + e.length > segStart) return true;
    }
    return false;
  }

  @Builder
  buildPlainSegment(segText: string, segStart: number = 0) {
    if (this.hasEntities(segStart, segText.length)) {
      Text() {
        ForEach(splitRichSpans(segText, segStart, this.textEntities),
          (span: RichSpan) => {
            Span(span.text)
              .fontSize(span.isCode ? TgUiTokens.MSG_CODE_SIZE : TgUiTokens.MSG_TEXT_SIZE)
              .fontWeight(span.isBold ? FontWeight.Bold : TgUiTokens.MSG_TEXT_WEIGHT)
              .fontStyle(span.isItalic ? FontStyle.Italic : FontStyle.Normal)
              .fontColor(span.isLink ? this.linkColor() : this.textColor())
              .decoration({
                type: span.isUnderline ? TextDecorationType.Underline
                  : (span.isStrikethrough ? TextDecorationType.LineThrough : TextDecorationType.None),
                color: span.isLink ? this.linkColor() : this.textColor()
              })
              .fontFamily(span.isCode ? 'monospace' : 'HarmonyOS Sans')
              .textBackgroundStyle(span.isCode ? { color: this.codeBg(), radius: 4 } : undefined)
          })
      }
      .lineHeight(TgUiTokens.MSG_TEXT_LINE_HEIGHT)
      .textAlign(TextAlign.Start)
      .wordBreak(this.forceBreakAll ? WordBreak.BREAK_ALL : WordBreak.BREAK_WORD)
      .lineBreakStrategy(this.forceBreakAll ? LineBreakStrategy.GREEDY : LineBreakStrategy.HIGH_QUALITY)
      .width(this.contentWidth)
    } else {
      Text(segText)
        .fontSize(TgUiTokens.MSG_TEXT_SIZE)
        .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
        .lineHeight(TgUiTokens.MSG_TEXT_LINE_HEIGHT)
        .fontColor(this.textColor())
        .textAlign(TextAlign.Start)
        .wordBreak(this.forceBreakAll ? WordBreak.BREAK_ALL : WordBreak.BREAK_WORD)
        .lineBreakStrategy(this.forceBreakAll ? LineBreakStrategy.GREEDY : LineBreakStrategy.HIGH_QUALITY)
        .width(this.contentWidth)
    }
  }

  @Builder
  buildQuoteSegment(segText: string, isCollapsed: boolean) {
    Row() {
      // Left accent bar
      Column()
        .width(TgUiTokens.MSG_QUOTE_BAR_WIDTH)
        .height('100%')
        .backgroundColor(this.quoteBarColor())
        .borderRadius(TgUiTokens.MSG_QUOTE_BAR_WIDTH / 2)

      // Quote text
      Text(segText)
        .fontSize(TgUiTokens.MSG_QUOTE_TEXT_SIZE)
        .fontWeight(FontWeight.Regular)
        .lineHeight(TgUiTokens.MSG_QUOTE_TEXT_LINE_HEIGHT)
        .fontColor(this.textColor())
        .textAlign(TextAlign.Start)
        .wordBreak(WordBreak.BREAK_WORD)
        .opacity(isCollapsed ? TgUiTokens.MSG_QUOTE_COLLAPSED_OPACITY : 1.0)
        .layoutWeight(1)
    }
    .width(this.contentWidth)
    .padding({
      left: TgUiTokens.MSG_QUOTE_BAR_GAP,
      right: TgUiTokens.MSG_QUOTE_PADDING_H,
      top: TgUiTokens.MSG_QUOTE_PADDING_V,
      bottom: TgUiTokens.MSG_QUOTE_PADDING_V,
    })
    .backgroundColor(this.quoteBackground())
    .borderRadius(TgUiTokens.MSG_QUOTE_RADIUS)
  }

  build() {
    if (this.hasQuotes()) {
      Column({ space: TgUiTokens.MSG_QUOTE_SEGMENT_GAP }) {
        ForEach(this.buildSegments(), (seg: TextBodySegment, idx: number) => {
          if (seg.isQuote) {
            this.buildQuoteSegment(seg.text, seg.isCollapsed)
          } else {
            this.buildPlainSegment(seg.text, seg.startOffset)
          }
        }, (seg: TextBodySegment, idx: number) => `seg_${idx}_${seg.isQuote ? 'q' : 'p'}`)
      }
      .alignItems(HorizontalAlign.Start)
    } else {
      this.buildPlainSegment(this.text, 0)
    }
  }
}
