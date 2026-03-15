import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgReplySnippet {
  @Param author: string = '';
  @Param preview: string = '';
  @Param isOutgoing: boolean = false;
  @Param isQuote: boolean = false;
  @Param hasThumbnail: boolean = false;
  @Param thumbnailSrc: Resource | string = $r('app.media.app_icon_transparent');
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;

  private resolvedAuthor(): string {
    return this.author.length > 0 ? this.author : ' ';
  }

  private resolvedPreview(): string {
    return this.preview.length > 0 ? this.preview : ' ';
  }

  private titleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.REPLY_SNIPPET_TITLE_OUTGOING : TgUiTokens.REPLY_SNIPPET_TITLE_INCOMING;
  }

  private previewColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.REPLY_SNIPPET_PREVIEW_OUTGOING : TgUiTokens.REPLY_SNIPPET_PREVIEW_INCOMING;
  }

  private barColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.REPLY_SNIPPET_BAR_OUTGOING : TgUiTokens.REPLY_SNIPPET_BAR_INCOMING;
  }

  private bgColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.REPLY_SNIPPET_BG_OUTGOING : TgUiTokens.REPLY_SNIPPET_BG_INCOMING;
  }

  private maxSnippetWidth(): number {
    return TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio);
  }

  private quoteMarkColor(): ResourceColor {
    return this.titleColor();
  }

  private maxTitleLines(): number {
    return this.isQuote ? TgUiTokens.REPLY_SNIPPET_QUOTE_MAX_TITLE_LINES : TgUiTokens.REPLY_SNIPPET_MAX_TITLE_LINES;
  }

  private maxPreviewLines(): number {
    return this.isQuote ? TgUiTokens.REPLY_SNIPPET_QUOTE_MAX_PREVIEW_LINES : TgUiTokens.REPLY_SNIPPET_MAX_PREVIEW_LINES;
  }

  @Builder
  private buildThumbnailSlot() {
    if (this.hasThumbnail) {
      Image(this.thumbnailSrc)
        .width(TgUiTokens.REPLY_SNIPPET_THUMB_SIZE)
        .height(TgUiTokens.REPLY_SNIPPET_THUMB_SIZE)
        .objectFit(ImageFit.Cover)
        .borderRadius(TgUiTokens.REPLY_SNIPPET_THUMB_RADIUS)
        .clip(true)
        .margin({ left: TgUiTokens.REPLY_SNIPPET_THUMB_GAP })
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Row()
          .width(TgUiTokens.REPLY_SNIPPET_BAR_WIDTH)
          .height('100%')
          .backgroundColor(this.barColor())
          .borderRadius(TgUiTokens.REPLY_SNIPPET_BAR_RADIUS)

        Row() {
          Column({ space: TgUiTokens.REPLY_SNIPPET_TEXT_GAP }) {
            Text(this.resolvedAuthor())
              .fontSize(TgUiTokens.REPLY_SNIPPET_TITLE_SIZE)
              .fontWeight(TgUiTokens.REPLY_SNIPPET_TITLE_WEIGHT)
              .lineHeight(TgUiTokens.REPLY_SNIPPET_TITLE_LINE_HEIGHT)
              .fontColor(this.titleColor())
              .maxLines(this.maxTitleLines())
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')

            Text(this.resolvedPreview())
              .fontSize(TgUiTokens.REPLY_SNIPPET_PREVIEW_SIZE)
              .fontWeight(TgUiTokens.REPLY_SNIPPET_PREVIEW_WEIGHT)
              .lineHeight(TgUiTokens.REPLY_SNIPPET_PREVIEW_LINE_HEIGHT)
              .fontColor(this.previewColor())
              .maxLines(this.maxPreviewLines())
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .layoutWeight(1)

          this.buildThumbnailSlot()
        }
        .layoutWeight(1)
        .alignItems(this.isQuote ? VerticalAlign.Top : VerticalAlign.Center)
        .margin({ left: TgUiTokens.REPLY_SNIPPET_BAR_GAP })
      }
      .constraintSize({
        maxWidth: this.maxSnippetWidth(),
        minHeight: TgUiTokens.REPLY_SNIPPET_MIN_HEIGHT
      })
      .padding({
        left: TgUiTokens.REPLY_SNIPPET_PADDING_H,
        right: TgUiTokens.REPLY_SNIPPET_PADDING_H,
        top: TgUiTokens.REPLY_SNIPPET_PADDING_V,
        bottom: TgUiTokens.REPLY_SNIPPET_PADDING_V
      })
      .alignItems(this.isQuote ? VerticalAlign.Top : VerticalAlign.Center)
      .backgroundColor(this.bgColor())
      .borderRadius(TgUiTokens.REPLY_SNIPPET_BG_RADIUS)
      .clip(true)

      if (this.isQuote) {
        Text('❞')
          .fontSize(TgUiTokens.REPLY_SNIPPET_QUOTE_MARK_SIZE)
          .lineHeight(TgUiTokens.REPLY_SNIPPET_QUOTE_MARK_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.quoteMarkColor())
          .opacity(0.7)
          .margin({
            top: TgUiTokens.REPLY_SNIPPET_QUOTE_MARK_TOP,
            right: TgUiTokens.REPLY_SNIPPET_QUOTE_MARK_RIGHT
          })
      }
    }
  }
}
