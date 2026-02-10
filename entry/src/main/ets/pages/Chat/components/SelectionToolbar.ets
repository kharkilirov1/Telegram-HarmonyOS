@ComponentV2
export struct SelectionToolbar {
  @Param selectedCount: number = 0;
  @Event onCancel: () => void = () => {};
  @Event onForward: () => void = () => {};
  @Event onDelete: () => void = () => {};

  build() {
    Row() {
      Text($r('app.string.cancel'))
        .fontSize(16)
        .fontColor($r('app.color.telegram_blue'))
        .onClick(() => { this.onCancel(); })

      Blank()

      Text(`${this.selectedCount}`)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .accessibilityText($r('app.string.selected_count'))

      Blank()

      Image($r('app.media.ic_forward'))
        .width(22)
        .height(22)
        .fillColor($r('app.color.telegram_blue'))
        .margin({ right: 16 })
        .onClick(() => { this.onForward(); })

      Image($r('app.media.ic_delete'))
        .width(22)
        .height(22)
        .fillColor($r('app.color.error_red'))
        .onClick(() => { this.onDelete(); })
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
