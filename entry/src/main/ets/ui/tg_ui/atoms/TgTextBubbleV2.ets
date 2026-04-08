import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgMessageBubbleBase } from './TgMessageBubbleBase';
import { TgReplySnippet } from './TgReplySnippet';
import { TgMessageTextBodyV2 } from './TgMessageTextBodyV2';
import { TgMessageMeta, TgMessageSendStatus } from './TgMessageMeta';

@ComponentV2
export struct TgTextBubbleV2 {
  @Param text: string = '';
  @Param isOutgoing: boolean = false;
  @Param isEmojiOnly: boolean = false;
  @Param forceBreakAll: boolean = false;
  @Param quoteOffsets: number[] = [];
  @Param quoteLengths: number[] = [];
  @Param quoteCollapsedFlags: boolean[] = [];
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param groupingFlags: string = 'none';

  @Param showSenderName: boolean = false;
  @Param senderName: string = '';
  @Param senderColorHex: string = '';

  @Param showReplySnippet: boolean = false;
  @Param replyAuthor: string = '';
  @Param replyAuthorColorHex: string = '';
  @Param replyPreview: string = '';
  @Param replyIsOutgoing: boolean = false;
  @Param replyIsQuote: boolean = false;
  @Param replyHasThumbnail: boolean = false;
  @Param replyThumbnailSrc: Resource | string = '';

  @Param timeText: string = '';
  @Param sendStatus: TgMessageSendStatus = TgMessageSendStatus.None;

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private bubbleRadius(): number | BorderRadiuses {
    const defaultRadius = this.isOutgoing ? TgUiTokens.BUBBLE_RADIUS_OUTGOING : TgUiTokens.BUBBLE_RADIUS_INCOMING;
    const smallRadius = 6;

    if (this.groupingFlags === 'none') {
      return defaultRadius;
    }

    if (this.isOutgoing) {
      if (this.groupingFlags === 'both') {
        return { topLeft: defaultRadius, bottomLeft: defaultRadius, topRight: smallRadius, bottomRight: smallRadius };
      }
      if (this.groupingFlags === 'top') {
        return { topLeft: defaultRadius, bottomLeft: defaultRadius, topRight: smallRadius, bottomRight: defaultRadius };
      }
      if (this.groupingFlags === 'bottom') {
        return { topLeft: defaultRadius, bottomLeft: defaultRadius, topRight: defaultRadius, bottomRight: smallRadius };
      }
    } else {
      if (this.groupingFlags === 'both') {
        return { topRight: defaultRadius, bottomRight: defaultRadius, topLeft: smallRadius, bottomLeft: smallRadius };
      }
      if (this.groupingFlags === 'top') {
        return { topRight: defaultRadius, bottomRight: defaultRadius, topLeft: smallRadius, bottomLeft: defaultRadius };
      }
      if (this.groupingFlags === 'bottom') {
        return { topRight: defaultRadius, bottomRight: defaultRadius, topLeft: defaultRadius, bottomLeft: smallRadius };
      }
    }

    return defaultRadius;
  }

  private maxBubbleWidth(): number {
    return TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio);
  }

  private hasQuoteBlocks(): boolean {
    const count = Math.min(this.quoteOffsets.length, this.quoteLengths.length);
    for (let i = 0; i < count; i++) {
      if (this.quoteLengths[i] > 0) {
        return true;
      }
    }
    return false;
  }

  private buildMetaReserve(): string {
    let reserve = '\u00A0\u00A0';
    if (this.timeText.length > 0) {
      reserve += this.timeText;
    } else {
      reserve += '\u00A0\u00A0\u00A0\u00A0\u00A0';
    }
    if (this.isOutgoing && this.sendStatus !== TgMessageSendStatus.None) {
      reserve += '\u00A0\u00A0\u00A0';
    }
    return reserve;
  }

  @Builder
  private buildInlineMeta() {
    TgMessageMeta({
      timeText: this.timeText,
      sendStatus: this.sendStatus,
      isOutgoing: this.isOutgoing,
      minWidth: 0,
      reserveTimeSlot: false,
      reserveStatusSlot: false,
      overlayMode: false
    })
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          if (this.showSenderName && this.senderName.length > 0) {
            Text(this.senderName)
              .fontSize(TgUiTokens.MSG_SENDER_NAME_SIZE)
              .fontWeight(TgUiTokens.MSG_SENDER_NAME_WEIGHT)
              .fontColor(this.senderColorHex.length > 0 ? this.senderColorHex : TgUiTokens.COLOR_TEXT_TITLE)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: this.maxBubbleWidth() - TgUiTokens.BUBBLE_PADDING_H * 2 })
              .margin({ bottom: TgUiTokens.SPACE_2 })
          }

          if (this.showReplySnippet) {
            TgReplySnippet({
              author: this.replyAuthor,
              preview: this.replyPreview,
              isOutgoing: this.replyIsOutgoing,
              isQuote: this.replyIsQuote,
              accentHex: this.replyAuthorColorHex,
              hasThumbnail: this.replyHasThumbnail,
              thumbnailSrc: this.replyThumbnailSrc,
              containerWidth: this.maxBubbleWidth()
            })
          }

          if (this.hasQuoteBlocks()) {
            TgMessageTextBodyV2({
              text: this.text,
              isOutgoing: this.isOutgoing,
              forceBreakAll: this.forceBreakAll,
              quoteAccentHex: !this.isOutgoing && this.senderColorHex.length > 0 ? this.senderColorHex : '',
              metaReserveText: this.buildMetaReserve(),
              quoteOffsets: this.quoteOffsets,
              quoteLengths: this.quoteLengths,
              quoteCollapsedFlags: this.quoteCollapsedFlags,
              contentWidth: this.maxBubbleWidth() - TgUiTokens.BUBBLE_PADDING_H * 2
            })
          } else {
            TgMessageBubbleBase({
              text: this.text,
              isOutgoing: this.isOutgoing,
              isEmojiOnly: this.isEmojiOnly,
              forceBreakAll: this.forceBreakAll,
              containerWidth: this.maxBubbleWidth(),
              noBubbleWrap: true,
              metaReserveText: this.buildMetaReserve()
            })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: TgUiTokens.BUBBLE_PADDING_H,
          right: TgUiTokens.BUBBLE_PADDING_H,
          top: this.showReplySnippet ? TgUiTokens.SPACE_4 : TgUiTokens.BUBBLE_PADDING_V,
          bottom: this.showReplySnippet ? TgUiTokens.SPACE_4 : TgUiTokens.BUBBLE_PADDING_V
        })

        if (this.hasQuoteBlocks()) {
          Row() {
            this.buildInlineMeta()
          }
          .margin({
            right: TgUiTokens.BUBBLE_PADDING_H,
            bottom: TgUiTokens.BUBBLE_PADDING_V
          })
        } else {
          Row() {
            this.buildInlineMeta()
          }
          .margin({
            right: TgUiTokens.BUBBLE_PADDING_H,
            bottom: TgUiTokens.BUBBLE_PADDING_V
          })
        }
      }
      .constraintSize({ maxWidth: this.maxBubbleWidth() })
      .backgroundColor(this.bubbleColor())
      .borderRadius(this.bubbleRadius())
    }
    .width('100%')
    .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
  }
}
