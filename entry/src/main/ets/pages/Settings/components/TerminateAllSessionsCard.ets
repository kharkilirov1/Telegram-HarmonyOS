@ComponentV2
export struct TerminateAllSessionsCard {
  @Event onTap: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text($r('app.string.terminate_all_sessions'))
          .fontSize(16)
          .fontColor($r('app.color.logout_red'))
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Center)
      .accessibilityText($r('app.string.accessibility_terminate_all'))
      .onClick(() => {
        this.onTap();
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 16, right: 16 })
  }
}
