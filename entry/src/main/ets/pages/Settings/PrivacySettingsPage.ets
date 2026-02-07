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

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const prefs = PreferencesService.getInstance();
    this.lastSeen = await prefs.getLastSeenVisibility();
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
            .fontSize(17)
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

        Scroll() {
          Column() {
            // --- Security section ---
            this.sectionHeader('SECURITY')

            Column() {
              // Passcode Lock
              Row() {
                this.settingsIcon($r('app.media.ic_lock'), $r('app.color.settings_icon_blue'))
                Text('Passcode Lock')
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.passcodeEnabled })
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange((isOn: boolean) => { this.passcodeEnabled = isOn; })
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

              // Two-Step Verification
              Row() {
                this.settingsIcon($r('app.media.ic_lock'), $r('app.color.settings_icon_green'))
                Text('Two-Step Verification')
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text(this.twoStepEnabled ? 'On' : 'Off')
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

              // Active Sessions
              Row() {
                this.settingsIcon($r('app.media.ic_channel'), $r('app.color.settings_icon_orange'))
                Text($r('app.string.settings_devices'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Image($r('app.media.ic_forward'))
                  .width(14).height(14)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Privacy section ---
            this.sectionHeader('PRIVACY')

            Column() {
              this.privacyRow('Phone Number', this.phoneNumber)
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow('Last Seen & Online', this.lastSeen)
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow('Profile Photos', this.profilePhoto)
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow('Forwarded Messages', this.forwards)
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow('Calls', this.calls)
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.privacyRow('Groups & Channels', this.groups)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Auto-Delete section ---
            this.sectionHeader('AUTO-DELETE MESSAGES')

            Column() {
              Row() {
                this.settingsIcon($r('app.media.ic_delete'), $r('app.color.settings_icon_red'))
                Text('Auto-Delete Messages')
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text('Off')
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Delete Account ---
            Column() {
              Row() {
                this.settingsIcon($r('app.media.ic_delete'), $r('app.color.settings_icon_red'))
                Column() {
                  Text('Delete My Account')
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                  Text('If away for 6 months')
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
            .borderRadius(16)
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
  settingsIcon(icon: Resource, bgColor: ResourceColor) {
    Column() {
      Image(icon)
        .width(18).height(18)
        .fillColor(Color.White)
    }
    .width(28).height(28)
    .borderRadius(6)
    .backgroundColor(bgColor)
    .justifyContent(FlexAlign.Center)
    .margin({ right: 12 })
  }

  @Builder
  privacyRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Text(this.formatPrivacyValue(value))
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))

      Image($r('app.media.ic_forward'))
        .width(14).height(14)
        .fillColor($r('app.color.text_secondary'))
        .margin({ left: 6 })
    }
    .width('100%').height(44)
    .padding({ left: 16, right: 16 })
  }

  private formatPrivacyValue(value: string): string {
    switch (value) {
      case 'everybody': return 'Everybody';
      case 'contacts': return 'My Contacts';
      case 'nobody': return 'Nobody';
      default: return 'Everybody';
    }
  }
}
