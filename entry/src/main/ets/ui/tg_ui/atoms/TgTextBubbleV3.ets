// TgTextBubbleV3 — Engine-driven text message bubble.
// Receives pre-computed TextBubbleLayout — no auto-measurement, no transparent Span hack.
// Layout is computed by TgBubbleLayout.computeTextBubbleLayout().

import { TgUiTokens } from '../tokens/TgUiTokens'
import { TextBubbleLayout } from '../layout/TgBubbleLayoutTypes'
import { TextEntity } from '../../../core/model/AppState'
import { TgTextBodyV3 } from './TgTextBodyV3'
import { TgReplySnippet } from './TgReplySnippet'
import { TgMessageMeta, TgMessageSendStatus } from './TgMessageMeta'

@ComponentV2
export struct TgTextBubbleV3 {
  // ── Layout (pre-computed) ──
  @Param layout: TextBubbleLayout | null = null

  // ── Content ──
  @Param text: string = ''
  @Param isOutgoing: boolean = false
  @Param isEmojiOnly: boolean = false
  @Param forceBreakAll: boolean = false

  // ── Sender ──
  @Param showSenderName: boolean = false
  @Param senderName: string = ''
  @Param senderColorHex: string = ''

  // ── Reply ──
  @Param showReplySnippet: boolean = false
  @Param replyAuthor: string = ''
  @Param replyAuthorColorHex: string = ''
  @Param replyPreview: string = ''
  @Param replyIsOutgoing: boolean = false
  @Param replyIsQuote: boolean = false
  @Param replyHasThumbnail: boolean = false
  @Param replyThumbnailSrc: Resource | string = ''

  // ── Quote ──
  @Param quoteOffsets: number[] = []
  @Param quoteLengths: number[] = []
  @Param quoteCollapsedFlags: boolean[] = []
  @Param textEntities: TextEntity[] = []
  @Param quoteAccentHex: string = ''

  // ── Meta ──
  @Param timeText: string = ''
  @Param sendStatus: TgMessageSendStatus = TgMessageSendStatus.None

  // ── Visual ──
  @Param containerWidth: number = 360
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO
  @Param groupingFlags: string = 'none'

  // ── Events ──
  @Event onReplyTap: () => void = () => {}

  // ── Computed helpers ──

  private bubbleColor(): ResourceColor {
    return this.isOutgoing
      ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG
      : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG
  }

  private bubbleRadius(): BorderRadiuses {
    const big = this.isOutgoing ? TgUiTokens.BUBBLE_RADIUS_OUTGOING : TgUiTokens.BUBBLE_RADIUS_INCOMING
    const small = 6

    switch (this.groupingFlags) {
      case 'top':
        return this.isOutgoing
          ? { topLeft: big, topRight: big, bottomLeft: big, bottomRight: small }
          : { topLeft: big, topRight: big, bottomLeft: small, bottomRight: big }
      case 'middle':
        return this.isOutgoing
          ? { topLeft: big, topRight: small, bottomLeft: big, bottomRight: small }
          : { topLeft: small, topRight: big, bottomLeft: small, bottomRight: big }
      case 'bottom':
        return this.isOutgoing
          ? { topLeft: big, topRight: small, bottomLeft: big, bottomRight: big }
          : { topLeft: small, topRight: big, bottomLeft: big, bottomRight: big }
      default: // 'none' — standalone
        return { topLeft: big, topRight: big, bottomLeft: big, bottomRight: big }
    }
  }

  private senderColor(): ResourceColor {
    return this.senderColorHex.length > 0 ? this.senderColorHex : TgUiTokens.COLOR_TEXT_TITLE
  }

  @Builder
  buildSenderName() {
    if (this.showSenderName && this.senderName.length > 0) {
      Text(this.senderName)
        .fontSize(TgUiTokens.MSG_SENDER_NAME_SIZE)
        .fontWeight(TgUiTokens.MSG_SENDER_NAME_WEIGHT)
        .fontColor(this.senderColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(this.layout?.contentWidth ?? undefined)
        .margin({ bottom: TgUiTokens.SPACE_2 })
    }
  }

  @Builder
  buildReplySnippet() {
    if (this.showReplySnippet) {
      TgReplySnippet({
        author: this.replyAuthor,
        preview: this.replyPreview,
        isOutgoing: this.replyIsOutgoing,
        isQuote: this.replyIsQuote,
        accentHex: this.replyAuthorColorHex,
        hasThumbnail: this.replyHasThumbnail,
        thumbnailSrc: this.replyThumbnailSrc,
        containerWidth: this.layout?.bubbleWidth ?? this.containerWidth,
      })
        .margin({ bottom: TgUiTokens.SPACE_4 })
        .onClick(() => this.onReplyTap())
    }
  }

  @Builder
  buildTextContent() {
    if (this.text.length > 0) {
      if (this.isEmojiOnly) {
        Text(this.text)
          .fontSize(TgUiTokens.MSG_EMOJI_ONLY_SIZE)
          .lineHeight(TgUiTokens.MSG_EMOJI_ONLY_LINE_HEIGHT)
          .width(this.layout?.contentWidth ?? undefined)
      } else {
        TgTextBodyV3({
          text: this.text,
          isOutgoing: this.isOutgoing,
          contentWidth: this.layout?.contentWidth ?? 300,
          forceBreakAll: this.forceBreakAll,
          quoteOffsets: this.quoteOffsets,
          quoteLengths: this.quoteLengths,
          quoteCollapsedFlags: this.quoteCollapsedFlags,
          textEntities: this.textEntities,
          quoteAccentHex: this.quoteAccentHex,
        })
      }
    }
  }

  @Builder
  buildMeta() {
    TgMessageMeta({
      timeText: this.timeText,
      sendStatus: this.sendStatus,
      isOutgoing: this.isOutgoing,
    })
  }

  build() {
    Row() {
      // Bubble container with explicit engine-computed width
      Stack({ alignContent: this.layout?.metaInline ? Alignment.BottomEnd : Alignment.Bottom }) {
        // Content column
        Column() {
          this.buildSenderName()
          this.buildReplySnippet()
          this.buildTextContent()

          // Separate meta row when not inline
          if (this.layout !== null && !this.layout.metaInline) {
            Row() {
              this.buildMeta()
            }
            .width('100%')
            .justifyContent(FlexAlign.End)
          }
        }
        .padding({
          left: TgUiTokens.BUBBLE_PADDING_H,
          right: TgUiTokens.BUBBLE_PADDING_H,
          top: this.showReplySnippet ? TgUiTokens.SPACE_4 : TgUiTokens.BUBBLE_PADDING_V,
          bottom: TgUiTokens.BUBBLE_PADDING_V,
        })
        .alignItems(HorizontalAlign.Start)

        // Inline meta overlay (bottom-right of bubble)
        if (this.layout !== null && this.layout.metaInline) {
          Row() {
            this.buildMeta()
          }
          .padding({ right: TgUiTokens.BUBBLE_PADDING_H, bottom: TgUiTokens.BUBBLE_PADDING_V })
        }
      }
      .width(this.layout?.bubbleWidth ?? undefined)
      .constraintSize({
        maxWidth: TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio)
      })
      .backgroundColor(this.bubbleColor())
      .borderRadius(this.bubbleRadius())
    }
    .width('100%')
    .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
  }
}
