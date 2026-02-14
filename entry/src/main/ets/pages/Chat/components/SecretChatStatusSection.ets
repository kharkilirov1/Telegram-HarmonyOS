@ComponentV2
export struct SecretChatStatusSection {
  @Param chatState: string = 'creating';
  @Param waitingMessage: string = '';
  @Param errorMessage: string = '';

  build() {
    Column() {
      if (this.chatState === 'creating') {
        LoadingProgress()
          .width(48)
          .height(48)
          .color($r('app.color.telegram_blue'))

        Text($r('app.string.secret_chat_creating'))
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 12 })

        Text(this.waitingMessage)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
          .textAlign(TextAlign.Center)
      } else if (this.chatState === 'active') {
        Image($r('app.media.ic_lock'))
          .width(48)
          .height(48)
          .fillColor($r('app.color.settings_icon_green'))

        Text($r('app.string.secret_chat_active'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.settings_icon_green'))
          .margin({ top: 12 })
      } else {
        Image($r('app.media.ic_close'))
          .width(48)
          .height(48)
          .fillColor($r('app.color.error_red'))

        Text($r('app.string.secret_chat_closed'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.error_red'))
          .margin({ top: 12 })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
            .textAlign(TextAlign.Center)
            .padding({ left: 24, right: 24 })
        }
      }
    }
    .width('100%')
    .padding({ top: 32, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
  }
}
