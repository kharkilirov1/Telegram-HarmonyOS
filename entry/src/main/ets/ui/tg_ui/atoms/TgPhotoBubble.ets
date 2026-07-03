import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgPhotoBubble {
  @Param photoPath: string | Resource = '';
  @Param photoMinithumb: string = '';
  @Param hasLocalPhoto: boolean = false;
  @Param isDownloading: boolean = false;
  @Param isDownloadFailed: boolean = false;
  @Param downloadProgress: number = -1;
  @Param caption: string = '';
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param photoWidth: number = 0;
  @Param photoHeight: number = 0;
  @Param noBubbleWrap: boolean = false;
  @Param useRegularMaxDimensions: boolean = false;
  @Event onPhotoTap: () => void = () => {};
  @Event onDownloadToggle: () => void = () => {};

  private usesRegularDimensions(): boolean {
    return this.useRegularMaxDimensions || TgUiTokens.isRegularMessageWidth(this.containerWidth);
  }

  private hasPhoto(): boolean {
    if (typeof this.photoPath === 'string') {
      return this.photoPath.trim().length > 0;
    }
    return true;
  }

  private hasCaption(): boolean {
    return this.caption.trim().length > 0;
  }

  private hasDeterminateProgress(): boolean {
    return this.downloadProgress >= 0 && this.downloadProgress < 1;
  }

  private normalizedDownloadProgress(): number {
    return Math.max(0, Math.min(1, this.downloadProgress));
  }

  private downloadPercentLabel(): string {
    const percent = Math.floor(this.normalizedDownloadProgress() * 100);
    return Math.max(1, Math.min(99, percent)).toString() + '%';
  }

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private captionColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.PHOTO_BUBBLE_CAPTION_TEXT_OUTGOING : TgUiTokens.PHOTO_BUBBLE_CAPTION_TEXT_INCOMING;
  }

  private maxBubbleBoxWidth(): number {
    const byRatio = TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio);
    const maxAllowed = Math.min(byRatio,
      this.usesRegularDimensions() ? TgUiTokens.PHOTO_BUBBLE_MAX_WIDTH_REGULAR : TgUiTokens.PHOTO_BUBBLE_MAX_WIDTH);
    const minAllowed = Math.min(TgUiTokens.PHOTO_BUBBLE_MIN_WIDTH, Math.max(1, Math.floor(this.containerWidth)));
    return Math.max(minAllowed, maxAllowed);
  }

  private maxMediaWidth(): number {
    return Math.max(1, this.maxBubbleBoxWidth() - TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET * 2);
  }

  private maxMediaHeight(): number {
    return this.usesRegularDimensions() ? TgUiTokens.PHOTO_BUBBLE_MAX_HEIGHT_REGULAR : TgUiTokens.PHOTO_BUBBLE_MAX_HEIGHT;
  }

  private computedMediaSize(): SizeOptions {
    const maxWidth = this.maxMediaWidth();
    const maxHeight = this.maxMediaHeight();
    if (this.photoWidth > 0 && this.photoHeight > 0) {
      let scale = Math.min(maxWidth / this.photoWidth, maxHeight / this.photoHeight);
      if (!isFinite(scale) || scale <= 0) {
        scale = 1;
      }

      let fittedWidth = Math.max(1, Math.floor(this.photoWidth * scale));
      let fittedHeight = Math.max(1, Math.floor(this.photoHeight * scale));

      const minMediaWidth = Math.max(1, TgUiTokens.PHOTO_BUBBLE_MIN_WIDTH - TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET * 2);
      if (fittedWidth < minMediaWidth) {
        const expandedHeight = Math.max(1, Math.floor(minMediaWidth * this.photoHeight / this.photoWidth));
        if (expandedHeight <= maxHeight) {
          fittedWidth = minMediaWidth;
          fittedHeight = expandedHeight;
        }
      }

      return {
        width: Math.min(maxWidth, fittedWidth),
        height: Math.min(maxHeight, fittedHeight)
      };
    }

    const squareSide = Math.min(maxWidth, Math.max(TgUiTokens.PHOTO_BUBBLE_MIN_HEIGHT, maxWidth));
    return {
      width: squareSide,
      height: Math.min(squareSide, maxHeight)
    };
  }

  private computedBubbleWidth(): number {
    const mediaSize = this.computedMediaSize();
    const mediaWidth = Number(mediaSize.width) || this.maxMediaWidth();
    return Math.max(1, mediaWidth + TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET * 2);
  }

  private computedMediaWidth(): number {
    return Number(this.computedMediaSize().width) || this.maxMediaWidth();
  }

  private computedMediaHeight(): number {
    return Number(this.computedMediaSize().height) || this.maxMediaHeight();
  }

  @Builder
  private buildPlaceholder() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.photoMinithumb.length > 0) {
        // R1.5: telegram-style мгновенный превью — blur поверх minithumbnail из TDLib
        Image(this.photoMinithumb)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(TgUiTokens.PHOTO_BUBBLE_MINITHUMB_BLUR)
      } else {
        Column({ space: TgUiTokens.SPACE_6 }) {
          TgIcon({
            src: TgUiTokens.ICON_RES_PHOTO,
            iconSize: TgUiTokens.ICON_SIZE_XL,
            tintColor: TgUiTokens.PHOTO_BUBBLE_PLACEHOLDER_ICON
          })

          Text($r('app.string.photo'))
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.PHOTO_BUBBLE_PLACEHOLDER_ICON)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width('100%')
        .height('100%')
      }
    }
    .width(this.maxMediaWidth())
    .height(this.maxMediaHeight())
    .backgroundColor(TgUiTokens.PHOTO_BUBBLE_PLACEHOLDER_BG)
    .borderRadius(TgUiTokens.PHOTO_BUBBLE_RADIUS - TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET)
    .clip(true)
  }

  @Builder
  private buildDownloadingStatusButton() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasDeterminateProgress()) {
        Progress({
          value: this.normalizedDownloadProgress() * 100,
          total: 100,
          type: ProgressType.Ring
        })
          .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
          .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
          .color(TgUiTokens.MEDIA_PROGRESS_COLOR)
          .backgroundColor(Color.Transparent)
          .style({ strokeWidth: TgUiTokens.MEDIA_PROGRESS_STROKE })
      } else {
        LoadingProgress()
          .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
          .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
          .color(TgUiTokens.MEDIA_PROGRESS_COLOR)
      }

      TgIcon({
        src: TgUiTokens.ICON_RES_CLOSE,
        iconSize: TgUiTokens.MEDIA_CANCEL_ICON_SIZE,
        tintColor: TgUiTokens.MEDIA_PROGRESS_COLOR
      })
    }
    .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
    .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
    .backgroundColor(TgUiTokens.MEDIA_OVERLAY_DARK)
    .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
    .onClick(() => this.onDownloadToggle())
    .transition({
      type: TransitionType.All,
      opacity: 0,
      scale: {
        x: TgUiTokens.MEDIA_STATUS_TRANSITION_SCALE,
        y: TgUiTokens.MEDIA_STATUS_TRANSITION_SCALE
      }
    })
    .animation({ duration: TgUiTokens.MEDIA_STATUS_ANIM_DURATION, curve: Curve.EaseInOut })
  }

  @Builder
  private buildIdleStatusButton(src: Resource, onTap: () => void) {
    Row() {
      TgIcon({
        src: src,
        iconSize: TgUiTokens.VIDEO_BUBBLE_PLAY_ICON_SIZE,
        tintColor: TgUiTokens.VIDEO_BUBBLE_PLAY_ICON
      })
    }
    .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
    .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(TgUiTokens.VIDEO_BUBBLE_PLAY_BG)
    .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
    .onClick(() => onTap())
    .transition({
      type: TransitionType.All,
      opacity: 0,
      scale: {
        x: TgUiTokens.MEDIA_STATUS_TRANSITION_SCALE,
        y: TgUiTokens.MEDIA_STATUS_TRANSITION_SCALE
      }
    })
    .animation({ duration: TgUiTokens.MEDIA_STATUS_ANIM_DURATION, curve: Curve.EaseInOut })
  }

  @Builder
  private buildMedia() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        if (this.hasPhoto()) {
          Image(this.photoPath)
            .width(this.computedMediaWidth())
            .height(this.computedMediaHeight())
            .objectFit(ImageFit.Contain)
            .borderRadius(TgUiTokens.PHOTO_BUBBLE_RADIUS - TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET)
            .clip(true)
            .onClick(() => this.handleSurfaceTap())
        } else {
          Column() {
            this.buildPlaceholder()
          }
          .onClick(() => this.handleSurfaceTap())
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      if (this.isDownloading) {
        this.buildDownloadingStatusButton()
      } else if (!this.hasLocalPhoto || this.isDownloadFailed) {
        this.buildIdleStatusButton(TgUiTokens.ICON_RES_DOWNLOAD, () => this.onDownloadToggle())
      }
    }
    .width('100%')
    .padding({
      left: TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET,
      right: TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET,
      top: TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET,
      bottom: this.hasCaption() ? 0 : TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET
    })
  }

  private handleSurfaceTap(): void {
    if (this.isDownloading) {
      // Already downloading — no-op (cancel handled by overlay button)
      return;
    }
    if (this.hasLocalPhoto) {
      this.onPhotoTap();
    } else {
      this.onDownloadToggle();
    }
  }

  @Builder
  private buildCaption() {
    if (this.hasCaption()) {
      Text(this.caption.trim())
        .fontSize(TgUiTokens.PHOTO_BUBBLE_CAPTION_SIZE)
        .lineHeight(TgUiTokens.PHOTO_BUBBLE_CAPTION_LINE_HEIGHT)
        .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
        .fontColor(this.captionColor())
        .wordBreak(WordBreak.BREAK_WORD)
        .lineBreakStrategy(LineBreakStrategy.HIGH_QUALITY)
        .maxLines(TgUiTokens.PHOTO_BUBBLE_CAPTION_MAX_LINES)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({
          left: TgUiTokens.PHOTO_BUBBLE_CAPTION_PADDING_H,
          right: TgUiTokens.PHOTO_BUBBLE_CAPTION_PADDING_H,
          top: TgUiTokens.PHOTO_BUBBLE_CAPTION_TOP_GAP,
          bottom: TgUiTokens.PHOTO_BUBBLE_CAPTION_PADDING_BOTTOM
        })
    }
  }

  @Builder
  private buildBubble() {
    Column() {
      this.buildMedia()
      this.buildCaption()
    }
    .width(this.computedBubbleWidth())
    .backgroundColor(this.bubbleColor())
    .borderRadius(TgUiTokens.PHOTO_BUBBLE_RADIUS)
    .clip(true)
  }

  build() {
    if (this.noBubbleWrap) {
      // noBubbleWrap: media only — caption rendered by TgMessageRouter for inline meta
      Column() {
        this.buildMedia()
      }
      .width(this.computedBubbleWidth())
    } else {
      Row() {
        this.buildBubble()
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
    }
  }
}
