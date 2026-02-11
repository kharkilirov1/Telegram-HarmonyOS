export interface SecretChatTimerOption {
  label: string;
  seconds: number;
}

@ComponentV2
export struct SecretChatTimerSection {
  @Param selectedTimerLabel: string = '';
  @Param isSettingTimer: boolean = false;
  @Param showTimerPicker: boolean = false;
  @Param canOpenPicker: boolean = false;
  @Param selectedTimerIndex: number = 0;
  @Param timerOptions: SecretChatTimerOption[] = [];

  @Event onTogglePicker: () => void = () => {};
  @Event onSelectTimer: (index: number, seconds: number) => void = (_index: number, _seconds: number) => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_settings'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.text_secondary'))
          .margin({ right: 12 })

        Text($r('app.string.self_destruct_timer'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        if (this.isSettingTimer) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color($r('app.color.telegram_blue'))
        } else {
          Text(this.selectedTimerLabel)
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        if (this.canOpenPicker) {
          this.onTogglePicker();
        }
      })

      if (this.showTimerPicker) {
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 48 })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.timerOptions, (option: SecretChatTimerOption, index: number) => {
            Text(option.label)
              .fontSize(14)
              .fontColor(index === this.selectedTimerIndex
                ? Color.White
                : $r('app.color.text_primary'))
              .backgroundColor(index === this.selectedTimerIndex
                ? $r('app.color.telegram_blue')
                : $r('app.color.background_secondary'))
              .borderRadius(16)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .margin(4)
              .onClick(() => {
                this.onSelectTimer(index, option.seconds);
              })
          }, (_option: SecretChatTimerOption, index: number) => `timer_${index}`)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      }

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 48 })

      Text($r('app.string.self_destruct_hint'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: 16, right: 16, top: 10, bottom: 14 })
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(24)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 12, right: 12 })
  }
}
