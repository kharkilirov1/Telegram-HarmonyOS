// TgTextBubbleV3 — Engine-driven text message bubble.
// Receives pre-computed TextBubbleLayout — no auto-measurement, no transparent Span hack.
// Layout is computed by TgBubbleLayout.computeTextBubbleLayout().

import { TgUiTokens } from '../tokens/TgUiTokens'
import { TextBubbleLayout } from '../layout/TgBubbleLayoutTypes'
import { TextEntity } from '../../../core/model/AppState'
import { TgTextBodyV3 } from './TgTextBodyV3'
import { TgReplySnippet } from './TgReplySnippet'
import { TgMessageMeta, TgMessageSendStatus } from './TgMessageMeta'
import { TgLinkPreviewBubble } from './TgLinkPreviewBubble'

@ComponentV2
export struct TgTextBubbleV3 {
  // ── Layout (pre-computed) ──
  @Param layout: TextBubbleLayout | null = null

  // ── Content ──
  @Param text: string = ''
  @Param isOutgoing: boolean = false
  @Param isEmojiOnly: boolean = false
  @Param forceBreakAll: boolean = false

  // ── Link preview ──
  @Param linkPreviewUrl: string = ''
  @Param linkPreviewDisplayUrl: string = ''
  @Param linkPreviewSiteName: string = ''
  @Param linkPreviewTitle: string = ''
  @Param linkPreviewDescription: string = ''
  @Param linkPreviewAuthor: string = ''
  @Param linkPreviewPhotoPath: Resource | string = ''
  @Param linkPreviewPhotoMinithumb: Resource | string = ''
  @Param linkPreviewShowLargeMedia: boolean = false
  @Param linkPreviewShowMediaAboveDescription: boolean = false
  @Param linkPreviewShowAboveText: boolean = false

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
  @Param expandedQuoteIndices: number[] = []
  @Param textEntities: TextEntity[] = []
  @Param quoteAccentHex: string = ''

  // ── Meta ──
  @Param timeText: string = ''
  @Param editedText: string = ''
  @Param sendStatus: TgMessageSendStatus = TgMessageSendStatus.None

  // ── Visual ──
  @Param containerWidth: number = 360
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO
  @Param groupingFlags: string = 'none'

  // ── Events ──
  @Event onReplyTap: () => void = () => {}
  @Event onQuoteToggle: (quoteIndex: number) => void = (_: number) => {}

  // ── Computed helpers ──

  private bubbleColor(): ResourceColor {
    return this.isOutgoing
      ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG
      : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG
  }

  private bubbleRadius(): BorderRadiuses {
    const big = this.isOutgoing ? TgUiTokens.BUBBLE_RADIUS_OUTGOING : TgUiTokens.BUBBLE_RADIUS_INCOMING
    const small = TgUiTokens.BUBBLE_RADIUS_GROUPED

    switch (this.groupingFlags) {
      case 'top':
        return this.isOutgoing
          ? { topLeft: big, topRight: big, bottomLeft: big, bottomRight: small }
          : { topLeft: big, topRight: big, bottomLeft: small, bottomRight: big }
      case 'middle':
      case 'both':
        return this.isOutgoing
          ? { topLeft: big, topRight: small, bottomLeft: big, bottomRight: small }
          : { topLeft: small, topRight: big, bottomLeft: small, bottomRight: big }
      case 'bottom':
        // Tail-side bottom corner stays small so the tail continues the contour
        return this.isOutgoing
          ? { topLeft: big, topRight: small, bottomLeft: big, bottomRight: small }
          : { topLeft: small, topRight: big, bottomLeft: small, bottomRight: big }
      default: // 'none' — standalone (still carries a tail)
        return this.isOutgoing
          ? { topLeft: big, topRight: big, bottomLeft: big, bottomRight: small }
          : { topLeft: big, topRight: big, bottomLeft: small, bottomRight: big }
    }
  }

  private senderColor(): ResourceColor {
    return this.senderColorHex.length > 0 ? this.senderColorHex : TgUiTokens.COLOR_TEXT_TITLE
  }

  private hasLinkPreview(): boolean {
    return this.linkPreviewUrl.trim().length > 0
      || this.linkPreviewDisplayUrl.trim().length > 0
      || this.linkPreviewSiteName.trim().length > 0
      || this.linkPreviewTitle.trim().length > 0
      || this.linkPreviewDescription.trim().length > 0
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
        fillWidth: true,
        // The engine already shrink-wrapped the bubble; re-applying the bubble
        // ratio here would clip the snippet below the reserved content width.
        containerWidth: this.layout?.bubbleWidth ?? this.containerWidth,
        maxWidthRatio: 1.0,
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
          expandedQuoteIndices: this.expandedQuoteIndices,
          textEntities: this.textEntities,
          quoteAccentHex: this.quoteAccentHex,
          onQuoteToggle: (quoteIndex: number): void => {
            this.onQuoteToggle(quoteIndex)
          },
        })
      }
    }
  }

  @Builder
  buildLinkPreview() {
    if (this.hasLinkPreview()) {
      TgLinkPreviewBubble({
        url: this.linkPreviewUrl,
        displayUrl: this.linkPreviewDisplayUrl,
        siteName: this.linkPreviewSiteName,
        title: this.linkPreviewTitle,
        description: this.linkPreviewDescription,
        author: this.linkPreviewAuthor,
        photoPath: this.linkPreviewPhotoPath,
        photoMinithumb: this.linkPreviewPhotoMinithumb,
        showLargeMedia: this.linkPreviewShowLargeMedia,
        showMediaAboveDescription: this.linkPreviewShowMediaAboveDescription,
        isOutgoing: this.isOutgoing,
        availableWidth: this.layout?.contentWidth ?? TgUiTokens.LINK_PREVIEW_MIN_WIDTH,
      })
        .margin({
          top: !this.linkPreviewShowAboveText && this.text.length > 0 ? TgUiTokens.SPACE_6 : 0,
          bottom: this.linkPreviewShowAboveText && this.text.length > 0 ? TgUiTokens.SPACE_6 : 0,
        })
    }
  }

  @Builder
  buildMeta() {
    TgMessageMeta({
      timeText: this.timeText,
      editedText: this.editedText,
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
          if (this.linkPreviewShowAboveText) {
            this.buildLinkPreview()
          }
          this.buildTextContent()
          if (!this.linkPreviewShowAboveText) {
            this.buildLinkPreview()
          }

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
