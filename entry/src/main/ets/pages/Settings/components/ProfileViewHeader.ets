@ComponentV2
export struct ProfileViewHeader {
  @Param photoUrl: string | null = null;
  @Param initials: string = '?';
  @Param fullName: string = '';
  @Param isOnline: boolean = false;

  build() {
    Column() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (this.photoUrl) {
          Image(this.photoUrl)
            .alt($r('app.media.app_icon'))
            .autoResize(true)
            .onError(() => {})
            .width(100)
            .height(100)
            .borderRadius(50)
        } else {
          Text(this.initials)
            .fontSize(40)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width(100)
            .height(100)
            .borderRadius(50)
            .backgroundColor($r('app.color.telegram_blue'))
            .textAlign(TextAlign.Center)
        }

        if (this.isOnline) {
          Circle()
            .width(16)
            .height(16)
            .fill($r('app.color.online_indicator'))
            .stroke(Color.White)
            .strokeWidth(2)
            .position({ right: 2, bottom: 2 })
        }
      }

      Text($r('app.string.profile_set_photo'))
        .fontSize(14)
        .fontColor($r('app.color.telegram_blue'))
        .margin({ top: 10 })

      Text(this.fullName)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 12 })

      Text(this.isOnline ? $r('app.string.online') : $r('app.string.last_seen_recently'))
        .fontSize(14)
        .fontColor(this.isOnline
          ? $r('app.color.online_indicator')
          : $r('app.color.text_secondary'))
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 24, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.background_primary'))
  }
}
