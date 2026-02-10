@ComponentV2
export struct SavedMessageInputBar {
  @Param inputText: string = '';
  @Event onInputChange: (value: string) => void = (_value: string) => {};
  @Event onSend: () => void = () => {};

  private hasInputText(): boolean {
    return this.inputText.trim().length > 0;
  }

  build() {
    Row() {
      TextInput({ placeholder: $r('app.string.message_placeholder'), text: this.inputText })
        .onChange((value: string) => {
          this.onInputChange(value);
        })
        .onSubmit(() => {
          this.onSend();
        })
        .layoutWeight(1)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.background_secondary'))
        .padding({ left: 14, right: 14 })
        .fontSize(15)

      if (this.hasInputText()) {
        Image($r('app.media.ic_send'))
          .width(32)
          .height(32)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ left: 8 })
          .onClick(() => {
            this.onSend();
          })
          .accessibilityText($r('app.string.accessibility_send'))
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor($r('app.color.background_primary'))
  }
}
