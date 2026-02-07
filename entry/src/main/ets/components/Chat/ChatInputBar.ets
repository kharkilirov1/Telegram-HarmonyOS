import { Message } from '../../models/Message';

@Component
export struct ChatInputBar {
  @Link inputText: string;
  @State isRecording: boolean = false;
  @State recordingDuration: number = 0;
  @Prop replyMessage: Message | null = null;

  onSendMessage: (text: string) => void = () => {};
  onAttachTap: () => void = () => {};
  onCancelReply: () => void = () => {};

  build() {
    Column() {
      // Reply bar
      if (this.replyMessage !== null) {
        Row() {
          Divider()
            .vertical(true)
            .strokeWidth(2)
            .color($r('app.color.telegram_blue'))
            .height('100%')

          Column() {
            Text(this.replyMessage.senderName)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.telegram_blue'))
              .maxLines(1)

            Text(this.replyMessage.text)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .margin({ left: 8 })
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(18)
            .height(18)
            .fillColor($r('app.color.text_secondary'))
            .onClick(() => this.onCancelReply())
        }
        .width('100%')
        .height(40)
        .padding({ left: 16, right: 12 })
        .backgroundColor($r('app.color.background_primary'))

        Divider().strokeWidth(0.5).color($r('app.color.separator'))
      }

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Main input row
      Row() {
        if (this.isRecording) {
          this.buildRecordingUI()
        } else {
          // Attach button
          Image($r('sys.media.ohos_ic_public_add'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.text_secondary'))
            .onClick(() => this.onAttachTap())
            .margin({ right: 6 })

          // Text area
          TextArea({ placeholder: 'Message', text: this.inputText })
            .fontSize(16)
            .layoutWeight(1)
            .constraintSize({ minHeight: 36, maxHeight: 120 })
            .backgroundColor($r('app.color.background_secondary'))
            .borderRadius(18)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onChange((value: string) => {
              this.inputText = value;
            })

          // Send / Mic toggle
          if (this.inputText.trim().length > 0) {
            Image($r('sys.media.ohos_ic_public_send'))
              .width(28)
              .height(28)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ left: 6 })
              .onClick(() => {
                const text = this.inputText.trim();
                if (text.length > 0) {
                  this.onSendMessage(text);
                  this.inputText = '';
                }
              })
          } else {
            Image($r('sys.media.ohos_ic_public_voice'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_secondary'))
              .margin({ left: 6 })
              .gesture(
                LongPressGesture({ repeat: false, duration: 200 })
                  .onAction(() => {
                    this.startRecording();
                  })
              )
          }
        }
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.background_primary'))
    }
    .width('100%')
  }

  @Builder
  buildRecordingUI() {
    Row() {
      Circle()
        .width(10)
        .height(10)
        .fill(Color.Red)

      Text(this.formatRecordingDuration())
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 8 })

      Blank().layoutWeight(1)

      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
        Text('Slide to cancel')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 4 })
      }

      Blank().layoutWeight(1)
    }
    .width('100%')
  }

  private formatRecordingDuration(): string {
    const m = Math.floor(this.recordingDuration / 60);
    const s = this.recordingDuration % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private startRecording(): void {
    this.isRecording = true;
    this.recordingDuration = 0;
    // TODO: Start AudioCapturer from @kit.AudioKit
  }
}
