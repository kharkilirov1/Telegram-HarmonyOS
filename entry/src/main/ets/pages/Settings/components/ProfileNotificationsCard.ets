@ComponentV2
export struct ProfileNotificationsCard {
  @Param isEnabled: boolean = true;
  @Event onToggle: (isOn: boolean) => void = (_isOn: boolean) => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_unmute'))
          .width(22)
          .height(22)
          .fillColor($r('app.color.settings_icon_green'))
          .margin({ right: 12 })
        Text($r('app.string.settings_notifications'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
          .selectedColor($r('app.color.telegram_blue'))
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
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 16, right: 16 })
  }
}
