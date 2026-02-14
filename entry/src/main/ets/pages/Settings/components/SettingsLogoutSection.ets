@ComponentV2
export struct SettingsLogoutSection {
  @Event onLogout: () => void = () => {};

  build() {
    Column() {
      Text($r('app.string.settings_log_out'))
        .fontSize(16)
        .fontColor($r('app.color.logout_red'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(48)
        .onClick(() => {
          this.onLogout();
        })
        .hoverEffect(HoverEffect.Highlight)
        .opacity(1.0)
        .stateStyles({
          pressed: {
            .opacity(0.6)
          },
          normal: {
            .opacity(1.0)
          }
        })
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(24)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 12, right: 12 })
  }
}
