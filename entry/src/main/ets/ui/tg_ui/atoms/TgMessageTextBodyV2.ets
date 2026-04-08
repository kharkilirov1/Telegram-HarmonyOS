import { TgUiTokens } from '../tokens/TgUiTokens';
import { TextEntity } from '../../../core/model/AppState';

// A styled sub-span within a text segment
class StyledSpan {
  text: string = '';
  isBold: boolean = false;
  isItalic: boolean = false;
  isUnderline: boolean = false;
  isStrikethrough: boolean = false;
  isCode: boolean = false;
  isLink: boolean = false;
  isSpoiler: boolean = false;
}

// Split text segment into styled sub-spans based on entities
function buildStyledSpans(text: string, segmentStart: number, entities: TextEntity[]): StyledSpan[] {
  if (entities.length === 0 || text.length === 0) {
    const span = new StyledSpan();
    span.text = text;
    return [span];
  }

  const segEnd = segmentStart + text.length;

  // Collect entity boundaries within this segment
  interface Boundary { pos: number; isStart: boolean; entity: TextEntity; }
  const boundaries: Boundary[] = [];
  for (const e of entities) {
    const eStart = Math.max(segmentStart, e.offset);
    const eEnd = Math.min(segEnd, e.offset + e.length);
    if (eStart >= eEnd) continue;
    boundaries.push({ pos: eStart, isStart: true, entity: e });
    boundaries.push({ pos: eEnd, isStart: false, entity: e });
  }
  if (boundaries.length === 0) {
    const span = new StyledSpan();
    span.text = text;
    return [span];
  }

  // Sort boundaries by position
  boundaries.sort((a, b) => a.pos !== b.pos ? a.pos - b.pos : (a.isStart ? -1 : 1));

  // Build split points
  const splitPoints: number[] = [segmentStart];
  for (const b of boundaries) {
    if (splitPoints[splitPoints.length - 1] !== b.pos) {
      splitPoints.push(b.pos);
    }
  }
  if (splitPoints[splitPoints.length - 1] !== segEnd) {
    splitPoints.push(segEnd);
  }

  // For each sub-range, determine active entities
  const result: StyledSpan[] = [];
  for (let i = 0; i < splitPoints.length - 1; i++) {
    const rangeStart = splitPoints[i];
    const rangeEnd = splitPoints[i + 1];
    const subText = text.substring(rangeStart - segmentStart, rangeEnd - segmentStart);
    if (subText.length === 0) continue;

    const span = new StyledSpan();
    span.text = subText;
    for (const e of entities) {
      if (e.offset < rangeEnd && e.offset + e.length > rangeStart) {
        switch (e.type) {
          case 'bold': span.isBold = true; break;
          case 'italic': span.isItalic = true; break;
          case 'underline': span.isUnderline = true; break;
          case 'strikethrough': span.isStrikethrough = true; break;
          case 'code': case 'pre': case 'preCode': span.isCode = true; break;
          case 'url': case 'textUrl': case 'mention': case 'mentionName':
          case 'emailAddress': case 'phoneNumber': case 'hashtag':
          case 'cashtag': case 'botCommand': span.isLink = true; break;
          case 'spoiler': span.isSpoiler = true; break;
          default: break;
        }
      }
    }
    result.push(span);
  }
  return result;
}

class TgQuoteTextRange {
  start: number = 0;
  end: number = 0;
  isCollapsed: boolean = false;
}

class TgTextBodySegment {
  key: string = '';
  text: string = '';
  startOffset: number = 0; // position in original full text
  isQuote: boolean = false;
  isCollapsed: boolean = false;
  isLast: boolean = false;
}

@ComponentV2
export struct TgMessageTextBodyV2 {
  @Param text: string = '';
  @Param isOutgoing: boolean = false;
  @Param forceBreakAll: boolean = false;
  @Param quoteAccentHex: string = '';
  @Param metaReserveText: string = '';
  @Param quoteOffsets: number[] = [];
  @Param quoteLengths: number[] = [];
  @Param quoteCollapsedFlags: boolean[] = [];
  @Param textEntities: TextEntity[] = [];
  @Param contentWidth: number = 0;

  private safeText(value: string): string {
    return value.length > 0 ? value : ' ';
  }

  private wordBreakMode(): WordBreak {
    return this.forceBreakAll ? WordBreak.BREAK_ALL : WordBreak.BREAK_WORD;
  }

  private textLineBreakStrategy(): LineBreakStrategy {
    return this.forceBreakAll ? LineBreakStrategy.GREEDY : LineBreakStrategy.HIGH_QUALITY;
  }

