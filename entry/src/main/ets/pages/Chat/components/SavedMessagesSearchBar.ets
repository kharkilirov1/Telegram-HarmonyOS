@ComponentV2
export struct SavedMessagesSearchBar {
  @Param searchQuery: string = '';
  @Param resultsCount: number = 0;
  @Param currentResultIndex: number = -1;

  @Event onBack: () => void = () => {};
  @Event onQueryChange: (value: string) => void = (_value: string) => {};
  @Event onSubmitSearch: () => void = () => {};
  @Event onPreviousResult: () => void = () => {};
  @Event onNextResult: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .onClick(() => {
          this.onBack();
        })
        .accessibilityText($r('app.string.accessibility_back'))

      TextInput({ placeholder: $r('app.string.search_messages_placeholder'), text: this.searchQuery })
        .onChange((value: string) => {
          this.onQueryChange(value);
        })
        .onSubmit(() => {
          this.onSubmitSearch();
        })
        .layoutWeight(1)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.background_secondary'))
        .padding({ left: 12, right: 12 })
        .fontSize(14)
        .margin({ left: 8 })

      if (this.resultsCount > 0) {
        Text(`${this.currentResultIndex + 1}/${this.resultsCount}`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })

        Image($r('app.media.ic_arrow_up'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ left: 4 })
          .accessibilityText($r('app.string.search_previous_result'))
          .onClick(() => {
            this.onPreviousResult();
          })

        Image($r('app.media.ic_arrow_down'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ left: 4 })
          .accessibilityText($r('app.string.search_next_result'))
          .onClick(() => {
            this.onNextResult();
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 12 })
    .backgroundColor($r('app.color.glass_nav_bg'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
  }
}
