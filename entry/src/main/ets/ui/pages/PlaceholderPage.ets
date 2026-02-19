// Placeholder page - minimal UI for core-only build
// Will be replaced by actual UI in presentation layer

@Entry
@Component
struct PlaceholderPage {
  build() {
    Column() {
      Text('Telegram Core')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })

      Text('Core runtime initialized.')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 8 })

      Text('UI layer not yet implemented.')
        .fontSize(14)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F5F5')
  }
}
