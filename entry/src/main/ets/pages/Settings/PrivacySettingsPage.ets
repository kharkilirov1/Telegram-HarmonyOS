// Privacy and Security settings page
// Reference: Telegram iOS PrivacySettingsController, Android PrivacySettingsActivity

import { PreferencesService } from '../../services/PreferencesService';

@Builder
export function PrivacySettingsBuilder(name: string, param: Object) {
  PrivacySettingsPage()
}

@ComponentV2
export struct PrivacySettingsPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local lastSeen: string = 'everybody';
  @Local profilePhoto: string = 'everybody';
  @Local phoneNumber: string = 'contacts';
  @Local forwards: string = 'everybody';
  @Local calls: string = 'everybody';
  @Local groups: string = 'everybody';
  @Local passcodeEnabled: boolean = false;
  @Local twoStepEnabled: boolean = false;
  @Local autoDeleteSeconds: number = 0;

  aboutToAppear(): void {
    void this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const prefs = PreferencesService.getInstance();
    this.lastSeen = await prefs.getLastSeenVisibility();
    this.profilePhoto = await prefs.getStringSetting('privacy_profile_photo_visibility', 'everybody');
    this.phoneNumber = await prefs.getStringSetting('privacy_phone_visibility', 'contacts');
    this.forwards = await prefs.getStringSetting('privacy_forwards_visibility', 'everybody');
    this.calls = await prefs.getStringSetting('privacy_calls_visibility', 'everybody');
    this.groups = await prefs.getStringSetting('privacy_groups_visibility', 'everybody');
    this.passcodeEnabled = await prefs.getPasscodeEnabled();
    this.twoStepEnabled = await prefs.getBooleanSetting('privacy_two_step_enabled', false);
    this.autoDeleteSeconds = await prefs.getNumberSetting('privacy_auto_delete_seconds', 0);
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

          Text($r('app.string.settings_privacy_security'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Scroll() {
          Column() {
            // --- Security section ---
            this.sectionHeader($r('app.string.privacy_section_security'))

            Column() {
              // Passcode Lock
              Row() {
                this.settingsIcon($r('app.media.ic_lock'), $r('app.color.settings_icon_blue'))
                Text($r('app.string.passcode_lock'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.passcodeEnabled })
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange((isOn: boolean) => {
                    this.passcodeEnabled = isOn;
                    void PreferencesService.getInstance().setPasscodeEnabled(isOn);
                  })
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

              // Two-Step Verification
              Row() {
                this.settingsIcon($r('app.media.ic_lock'), $r('app.color.settings_icon_green'))
                Text($r('app.string.two_step_verification'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text(this.twoStepEnabled ? $r('app.string.toggle_on') : $r('app.string.timer_off'))
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.twoStepEnabled = !this.twoStepEnabled;
                void PreferencesService.getInstance()
                  .setBooleanSetting('privacy_two_step_enabled', this.twoStepEnabled);
              })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

              // Active Sessions
              Row() {
                this.settingsIcon($r('app.media.ic_channel'), $r('app.color.settings_icon_orange'))
                Text($r('app.string.settings_devices'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Image($r('app.media.ic_forward'))
                  .width(16).height(16)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => this.navPathStack.pushPath(new NavPathInfo('SessionManagement', new Object())))
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Privacy section ---
            this.sectionHeader($r('app.string.privacy_section_privacy'))

            Column() {
              this.privacyRow($r('app.string.profile_phone'), this.phoneNumber, () => {
                this.phoneNumber = this.nextPrivacyValue(this.phoneNumber);
                void PreferencesService.getInstance().setStringSetting('privacy_phone_visibility', this.phoneNumber);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow($r('app.string.privacy_last_seen_online'), this.lastSeen, () => {
                this.lastSeen = this.nextPrivacyValue(this.lastSeen);
                void PreferencesService.getInstance().setLastSeenVisibility(this.lastSeen);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow($r('app.string.privacy_profile_photos'), this.profilePhoto, () => {
                this.profilePhoto = this.nextPrivacyValue(this.profilePhoto);
                void PreferencesService.getInstance().setStringSetting('privacy_profile_photo_visibility', this.profilePhoto);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow($r('app.string.privacy_forwarded_messages'), this.forwards, () => {
                this.forwards = this.nextPrivacyValue(this.forwards);
                void PreferencesService.getInstance().setStringSetting('privacy_forwards_visibility', this.forwards);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow($r('app.string.calls_title'), this.calls, () => {
                this.calls = this.nextPrivacyValue(this.calls);
                void PreferencesService.getInstance().setStringSetting('privacy_calls_visibility', this.calls);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow($r('app.string.privacy_groups_channels'), this.groups, () => {
                this.groups = this.nextPrivacyValue(this.groups);
                void PreferencesService.getInstance().setStringSetting('privacy_groups_visibility', this.groups);
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Auto-Delete section ---
            this.sectionHeader($r('app.string.privacy_section_auto_delete'))

            Column() {
              Row() {
                this.settingsIcon($r('app.media.ic_delete'), $r('app.color.settings_icon_red'))
                Text($r('app.string.auto_delete_messages'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text(this.getAutoDeleteLabel())
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.autoDeleteSeconds = this.nextAutoDeleteSeconds(this.autoDeleteSeconds);
                void PreferencesService.getInstance().setNumberSetting('privacy_auto_delete_seconds', this.autoDeleteSeconds);
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Delete Account ---
            Column() {
              Row() {
                this.settingsIcon($r('app.media.ic_delete'), $r('app.color.settings_icon_red'))
                Column() {
                  Text($r('app.string.delete_my_account'))
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                  Text($r('app.string.delete_account_inactive_period'))
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%').height(52)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

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
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 32, bottom: 6, top: 2 })
  }

  @Builder
  settingsIcon(icon: Resource, bgColor: ResourceColor) {
    Column() {
      Image(icon)
        .width(18).height(18)
        .fillColor(Color.White)
    }
    .width(28).height(28)
    .borderRadius(8)
    .backgroundColor(bgColor)
    .justifyContent(FlexAlign.Center)
    .margin({ right: 12 })
  }

  @Builder
  privacyRow(label: Resource, value: string, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Text(this.formatPrivacyValue(value))
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))

      Image($r('app.media.ic_forward'))
        .width(16).height(16)
        .fillColor($r('app.color.text_secondary'))
        .margin({ left: 6 })
    }
    .width('100%').height(44)
    .padding({ left: 16, right: 16 })
    .onClick(onTap)
  }

  private formatPrivacyValue(value: string): string {
    switch (value) {
      case 'everybody': return getContext(this).resourceManager.getStringByNameSync('settings_everybody');
      case 'contacts': return getContext(this).resourceManager.getStringByNameSync('settings_my_contacts');
      case 'nobody': return getContext(this).resourceManager.getStringByNameSync('settings_nobody');
      default: return getContext(this).resourceManager.getStringByNameSync('settings_everybody');
    }
  }

  private nextPrivacyValue(current: string): string {
    if (current === 'everybody') return 'contacts';
    if (current === 'contacts') return 'nobody';
    return 'everybody';
  }

  private nextAutoDeleteSeconds(current: number): number {
    if (current <= 0) return 86400; // 1 day
    if (current === 86400) return 604800; // 7 days
    if (current === 604800) return 2592000; // 30 days
    return 0;
  }

  private getAutoDeleteLabel(): string {
    if (this.autoDeleteSeconds <= 0) {
      return getContext(this).resourceManager.getStringByNameSync('timer_off');
    }
    if (this.autoDeleteSeconds === 86400) {
      return this.getString('auto_delete_1_day', '1 day');
    }
    if (this.autoDeleteSeconds === 604800) {
      return this.getString('auto_delete_7_days', '7 days');
    }
    if (this.autoDeleteSeconds === 2592000) {
      return this.getString('auto_delete_30_days', '30 days');
    }
    return `${Math.floor(this.autoDeleteSeconds / 86400)}d`;
  }

  private getString(name: string, fallback: string): string {
    try {
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (_e) {
      return fallback;
    }
  }
}
