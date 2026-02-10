@ComponentV2
export struct SecretChatInfoSection {
  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_lock'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.settings_icon_green'))
          .margin({ right: 12 })

        Text($r('app.string.end_to_end_encryption'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14 })

      Column({ space: 12 }) {
        Text($r('app.string.secret_chat_info_1'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)

        Text($r('app.string.secret_chat_info_2'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)

        Text($r('app.string.secret_chat_info_3'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 14 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 16, right: 16 })
  }
}
