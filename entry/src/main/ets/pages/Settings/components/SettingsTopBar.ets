@ComponentV2
export struct SettingsTopBar {
  @Event onBack: () => void = () => {};
  @Event onEditProfile: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .onClick(() => {
          this.onBack();
        })

      Text($r('app.string.settings'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 16 })

      Blank()

      Text($r('app.string.profile_edit'))
        .fontSize(16)
        .fontColor($r('app.color.telegram_blue'))
        .onClick(() => {
          this.onEditProfile();
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.glass_nav_bg'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
