@ComponentV2
export struct GroupInfoTopBar {
  @Event onBack: () => void = () => {};
  @Event onEdit: () => void = () => {};

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

      Blank()

      Text($r('app.string.edit'))
        .fontSize(16)
        .fontColor($r('app.color.telegram_blue'))
        .onClick(() => {
          this.onEdit();
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
  }
}
