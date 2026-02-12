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
        .padding(12)
        .onClick(() => {
          this.onBack();
        })
        .accessibilityText($r('app.string.accessibility_back'))

      Image($r('app.media.ic_saved'))
        .width(40)
        .height(40)
        .fillColor($r('app.color.icon_on_primary'))
        .backgroundColor($r('app.color.settings_icon_blue'))
        .borderRadius(20)
        .padding(8)
        .margin({ left: 4 })

      Column() {
        Text($r('app.string.saved_messages'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .margin({ left: 8 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($r('app.media.ic_search'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .padding(12)
        .onClick(() => {
          this.onEnterSearch();
        })
        .accessibilityText($r('app.string.accessibility_search'))
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
    .backgroundColor($r('app.color.glass_nav_bg'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
    .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 24, bottomRight: 24 })
    .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
