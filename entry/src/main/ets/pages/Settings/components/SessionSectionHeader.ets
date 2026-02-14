@ComponentV2
export struct SessionSectionHeader {
  @Param title: ResourceStr = '';

  build() {
    Text(this.title)
      .fontSize(14)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 32, bottom: 6, top: 2 })
  }
}
