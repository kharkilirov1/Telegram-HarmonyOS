@ComponentV2
export struct PasscodeActionsCard {
  @Event onChangePasscode: () => void = () => {};
  @Event onTurnOffPasscode: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text($r('app.string.change_passcode'))
          .fontSize(16)
          .fontColor($r('app.color.telegram_blue'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onChangePasscode();
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

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

      Row() {
        Text($r('app.string.turn_off_passcode'))
          .fontSize(16)
          .fontColor($r('app.color.error_red'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onTurnOffPasscode();
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
