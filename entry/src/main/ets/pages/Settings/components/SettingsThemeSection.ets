@ComponentV2
export struct SettingsThemeSection {
  @Param themeMode: string = 'system';
  @Event onThemeChange: (mode: string) => void = (_mode: string) => {};

  build() {
    Column() {
      Text($r('app.string.settings_theme'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, bottom: 6, top: 2 })

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
    }
    .width('100%')
  }

  @Builder
  private themeOption(mode: string, label: Resource) {
    Row() {
      Radio({ value: mode, group: 'theme' })
        .checked(this.themeMode === mode)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.onThemeChange(mode);
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
}
