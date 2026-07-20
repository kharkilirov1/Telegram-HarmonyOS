// TgComposerStickerPanel — recent-stickers grid for the composer input mode.
//
// Cells render static previews only (webp file, else thumbnail, else emoji):
// animating a whole grid of tgs/webm players would burn the main thread.
// Paths land asynchronously as downloads finish, hence the @Trace VO fields.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgIcon } from './TgIcon';
import { TgEntityKeyboardMode, TgEntityKeyboardModeBar } from './TgEntityKeyboardModeBar';

@ObservedV2
export class StickerCellVO {
  readonly stickerId: string;
  readonly remoteFileId: string;
  readonly fileId: number;
  readonly thumbFileId: number;
  readonly emoji: string;
  readonly isAnimated: boolean;
  readonly isVideo: boolean;
  readonly width: number;
  readonly height: number;
  @Trace pathUri: string = '';      // file:// URI of the sticker file (webp usable directly)
  @Trace thumbPathUri: string = ''; // file:// URI of the thumbnail
  isGif: boolean = false;           // GIF tab cell — tap sends inputMessageAnimation
  duration: number = 0;             // animation duration (GIF cells)
  inlineQueryId: string = '0';      // exact TDLib int64 string for inline GIF send
  inlineResultId: string = '';      // inline bot result id
  minithumbnailUri: string = '';    // immediate TDLib blur preview for GIF results

  constructor(stickerId: string, remoteFileId: string, fileId: number, thumbFileId: number,
    emoji: string, isAnimated: boolean, isVideo: boolean, width: number, height: number) {
    this.stickerId = stickerId;
    this.remoteFileId = remoteFileId;
    this.fileId = fileId;
    this.thumbFileId = thumbFileId;
    this.emoji = emoji;
    this.isAnimated = isAnimated;
    this.isVideo = isVideo;
    this.width = width;
    this.height = height;
  }

  previewUri(): string {
    // tgs/webm files are not renderable by Image — always prefer the thumbnail
    if (this.isAnimated || this.isVideo) {
      return this.thumbPathUri.length > 0 ? this.thumbPathUri : this.minithumbnailUri;
    }
    return this.pathUri.length > 0 ? this.pathUri : this.thumbPathUri;
  }

}

// One pack tab in the strip; 'recent' is a synthetic tab, real packs carry a set id.
@ObservedV2
export class StickerSetTabVO {
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

@ComponentV2
export struct TgComposerStickerPanel {
  private static readonly SEARCH_INPUT_ID: string = 'tg_sticker_panel_search_input';

  @Param title: string = 'Stickers';
  @Param recentTitle: string = 'Recent';
  @Param favoritesTitle: string = 'Favorites';
  @Param premiumTitle: string = 'Popular Premium Stickers';
  @Param searchTitle: string = 'Search';
  @Param gifTitle: string = 'GIF';
  @Param emojiTitle: string = 'Emoji';
  @Param settingsTitle: string = 'Sticker settings';
  @Param items: StickerCellVO[] = [];
  @Param premiumItems: StickerCellVO[] = [];
  @Param favoriteItems: StickerCellVO[] = [];
  @Param searchItems: StickerCellVO[] = [];
  @Param tabs: StickerSetTabVO[] = [];
  @Param activeTabId: string = 'recent';
  @Param isLoading: boolean = false;
  @Param searchLoading: boolean = false;
  @Param searchHasMore: boolean = false;
  @Param bottomInset: number = 0;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;

  @Local private searchOpen: boolean = false;
  @Local private searchQuery: string = '';

  @Event onStickerSelected: (item: StickerCellVO) => void = (_: StickerCellVO) => {};
  @Event onTabSelected: (tabId: string) => void = (_: string) => {};
  @Event onGifPress: () => void = () => {};
  @Event onStickerPress: () => void = () => {};
  @Event onEmojiPress: () => void = () => {};
  @Event onSearchQueryChange: (query: string) => void = (_: string) => {};
  @Event onGifSearchQueryChange: (query: string) => void = (_: string) => {};
  @Event onSearchLoadMore: () => void = () => {};
  @Event onSettingsPress: () => void = () => {};

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private panelBg(): ResourceColor {
    return this.useBlur() ? TgUiTokens.COMPOSER_CAPSULE_BG : TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG;
  }

