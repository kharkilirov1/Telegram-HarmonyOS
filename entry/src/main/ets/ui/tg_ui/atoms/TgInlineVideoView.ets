import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgInlineVideoView {
  @Param videoPath: string = '';
  @Param thumbnailPath: string | Resource = '';
  @Param videoWidth: number = 0;
  @Param videoHeight: number = 0;
  @Param autoPlay: boolean = false;
  @Param loop: boolean = false;
  @Param muted: boolean = true;
  @Param showControls: boolean = false;
  @Param isCircular: boolean = false;
  @Param playbackCommand: string = 'none';
  @Event onTap: () => void = () => {};
  @Event onPlaybackEnd: () => void = () => {};
  @Event onProgressUpdate: (currentSec: number, totalSec: number) => void =
    (_c: number, _t: number) => {};

  @Local private currentState: string = 'idle';
  @Local private showThumb: boolean = true;
  @Local private hasError: boolean = false;
  @Local private totalDuration: number = 0;
  private controller: VideoController = new VideoController();

  @Monitor('playbackCommand')
  onCommandChange(): void {
    if (this.playbackCommand === 'play' && this.hasVideoFile()) {
      this.controller.start();
    } else if (this.playbackCommand === 'pause') {
      this.controller.pause();
    } else if (this.playbackCommand === 'stop') {
      this.controller.stop();
      this.currentState = 'idle';
      this.showThumb = true;
    }
  }

  aboutToDisappear(): void {
    try { this.controller.stop(); } catch (_e) {}
  }

  private hasVideoFile(): boolean {
    return typeof this.videoPath === 'string' && this.videoPath.trim().length > 0;
  }

  private hasThumb(): boolean {
    if (typeof this.thumbnailPath === 'string') {
      return (this.thumbnailPath as string).trim().length > 0;
    }
    return true;
  }

  private radius(): number {
    return this.isCircular ? this.videoHeight / 2 : 0;
  }

  @Builder
  private buildPlayIcon() {
    if (this.showControls && this.currentState !== 'playing' && !this.hasError) {
      Row() {
        TgIcon({
          src: TgUiTokens.ICON_RES_PLAY,
          iconSize: TgUiTokens.VIDEO_BUBBLE_PLAY_ICON_SIZE,
          tintColor: '#FFFFFF'
        })
      }
      .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#40000000')
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
    }
  }

  @Builder
  private buildErrorIcon() {
    if (this.hasError) {
      Column({ space: 4 }) {
        Image($r('sys.media.ohos_ic_public_play_next'))
          .width(24).height(24).fillColor('#FFFFFF')
      }
      .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#40000000')
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
      .onClick(() => {
        this.hasError = false;
        this.currentState = 'idle';
        this.controller.reset();
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasVideoFile()) {
        Video({
          src: this.videoPath,
          controller: this.controller
        })
          .width(this.videoWidth)
          .height(this.videoHeight)
          .autoPlay(this.autoPlay)
          .loop(this.loop)
          .muted(this.muted)
          .controls(this.showControls)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.radius())
          .clip(true)
          .onStart(() => {
            this.currentState = 'playing';
            this.showThumb = false;
            this.hasError = false;
          })
          .onPause(() => {
            this.currentState = 'paused';
          })
          .onFinish(() => {
            if (!this.loop) {
              this.currentState = 'completed';
              this.onPlaybackEnd();
            }
          })
          .onPrepared((event?: DurationObject) => {
            if (event) {
              this.totalDuration = event.duration;
            }
          })
          .onUpdate((event?: TimeObject) => {
            if (event && this.totalDuration > 0) {
              this.onProgressUpdate(event.time, this.totalDuration);
            }
          })
          .onError(() => {
            this.hasError = true;
            this.currentState = 'idle';
            this.showThumb = true;
          })
      }

      if (this.showThumb && this.hasThumb()) {
        Image(this.thumbnailPath)
          .width(this.videoWidth)
          .height(this.videoHeight)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.radius())
          .clip(true)
      }

      this.buildPlayIcon()
      this.buildErrorIcon()
    }
    .width(this.videoWidth)
    .height(this.videoHeight)
    .borderRadius(this.radius())
    .clip(true)
    .onClick(() => this.onTap())
  }
}

interface DurationObject {
  duration: number;
}

interface TimeObject {
  time: number;
}
