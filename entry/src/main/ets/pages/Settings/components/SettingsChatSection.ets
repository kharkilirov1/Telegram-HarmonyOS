import { SettingsIconBadge } from './SettingsIconBadge';

@ComponentV2
export struct SettingsChatSection {
  @Param sendByEnter: boolean = true;
  @Param fontSize: number = 16;

  @Event onSendByEnterChange: (isOn: boolean) => void = (_isOn: boolean) => {};
  @Event onFontSizeChange: (size: number) => void = (_size: number) => {};

  build() {
    Column() {
      Text($r('app.string.settings_chat'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, bottom: 6, top: 2 })

      Column() {
        Row() {
          SettingsIconBadge({
            icon: $r('app.media.ic_send'),
            bgColor: $r('app.color.settings_icon_blue')
          })

          Text($r('app.string.settings_send_by_enter'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.sendByEnter })
            .selectedColor($r('app.color.telegram_blue'))
            .onChange((isOn: boolean) => {
              this.onSendByEnterChange(isOn);
            })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })

        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

        Row() {
          SettingsIconBadge({
            icon: $r('app.media.ic_edit'),
            bgColor: $r('app.color.settings_icon_purple')
          })

          Text($r('app.string.settings_font_size'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Text(this.fontSize.toString())
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .margin({ right: 8 })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })

        Row() {
          Text('12').fontSize(12).fontColor($r('app.color.text_secondary'))

          Slider({
            value: this.fontSize,
            min: 12,
            max: 24,
            step: 1
          })
            .layoutWeight(1)
            .selectedColor($r('app.color.telegram_blue'))
            .onChange((value: number) => {
              this.onFontSizeChange(Math.round(value));
            })

          Text('24').fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
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
