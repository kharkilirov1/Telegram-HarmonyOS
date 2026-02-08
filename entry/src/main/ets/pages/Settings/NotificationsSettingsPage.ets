// Notifications and Sounds settings page
// Reference: Telegram iOS NotificationsSettingsController, Android NotificationsSettingsActivity

import { PreferencesService } from '../../services/PreferencesService';

@Builder
export function NotificationsSettingsBuilder(name: string, param: Object) {
  NotificationsSettingsPage()
}

@ComponentV2
export struct NotificationsSettingsPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local privateChatsNotify: boolean = true;
  @Local privateChatsPreview: boolean = true;
  @Local privateChatsSound: string = 'Default';

  @Local groupNotify: boolean = true;
  @Local groupPreview: boolean = true;
  @Local groupSound: string = 'Default';

  @Local channelNotify: boolean = true;
  @Local channelPreview: boolean = true;
  @Local channelSound: string = 'Default';

  @Local inAppSounds: boolean = true;
  @Local inAppVibrate: boolean = true;
  @Local inAppPreview: boolean = true;

  @Local contactJoined: boolean = true;
  @Local pinnedMessages: boolean = true;

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const prefs = PreferencesService.getInstance();
    this.privateChatsNotify = await prefs.getNotificationsEnabled();
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.settings_notifications_sounds'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })

          Blank()
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

        Scroll() {
          Column() {
            // --- Private Chats ---
            this.sectionHeader('Private Chats')

            Column() {
              this.notificationToggle('Notifications', this.privateChatsNotify, (v: boolean) => {
                this.privateChatsNotify = v;
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle('Message Preview', this.privateChatsPreview, (v: boolean) => {
                this.privateChatsPreview = v;
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.soundRow('Sound', this.privateChatsSound)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Groups ---
            this.sectionHeader('Groups')

            Column() {
              this.notificationToggle('Notifications', this.groupNotify, (v: boolean) => {
                this.groupNotify = v;
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle('Message Preview', this.groupPreview, (v: boolean) => {
                this.groupPreview = v;
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.soundRow('Sound', this.groupSound)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Channels ---
            this.sectionHeader('Channels')

            Column() {
              this.notificationToggle('Notifications', this.channelNotify, (v: boolean) => {
                this.channelNotify = v;
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle('Message Preview', this.channelPreview, (v: boolean) => {
                this.channelPreview = v;
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.soundRow('Sound', this.channelSound)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- In-App Notifications ---
            this.sectionHeader('In-App Notifications')

            Column() {
              this.notificationToggle('In-App Sounds', this.inAppSounds, (v: boolean) => {
                this.inAppSounds = v;
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle('In-App Vibrate', this.inAppVibrate, (v: boolean) => {
                this.inAppVibrate = v;
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle('In-App Preview', this.inAppPreview, (v: boolean) => {
                this.inAppPreview = v;
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Events ---
            this.sectionHeader('Events')

            Column() {
              this.notificationToggle('Contact Joined Telegram', this.contactJoined, (v: boolean) => {
                this.contactJoined = v;
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle('Pinned Messages', this.pinnedMessages, (v: boolean) => {
                this.pinnedMessages = v;
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Reset ---
            Column() {
              Text('Reset All Notifications')
                .fontSize(16)
                .fontColor($r('app.color.error_red'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(48)
                .onClick(() => {
                  this.resetAll();
                })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Text('Undo all custom notification settings for all your chats, groups and channels.')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, right: 32, top: 8 })

            Blank().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  sectionHeader(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 32, bottom: 6, top: 2 })
  }

  @Builder
  notificationToggle(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.telegram_blue'))
        .onChange(onChange)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  soundRow(label: string, soundName: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Text(soundName)
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))

      Image($r('app.media.ic_forward'))
        .width(14).height(14)
        .fillColor($r('app.color.text_secondary'))
        .margin({ left: 6 })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
  }

  private resetAll(): void {
    this.privateChatsNotify = true;
    this.privateChatsPreview = true;
    this.privateChatsSound = 'Default';
    this.groupNotify = true;
    this.groupPreview = true;
    this.groupSound = 'Default';
    this.channelNotify = true;
    this.channelPreview = true;
    this.channelSound = 'Default';
    this.inAppSounds = true;
    this.inAppVibrate = true;
    this.inAppPreview = true;
    this.contactJoined = true;
    this.pinnedMessages = true;
  }
}
