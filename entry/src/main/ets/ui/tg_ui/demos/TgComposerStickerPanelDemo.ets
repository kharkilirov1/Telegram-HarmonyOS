import {
  StickerCellVO,
  StickerSetTabVO,
  TgComposerStickerPanel
} from '../atoms/TgComposerStickerPanel';
import { TgUiTokens } from '../tokens/TgUiTokens';

function sticker(id: string, emoji: string): StickerCellVO {
  return new StickerCellVO(id, `remote_${id}`, 0, 0, emoji, false, false, 512, 512);
}

function gif(id: string): StickerCellVO {
  const cell = new StickerCellVO(`gif_${id}`, `remote_gif_${id}`, 0, 0, 'GIF', false, true, 320, 240);
  cell.isGif = true;
  cell.duration = 3;
  return cell;
}

const DEMO_STICKERS: StickerCellVO[] = [
  sticker('1', '🐱'), sticker('2', '🐶'), sticker('3', '🐸'), sticker('4', '🦊'),
  sticker('5', '🐻'), sticker('6', '🐼'), sticker('7', '🐵'), sticker('8', '🐯')
];
const DEMO_FAVORITES: StickerCellVO[] = [sticker('9', '❤️'), sticker('10', '🔥')];
const DEMO_PREMIUM: StickerCellVO[] = [
  sticker('11', '🐙'), sticker('12', '🦎'), sticker('13', '🍑'), sticker('14', '💎'),
  sticker('15', '🐸'), sticker('16', '🦊'), sticker('17', '🐯'), sticker('18', '🐬')
];
const DEMO_GIFS: StickerCellVO[] = [gif('1'), gif('2'), gif('3'), gif('4')];
const DEMO_TABS: StickerSetTabVO[] = [
  new StickerSetTabVO('favorites', 'Favorites', 0, ''),
  new StickerSetTabVO('recent', 'Recent', 0, ''),
  new StickerSetTabVO('cats', 'Cats', 0, '🐱')
];

@Preview({ title: 'TgComposerStickerPanel' })
@ComponentV2
export struct TgComposerStickerPanelDemo {
  @Builder
  private caseBlock(label: string, items: StickerCellVO[], activeTabId: string,
    isLoading: boolean = false, tabs: StickerSetTabVO[] = DEMO_TABS,
    premiumItems: StickerCellVO[] = [], favoriteItems: StickerCellVO[] = []) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      TgComposerStickerPanel({
        items: items,
        premiumItems: premiumItems,
        favoriteItems: favoriteItems,
        tabs: tabs,
        activeTabId: activeTabId,
        isLoading: isLoading,
        onStickerSelected: (_item: StickerCellVO): void => {},
        onTabSelected: (_tabId: string): void => {},
        onSearchQueryChange: (_query: string): void => {}
      })
    }
    .width('100%')
    .padding({ left: TgUiTokens.SPACE_8, right: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_12 })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgComposerStickerPanel Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
          .padding(TgUiTokens.SPACE_16)

        this.caseBlock('01 grouped Premium + Favorites home', DEMO_STICKERS, 'recent', false,
          DEMO_TABS, DEMO_PREMIUM, DEMO_FAVORITES)
        this.caseBlock('02 favorites', DEMO_FAVORITES, 'favorites')
        this.caseBlock('03 installed pack', DEMO_STICKERS, 'cats')
        this.caseBlock('04 loading', [], 'recent', true)
        this.caseBlock('05 empty', [], 'recent')
        this.caseBlock('06 saved GIF mode', DEMO_GIFS, 'gifs', false, [])
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}
