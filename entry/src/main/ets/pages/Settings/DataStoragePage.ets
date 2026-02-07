// Data and Storage settings page
// Reference: Telegram iOS DataSettingsController, Android DataSettingsActivity

@Builder
export function DataStorageBuilder(name: string, param: Object) {
  DataStoragePage()
}

@ComponentV2
export struct DataStoragePage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local autoDownloadPhotos: boolean = true;
  @Local autoDownloadVideos: boolean = false;
  @Local autoDownloadFiles: boolean = false;
  @Local autoPlayGifs: boolean = true;
  @Local autoPlayVideos: boolean = true;
  @Local saveIncoming: boolean = false;
  @Local saveEdited: boolean = false;
  @Local cacheSize: string = '256 MB';

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.settings_data_storage'))
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
            // --- Storage Usage ---
            this.sectionHeader('STORAGE USAGE')

            Column() {
              Row() {
                this.settingsIcon($r('app.media.ic_document'), $r('app.color.settings_icon_blue'))
                Column() {
                  Text('Storage Usage')
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                  Text(this.cacheSize)
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Image($r('app.media.ic_forward'))
                  .width(14).height(14)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(52)
              .padding({ left: 16, right: 16 })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

              Row() {
                this.settingsIcon($r('app.media.ic_channel'), $r('app.color.settings_icon_green'))
                Text('Network Usage')
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

            // --- Auto-Download Media ---
            this.sectionHeader('AUTO-DOWNLOAD MEDIA')

            Column() {
              this.toggleRow('Photos', this.autoDownloadPhotos, (v: boolean) => { this.autoDownloadPhotos = v; })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.toggleRow('Videos', this.autoDownloadVideos, (v: boolean) => { this.autoDownloadVideos = v; })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.toggleRow('Files', this.autoDownloadFiles, (v: boolean) => { this.autoDownloadFiles = v; })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Text('Media will be auto-downloaded over Wi-Fi')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, top: 6 })

            Blank().height(24)

            // --- Auto-play Media ---
            this.sectionHeader('AUTO-PLAY MEDIA')

            Column() {
              this.toggleRow('GIFs', this.autoPlayGifs, (v: boolean) => { this.autoPlayGifs = v; })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.toggleRow('Videos', this.autoPlayVideos, (v: boolean) => { this.autoPlayVideos = v; })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Save to Gallery ---
            this.sectionHeader('SAVE TO GALLERY')

            Column() {
              this.toggleRow('Save Incoming Photos', this.saveIncoming,
                (v: boolean) => { this.saveIncoming = v; })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.toggleRow('Save Edited Photos', this.saveEdited,
                (v: boolean) => { this.saveEdited = v; })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Clear Cache ---
            Column() {
              Text('Clear Cache')
                .fontSize(16)
                .fontColor($r('app.color.logout_red'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(48)
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
  toggleRow(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.telegram_blue'))
        .onChange(onChange)
    }
    .width('100%').height(44)
    .padding({ left: 16, right: 16 })
  }
}
