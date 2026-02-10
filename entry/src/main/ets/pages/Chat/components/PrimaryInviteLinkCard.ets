@ComponentV2
export struct PrimaryInviteLinkCard {
  @Param primaryLink: string = '';
  @Param copiedLink: string = '';
  @Event onCopy: () => void = () => {};
  @Event onShare: () => void = () => {};

  build() {
    Column() {
      Text($r('app.string.primary_link_label'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Column() {
        Row() {
          Text(this.primaryLink)
            .fontSize(15)
            .fontColor($r('app.color.telegram_blue'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })

        Divider().strokeWidth(0.5).color($r('app.color.separator'))

        Row() {
          Row() {
            Text(this.copiedLink === this.primaryLink ? $r('app.string.copied') : $r('app.string.copy_link'))
              .fontSize(15)
              .fontColor($r('app.color.telegram_blue'))
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.onCopy();
          })

          Divider()
            .vertical(true)
            .strokeWidth(0.5)
            .color($r('app.color.separator'))
            .height(24)

          Row() {
            Text($r('app.string.share'))
              .fontSize(15)
              .fontColor($r('app.color.telegram_blue'))
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.onShare();
          })
        }
        .width('100%')
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 20 })
    .alignItems(HorizontalAlign.Start)
  }
}
