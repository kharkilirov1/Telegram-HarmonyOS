// VoiceRecordingBar — voice recording UI with slide-to-cancel and lock modes
// Extracted from ChatInputBar
// Reference: Telegram iOS ChatRecordingButton, Android ChatActivityEnterView

@ComponentV2
export struct VoiceRecordingBar {
  @Param recordingDuration: number = 0;
  @Param recordingLocked: boolean = false;
  @Local slideOffsetX: number = 0;
  @Local slideOffsetY: number = 0;

  @Event onStop: () => void = () => {};
  @Event onCancel: () => void = () => {};
  @Event onLock: () => void = () => {};

  build() {
    if (this.recordingLocked) {
      this.buildLockedMode()
    } else {
      this.buildSlideMode()
    }
  }

  @Builder
  buildLockedMode() {
    Row() {
      // Delete (trash) button
      Image($r('app.media.ic_delete'))
        .width(24).height(24)
        .fillColor($r('app.color.error_red'))
        .onClick(() => { this.onCancel(); })

      // Recording indicator + timer
      Row() {
        Circle()
          .width(8).height(8)
          .fill($r('app.color.recording_red'))

        Text(this.formatDuration())
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 6 })
      }
      .margin({ left: 12 })

      // Waveform preview bars
      Row({ space: 1 }) {
        ForEach(this.generateLiveWaveform(), (amp: number, index: number) => {
          Column()
            .width(3)
            .height(amp * 20)
            .borderRadius(1.5)
            .backgroundColor($r('app.color.telegram_blue'))
        }, (_amp: number, index: number) => index.toString())
      }
      .height(24)
      .alignItems(VerticalAlign.Center)
      .margin({ left: 12 })
      .layoutWeight(1)

      // Send button
      Image($r('app.media.ic_send'))
        .width(28).height(28)
        .fillColor($r('app.color.telegram_blue'))
        .margin({ left: 8 })
        .onClick(() => { this.onStop(); })
    }
    .width('100%')
  }

  @Builder
  buildSlideMode() {
    Row() {
      Circle()
        .width(10).height(10)
        .fill($r('app.color.recording_red'))

      Text(this.formatDuration())
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 8 })

      Blank().layoutWeight(1)

      Row() {
        Image($r('app.media.ic_back'))
          .width(16).height(16)
          .fillColor($r('app.color.text_secondary'))
          .opacity(Math.min(1, Math.abs(this.slideOffsetX) / 60 + 0.4))
        Text($r('app.string.slide_to_cancel'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 4 })
      }
      .translate({ x: this.slideOffsetX * 0.5 })

      Blank().layoutWeight(1)

      // Lock indicator (slide up to lock)
      Column() {
        Image($r('app.media.ic_pin'))
          .width(16).height(16)
          .fillColor($r('app.color.text_secondary'))
      }
      .width(28).height(28)
      .borderRadius(14)
      .backgroundColor($r('app.color.background_secondary'))
      .justifyContent(FlexAlign.Center)
      .opacity(this.slideOffsetY < -20 ? 1 : 0.5)
      .margin({ right: 4 })

      // Stop/send recording button
      Image($r('app.media.ic_send'))
        .width(28).height(28)
        .fillColor($r('app.color.telegram_blue'))
        .onClick(() => { this.onStop(); })
    }
    .width('100%')
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal | PanDirection.Vertical })
        .onActionUpdate((event: GestureEvent) => {
          this.slideOffsetX = Math.min(0, event.offsetX);
          this.slideOffsetY = Math.min(0, event.offsetY);
        })
        .onActionEnd(() => {
          if (this.slideOffsetX < -100) {
            this.onCancel();
          } else if (this.slideOffsetY < -60) {
            this.onLock();
          }
          this.slideOffsetX = 0;
          this.slideOffsetY = 0;
        })
    )
  }

  private formatDuration(): string {
    const m = Math.floor(this.recordingDuration / 60);
    const s = this.recordingDuration % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private generateLiveWaveform(): number[] {
    const bars: number[] = [];
    const count = 20;
    for (let i = 0; i < count; i++) {
      const base = 0.3 + 0.4 * Math.sin((this.recordingDuration * 2 + i) * 0.8);
      bars.push(Math.min(1, Math.max(0.15, base)));
    }
    return bars;
  }
}
