import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgReplySnippet {
  @Param author: string = '';
  @Param preview: string = '';
  @Param isOutgoing: boolean = false;
  @Param isQuote: boolean = false;
  @Param accentHex: string = '';
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

  private normalizedAccentHex(): string {
    const raw = this.accentHex.trim();
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

  private accentRgba(alpha: number): string {
    const normalized = this.normalizedAccentHex();
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

  private titleColor(): ResourceColor {
    const accent = this.normalizedAccentHex();
    if (accent.length > 0) {
      return accent;
    }
    return this.isOutgoing ? TgUiTokens.REPLY_SNIPPET_TITLE_OUTGOING : TgUiTokens.REPLY_SNIPPET_TITLE_INCOMING;
  }

  private previewColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.REPLY_SNIPPET_PREVIEW_OUTGOING : TgUiTokens.REPLY_SNIPPET_PREVIEW_INCOMING;
  }

  private barColor(): ResourceColor {
    const accent = this.normalizedAccentHex();
    if (accent.length > 0) {
      return accent;
    }
    return this.isOutgoing ? TgUiTokens.REPLY_SNIPPET_BAR_OUTGOING : TgUiTokens.REPLY_SNIPPET_BAR_INCOMING;
  }

  private bgColor(): ResourceColor {
    const accentBg = this.accentRgba(this.isOutgoing ? 0.10 : 0.12);
    if (accentBg.length > 0) {
      return accentBg;
    }
    return this.isOutgoing ? TgUiTokens.MSG_QUOTE_BG_OUTGOING : TgUiTokens.MSG_QUOTE_BG_INCOMING;
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

  private barHeight(): number {
    const titleLines = 1;
    const previewLines = this.isQuote ? 2 : 1;
    return TgUiTokens.REPLY_SNIPPET_TITLE_LINE_HEIGHT * titleLines +
      TgUiTokens.REPLY_SNIPPET_TEXT_GAP +
      TgUiTokens.REPLY_SNIPPET_PREVIEW_LINE_HEIGHT * previewLines;
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
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        Row() {
          Column({ space: TgUiTokens.REPLY_SNIPPET_TEXT_GAP }) {
            Text(this.resolvedAuthor())
              .fontSize(TgUiTokens.REPLY_SNIPPET_TITLE_SIZE)
              .fontWeight(TgUiTokens.REPLY_SNIPPET_TITLE_WEIGHT)
              .lineHeight(TgUiTokens.REPLY_SNIPPET_TITLE_LINE_HEIGHT)
              .fontColor(this.titleColor())
              .maxLines(this.maxTitleLines())
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.resolvedPreview())
              .fontSize(TgUiTokens.REPLY_SNIPPET_PREVIEW_SIZE)
              .fontWeight(TgUiTokens.REPLY_SNIPPET_PREVIEW_WEIGHT)
              .lineHeight(TgUiTokens.REPLY_SNIPPET_PREVIEW_LINE_HEIGHT)
              .fontColor(this.previewColor())
              .maxLines(this.maxPreviewLines())
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)

          this.buildThumbnailSlot()
        }
        .alignItems(this.isQuote ? VerticalAlign.Top : VerticalAlign.Center)
      }
      .padding({
        left: TgUiTokens.REPLY_SNIPPET_PADDING_H + TgUiTokens.REPLY_SNIPPET_BAR_WIDTH + TgUiTokens.REPLY_SNIPPET_BAR_GAP,
        right: TgUiTokens.REPLY_SNIPPET_PADDING_H,
        top: TgUiTokens.REPLY_SNIPPET_PADDING_V,
        bottom: TgUiTokens.REPLY_SNIPPET_PADDING_V
      })

      Column() {}
        .width(TgUiTokens.REPLY_SNIPPET_BAR_WIDTH)
        .height(this.barHeight() + TgUiTokens.REPLY_SNIPPET_PADDING_V * 2)
        .backgroundColor(this.barColor())
    }
    .constraintSize({
      maxWidth: this.maxSnippetWidth()
    })
    .backgroundColor(this.bgColor())
    .borderRadius(TgUiTokens.MSG_QUOTE_RADIUS)
    .clip(true)
  }
}
