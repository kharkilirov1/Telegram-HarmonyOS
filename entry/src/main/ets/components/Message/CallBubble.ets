import { Message } from '../../models/Message';
import { MessageMetaRow } from './MessageMetaRow';
import { formatMessageTime } from './MessageUtils';

@ComponentV2
export struct CallBubble {
  @Param message: Message = new Message();

  build() {
    Column() {
      Row() {
        // Call direction indicator — iOS: green/red arrow icon
        Column() {
          Image(this.message.isOutgoing ? $r('app.media.ic_call_outgoing') : $r('app.media.ic_call_incoming'))
            .width(16)
            .height(16)
            .fillColor(this.isMissed() ? '#FF4747' : '#36C033')
        }
        .width(20)
        .margin({ right: 6, top: 2 })

        Column() {
          // iOS: medium 16pt title
          Text(this.getCallLabel())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isMissed() ? $r('app.color.error_red') : $r('app.color.text_primary'))

          // iOS: regular 13pt duration + timestamp (fileDurationColor)
          Row() {
            if (this.message.callDuration > 0) {
              Text(this.formatCallDuration(this.message.callDuration))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
              Text(' \u2022 ')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
            Text(formatMessageTime(this.message.date))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // iOS: call action button (right-aligned)
        Column() {
          Image(this.message.callIsVideo ? $r('app.media.ic_video_call') : $r('app.media.ic_phone_call'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.telegram_blue'))
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.background_secondary'))
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(47)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  private getCallLabel(): string {
    const reason: string = this.message.callDiscardReason;
    const isVideo: boolean = this.message.callIsVideo;

    if (reason === 'missed') {
      return isVideo ? 'Missed Video Call' : 'Missed Call';
    }
    if (reason === 'declined') {
      return isVideo ? 'Declined Video Call' : 'Declined Call';
    }
    if (this.message.isOutgoing) {
      return isVideo ? 'Outgoing Video Call' : 'Outgoing Call';
    }
    return isVideo ? 'Incoming Video Call' : 'Incoming Call';
  }

  private isMissed(): boolean {
    return this.message.callDiscardReason === 'missed' || this.message.callDiscardReason === 'declined';
  }

  private formatCallDuration(totalSeconds: number): string {
    if (totalSeconds <= 0) return '';
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const seconds: number = totalSeconds % 60;
    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }
}
