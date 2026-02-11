@ComponentV2
export struct GroupAdminRecentActionsSection {
  @Event onOpen: () => void = () => {};

  build() {
    Column() {
      Text($r('app.string.recent_actions'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Column() {
        Row() {
          Image($r('app.media.ic_forward'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.text_secondary'))
            .margin({ right: 12 })

          Text($r('app.string.view_recent_actions'))
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
        .onClick(() => {
          this.onOpen();
        })
      }
      .width('100%')
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
