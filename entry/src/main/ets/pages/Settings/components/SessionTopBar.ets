@ComponentV2
export struct SessionTopBar {
  @Event onBack: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .accessibilityText($r('app.string.accessibility_back'))
        .onClick(() => {
          this.onBack();
        })

      Text($r('app.string.active_sessions'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 16 })
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
    .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 16, bottomRight: 16 })
    .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
