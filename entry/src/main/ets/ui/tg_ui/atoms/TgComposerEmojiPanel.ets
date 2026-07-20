// TgComposerEmojiPanel — Telegram-style Unicode + custom-emoji entity keyboard.
//
// Telegram custom emoji come from TDLib stickerTypeCustomEmoji packs. The grid
// renders static previews only; the selected item is emitted with its int64 id
// so the outgoing formattedText can carry textEntityTypeCustomEmoji.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgIcon } from './TgIcon';
import { TgEntityKeyboardMode, TgEntityKeyboardModeBar } from './TgEntityKeyboardModeBar';
import {
  UnicodeEmojiCategory,
  UNICODE_EMOJI_CATEGORIES
} from '../data/TgUnicodeEmojiCatalog';

const DEFAULT_COMPOSER_EMOJI: string[] = [
  '😀', '😂', '😍', '👍', '🙏', '🔥',
  '❤️', '🎉', '😎', '🥲', '👏', '🤔',
  '😅', '👌', '😭', '💯', '🤝', '✨'
];

class EmojiStringDataSource implements IDataSource {
  private items: string[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): string {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  reload(items: string[]): void {
    this.items = items;
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }
}

@ObservedV2
export class CustomEmojiCellVO {
  readonly customEmojiId: string;
  readonly fallbackEmoji: string;
  readonly fileId: number;
  readonly thumbFileId: number;
  readonly isAnimated: boolean;
  readonly isVideo: boolean;
  @Trace pathUri: string = '';
  @Trace thumbPathUri: string = '';

  constructor(customEmojiId: string, fallbackEmoji: string, fileId: number, thumbFileId: number,
    isAnimated: boolean, isVideo: boolean) {
    this.customEmojiId = customEmojiId;
    this.fallbackEmoji = fallbackEmoji;
    this.fileId = fileId;
    this.thumbFileId = thumbFileId;
    this.isAnimated = isAnimated;
    this.isVideo = isVideo;
  }

  previewUri(): string {
    if (this.isAnimated || this.isVideo) {
      return this.thumbPathUri;
    }
    return this.pathUri.length > 0 ? this.pathUri : this.thumbPathUri;
  }
}

@ObservedV2
export class CustomEmojiPackTabVO {
  readonly tabId: string;
  readonly title: string;
  readonly thumbFileId: number;
  readonly fallbackEmoji: string;
  @Trace thumbUri: string = '';

  constructor(tabId: string, title: string, thumbFileId: number, fallbackEmoji: string) {
    this.tabId = tabId;
    this.title = title;
    this.thumbFileId = thumbFileId;
    this.fallbackEmoji = fallbackEmoji;
  }
}

const UNICODE_PACK_ID: string = 'unicode';
const RECENT_CATEGORY_ID: string = 'recent';
const RECENT_EMOJI_CATEGORY: UnicodeEmojiCategory =
  new UnicodeEmojiCategory(RECENT_CATEGORY_ID, '🕐', []);
const EMOJI_CATEGORIES: UnicodeEmojiCategory[] = [
  RECENT_EMOJI_CATEGORY,
  ...UNICODE_EMOJI_CATEGORIES
];

@ComponentV2
export struct TgComposerEmojiPanel {
  private static readonly SEARCH_INPUT_ID: string = 'tg_emoji_panel_search_input';

  @Param title: string = 'Recent';
  @Param searchTitle: string = 'Search';
  @Param gifTitle: string = 'GIF';
  @Param stickersTitle: string = 'Stickers';
  @Param emojiTitle: string = 'Emoji';
  @Param settingsTitle: string = 'Sticker settings';
  @Param emojis: string[] = [];
  @Param customEmojiItems: CustomEmojiCellVO[] = [];
  @Param searchUnicodeResults: string[] = [];
  @Param searchCustomEmojiItems: CustomEmojiCellVO[] = [];
  @Param customEmojiTabs: CustomEmojiPackTabVO[] = [];
  @Param activePackId: string = UNICODE_PACK_ID;
  @Param isLoading: boolean = false;
  @Param searchLoading: boolean = false;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param bottomInset: number = 0;

  @Event onEmojiSelected: (emoji: string) => void = (_: string) => {};
  @Event onCustomEmojiSelected: (item: CustomEmojiCellVO) => void = (_: CustomEmojiCellVO) => {};
  @Event onCustomEmojiTabSelected: (tabId: string) => void = (_: string) => {};
  @Event onSearchQueryChange: (query: string) => void = (_: string) => {};
  @Event onGifPress: () => void = () => {};
  @Event onStickerPress: () => void = () => {};
  @Event onSettingsPress: () => void = () => {};

