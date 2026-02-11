@ComponentV2
export struct SessionRowItem {
  @Param sessionId: string = '0';
  @Param appDisplayName: string = '';
  @Param deviceDisplayName: string = '';
  @Param lastActiveLabel: string = '';
  @Param ip: string = '';
  @Param location: string = '';
  @Event onTerminate: (sessionId: string) => void = (_sessionId: string) => {};

  build() {
    Row() {
      Column() {
        Row() {
          Text(this.appDisplayName)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Text(this.lastActiveLabel)
            .fontSize(12)
            .fontColor($r('app.color.telegram_blue'))
        }
        .width('100%')

        Text(this.deviceDisplayName)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })

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
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .gesture(
      SwipeGesture({ direction: SwipeDirection.Horizontal })
        .onAction(() => {
          this.onTerminate(this.sessionId);
        })
    )
  }
}
