// Sticker picker panel — displays sticker packs with search
// Reference: Telegram iOS StickerPanelController, Android StickersAlert

interface StickerPack {
  id: number;
  name: string;
  emoji: string;
  stickers: StickerItem[];
}

interface StickerItem {
  id: number;
  emoji: string;
  isAnimated: boolean;
}

@ComponentV2
export struct StickerPicker {
  @Event onStickerSelected: (emoji: string) => void = () => {};
  @Local activePack: number = 0;
  @Local searchText: string = '';

  // Stub sticker packs
  private readonly stickerPacks: StickerPack[] = [
    {
      id: 0, name: 'Recent', emoji: '\u{1F551}',
      stickers: [
        { id: 1, emoji: '\u{1F44D}', isAnimated: false },
        { id: 2, emoji: '\u{2764}\u{FE0F}', isAnimated: false },
        { id: 3, emoji: '\u{1F602}', isAnimated: false },
        { id: 4, emoji: '\u{1F525}', isAnimated: false },
        { id: 5, emoji: '\u{1F60D}', isAnimated: false },
        { id: 6, emoji: '\u{1F44F}', isAnimated: false },
        { id: 7, emoji: '\u{1F62D}', isAnimated: false },
        { id: 8, emoji: '\u{1F914}', isAnimated: false },
      ]
    },
    {
      id: 1, name: 'Classic Telegram', emoji: '\u{2708}\u{FE0F}',
      stickers: [
        { id: 10, emoji: '\u{1F4AC}', isAnimated: true },
        { id: 11, emoji: '\u{1F4E8}', isAnimated: true },
        { id: 12, emoji: '\u{2708}\u{FE0F}', isAnimated: true },
        { id: 13, emoji: '\u{1F31F}', isAnimated: true },
        { id: 14, emoji: '\u{1F389}', isAnimated: true },
        { id: 15, emoji: '\u{1F380}', isAnimated: true },
        { id: 16, emoji: '\u{1F48E}', isAnimated: true },
        { id: 17, emoji: '\u{26A1}', isAnimated: true },
        { id: 18, emoji: '\u{1F308}', isAnimated: true },
        { id: 19, emoji: '\u{1F680}', isAnimated: true },
        { id: 20, emoji: '\u{1F3AF}', isAnimated: true },
        { id: 21, emoji: '\u{1F4AB}', isAnimated: true },
      ]
    },
    {
      id: 2, name: 'Animals', emoji: '\u{1F43B}',
      stickers: [
        { id: 30, emoji: '\u{1F436}', isAnimated: false },
        { id: 31, emoji: '\u{1F431}', isAnimated: false },
        { id: 32, emoji: '\u{1F43B}', isAnimated: false },
        { id: 33, emoji: '\u{1F430}', isAnimated: false },
        { id: 34, emoji: '\u{1F981}', isAnimated: false },
        { id: 35, emoji: '\u{1F427}', isAnimated: false },
        { id: 36, emoji: '\u{1F422}', isAnimated: false },
        { id: 37, emoji: '\u{1F98A}', isAnimated: false },
        { id: 38, emoji: '\u{1F984}', isAnimated: false },
        { id: 39, emoji: '\u{1F43C}', isAnimated: false },
      ]
    },
    {
      id: 3, name: 'Food', emoji: '\u{1F354}',
      stickers: [
        { id: 40, emoji: '\u{1F355}', isAnimated: false },
        { id: 41, emoji: '\u{1F354}', isAnimated: false },
        { id: 42, emoji: '\u{1F370}', isAnimated: false },
        { id: 43, emoji: '\u{1F36A}', isAnimated: false },
        { id: 44, emoji: '\u{2615}', isAnimated: false },
        { id: 45, emoji: '\u{1F37A}', isAnimated: false },
        { id: 46, emoji: '\u{1F363}', isAnimated: false },
        { id: 47, emoji: '\u{1F96A}', isAnimated: false },
      ]
    }
  ];

  build() {
    Column() {
      // Pack tabs
      Scroll() {
        Row({ space: 0 }) {
          ForEach(this.stickerPacks, (pack: StickerPack, index: number) => {
            Column() {
              Text(pack.emoji)
                .fontSize(24)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })

              Divider()
                .strokeWidth(2)
                .color(this.activePack === index
                  ? $r('app.color.telegram_blue')
                  : Color.Transparent)
                .width('80%')
            }
            .onClick(() => { this.activePack = index; })
          }, (pack: StickerPack) => pack.id.toString())
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(48)
      .backgroundColor($r('app.color.background_primary'))

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Sticker grid
      Grid() {
        ForEach(this.getCurrentStickers(), (sticker: StickerItem) => {
          GridItem() {
            Column() {
              Text(sticker.emoji)
                .fontSize(36)

              if (sticker.isAnimated) {
                Text('\u{2728}')
                  .fontSize(10)
                  .position({ right: 2, bottom: 2 })
              }
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.onStickerSelected(sticker.emoji);
            })
          }
        }, (sticker: StickerItem) => sticker.id.toString())
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
      .rowsGap(4)
      .columnsGap(4)
      .width('100%')
      .height(200)
      .padding(8)
      .backgroundColor($r('app.color.background_primary'))
    }
    .width('100%')
  }

  private getCurrentStickers(): StickerItem[] {
    if (this.activePack >= 0 && this.activePack < this.stickerPacks.length) {
      return this.stickerPacks[this.activePack].stickers;
    }
    return [];
  }
}
