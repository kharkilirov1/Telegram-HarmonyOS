@ComponentV2
export struct SecretChatKeySection {
  @Param keyHash: number[] = [];
  @Param compareKeyHint: string = '';

  build() {
    Column() {
      Text($r('app.string.encryption_key'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.telegram_blue'))
        .width('100%')
        .padding({ left: 16, top: 14, bottom: 10 })

      if (this.keyHash.length > 0) {
        Column() {
          ForEach(this.getRows(), (rowIndex: number) => {
            Row({ space: 4 }) {
              ForEach(this.getCols(), (colIndex: number) => {
                Column()
                  .width(36)
                  .height(36)
                  .borderRadius(4)
                  .backgroundColor(this.getKeyColor(
                    this.keyHash[(rowIndex * 6 + colIndex) % this.keyHash.length]
                  ))
              }, (colIndex: number) => `col_${colIndex}`)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .margin({ bottom: 4 })
          }, (rowIndex: number) => `row_${rowIndex}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 14 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Text($r('app.string.key_not_available'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 16, bottom: 14 })
      }

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

      Text(this.compareKeyHint)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: 16, right: 16, top: 10, bottom: 14 })
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 16, right: 16 })
  }

  private getRows(): number[] {
    return [0, 1, 2, 3, 4, 5];
  }

  private getCols(): number[] {
    return [0, 1, 2, 3, 4, 5];
  }

  private getKeyColor(byteValue: number): string {
    const colors: string[] = [
      '#FFFFFF',
      '#D5E6F3',
      '#2D9ED6',
      '#89C85F',
      '#F2A43A',
      '#E5574F'
    ];
    return colors[byteValue % colors.length];
  }
}
