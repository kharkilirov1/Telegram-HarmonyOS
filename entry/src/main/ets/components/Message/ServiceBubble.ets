import { Message } from '../../models/Message';
import { getSenderColor } from './MessageUtils';

@ComponentV2
export struct ServiceBubble {
  @Param message: Message = new Message();
  @Param showSenderName: boolean = false;
  @Param isFirstInGroup: boolean = true;

  build() {
    Column() {
      if (this.message.forwardedFrom.length > 0) {
        Column() {
          Row() {
            Image($r('app.media.ic_forward'))
              .width(14)
              .height(14)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ right: 4 })
            Text($r('app.string.forwarded_message'))
              .fontSize(12)
              .fontColor($r('app.color.telegram_blue'))
              .fontStyle(FontStyle.Italic)
          }
          Text(this.message.forwardedFrom)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.telegram_blue'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: 4 })
      }

      if (!this.message.isOutgoing && this.showSenderName && this.isFirstInGroup) {
        Text(this.message.senderName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(getSenderColor(this.message.senderId))
          .margin({ bottom: 2 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
