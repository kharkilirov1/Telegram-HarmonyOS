// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { composerPopupTransition } from '../../tg_ui/utils/TgComposerMotionPolicy';
import { TgComposerEmojiPanel, CustomEmojiCellVO } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { TgComposerStickerPanel, StickerCellVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { localized } from '../../../core/utils/AppResource';
import { ChatChromeState } from './ChatChromeState';
import { ChatPanelsState } from './ChatPanelsState';
import { ChatKeyboardPanelsPort } from './ChatScreenViewPorts';

@ComponentV2
export struct TgChatKeyboardPanels {
  @Require @Param chrome: ChatChromeState;
  @Require @Param panels: ChatPanelsState;
  @Require @Param bindings: ChatKeyboardPanelsPort;

  build() {
    if (this.panels.showComposerEmojiPanel) {
      TgComposerEmojiPanel({
        title: localized($r('app.string.sticker_packs_recent').id, 'Recent'),
        searchTitle: localized($r('app.string.accessibility_search').id, 'Search'),
        gifTitle: localized($r('app.string.gifs_tab').id, 'GIF'),
        stickersTitle: localized($r('app.string.stickers_tab').id, 'Stickers'),
        emojiTitle: localized($r('app.string.emoji_tab').id, 'Emoji'),
        settingsTitle: localized($r('app.string.settings_stickers').id, 'Stickers and Emoji'),
        customEmojiItems: this.panels.customEmojiPanelItems,
        searchUnicodeResults: this.panels.emojiSearchUnicodeResults,
        searchCustomEmojiItems: this.panels.emojiSearchCustomItems,
        customEmojiTabs: this.panels.customEmojiPackTabs,
        activePackId: this.panels.activeCustomEmojiPackId,
        isLoading: this.panels.customEmojiPanelLoading,
        searchLoading: this.panels.emojiSearchLoading,
        bottomInset: this.chrome.bottomOverlayInset,
        onEmojiSelected: (emoji: string): void => {
          this.bindings.handleComposerEmojiSelected(emoji);
        },
        onCustomEmojiSelected: (item: CustomEmojiCellVO): void => {
          this.bindings.handleCustomEmojiSelected(item);
        },
        onCustomEmojiTabSelected: (tabId: string): void => {
          this.bindings.handleCustomEmojiTabSelected(tabId);
        },
        onSearchQueryChange: (query: string): void => {
          this.bindings.handleEmojiSearchQueryChange(query);
        },
        onStickerPress: (): void => {
          this.bindings.handleComposerStickerPress();
        },
        onGifPress: (): void => {
          this.bindings.handleComposerGifPress();
        },
        onSettingsPress: (): void => {
          this.bindings.openStickerSettings();
        }
      })
      .transition(composerPopupTransition())
    } else if (this.panels.showComposerStickerPanel) {
      TgComposerStickerPanel({
        title: localized($r('app.string.stickers_tab').id, 'Stickers'),
        recentTitle: localized($r('app.string.sticker_packs_recent').id, 'Recent'),
        favoritesTitle: localized($r('app.string.sticker_packs_favorites').id, 'Favorites'),
        premiumTitle: localized($r('app.string.sticker_packs_popular_premium').id,
          'Popular Premium Stickers'),
        searchTitle: localized($r('app.string.accessibility_search').id, 'Search'),
        gifTitle: localized($r('app.string.gifs_tab').id, 'GIF'),
        emojiTitle: localized($r('app.string.emoji_tab').id, 'Emoji'),
        settingsTitle: localized($r('app.string.settings_stickers').id, 'Stickers and Emoji'),
        items: this.panels.stickerPanelItems,
        premiumItems: this.panels.premiumStickerItems,
        favoriteItems: this.panels.favoriteStickerItems,
        searchItems: this.panels.activeStickerTabId === 'gifs'
          ? this.panels.gifSearchItems : this.panels.stickerSearchItems,
        tabs: this.panels.stickerSetTabs,
        activeTabId: this.panels.activeStickerTabId,
        isLoading: this.panels.stickerPanelLoading,
        searchLoading: this.panels.activeStickerTabId === 'gifs'
          ? this.panels.gifSearchLoading || this.panels.gifSearchPageLoading : this.panels.stickerSearchLoading,
        searchHasMore: this.panels.activeStickerTabId === 'gifs' ? this.panels.gifSearchHasMore : false,
        bottomInset: this.chrome.bottomOverlayInset,
        onStickerSelected: (item: StickerCellVO): void => {
          this.bindings.handleStickerSelected(item);
        },
        onTabSelected: (tabId: string): void => {
          this.bindings.handleStickerTabSelected(tabId);
        },
        onSearchQueryChange: (query: string): void => {
          this.bindings.handleStickerSearchQueryChange(query);
        },
        onGifSearchQueryChange: (query: string): void => {
          this.bindings.handleGifSearchQueryChange(query);
        },
        onSearchLoadMore: (): void => {
          this.bindings.loadMoreGifSearch();
        },
        onGifPress: (): void => {
          this.bindings.handleComposerGifPress();
        },
        onStickerPress: (): void => {
          this.bindings.handleComposerStickerModePress();
        },
        onEmojiPress: (): void => {
          this.bindings.setEmojiPanelVisible(true);
        },
        onSettingsPress: (): void => {
          this.bindings.openStickerSettings();
        }
      })
      .transition(composerPopupTransition())
    }
  }
}
