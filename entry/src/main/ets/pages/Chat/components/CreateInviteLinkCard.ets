@ComponentV2
export struct CreateInviteLinkCard {
  @Param isCreating: boolean = false;
  @Event onCreate: () => void = () => {};

  build() {
    Column() {
      Row() {
        if (this.isCreating) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color($r('app.color.telegram_blue'))
            .margin({ right: 12 })
        }
        Text(this.isCreating ? $r('app.string.creating_link') : $r('app.string.create_new_link'))
          .fontSize(16)
          .fontColor($r('app.color.telegram_blue'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .onClick(() => {
        this.onCreate();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }
}
