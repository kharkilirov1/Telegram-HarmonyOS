import { PreferencesService } from '../../services/PreferencesService';
import { AuthController } from '../../controllers/AuthController';

@Builder
export function SettingsBuilder(name: string, param: Object) {
  SettingsPage()
}

@ComponentV2
export struct SettingsPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local themeMode: string = 'system';
  @Local notificationsEnabled: boolean = true;
  @Local notificationSound: string = 'default';
  @Local sendByEnter: boolean = true;
  @Local fontSize: number = 16;
  @Local lastSeenVisibility: string = 'everybody';

  // User info for the profile card
  @Local userName: string = 'User';
  @Local userPhone: string = '+1 234 567 890';

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const prefs = PreferencesService.getInstance();
    this.themeMode = await prefs.getThemeMode();
    this.notificationsEnabled = await prefs.getNotificationsEnabled();
    this.notificationSound = await prefs.getNotificationSound();
    this.sendByEnter = await prefs.getSendByEnter();
    this.fontSize = await prefs.getFontSize();
    this.lastSeenVisibility = await prefs.getLastSeenVisibility();
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.settings'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })

          Blank()

          Text($r('app.string.profile_edit'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
            .onClick(() => {
              this.navPathStack.pushPath({ name: 'Profile' });
            })
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

        // Scrollable settings content
        Scroll() {
          Column() {
            // --- Profile card ---
            Row() {
              Text(this.userName.charAt(0))
                .fontSize(22)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .width(60)
                .height(60)
                .borderRadius(30)
                .backgroundColor($r('app.color.telegram_blue'))
                .textAlign(TextAlign.Center)

              Column() {
                Text(this.userName)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))

                Text(this.userPhone)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
              .margin({ left: 16 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.settings_section_bg'))
            .onClick(() => {
              this.navPathStack.pushPath({ name: 'Profile' });
            })

            this.sectionGap()

            // --- Theme ---
            this.sectionHeader($r('app.string.settings_theme'))

            Column() {
              this.themeOption('system', $r('app.string.settings_theme_system'))
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
              this.themeOption('light', $r('app.string.settings_theme_light'))
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
              this.themeOption('dark', $r('app.string.settings_theme_dark'))
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            this.sectionGap()

            // --- Notifications ---
            this.sectionHeader($r('app.string.settings_notifications'))

            Column() {
              // Notifications toggle
              Row() {
                this.settingsIcon($r('app.media.ic_unmute'), $r('app.color.settings_icon_green'))

                Text($r('app.string.settings_notifications_enabled'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.notificationsEnabled })
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange((isOn: boolean) => {
                    this.notificationsEnabled = isOn;
                    PreferencesService.getInstance().setNotificationsEnabled(isOn);
                  })
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

              // Notification sound
              Row() {
                this.settingsIcon($r('app.media.ic_unmute'), $r('app.color.settings_icon_orange'))

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
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            this.sectionGap()

            // --- Chat settings ---
            this.sectionHeader($r('app.string.settings_chat'))

            Column() {
              // Send by Enter
              Row() {
                this.settingsIcon($r('app.media.ic_send'), $r('app.color.settings_icon_blue'))

                Text($r('app.string.settings_send_by_enter'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.sendByEnter })
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange((isOn: boolean) => {
                    this.sendByEnter = isOn;
                    PreferencesService.getInstance().setSendByEnter(isOn);
                  })
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

              // Font size
              Row() {
                this.settingsIcon($r('app.media.ic_edit'), $r('app.color.settings_icon_purple'))

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

              // Font size slider
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
                    this.fontSize = Math.round(value);
                    PreferencesService.getInstance().setFontSize(this.fontSize);
                  })
                Text('24').fontSize(12).fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 8 })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            this.sectionGap()

            // --- Privacy ---
            this.sectionHeader($r('app.string.settings_privacy'))

            Column() {
              Row() {
                this.settingsIcon($r('app.media.ic_lock'), $r('app.color.settings_icon_blue'))

                Text($r('app.string.settings_last_seen'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Text(this.getLastSeenLabel())
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => this.showLastSeenPicker())
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            this.sectionGap()

            // --- Log out ---
            Column() {
              Text($r('app.string.settings_log_out'))
                .fontSize(16)
                .fontColor($r('app.color.logout_red'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(48)
                .onClick(() => {
                  AuthController.getInstance().logout();
                })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            // Bottom padding
            Blank().height(32)
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
  sectionHeader(title: Resource) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 32, bottom: 6, top: 2 })
      .textTransform(TextTransform.Uppercase)
  }

  @Builder
  sectionGap() {
    Blank().height(24)
  }

  @Builder
  settingsIcon(icon: Resource, bgColor: ResourceColor) {
    Column() {
      Image(icon)
        .width(18)
        .height(18)
        .fillColor(Color.White)
    }
    .width(28)
    .height(28)
    .borderRadius(6)
    .backgroundColor(bgColor)
    .justifyContent(FlexAlign.Center)
    .margin({ right: 12 })
  }

  @Builder
  themeOption(mode: string, label: Resource) {
    Row() {
      Radio({ value: mode, group: 'theme' })
        .checked(this.themeMode === mode)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.themeMode = mode;
            PreferencesService.getInstance().setThemeMode(mode);
          }
        })
        .margin({ right: 12 })

      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
  }

  private getLastSeenLabel(): string {
    switch (this.lastSeenVisibility) {
      case 'everybody': return 'Everybody';
      case 'contacts': return 'My Contacts';
      case 'nobody': return 'Nobody';
      default: return 'Everybody';
    }
  }

  private showLastSeenPicker(): void {
    const options = ['everybody', 'contacts', 'nobody'];
    const current = options.indexOf(this.lastSeenVisibility);
    const nextIndex = (current + 1) % options.length;
    this.lastSeenVisibility = options[nextIndex];
    PreferencesService.getInstance().setLastSeenVisibility(this.lastSeenVisibility);
  }
}
