// Wallpaper page — chat background selection
// Reference: Telegram iOS WallpaperGalleryController, Android WallpapersListActivity
// HarmonyOS: Grid, NavDestination

@Builder
export function WallpaperBuilder(name: string, param: Object) {
  WallpaperPage()
}

interface WallpaperItem {
  id: number;
  color: string;
  name: string;
  isPattern: boolean;
}

@ComponentV2
export struct WallpaperPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local selectedId: number = 0;

  private wallpapers: WallpaperItem[] = [
    { id: 0, color: '#DCE6F1', name: 'Default', isPattern: false },
    { id: 1, color: '#E8D5B7', name: 'Warm Sand', isPattern: false },
    { id: 2, color: '#D5E8D4', name: 'Green Meadow', isPattern: false },
    { id: 3, color: '#D5D5E8', name: 'Lavender', isPattern: false },
    { id: 4, color: '#E8D5D5', name: 'Rose', isPattern: false },
    { id: 5, color: '#D5E0E8', name: 'Ice Blue', isPattern: false },
    { id: 6, color: '#E8E1D5', name: 'Cream', isPattern: false },
    { id: 7, color: '#D5E8E0', name: 'Mint', isPattern: false },
    { id: 8, color: '#1A1A2E', name: 'Dark Night', isPattern: false },
    { id: 9, color: '#16213E', name: 'Deep Blue', isPattern: false },
    { id: 10, color: '#2D3436', name: 'Charcoal', isPattern: false },
    { id: 11, color: '#1B4332', name: 'Forest', isPattern: false },
    // Patterns
    { id: 100, color: '#3390EC', name: 'Telegram Blue', isPattern: true },
    { id: 101, color: '#34C759', name: 'Telegram Green', isPattern: true },
    { id: 102, color: '#FF9500', name: 'Telegram Orange', isPattern: true },
    { id: 103, color: '#AF52DE', name: 'Telegram Purple', isPattern: true }
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

          Text($r('app.string.chat_background'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })

          Blank()

          Text($r('app.string.done'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
            .onClick(() => {
              // Save wallpaper selection
              this.navPathStack.pop();
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

        Scroll() {
          Column() {
            // --- Chat preview with selected wallpaper ---
            Column() {
              Text($r('app.string.wallpaper_preview'))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 16, bottom: 8, top: 16 })
                .textTransform(TextTransform.Uppercase)

              Column() {
                // Sample messages on selected background
                Row() {
                  Blank().width(8)
                  Text($r('app.string.wallpaper_preview_incoming'))
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor($r('app.color.chat_bubble_incoming'))
                    .borderRadius(17)
                  Blank()
                }
                .width('100%').margin({ bottom: 4 })

                Row() {
                  Blank()
                  Text($r('app.string.wallpaper_preview_outgoing'))
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor($r('app.color.chat_bubble_outgoing'))
                    .borderRadius(17)
                  Blank().width(8)
                }
                .width('100%')
              }
              .width('100%')
              .height(120)
              .padding(12)
              .backgroundColor(this.getSelectedColor())
              .borderRadius(16)
              .margin({ left: 16, right: 16 })
            }

            Blank().height(24)

            // --- Solid Colors ---
            Text($r('app.string.wallpaper_colors'))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, bottom: 8 })
              .textTransform(TextTransform.Uppercase)

            Grid() {
              ForEach(this.wallpapers.filter(w => !w.isPattern), (w: WallpaperItem) => {
                GridItem() {
                  Stack({ alignContent: Alignment.BottomEnd }) {
                    Column()
                      .width('100%')
                      .height('100%')
                      .borderRadius(12)
                      .backgroundColor(w.color)

                    if (w.id === this.selectedId) {
                      Image($r('app.media.ic_check_single'))
                        .width(20).height(20)
                        .fillColor(Color.White)
                        .margin({ right: 6, bottom: 6 })
                    }
                  }
                  .width('100%')
                  .height('100%')
                  .borderWidth(w.id === this.selectedId ? 2 : 0)
                  .borderColor($r('app.color.telegram_blue'))
                  .borderRadius(12)
                }
                .onClick(() => { this.selectedId = w.id; })
              }, (w: WallpaperItem) => w.id.toString())
            }
            .columnsTemplate('1fr 1fr 1fr 1fr')
            .rowsGap(12)
            .columnsGap(12)
            .height(200)
            .padding({ left: 16, right: 16 })

            Blank().height(24)

            // --- Patterns ---
            Text($r('app.string.wallpaper_patterns'))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, bottom: 8 })
              .textTransform(TextTransform.Uppercase)

            Grid() {
              ForEach(this.wallpapers.filter(w => w.isPattern), (w: WallpaperItem) => {
                GridItem() {
                  Stack({ alignContent: Alignment.Center }) {
                    Column()
                      .width('100%')
                      .height('100%')
                      .borderRadius(12)
                      .backgroundColor(w.color)
                      .opacity(0.3)

                    // Pattern overlay simulation
                    Text('\u2726')
                      .fontSize(28)
                      .fontColor(w.color)
                      .opacity(0.8)

                    if (w.id === this.selectedId) {
                      Image($r('app.media.ic_check_single'))
                        .width(20).height(20)
                        .fillColor(Color.White)
                        .position({ right: 6, bottom: 6 })
                    }
                  }
                  .width('100%')
                  .height('100%')
                  .borderWidth(w.id === this.selectedId ? 2 : 0)
                  .borderColor($r('app.color.telegram_blue'))
                  .borderRadius(12)
                }
                .onClick(() => { this.selectedId = w.id; })
              }, (w: WallpaperItem) => w.id.toString())
            }
            .columnsTemplate('1fr 1fr 1fr 1fr')
            .rowsGap(12)
            .columnsGap(12)
            .height(80)
            .padding({ left: 16, right: 16 })

            Blank().height(24)

            // --- Reset button ---
            Column() {
              Text($r('app.string.wallpaper_reset'))
                .fontSize(16)
                .fontColor($r('app.color.telegram_blue'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(48)
                .onClick(() => { this.selectedId = 0; })
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

  private getSelectedColor(): string {
    const w = this.wallpapers.find(item => item.id === this.selectedId);
    return w ? w.color : '#DCE6F1';
  }
}
