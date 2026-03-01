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

  private hasDuration(): boolean {
    return this.durationSec > 0;
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
    const byRatio = Math.floor(this.containerWidth * this.maxWidthRatio);
    const maxAllowed = Math.min(byRatio, TgUiTokens.VIDEO_BUBBLE_MAX_WIDTH);
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
      return Math.max(TgUiTokens.VIDEO_BUBBLE_MIN_HEIGHT, Math.min(scaled, TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT));
    }
    const fallback = Math.max(TgUiTokens.VIDEO_BUBBLE_MIN_HEIGHT, mediaWidth);
    return Math.min(fallback, TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT);
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
      } else {
        this.buildPlaceholder()
      }

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

      this.buildDurationBadge()
    }
    .width(this.computedMediaWidth())
    .height(this.computedMediaHeight())
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
  }

  build() {
    Row() {
      this.buildBubble()
    }
    .width('100%')
    .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
  }
}
