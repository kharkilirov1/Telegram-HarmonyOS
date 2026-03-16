import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgVideoBubble {
  @Param thumbnailPath: string | Resource = '';
  @Param videoPath: string | Resource = '';
  @Param durationSec: number = 0;
  @Param caption: string = '';
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param videoWidth: number = 0;
  @Param videoHeight: number = 0;
  @Param noBubbleWrap: boolean = false;
  @Param hidePlayButton: boolean = false;
  @Param useRegularMaxDimensions: boolean = false;
  @Param isDownloadPending: boolean = false;
  @Param downloadProgress: number = -1;
  @Event onVideoPlayTap: () => void = () => {};
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
    return this.hasPath(this.thumbnailPath) || this.hasPath(this.videoPath);
  }

  private hasCaption(): boolean {
    return this.caption.trim().length > 0;
  }

  private hasLocalVideo(): boolean {
    return this.hasPath(this.videoPath);
  }

  private hasDuration(): boolean {
    return this.durationSec > 0;
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

  private previewSource(): string | Resource {
    if (this.hasPath(this.thumbnailPath)) {
      return this.thumbnailPath;
    }
    return this.videoPath;
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
    if (this.videoWidth > 0 && this.videoHeight > 0) {
      const scaled = Math.floor(mediaWidth * this.videoHeight / this.videoWidth);
      return Math.max(TgUiTokens.VIDEO_BUBBLE_MIN_HEIGHT,
        Math.min(scaled,
          this.usesRegularDimensions() ? TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT_REGULAR : TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT));
    }
    const fallback = Math.max(TgUiTokens.VIDEO_BUBBLE_MIN_HEIGHT, mediaWidth);
    return Math.min(fallback,
      this.usesRegularDimensions() ? TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT_REGULAR : TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT);
  }

  private formatDuration(): string {
    const seconds = Math.max(0, Math.floor(this.durationSec));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const remainSeconds = seconds % 60;
    const mm = minutes < 10 ? '0' + minutes.toString() : minutes.toString();
    const ss = remainSeconds < 10 ? '0' + remainSeconds.toString() : remainSeconds.toString();

    if (hours > 0) {
      return hours.toString() + ':' + mm + ':' + ss;
    }
    return minutes.toString() + ':' + ss;
  }

  @Builder
  private buildPlaceholder() {
    Column({ space: TgUiTokens.SPACE_6 }) {
      TgIcon({
        src: TgUiTokens.ICON_RES_VIDEO,
        iconSize: TgUiTokens.ICON_SIZE_XL,
        tintColor: TgUiTokens.VIDEO_BUBBLE_PLACEHOLDER_ICON
      })
      Text($r('app.string.video'))
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
  private buildDurationBadge() {
    if (this.hasDuration()) {
      Row() {
        Text(this.formatDuration())
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
  }

  @Builder
  private buildMedia() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasPreview()) {
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
        Stack({ alignContent: Alignment.Center }) {
          if (this.hasDeterminateProgress()) {
            Progress({
              value: this.normalizedDownloadProgress() * 100,
              total: 100,
              type: ProgressType.Ring
            })
              .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
              .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
              .color('#FFFFFF')
              .backgroundColor(Color.Transparent)
              .style({ strokeWidth: 3 })
          } else {
            LoadingProgress()
              .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
              .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
              .color('#FFFFFF')
          }
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(16).height(16).fillColor('#FFFFFF')
        }
        .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
        .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
        .backgroundColor('#40000000')
        .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
        .onClick(() => this.onDownloadToggle())
      } else if (!this.hasLocalVideo()) {
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_DOWNLOAD,
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
        .onClick(() => this.onDownloadToggle())
      } else if (!this.hidePlayButton) {
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_PLAY,
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
        .onClick(() => this.onVideoPlayTap())
      }

      this.buildDurationBadge()
    }
    .width(this.computedMediaWidth())
    .height(this.computedMediaHeight())
    .borderRadius(TgUiTokens.VIDEO_BUBBLE_RADIUS - TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET)
    .clip(true)
  }

  @Builder
  private buildCaption() {
    if (this.hasCaption()) {
      Text(this.caption.trim())
        .fontSize(TgUiTokens.VIDEO_BUBBLE_CAPTION_SIZE)
        .lineHeight(TgUiTokens.VIDEO_BUBBLE_CAPTION_LINE_HEIGHT)
        .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
        .fontColor(this.captionColor())
        .wordBreak(WordBreak.BREAK_WORD)
        .lineBreakStrategy(LineBreakStrategy.HIGH_QUALITY)
        .maxLines(TgUiTokens.VIDEO_BUBBLE_CAPTION_MAX_LINES)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({
          left: TgUiTokens.VIDEO_BUBBLE_CAPTION_PADDING_H,
          right: TgUiTokens.VIDEO_BUBBLE_CAPTION_PADDING_H,
          top: TgUiTokens.VIDEO_BUBBLE_CAPTION_TOP_GAP,
          bottom: TgUiTokens.VIDEO_BUBBLE_CAPTION_PADDING_BOTTOM
        })
    }
  }

  @Builder
  private buildBubble() {
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
        bottom: this.hasCaption() ? 0 : TgUiTokens.VIDEO_BUBBLE_IMAGE_INSET
      })

      this.buildCaption()
    }
    .width(this.computedBubbleWidth())
    .backgroundColor(this.bubbleColor())
    .borderRadius(TgUiTokens.VIDEO_BUBBLE_RADIUS)
    .clip(true)
  }

  build() {
    if (this.noBubbleWrap) {
      // noBubbleWrap: media only — caption rendered by TgMessageRouter for inline meta
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
        this.buildBubble()
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
    }
  }
}