  @Local private activeCategoryId: string = RECENT_CATEGORY_ID;
  @Local private searchOpen: boolean = false;
  @Local private searchQuery: string = '';
  private unicodeDataSource: EmojiStringDataSource = new EmojiStringDataSource();

  aboutToAppear(): void {
    this.syncUnicodeDataSource();
  }

  @Monitor('activeCategoryId', 'emojis')
  private onUnicodeSourceChanged(_monitor: IMonitor): void {
    this.syncUnicodeDataSource();
  }

  private syncUnicodeDataSource(): void {
    this.unicodeDataSource.reload(this.resolvedUnicodeEmojis());
  }

  private focusSearchInput(): void {
    setTimeout(() => {
      try {
        this.getUIContext().getFocusController().requestFocus(TgComposerEmojiPanel.SEARCH_INPUT_ID);
      } catch (_) {
      }
    }, 0);
  }

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private panelBg(): ResourceColor {
    return this.useBlur() ? TgUiTokens.COMPOSER_CAPSULE_BG : TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG;
  }

  private isUnicodePack(): boolean {
    return this.activePackId === UNICODE_PACK_ID;
  }

  private activeCategory(): UnicodeEmojiCategory {
    for (const category of EMOJI_CATEGORIES) {
      if (category.id === this.activeCategoryId) {
        return category;
      }
    }
    return EMOJI_CATEGORIES[0];
  }

  private categoryTitle(categoryId: string): ResourceStr {
    if (categoryId === 'smileys') {
      return $r('app.string.emoji_category_smileys');
    }
    if (categoryId === 'people') {
      return $r('app.string.emoji_category_people');
    }
    if (categoryId === 'animals') {
      return $r('app.string.emoji_category_animals');
    }
    if (categoryId === 'food') {
      return $r('app.string.emoji_category_food');
    }
    if (categoryId === 'travel') {
      return $r('app.string.emoji_category_travel');
    }
    if (categoryId === 'activity') {
      return $r('app.string.emoji_category_activity');
    }
    if (categoryId === 'objects') {
      return $r('app.string.emoji_category_objects');
    }
    if (categoryId === 'symbols') {
      return $r('app.string.emoji_category_symbols');
    }
    if (categoryId === 'flags') {
      return $r('app.string.emoji_category_flags');
    }
    return this.title;
  }

  private sectionTitle(): ResourceStr {
    if (this.searchQuery.trim().length > 0) {
      return this.searchTitle;
    }
    if (this.isUnicodePack()) {
      return this.activeCategoryId === RECENT_CATEGORY_ID
        ? this.title
        : this.categoryTitle(this.activeCategoryId);
    }
    for (const tab of this.customEmojiTabs) {
      if (tab.tabId === this.activePackId) {
        return tab.title;
      }
    }
    return this.emojiTitle;
  }

  private resolvedUnicodeEmojis(): string[] {
    if (this.searchQuery.trim().length > 0) {
      return this.searchUnicodeResults;
    }
    if (this.activeCategoryId === RECENT_CATEGORY_ID) {
      return this.emojis.length > 0 ? this.emojis : DEFAULT_COMPOSER_EMOJI;
    }
    return this.activeCategory().emojis;
  }

  private resolvedCustomEmoji(): CustomEmojiCellVO[] {
    if (this.searchQuery.trim().length > 0) {
      return this.searchCustomEmojiItems;
    }
    return this.customEmojiItems;
  }

  @Builder
  private buildPackTab(tab: CustomEmojiPackTabVO) {
    Row() {
      if (tab.tabId === UNICODE_PACK_ID) {
        TgIcon({
          src: TgUiTokens.ICON_RES_EMOJI,
          iconSize: TgUiTokens.COMPOSER_EMOJI_PACK_ICON_SIZE,
          tintColor: this.activePackId === tab.tabId
            ? TgUiTokens.COMPOSER_ACTION_ACTIVE
            : TgUiTokens.COLOR_TEXT_META
        })
      } else if (tab.thumbUri.length > 0) {
        Image(tab.thumbUri)
          .width(TgUiTokens.COMPOSER_EMOJI_PACK_ICON_SIZE)
          .height(TgUiTokens.COMPOSER_EMOJI_PACK_ICON_SIZE)
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
      } else {
        Text(tab.fallbackEmoji.length > 0 ? tab.fallbackEmoji : tab.title.substring(0, 1))
          .fontSize(TgUiTokens.COMPOSER_EMOJI_PACK_ICON_SIZE)
      }
    }
    .width(TgUiTokens.COMPOSER_EMOJI_PACK_TAB_SIZE)
    .height(TgUiTokens.COMPOSER_EMOJI_PACK_TAB_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.COMPOSER_EMOJI_PACK_TAB_RADIUS)
    .backgroundColor(this.activePackId === tab.tabId
      ? TgUiTokens.COLOR_BG_SECONDARY : Color.Transparent)
    .onClick(() => {
      this.searchOpen = false;
      this.searchQuery = '';
      this.onSearchQueryChange('');
      this.onCustomEmojiTabSelected(tab.tabId);
    })
  }

