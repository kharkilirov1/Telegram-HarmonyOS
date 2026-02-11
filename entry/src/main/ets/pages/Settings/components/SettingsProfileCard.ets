@ComponentV2
export struct SettingsProfileCard {
  @Param userName: string = '';
  @Param userPhone: string = '';

  @Event onOpenProfile: () => void = () => {};

  build() {
    Row() {
      Text(this.getInitial())
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(60)
        .height(60)
        .borderRadius(30)
        .backgroundColor($r('app.color.telegram_blue'))
        .textAlign(TextAlign.Center)

      Column() {
        Text(this.userName)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))

        if (this.userPhone.length > 0) {
          Text(this.userPhone)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
      }
      .margin({ left: 16 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.settings_section_bg'))
    .onClick(() => {
      this.onOpenProfile();
    })
  }

  private getInitial(): string {
    return this.userName.length > 0 ? this.userName.charAt(0) : '?';
  }
}
