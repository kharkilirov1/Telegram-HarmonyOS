@ComponentV2
export struct ProfileTopBar {
  @Param isEditing: boolean = false;
  @Param isSaving: boolean = false;

  @Event onBack: () => void = () => {};
  @Event onDone: () => void = () => {};
  @Event onEdit: () => void = () => {};

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

      Blank()

      if (this.isEditing) {
        if (this.isSaving) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color($r('app.color.telegram_blue'))
        } else {
          Text($r('app.string.done'))
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.telegram_blue'))
            .onClick(() => {
              this.onDone();
            })
        }
      } else {
        Text($r('app.string.profile_edit'))
          .fontSize(20)
          .fontColor($r('app.color.telegram_blue'))
          .onClick(() => {
            this.onEdit();
          })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
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
