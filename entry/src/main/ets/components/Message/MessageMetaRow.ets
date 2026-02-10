import { formatMessageTime } from './MessageUtils';

@ComponentV2
export struct MessageMetaRow {
  @Param date: number = 0;
  @Param isOutgoing: boolean = false;
  @Param isRead: boolean = false;
  @Param tint: ResourceColor = $r('app.color.text_secondary');
  @Param checkTint: ResourceColor = $r('app.color.telegram_blue');

  build() {
    Row() {
      Blank().layoutWeight(1)
      Text(formatMessageTime(this.date))
        .fontSize(11)
        .fontColor(this.tint)
      if (this.isOutgoing) {
        Image(this.isRead ? $r('app.media.ic_check_double') : $r('app.media.ic_check_single'))
          .width(16)
          .height(16)
          .fillColor(this.isRead ? this.checkTint : this.tint)
          .margin({ left: 3 })
      }
    }
    .width('100%')
    .margin({ top: 2 })
  }
}
