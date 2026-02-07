@Builder
export function MediaViewerBuilder(name: string, param: Object) {
  MediaViewerPage({ mediaUrl: (param as Record<string, string>)?.url ?? '' })
}

@ComponentV2
export struct MediaViewerPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param mediaUrl: string = '';
  @Local scale: number = 1;
  @Local offsetX: number = 0;
  @Local offsetY: number = 0;
  @Local isToolbarVisible: boolean = true;

  build() {
    NavDestination() {
      Stack() {
        // Black background
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.media_viewer_bg'))
          .onClick(() => {
            this.isToolbarVisible = !this.isToolbarVisible;
          })

        // Image with pinch zoom
        if (this.mediaUrl.length > 0) {
          Image(this.mediaUrl)
            .alt($r('app.media.ic_photo'))
            .autoResize(true)
            .onError(() => {})
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .scale({ x: this.scale, y: this.scale })
            .translate({ x: this.offsetX, y: this.offsetY })
            .gesture(
              PinchGesture({ fingers: 2 })
                .onActionUpdate((event: GestureEvent) => {
                  this.scale = Math.max(0.5, Math.min(event.scale, 5));
                })
                .onActionEnd(() => {
                  if (this.scale < 1) {
                    this.scale = 1;
                    this.offsetX = 0;
                    this.offsetY = 0;
                  }
                })
            )
            .onClick(() => {
              this.isToolbarVisible = !this.isToolbarVisible;
            })
        }

        // Top toolbar
        if (this.isToolbarVisible) {
          Row() {
            Image($r('app.media.ic_back'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
              .onClick(() => this.navPathStack.pop())

            Blank()

            Image($r('app.media.ic_forward'))
              .width(22)
              .height(22)
              .fillColor(Color.White)
              .onClick(() => {
                // Share action
              })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#66000000')
          .position({ x: 0, y: 0 })
        }

        // Bottom toolbar
        if (this.isToolbarVisible) {
          Row() {
            Blank()

            Button() {
              Row() {
                Image($r('app.media.ic_download'))
                  .width(20)
                  .height(20)
                  .fillColor(Color.White)
                  .margin({ right: 6 })

                Text($r('app.string.media_save'))
                  .fontSize(14)
                  .fontColor(Color.White)
              }
            }
            .backgroundColor('#66000000')
            .borderRadius(20)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })

            Blank()
          }
          .width('100%')
          .height(56)
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
