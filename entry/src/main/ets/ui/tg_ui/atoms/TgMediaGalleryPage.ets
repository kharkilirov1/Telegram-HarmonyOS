import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgInlineVideoView } from './TgInlineVideoView';
import { TgIcon } from './TgIcon';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';

@ComponentV2
export struct TgMediaGalleryPage {
  @Param mediaItems: MediaGalleryItem[] = [];
  @Param initialIndex: number = 0;
  @Param statusBarHeight: number = 0;
  @Event onDismiss: () => void = () => {};
  @Event onIndexChange: (index: number) => void = (_: number) => {};
  @Event onDownloadRequest: (fileId: number) => void = (_: number) => {};
  @Event onDownloadCancel: (fileId: number) => void = (_: number) => {};

  @Local private currentIndex: number = 0;
  @Local private showOverlay: boolean = true;
  @Local private photoScale: number = 1.0;
  @Local private photoOffsetX: number = 0;
  @Local private photoOffsetY: number = 0;
  @Local private pinchStartScale: number = 1.0;
  @Local private panStartX: number = 0;
  @Local private panStartY: number = 0;
  @Local private dismissOffsetY: number = 0;
  @Local private dismissOpacity: number = 1.0;
  @Local private activeVideoCommand: string = 'none';
  @Local private prevVideoCommand: string = 'none';
  @Local private localDownloadVersion: number = 0;

  private swiperController: SwiperController = new SwiperController();
  private videoControllers: Map<number, string> = new Map();
  private localDownloadFileIds: Set<number> = new Set<number>();

  aboutToAppear(): void {
    this.currentIndex = this.clampedIndex(this.initialIndex);
  }

  @Monitor('mediaItems', 'initialIndex')
  onExternalGalleryStateChanged(): void {
    const nextIndex = this.clampedIndex(this.initialIndex);
    if (this.currentIndex !== nextIndex) {
      this.currentIndex = nextIndex;
    }
    this.clearResolvedLocalDownloads();
  }

  aboutToDisappear(): void {
    this.videoControllers.clear();
  }

  private currentItem(): MediaGalleryItem | undefined {
    if (this.currentIndex >= 0 && this.currentIndex < this.mediaItems.length) {
      return this.mediaItems[this.currentIndex];
    }
    return undefined;
  }

  private clampedIndex(index: number): number {
    if (this.mediaItems.length <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(this.mediaItems.length - 1, index));
  }

  private isVideoType(type: string): boolean {
    return type === 'video' || type === 'animation' || type === 'videoNote';
  }

  private hasFile(path: string): boolean {
    return typeof path === 'string' && path.trim().length > 0;
  }

  private hasDownloadProgress(item: MediaGalleryItem): boolean {
    return item.downloadProgress >= 0 && item.downloadProgress < 1;
  }

  private normalizedDownloadProgress(item: MediaGalleryItem): number {
    return Math.max(0, Math.min(1, item.downloadProgress));
  }

  private isLocalDownloadPending(fileId: number): boolean {
    const version = this.localDownloadVersion;
    return version >= 0 && fileId > 0 && this.localDownloadFileIds.has(fileId);
  }

  private clearResolvedLocalDownloads(): void {
    let changed = false;
    for (let i = 0; i < this.mediaItems.length; i++) {
      const item = this.mediaItems[i];
      if (item.fileId > 0 && this.hasFile(item.path) && this.localDownloadFileIds.has(item.fileId)) {
        this.localDownloadFileIds.delete(item.fileId);
        changed = true;
      }
    }
    if (changed) {
      this.localDownloadVersion++;
    }
  }

  private isTransferActive(item: MediaGalleryItem): boolean {
    return item.isDownloading || this.hasDownloadProgress(item) || this.isLocalDownloadPending(item.fileId);
  }

  private handleDownloadToggle(item: MediaGalleryItem): void {
    if (item.fileId <= 0) {
      return;
    }
    if (this.isTransferActive(item)) {
      this.localDownloadFileIds.delete(item.fileId);
      this.localDownloadVersion++;
      this.onDownloadCancel(item.fileId);
      return;
    }
    this.localDownloadFileIds.add(item.fileId);
    this.localDownloadVersion++;
    this.onDownloadRequest(item.fileId);
  }

  private toggleOverlay(): void {
    this.showOverlay = !this.showOverlay;
  }

  private resetZoom(): void {
    this.photoScale = 1.0;
    this.photoOffsetX = 0;
    this.photoOffsetY = 0;
  }

  private handleDoubleTap(): void {
    if (this.photoScale > 1.5) {
      this.resetZoom();
    } else {
      this.photoScale = 2.0;
    }
  }

  private handleSwiperChange(index: number): void {
    // Stop previous video
    this.prevVideoCommand = 'stop';

    this.currentIndex = index;
    this.onIndexChange(index);
    this.resetZoom();

    // Auto-play if current is video/animation
    const item = this.currentItem();
    if (item && this.isVideoType(item.type) && this.hasFile(item.path)) {
      this.activeVideoCommand = 'play';
    } else {
      this.activeVideoCommand = 'none';
    }
  }

