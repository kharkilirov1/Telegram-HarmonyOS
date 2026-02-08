// Video player page — full-screen video playback with Telegram-style controls
// Reference: Telegram iOS VideoPlayerController, Android VideoPlayerActivity
// HarmonyOS: NavDestination, Video component, Slider, auto-hide overlay

@Builder
export function VideoPlayerBuilder(name: string, param: Object) {
  VideoPlayerPage({
    videoUrl: (param as Record<string, string>)['videoUrl'] ?? '',
    videoDuration: (param as Record<string, number>)['duration'] ?? 0
  })
}

@ComponentV2
export struct VideoPlayerPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param videoUrl: string = '';
  @Param videoDuration: number = 0;

  @Local isPlaying: boolean = false;
  @Local isBuffering: boolean = true;
  @Local showControls: boolean = true;
  @Local currentTime: number = 0;
  @Local totalDuration: number = 0;
  @Local isSeeking: boolean = false;
  @Local seekPosition: number = 0;
  @Local isFullscreen: boolean = false;

  private videoController: VideoController = new VideoController();
  private controlsTimerId: number = -1;

  aboutToAppear(): void {
    this.totalDuration = this.videoDuration;
    this.scheduleHideControls();
  }

  aboutToDisappear(): void {
    this.clearControlsTimer();
  }

  build() {
    NavDestination() {
      Stack() {
        // Black background
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Black)

        // Video component
        if (this.videoUrl.length > 0) {
          Video({
            src: this.videoUrl,
            controller: this.videoController
          })
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .autoPlay(true)
            .controls(false)
            .onStart(() => {
              this.isPlaying = true;
              this.isBuffering = false;
            })
            .onPause(() => {
              this.isPlaying = false;
            })
            .onFinish(() => {
              this.isPlaying = false;
              this.currentTime = this.totalDuration;
              this.showControls = true;
              this.clearControlsTimer();
            })
            .onPrepared((event) => {
              if (event && event.duration > 0) {
                this.totalDuration = event.duration;
              }
              this.isBuffering = false;
            })
            .onUpdate((event) => {
              if (!this.isSeeking && event) {
                this.currentTime = event.time;
              }
            })
            .onError(() => {
              this.isBuffering = false;
            })
            .onClick(() => {
              this.toggleControls();
            })
        }

        // Buffering indicator
        if (this.isBuffering) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color(Color.White)

            Text($r('app.string.loading'))
              .fontSize(14)
              .fontColor('#B3FFFFFF')
              .margin({ top: 12 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .hitTestBehavior(HitTestMode.Transparent)
        }

        // Controls overlay
        if (this.showControls) {
          // Top bar — glass-style back button and title
          Row() {
            // Glass back button
            Column() {
              Image($r('app.media.ic_back'))
                .width(20)
                .height(20)
                .fillColor(Color.White)
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor('#66000000')
            .backgroundBlurStyle(BlurStyle.COMPONENT_THIN, {
              colorMode: ThemeColorMode.DARK,
              adaptiveColor: AdaptiveColor.DEFAULT,
              scale: 1.0
            })
            .justifyContent(FlexAlign.Center)
            .onClick(() => this.navPathStack.pop())

            Text($r('app.string.video_player'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .margin({ left: 12 })
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Blank()
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .linearGradient({
            direction: GradientDirection.Top,
            colors: [['#99000000', 0.0], ['#00000000', 1.0]]
          })
          .position({ x: 0, y: 0 })

          // Bottom controls — play/pause, slider, time, fullscreen
          Column() {
            // Seek slider
            Row() {
              // Current time
              Text(this.formatTime(this.isSeeking ? this.seekPosition : this.currentTime))
                .fontSize(13)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Medium)
                .width(52)
                .textAlign(TextAlign.Center)

              Slider({
                value: this.isSeeking ? this.seekPosition : this.currentTime,
                min: 0,
                max: this.totalDuration > 0 ? this.totalDuration : 1,
                style: SliderStyle.OutSet
              })
                .layoutWeight(1)
                .trackThickness(3)
                .trackColor('#4DFFFFFF')
                .selectedColor(Color.White)
                .blockSize({ width: 14, height: 14 })
                .blockColor(Color.White)
                .onChange((value: number, mode: SliderChangeMode) => {
                  if (mode === SliderChangeMode.Begin) {
                    this.isSeeking = true;
                    this.clearControlsTimer();
                  }
                  this.seekPosition = value;
                  if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                    this.isSeeking = false;
                    this.currentTime = value;
                    this.videoController.setCurrentTime(value);
                    this.scheduleHideControls();
                  }
                })

              // Total duration
              Text(this.formatTime(this.totalDuration))
                .fontSize(13)
                .fontColor('#B3FFFFFF')
                .width(52)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            // Control buttons row
            Row() {
              Blank().layoutWeight(1)

              // Play / Pause button
              Column() {
                Image(this.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
                  .width(28)
                  .height(28)
                  .fillColor(Color.White)
              }
              .width(56)
              .height(56)
              .borderRadius(28)
              .backgroundColor('#66000000')
              .justifyContent(FlexAlign.Center)
              .accessibilityText(this.isPlaying ? $r('app.string.pause') : $r('app.string.play'))
              .onClick(() => {
                this.togglePlayback();
              })

              Blank().layoutWeight(1)

              // Fullscreen toggle
              Image($r('app.media.ic_fullscreen'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
                .margin({ right: 8 })
                .onClick(() => {
                  this.isFullscreen = !this.isFullscreen;
                  this.scheduleHideControls();
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 8 })
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 24, top: 12 })
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [['#99000000', 0.0], ['#00000000', 1.0]]
          })
          .position({ x: 0, bottom: 0 })
        }

        // Center play button when paused and controls hidden (tap to show)
        if (!this.showControls && !this.isPlaying && !this.isBuffering) {
          Column() {
            Image($r('app.media.ic_play'))
              .width(48)
              .height(48)
              .fillColor(Color.White)
              .opacity(0.8)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            this.toggleControls();
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(Color.Black)
  }

  // --- Playback control ---

  private togglePlayback(): void {
    if (this.isPlaying) {
      this.videoController.pause();
      this.isPlaying = false;
      this.clearControlsTimer();
    } else {
      this.videoController.start();
      this.isPlaying = true;
      this.scheduleHideControls();
    }
  }

  // --- Controls visibility ---

  private toggleControls(): void {
    this.showControls = !this.showControls;
    if (this.showControls && this.isPlaying) {
      this.scheduleHideControls();
    } else {
      this.clearControlsTimer();
    }
  }

  private scheduleHideControls(): void {
    this.clearControlsTimer();
    if (this.isPlaying) {
      this.controlsTimerId = setTimeout(() => {
        this.showControls = false;
        this.controlsTimerId = -1;
      }, 3000);
    }
  }

  private clearControlsTimer(): void {
    if (this.controlsTimerId >= 0) {
      clearTimeout(this.controlsTimerId);
      this.controlsTimerId = -1;
    }
  }

  // --- Time formatting ---

  private formatTime(seconds: number): string {
    const totalSeconds = Math.floor(Math.max(0, seconds));
    const h = Math.floor(totalSeconds / 3600);
    const m = Math.floor((totalSeconds % 3600) / 60);
    const s = totalSeconds % 60;
    if (h > 0) {
      return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }
    return `${m}:${s.toString().padStart(2, '0')}`;
  }
}
