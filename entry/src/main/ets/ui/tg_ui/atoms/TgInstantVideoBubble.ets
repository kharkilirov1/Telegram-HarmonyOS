import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgInstantVideoBubble {
  @Param thumbnailPath: string | Resource = '';
  @Param videoPath: string | Resource = '';
  @Param durationSec: number = 0;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param noBubbleWrap: boolean = false;
  @Param isDownloadPending: boolean = false;
  @Param downloadProgress: number = -1;
  @Event onTap: () => void = () => {};

  private hasPath(path: string | Resource): boolean {
    if (typeof path === 'string') {
      return path.trim().length > 0;
    }
    return true;
  }

  private previewSource(): string | Resource {
    if (this.hasPath(this.thumbnailPath)) {
      return this.thumbnailPath;
    }
    return this.videoPath;
  }

  private hasPreview(): boolean {
    return this.hasPath(this.thumbnailPath) || this.hasPath(this.videoPath);
  }

  private hasLocalVideo(): boolean {
    return this.hasPath(this.videoPath);
  }

  private bubbleSize(): number {
    return TgUiTokens.resolveInstantVideoBubbleSize(this.containerWidth);
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
    .width(this.bubbleSize())
    .height(this.bubbleSize())
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(TgUiTokens.VIDEO_BUBBLE_PLACEHOLDER_BG)
    .borderRadius(this.bubbleSize() / 2)
    .clip(true)
  }

  @Builder
  private buildDurationBadge() {
    if (this.hasDuration()) {
      Row() {
        Text(this.formatDuration())
          .fontSize(TgUiTokens.INSTANT_VIDEO_BUBBLE_DURATION_FONT_SIZE)
          .lineHeight(TgUiTokens.INSTANT_VIDEO_BUBBLE_DURATION_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.VIDEO_BUBBLE_DURATION_TEXT)
      }
      .padding({
        left: TgUiTokens.INSTANT_VIDEO_BUBBLE_DURATION_PADDING_H,
        right: TgUiTokens.INSTANT_VIDEO_BUBBLE_DURATION_PADDING_H,
        top: TgUiTokens.INSTANT_VIDEO_BUBBLE_DURATION_PADDING_V,
        bottom: TgUiTokens.INSTANT_VIDEO_BUBBLE_DURATION_PADDING_V
      })
      .backgroundColor(TgUiTokens.VIDEO_BUBBLE_DURATION_BG)
      .borderRadius(TgUiTokens.INSTANT_VIDEO_BUBBLE_DURATION_RADIUS)
      .position({
        right: TgUiTokens.INSTANT_VIDEO_BUBBLE_DURATION_MARGIN,
        bottom: TgUiTokens.INSTANT_VIDEO_BUBBLE_DURATION_MARGIN
      })
    }
  }

  @Builder
  private buildRadialProgress() {
    // iOS-style radial progress ring around the entire circle perimeter
    Progress({
      value: this.normalizedDownloadProgress() * 100,
      total: 100,
      type: ProgressType.Ring
    })
      .width(this.bubbleSize() - 4)
      .height(this.bubbleSize() - 4)
      .color('#99FFFFFF')
      .backgroundColor(Color.Transparent)
      .style({ strokeWidth: 3 })
  }

  @Builder
  private buildCenterOverlay() {
    if (this.isDownloadPending && this.hasDeterminateProgress()) {
      // Downloading with progress: radial ring + percent text
      Column({ space: TgUiTokens.SPACE_2 }) {
        this.buildRadialProgress()
      }

    } else if (this.isDownloadPending) {
      // Downloading indeterminate: radial spinner (no bg circle)
      LoadingProgress()
        .width(TgUiTokens.INSTANT_VIDEO_BUBBLE_PLAY_ICON_SIZE + 8)
        .height(TgUiTokens.INSTANT_VIDEO_BUBBLE_PLAY_ICON_SIZE + 8)
        .color('#99FFFFFF')

    } else if (!this.hasLocalVideo()) {
      // Not downloaded: semi-transparent download icon (no opaque bg)
      TgIcon({
        src: TgUiTokens.ICON_RES_DOWNLOAD,
        iconSize: TgUiTokens.INSTANT_VIDEO_BUBBLE_PLAY_ICON_SIZE + 4,
        tintColor: '#99FFFFFF'
      })

    } else {
      // Downloaded: semi-transparent play triangle (no opaque bg circle — iOS style)
      TgIcon({
        src: TgUiTokens.ICON_RES_PLAY,
        iconSize: TgUiTokens.INSTANT_VIDEO_BUBBLE_PLAY_ICON_SIZE + 4,
        tintColor: '#99FFFFFF'
      })
    }
  }

  @Builder
  private buildCircle() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasPreview()) {
        Image(this.previewSource())
          .width(this.bubbleSize())
          .height(this.bubbleSize())
          .objectFit(ImageFit.Cover)
          .borderRadius(this.bubbleSize() / 2)
          .clip(true)
      } else {
        this.buildPlaceholder()
      }

      // Dim overlay when downloading or showing play button
      if (this.isDownloadPending || this.hasLocalVideo()) {
        Column()
          .width(this.bubbleSize())
          .height(this.bubbleSize())
          .borderRadius(this.bubbleSize() / 2)
          .backgroundColor(this.isDownloadPending ? '#33000000' : Color.Transparent)
      }

      this.buildCenterOverlay()

      this.buildDurationBadge()
    }
    .width(this.bubbleSize())
    .height(this.bubbleSize())
    .borderRadius(this.bubbleSize() / 2)
    .clip(true)
    .onClick(() => {
      this.onTap();
    })
  }

  build() {
    if (this.noBubbleWrap) {
      this.buildCircle()
    } else {
      Row() {
        this.buildCircle()
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
  }
}
