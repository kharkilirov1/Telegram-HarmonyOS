@ComponentV2
export struct ProfileInfoRow {
  @Param label: Resource = $r('app.string.profile_phone');
  @Param value: string = '';
  @Param icon: Resource = $r('app.media.ic_phone_call');

  build() {
    Row() {
      Image(this.icon)
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .margin({ right: 12 })
      Column() {
        Text(this.value)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        Text(this.label)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }
}
