import { SettingsIconBadge } from './SettingsIconBadge';

@ComponentV2
export struct SettingsNotificationsSection {
  @Param notificationsEnabled: boolean = true;
  @Event onNotificationsEnabledChange: (isOn: boolean) => void = (_isOn: boolean) => {};

  build() {
    Column() {
      Text($r('app.string.settings_notifications'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, bottom: 6, top: 2 })

      Column() {
        Row() {
          SettingsIconBadge({
            icon: $r('app.media.ic_unmute'),
            bgColor: $r('app.color.settings_icon_green')
          })

          Text($r('app.string.settings_notifications_enabled'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.notificationsEnabled })
            .selectedColor($r('app.color.telegram_blue'))
            .onChange((isOn: boolean) => {
              this.onNotificationsEnabledChange(isOn);
            })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })

        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

        Row() {
          SettingsIconBadge({
            icon: $r('app.media.ic_unmute'),
            bgColor: $r('app.color.settings_icon_orange')
          })

          Text($r('app.string.settings_notification_sound'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Text($r('app.string.settings_notification_sound_default'))
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height(48)
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
