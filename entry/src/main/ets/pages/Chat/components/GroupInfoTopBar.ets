@ComponentV2
export struct GroupInfoTopBar {
  @Param canEdit: boolean = false;
  @Event onBack: () => void = () => {};
  @Event onEdit: () => void = () => {};

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

      Blank()

      if (this.canEdit) {
        Text($r('app.string.edit'))
          .fontSize(16)
          .fontColor($r('app.color.telegram_blue'))
          .onClick(() => {
            this.onEdit();
          })
      } else {
        Blank()
          .width(32)
      }
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
