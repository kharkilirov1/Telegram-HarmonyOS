@ComponentV2
export struct DataStorageActionCard {
  @Param label: ResourceStr = '';
  @Param textColor: ResourceColor = $r('app.color.telegram_blue');
  @Param rowHeight: number = 48;

  @Event onTap: () => void = () => {};

  build() {
    Column() {
      Text(this.label)
        .fontSize(16)
        .fontColor(this.textColor)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(this.rowHeight)
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
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(24)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 12, right: 12 })
  }
}
