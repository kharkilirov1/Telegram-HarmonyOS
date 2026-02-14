@ComponentV2
export struct CurrentSessionCard {
  @Param appDisplayName: string = '';
  @Param deviceDisplayName: string = '';
  @Param lastActiveLabel: string = '';
  @Param ip: string = '';
  @Param location: string = '';

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.appDisplayName)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.telegram_blue'))

          Text(this.deviceDisplayName)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 4 })

          Text(this.lastActiveLabel)
            .fontSize(12)
            .fontColor($r('app.color.online_indicator'))
            .margin({ top: 4 })

          Row() {
            Text(this.ip)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))

            if (this.location.length > 0) {
              Text(' - ')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))

              Text(this.location)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    }
  }
}
