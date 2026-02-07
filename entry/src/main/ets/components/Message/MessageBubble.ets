import { Message, MessageContentType } from '../../models/Message';

@Component
export struct MessageBubble {
  @ObjectLink message: Message;

  build() {
    Column() {
      Row() {
        if (!this.message.isOutgoing) {
          Blank()
            .width(48)
        }

        Column() {
          // Sender name (in groups)
          if (!this.message.isOutgoing && this.message.senderName.length > 0) {
            Text(this.message.senderName)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.telegram_blue'))
              .margin({ bottom: 2 })
          }

          // Content based on type
          if (this.message.contentType === MessageContentType.PHOTO && this.message.photoUrl !== null) {
            Image(this.message.photoUrl)
              .width('100%')
              .borderRadius(8)
              .margin({ bottom: 4 })
          }

          if (this.message.text.length > 0) {
            Text(this.message.text)
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
          }

          // Time + read status
          Row() {
            Text(this.formatTime(this.message.date))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))

            if (this.message.isOutgoing) {
              // Read checkmarks
              Image(this.message.isRead
                ? $r('sys.media.ohos_ic_public_ok')
                : $r('sys.media.ohos_ic_public_ok'))
                .width(14)
                .height(14)
                .fillColor(this.message.isRead ? $r('app.color.telegram_blue') : $r('app.color.text_secondary'))
                .margin({ left: 4 })
            }
          }
          .justifyContent(FlexAlign.End)
          .width('100%')
        }
        .padding(8)
        .borderRadius(16)
        .backgroundColor(this.message.isOutgoing ? $r('app.color.chat_bubble_outgoing') : $r('app.color.chat_bubble_incoming'))
        .constraintSize({ maxWidth: '75%' })

        if (this.message.isOutgoing) {
          Blank()
            .width(48)
        }
      }
      .width('100%')
      .justifyContent(this.message.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .margin({ top: 2, bottom: 2 })
  }

  private formatTime(timestamp: number): string {
    if (timestamp === 0) return '';
    const date = new Date(timestamp * 1000);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' } as Intl.DateTimeFormatOptions);
  }
}