  private handleDismissGesture(): void {
    if (Math.abs(this.dismissOffsetY) > TgUiTokens.MEDIA_GALLERY_DISMISS_THRESHOLD) {
      this.onDismiss();
    } else {
      this.dismissOffsetY = 0;
      this.dismissOpacity = 1.0;
    }
  }

  private formatDuration(sec: number): string {
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  @Builder
  private buildTopBar() {
    if (this.showOverlay) {
      Row() {
        Column({ space: 2 }) {
          if (this.currentItem()) {
            Text(this.currentItem()!.senderName.trim().length > 0 ? this.currentItem()!.senderName : 'Media')
              .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(TgUiTokens.MEDIA_GALLERY_TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.currentItem()!.timestamp)
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(TgUiTokens.MEDIA_GALLERY_TEXT_SECONDARY)
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        TgIcon({
          src: TgUiTokens.ICON_RES_CLOSE,
          iconSize: TgUiTokens.MEDIA_GALLERY_CLOSE_ICON_SIZE,
          tintColor: TgUiTokens.MEDIA_GALLERY_TEXT_PRIMARY
        })
          .onClick(() => this.onDismiss())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.statusBarHeight + 12, bottom: 12 })
      .backgroundColor(TgUiTokens.MEDIA_GALLERY_OVERLAY_BG)
    }
  }

  @Builder
  private buildBottomBar() {
    if (this.showOverlay && this.currentItem() && this.currentItem()!.caption.trim().length > 0) {
      Row() {
        Text(this.currentItem()!.caption)
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.MEDIA_GALLERY_TEXT_PRIMARY)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(TgUiTokens.MEDIA_GALLERY_OVERLAY_BG)
    }
  }

  @Builder
  private buildPhotoItem(item: MediaGalleryItem) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasFile(item.path)) {
        Image(item.path)
          .objectFit(ImageFit.Contain)
          .width('100%')
          .height('100%')
          .scale({ x: this.photoScale, y: this.photoScale })
          .translate({ x: this.photoOffsetX, y: this.photoOffsetY })
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.pinchStartScale = this.photoScale;
                })
                .onActionUpdate((event: GestureEvent) => {
                  const newScale = this.pinchStartScale * event.scale;
                  this.photoScale = Math.max(1.0, Math.min(4.0, newScale));
                })
                .onActionEnd(() => {
                  if (this.photoScale < 1.1) {
                    this.resetZoom();
                  }
                }),
              PanGesture({ fingers: 1 })
                .onActionStart(() => {
                  this.panStartX = this.photoOffsetX;
                  this.panStartY = this.photoOffsetY;
                })
                .onActionUpdate((event: GestureEvent) => {
                  if (this.photoScale > 1.0) {
                    this.photoOffsetX = this.panStartX + event.offsetX;
                    this.photoOffsetY = this.panStartY + event.offsetY;
                  } else {
                    // Dismiss gesture when not zoomed
                    this.dismissOffsetY = event.offsetY;
                    this.dismissOpacity = Math.max(0.3, 1 - Math.abs(event.offsetY) / 400);
                  }
                })
                .onActionEnd(() => {
                  if (this.photoScale <= 1.0) {
                    this.handleDismissGesture();
                  }
                })
            )
          )
      } else {
        // Not downloaded — thumbnail + download button
        this.buildNotDownloaded(item)
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => this.toggleOverlay())
    .gesture(
      TapGesture({ count: 2 })
        .onAction(() => this.handleDoubleTap())
    )
  }

  @Builder
  private buildVideoItem(item: MediaGalleryItem, index: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasFile(item.path)) {
        TgInlineVideoView({
          videoPath: item.path,
          thumbnailPath: item.thumbnailPath,
          videoWidth: item.width > 0 ? item.width : 360,
          videoHeight: item.height > 0 ? item.height : 640,
          autoPlay: index === this.currentIndex,
          loop: item.type === 'animation',
          muted: item.type === 'animation',
          showControls: item.type !== 'animation',
          isCircular: false,
          playbackCommand: index === this.currentIndex ? this.activeVideoCommand : this.prevVideoCommand,
          onTap: () => this.toggleOverlay(),
          onPlaybackEnd: () => {}
        })
      } else {
        this.buildNotDownloaded(item)
      }

      // Duration badge for video
      if (item.type === 'video' && item.durationSec > 0) {
        Text(this.formatDuration(item.durationSec))
          .fontSize(12)
          .fontColor(TgUiTokens.MEDIA_GALLERY_TEXT_PRIMARY)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(TgUiTokens.MEDIA_GALLERY_PILL_BG)
          .borderRadius(4)
          .position({ right: 12, bottom: 12 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildNotDownloaded(item: MediaGalleryItem) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasFile(item.thumbnailPath)) {
        Image(item.thumbnailPath)
          .objectFit(ImageFit.Contain)
          .width('100%')
          .height('100%')
          .opacity(0.72)
      }
      Column({ space: 10 }) {
        Column({ space: 8 }) {
          if (this.isTransferActive(item)) {
            Stack({ alignContent: Alignment.Center }) {
              if (this.hasDownloadProgress(item)) {
                Progress({
                  value: this.normalizedDownloadProgress(item) * 100,
                  total: 100,
                  type: ProgressType.Ring
                })
                  .width(TgUiTokens.MEDIA_GALLERY_DOWNLOAD_BUTTON_SIZE)
                  .height(TgUiTokens.MEDIA_GALLERY_DOWNLOAD_BUTTON_SIZE)
                  .color(TgUiTokens.MEDIA_PROGRESS_COLOR)
                  .backgroundColor(Color.Transparent)
                  .style({ strokeWidth: TgUiTokens.MEDIA_PROGRESS_STROKE })
              } else {
                LoadingProgress()
                  .width(TgUiTokens.MEDIA_GALLERY_DOWNLOAD_ICON_SIZE)
                  .height(TgUiTokens.MEDIA_GALLERY_DOWNLOAD_ICON_SIZE)
                  .color(TgUiTokens.MEDIA_PROGRESS_COLOR)
              }
              TgIcon({
                src: TgUiTokens.ICON_RES_CLOSE,
                iconSize: TgUiTokens.MEDIA_CANCEL_ICON_SIZE,
                tintColor: TgUiTokens.MEDIA_PROGRESS_COLOR
              })
            }
            .width(TgUiTokens.MEDIA_GALLERY_DOWNLOAD_BUTTON_SIZE)
            .height(TgUiTokens.MEDIA_GALLERY_DOWNLOAD_BUTTON_SIZE)
          } else {
            TgIcon({
              src: TgUiTokens.ICON_RES_DOWNLOAD,
              iconSize: TgUiTokens.MEDIA_GALLERY_DOWNLOAD_ICON_SIZE,
              tintColor: TgUiTokens.MEDIA_GALLERY_TEXT_PRIMARY
            })
          }
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width(TgUiTokens.MEDIA_GALLERY_DOWNLOAD_BUTTON_SIZE)
        .height(TgUiTokens.MEDIA_GALLERY_DOWNLOAD_BUTTON_SIZE)
        .backgroundColor(TgUiTokens.MEDIA_GALLERY_PILL_BG)
        .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)

        if (item.isDownloadFailed && !this.isTransferActive(item)) {
          Text('Download failed - tap to retry')
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.MEDIA_GALLERY_TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .padding({ left: 16, right: 16 })
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => this.handleDownloadToggle(item))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildGalleryItem(item: MediaGalleryItem, index: number) {
    if (item.type === 'photo') {
      this.buildPhotoItem(item)
    } else {
      this.buildVideoItem(item, index)
    }
  }

  @Builder
  private buildEmptyState() {
    Column({ space: 12 }) {
      TgIcon({
        src: TgUiTokens.ICON_RES_PHOTO,
        iconSize: 44,
        tintColor: TgUiTokens.MEDIA_GALLERY_TEXT_SECONDARY
      })
      Text('No media')
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.MEDIA_GALLERY_TEXT_PRIMARY)
      Text('There is nothing to preview in this chat state.')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.MEDIA_GALLERY_TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ left: 32, right: 32 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Black background
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(this.dismissOpacity)

      // Swiper content
      Column() {
        if (this.mediaItems.length > 0) {
          Swiper(this.swiperController) {
            ForEach(this.mediaItems, (item: MediaGalleryItem, index: number) => {
              this.buildGalleryItem(item, index)
            }, (item: MediaGalleryItem, index: number) => `gallery_${index}_${item.messageId}`)
          }
          .index(this.clampedIndex(this.initialIndex))
          .loop(false)
          .indicator(false)
          .cachedCount(1)
          .onChange((index: number) => {
            this.handleSwiperChange(index);
          })
        } else {
          this.buildEmptyState()
        }
      }
      .width('100%')
      .height('100%')
      .translate({ x: 0, y: this.dismissOffsetY })
      .opacity(this.dismissOpacity)

      // Top overlay bar
      Column() {
        this.buildTopBar()
      }
      .width('100%')
      .position({ top: 0 })

      // Bottom overlay bar
      Column() {
        this.buildBottomBar()
      }
      .width('100%')
      .position({ bottom: 0 })

      // Counter indicator
      if (this.mediaItems.length > 1 && this.showOverlay) {
        Text(`${this.currentIndex + 1} / ${this.mediaItems.length}`)
          .fontSize(14)
          .fontColor(TgUiTokens.MEDIA_GALLERY_TEXT_PRIMARY)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(TgUiTokens.MEDIA_GALLERY_PILL_BG)
          .borderRadius(12)
          .position({ top: this.statusBarHeight + 60 })
          .alignSelf(ItemAlign.Center)
          .width('auto')
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
