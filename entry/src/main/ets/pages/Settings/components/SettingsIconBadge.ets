@ComponentV2
export struct SettingsIconBadge {
  @Param icon: Resource = $r('app.media.ic_saved');
  @Param bgColor: ResourceColor = $r('app.color.telegram_blue');

  build() {
    Column() {
      Image(this.icon)
        .width(18)
        .height(18)
        .fillColor(Color.White)
    }
    .width(28)
    .height(28)
    .borderRadius(8)
    .backgroundColor(this.bgColor)
    .justifyContent(FlexAlign.Center)
    .margin({ right: 12 })
  }
}
