@ComponentV2
export struct SavedMessagesEmptyState {
  build() {
    Column() {
      Image($r('app.media.ic_saved'))
        .width(64)
        .height(64)
        .fillColor($r('app.color.text_secondary'))
        .opacity(0.5)

      Text($r('app.string.saved_messages'))
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16 })

      Text($r('app.string.saved_messages_hint'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
        .padding({ left: 40, right: 40 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }
}
