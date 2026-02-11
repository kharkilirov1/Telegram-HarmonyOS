export interface AutoLockPickerOption {
  labelRes: Resource;
  seconds: number;
}

@ComponentV2
export struct AutoLockPickerOverlay {
  @Param options: AutoLockPickerOption[] = [];
  @Param selectedSeconds: number = 0;

  @Event onClose: () => void = () => {};
  @Event onSelect: (seconds: number) => void = (_seconds: number) => {};

  build() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('app.color.overlay_dark'))
        .onClick(() => {
          this.onClose();
        })

      Column() {
        Row() {
          Column()
            .width(36)
            .height(4)
            .borderRadius(2)
            .backgroundColor($r('app.color.separator'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 16 })

        Text($r('app.string.auto_lock_timeout'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8, left: 16 })

        ForEach(this.options, (option: AutoLockPickerOption, index: number) => {
          Row() {
            Text(option.labelRes)
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)

            if (this.selectedSeconds === option.seconds) {
              Image($r('app.media.ic_check'))
                .width(20)
                .height(20)
                .fillColor($r('app.color.telegram_blue'))
            }
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .accessibilityText(option.labelRes)
          .onClick(() => {
            this.onSelect(option.seconds);
          })

          if (index < this.options.length - 1) {
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
          }
        }, (option: AutoLockPickerOption) => option.seconds.toString())

        Blank().height(34)
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius({ topLeft: 16, topRight: 16 })
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: -2 })
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
  }
}
