@ComponentV2
export struct ProxyUseToggleCard {
  @Param useProxy: boolean = false;
  @Event onToggle: (isOn: boolean) => void = (_isOn: boolean) => {};

  build() {
    Column() {
      Row() {
        Text($r('app.string.use_proxy'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.useProxy })
          .selectedColor($r('app.color.telegram_blue'))
          .accessibilityText($r('app.string.accessibility_toggle_proxy'))
          .onChange((isOn: boolean) => {
            this.onToggle(isOn);
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(24)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 12, right: 12, top: 16 })
  }
}
