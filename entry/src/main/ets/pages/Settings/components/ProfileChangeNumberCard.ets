@ComponentV2
export struct ProfileChangeNumberCard {
  @Event onOpen: () => void = () => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_phone_call'))
          .width(22)
          .height(22)
          .fillColor($r('app.color.settings_icon_orange'))
          .margin({ right: 12 })
        Text($r('app.string.profile_change_number'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Image($r('app.media.ic_forward'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
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
    .onClick(() => {
      this.onOpen();
    })
  }
}
