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
  private readonly soundOptions: string[] = ['Default', 'None'];

  aboutToAppear(): void {
    void this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const prefs = PreferencesService.getInstance();
    const globalEnabled = await prefs.getNotificationsEnabled();
    this.privateChatsNotify = await prefs.getBooleanSetting('notify_private_enabled', globalEnabled);
    this.privateChatsPreview = await prefs.getBooleanSetting('notify_private_preview', true);
    this.privateChatsSound = await prefs.getStringSetting('notify_private_sound', 'Default');

    this.groupNotify = await prefs.getBooleanSetting('notify_group_enabled', true);
    this.groupPreview = await prefs.getBooleanSetting('notify_group_preview', true);
    this.groupSound = await prefs.getStringSetting('notify_group_sound', 'Default');

    this.channelNotify = await prefs.getBooleanSetting('notify_channel_enabled', true);
    this.channelPreview = await prefs.getBooleanSetting('notify_channel_preview', true);
    this.channelSound = await prefs.getStringSetting('notify_channel_sound', 'Default');

    this.inAppSounds = await prefs.getBooleanSetting('notify_inapp_sounds', true);
    this.inAppVibrate = await prefs.getBooleanSetting('notify_inapp_vibrate', true);
    this.inAppPreview = await prefs.getBooleanSetting('notify_inapp_preview', true);

    this.contactJoined = await prefs.getBooleanSetting('notify_event_contact_joined', true);
    this.pinnedMessages = await prefs.getBooleanSetting('notify_event_pinned_messages', true);
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .padding(12)
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.settings_notifications_sounds'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })

          Blank()
        }
        .width('100%')
        .height(48)
        .padding({ left: 12, right: 12 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 24, bottomRight: 24 })
        .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Scroll() {
          Column() {
            // --- Private Chats ---
            this.sectionHeader($r('app.string.notifications_private_chats'))

            Column() {
              this.notificationToggle($r('app.string.settings_notifications_enabled'), this.privateChatsNotify, (v: boolean) => {
                this.privateChatsNotify = v;
                void this.persistBoolean('notify_private_enabled', v);
                void PreferencesService.getInstance().setNotificationsEnabled(v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle($r('app.string.notifications_message_preview'), this.privateChatsPreview, (v: boolean) => {
                this.privateChatsPreview = v;
                void this.persistBoolean('notify_private_preview', v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.soundRow($r('app.string.notifications_sound_label'), this.privateChatsSound, () => {
                this.privateChatsSound = this.nextSound(this.privateChatsSound);
                void this.persistString('notify_private_sound', this.privateChatsSound);
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // --- Groups ---
            this.sectionHeader($r('app.string.notifications_groups'))

            Column() {
              this.notificationToggle($r('app.string.settings_notifications_enabled'), this.groupNotify, (v: boolean) => {
                this.groupNotify = v;
                void this.persistBoolean('notify_group_enabled', v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle($r('app.string.notifications_message_preview'), this.groupPreview, (v: boolean) => {
                this.groupPreview = v;
                void this.persistBoolean('notify_group_preview', v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.soundRow($r('app.string.notifications_sound_label'), this.groupSound, () => {
                this.groupSound = this.nextSound(this.groupSound);
                void this.persistString('notify_group_sound', this.groupSound);
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // --- Channels ---
            this.sectionHeader($r('app.string.notifications_channels'))

            Column() {
              this.notificationToggle($r('app.string.settings_notifications_enabled'), this.channelNotify, (v: boolean) => {
                this.channelNotify = v;
                void this.persistBoolean('notify_channel_enabled', v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle($r('app.string.notifications_message_preview'), this.channelPreview, (v: boolean) => {
                this.channelPreview = v;
                void this.persistBoolean('notify_channel_preview', v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.soundRow($r('app.string.notifications_sound_label'), this.channelSound, () => {
                this.channelSound = this.nextSound(this.channelSound);
                void this.persistString('notify_channel_sound', this.channelSound);
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // --- In-App Notifications ---
            this.sectionHeader($r('app.string.notifications_in_app'))

            Column() {
              this.notificationToggle($r('app.string.notifications_in_app_sounds'), this.inAppSounds, (v: boolean) => {
                this.inAppSounds = v;
                void this.persistBoolean('notify_inapp_sounds', v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle($r('app.string.notifications_in_app_vibrate'), this.inAppVibrate, (v: boolean) => {
                this.inAppVibrate = v;
                void this.persistBoolean('notify_inapp_vibrate', v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle($r('app.string.notifications_in_app_preview'), this.inAppPreview, (v: boolean) => {
                this.inAppPreview = v;
                void this.persistBoolean('notify_inapp_preview', v);
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // --- Events ---
            this.sectionHeader($r('app.string.notifications_events'))

            Column() {
              this.notificationToggle($r('app.string.notifications_contact_joined'), this.contactJoined, (v: boolean) => {
                this.contactJoined = v;
                void this.persistBoolean('notify_event_contact_joined', v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.notificationToggle($r('app.string.notifications_pinned_messages'), this.pinnedMessages, (v: boolean) => {
                this.pinnedMessages = v;
                void this.persistBoolean('notify_event_pinned_messages', v);
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // --- Reset ---
            Column() {
              Text($r('app.string.notifications_reset_all'))
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
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Text($r('app.string.notifications_reset_hint'))
              .fontSize(14)
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
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
  }

  @Builder
  sectionHeader(title: Resource) {
    Text(title)
      .fontSize(14)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 32, bottom: 6, top: 2 })
  }

  @Builder
  notificationToggle(label: Resource, isOn: boolean, onChange: (v: boolean) => void) {
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
  soundRow(label: Resource, soundName: string, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Text(this.getSoundDisplayName(soundName))
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))

      Image($r('app.media.ic_forward'))
        .width(16).height(16)
        .fillColor($r('app.color.text_secondary'))
        .margin({ left: 6 })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(onTap)
  }

  private getSoundDisplayName(soundName: string): string {
    if (soundName === 'Default') {
      return getContext(this).resourceManager.getStringByNameSync('settings_notification_sound_default');
    }
    if (soundName === 'None') {
      return this.getString('notifications_sound_none', 'None');
    }
    return soundName;
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
    void this.persistAllSettings();
  }

  private nextSound(current: string): string {
    const index = this.soundOptions.indexOf(current);
    if (index < 0) {
      return this.soundOptions[0];
    }
    return this.soundOptions[(index + 1) % this.soundOptions.length];
  }

  private async persistBoolean(key: string, value: boolean): Promise<void> {
    await PreferencesService.getInstance().setBooleanSetting(key, value);
  }

  private async persistString(key: string, value: string): Promise<void> {
    await PreferencesService.getInstance().setStringSetting(key, value);
  }

  private async persistAllSettings(): Promise<void> {
    await this.persistBoolean('notify_private_enabled', this.privateChatsNotify);
    await PreferencesService.getInstance().setNotificationsEnabled(this.privateChatsNotify);
    await this.persistBoolean('notify_private_preview', this.privateChatsPreview);
    await this.persistString('notify_private_sound', this.privateChatsSound);

    await this.persistBoolean('notify_group_enabled', this.groupNotify);
    await this.persistBoolean('notify_group_preview', this.groupPreview);
    await this.persistString('notify_group_sound', this.groupSound);

    await this.persistBoolean('notify_channel_enabled', this.channelNotify);
    await this.persistBoolean('notify_channel_preview', this.channelPreview);
    await this.persistString('notify_channel_sound', this.channelSound);

    await this.persistBoolean('notify_inapp_sounds', this.inAppSounds);
    await this.persistBoolean('notify_inapp_vibrate', this.inAppVibrate);
    await this.persistBoolean('notify_inapp_preview', this.inAppPreview);

    await this.persistBoolean('notify_event_contact_joined', this.contactJoined);
    await this.persistBoolean('notify_event_pinned_messages', this.pinnedMessages);
  }

  private getString(name: string, fallback: string): string {
    try {
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (_e) {
      return fallback;
    }
  }
}
