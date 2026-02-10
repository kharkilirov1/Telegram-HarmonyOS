@ComponentV2
export struct TerminateAllConfirmSheet {
  @Event onConfirm: () => void = () => {};
  @Event onCancel: () => void = () => {};

  build() {
    Column() {
      Text($r('app.string.terminate_all_confirm'))
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .margin({ top: 24, left: 24, right: 24 })

      Text($r('app.string.terminate_all_warning'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ top: 12, left: 24, right: 24 })

      Button($r('app.string.terminate_all_sessions'))
        .type(ButtonType.Capsule)
        .width('80%')
        .height(44)
        .backgroundColor($r('app.color.logout_red'))
        .fontColor($r('app.color.icon_on_primary'))
        .fontSize(16)
        .margin({ top: 24 })
        .onClick(() => {
          this.onConfirm();
        })

      Button($r('app.string.cancel'))
        .type(ButtonType.Capsule)
        .width('80%')
        .height(44)
        .backgroundColor($r('app.color.overlay_gradient_end'))
        .fontColor($r('app.color.telegram_blue'))
        .fontSize(16)
        .margin({ top: 8, bottom: 24 })
        .onClick(() => {
          this.onCancel();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
