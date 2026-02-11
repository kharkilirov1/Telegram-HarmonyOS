@ComponentV2
export struct SecretChatTopBar {
  @Param userName: string = '';
  @Event onBack: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .onClick(() => {
          this.onBack();
        })

      Column() {
        Text($r('app.string.secret_chat'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text(this.userName)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 16 })
      .layoutWeight(1)

      Image($r('app.media.ic_lock'))
        .width(20)
        .height(20)
        .fillColor($r('app.color.settings_icon_green'))
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
