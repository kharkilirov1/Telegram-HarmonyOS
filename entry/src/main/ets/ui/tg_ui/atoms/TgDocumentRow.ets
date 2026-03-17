import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgDocumentRow {
  @Param fileName: string = '';
  @Param fileSize: number = 0;
  @Param mimeType: string = '';
  @Param isOutgoing: boolean = false;
  @Param documentPath: string = ''; // file:// URI when downloaded
  @Param downloadProgress: number = -1; // -1: hidden, 0..1: visible
  @Param isDownloading: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param noBubbleWrap: boolean = false;
  @Event onTap: () => void = () => {};
  @Event onDownloadToggle: () => void = () => {};

  private safeFileName(): string {
    const trimmed = this.fileName.trim();
    return trimmed.length > 0 ? trimmed : 'File';
  }

  private titleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.DOCUMENT_ROW_TITLE_OUTGOING : TgUiTokens.DOCUMENT_ROW_TITLE_INCOMING;
  }

  private metaColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.DOCUMENT_ROW_META_OUTGOING : TgUiTokens.DOCUMENT_ROW_META_INCOMING;
  }

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private computedBubbleWidth(): number {
    const byRatio = TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio);
    const maxAllowed = Math.min(byRatio, TgUiTokens.DOCUMENT_ROW_MAX_WIDTH);
    const minAllowed = Math.min(TgUiTokens.DOCUMENT_ROW_MIN_WIDTH, Math.max(1, Math.floor(this.containerWidth)));
    return Math.max(minAllowed, maxAllowed);
  }

  private hasProgress(): boolean {
    return this.downloadProgress >= 0 && this.downloadProgress < 1;
  }

  private normalizedProgress(): number {
    return Math.max(0, Math.min(1, this.downloadProgress));
  }

  private progressPercentLabel(): string {
    return Math.floor(this.normalizedProgress() * 100).toString() + '%';
  }

  private progressWidthLabel(): string {
    const percent = Math.floor(this.normalizedProgress() * 100);
    const clamped = Math.max(TgUiTokens.DOCUMENT_ROW_PROGRESS_MIN_VISIBLE_PERCENT, percent);
    return clamped.toString() + '%';
  }

  private detectExtension(): string {
    const name = this.safeFileName();
    const lastDot = name.lastIndexOf('.');
    if (lastDot <= 0 || lastDot === name.length - 1) {
      return '';
    }
    return name.substring(lastDot + 1).toUpperCase();
  }

  private mimeLabel(): string {
    const mime = this.mimeType.trim();
    if (mime.length === 0) {
      const ext = this.detectExtension();
      return ext.length > 0 ? ext : 'FILE';
    }
    const slashIndex = mime.indexOf('/');
    if (slashIndex >= 0 && slashIndex < mime.length - 1) {
      return mime.substring(slashIndex + 1).toUpperCase();
    }
    return mime.toUpperCase();
  }

  private formatFileSize(bytes: number): string {
    if (bytes <= 0) {
      return '';
    }
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      const value = bytes / gb;
      return value.toFixed(1) + ' GB';
    }
    if (bytes >= mb) {
      const value = bytes / mb;
      return value.toFixed(1) + ' MB';
    }
    if (bytes >= kb) {
      const value = bytes / kb;
      return value.toFixed(1) + ' KB';
    }
    return bytes.toString() + ' B';
  }

  private extensionBadgeText(): string {
    const ext = this.detectExtension();
    const label = ext.length > 0 ? ext : this.mimeLabel();
    if (label.length <= TgUiTokens.DOCUMENT_ROW_EXTENSION_MAX_LEN) {
      return label;
    }
    return label.substring(0, TgUiTokens.DOCUMENT_ROW_EXTENSION_MAX_LEN);
  }

  private shouldShowExtensionBadge(): boolean {
    return !this.hasProgress() && !this.isDownloading && this.extensionBadgeText().trim().length > 0;
  }

  private metaLine(): string {
    const sizeLabel = this.formatFileSize(this.fileSize);
    if (this.hasProgress()) {
      if (sizeLabel.length > 0) {
        return this.progressPercentLabel() + ' • ' + sizeLabel;
      }
      return this.progressPercentLabel();
    }
    if (this.isDownloading) {
      if (sizeLabel.length > 0) {
        return 'Downloading • ' + sizeLabel;
      }
      return 'Downloading';
    }
    const mime = this.mimeLabel();
    if (sizeLabel.length > 0) {
      return mime + ' • ' + sizeLabel;
    }
    return mime;
  }

  private isDownloaded(): boolean {
    return this.documentPath.length > 0;
  }

  private isImageOrPdf(): boolean {
    const mime = this.mimeType.toLowerCase();
    return mime.startsWith('image/') || mime === 'application/pdf';
  }

  private leadingIconResource(): Resource {
    if (this.isDownloaded()) {
      return TgUiTokens.ICON_RES_DOCUMENT;
    }
    return TgUiTokens.ICON_RES_DOWNLOAD;
  }

  @Builder
  private buildActionChip() {
    if (!this.hasProgress() && !this.isDownloading) {
      Row() {
        TgIcon({
          src: this.leadingIconResource(),
          iconSize: TgUiTokens.DOCUMENT_ROW_ACTION_ICON_SIZE,
          tintColor: TgUiTokens.DOCUMENT_ROW_ACTION_ICON
        })
      }
      .width(TgUiTokens.DOCUMENT_ROW_ACTION_SIZE)
      .height(TgUiTokens.DOCUMENT_ROW_ACTION_SIZE)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(TgUiTokens.DOCUMENT_ROW_ACTION_BG)
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
      .margin({
        right: TgUiTokens.DOCUMENT_ROW_ACTION_OFFSET,
        bottom: TgUiTokens.DOCUMENT_ROW_ACTION_OFFSET
      })
      .onClick((event: ClickEvent) => {
        this.onDownloadToggle();
      })
    }
  }

  @Builder
  private buildTilePrimaryFace() {
    if (this.isDownloading) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.hasProgress()) {
          Progress({
            value: this.normalizedProgress() * 100,
            total: 100,
            type: ProgressType.Ring
          })
            .width(TgUiTokens.DOCUMENT_ROW_ICON_BOX_SIZE)
            .height(TgUiTokens.DOCUMENT_ROW_ICON_BOX_SIZE)
            .color('#FFFFFF')
            .backgroundColor(Color.Transparent)
            .style({ strokeWidth: TgUiTokens.DOCUMENT_ROW_PROGRESS_RING_STROKE })
        } else {
          LoadingProgress()
            .width(TgUiTokens.DOCUMENT_ROW_ICON_SIZE)
            .height(TgUiTokens.DOCUMENT_ROW_ICON_SIZE)
            .color('#FFFFFF')
        }
        Image($r('sys.media.ohos_ic_public_cancel'))
          .width(16).height(16).fillColor('#FFFFFF')
      }
      .width(TgUiTokens.DOCUMENT_ROW_ICON_BOX_SIZE)
      .height(TgUiTokens.DOCUMENT_ROW_ICON_BOX_SIZE)
      .backgroundColor('#40000000') // Dark overlay
      .borderRadius(TgUiTokens.DOCUMENT_ROW_ICON_RADIUS)
    } else if (this.isDownloaded() && this.isImageOrPdf()) {
      Image(this.documentPath)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
    } else if (this.shouldShowExtensionBadge()) {
      Text(this.extensionBadgeText())
        .fontSize(TgUiTokens.DOCUMENT_ROW_EXTENSION_SIZE)
        .lineHeight(TgUiTokens.DOCUMENT_ROW_EXTENSION_LINE_HEIGHT)
        .fontWeight(FontWeight.Bold)
        .fontColor(TgUiTokens.DOCUMENT_ROW_ICON_TINT)
        .maxLines(1)
        .textAlign(TextAlign.Center)
    } else {
      TgIcon({
        src: this.leadingIconResource(),
        iconSize: TgUiTokens.DOCUMENT_ROW_ICON_SIZE,
        tintColor: TgUiTokens.DOCUMENT_ROW_ICON_TINT
      })
    }
  }

  @Builder
  private buildProgressBar() {
    if (this.hasProgress()) {
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(TgUiTokens.DOCUMENT_ROW_PROGRESS_HEIGHT)
          .backgroundColor(TgUiTokens.DOCUMENT_ROW_PROGRESS_BG)
          .borderRadius(TgUiTokens.DOCUMENT_ROW_PROGRESS_RADIUS)

        Row()
          .width(this.progressWidthLabel())
          .height(TgUiTokens.DOCUMENT_ROW_PROGRESS_HEIGHT)
          .backgroundColor(TgUiTokens.DOCUMENT_ROW_PROGRESS_FILL)
          .borderRadius(TgUiTokens.DOCUMENT_ROW_PROGRESS_RADIUS)
      }
      .width('100%')
      .margin({ top: TgUiTokens.DOCUMENT_ROW_PROGRESS_TOP_GAP })
      .transition({ type: TransitionType.All, opacity: 0 })
    }
  }

  @Builder
  private buildLeadingTile() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Row() {
        this.buildTilePrimaryFace()
      }
      .width(TgUiTokens.DOCUMENT_ROW_ICON_BOX_SIZE)
      .height(TgUiTokens.DOCUMENT_ROW_ICON_BOX_SIZE)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(TgUiTokens.DOCUMENT_ROW_ICON_BG)
      .borderRadius(TgUiTokens.DOCUMENT_ROW_ICON_RADIUS)
      .clip(true)
      .onClick((event: ClickEvent) => {
        if (!this.isDownloaded() || this.hasProgress() || this.isDownloading) {
          this.onDownloadToggle();
        }
      })

      this.buildActionChip()
    }
    .width(TgUiTokens.DOCUMENT_ROW_ICON_BOX_SIZE)
    .height(TgUiTokens.DOCUMENT_ROW_ICON_BOX_SIZE)
  }

  @Builder
  private buildBubble() {
    Row({ space: TgUiTokens.DOCUMENT_ROW_CONTENT_GAP }) {
      this.buildLeadingTile()

      Column({ space: TgUiTokens.DOCUMENT_ROW_TEXT_GAP }) {
        Text(this.safeFileName())
          .fontSize(TgUiTokens.DOCUMENT_ROW_TITLE_SIZE)
          .lineHeight(TgUiTokens.DOCUMENT_ROW_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.titleColor())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.metaLine())
          .fontSize(TgUiTokens.DOCUMENT_ROW_META_SIZE)
          .lineHeight(TgUiTokens.DOCUMENT_ROW_META_LINE_HEIGHT)
          .fontColor(this.metaColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        this.buildProgressBar()
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width(this.computedBubbleWidth())
    .padding({
      left: TgUiTokens.DOCUMENT_ROW_PADDING_H,
      right: TgUiTokens.DOCUMENT_ROW_PADDING_H,
      top: TgUiTokens.DOCUMENT_ROW_PADDING_V,
      bottom: TgUiTokens.DOCUMENT_ROW_PADDING_V
    })
    .backgroundColor(this.bubbleColor())
    .borderRadius(TgUiTokens.DOCUMENT_ROW_RADIUS)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildContent() {
    Row({ space: TgUiTokens.DOCUMENT_ROW_CONTENT_GAP }) {
      this.buildLeadingTile()

      Column({ space: TgUiTokens.DOCUMENT_ROW_TEXT_GAP }) {
        Text(this.safeFileName())
          .fontSize(TgUiTokens.DOCUMENT_ROW_TITLE_SIZE)
          .lineHeight(TgUiTokens.DOCUMENT_ROW_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.titleColor())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.metaLine())
          .fontSize(TgUiTokens.DOCUMENT_ROW_META_SIZE)
          .lineHeight(TgUiTokens.DOCUMENT_ROW_META_LINE_HEIGHT)
          .fontColor(this.metaColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        this.buildProgressBar()
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width(this.computedBubbleWidth())
    .padding({
      left: TgUiTokens.DOCUMENT_ROW_PADDING_H,
      right: TgUiTokens.DOCUMENT_ROW_PADDING_H,
      top: TgUiTokens.DOCUMENT_ROW_PADDING_V,
      bottom: TgUiTokens.DOCUMENT_ROW_PADDING_V
    })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    if (this.noBubbleWrap) {
      Column() {
        this.buildContent()
      }
      .onClick(() => this.onTap())
    } else {
      Row() {
        this.buildBubble()
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .onClick(() => this.onTap())
    }
  }
}

