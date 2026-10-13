// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgGlassPolicy } from '../../tg_ui/tokens/TgGlassPolicy';
import { TgStickerSettingsSheet } from '../../tg_ui/atoms/TgStickerSettingsSheet';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgChatBackground } from '../../tg_ui/atoms/TgChatBackground';
import { TgPinnedMessagePanel } from '../../tg_ui/atoms/TgPinnedMessagePanel';
import { localized } from '../../../core/utils/AppResource';
import { ChatScreenViewState } from './ChatScreenViewState';
import { ChatScreenSession } from './ChatScreenSession';
import { ChatScreenViewBindings } from './ChatScreenViewBindings';
import { TgChatTimelineViewport } from './TgChatTimelineViewport';
import { TgChatComposerDock } from './TgChatComposerDock';
import { TgChatPinnedOverlay } from './TgChatPinnedOverlay';
import { TgChatMediaOverlay } from './TgChatMediaOverlay';
import { NavigationUIState, navigationUIState } from '../../../core/model/UIStateModels';

@ComponentV2
export struct TgChatScreenPage {
  @Local private view: ChatScreenViewState = new ChatScreenViewState();
  @Local private appLifecycle: NavigationUIState = navigationUIState;
  private session: ChatScreenSession = new ChatScreenSession(
    this.view, () => this.getUIContext(), () => this.queryNavigationInfo());
  private bindings: ChatScreenViewBindings = new ChatScreenViewBindings(this.session);

  aboutToAppear(): void {
    this.session.aboutToAppear();
  }

  aboutToDisappear(): void {
    this.session.aboutToDisappear();
  }

  @Monitor('appLifecycle.applicationForeground')
  private onApplicationForegroundChanged(): void {
    if (!this.appLifecycle.applicationForeground) {
      this.session.slowmodeController.pause();
    } else if (this.session.routeContext !== undefined &&
      this.session.isRouteContextCurrent(this.session.routeContext)) {
      this.session.refreshChatInputPanel();
    }
  }

  @Builder
  private buildStickerSettingsSheet() {
    TgStickerSettingsSheet({
      packs: this.view.panels.stickerSetTabs,
      installedTitle: localized($r('app.string.sticker_packs_installed').id, 'Installed Sticker Packs'),
      emptyTitle: localized($r('app.string.sticker_packs_empty').id, 'No installed sticker packs')
    })
  }


  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        TgChatBackground()

        TgChatTimelineViewport({ chrome: this.view.chrome, media: this.view.media, timeline: this.view.timeline, bindings: this.bindings, dataSource: this.bindings.dataSource, listScroller: this.bindings.listScroller })

        // ── Pinned-message overlay (custom Telegram content below native/hybrid chrome) ──
        if (this.bindings.shouldShowPinnedMessagePanel()) {
          TgPinnedMessagePanel({
            title: this.bindings.pinnedMessageTitle(this.view.pinnedSearch.pinnedMessageIndex, this.view.pinnedSearch.pinnedMessageTotalCount),
            preview: this.view.pinnedSearch.pinnedMessagePreview,
            index: this.view.pinnedSearch.pinnedMessageIndex,
            totalCount: this.view.pinnedSearch.pinnedMessageTotalCount,
            hasThumbnail: this.view.pinnedSearch.pinnedMessageHasThumbnail,
            thumbnailSrc: this.view.pinnedSearch.pinnedMessageThumbnailPath,
            onPress: (): void => {
              this.bindings.handlePinnedMessagePress();
            },
            onClosePress: (): void => {
              this.bindings.handlePinnedMessageClose();
            },
            onListPress: (): void => {
              this.bindings.handlePinnedMessageListPress();
            }
          })
            .position({ x: 0, y: this.view.chrome.topBarTotalHeight })
        }

        // ── Top bar overlay (glass capsules, floats over content) ──
        TgChatTopBar({
          topInset: this.bindings.chatTopInset(),
          title: this.view.chrome.title,
          subtitle: this.view.chrome.chatSubtitle,
          subtitleMode: this.view.chrome.chatSubtitleMode,
          showSubtitleSpinner: this.view.chrome.chatSubtitleSpinner,
          avatarInitials: this.view.chrome.chatAvatarInitials,
          avatarColorIndex: this.view.chrome.chatAvatarColorIndex,
          avatarImageSrc: this.view.chrome.chatAvatarImageSrc,
          isOnline: this.view.chrome.chatIsOnline,
          trailingAction: this.view.chrome.chatTopBarTrailingAction,
          onBackPress: (): void => {
            this.bindings.handleBackPress();
          },
          onTitlePress: (): void => {
            this.bindings.openProfile();
          },
          onAvatarPress: (): void => {
            this.bindings.openProfile();
          },
          onSearchPress: (): void => {
            this.bindings.openSearch();
          },
          isSearchMode: this.view.pinnedSearch.isSearchMode,
          searchQuery: this.view.pinnedSearch.searchQuery,
          searchPlaceholder: localized($r('app.string.search_messages_placeholder').id, 'Search messages'),
          onSearchQueryChange: (query: string): void => {
            this.bindings.handleSearchQueryChange(query);
          },
          onSearchClose: (): void => {
            this.bindings.closeSearch();
          }
        })
        // Default hit-test: Transparent let the list underneath steal taps —
        // title/avatar onClick never fired, profile would not open

        TgChatComposerDock({ chrome: this.view.chrome, composer: this.view.composer, media: this.view.media, panels: this.view.panels, pinnedSearch: this.view.pinnedSearch, timeline: this.view.timeline, bindings: this.bindings })

        if (this.view.media.showMediaGallery) {
          TgChatMediaOverlay({ chrome: this.view.chrome, media: this.view.media, bindings: this.bindings })
        }

        if (this.view.pinnedSearch.pinnedMessagesListVisible) {
          TgChatPinnedOverlay({ chrome: this.view.chrome, pinnedSearch: this.view.pinnedSearch, bindings: this.bindings })
        }
      }
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.bindings.handleChatViewportAreaChange(newArea);
      })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .bindSheet(this.view.panels.stickerSettingsOpen, this.buildStickerSettingsSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: true,
        title: { title: localized($r('app.string.settings_stickers').id, 'Stickers and Emoji') },
        preferType: SheetType.BOTTOM,
        mode: SheetMode.OVERLAY,
        backgroundColor: TgUiTokens.COMPOSER_CAPSULE_BG,
        blurStyle: TgGlassPolicy.composerBlurStyle(),
        maskColor: TgUiTokens.COMPOSER_ATTACHMENT_SHEET_MASK,
        enableOutsideInteractive: false,
        onDisappear: () => {
          if (this.view.panels.stickerSettingsOpen) {
            this.view.panels.stickerSettingsOpen = false;
          }
        }
      })
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true)
    .onReady((context: NavDestinationContext) => {
      this.session.handleNavReady(context);
    })
    .onShown(() => {
      this.session.handleNavShown();
      if (this.session.routeActivated && this.session.routeContext !== undefined &&
        this.session.isRouteContextCurrent(this.session.routeContext)) {
        this.session.slowmodeController.resume();
        this.session.refreshChatInputPanel();
      }
    })
    .onHidden(() => {
      this.session.slowmodeController.suspend();
    })
    .onBackPressed(() => {
      return this.session.handleNavBackPressed();
    })
  }

}

// System route table builder — referenced by route_map.json
@Builder
export function TgChatScreenPageBuilder() {
  TgChatScreenPage()
}
