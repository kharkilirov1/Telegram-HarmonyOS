import { SettingsIconBadge } from './SettingsIconBadge';

@ComponentV2
export struct SettingsPrivacySection {
  @Param lastSeenLabel: string = 'Everybody';
  @Event onPickLastSeen: () => void = () => {};

  build() {
    Column() {
      Text($r('app.string.settings_privacy'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, bottom: 6, top: 2 })

      Column() {
        Row() {
          SettingsIconBadge({
            icon: $r('app.media.ic_lock'),
            bgColor: $r('app.color.settings_icon_blue')
          })

          Text($r('app.string.settings_last_seen'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Text(this.lastSeenLabel)
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.onPickLastSeen();
        })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })
    }
    .width('100%')
  }
}
