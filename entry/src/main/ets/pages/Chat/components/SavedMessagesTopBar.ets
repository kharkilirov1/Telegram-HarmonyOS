@ComponentV2
export struct SavedMessagesTopBar {
  @Event onBack: () => void = () => {};
  @Event onEnterSearch: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .onClick(() => {
          this.onBack();
        })
        .accessibilityText($r('app.string.accessibility_back'))

      Image($r('app.media.ic_saved'))
        .width(36)
        .height(36)
        .fillColor($r('app.color.icon_on_primary'))
        .backgroundColor($r('app.color.settings_icon_blue'))
        .borderRadius(18)
        .padding(6)
        .margin({ left: 8 })

      Column() {
        Text($r('app.string.saved_messages'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .margin({ left: 10 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($r('app.media.ic_search'))
        .width(22)
        .height(22)
        .fillColor($r('app.color.telegram_blue'))
        .onClick(() => {
          this.onEnterSearch();
        })
        .accessibilityText($r('app.string.accessibility_search'))
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 16 })
    .backgroundColor($r('app.color.glass_nav_bg'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
  }
}
