import { GroupedMessage, Message, MessageContentType } from '../../../models/Message';

@ComponentV2
export struct SavedMessageRow {
  @Param groupedMessage: GroupedMessage = new GroupedMessage(new Message(), true, true);
  @Event onLongPress: (message: Message) => void = (_message: Message) => {};

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp * 1000);
    const h = date.getHours().toString().padStart(2, '0');
    const m = date.getMinutes().toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  build() {
    Column() {
      Row() {
        Column() {
          if (this.groupedMessage.message.forwardedFrom.length > 0) {
            Row() {
              Text($r('app.string.forwarded_from', this.groupedMessage.message.forwardedFrom))
                .fontSize(12)
                .fontColor($r('app.color.telegram_blue'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .margin({ bottom: 4 })
          }

          if (this.groupedMessage.message.contentType === MessageContentType.TEXT) {
            Text(this.groupedMessage.message.text)
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .wordBreak(WordBreak.BREAK_ALL)
          } else if (this.groupedMessage.message.contentType === MessageContentType.PHOTO) {
            if (this.groupedMessage.message.photoUrl && this.groupedMessage.message.photoUrl.length > 0) {
              Image(this.groupedMessage.message.photoUrl)
                .width('100%')
                .constraintSize({ maxHeight: 200 })
                .borderRadius(8)
                .objectFit(ImageFit.Contain)
                .alt($r('app.string.photo'))
                .autoResize(true)
                .onError(() => {})
            }
            if (this.groupedMessage.message.text.length > 0) {
              Text(this.groupedMessage.message.text)
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 4 })
            }
          } else if (this.groupedMessage.message.contentType === MessageContentType.DOCUMENT) {
            Row() {
              Image($r('app.media.ic_document'))
                .width(20)
                .height(20)
                .fillColor($r('app.color.telegram_blue'))
              Text(this.groupedMessage.message.fileName || $r('app.string.document_label'))
                .fontSize(14)
                .fontColor($r('app.color.telegram_blue'))
                .margin({ left: 6 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          } else if (this.groupedMessage.message.contentType === MessageContentType.STICKER) {
            Text(this.groupedMessage.message.text)
              .fontSize(48)
          } else {
            Text(`[${this.groupedMessage.message.contentType}]`)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .fontStyle(FontStyle.Italic)
          }

          Row() {
            Text(this.formatTime(this.groupedMessage.message.date))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .margin({ top: 4 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
    }
    .width('100%')
    .padding({
      left: 8,
      right: 8,
      top: this.groupedMessage.isFirstInGroup ? 6 : 1,
      bottom: this.groupedMessage.isLastInGroup ? 6 : 1
    })
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(this.groupedMessage.isFirstInGroup || this.groupedMessage.isLastInGroup ? 12 : 4)
    .margin({
      left: 8,
      right: 8,
      top: this.groupedMessage.isFirstInGroup ? 4 : 0,
      bottom: this.groupedMessage.isLastInGroup ? 4 : 0
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          this.onLongPress(this.groupedMessage.message);
        })
    )
  }
}
