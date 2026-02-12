import { formatMessageTime } from './MessageUtils';

@ComponentV2
export struct MessageMetaRow {
  @Param date: number = 0;
  @Param isOutgoing: boolean = false;
  @Param isRead: boolean = false;
  @Param isEdited: boolean = false;
  @Param sendState: string = ''; // '' | 'sending' | 'failed'
  @Param tint: ResourceColor = $r('app.color.text_secondary');
  @Param checkTint: ResourceColor = $r('app.color.telegram_blue');

  build() {
    Row() {
      Blank().layoutWeight(1)
      if (this.isEdited) {
        Text($r('app.string.editing_message'))
          .fontSize(11)
          .fontColor(this.tint)
          .fontStyle(FontStyle.Italic)
          .margin({ right: 4 })
      }
      Text(formatMessageTime(this.date))
        .fontSize(11)
        .fontColor(this.tint)
      if (this.isOutgoing) {
        if (this.sendState === 'sending') {
          // Clock icon for pending messages
          Image($r('app.media.ic_clock'))
            .width(16)
            .height(16)
            .fillColor(this.tint)
            .margin({ left: 3 })
        } else if (this.sendState === 'failed') {
          // Error icon for failed messages
          Image($r('app.media.ic_warning'))
            .width(16)
            .height(16)
            .fillColor($r('app.color.swipe_delete'))
            .margin({ left: 3 })
        } else {
          // Confirmed: double check if read, single check if delivered
          Image(this.isRead ? $r('app.media.ic_check_double') : $r('app.media.ic_check_single'))
            .width(16)
            .height(16)
            .fillColor(this.isRead ? this.checkTint : this.tint)
            .margin({ left: 3 })
        }
      }
    }
    .width('100%')
    .margin({ top: 2 })
  }
}
