@ComponentV2
export struct GroupInfoHeaderSection {
  @Param title: string = '';
  @Param photoUrl: string | null = null;
  @Param isChannel: boolean = false;
  @Param memberCount: number = 0;

  private subtitle(): string {
    if (this.isChannel) {
      return `${this.memberCount} subscribers`;
    }
    return `${this.memberCount} members`;
  }

  build() {
    Column() {
      if (this.photoUrl) {
        Image(this.photoUrl)
          .alt($r('app.media.app_icon'))
          .autoResize(true)
          .onError(() => {})
          .width(100)
          .height(100)
          .borderRadius(50)
      } else {
        Text(this.title.length > 0 ? this.title.charAt(0) : '?')
          .fontSize(36)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .width(100)
          .height(100)
          .borderRadius(50)
          .backgroundColor($r('app.color.telegram_blue'))
          .textAlign(TextAlign.Center)
      }

      Text(this.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 12 })

      Text(this.subtitle())
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 2 })
    }
    .width('100%')
    .padding({ top: 24, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
  }
}
