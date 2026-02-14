@ComponentV2
export struct GroupAdminTopBar {
  @Param isSaving: boolean = false;
  @Event onBack: () => void = () => {};
  @Event onSave: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .padding(12)
        .accessibilityText($r('app.string.accessibility_back'))
        .onClick(() => {
          this.onBack();
        })

      Text($r('app.string.admin_settings'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 16 })
        .layoutWeight(1)

      if (this.isSaving) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('app.color.telegram_blue'))
      } else {
        Text($r('app.string.save'))
          .fontSize(16)
          .fontColor($r('app.color.telegram_blue'))
          .onClick(() => {
            this.onSave();
          })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 12 })
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
