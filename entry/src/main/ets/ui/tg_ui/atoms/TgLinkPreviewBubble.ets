import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgLinkPreviewBubble {
  @Param url: string = '';
  @Param displayUrl: string = '';
  @Param siteName: string = '';
  @Param title: string = '';
  @Param description: string = '';
  @Param author: string = '';
  @Param photoPath: Resource | string = '';
  @Param photoMinithumb: Resource | string = '';
  @Param showLargeMedia: boolean = false;
  @Param showMediaAboveDescription: boolean = false;
  @Param isOutgoing: boolean = false;
  @Param availableWidth: number = TgUiTokens.LINK_PREVIEW_MIN_WIDTH;

  private accentColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.LINK_PREVIEW_ACCENT_OUTGOING
      : TgUiTokens.LINK_PREVIEW_ACCENT_INCOMING;
  }

  private titleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.LINK_PREVIEW_TITLE_OUTGOING
      : TgUiTokens.LINK_PREVIEW_TITLE_INCOMING;
  }

  private descriptionColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.LINK_PREVIEW_DESCRIPTION_OUTGOING
      : TgUiTokens.LINK_PREVIEW_DESCRIPTION_INCOMING;
  }

  private previewBackgroundColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.LINK_PREVIEW_BG_OUTGOING
      : TgUiTokens.LINK_PREVIEW_BG_INCOMING;
  }

  private resolvedSiteName(): string {
    if (this.siteName.trim().length > 0) {
      return this.siteName.trim();
    }
    if (this.displayUrl.trim().length > 0) {
      return this.displayUrl.trim();
    }
    return this.url.trim();
  }

  private resolvedTitle(): string {
    return this.title.trim().length > 0 ? this.title.trim() : this.author.trim();
  }

  private hasSource(value: Resource | string): boolean {
    return typeof value !== 'string' || value.trim().length > 0;
  }

  private hasMedia(): boolean {
    return this.hasSource(this.photoPath) || this.hasSource(this.photoMinithumb);
  }

  private mediaSource(): Resource | string {
    return this.hasSource(this.photoPath) ? this.photoPath : this.photoMinithumb;
  }

  private innerWidth(): number {
    return Math.max(1, this.availableWidth - TgUiTokens.LINK_PREVIEW_RAIL_WIDTH
      - TgUiTokens.LINK_PREVIEW_RAIL_GAP - TgUiTokens.LINK_PREVIEW_RIGHT_INSET);
  }

  private compactTextWidth(): number {
    if (!this.hasMedia() || this.showLargeMedia) {
      return this.innerWidth();
    }
    return Math.max(1, this.innerWidth() - TgUiTokens.LINK_PREVIEW_SMALL_MEDIA_SIZE
      - TgUiTokens.LINK_PREVIEW_MEDIA_GAP);
  }

  private largeMediaHeight(): number {
    const natural = this.innerWidth() / TgUiTokens.LINK_PREVIEW_LARGE_MEDIA_ASPECT_RATIO;
    return Math.max(TgUiTokens.LINK_PREVIEW_LARGE_MEDIA_MIN_HEIGHT,
      Math.min(TgUiTokens.LINK_PREVIEW_LARGE_MEDIA_MAX_HEIGHT, natural));
  }

  @Builder
  private buildSiteAndTitle(contentWidth: number) {
    Column({ space: TgUiTokens.LINK_PREVIEW_TEXT_GAP }) {
      if (this.resolvedSiteName().length > 0) {
        Text(this.resolvedSiteName())
          .fontSize(TgUiTokens.LINK_PREVIEW_SITE_SIZE)
          .lineHeight(TgUiTokens.LINK_PREVIEW_SITE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor())
          .maxLines(TgUiTokens.LINK_PREVIEW_MAX_SITE_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (this.resolvedTitle().length > 0) {
        Text(this.resolvedTitle())
          .fontSize(TgUiTokens.LINK_PREVIEW_TITLE_SIZE)
          .lineHeight(TgUiTokens.LINK_PREVIEW_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.titleColor())
          .maxLines(TgUiTokens.LINK_PREVIEW_MAX_TITLE_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width(contentWidth)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildDescription(contentWidth: number) {
    if (this.description.trim().length > 0) {
      Text(this.description.trim())
        .fontSize(TgUiTokens.LINK_PREVIEW_DESCRIPTION_SIZE)
        .lineHeight(TgUiTokens.LINK_PREVIEW_DESCRIPTION_LINE_HEIGHT)
        .fontColor(this.descriptionColor())
        .maxLines(TgUiTokens.LINK_PREVIEW_MAX_DESCRIPTION_LINES)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(contentWidth)
    }
  }

  @Builder
  private buildLargeMedia() {
    if (this.hasMedia()) {
      Image(this.mediaSource())
        .width(this.innerWidth())
        .height(this.largeMediaHeight())
        .objectFit(ImageFit.Cover)
        .borderRadius(TgUiTokens.LINK_PREVIEW_LARGE_MEDIA_RADIUS)
        .backgroundColor(TgUiTokens.LINK_PREVIEW_MEDIA_PLACEHOLDER)
    }
  }

  @Builder
  private buildCompactContent() {
    Row({ space: TgUiTokens.LINK_PREVIEW_MEDIA_GAP }) {
      Column({ space: TgUiTokens.LINK_PREVIEW_TEXT_GAP }) {
        this.buildSiteAndTitle(this.compactTextWidth())
        this.buildDescription(this.compactTextWidth())
      }
      .width(this.compactTextWidth())
      .alignItems(HorizontalAlign.Start)

      if (this.hasMedia()) {
        Image(this.mediaSource())
          .width(TgUiTokens.LINK_PREVIEW_SMALL_MEDIA_SIZE)
          .height(TgUiTokens.LINK_PREVIEW_SMALL_MEDIA_SIZE)
          .objectFit(ImageFit.Cover)
          .borderRadius(TgUiTokens.LINK_PREVIEW_SMALL_MEDIA_RADIUS)
          .backgroundColor(TgUiTokens.LINK_PREVIEW_MEDIA_PLACEHOLDER)
      }
    }
    .width(this.innerWidth())
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildLargeContent() {
    Column({ space: TgUiTokens.LINK_PREVIEW_MEDIA_GAP }) {
      this.buildSiteAndTitle(this.innerWidth())
      if (this.showMediaAboveDescription) {
        this.buildLargeMedia()
        this.buildDescription(this.innerWidth())
      } else {
        this.buildDescription(this.innerWidth())
        this.buildLargeMedia()
      }
    }
    .width(this.innerWidth())
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row() {
        if (this.showLargeMedia && this.hasMedia()) {
          this.buildLargeContent()
        } else {
          this.buildCompactContent()
        }
      }
      .width(this.availableWidth)
      .padding({
        left: TgUiTokens.LINK_PREVIEW_RAIL_WIDTH + TgUiTokens.LINK_PREVIEW_RAIL_GAP,
        right: TgUiTokens.LINK_PREVIEW_RIGHT_INSET,
        top: TgUiTokens.LINK_PREVIEW_PADDING_V,
        bottom: TgUiTokens.LINK_PREVIEW_PADDING_V
      })
      .backgroundColor(this.previewBackgroundColor())
      .borderRadius(TgUiTokens.LINK_PREVIEW_RADIUS)

      Column()
        .width(TgUiTokens.LINK_PREVIEW_RAIL_WIDTH)
        .height('100%')
        .backgroundColor(this.accentColor())
        .borderRadius(TgUiTokens.LINK_PREVIEW_RAIL_RADIUS)
    }
    .width(this.availableWidth)
  }
}
