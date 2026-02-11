import { SettingsIconBadge } from './SettingsIconBadge';

@ComponentV2
export struct SettingsCoreSettingsSection {
  @Event onOpenNotifications: () => void = () => {};
  @Event onOpenPrivacy: () => void = () => {};
  @Event onOpenBiometric: () => void = () => {};
  @Event onOpenDataStorage: () => void = () => {};
  @Event onOpenProxy: () => void = () => {};
  @Event onOpenAppearance: () => void = () => {};
  @Event onOpenLanguage: () => void = () => {};

  build() {
    Column() {
      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_unmute'),
          bgColor: $r('app.color.error_red')
        })

        Text($r('app.string.settings_notifications_sounds'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Image($r('app.media.ic_forward'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onOpenNotifications();
      })

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_lock'),
          bgColor: $r('app.color.settings_icon_blue')
        })

        Text($r('app.string.settings_privacy_security'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Image($r('app.media.ic_forward'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onOpenPrivacy();
      })

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_lock'),
          bgColor: $r('app.color.settings_icon_orange')
        })

        Text($r('app.string.passcode_lock'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Image($r('app.media.ic_forward'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onOpenBiometric();
      })

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_download'),
          bgColor: $r('app.color.settings_icon_green')
        })

        Text($r('app.string.settings_data_storage'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Image($r('app.media.ic_forward'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onOpenDataStorage();
      })

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_forward'),
          bgColor: $r('app.color.settings_icon_green')
        })

        Text($r('app.string.proxy_settings'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Image($r('app.media.ic_forward'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onOpenProxy();
      })

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_photo'),
          bgColor: $r('app.color.settings_icon_purple')
        })

        Text($r('app.string.settings_appearance'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Image($r('app.media.ic_forward'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onOpenAppearance();
      })

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_language'),
          bgColor: $r('app.color.settings_icon_purple')
        })

        Text($r('app.string.settings_language'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Text($r('app.string.language_english'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))

        Image($r('app.media.ic_forward'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
          .margin({ left: 4 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onOpenLanguage();
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
