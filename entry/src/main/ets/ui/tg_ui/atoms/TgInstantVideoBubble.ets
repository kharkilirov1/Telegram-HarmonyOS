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
  @Event onPlayToggle: () => void = () => {};
  @Event onDownloadToggle: () => void = () => {};

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
    if (this.isDownloadPending) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.hasDeterminateProgress()) {
          this.buildRadialProgress()
        } else {
          LoadingProgress()
            .width(this.bubbleSize() - 4)
            .height(this.bubbleSize() - 4)
            .color('#FFFFFF')
        }
        Image($r('sys.media.ohos_ic_public_cancel'))
          .width(20).height(20).fillColor('#FFFFFF')
      }
      .width(this.bubbleSize())
      .height(this.bubbleSize())
      .backgroundColor('#40000000') // Dark overlay
      .borderRadius(this.bubbleSize() / 2)
      .onClick(() => this.onDownloadToggle())
    } else if (!this.hasLocalVideo()) {
      Stack() {
        TgIcon({
          src: TgUiTokens.ICON_RES_DOWNLOAD,
          iconSize: TgUiTokens.INSTANT_VIDEO_BUBBLE_PLAY_ICON_SIZE + 4,
          tintColor: '#FFFFFF'
        })
      }
      .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .backgroundColor('#40000000')
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
      .onClick(() => this.onDownloadToggle())
    } else {
      // Downloaded: play button
      Stack() {
        TgIcon({
          src: TgUiTokens.ICON_RES_PLAY,
          iconSize: TgUiTokens.INSTANT_VIDEO_BUBBLE_PLAY_ICON_SIZE + 4,
          tintColor: '#FFFFFF'
        })
      }
      .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .backgroundColor('#40000000')
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
      .onClick(() => this.onPlayToggle())
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
