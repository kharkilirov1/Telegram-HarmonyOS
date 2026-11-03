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
import { TgSelectionPanel } from '../../tg_ui/molecules/TgSelectionPanel';
import { TgChatComposerDock } from './TgChatComposerDock';
import { TgChatPinnedOverlay } from './TgChatPinnedOverlay';
import { TgChatMediaOverlay } from './TgChatMediaOverlay';
import { NavigationUIState, navigationUIState } from '../../../core/model/UIStateModels';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, Chat } from '../../../core/model/AppState';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createSetChatMuteUseCase, MUTE_FOREVER } from '../../../domain/usecases/setChatMute';
import { createDeleteChatHistoryUseCase } from '../../../domain/usecases/deleteChatHistory';

@ComponentV2
export struct TgChatScreenPage {
  @Local private view: ChatScreenViewState = new ChatScreenViewState();
  @Local private appLifecycle: NavigationUIState = navigationUIState;
  private session: ChatScreenSession = new ChatScreenSession(
    this.view, () => this.getUIContext(), () => this.queryNavigationInfo());
  private bindings: ChatScreenViewBindings = new ChatScreenViewBindings(this.session);
  private pageLifecycleToken: number = 0;

  private activeChat(): Chat | undefined {
    const chatId = this.view.chrome.activeChatId;
    if (chatId <= 0) {
      return undefined;
    }
    try {
      const state: AppState = getAppCoreRuntime().getStore().getState();
      return state.chats.chats.get(chatId);
    } catch (_error) {
      return undefined;
    }
  }

  private isActiveChatMuted(): boolean {
    const chat = this.activeChat();
    return chat !== undefined && chat.muteForSeconds > 0;
  }

  private showChatActionToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  private openChatActions(): void {
    const chatId = this.view.chrome.activeChatId;
    if (chatId <= 0) {
      return;
    }
    const muteTitle: string = this.isActiveChatMuted()
      ? localized($r('app.string.profile_unmute').id, 'Unmute')
      : localized($r('app.string.profile_mute').id, 'Mute');
    this.getUIContext().getPromptAction().showActionMenu({
      title: this.view.chrome.title,
      buttons: [
        { text: localized($r('app.string.chat_actions_info').id, 'Chat Info'),
          color: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND },
        { text: muteTitle, color: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND },
        { text: localized($r('app.string.profile_clear_history').id, 'Clear History'),
          color: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND },
        { text: localized($r('app.string.profile_delete_chat').id, 'Delete Chat'),
          color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index === 0) {
        this.bindings.openProfile();
      } else if (result.index === 1) {
        this.toggleActiveChatMute(chatId);
      } else if (result.index === 2) {
        this.confirmChatDeletion(chatId, false);
      } else if (result.index === 3) {
        this.confirmChatDeletion(chatId, true);
      }
    }).catch((error: Error) => {
      hilog.warn(0x003b, 'TgChatScreenPage', 'Chat actions failed: %{public}s', error.message);
    });
  }

  private toggleActiveChatMute(chatId: number): void {
    const token: number = this.pageLifecycleToken;
    const nextMuted: boolean = !this.isActiveChatMuted();
    try {
      const useCase = createSetChatMuteUseCase(getTdGatewayAdapter());
      const work = nextMuted ? useCase.mute(chatId, MUTE_FOREVER) : useCase.unmute(chatId);
      work.then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.showChatActionToast(nextMuted
          ? localized($r('app.string.profile_mute').id, 'Mute')
          : localized($r('app.string.profile_unmute').id, 'Unmute'));
      }).catch((error: Error) => {
        hilog.error(0x003b, 'TgChatScreenPage', 'Chat mute failed: %{public}s', error.message);
      });
    } catch (error) {
      hilog.error(0x003b, 'TgChatScreenPage', 'Mute use case init failed: %{public}s', String(error));
    }
  }

  private confirmChatDeletion(chatId: number, removeChat: boolean): void {
    const title: string = removeChat
      ? localized($r('app.string.profile_delete_chat').id, 'Delete Chat')
      : localized($r('app.string.profile_clear_history').id, 'Clear History');
    const message: string = removeChat
      ? localized($r('app.string.profile_delete_chat_confirm').id, 'Delete this chat and all its messages?')
      : localized($r('app.string.profile_clear_history_confirm').id,
        'Delete all messages in this chat? The chat itself stays in the list.');
    this.getUIContext().getPromptAction().showDialog({
      title: title,
      message: message,
      buttons: [
        { text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND },
        { text: title, color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index !== 1) {
        return;
      }
      this.executeChatDeletion(chatId, removeChat);
    }).catch((error: Error) => {
      hilog.warn(0x003b, 'TgChatScreenPage', 'Delete dialog failed: %{public}s', error.message);
    });
  }

  private executeChatDeletion(chatId: number, removeChat: boolean): void {
    const token: number = this.pageLifecycleToken;
    try {
      const useCase = createDeleteChatHistoryUseCase(getTdGatewayAdapter());
      useCase.execute(chatId, removeChat, removeChat).then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.showChatActionToast(removeChat
          ? localized($r('app.string.profile_chat_deleted_toast').id, 'Chat deleted')
          : localized($r('app.string.profile_history_cleared_toast').id, 'History cleared'));
        if (removeChat) {
          this.bindings.handleBackPress();
        }
      }).catch((error: Error) => {
        hilog.error(0x003b, 'TgChatScreenPage', 'Delete chat failed: %{public}s', error.message);
      });
    } catch (error) {
      hilog.error(0x003b, 'TgChatScreenPage', 'Delete use case init failed: %{public}s', String(error));
    }
  }

  aboutToAppear(): void {
    this.session.aboutToAppear();
    this.pageLifecycleToken += 1;
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
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
  avatarIsSavedMessages: this.view.chrome.chatIsSavedMessages,
          avatarColorIndex: this.view.chrome.chatAvatarColorIndex,
          avatarImageSrc: this.view.chrome.chatAvatarImageSrc,
          isOnline: this.view.chrome.chatIsOnline,
          trailingAction: this.view.chrome.chatTopBarTrailingAction,
          showMoreAction: this.view.chrome.activeChatId > 0,
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
          onMorePress: (): void => {
            this.openChatActions();
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

        // S5b (C9): while messages are selected the selection bar takes the composer's place.
        if (this.view.timeline.selectionActive) {
          TgSelectionPanel({
            title: this.bindings.selectionTitle(),
            onClose: (): void => {
              this.bindings.clearMessageSelection();
            },
            onCopy: (): void => {
              this.bindings.copySelectedMessages();
            },
            onForward: (): void => {
              this.bindings.forwardSelectedMessages();
            },
            onDelete: (): void => {
              this.bindings.deleteSelectedMessages();
            }
          })
        } else {
          TgChatComposerDock({ chrome: this.view.chrome, composer: this.view.composer, media: this.view.media, panels: this.view.panels, pinnedSearch: this.view.pinnedSearch, timeline: this.view.timeline, bindings: this.bindings })
        }

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
