import { promptAction } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const MEDIA_TAG = 'MediaViewerPage';
const MEDIA_DOMAIN = 0x0001;

@Builder
export function MediaViewerBuilder(name: string, param: Object) {
  MediaViewerPage({ mediaUrl: (param as Record<string, string>)?.url ?? '' })
}

@ComponentV2
export struct MediaViewerPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param mediaUrl: string = '';
  @Local zoomScale: number = 1;
  @Local offsetX: number = 0;
  @Local offsetY: number = 0;
  @Local isToolbarVisible: boolean = true;
  @Local senderName: string = '';
  @Local dateText: string = '';

  private async saveToGallery(): Promise<void> {
    if (this.mediaUrl.length === 0) return;
    try {
      // Copy file to app's files directory with a timestamp-based name
      const timestamp = Date.now();
      const ext = this.mediaUrl.includes('.') ?
        this.mediaUrl.substring(this.mediaUrl.lastIndexOf('.')) : '.jpg';
      const destPath = getContext(this).filesDir + `/saved_media_${timestamp}${ext}`;
      await fileIo.copyFile(this.mediaUrl, destPath);
      promptAction.showToast({ message: 'Saved', duration: 2000, bottom: 80 });
      hilog.info(MEDIA_DOMAIN, MEDIA_TAG, 'Media saved to %{public}s', destPath);
    } catch (e) {
      hilog.error(MEDIA_DOMAIN, MEDIA_TAG, 'Failed to save media: %{public}s', String(e));
      promptAction.showToast({ message: 'Save failed', duration: 2000, bottom: 80 });
    }
  }

  private confirmDelete(): void {
    if (this.mediaUrl.length === 0) return;
    AlertDialog.show({
      message: 'Delete this media?',
      primaryButton: {
        value: 'Cancel',
        action: () => {}
      },
      secondaryButton: {
        value: 'Delete',
        fontColor: Color.Red,
        action: () => {
          this.deleteMedia();
        }
      }
    });
  }

  private async deleteMedia(): Promise<void> {
    try {
      await fileIo.unlink(this.mediaUrl);
      hilog.info(MEDIA_DOMAIN, MEDIA_TAG, 'Media deleted');
      this.navPathStack.pop();
    } catch (e) {
      hilog.error(MEDIA_DOMAIN, MEDIA_TAG, 'Failed to delete media: %{public}s', String(e));
      promptAction.showToast({ message: 'Delete failed', duration: 2000, bottom: 80 });
    }
  }

  build() {
    NavDestination() {
      Stack() {
        // Black background — tap to toggle toolbar
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.media_viewer_bg'))
          .onClick(() => {
            this.isToolbarVisible = !this.isToolbarVisible;
          })

        // Image with pinch-to-zoom + pan (like both platforms)
        if (this.mediaUrl.length > 0) {
          Image(this.mediaUrl)
            .alt($r('app.media.ic_photo'))
            .autoResize(true)
            .onError(() => {})
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .scale({ x: this.zoomScale, y: this.zoomScale })
            .translate({ x: this.offsetX, y: this.offsetY })
            .gesture(
              GestureGroup(GestureMode.Parallel,
                PinchGesture({ fingers: 2 })
                  .onActionUpdate((event: GestureEvent) => {
                    this.zoomScale = Math.max(0.5, Math.min(event.scale, 5));
                  })
                  .onActionEnd(() => {
                    if (this.zoomScale < 1) {
                      this.zoomScale = 1;
                      this.offsetX = 0;
                      this.offsetY = 0;
                    }
                  }),
                PanGesture()
                  .onActionUpdate((event: GestureEvent) => {
                    if (this.zoomScale > 1) {
                      this.offsetX = event.offsetX;
                      this.offsetY = event.offsetY;
                    }
                  })
                  .onActionEnd(() => {
                    if (this.zoomScale <= 1) {
                      this.offsetX = 0;
                      this.offsetY = 0;
                    }
                  })
              )
            )
            .onClick(() => {
              this.isToolbarVisible = !this.isToolbarVisible;
            })
        }

        // Top toolbar (like both platforms — sender name + date on left, more on right)
        if (this.isToolbarVisible) {
          Row() {
            Image($r('app.media.ic_back'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
              .onClick(() => this.navPathStack.pop())

            if (this.senderName.length > 0) {
              Column() {
                Text(this.senderName)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                  .maxLines(1)

                if (this.dateText.length > 0) {
                  Text(this.dateText)
                    .fontSize(12)
                    .fontColor($r('app.color.text_on_overlay'))
                    .maxLines(1)
                }
              }
              .margin({ left: 12 })
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            } else {
              Blank().layoutWeight(1)
            }

            // More actions (like Android Telegram)
            Image($r('app.media.ic_more'))
              .width(22)
              .height(22)
              .fillColor(Color.White)
              .margin({ left: 16 })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.overlay_dark'))
          .position({ x: 0, y: 0 })
        }

        // Bottom toolbar (like iOS Telegram — share, save, delete)
        if (this.isToolbarVisible) {
          Row() {
            // Share — forward to another chat via ForwardPicker
            Image($r('app.media.ic_forward'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
              .onClick(() => {
                const forwardParam: Record<string, Object> = {};
                forwardParam['mediaUrl'] = this.mediaUrl;
                this.navPathStack.pushPath(new NavPathInfo('ForwardPicker', forwardParam));
              })
              .accessibilityText('Share')

            Blank()

            // Save to gallery — copy file to public Downloads directory
            Image($r('app.media.ic_download'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
              .onClick(() => {
                this.saveToGallery();
              })
              .accessibilityText('Save to gallery')

            Blank()

            // Delete — confirm and remove local file
            Image($r('app.media.ic_delete'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
              .onClick(() => {
                this.confirmDelete();
              })
              .accessibilityText('Delete')
          }
          .width('100%')
          .height(56)
          .padding({ left: 32, right: 32 })
          .backgroundColor($r('app.color.overlay_dark'))
          .position({ x: 0, bottom: 0 })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Color.Black)
  }
}
