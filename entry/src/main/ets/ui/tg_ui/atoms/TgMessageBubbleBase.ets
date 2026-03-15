import { TgUiTokens } from '../tokens/TgUiTokens';

export enum TgMessageTextKind {
  Plain = 0,
  Link = 1,
  Mention = 2,
  Hashtag = 3
}

@ComponentV2
export struct TgMessageBubbleBase {
  @Param text: string = '';
  @Param isOutgoing: boolean = false;
  @Param isEmojiOnly: boolean = false;
  @Param kind: TgMessageTextKind = TgMessageTextKind.Plain;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param forceBreakAll: boolean = false;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  // When true, renders ONLY content (no Row wrapper, no bg, no radius)
  @Param noBubbleWrap: boolean = false;
  // Invisible trailing text to reserve space for inline time overlay (iOS/Android pattern)
  @Param metaReserveText: string = '';

  private safeText(): string {
    return this.text.length > 0 ? this.text : ' ';
  }

  private textColor(): ResourceColor {
    if (this.kind === TgMessageTextKind.Plain) {
      return this.isOutgoing ? TgUiTokens.MSG_TEXT_OUTGOING : TgUiTokens.MSG_TEXT_INCOMING;
    }
    return this.isOutgoing ? TgUiTokens.MSG_LINK_OUTGOING : TgUiTokens.MSG_LINK_INCOMING;
  }

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private bubbleRadius(): number {
    return this.isOutgoing ? TgUiTokens.BUBBLE_RADIUS_OUTGOING : TgUiTokens.BUBBLE_RADIUS_INCOMING;
  }

  private maxBubbleWidth(): number {
    return TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio);
  }

  private wordBreakMode(): WordBreak {
    return this.forceBreakAll ? WordBreak.BREAK_ALL : WordBreak.BREAK_WORD;
  }

  private textFontSize(): number {
    return this.isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_SIZE : TgUiTokens.MSG_TEXT_SIZE;
  }

  private textLineHeight(): number {
    return this.isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_LINE_HEIGHT : TgUiTokens.MSG_TEXT_LINE_HEIGHT;
  }

  private textLineBreakStrategy(): LineBreakStrategy {
    return this.forceBreakAll ? LineBreakStrategy.GREEDY : LineBreakStrategy.HIGH_QUALITY;
  }

  @Builder
  private buildText() {
    if (this.metaReserveText.length > 0) {
      // iOS/Android pattern: invisible trailing text reserves space for inline time overlay.
      // If last line has room, time sits inline. If not, text wraps and time gets its own line.
      Text() {
        Span(this.safeText())
          .fontSize(this.textFontSize())
          .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
          .fontColor(this.textColor())
        Span(this.metaReserveText)
          .fontSize(TgUiTokens.MSG_META_SIZE)
          .fontColor(Color.Transparent)
      }
      .lineHeight(this.textLineHeight())
      .textAlign(TextAlign.Start)
      .wordBreak(this.wordBreakMode())
      .lineBreakStrategy(this.textLineBreakStrategy())
    } else if (TgUiTokens.TEXT_MAX_LINES > 0) {
      Text(this.safeText())
        .fontSize(this.textFontSize())
        .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
        .lineHeight(this.textLineHeight())
        .fontColor(this.textColor())
        .textAlign(TextAlign.Start)
        .wordBreak(this.wordBreakMode())
        .lineBreakStrategy(this.textLineBreakStrategy())
        .maxLines(TgUiTokens.TEXT_MAX_LINES)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Text(this.safeText())
        .fontSize(this.textFontSize())
        .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
        .lineHeight(this.textLineHeight())
        .fontColor(this.textColor())
        .textAlign(TextAlign.Start)
        .wordBreak(this.wordBreakMode())
        .lineBreakStrategy(this.textLineBreakStrategy())
    }
  }

  build() {
    if (this.noBubbleWrap) {
      // Embedded mode — just the text content, no wrapper
      this.buildText()
    } else {
      // Standalone mode — full bubble with bg
      Row() {
        Row() {
          this.buildText()
        }
        .padding({
          left: TgUiTokens.BUBBLE_PADDING_H,
          right: TgUiTokens.BUBBLE_PADDING_H,
          top: TgUiTokens.BUBBLE_PADDING_V,
          bottom: TgUiTokens.BUBBLE_PADDING_V
        })
        .constraintSize({ maxWidth: this.maxBubbleWidth() })
        .backgroundColor(this.bubbleColor())
        .borderRadius(this.bubbleRadius())
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
    }
  }
}
