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
    return Math.max(1, Math.floor(this.containerWidth * this.maxWidthRatio));
  }

  private wordBreakMode(): WordBreak {
    return this.forceBreakAll ? WordBreak.BREAK_ALL : WordBreak.BREAK_WORD;
  }

  @Builder
  private buildText() {
    if (TgUiTokens.TEXT_MAX_LINES > 0) {
      Text(this.safeText())
        .fontSize(this.isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_SIZE : TgUiTokens.MSG_TEXT_SIZE)
        .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
        .lineHeight(this.isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_LINE_HEIGHT : TgUiTokens.MSG_TEXT_LINE_HEIGHT)
        .fontColor(this.textColor())
        .textAlign(TextAlign.Start)
        .wordBreak(this.wordBreakMode())
        .maxLines(TgUiTokens.TEXT_MAX_LINES)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Text(this.safeText())
        .fontSize(this.isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_SIZE : TgUiTokens.MSG_TEXT_SIZE)
        .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
        .lineHeight(this.isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_LINE_HEIGHT : TgUiTokens.MSG_TEXT_LINE_HEIGHT)
        .fontColor(this.textColor())
        .textAlign(TextAlign.Start)
        .wordBreak(this.wordBreakMode())
    }
  }

  @Builder
  private buildBubble() {
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

  build() {
    Row() {
      this.buildBubble()
    }
    .width('100%')
    .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
  }
}