  private bodyTextColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.MSG_TEXT_OUTGOING : TgUiTokens.MSG_TEXT_INCOMING;
  }

  private normalizedQuoteAccentHex(): string {
    const raw = this.quoteAccentHex.trim();
    if (raw.length === 0) {
      return '';
    }
    const value = raw.startsWith('#') ? raw.substring(1) : raw;
    if (value.length === 3) {
      return '#' + value[0] + value[0] + value[1] + value[1] + value[2] + value[2];
    }
    if (value.length === 6) {
      return '#' + value;
    }
    return '';
  }

  private hexToRgba(hex: string, alpha: number): string {
    const raw = hex.trim();
    const value = raw.startsWith('#') ? raw.substring(1) : raw;
    let normalized = '';
    if (value.length === 3) {
      normalized = '#' + value[0] + value[0] + value[1] + value[1] + value[2] + value[2];
    } else if (value.length === 6) {
      normalized = '#' + value;
    }
    if (normalized.length !== 7) {
      return '';
    }
    const red = Number.parseInt(normalized.substring(1, 3), 16);
    const green = Number.parseInt(normalized.substring(3, 5), 16);
    const blue = Number.parseInt(normalized.substring(5, 7), 16);
    if (Number.isNaN(red) || Number.isNaN(green) || Number.isNaN(blue)) {
      return '';
    }
    return `rgba(${red}, ${green}, ${blue}, ${alpha})`;
  }

  private quoteBarColor(): ResourceColor {
    const accent = this.normalizedQuoteAccentHex();
    if (accent.length > 0) {
      return accent;
    }
    return this.isOutgoing ? TgUiTokens.MSG_QUOTE_BAR_OUTGOING : TgUiTokens.MSG_QUOTE_BAR_INCOMING;
  }

  private quoteBackgroundColor(): ResourceColor {
    const alpha = this.isOutgoing ? 0.10 : 0.12;
    const accentBackground = this.hexToRgba(this.quoteAccentHex, alpha);
    if (accentBackground.length > 0) {
      return accentBackground;
    }
    return this.isOutgoing ? TgUiTokens.MSG_QUOTE_BG_OUTGOING : TgUiTokens.MSG_QUOTE_BG_INCOMING;
  }

  private quoteTextColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.MSG_QUOTE_TEXT_OUTGOING : TgUiTokens.MSG_QUOTE_TEXT_INCOMING;
  }

  private buildQuoteRanges(): TgQuoteTextRange[] {
    const result: TgQuoteTextRange[] = [];
    const count = Math.min(this.quoteOffsets.length, this.quoteLengths.length);
    if (count === 0 || this.text.length === 0) {
      return result;
    }

    for (let i = 0; i < count; i++) {
      const start = Math.max(0, Math.min(this.text.length, this.quoteOffsets[i]));
      const end = Math.max(start, Math.min(this.text.length, start + this.quoteLengths[i]));
      if (end <= start) {
        continue;
      }
      const range = new TgQuoteTextRange();
      range.start = start;
      range.end = end;
      range.isCollapsed = i < this.quoteCollapsedFlags.length ? this.quoteCollapsedFlags[i] : false;
      result.push(range);
    }

    result.sort((a, b) => a.start - b.start);

    const merged: TgQuoteTextRange[] = [];
    for (const range of result) {
      if (merged.length === 0) {
        merged.push(range);
        continue;
      }
      const last = merged[merged.length - 1];
      if (range.start <= last.end) {
        last.end = Math.max(last.end, range.end);
        last.isCollapsed = last.isCollapsed || range.isCollapsed;
      } else {
        merged.push(range);
      }
    }

    return merged;
  }

  private buildSegments(): TgTextBodySegment[] {
    const ranges = this.buildQuoteRanges();
    const result: TgTextBodySegment[] = [];

    if (ranges.length === 0) {
      const segment = new TgTextBodySegment();
      segment.key = 'plain_0';
      segment.text = this.text;
      segment.startOffset = 0;
      result.push(segment);
      return result;
    }

    let cursor = 0;
    let index = 0;
    for (const range of ranges) {
      if (range.start > cursor) {
        const textSegment = new TgTextBodySegment();
        textSegment.key = 'plain_' + index.toString();
        textSegment.text = this.text.substring(cursor, range.start);
        textSegment.startOffset = cursor;
        result.push(textSegment);
        index++;
      }

      const quoteSegment = new TgTextBodySegment();
      quoteSegment.key = 'quote_' + index.toString();
      quoteSegment.text = this.text.substring(range.start, range.end).trimEnd();
      quoteSegment.startOffset = range.start;
      quoteSegment.isQuote = true;
      quoteSegment.isCollapsed = range.isCollapsed;
      result.push(quoteSegment);
      index++;
      cursor = range.end;
    }

    if (cursor < this.text.length) {
      const tail = new TgTextBodySegment();
      tail.key = 'plain_' + index.toString();
      tail.text = this.text.substring(cursor);
      tail.startOffset = cursor;
      result.push(tail);
    }

    const filtered = result.filter((segment: TgTextBodySegment) => segment.text.length > 0);
    if (filtered.length > 0) {
      filtered[filtered.length - 1].isLast = true;
    }
    return filtered;
  }

  private linkColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.MSG_LINK_OUTGOING : TgUiTokens.MSG_LINK_INCOMING;
  }

  private codeBackground(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.MSG_CODE_BG_OUTGOING : TgUiTokens.MSG_CODE_BG_INCOMING;
  }

  private hasEntitiesInRange(segmentStart: number, segmentLength: number): boolean {
    for (const e of this.textEntities) {
      if (e.offset < segmentStart + segmentLength && e.offset + e.length > segmentStart) {
        return true;
      }
    }
    return false;
  }

  @Builder
  private buildPlainSegment(segmentText: string, segmentStart: number, reserveText: string) {
    Text() {
      if (this.hasEntitiesInRange(segmentStart, segmentText.length)) {
        ForEach(buildStyledSpans(segmentText, segmentStart, this.textEntities),
          (span: StyledSpan, index: number) => {
            Span(span.text)
              .fontSize(span.isCode ? TgUiTokens.MSG_CODE_SIZE : TgUiTokens.MSG_TEXT_SIZE)
              .fontWeight(span.isBold ? FontWeight.Bold : TgUiTokens.MSG_TEXT_WEIGHT)
              .fontStyle(span.isItalic ? FontStyle.Italic : FontStyle.Normal)
              .fontColor(span.isLink ? this.linkColor() : this.bodyTextColor())
              .decoration({
                type: span.isUnderline ? TextDecorationType.Underline
                  : (span.isStrikethrough ? TextDecorationType.LineThrough : TextDecorationType.None),
                color: span.isLink ? this.linkColor() : this.bodyTextColor()
              })
              .fontFamily(span.isCode ? 'monospace' : 'HarmonyOS Sans')
              .textBackgroundStyle(span.isCode ? {
                color: this.codeBackground(),
                radius: 4
              } : undefined)
          })
      } else {
        Span(this.safeText(segmentText))
          .fontSize(TgUiTokens.MSG_TEXT_SIZE)
          .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
          .fontColor(this.bodyTextColor())
      }
      if (reserveText.length > 0) {
        Span(reserveText)
          .fontSize(TgUiTokens.MSG_META_SIZE)
          .fontColor(Color.Transparent)
      }
    }
    .lineHeight(TgUiTokens.MSG_TEXT_LINE_HEIGHT)
    .textAlign(TextAlign.Start)
    .wordBreak(this.wordBreakMode())
    .lineBreakStrategy(this.textLineBreakStrategy())
  }

  @Builder
  private buildQuoteSegment(segmentText: string, isCollapsed: boolean, reserveText: string) {
    Row() {
      Column() {}
        .width(TgUiTokens.MSG_QUOTE_BAR_WIDTH)
        .alignSelf(ItemAlign.Stretch)
        .backgroundColor(this.quoteBarColor())

      Column() {
        if (reserveText.length > 0) {
          Text() {
            Span(this.safeText(segmentText))
              .fontSize(TgUiTokens.MSG_QUOTE_TEXT_SIZE)
              .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
              .fontColor(this.quoteTextColor())
            Span(reserveText)
              .fontSize(TgUiTokens.MSG_META_SIZE)
              .fontColor(Color.Transparent)
          }
          .lineHeight(TgUiTokens.MSG_QUOTE_TEXT_LINE_HEIGHT)
          .textAlign(TextAlign.Start)
          .wordBreak(this.wordBreakMode())
          .lineBreakStrategy(this.textLineBreakStrategy())
          .opacity(isCollapsed ? TgUiTokens.MSG_QUOTE_COLLAPSED_OPACITY : 1)
        } else {
          Text(this.safeText(segmentText))
            .fontSize(TgUiTokens.MSG_QUOTE_TEXT_SIZE)
            .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
            .lineHeight(TgUiTokens.MSG_QUOTE_TEXT_LINE_HEIGHT)
            .fontColor(this.quoteTextColor())
            .textAlign(TextAlign.Start)
            .wordBreak(this.wordBreakMode())
            .lineBreakStrategy(this.textLineBreakStrategy())
            .opacity(isCollapsed ? TgUiTokens.MSG_QUOTE_COLLAPSED_OPACITY : 1)
        }
      }
      .padding({
        left: TgUiTokens.MSG_QUOTE_BAR_GAP,
        right: TgUiTokens.MSG_QUOTE_PADDING_H,
        top: TgUiTokens.MSG_QUOTE_PADDING_V,
        bottom: TgUiTokens.MSG_QUOTE_PADDING_V
      })
      .layoutWeight(1)
    }
    .constraintSize({ minWidth: this.contentWidth > 0 ? this.contentWidth : undefined })
    .backgroundColor(this.quoteBackgroundColor())
    .borderRadius(TgUiTokens.MSG_QUOTE_RADIUS)
    .clip(true)
  }

  build() {
    Column({ space: TgUiTokens.MSG_QUOTE_SEGMENT_GAP }) {
      ForEach(this.buildSegments(), (segment: TgTextBodySegment) => {
        if (segment.isQuote) {
          this.buildQuoteSegment(segment.text, segment.isCollapsed, segment.isLast ? this.metaReserveText : '')
        } else {
          this.buildPlainSegment(segment.text, segment.startOffset, segment.isLast ? this.metaReserveText : '')
        }
      }, (segment: TgTextBodySegment) => segment.key)
    }
    .alignItems(HorizontalAlign.Start)
  }
}
