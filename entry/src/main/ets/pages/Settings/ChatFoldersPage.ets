// Chat Folders management page
// Reference: Telegram iOS FiltersSettingsController, Android FiltersSetupActivity

@Builder
export function ChatFoldersBuilder(name: string, param: Object) {
  ChatFoldersPage()
}

interface ChatFolder {
  id: number;
  name: string;
  icon: string;
  chatCount: number;
}

@ComponentV2
export struct ChatFoldersPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local folders: ChatFolder[] = [
    { id: 1, name: 'Personal', icon: '\u{1F464}', chatCount: 5 },
    { id: 2, name: 'Work', icon: '\u{1F4BC}', chatCount: 3 },
    { id: 3, name: 'Unread', icon: '\u{1F4AC}', chatCount: 8 },
    { id: 4, name: 'Groups', icon: '\u{1F465}', chatCount: 4 },
    { id: 5, name: 'Channels', icon: '\u{1F4E2}', chatCount: 6 },
  ];

  @Local recommendedFolders: ChatFolder[] = [
    { id: 100, name: 'Bots', icon: '\u{1F916}', chatCount: 0 },
    { id: 101, name: 'News', icon: '\u{1F4F0}', chatCount: 0 },
  ];

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .accessibilityText($r('app.string.accessibility_back'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.settings_chat_folders'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)

          Text($r('app.string.edit'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
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
            // --- Your Folders ---
            this.sectionHeader($r('app.string.your_folders'))

            Column() {
              // Create new folder button
              Row() {
                Image($r('app.media.ic_edit'))
                  .width(24).height(24)
                  .fillColor($r('app.color.telegram_blue'))
                  .margin({ right: 12 })

                Text($r('app.string.create_new_folder'))
                  .fontSize(16)
                  .fontColor($r('app.color.telegram_blue'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })

              Divider().strokeWidth(0.5).color($r('app.color.separator'))

              // Existing folders
              ForEach(this.folders, (folder: ChatFolder, index: number) => {
                Row() {
                  Text(folder.icon)
                    .fontSize(22)
                    .margin({ right: 12 })

                  Text(folder.name)
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)

                  Text(`${folder.chatCount} chats`)
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))

                  Image($r('app.media.ic_forward'))
                    .width(16).height(16)
                    .fillColor($r('app.color.text_secondary'))
                    .margin({ left: 8 })
                }
                .width('100%').height(48)
                .padding({ left: 16, right: 16 })

                if (index < this.folders.length - 1) {
                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
                }
              }, (folder: ChatFolder) => folder.id.toString())
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Text($r('app.string.folders_hint'))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, top: 6 })

            Blank().height(24)

            // --- Recommended ---
            this.sectionHeader($r('app.string.recommended_folders'))

            Column() {
              ForEach(this.recommendedFolders, (folder: ChatFolder, index: number) => {
                Row() {
                  Text(folder.icon)
                    .fontSize(22)
                    .margin({ right: 12 })

                  Text(folder.name)
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)

                  Button($r('app.string.add'))
                    .fontSize(14)
                    .fontColor($r('app.color.telegram_blue'))
                    .backgroundColor(Color.Transparent)
                    .borderWidth(1)
                    .borderColor($r('app.color.telegram_blue'))
                    .borderRadius(14)
                    .height(28)
                    .onClick(() => {
                      this.addRecommendedFolder(folder);
                    })
                }
                .width('100%').height(48)
                .padding({ left: 16, right: 16 })

                if (index < this.recommendedFolders.length - 1) {
                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
                }
              }, (folder: ChatFolder) => folder.id.toString())
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
    }
    .hideTitleBar(true)
  }

  @Builder
  sectionHeader(title: ResourceStr) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 32, bottom: 6, top: 2 })
  }

  private addRecommendedFolder(folder: ChatFolder): void {
    this.folders = [...this.folders, folder];
    this.recommendedFolders = this.recommendedFolders.filter(f => f.id !== folder.id);
  }
}
