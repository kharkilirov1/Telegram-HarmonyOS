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
        .padding(12)
        .onClick(() => {
          this.onBack();
        })

      Column() {
        Text($r('app.string.secret_chat'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text(this.userName)
          .fontSize(14)
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
    .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 16, bottomRight: 16 })
    .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
