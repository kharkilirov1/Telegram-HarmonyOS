import { SettingsIconBadge } from './SettingsIconBadge';

@ComponentV2
export struct SettingsQuickActionsSection {
  @Event onOpenSavedMessages: () => void = () => {};
  @Event onOpenRecentCalls: () => void = () => {};
  @Event onOpenDevices: () => void = () => {};
  @Event onOpenChatFolders: () => void = () => {};

  build() {
    Column() {
      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_saved'),
          bgColor: $r('app.color.telegram_blue')
        })

        Text($r('app.string.saved_messages'))
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
        this.onOpenSavedMessages();
      })

      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.separator'))
        .margin({ left: 52 })

      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_phone_call'),
          bgColor: $r('app.color.settings_icon_green')
        })

        Text($r('app.string.settings_recent_calls'))
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
        this.onOpenRecentCalls();
      })

      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.separator'))
        .margin({ left: 52 })

      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_device'),
          bgColor: $r('app.color.settings_icon_orange')
        })

        Text($r('app.string.settings_devices'))
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
        this.onOpenDevices();
      })

      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.separator'))
        .margin({ left: 52 })

      Row() {
        SettingsIconBadge({
          icon: $r('app.media.ic_folder'),
          bgColor: $r('app.color.telegram_blue')
        })

        Text($r('app.string.settings_chat_folders'))
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
        this.onOpenChatFolders();
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 16, right: 16 })
  }
}
