// Appearance settings page — theme, chat background, font, icon color
// Reference: Telegram iOS AppearanceViewController, Android ThemeActivity

import { PreferencesService } from '../../services/PreferencesService';
import { ConfigurationConstant } from '@kit.AbilityKit';

@Builder
export function AppearanceBuilder(name: string, param: Object) {
  AppearancePage()
}

@ComponentV2
export struct AppearancePage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local themeMode: string = 'system';
  @Local fontSize: number = 16;
  @Local chatCornerRadius: number = 17;
  @Local autoNightMode: boolean = true;

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const prefs = PreferencesService.getInstance();
    this.themeMode = await prefs.getThemeMode();
    this.fontSize = await prefs.getFontSize();
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

          Text($r('app.string.settings_appearance'))
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
            // --- Chat preview ---
            Column() {
              Text($r('app.string.appearance_chat_preview'))
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 16, bottom: 8, top: 16 })

              Column() {
                // Sample incoming message
                Row() {
                  Blank().width(8)
                  Column() {
                    Text($r('app.string.appearance_preview_incoming'))
                      .fontSize(this.fontSize)
                      .fontColor($r('app.color.text_primary'))
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  }
                  .backgroundColor($r('app.color.chat_bubble_incoming'))
                  .borderRadius(this.chatCornerRadius)
                  .constraintSize({ maxWidth: '70%' })
                  Blank()
                }
                .width('100%')
                .margin({ bottom: 4 })

                // Sample outgoing message
                Row() {
                  Blank()
                  Column() {
                    Text($r('app.string.appearance_preview_outgoing'))
                      .fontSize(this.fontSize)
                      .fontColor($r('app.color.text_primary'))
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  }
                  .backgroundColor($r('app.color.chat_bubble_outgoing'))
                  .borderRadius(this.chatCornerRadius)
                  .constraintSize({ maxWidth: '70%' })
                  Blank().width(8)
                }
                .width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.background_secondary'))
              .borderRadius(24)
              .margin({ left: 12, right: 12 })
            }

            Blank().height(16)

            // --- Chat Background (like Telegram iOS/Android) ---
            Column() {
              Row() {
                Image($r('app.media.ic_photo'))
                  .width(20).height(20)
                  .fillColor($r('app.color.text_secondary'))
                  .margin({ right: 12 })
                Text($r('app.string.chat_background'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Image($r('app.media.ic_forward'))
                  .width(16).height(16)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.navPathStack.pushPath(new NavPathInfo('Wallpaper', new Object()));
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // --- Theme section ---
            Text($r('app.string.appearance_color_theme'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, bottom: 6 })

            Column() {
              this.themeOption('system', $r('app.string.settings_theme_system'), $r('app.string.appearance_theme_system_hint'))
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
              this.themeOption('light', $r('app.string.settings_theme_light'), $r('app.string.appearance_theme_light_hint'))
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
              this.themeOption('dark', $r('app.string.settings_theme_dark'), $r('app.string.appearance_theme_dark_hint'))
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // --- Auto Night Mode ---
            Text($r('app.string.appearance_night_mode'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, bottom: 6 })

            Column() {
              Row() {
                Text($r('app.string.appearance_auto_night'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.autoNightMode })
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange((isOn: boolean) => {
                    this.autoNightMode = isOn;
                  })
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })

              Text($r('app.string.appearance_auto_night_hint'))
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 16, right: 16, bottom: 12 })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // --- Text Size ---
            Text($r('app.string.appearance_text_size'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, bottom: 6 })

            Column() {
              Row() {
                Text('A')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ right: 8 })

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

                Text('A')
                  .fontSize(22)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 8 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // --- Bubble corners ---
            Text($r('app.string.appearance_bubble_style'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, bottom: 6 })

            Column() {
              Row() {
                Text($r('app.string.appearance_corner_radius'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Text(this.chatCornerRadius.toString())
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12 })

              Row() {
                Slider({
                  value: this.chatCornerRadius,
                  min: 4,
                  max: 24,
                  step: 1
                })
                  .layoutWeight(1)
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange((value: number) => {
                    this.chatCornerRadius = Math.round(value);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            // --- App Icon ---
            Blank().height(24)

            Text($r('app.string.appearance_app_icon'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, bottom: 6 })

            Column() {
              Row({ space: 16 }) {
                this.appIconOption('#3390EC', true) // Default blue
                this.appIconOption('#34C759', false) // Green
                this.appIconOption('#AF52DE', false) // Purple
                this.appIconOption('#FF9500', false) // Orange
                this.appIconOption('#FF3B30', false) // Red
                this.appIconOption('#1C1C1E', false) // Black
              }
              .width('100%')
              .padding(16)
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

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
  themeOption(mode: string, label: Resource, subtitle: ResourceStr) {
    Row() {
      Radio({ value: mode, group: 'theme' })
        .checked(this.themeMode === mode)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.themeMode = mode;
            PreferencesService.getInstance().setThemeMode(mode);
            this.applyTheme(mode);
          }
        })
        .margin({ right: 12 })

      Column() {
        Text(label)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        Text(subtitle)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  appIconOption(color: string, isSelected: boolean) {
    Column() {
      Column() {
        Image($r('app.media.app_icon'))
          .width(28).height(28)
      }
      .width(48).height(48)
      .borderRadius(12)
      .backgroundColor(color)
      .justifyContent(FlexAlign.Center)
      .borderWidth(isSelected ? 2 : 0)
      .borderColor($r('app.color.telegram_blue'))
    }
  }

  private applyTheme(mode: string): void {
    try {
      const ctx = getContext(this).getApplicationContext();
      switch (mode) {
        case 'light':
          ctx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          break;
        case 'dark':
          ctx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          break;
        default:
          ctx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
          break;
      }
    } catch (e) {
      // Fallback: some environments may not support setColorMode
    }
  }
}
