// TgVideoPlayerPage — fullscreen video player using ArkUI Video component.
// Supports local file playback with controls, duration display, and tap-to-dismiss.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';

@ComponentV2
export struct TgVideoPlayerPage {
  @Param videoPath: string = '';
  @Param caption: string = '';
  @Param thumbnailPath: string = '';
  onDismiss: () => void = () => {};

  @Local private isPlaying: boolean = false;
  @Local private isPrepared: boolean = false;
  @Local private currentTime: number = 0;
  @Local private totalDuration: number = 0;
  @Local private showControls: boolean = true;

  private controller: VideoController = new VideoController();
  private hideControlsTimerId: number = -1;

  aboutToDisappear(): void {
    if (this.hideControlsTimerId >= 0) {
      clearTimeout(this.hideControlsTimerId);
      this.hideControlsTimerId = -1;
    }
    try {
      this.controller.stop();
    } catch (_e) {
      // ignore
    }
  }

  private formatTime(seconds: number): string {
    const s = Math.max(0, Math.floor(seconds));
    const hours = Math.floor(s / 3600);
    const minutes = Math.floor((s % 3600) / 60);
    const remainSeconds = s % 60;
    const mm = minutes < 10 ? '0' + minutes.toString() : minutes.toString();
    const ss = remainSeconds < 10 ? '0' + remainSeconds.toString() : remainSeconds.toString();
    if (hours > 0) {
      return hours.toString() + ':' + mm + ':' + ss;
    }
    return minutes.toString() + ':' + ss;
  }

  private togglePlayPause(): void {
    if (this.isPlaying) {
      this.controller.pause();
      this.isPlaying = false;
    } else {
      this.controller.start();
      this.isPlaying = true;
      this.scheduleHideControls();
    }
  }

  private scheduleHideControls(): void {
    if (this.hideControlsTimerId >= 0) {
      clearTimeout(this.hideControlsTimerId);
    }
    this.hideControlsTimerId = setTimeout(() => {
      this.hideControlsTimerId = -1;
      if (this.isPlaying) {
        this.showControls = false;
      }
    }, 3000);
  }

  private toggleControls(): void {
    this.showControls = !this.showControls;
    if (this.showControls && this.isPlaying) {
      this.scheduleHideControls();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Black background
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)

      // Video player
      Video({
        src: this.videoPath,
        previewUri: this.thumbnailPath.length > 0 ? this.thumbnailPath : undefined,
        controller: this.controller
      })
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
        .controls(false)
        .autoPlay(true)
        .loop(false)
        .onPrepared((event) => {
          if (event) {
            this.totalDuration = event.duration;
          }
          this.isPrepared = true;
          this.isPlaying = true;
          this.scheduleHideControls();
        })
        .onUpdate((event) => {
          if (event) {
            this.currentTime = event.time;
          }
        })
        .onFinish(() => {
          this.isPlaying = false;
          this.showControls = true;
        })
        .onError(() => {
          this.isPlaying = false;
          this.showControls = true;
        })
        .onClick(() => {
          this.toggleControls();
        })

      // Controls overlay
      if (this.showControls) {
        // Top bar: close button
        Column() {
          Row() {
            Image($r('app.media.ic_close'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
              .onClick(() => {
                this.onDismiss();
              })

            Blank()

            // Duration text
            if (this.totalDuration > 0) {
              Text(this.formatTime(this.currentTime) + ' / ' + this.formatTime(this.totalDuration))
                .fontSize(14)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Medium)
            }
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 50,
            bottom: 12
          })
          .linearGradient({
            direction: GradientDirection.Top,
            colors: [['rgba(0,0,0,0.5)', 0.0], ['rgba(0,0,0,0)', 1.0]]
          })

          Blank()
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)

        // Center play/pause button
        Row() {
          Image(this.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
            .width(36)
            .height(36)
            .fillColor(Color.White)
        }
        .width(64)
        .height(64)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('rgba(0,0,0,0.5)')
        .borderRadius(32)
        .onClick(() => {
          this.togglePlayPause();
        })
      }

      // Caption at bottom
      if (this.showControls && this.caption.trim().length > 0) {
        Column() {
          Blank()
          Text(this.caption)
            .fontSize(15)
            .fontColor(Color.White)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({
              left: 16,
              right: 16,
              bottom: 40,
              top: 12
            })
            .width('100%')
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [['rgba(0,0,0,0.5)', 0.0], ['rgba(0,0,0,0)', 1.0]]
            })
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
