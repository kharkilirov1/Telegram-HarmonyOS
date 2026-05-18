import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';
import { TgInlineVideoView } from './TgInlineVideoView';

@ComponentV2
export struct TgAnimationBubble {
  @Param thumbnailPath: string | Resource = '';
  @Param animationPath: string | Resource = '';
  @Param caption: string = '';
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param animationWidth: number = 0;
  @Param animationHeight: number = 0;
  @Param noBubbleWrap: boolean = false;
  @Param useRegularMaxDimensions: boolean = false;
  @Param isDownloadPending: boolean = false;
  @Param isDownloadFailed: boolean = false;
  @Param downloadProgress: number = -1;
  @Event onAnimationTap: () => void = () => {};
  @Event onDownloadToggle: () => void = () => {};

  private usesRegularDimensions(): boolean {
    return this.useRegularMaxDimensions || TgUiTokens.isRegularMessageWidth(this.containerWidth);
  }

  private hasPath(path: string | Resource): boolean {
    if (typeof path === 'string') {
      return path.trim().length > 0;
    }
    return true;
  }

  private hasPreview(): boolean {
    return this.hasPath(this.thumbnailPath) || this.hasPath(this.animationPath);
  }

  private hasLocalAnimation(): boolean {
    return this.hasPath(this.animationPath);
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

  private previewSource(): string | Resource {
    if (this.hasPath(this.thumbnailPath)) {
      return this.thumbnailPath;
    }
    return this.animationPath;
  }

  private displaySource(): string | Resource {
    if (this.hasLocalAnimation()) {
      return this.animationPath;
    }
    return this.previewSource();
  }

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private captionColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.VIDEO_BUBBLE_CAPTION_TEXT_OUTGOING : TgUiTokens.VIDEO_BUBBLE_CAPTION_TEXT_INCOMING;
  }

  private computedBubbleWidth(): number {
    const byRatio = TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio);
    const maxAllowed = Math.min(byRatio,
      this.usesRegularDimensions() ? TgUiTokens.VIDEO_BUBBLE_MAX_WIDTH_REGULAR : TgUiTokens.VIDEO_BUBBLE_MAX_WIDTH);
    const minAllowed = Math.min(TgUiTokens.VIDEO_BUBBLE_MIN_WIDTH, Math.max(1, Math.floor(this.containerWidth)));
    return Math.max(minAllowed, maxAllowed);
  }

  private computedMediaWidth(): number {
    return Math.max(1, this.computedBubbleWidth() - TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET * 2);
  }

  private computedMediaHeight(): number {
    const mediaWidth = this.computedMediaWidth();
    if (this.animationWidth > 0 && this.animationHeight > 0) {
      const scaled = Math.floor(mediaWidth * this.animationHeight / this.animationWidth);
      return Math.max(TgUiTokens.VIDEO_BUBBLE_MIN_HEIGHT,
        Math.min(scaled,
          this.usesRegularDimensions() ? TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT_REGULAR : TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT));
    }
    const fallback = Math.max(TgUiTokens.VIDEO_BUBBLE_MIN_HEIGHT, mediaWidth);
    return Math.min(fallback,
      this.usesRegularDimensions() ? TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT_REGULAR : TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT);
  }

  private handleSurfaceTap(): void {
    if (this.isDownloadPending) {
      return;
    }
    if (this.hasLocalAnimation()) {
      this.onAnimationTap();
    } else {
      this.onDownloadToggle();
    }
  }

  @Builder
  private buildPlaceholder() {
    Column({ space: TgUiTokens.SPACE_6 }) {
      TgIcon({
        src: TgUiTokens.ICON_RES_VIDEO,
        iconSize: TgUiTokens.ICON_SIZE_XL,
        tintColor: TgUiTokens.VIDEO_BUBBLE_PLACEHOLDER_ICON
      })
      Text('GIF')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.VIDEO_BUBBLE_PLACEHOLDER_ICON)
    }
    .width(this.computedMediaWidth())
    .height(this.computedMediaHeight())
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(TgUiTokens.VIDEO_BUBBLE_PLACEHOLDER_BG)
    .borderRadius(TgUiTokens.VIDEO_BUBBLE_RADIUS - TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET)
  }

  @Builder
  private buildGifBadge() {
    Row() {
      Text('GIF')
        .fontSize(TgUiTokens.VIDEO_BUBBLE_DURATION_FONT_SIZE)
        .lineHeight(TgUiTokens.VIDEO_BUBBLE_DURATION_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.VIDEO_BUBBLE_DURATION_TEXT)
    }
    .padding({
      left: TgUiTokens.VIDEO_BUBBLE_DURATION_PADDING_H,
      right: TgUiTokens.VIDEO_BUBBLE_DURATION_PADDING_H,
      top: TgUiTokens.VIDEO_BUBBLE_DURATION_PADDING_V,
      bottom: TgUiTokens.VIDEO_BUBBLE_DURATION_PADDING_V
    })
    .backgroundColor(TgUiTokens.VIDEO_BUBBLE_DURATION_BG)
    .borderRadius(TgUiTokens.VIDEO_BUBBLE_DURATION_RADIUS)
    .position({
      right: TgUiTokens.VIDEO_BUBBLE_DURATION_MARGIN,
      bottom: TgUiTokens.VIDEO_BUBBLE_DURATION_MARGIN
    })
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
      if (this.hasLocalAnimation()) {
        // Local file — play as inline video (GIF auto-play loop muted)
        TgInlineVideoView({
          videoPath: this.animationPath as string,
          thumbnailPath: this.thumbnailPath,
          videoWidth: this.computedMediaWidth(),
          videoHeight: this.computedMediaHeight(),
          autoPlay: true,
          loop: true,
          muted: true,
          showControls: false,
          isCircular: false,
          onTap: () => this.onAnimationTap()
        })
      } else if (this.hasPreview()) {
        Image(this.previewSource())
          .width(this.computedMediaWidth())
          .height(this.computedMediaHeight())
          .objectFit(ImageFit.Cover)
          .borderRadius(TgUiTokens.VIDEO_BUBBLE_RADIUS - TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET)
          .clip(true)
      } else {
        this.buildPlaceholder()
      }

      if (this.isDownloadPending) {
        this.buildDownloadingStatusButton()
      } else if (!this.hasLocalAnimation() || this.isDownloadFailed) {
        this.buildIdleStatusButton(TgUiTokens.ICON_RES_DOWNLOAD, () => this.onDownloadToggle())
      }

      this.buildGifBadge()
    }
    .width(this.computedMediaWidth())
    .height(this.computedMediaHeight())
    .borderRadius(TgUiTokens.VIDEO_BUBBLE_RADIUS - TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET)
    .clip(true)
    .onClick(() => this.handleSurfaceTap())
  }

  build() {
    if (this.noBubbleWrap) {
      Column() {
        Row() {
          this.buildMedia()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({
          left: TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET,
          right: TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET,
          top: TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET,
          bottom: TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET
        })
      }
      .width(this.computedBubbleWidth())
    } else {
      Row() {
        Column() {
          Row() {
            this.buildMedia()
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({
            left: TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET,
            right: TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET,
            top: TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET,
            bottom: TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET
          })
        }
        .width(this.computedBubbleWidth())
        .backgroundColor(this.bubbleColor())
        .borderRadius(TgUiTokens.VIDEO_BUBBLE_RADIUS)
        .clip(true)
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
    }
  }
}
