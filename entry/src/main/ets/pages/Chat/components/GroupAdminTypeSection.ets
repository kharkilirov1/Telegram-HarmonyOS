@ComponentV2
export struct GroupAdminTypeSection {
  @Param isPublic: boolean = false;
  @Event onToggle: () => void = () => {};

  build() {
    Column() {
      Text($r('app.string.group_type'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Row() {
        Column() {
          Text($r('app.string.public_group'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.public_group_hint'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.isPublic })
          .selectedColor($r('app.color.telegram_blue'))
          .onChange((_isOn: boolean) => {
            this.onToggle();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start)
  }
}
