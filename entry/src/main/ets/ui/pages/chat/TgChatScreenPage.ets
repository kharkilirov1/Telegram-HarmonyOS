// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgGlassPolicy } from '../../tg_ui/tokens/TgGlassPolicy';
import { TgStickerSettingsSheet } from '../../tg_ui/atoms/TgStickerSettingsSheet';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgChatBackground } from '../../tg_ui/atoms/TgChatBackground';
import { TgPinnedMessagePanel } from '../../tg_ui/atoms/TgPinnedMessagePanel';
import { localized } from '../../../core/utils/AppResource';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { ProfileMembersRouteParams } from '../profile/TgProfileMembersPage';
import { ChatInviteLinksRouteParams } from './chatInviteLinksRoute';
import { ChatScreenViewState } from './ChatScreenViewState';
import { ChatScreenSession } from './ChatScreenSession';
import { ChatScreenViewBindings } from './ChatScreenViewBindings';
import { TgChatTimelineViewport } from './TgChatTimelineViewport';
import { TgSelectionPanel } from '../../tg_ui/molecules/TgSelectionPanel';
import { TgChatComposerDock } from './TgChatComposerDock';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TgReportCommentOverlay } from '../../tg_ui/molecules/TgReportCommentOverlay';
import { TgChatPinnedOverlay } from './TgChatPinnedOverlay';
import { TgChatMediaOverlay } from './TgChatMediaOverlay';
import { NavigationUIState, navigationUIState } from '../../../core/model/UIStateModels';
import { ChatActionsCoordinator, ChatActionsHost } from './ChatActionsCoordinator';
import { UIContext } from '@kit.ArkUI';

const DOMAIN = 0x0042;
const TAG = 'TgChatScreenPage';

@ComponentV2
export struct TgChatScreenPage {
  @Local private view: ChatScreenViewState = new ChatScreenViewState();
  @Local private appLifecycle: NavigationUIState = navigationUIState;
  private session: ChatScreenSession = new ChatScreenSession(
    this.view, () => this.getUIContext(), () => this.queryNavigationInfo());
  private bindings: ChatScreenViewBindings = new ChatScreenViewBindings(this.session);
  private pageLifecycleToken: number = 0;
  // Report comment panel (page-local: the shared panels slice is pinned by the decomposition contract).
  @Local private reportCommentVisible: boolean = false;
  @Local private reportCommentChatId: number = 0;
  @Local private reportCommentOptionId: string = '';
  @Local private reportCommentDraft: string = '';
  @Local private reportCommentSubmitting: boolean = false;
  // Report by message selection: TDLib can require the offending messages instead of a comment.
  @Local private reportSelectionActive: boolean = false;
  @Local private reportSelectionChatId: number = 0;
  @Local private reportSelectionOptionId: string = '';

  private chatActions: ChatActionsCoordinator = new ChatActionsCoordinator(new ChatActionsHost(
    (): UIContext => this.getUIContext(),
    (): string => this.view.chrome.title,
    (): number => this.pageLifecycleToken,
    (): void => {
      this.bindings.openProfile();
    },
    (): void => {
      this.bindings.handleBackPress();
    },
    (chatId: number, optionId: string): void => {
      this.openReportComment(chatId, optionId);
    },
    (chatId: number, optionId: string): void => {
      this.beginReportSelection(chatId, optionId);
    },
    (): number => this.currentUserId(),
    (chatId: number, title: string): void => {
      this.openMembersFromChat(chatId, title);
    },
    (chatId: number): void => {
      this.openInviteLinksFromChat(chatId);
    }
  ));

  private currentUserId(): number {
    try {
      return getAppCoreRuntime().getStore().getState().auth.userId;
    } catch (_error) {
      return 0;
    }
  }

