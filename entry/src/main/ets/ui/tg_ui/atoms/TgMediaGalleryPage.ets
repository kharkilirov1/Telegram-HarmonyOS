import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgInlineVideoView } from './TgInlineVideoView';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';

@ComponentV2
export struct TgMediaGalleryPage {
  @Param mediaItems: MediaGalleryItem[] = [];
  @Param initialIndex: number = 0;
  @Param statusBarHeight: number = 0;
  @Event onDismiss: () => void = () => {};
  @Event onDownloadRequest: (fileId: number) => void = (_: number) => {};

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

  private swiperController: SwiperController = new SwiperController();
  private videoControllers: Map<number, string> = new Map();

  aboutToAppear(): void {
    this.currentIndex = this.initialIndex;
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

  private isVideoType(type: string): boolean {
    return type === 'video' || type === 'animation' || type === 'videoNote';
  }

  private hasFile(path: string): boolean {
    return typeof path === 'string' && path.trim().length > 0;
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
    if (Math.abs(this.dismissOffsetY) > 100) {
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
            Text(this.currentItem()!.senderName)
              .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.currentItem()!.timestamp)
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor('#B0FFFFFF')
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Image($r('sys.media.ohos_ic_public_cancel'))
          .width(24)
          .height(24)
          .fillColor('#FFFFFF')
          .onClick(() => this.onDismiss())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.statusBarHeight + 12, bottom: 12 })
      .backgroundColor('#80000000')
    }
  }

  @Builder
  private buildBottomBar() {
    if (this.showOverlay && this.currentItem() && this.currentItem()!.caption.trim().length > 0) {
      Row() {
        Text(this.currentItem()!.caption)
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor('#FFFFFF')
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#80000000')
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
          .fontColor('#FFFFFF')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#60000000')
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
      }
      Column({ space: 8 }) {
        Image(TgUiTokens.ICON_RES_DOWNLOAD)
          .width(32)
          .height(32)
          .fillColor('#FFFFFF')
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width(80)
      .height(80)
      .backgroundColor('#60000000')
      .borderRadius(40)
      .onClick(() => this.onDownloadRequest(item.fileId))
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
        Swiper(this.swiperController) {
          ForEach(this.mediaItems, (item: MediaGalleryItem, index: number) => {
            this.buildGalleryItem(item, index)
          }, (item: MediaGalleryItem, index: number) => `gallery_${index}_${item.messageId}`)
        }
        .index(this.initialIndex)
        .loop(false)
        .indicator(false)
        .cachedCount(1)
        .onChange((index: number) => {
          this.handleSwiperChange(index);
        })
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
          .fontColor('#FFFFFF')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#60000000')
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
