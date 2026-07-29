import { TgPhotoAlbumFrame, TgPhotoAlbumItemSize, TgPhotoAlbumLayoutResult,
  TgPhotoAlbumPosition, computeTgPhotoAlbumLayout } from '../layout/TgPhotoAlbumLayout';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { albumMediaSourceId, mediaGeometryTransitionId } from '../utils/TgMediaGeometryTransition';
import { resolvePhotoAlbumTapMode, TgPhotoAlbumTapMode } from '../utils/TgMediaGalleryPolicy';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgGroupedPhotoBubble {
  @Param messageId: string = '0';
  @Param photoPaths: string[] = [];
  @Param photoMinithumbs: string[] = [];
  @Param photoMessageIds: string[] = [];
  @Param photoFileIds: number[] = [];
  @Param photoHasLocal: boolean[] = [];
  @Param photoDownloading: boolean[] = [];
  @Param photoDownloadFailed: boolean[] = [];
  @Param photoDownloadProgress: number[] = [];
  @Param photoWidths: number[] = [];
  @Param photoHeights: number[] = [];
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param noBubbleWrap: boolean = false;
  @Param hiddenPhotoMessageId: string = '0';
  @Event onPhotoTap: (albumIndex: number) => void = (_: number) => {};
  @Event onDownloadToggle: (albumIndex: number) => void = (_: number) => {};

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private sourcePhotoCount(): number {
    return Math.max(this.photoPaths.length, this.photoMinithumbs.length, this.photoMessageIds.length,
      this.photoFileIds.length,
      this.photoHasLocal.length, this.photoDownloading.length, this.photoDownloadFailed.length,
      this.photoDownloadProgress.length, this.photoWidths.length, this.photoHeights.length);
  }

  private renderedPhotoCount(): number {
    return Math.min(10, this.sourcePhotoCount());
  }

  private hiddenCount(): number {
    return Math.max(0, this.sourcePhotoCount() - this.renderedPhotoCount());
  }

  private bubbleWidth(): number {
    const byRatio = TgUiTokens.resolveBubbleMaxWidth(this.containerWidth, this.maxWidthRatio);
    const maxAllowed = Math.min(byRatio, TgUiTokens.resolvePhotoAlbumMaxWidth(this.containerWidth));
    const minAllowed = Math.min(TgUiTokens.PHOTO_BUBBLE_MIN_WIDTH, Math.max(1, Math.floor(this.containerWidth)));
    return Math.max(minAllowed, maxAllowed);
  }

  private cellPath(index: number): string {
    return index < this.photoPaths.length ? this.photoPaths[index] : '';
  }

  private cellMinithumb(index: number): string {
    return index < this.photoMinithumbs.length ? this.photoMinithumbs[index] : '';
  }

  private cellFileId(index: number): number {
    return index < this.photoFileIds.length ? this.photoFileIds[index] : 0;
  }

  private cellMessageId(index: number): string {
    const memberMessageId = index < this.photoMessageIds.length ? this.photoMessageIds[index] : '';
    return albumMediaSourceId(this.messageId, memberMessageId, index);
  }

  private shouldHideCell(index: number): boolean {
    const hiddenMessageId = this.hiddenPhotoMessageId.trim();
    return hiddenMessageId.length > 0 && hiddenMessageId !== '0' && hiddenMessageId === this.cellMessageId(index);
  }

  private cellHasLocal(index: number): boolean {
    if (index < this.photoHasLocal.length) {
      return this.photoHasLocal[index];
    }
    // Demo/fallback callers that only provide a path keep the historical local-photo behavior.
    return this.cellPath(index).trim().length > 0;
  }

  private cellDownloading(index: number): boolean {
    return index < this.photoDownloading.length ? this.photoDownloading[index] : false;
  }

  private cellDownloadFailed(index: number): boolean {
    return index < this.photoDownloadFailed.length ? this.photoDownloadFailed[index] : false;
  }

  private cellDownloadProgress(index: number): number {
    return index < this.photoDownloadProgress.length ? this.photoDownloadProgress[index] : -1;
  }

  private hasDeterminateProgress(index: number): boolean {
    const progress = this.cellDownloadProgress(index);
    return progress >= 0 && progress < 1;
  }

  private normalizedDownloadProgress(index: number): number {
    return Math.max(0, Math.min(1, this.cellDownloadProgress(index)));
  }

  private albumItemSizes(): TgPhotoAlbumItemSize[] {
    const result: TgPhotoAlbumItemSize[] = [];
    for (let index = 0; index < this.renderedPhotoCount(); index++) {
      result.push({
        width: index < this.photoWidths.length ? this.photoWidths[index] : 0,
        height: index < this.photoHeights.length ? this.photoHeights[index] : 0
      });
    }
    return result;
  }

  private albumLayout(): TgPhotoAlbumLayoutResult {
    return computeTgPhotoAlbumLayout(
      this.albumItemSizes(),
      this.bubbleWidth(),
      TgUiTokens.resolvePhotoAlbumMaxHeight(this.containerWidth),
      TgUiTokens.PHOTO_ALBUM_GAP,
      true
    );
  }

  private bubbleHeight(): number {
    return this.albumLayout().height;
  }

  private hasPosition(frame: TgPhotoAlbumFrame, position: TgPhotoAlbumPosition): boolean {
    return (frame.position & position) === position;
  }

  private cellRadius(frame: TgPhotoAlbumFrame): BorderRadiuses {
    return {
      topLeft: this.hasPosition(frame, TgPhotoAlbumPosition.Top) &&
        this.hasPosition(frame, TgPhotoAlbumPosition.Left) ? TgUiTokens.PHOTO_ALBUM_RADIUS : 0,
      topRight: this.hasPosition(frame, TgPhotoAlbumPosition.Top) &&
        this.hasPosition(frame, TgPhotoAlbumPosition.Right) ? TgUiTokens.PHOTO_ALBUM_RADIUS : 0,
      bottomLeft: this.hasPosition(frame, TgPhotoAlbumPosition.Bottom) &&
        this.hasPosition(frame, TgPhotoAlbumPosition.Left) ? TgUiTokens.PHOTO_ALBUM_RADIUS : 0,
      bottomRight: this.hasPosition(frame, TgPhotoAlbumPosition.Bottom) &&
        this.hasPosition(frame, TgPhotoAlbumPosition.Right) ? TgUiTokens.PHOTO_ALBUM_RADIUS : 0
    };
  }

  private shouldShowIdleStatus(index: number): boolean {
    return !this.cellHasLocal(index) || this.cellDownloadFailed(index);
  }

  private handleSurfaceTap(index: number): void {
    const mode: TgPhotoAlbumTapMode = resolvePhotoAlbumTapMode(
      this.cellHasLocal(index),
      this.cellDownloading(index),
      this.cellFileId(index)
    );
    if (mode === 'downloadAndOpen') {
      this.onDownloadToggle(index);
    }
    if (mode === 'open' || mode === 'downloadAndOpen') {
      this.onPhotoTap(index);
    }
  }

  @Builder
  private buildPlaceholder(index: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.cellMinithumb(index).length > 0) {
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
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.PHOTO_BUBBLE_PLACEHOLDER_BG)
  }

  @Builder
  private buildDownloadingStatusButton(index: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasDeterminateProgress(index)) {
        Progress({
          value: this.normalizedDownloadProgress(index) * 100,
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
    .onClick(() => this.onDownloadToggle(index))
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
  private buildIdleStatusButton(index: number) {
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
    .onClick(() => this.handleSurfaceTap(index))
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
  private buildCellSurface(frame: TgPhotoAlbumFrame, showOverlay: boolean) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.cellPath(frame.index).trim().length > 0) {
        Image(this.cellPath(frame.index))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .onClick(() => this.handleSurfaceTap(frame.index))
      } else {
        Column() {
          this.buildPlaceholder(frame.index)
        }
        .width('100%')
        .height('100%')
        .onClick(() => this.handleSurfaceTap(frame.index))
      }

      if (this.cellDownloading(frame.index)) {
        this.buildDownloadingStatusButton(frame.index)
      } else if (this.shouldShowIdleStatus(frame.index)) {
        this.buildIdleStatusButton(frame.index)
      }

      if (showOverlay) {
        Row() {
          Text('+' + this.hiddenCount().toString())
            .fontSize(TgUiTokens.PHOTO_ALBUM_OVERLAY_TEXT_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(TgUiTokens.PHOTO_ALBUM_OVERLAY_BG)
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.cellRadius(frame))
    .clip(true)
  }

  @Builder
  private buildCell(frame: TgPhotoAlbumFrame, showOverlay: boolean) {
    if (this.shouldHideCell(frame.index)) {
      Stack({ alignContent: Alignment.Center }) {
        this.buildCellSurface(frame, showOverlay)
      }
      .width(frame.width)
      .height(frame.height)
      .position({ x: frame.x, y: frame.y })
      .visibility(Visibility.Hidden)
    } else {
      Stack({ alignContent: Alignment.Center }) {
        this.buildCellSurface(frame, showOverlay)
      }
      .width(frame.width)
      .height(frame.height)
      .position({ x: frame.x, y: frame.y })
      .geometryTransition(mediaGeometryTransitionId(this.cellMessageId(frame.index)))
      .transition(TransitionEffect.OPACITY)
    }
  }

  @Builder
  private buildAlbumContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.albumLayout().frames, (frame: TgPhotoAlbumFrame, index: number) => {
        this.buildCell(frame, this.hiddenCount() > 0 && index === this.renderedPhotoCount() - 1)
      }, (frame: TgPhotoAlbumFrame) => frame.index.toString())
    }
    .width(this.bubbleWidth())
    .height(this.bubbleHeight())
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
