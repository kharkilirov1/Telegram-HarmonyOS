@ComponentV2
export struct GroupInfoActionButton {
  @Param icon: Resource = $r('app.media.ic_more');
  @Param label: ResourceStr = '';
  @Event onTap: () => void = () => {};

  build() {
    Column() {
      Column() {
        Image(this.icon)
          .width(24)
          .height(24)
          .fillColor($r('app.color.telegram_blue'))
      }
      .width(52)
      .height(52)
      .borderRadius(24)
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.onTap();
      })
      .hoverEffect(HoverEffect.Highlight)
      .opacity(1.0)
      .stateStyles({
        pressed: {
          .opacity(0.6)
        },
        normal: {
          .opacity(1.0)
        }
      })

      Text(this.label)
        .fontSize(12)
        .fontColor($r('app.color.telegram_blue'))
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
  }
}
