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
                    .fontColor('#B3FFFFFF')
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
          .backgroundColor('#66000000')
          .position({ x: 0, y: 0 })
        }

        // Bottom toolbar (like iOS Telegram — share, save, delete)
        if (this.isToolbarVisible) {
          Row() {
            // Share
            Image($r('app.media.ic_forward'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
              .onClick(() => {
                // TODO: Share action
              })

            Blank()

            // Save to gallery
            Image($r('app.media.ic_download'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
              .onClick(() => {
                // TODO: Save to gallery
              })

            Blank()

            // Delete
            Image($r('app.media.ic_delete'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
              .onClick(() => {
                // TODO: Delete media
              })
          }
          .width('100%')
          .height(56)
          .padding({ left: 32, right: 32 })
          .backgroundColor('#66000000')
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
