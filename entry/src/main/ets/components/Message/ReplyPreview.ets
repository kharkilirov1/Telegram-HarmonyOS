import { Message } from '../../models/Message';

@ComponentV2
export struct ReplyPreview {
  @Param message: Message = new Message();

  build() {
    if (this.message.replyToMessageId > 0 && this.message.replyPreviewText.length > 0) {
      Row() {
        Divider()
          .vertical(true)
          .strokeWidth(2)
          .color($r('app.color.telegram_blue'))
          .height('100%')

        Column() {
          Text(this.message.replyPreviewSenderName)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.telegram_blue'))
            .maxLines(1)

          Text(this.message.replyPreviewText)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .margin({ left: 8 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(36)
      .margin({ bottom: 4 })
    }
  }
}
