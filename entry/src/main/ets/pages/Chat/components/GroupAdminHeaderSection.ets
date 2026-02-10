@ComponentV2
export struct GroupAdminHeaderSection {
  @Param title: string = '';

  build() {
    Column() {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Text($r('app.string.manage_group_subtitle'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }
}
