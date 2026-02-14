@ComponentV2
export struct SearchSectionHeader {
  @Param title: ResourceStr = '';

  build() {
    Row() {
      Text(this.title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.telegram_blue'))
    }
    .width('100%')
    .height(36)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.background_secondary'))
  }
}
