import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgPhotoBubble {
  @Param photoPath: string | Resource = '';
  @Param caption: string = '';
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param photoWidth: number = 0;
  @Param photoHeight: number = 0;

  private hasPhoto(): boolean {
    if (typeof this.photoPath === 'string') {
      return this.photoPath.trim().length > 0;
    }
    return true;
  }

  private hasCaption(): boolean {
    return this.caption.trim().length > 0;
  }

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private captionColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.PHOTO_BUBBLE_CAPTION_TEXT_OUTGOING : TgUiTokens.PHOTO_BUBBLE_CAPTION_TEXT_INCOMING;
  }

  private computedBubbleWidth(): number {
    const byRatio = Math.floor(this.containerWidth * this.maxWidthRatio);
    const maxAllowed = Math.min(byRatio, TgUiTokens.PHOTO_BUBBLE_MAX_WIDTH);
    const minAllowed = Math.min(TgUiTokens.PHOTO_BUBBLE_MIN_WIDTH, Math.max(1, Math.floor(this.containerWidth)));
    return Math.max(minAllowed, maxAllowed);
  }

  private computedMediaWidth(): number {
    return Math.max(1, this.computedBubbleWidth() - TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET * 2);
  }

  private computedMediaHeight(): number {
    const mediaWidth = this.computedMediaWidth();
    if (this.photoWidth > 0 && this.photoHeight > 0) {
      const scaled = Math.floor(mediaWidth * this.photoHeight / this.photoWidth);
      return Math.max(TgUiTokens.PHOTO_BUBBLE_MIN_HEIGHT, Math.min(scaled, TgUiTokens.PHOTO_BUBBLE_MAX_HEIGHT));
    }
    const square = Math.max(TgUiTokens.PHOTO_BUBBLE_MIN_HEIGHT, mediaWidth);
    return Math.min(square, TgUiTokens.PHOTO_BUBBLE_MAX_HEIGHT);
  }

  @Builder
  private buildPlaceholder() {
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
    .width(this.computedMediaWidth())
    .height(this.computedMediaHeight())
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(TgUiTokens.PHOTO_BUBBLE_PLACEHOLDER_BG)
    .borderRadius(TgUiTokens.PHOTO_BUBBLE_RADIUS - TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET)
  }

  @Builder
  private buildMedia() {
    Row() {
      if (this.hasPhoto()) {
        Image(this.photoPath)
          .width(this.computedMediaWidth())
          .height(this.computedMediaHeight())
          .objectFit(ImageFit.Cover)
          .borderRadius(TgUiTokens.PHOTO_BUBBLE_RADIUS - TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET)
      } else {
        this.buildPlaceholder()
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({
      left: TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET,
      right: TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET,
      top: TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET,
      bottom: this.hasCaption() ? 0 : TgUiTokens.PHOTO_BUBBLE_IMAGE_INSET
    })
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
  }

  build() {
    Row() {
      this.buildBubble()
    }
    .width('100%')
    .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
  }
}