  private activeMode(): TgEntityKeyboardMode {
    return this.activeTabId === 'gifs' ? 'gifs' : 'stickers';
  }

  private panelTitle(): string {
    if (this.searchQuery.trim().length > 0) {
      return this.searchTitle;
    }
    if (this.activeTabId === 'gifs') {
      return this.gifTitle;
    }
    if (this.activeTabId === 'recent') {
      return this.recentTitle;
    }
    if (this.activeTabId === 'favorites') {
      return this.favoritesTitle;
    }
    for (const tab of this.tabs) {
      if (tab.tabId === this.activeTabId && tab.title.length > 0) {
        return tab.title;
      }
    }
    return this.title;
  }

  private handleModePress(mode: TgEntityKeyboardMode): void {
    if (mode !== this.activeMode()) {
      this.resetSearch();
    }
    if (mode === 'gifs') {
      this.onGifPress();
    } else if (mode === 'stickers') {
      this.onStickerPress();
    } else {
      this.onEmojiPress();
    }
  }

  private visibleItems(): StickerCellVO[] {
    return this.searchQuery.trim().length > 0 ? this.searchItems : this.items;
  }

  private visibleLoading(): boolean {
    return this.searchQuery.trim().length > 0 ? this.searchLoading : this.isLoading;
  }

  private shouldShowGroupedHome(): boolean {
    return this.activeMode() === 'stickers' && this.activeTabId === 'recent' &&
      this.searchQuery.trim().length === 0 &&
      (this.premiumItems.length > 0 || this.favoriteItems.length > 0);
  }

  private resetSearch(): void {
    if (!this.searchOpen && this.searchQuery.length === 0) {
      return;
    }
    this.searchOpen = false;
    this.searchQuery = '';
    this.emitSearchQuery('');
  }

  private emitSearchQuery(query: string): void {
    if (this.activeMode() === 'gifs') {
      this.onGifSearchQueryChange(query);
      return;
    }
    this.onSearchQueryChange(query);
  }

  private focusSearchInput(): void {
    setTimeout(() => {
      try {
        this.getUIContext().getFocusController().requestFocus(TgComposerStickerPanel.SEARCH_INPUT_ID);
      } catch (_) {
      }
    }, 0);
  }

