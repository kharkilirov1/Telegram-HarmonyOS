@ComponentV2
export struct ProxyAddButtonCard {
  @Event onAdd: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text('+')
          .fontSize(20)
          .fontColor($r('app.color.telegram_blue'))
          .margin({ right: 8 })

        Text($r('app.string.add_proxy'))
          .fontSize(16)
          .fontColor($r('app.color.telegram_blue'))
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(24)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 12, right: 12 })
    .accessibilityText($r('app.string.accessibility_add_proxy'))
    .onClick(() => {
      this.onAdd();
    })
  }
}
