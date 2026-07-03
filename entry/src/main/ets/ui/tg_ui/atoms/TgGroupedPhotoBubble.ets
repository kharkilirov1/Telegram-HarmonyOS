import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgGroupedPhotoBubble {
  @Param photoPaths: string[] = [];
  @Param photoMinithumbs: string[] = [];
  @Param photoWidths: number[] = [];
  @Param photoHeights: number[] = [];
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param noBubbleWrap: boolean = false;
  @Event onPhotoTap: (photoPath: string) => void = (_: string) => {};

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private visibleCount(): number {
    return Math.min(4, this.photoPaths.length);
  }

  private hiddenCount(): number {
    return Math.max(0, this.photoPaths.length - 4);
  }

  private bubbleWidth(): number {
    const byRatio = TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio);
    const maxAllowed = Math.min(byRatio, TgUiTokens.resolvePhotoAlbumMaxWidth(this.containerWidth));
    const minAllowed = Math.min(TgUiTokens.PHOTO_BUBBLE_MIN_WIDTH, Math.max(1, Math.floor(this.containerWidth)));
    return Math.max(minAllowed, maxAllowed);
  }

  private bubbleHeight(): number {
    const width = this.bubbleWidth();
    const maxHeight = TgUiTokens.resolvePhotoAlbumMaxHeight(this.containerWidth);
    if (this.visibleCount() <= 1) {
      return Math.min(maxHeight, Math.floor(width * TgUiTokens.PHOTO_ALBUM_THREE_HEIGHT_RATIO));
    }
    if (this.visibleCount() === 2) {
      return Math.min(maxHeight, Math.floor(width * TgUiTokens.PHOTO_ALBUM_TWO_HEIGHT_RATIO));
    }
    if (this.visibleCount() === 3) {
      return Math.min(maxHeight, Math.floor(width * TgUiTokens.PHOTO_ALBUM_THREE_HEIGHT_RATIO));
    }
    return Math.min(maxHeight, width);
  }

  private leftWidthForThree(): number {
    return Math.max(1, Math.floor((this.bubbleWidth() - TgUiTokens.PHOTO_ALBUM_GAP) *
      TgUiTokens.PHOTO_ALBUM_THREE_PRIMARY_WIDTH_RATIO));
  }

  private rightWidthForThree(): number {
    return Math.max(1, this.bubbleWidth() - TgUiTokens.PHOTO_ALBUM_GAP - this.leftWidthForThree());
  }

  private topCellHeightForThree(): number {
    return Math.max(1, Math.floor((this.bubbleHeight() - TgUiTokens.PHOTO_ALBUM_GAP) / 2));
  }

  private bottomCellHeightForThree(): number {
    return Math.max(1, this.bubbleHeight() - TgUiTokens.PHOTO_ALBUM_GAP - this.topCellHeightForThree());
  }

  private gridCellWidth(): number {
    return Math.max(1, Math.floor((this.bubbleWidth() - TgUiTokens.PHOTO_ALBUM_GAP) / 2));
  }

  private gridCellHeight(): number {
    return Math.max(1, Math.floor((this.bubbleHeight() - TgUiTokens.PHOTO_ALBUM_GAP) / 2));
  }

  private cellPath(index: number): string {
    return index < this.photoPaths.length ? this.photoPaths[index] : '';
  }

  private cellMinithumb(index: number): string {
    return index < this.photoMinithumbs.length ? this.photoMinithumbs[index] : '';
  }

  @Builder
  private buildPlaceholder(index: number, width: number, height: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.cellMinithumb(index).length > 0) {
        // R1.5: blur-minithumbnail вместо серого плейсхолдера
        Image(this.cellMinithumb(index))
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
    .width(width)
    .height(height)
    .backgroundColor(TgUiTokens.PHOTO_BUBBLE_PLACEHOLDER_BG)
    .borderRadius(TgUiTokens.RADIUS_6)
    .clip(true)
  }

  @Builder
  private buildCell(index: number, width: number, height: number, showOverlay: boolean = false) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.cellPath(index).trim().length > 0) {
        Image(this.cellPath(index))
          .width(width)
          .height(height)
          .objectFit(ImageFit.Cover)
          .borderRadius(TgUiTokens.RADIUS_6)
          .clip(true)
      } else {
        this.buildPlaceholder(index, width, height)
      }

      if (showOverlay) {
        Row() {
          Text('+' + this.hiddenCount().toString())
            .fontSize(TgUiTokens.PHOTO_ALBUM_OVERLAY_TEXT_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(width)
        .height(height)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(TgUiTokens.PHOTO_ALBUM_OVERLAY_BG)
        .borderRadius(TgUiTokens.RADIUS_6)
        .clip(true)
      }
    }
    .width(width)
    .height(height)
    .onClick(() => {
      this.onPhotoTap(this.cellPath(index));
    })
  }

  @Builder
  private buildAlbumContent() {
    if (this.visibleCount() <= 1) {
      this.buildCell(0, this.bubbleWidth(), this.bubbleHeight(), false)
    } else if (this.visibleCount() === 2) {
      Row({ space: TgUiTokens.PHOTO_ALBUM_GAP }) {
        this.buildCell(0, this.gridCellWidth(), this.bubbleHeight(), false)
        this.buildCell(1, this.gridCellWidth(), this.bubbleHeight(), false)
      }
      .width(this.bubbleWidth())
      .height(this.bubbleHeight())
    } else if (this.visibleCount() === 3) {
      Row({ space: TgUiTokens.PHOTO_ALBUM_GAP }) {
        this.buildCell(0, this.leftWidthForThree(), this.bubbleHeight(), false)

        Column({ space: TgUiTokens.PHOTO_ALBUM_GAP }) {
          this.buildCell(1, this.rightWidthForThree(), this.topCellHeightForThree(), false)
          this.buildCell(2, this.rightWidthForThree(), this.bottomCellHeightForThree(), false)
        }
        .width(this.rightWidthForThree())
        .height(this.bubbleHeight())
      }
      .width(this.bubbleWidth())
      .height(this.bubbleHeight())
    } else {
      Column({ space: TgUiTokens.PHOTO_ALBUM_GAP }) {
        Row({ space: TgUiTokens.PHOTO_ALBUM_GAP }) {
          this.buildCell(0, this.gridCellWidth(), this.gridCellHeight(), false)
          this.buildCell(1, this.gridCellWidth(), this.gridCellHeight(), false)
        }

        Row({ space: TgUiTokens.PHOTO_ALBUM_GAP }) {
          this.buildCell(2, this.gridCellWidth(), this.gridCellHeight(), false)
          this.buildCell(3, this.gridCellWidth(), this.gridCellHeight(), this.hiddenCount() > 0)
        }
      }
      .width(this.bubbleWidth())
      .height(this.bubbleHeight())
    }
  }

  @Builder
  private buildBubble() {
    Column() {
      this.buildAlbumContent()
    }
    .width(this.bubbleWidth())
    .height(this.bubbleHeight())
    .backgroundColor(this.bubbleColor())
    .borderRadius(TgUiTokens.PHOTO_ALBUM_RADIUS)
    .clip(true)
  }

  build() {
    if (this.noBubbleWrap) {
      Column() {
        this.buildAlbumContent()
      }
      .width(this.bubbleWidth())
      .height(this.bubbleHeight())
      .borderRadius(TgUiTokens.PHOTO_ALBUM_RADIUS)
      .clip(true)
    } else {
      Row() {
        this.buildBubble()
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
    }
  }
}