  @Builder
  private buildCell(item: StickerCellVO) {
    Row() {
      if (item.previewUri().length > 0) {
        Image(item.previewUri())
          .width(item.isGif ? '100%' : TgUiTokens.COMPOSER_STICKER_CELL_SIZE)
          .height(item.isGif ? TgUiTokens.COMPOSER_GIF_CELL_HEIGHT : TgUiTokens.COMPOSER_STICKER_CELL_SIZE)
          .objectFit(item.isGif ? ImageFit.Cover : ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
      } else {
        Text(item.emoji.length > 0 ? item.emoji : '❔')
          .fontSize(TgUiTokens.COMPOSER_STICKER_EMOJI_FALLBACK_SIZE)
          .textAlign(TextAlign.Center)
      }
    }
    .width(item.isGif ? '100%' : TgUiTokens.COMPOSER_STICKER_CELL_SIZE)
    .height(item.isGif ? TgUiTokens.COMPOSER_GIF_CELL_HEIGHT : TgUiTokens.COMPOSER_STICKER_CELL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(item.isGif ? TgUiTokens.COMPOSER_GIF_CELL_RADIUS : TgUiTokens.COMPOSER_EMOJI_CELL_RADIUS)
    .clip(item.isGif)
    .onClick(() => {
      this.onStickerSelected(item);
    })
  }

  @Builder
  private buildCompactCell(item: StickerCellVO, cellSize: number) {
    Row() {
      if (item.previewUri().length > 0) {
        Image(item.previewUri())
          .width(cellSize)
          .height(cellSize)
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
      } else {
        Text(item.emoji.length > 0 ? item.emoji : '❔')
          .fontSize(cellSize * 0.58)
          .textAlign(TextAlign.Center)
      }
    }
    .width(cellSize)
    .height(cellSize)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.COMPOSER_EMOJI_CELL_RADIUS)
    .onClick(() => {
      this.onStickerSelected(item);
    })
  }

  @Builder
  private buildStickerGroup(title: string, items: StickerCellVO[], cellSize: number,
    rowHeight: number, limit: number, keyPrefix: string) {
    Column() {
      Row() {
        Text(title.toUpperCase())
          .fontSize(TgUiTokens.COMPOSER_STICKER_GROUP_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(TgUiTokens.COMPOSER_STICKER_GROUP_TITLE_HEIGHT)
      .alignItems(VerticalAlign.Center)

      Row({ space: TgUiTokens.COMPOSER_STICKER_GROUP_CELL_GAP }) {
        ForEach(items.slice(0, limit), (item: StickerCellVO) => {
          this.buildCompactCell(item, cellSize)
        }, (item: StickerCellVO) => `${keyPrefix}_${item.stickerId}`)
      }
      .width('100%')
      .height(rowHeight)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildGroupedStickerHome() {
    Column({ space: TgUiTokens.COMPOSER_STICKER_GROUP_GAP }) {
      if (this.premiumItems.length > 0) {
        this.buildStickerGroup(this.premiumTitle, this.premiumItems,
          TgUiTokens.COMPOSER_STICKER_PREMIUM_CELL_SIZE,
          TgUiTokens.COMPOSER_STICKER_PREMIUM_ROW_HEIGHT, 8, 'premium')
      }
      if (this.favoriteItems.length > 0) {
        this.buildStickerGroup(this.favoritesTitle, this.favoriteItems,
          TgUiTokens.COMPOSER_STICKER_FAVORITE_CELL_SIZE,
          TgUiTokens.COMPOSER_STICKER_FAVORITE_ROW_HEIGHT, 4, 'favorite')
      }
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildTab(tab: StickerSetTabVO) {
    Row() {
      if (tab.tabId === 'recent') {
        TgIcon({
          src: TgUiTokens.ICON_RES_CLOCK,
          iconSize: TgUiTokens.COMPOSER_STICKER_TAB_EMOJI_SIZE,
          tintColor: this.activeTabId === 'recent'
            ? TgUiTokens.COMPOSER_ACTION_ACTIVE
            : TgUiTokens.COLOR_TEXT_META
        })
      } else if (tab.tabId === 'favorites') {
        SymbolGlyph($r('sys.symbol.bookmark_fill'))
          .fontSize(TgUiTokens.COMPOSER_STICKER_TAB_EMOJI_SIZE)
          .fontColor([this.activeTabId === 'favorites'
            ? TgUiTokens.COMPOSER_ACTION_ACTIVE
            : TgUiTokens.COLOR_TEXT_META])
      } else if (tab.thumbUri.length > 0) {
        Image(tab.thumbUri)
          .width(TgUiTokens.COMPOSER_STICKER_TAB_SIZE - 8)
          .height(TgUiTokens.COMPOSER_STICKER_TAB_SIZE - 8)
          .objectFit(ImageFit.Contain)
      } else if (tab.fallbackEmoji.length > 0) {
        Text(tab.fallbackEmoji)
          .fontSize(TgUiTokens.COMPOSER_STICKER_TAB_EMOJI_SIZE)
      } else {
        Text(tab.title.length > 0 ? tab.title.substring(0, 1) : '?')
          .fontSize(TgUiTokens.COMPOSER_EMOJI_HEADER_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
      }
    }
    .width(TgUiTokens.COMPOSER_STICKER_TAB_SIZE)
    .height(TgUiTokens.COMPOSER_STICKER_TAB_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.COMPOSER_STICKER_TAB_RADIUS)
    .backgroundColor(this.activeTabId === tab.tabId
      ? TgUiTokens.COLOR_BG_SECONDARY
      : Color.Transparent)
    .onClick(() => {
      this.resetSearch();
      this.onTabSelected(tab.tabId);
    })
  }

  @Builder
  private buildTabStrip() {
    Scroll() {
      Row({ space: TgUiTokens.COMPOSER_STICKER_TAB_GAP }) {
        ForEach(this.tabs, (tab: StickerSetTabVO) => {
          this.buildTab(tab)
        }, (tab: StickerSetTabVO) => `sticker_tab_${tab.tabId}`)
      }
      .alignItems(VerticalAlign.Center)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
    .width('100%')
    .height(TgUiTokens.COMPOSER_STICKER_TAB_STRIP_HEIGHT)
  }

  @Builder
  private buildSearchRail() {
    if (this.searchOpen) {
      Row({ space: TgUiTokens.COMPOSER_EMOJI_CELL_GAP }) {
        TgIcon({
          src: TgUiTokens.ICON_RES_SEARCH,
          iconSize: TgUiTokens.COMPOSER_EMOJI_NAV_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_TEXT_META
        })
        TextInput({ text: this.searchQuery, placeholder: this.searchTitle })
          .id(TgComposerStickerPanel.SEARCH_INPUT_ID)
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
            this.emitSearchQuery(value);
          })
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_CLOSE,
            iconSize: TgUiTokens.COMPOSER_EMOJI_NAV_ICON_SIZE,
            tintColor: TgUiTokens.COLOR_TEXT_META
          })
        }
        .width(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
        .height(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.resetSearch();
        })
      }
      .width('100%')
      .height(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
      .padding({ left: TgUiTokens.COMPOSER_EMOJI_PILL_PADDING_H })
      .borderRadius(TgUiTokens.COMPOSER_EMOJI_PILL_RADIUS)
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    } else {
      Row({ space: TgUiTokens.COMPOSER_EMOJI_CELL_GAP }) {
        TgIcon({
          src: TgUiTokens.ICON_RES_SEARCH,
          iconSize: TgUiTokens.COMPOSER_EMOJI_NAV_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_TEXT_META
        })
        Text(this.searchTitle)
          .fontSize(TgUiTokens.COMPOSER_EMOJI_HEADER_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
      }
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.searchOpen = true;
        this.focusSearchInput();
      })
      .width('100%')
      .height(TgUiTokens.COMPOSER_EMOJI_NAV_HEIGHT)
      .padding({ left: TgUiTokens.COMPOSER_EMOJI_PILL_PADDING_H })
      .borderRadius(TgUiTokens.COMPOSER_EMOJI_PILL_RADIUS)
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    }
  }

  build() {
    Column() {
      Column() {
        Column({ space: TgUiTokens.COMPOSER_EMOJI_PANEL_ROW_GAP }) {
        if (this.activeMode() === 'stickers' && this.tabs.length > 0) {
          this.buildTabStrip()
        }

        this.buildSearchRail()

        if (this.shouldShowGroupedHome()) {
          this.buildGroupedStickerHome()
        } else {
          Row() {
            Text(this.panelTitle())
              .fontSize(TgUiTokens.COMPOSER_EMOJI_HEADER_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(TgUiTokens.COLOR_TEXT_META)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(TgUiTokens.COMPOSER_EMOJI_PANEL_HEADER_HEIGHT)
          .alignItems(VerticalAlign.Center)

          if (this.visibleItems().length === 0) {
            Row() {
              Text(this.visibleLoading() ? '…' : '—')
                .fontSize(TgUiTokens.COMPOSER_STICKER_EMOJI_FALLBACK_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
          } else {
            Grid() {
              ForEach(this.visibleItems(), (item: StickerCellVO) => {
                GridItem() {
                  this.buildCell(item)
                }
              }, (item: StickerCellVO) => `sticker_cell_${item.stickerId}`)
            }
            .columnsTemplate(this.activeMode() === 'gifs' ? '1fr 1fr' : '1fr 1fr 1fr 1fr')
            .columnsGap(TgUiTokens.COMPOSER_STICKER_CELL_GAP)
            .rowsGap(TgUiTokens.COMPOSER_STICKER_CELL_GAP)
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .onReachEnd(() => {
              if (this.activeMode() === 'gifs' && this.searchQuery.trim().length > 0 &&
                this.searchHasMore && !this.searchLoading) {
                this.onSearchLoadMore();
              }
            })
          }
        }
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
          activeMode: this.activeMode(),
          gifTitle: this.gifTitle,
          stickersTitle: this.title,
          emojiTitle: this.emojiTitle,
          settingsAccessibilityText: this.settingsTitle,
          showSettings: this.activeMode() !== 'gifs',
          onModePress: (mode: TgEntityKeyboardMode): void => {
            this.handleModePress(mode);
          },
          onSettingsPress: (): void => {
            this.onSettingsPress();
          }
        })
      }
      .width('100%')
      .height(TgUiTokens.COMPOSER_STICKER_PANEL_HEIGHT)
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
