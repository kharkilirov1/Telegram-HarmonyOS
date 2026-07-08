import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';
import { TgInlineVideoView } from './TgInlineVideoView';

@ComponentV2
export struct TgStickerView {
  @Param stickerPath: string | Resource = '';
  @Param stickerThumbnailPath: string = '';
  @Param isOutgoing: boolean = false;
  @Param isAnimatedSticker: boolean = false;
  @Param isVideoSticker: boolean = false;
  @Param stickerEmoji: string = '';
  @Param stickerWidth: number = 0;
  @Param stickerHeight: number = 0;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = 0.65;

  private hasSticker(): boolean {
    if (typeof this.stickerPath === 'string') {
      return this.stickerPath.trim().length > 0;
    }
    return true;
  }

  private hasThumbnail(): boolean {
    return this.stickerThumbnailPath.trim().length > 0;
  }

  private maxStickerSide(): number {
    const byContainer = Math.floor(this.containerWidth * this.maxWidthRatio);
    const maxByType = (this.isAnimatedSticker || this.isVideoSticker)
      ? TgUiTokens.STICKER_VIEW_ANIMATED_MAX_SIZE
      : TgUiTokens.STICKER_VIEW_MAX_SIZE;
    return Math.max(TgUiTokens.STICKER_VIEW_MIN_SIZE, Math.min(byContainer, maxByType));
  }

  private computedStickerWidth(): number {
    const maxSide = this.maxStickerSide();
    if (this.stickerWidth > 0 && this.stickerHeight > 0) {
      const ratio = this.stickerWidth / this.stickerHeight;
      if (ratio >= 1) {
        return maxSide;
      }
      return Math.max(TgUiTokens.STICKER_VIEW_MIN_SIZE, Math.floor(maxSide * ratio));
    }
    return maxSide;
  }

  private computedStickerHeight(): number {
    const maxSide = this.maxStickerSide();
    if (this.stickerWidth > 0 && this.stickerHeight > 0) {
      const ratio = this.stickerWidth / this.stickerHeight;
      if (ratio >= 1) {
        return Math.max(TgUiTokens.STICKER_VIEW_MIN_SIZE, Math.floor(maxSide / ratio));
      }
      return maxSide;
    }
    return maxSide;
  }

  @Builder
  private buildPlaceholder() {
    Row() {
      // A big sticker emoji reads far better than a generic icon while the
      // real render is unavailable (tgs without thumbnail / not downloaded)
      if (this.stickerEmoji.length > 0) {
        Text(this.stickerEmoji)
          .fontSize(TgUiTokens.STICKER_VIEW_EMOJI_FALLBACK_SIZE)
      } else {
        TgIcon({
          src: TgUiTokens.ICON_RES_STICKER,
          iconSize: TgUiTokens.STICKER_VIEW_PLACEHOLDER_SIZE,
          tintColor: TgUiTokens.STICKER_VIEW_PLACEHOLDER_ICON
        })
      }
    }
    .width(this.computedStickerWidth())
    .height(this.computedStickerHeight())
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(TgUiTokens.STICKER_VIEW_PLACEHOLDER_BG)
    .borderRadius(TgUiTokens.RADIUS_12)
  }

  @Builder
  private buildStickerContent() {
    if (this.isVideoSticker && this.hasSticker()) {
      // webm: play inline with TgInlineVideoView (autoPlay, loop, muted, no UI chrome)
      Row() {
        TgInlineVideoView({
          videoPath: typeof this.stickerPath === 'string' ? this.stickerPath as string : '',
          thumbnailPath: this.stickerThumbnailPath,
          videoWidth: this.computedStickerWidth(),
          videoHeight: this.computedStickerHeight(),
          autoPlay: true,
          loop: true,
          muted: true,
          showControls: false,
          isCircular: false
        })
      }
      .width(this.computedStickerWidth())
      .height(this.computedStickerHeight())
    } else if (this.isAnimatedSticker) {
      // tgs: no lottie engine — fall back to thumbnail; placeholder if no thumbnail
      if (this.hasThumbnail()) {
        Image(this.stickerThumbnailPath)
          .width(this.computedStickerWidth())
          .height(this.computedStickerHeight())
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
      } else {
        this.buildPlaceholder()
      }
    } else if (this.hasSticker()) {
      // static PNG/WEBP
      Image(this.stickerPath)
        .width(this.computedStickerWidth())
        .height(this.computedStickerHeight())
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
    } else {
      this.buildPlaceholder()
    }
  }

  build() {
    Row() {
      this.buildStickerContent()
    }
    .width('100%')
    .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
  }
}
