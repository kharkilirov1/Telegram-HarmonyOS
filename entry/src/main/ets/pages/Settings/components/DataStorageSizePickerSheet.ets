@ComponentV2
export struct DataStorageSizePickerSheet {
  @Param title: ResourceStr = '';
  @Param sizeOptions: Array<number> = [];
  @Param sizeLabels: Array<string> = [];
  @Param currentSize: number = 0;

  @Event onSelectSize: (size: number) => void = (_size: number) => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16, bottom: 12 })

      ForEach(this.sizeOptions, (size: number, index: number) => {
        Column() {
          Row() {
            Text(this.getLabel(index, size))
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)

            if (this.currentSize === size) {
              Image($r('app.media.ic_forward'))
                .width(16)
                .height(16)
                .fillColor($r('app.color.telegram_blue'))
            }
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.onSelectSize(size);
          })

          if (index < this.sizeOptions.length - 1) {
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
          }
        }
      }, (size: number) => size.toString())

      Blank().height(34)
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(16)
    .margin({ left: 16, right: 16 })
  }

  private getLabel(index: number, size: number): string {
    if (index >= 0 && index < this.sizeLabels.length) {
      return this.sizeLabels[index];
    }
    return size.toString();
  }
}
