import { TypingIndicator } from '../../../components/Common/TypingIndicator';

@ComponentV2
export struct ChatHeader {
  @Param chatPhoto: string | null = null;
  @Param chatInitial: string = '';
  @Param chatTitle: string = '';
  @Param isTyping: boolean = false;
  @Param typingText: string = '';
  @Param lastSeenText: string = '';
  @Param isOnline: boolean = false;

  @Event onBack: () => void = () => {};
  @Event onOpenInfo: () => void = () => {};
  @Event onCall: () => void = () => {};
  @Event onSearch: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .accessibilityText($r('app.string.accessibility_back'))
        .onClick(() => { this.onBack(); })

      if (this.chatPhoto) {
        Image(this.chatPhoto)
          .alt($r('app.media.app_icon'))
          .autoResize(true)
          .onError(() => {})
          .width(36)
          .height(36)
          .borderRadius(18)
          .margin({ left: 8 })
      } else {
        Text(this.chatInitial)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.icon_on_primary'))
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor($r('app.color.telegram_blue'))
          .textAlign(TextAlign.Center)
          .margin({ left: 8 })
      }

      Column() {
        Text(this.chatTitle)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)

        if (this.isTyping) {
          TypingIndicator({
            typingText: this.typingText.length > 0
              ? this.typingText
              : getContext(this).resourceManager.getStringByNameSync('typing')
          })
        } else {
          Text(this.lastSeenText)
            .fontSize(13)
            .fontColor(this.isOnline
              ? $r('app.color.online_indicator')
              : $r('app.color.text_secondary'))
        }
      }
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => { this.onOpenInfo(); })

      Image($r('app.media.ic_phone_call'))
        .width(22)
        .height(22)
        .fillColor($r('app.color.telegram_blue'))
        .margin({ right: 16 })
        .onClick(() => { this.onCall(); })

      Image($r('app.media.ic_search'))
        .width(22)
        .height(22)
        .fillColor($r('app.color.telegram_blue'))
        .margin({ right: 16 })
        .onClick(() => { this.onSearch(); })

      Image($r('app.media.ic_more'))
        .width(22)
        .height(22)
        .fillColor($r('app.color.telegram_blue'))
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 16 })
    .backgroundColor($r('app.color.glass_nav_bg'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