  // Admin entry: the same members screen the profile opens, with the chat's own counts.
  private openMembersFromChat(chatId: number, title: string): void {
    const chat = getAppCoreRuntime().getStore().getState().chats.chats.get(chatId);
    const params = new ProfileMembersRouteParams(chatId, chat?.supergroupId ?? 0, 'all',
      chat?.memberCount ?? 0);
    try {
      const navigation = this.queryNavigationInfo();
      const stack = navigation?.pathStack;
      if (stack !== undefined) {
        stack.pushPathByName('TgProfileMembersPage', params);
        return;
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Members navigation failed: %{public}s', String(error));
    }
    this.getUIContext().getPromptAction().showToast({
      message: localized($r('app.string.chat_actions_members_failed').id, 'Could not open members'),
      duration: 2000
    });
  }

  private openInviteLinksFromChat(chatId: number): void {
    try {
      const navigation = this.queryNavigationInfo();
      const stack = navigation?.pathStack;
      if (stack !== undefined) {
        stack.pushPathByName('TgChatInviteLinksPage', new ChatInviteLinksRouteParams(chatId));
        return;
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Invite links navigation failed: %{public}s', String(error));
    }
    this.getUIContext().getPromptAction().showToast({
      message: localized($r('app.string.invite_links_failed').id, 'Could not load invite links'),
      duration: 2000
    });
  }

  private openChatActions(): void {
    this.chatActions.currentChatId = this.view.chrome.activeChatId;
    this.chatActions.open();
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

  private openReportComment(chatId: number, optionId: string): void {
    this.reportCommentChatId = chatId;
    this.reportCommentOptionId = optionId;
    this.reportCommentDraft = '';
    this.reportCommentVisible = true;
  }

  private beginReportSelection(chatId: number, optionId: string): void {
    this.reportSelectionChatId = chatId;
    this.reportSelectionOptionId = optionId;
    this.reportSelectionActive = true;
    if (!this.view.timeline.selectionActive) {
      this.view.timeline.selectionActive = true;
      this.view.timeline.selectedMessageIds = [];
    }
  }

  private clearReportSelection(): void {
    this.reportSelectionActive = false;
    this.reportSelectionChatId = 0;
    this.reportSelectionOptionId = '';
  }

  private submitReportSelection(): void {
    const rawIds = this.view.timeline.selectedMessageIds;
    const messageIds: number[] = [];
    for (const rawId of rawIds) {
      const value = Number(rawId);
      if (Number.isSafeInteger(value) && value > 0) {
        messageIds.push(value);
      }
    }
    if (messageIds.length === 0) {
      return;
    }
    const chatId: number = this.reportSelectionChatId;
    const optionId: string = this.reportSelectionOptionId;
    this.chatActions.submitReportMessages(chatId, optionId, messageIds)
      .then((): void => {
        this.bindings.clearMessageSelection();
        this.clearReportSelection();
      })
      .catch((): void => {
        // Keep the selection so the user can retry.
      });
  }

  private closeReportComment(): void {
    this.reportCommentVisible = false;
    this.reportCommentChatId = 0;
    this.reportCommentOptionId = '';
    this.reportCommentDraft = '';
    this.reportCommentSubmitting = false;
  }

  private submitReportComment(): void {
    if (this.reportCommentSubmitting) {
      return;
    }
    if (this.reportCommentDraft.trim().length === 0) {
      this.getUIContext().getPromptAction().showToast({
        message: localized($r('app.string.chat_actions_report_text_required').id,
          'Telegram asks for a comment to finish this report'),
        duration: 2000
      });
      return;
    }
    const chatId: number = this.reportCommentChatId;
    const optionId: string = this.reportCommentOptionId;
    this.reportCommentSubmitting = true;
    this.chatActions.submitReportComment(chatId, optionId, this.reportCommentDraft)
      .then((): void => {
        this.closeReportComment();
      })
      .catch((): void => {
        this.reportCommentSubmitting = false;
      });
  }

  @Builder
  private buildReportCommentPanel() {
    Column() {
      Text(localized($r('app.string.chat_actions_report_comment_title').id, 'Report Comment'))
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .width('100%')
      TextInput({
        text: this.reportCommentDraft,
        placeholder: localized($r('app.string.chat_actions_report_comment_placeholder').id,
          'Describe the problem')
      })
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .height(44)
        .margin({ top: TgUiTokens.SPACE_8 })
        .onChange((value: string): void => {
          this.reportCommentDraft = value;
        })
      Row() {
        Button(localized($r('app.string.chat_actions_report_comment_cancel').id, 'Cancel'))
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .height(36)
          .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .onClick(() => {
            this.closeReportComment();
          })
        Button(localized($r('app.string.chat_actions_report_comment_send').id, 'Send'))
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .height(36)
          .margin({ left: TgUiTokens.SPACE_12 })
          .enabled(!this.reportCommentSubmitting)
          .onClick(() => {
            this.submitReportComment();
          })
      }
      .justifyContent(FlexAlign.End)
      .width('100%')
      .margin({ top: TgUiTokens.SPACE_12 })
    }
    .width('100%')
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, bottom: TgUiTokens.SPACE_16 })
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
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
              this.clearReportSelection();
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
            },
            showReport: this.reportSelectionActive,
            reportLabel: $r('app.string.chat_actions_report'),
            onReport: (): void => {
              this.submitReportSelection();
            }
          })
        } else {
          TgChatComposerDock({ chrome: this.view.chrome, composer: this.view.composer, media: this.view.media, panels: this.view.panels, pinnedSearch: this.view.pinnedSearch, timeline: this.view.timeline, bindings: this.bindings })
        }

        if (this.view.media.showMediaGallery) {
          TgChatMediaOverlay({ chrome: this.view.chrome, media: this.view.media, bindings: this.bindings })
        }

        if (this.reportCommentVisible) {
          TgReportCommentOverlay({
            title: localized($r('app.string.chat_actions_report_comment_title').id, 'Report Comment'),
            placeholder: localized($r('app.string.chat_actions_report_comment_placeholder').id,
              'Describe the problem'),
            draft: this.reportCommentDraft,
            submitting: this.reportCommentSubmitting,
            cancelLabel: localized($r('app.string.chat_actions_report_comment_cancel').id, 'Cancel'),
            sendLabel: localized($r('app.string.chat_actions_report_comment_send').id, 'Send'),
            onDraftChange: (value: string): void => {
              this.reportCommentDraft = value;
            },
            onCancel: (): void => {
              this.closeReportComment();
            },
            onSubmit: (): void => {
              this.submitReportComment();
            }
          })
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
