@ComponentV2
export struct DataStorageDualToggleSection {
  @Param title: ResourceStr = '';
  @Param firstLabel: ResourceStr = '';
  @Param firstValue: boolean = false;
  @Param secondLabel: ResourceStr = '';
  @Param secondValue: boolean = false;

  @Event onFirstChange: (value: boolean) => void = (_value: boolean) => {};
  @Event onSecondChange: (value: boolean) => void = (_value: boolean) => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, bottom: 6, top: 2 })

      Column() {
        Row() {
          Text(this.firstLabel)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.firstValue })
            .selectedColor($r('app.color.telegram_blue'))
            .onChange((value: boolean) => {
              this.onFirstChange(value);
            })
            .accessibilityText($r('app.string.accessibility_toggle_auto_download'))
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })

        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        Row() {
          Text(this.secondLabel)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.secondValue })
            .selectedColor($r('app.color.telegram_blue'))
            .onChange((value: boolean) => {
              this.onSecondChange(value);
            })
            .accessibilityText($r('app.string.accessibility_toggle_auto_download'))
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 12, right: 12 })
    }
    .width('100%')
  }
}