  @Builder
  private buildPackStrip() {
    Scroll() {
      Row({ space: TgUiTokens.COMPOSER_EMOJI_PACK_TAB_GAP }) {
        ForEach(this.customEmojiTabs, (tab: CustomEmojiPackTabVO) => {
          this.buildPackTab(tab)
        }, (tab: CustomEmojiPackTabVO) => `custom_emoji_pack_${tab.tabId}`)
      }
      .alignItems(VerticalAlign.Center)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
    .width('100%')
    .height(TgUiTokens.COMPOSER_EMOJI_PACK_STRIP_HEIGHT)
  }

  @Builder
  private buildCategoryRail() {
    if (this.searchOpen) {
      Row({ space: TgUiTokens.COMPOSER_EMOJI_CELL_GAP }) {
        TgIcon({
          src: TgUiTokens.ICON_RES_SEARCH,
          iconSize: TgUiTokens.COMPOSER_EMOJI_NAV_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_TEXT_META
        })
        TextInput({ text: this.searchQuery, placeholder: this.searchTitle })
          .id(TgComposerEmojiPanel.SEARCH_INPUT_ID)
          .onAppear(() => {
            this.focusSearchInput();
          })
          .fontSize(TgUiTokens.COMPOSER_EMOJI_HEADER_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .placeholderColor(TgUiTokens.COLOR_TEXT_META)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .height(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
          .onChange((value: string) => {
            this.searchQuery = value;
            this.onSearchQueryChange(value);
          })
        Row() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(TgUiTokens.COMPOSER_EMOJI_NAV_ICON_SIZE)
            .fontColor([TgUiTokens.COLOR_TEXT_META])
        }
        .width(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
        .height(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.searchOpen = false;
          this.searchQuery = '';
          this.onSearchQueryChange('');
        })
      }
      .width('100%')
      .height(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
      .padding({ left: TgUiTokens.COMPOSER_EMOJI_PILL_PADDING_H })
      .borderRadius(TgUiTokens.COMPOSER_EMOJI_PILL_RADIUS)
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    } else {
      Row() {
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_SEARCH,
            iconSize: TgUiTokens.COMPOSER_EMOJI_NAV_ICON_SIZE,
            tintColor: TgUiTokens.COLOR_TEXT_META
          })
        }
        .height(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.searchOpen = true;
          this.focusSearchInput();
        })

        if (this.isUnicodePack()) {
          ForEach(EMOJI_CATEGORIES, (category: UnicodeEmojiCategory) => {
            Row() {
              Text(category.icon)
                .fontSize(TgUiTokens.COMPOSER_EMOJI_HEADER_SIZE + 4)
                .opacity(this.activeCategoryId === category.id ? 1 : 0.5)
            }
            .height(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .borderRadius(TgUiTokens.COMPOSER_EMOJI_PILL_RADIUS)
            .backgroundColor(this.activeCategoryId === category.id
              ? TgUiTokens.COMPOSER_CAPSULE_BG : Color.Transparent)
            .onClick(() => {
              this.activeCategoryId = category.id;
            })
          }, (category: UnicodeEmojiCategory) => `composer_emoji_cat_${category.id}`)
        }
      }
      .width('100%')
      .height(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
      .borderRadius(TgUiTokens.COMPOSER_EMOJI_PILL_RADIUS)
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    }
  }

  @Builder
  private buildUnicodeCell(emoji: string) {
    Row() {
      Text(emoji)
        .fontSize(TgUiTokens.COMPOSER_EMOJI_TEXT_SIZE)
        .textAlign(TextAlign.Center)
    }
    .width(TgUiTokens.COMPOSER_EMOJI_CELL_SIZE)
    .height(TgUiTokens.COMPOSER_EMOJI_CELL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.COMPOSER_EMOJI_CELL_RADIUS)
    .onClick(() => {
      this.onEmojiSelected(emoji);
    })
  }

  @Builder
  private buildCustomEmojiCell(item: CustomEmojiCellVO) {
    Row() {
      if (item.previewUri().length > 0) {
        Image(item.previewUri())
          .width(TgUiTokens.COMPOSER_CUSTOM_EMOJI_IMAGE_SIZE)
          .height(TgUiTokens.COMPOSER_CUSTOM_EMOJI_IMAGE_SIZE)
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
      } else {
        Text(item.fallbackEmoji)
          .fontSize(TgUiTokens.COMPOSER_EMOJI_TEXT_SIZE)
      }
    }
    .width(TgUiTokens.COMPOSER_EMOJI_CELL_SIZE)
    .height(TgUiTokens.COMPOSER_EMOJI_CELL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.COMPOSER_EMOJI_CELL_RADIUS)
    .onClick(() => {
      this.onCustomEmojiSelected(item);
    })
  }

  @Builder
  private buildEmojiGrid() {
    if (this.searchQuery.trim().length > 0) {
      if (this.searchUnicodeResults.length === 0 && this.searchCustomEmojiItems.length === 0) {
        Row() {
          Text(this.searchLoading ? '…' : '—')
            .fontSize(TgUiTokens.COMPOSER_STICKER_EMOJI_FALLBACK_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_META)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      } else {
        Grid() {
          ForEach(this.searchUnicodeResults, (emoji: string, index: number) => {
            GridItem() {
              this.buildUnicodeCell(emoji)
            }
          }, (emoji: string, index: number) => `search_unicode_${index}_${emoji}`)
          ForEach(this.searchCustomEmojiItems, (item: CustomEmojiCellVO) => {
            GridItem() {
              this.buildCustomEmojiCell(item)
            }
          }, (item: CustomEmojiCellVO) => `search_custom_${item.customEmojiId}`)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
        .columnsGap(TgUiTokens.COMPOSER_EMOJI_CELL_GAP)
        .rowsGap(TgUiTokens.COMPOSER_EMOJI_CELL_GAP)
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    } else if (this.isUnicodePack()) {
      Grid() {
        LazyForEach(this.unicodeDataSource, (emoji: string, index: number) => {
          GridItem() {
            this.buildUnicodeCell(emoji)
          }
        }, (emoji: string, index: number) => `unicode_emoji_${index}_${emoji}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .columnsGap(TgUiTokens.COMPOSER_EMOJI_CELL_GAP)
      .rowsGap(TgUiTokens.COMPOSER_EMOJI_CELL_GAP)
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    } else if (this.customEmojiItems.length === 0) {
      Row() {
        Text(this.isLoading ? '…' : '—')
          .fontSize(TgUiTokens.COMPOSER_STICKER_EMOJI_FALLBACK_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    } else {
      Grid() {
        ForEach(this.resolvedCustomEmoji(), (item: CustomEmojiCellVO) => {
          GridItem() {
            this.buildCustomEmojiCell(item)
          }
        }, (item: CustomEmojiCellVO) => `custom_emoji_${item.customEmojiId}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .columnsGap(TgUiTokens.COMPOSER_EMOJI_CELL_GAP)
      .rowsGap(TgUiTokens.COMPOSER_EMOJI_CELL_GAP)
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
  }

  private handleModePress(mode: TgEntityKeyboardMode): void {
    if (mode === 'gifs') {
      this.onGifPress();
    } else if (mode === 'stickers') {
      this.onStickerPress();
    }
  }

  build() {
    Column() {
      Column() {
        Column({ space: TgUiTokens.COMPOSER_EMOJI_PANEL_ROW_GAP }) {
          if (this.customEmojiTabs.length > 1) {
            this.buildPackStrip()
          }

          this.buildCategoryRail()

          Row() {
            Text(this.sectionTitle())
              .fontSize(TgUiTokens.COMPOSER_EMOJI_HEADER_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(TgUiTokens.COLOR_TEXT_META)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(TgUiTokens.COMPOSER_EMOJI_PANEL_HEADER_HEIGHT)
          .alignItems(VerticalAlign.Center)

          this.buildEmojiGrid()
        }
        .width('100%')
        .layoutWeight(1)
        .padding({
          left: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING,
          right: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING,
          top: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING,
          bottom: 0
        })

        TgEntityKeyboardModeBar({
          activeMode: 'emoji',
          gifTitle: this.gifTitle,
          stickersTitle: this.stickersTitle,
          emojiTitle: this.emojiTitle,
          settingsAccessibilityText: this.settingsTitle,
          onModePress: (mode: TgEntityKeyboardMode): void => {
            this.handleModePress(mode);
          },
          onSettingsPress: (): void => {
            this.onSettingsPress();
          }
        })
      }
      .width('100%')
      .height(TgUiTokens.COMPOSER_KEYBOARD_PANEL_HEIGHT)
      .backgroundColor(this.panelBg())
      .backgroundBlurStyle(TgGlassPolicy.composerBlurStyle(), TgGlassPolicy.glassOptions())
      .borderRadius(TgUiTokens.COMPOSER_KEYBOARD_PANEL_RADIUS)
      .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
      .clip(true)
    }
    .width('100%')
    .padding({
      top: TgUiTokens.COMPOSER_EMOJI_PANEL_TOP_GAP,
      bottom: this.bottomInset
    })
  }
}
