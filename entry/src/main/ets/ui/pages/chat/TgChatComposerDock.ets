// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgGlassPolicy } from '../../tg_ui/tokens/TgGlassPolicy';
import { TgComposerInput } from '../../tg_ui/atoms/TgComposerInput';
import { TgPhotoSelectionPreview } from '../../tg_ui/atoms/TgPhotoSelectionPreview';
import { TgAttachmentRecentItem } from '../../tg_ui/atoms/TgAttachmentSheet';
import { TgScrollToBottomButton } from '../../tg_ui/atoms/TgScrollToBottomButton';
import { TgChatBottomActionBar } from '../../tg_ui/atoms/TgChatBottomActionBar';
import { localized } from '../../../core/utils/AppResource';
import { ChatChromeState } from './ChatChromeState';
import { ChatComposerState } from './ChatComposerState';
import { ChatMediaViewState } from './ChatMediaViewState';
import { ChatPanelsState } from './ChatPanelsState';
import { ChatPinnedSearchState } from './ChatPinnedSearchState';
import { ChatTimelineViewState } from './ChatTimelineViewState';
import { ChatComposerDockPort } from './ChatScreenViewPorts';
import { TgChatKeyboardPanels } from './TgChatKeyboardPanels';

@ComponentV2
export struct TgChatComposerDock {
  @Require @Param chrome: ChatChromeState;
  @Require @Param composer: ChatComposerState;
  @Require @Param media: ChatMediaViewState;
  @Require @Param panels: ChatPanelsState;
  @Require @Param pinnedSearch: ChatPinnedSearchState;
  @Require @Param timeline: ChatTimelineViewState;
  @Require @Param bindings: ChatComposerDockPort;

  build() {
    // ── Composer overlay (glass, floats over content at bottom) ──
    Column() {
        Blank()
          .hitTestBehavior(HitTestMode.None)
        if (this.timeline.showScrollToBottom && !this.pinnedSearch.isSearchMode && !this.media.showMediaGallery) {
          Row() {
            Blank()
              .hitTestBehavior(HitTestMode.None)
            TgScrollToBottomButton({
              unreadCount: this.timeline.scrollToBottomUnreadCount,
              onPress: (): void => {
                this.bindings.handleScrollToBottomPress();
              }
            })
          }
          .width('100%')
          .padding({ right: TgUiTokens.SCROLL_FAB_MARGIN, bottom: TgUiTokens.SCROLL_FAB_MARGIN })
          .hitTestBehavior(HitTestMode.Transparent)
          .zIndex(TgUiTokens.SCROLL_FAB_Z_OVER_FADE)
        }
        Stack({ alignContent: Alignment.Bottom }) {
          this.buildComposerFadeBackdrop()
          Column() {
          if (this.pinnedSearch.isSearchMode) {
            this.buildSearchNavBar()
          } else if (this.chrome.chatBottomBarRestricted || this.chrome.chatBottomBarAction !== 'none') {
            TgChatBottomActionBar({
              mode: this.chrome.chatBottomBarRestricted ? 'restricted' : 'action',
              actionText: this.bindings.bottomBarActionLabel(),
              isActionAccent: this.chrome.chatBottomBarAction === 'join',
                messageText: this.bindings.bottomBarMessage(),
              bottomInset: this.bindings.composerKeyboardPanelVisible() ? 0 : this.chrome.bottomOverlayInset,
              onActionPress: (): void => {
                this.bindings.handleChatBottomBarAction();
              }
            })
          } else {
            if (this.composer.pendingAttachmentKind === 'photo' && this.composer.pendingAttachmentUris.length > 0) {
              TgPhotoSelectionPreview({
                uris: this.composer.pendingAttachmentUris,
                disabled: this.composer.isSending || !this.bindings.composerAllows('photo') ||
                  this.composer.isEditingMessage || this.composer.isForwardingMessages,
                onRemove: (uri: string): void => { this.bindings.removePendingPhoto(uri); },
                onMove: (uri: string, direction: number): void => { this.bindings.movePendingPhoto(uri, direction); }
              })
            }
            TgComposerInput({
              text: this.composer.composerDraftText,
              requestedCaretPosition: this.composer.composerSelectionEnd,
              caretRequestRevision: this.composer.composerCaretRequestRevision,
              placeholder: localized($r('app.string.message_placeholder').id, 'Message'),
              isDisabled: this.chrome.activeChatId === 0,
              showAttachButton: this.bindings.composerAllows('attachment'),
              sendEnabled: this.bindings.composerCanSubmit(),
              slowmodeSeconds: this.composer.isEditingMessage ? 0 : this.chrome.composerSlowmodeSeconds,
              slowmodeLabel: localized($r('app.string.composer_slowmode_wait').id, 'Slow mode'),
              accessRetryVisible: this.chrome.composerAccessRetryVisible,
              accessRetryLabel: localized($r('app.string.retry').id, 'Retry'),
              onAccessRetryPress: (): void => { this.bindings.retryChatAccess(); },
              voiceEnabled: this.bindings.composerAllows('voice'),
              attachmentPhotoEnabled: this.bindings.composerAllows('photo'),
              attachmentVideoEnabled: this.bindings.composerAllows('video'),
              attachmentCategoryEnabled: [
                this.bindings.composerAllows('photo') || this.bindings.composerAllows('video'),
                this.bindings.composerAllows('photo') || this.bindings.composerAllows('video'),
                this.bindings.composerAllows('document'), false, false, false
              ],
              bottomInset: this.bindings.composerKeyboardPanelVisible() ? 0 : this.chrome.bottomOverlayInset,
              showReplySnippet: this.composer.replyToMessageId !== '0',
              replyAuthor: this.composer.replyToAuthor,
              replyPreview: this.composer.replyToPreview,
              replyIsOutgoing: false,
              replyIsQuote: this.composer.replyToIsQuote,
              replyHasThumbnail: false,
              showEditSnippet: this.composer.isEditingMessage,
              allowEmptyEdit: this.composer.editingAllowsEmpty,
              editPreview: this.composer.editingOriginalText,
              showForwardSnippet: this.composer.isForwardingMessages,
              forwardTitle: this.composer.forwardTitle,
              forwardPreview: this.composer.forwardPreview,
              showAttachmentSnippet: this.composer.pendingAttachmentUris.length > 0,
              attachmentKind: this.composer.pendingAttachmentKind,
              attachmentTitle: this.composer.pendingAttachmentTitle,
              attachmentPreview: this.composer.pendingAttachmentPreview,
              attachmentMenuLabels: this.bindings.composerAttachmentMenuLabels(),
              attachmentRecentItems: this.panels.attachmentRecentItems,
              attachmentRecentLoading: this.panels.attachmentRecentLoading,
              emojiPanelOpen: this.bindings.composerKeyboardPanelVisible(),
              showBotMenu: this.composer.showBotMenu,
              botMenuTitle: this.composer.botMenuTitle,
              botMenuOpen: this.composer.botMenuOpen,
              botMenuCommands: this.bindings.botMenuCommandNames(),
              botMenuDescriptions: this.bindings.botMenuCommandDescriptions(),
              containerWidth: this.chrome.timelineContainerWidth,
              voiceRecordingState: this.composer.voiceRecordingState,
              voiceRecordingDurationMs: this.composer.voiceRecordingDurationMs,
              voiceSlideLabel: localized($r('app.string.composer_voice_slide_cancel').id, 'Slide to cancel'),
              voiceLockedLabel: localized($r('app.string.composer_voice_locked').id, 'Recording'),
              voicePreviewLabel: localized($r('app.string.composer_voice_preview').id, 'Voice message'),
              voicePreparingLabel: localized($r('app.string.composer_voice_preparing').id, 'Starting...'),
              voiceSendingLabel: localized($r('app.string.composer_voice_sending').id, 'Sending...'),
              onTextChange: (value: string): void => {
                this.bindings.handleComposerTextChange(value);
              },
              onTextSelectionChange: (start: number, end: number): void => {
                this.bindings.handleComposerSelectionChange(start, end);
              },
              onInputWillFocus: (): void => {
                this.bindings.handleComposerWillFocus();
              },
              onInputFocusChange: (focused: boolean): void => {
                this.bindings.handleComposerFocusChange(focused);
              },
              onSendPress: (text: string): void => {
                this.bindings.handleSendMessage(text);
              },
              onAttachPress: (): void => {
                this.bindings.handleComposerAttachPress();
              },
              onAttachmentMenuItemPress: (index: number): void => {
                this.bindings.handleComposerAttachmentMenuItemPress(index);
              },
              onAttachmentMenuOpenChange: (isOpen: boolean): void => {
                this.bindings.handleAttachmentMenuOpenChange(isOpen);
              },
              onAttachmentRecentPress: (item: TgAttachmentRecentItem): void => {
                this.bindings.handleAttachmentRecentPress(item);
              },
              onEmojiPress: (): void => {
                this.bindings.handleComposerEmojiPress();
              },
              onKeyboardModePress: (): void => {
                this.bindings.handleComposerKeyboardModePress();
              },
              onVoicePress: (): void => {
                this.bindings.handleComposerVoicePress();
              },
              onVoiceRecordStart: (): void => {
                this.bindings.handleVoiceRecordStart();
              },
              onVoiceRecordSend: (): void => {
                this.bindings.handleVoiceRecordSend();
              },
              onVoiceRecordCancel: (): void => {
                this.bindings.handleVoiceRecordCancel();
              },
              onVoiceRecordLock: (): void => {
                this.bindings.handleVoiceRecordLock();
              },
              onBotMenuPress: (): void => {
                this.bindings.handleBotMenuPress();
              },
              onBotMenuOpenChange: (isOpen: boolean): void => {
                this.bindings.handleBotMenuOpenChange(isOpen);
              },
              onBotMenuCommandPress: (index: number): void => {
                this.bindings.handleBotMenuCommandPress(index);
              },
              onReplyCancelPress: (): void => {
                this.bindings.cancelReply();
              },
              onEditCancelPress: (): void => {
                this.bindings.cancelEditMessage();
              },
              onForwardCancelPress: (): void => {
                this.bindings.cancelForwardMessages();
              },
              onAttachmentCancelPress: (): void => {
                this.bindings.clearPendingAttachment();
              }
            })

            TgChatKeyboardPanels({ chrome: this.chrome, panels: this.panels, bindings: this.bindings })
          }
      }
      .width('100%')
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.bindings.handleComposerAreaChange(newArea.height as number);
      })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    // Bottom-aligned Stack on purpose: the scrim is anchored to the very
    // bottom edge of the screen (user direction 2026-08-29), one zone
    // taller than the composer so it dissolves bubbles just above the
    // capsule top, and shows through the translucent glass below it.
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private buildSearchNavBar() {
      Column() {
        Row() {
          Row() {
            Column() {
              SymbolGlyph($r('sys.symbol.chevron_up'))
                .fontSize(TgUiTokens.SEARCH_NAV_ICON_SIZE)
                .fontColor([this.pinnedSearch.searchResultPos < this.pinnedSearch.searchResultTotal
                  ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COMPOSER_ACTION_INACTIVE])
            }
            .width(TgUiTokens.SEARCH_NAV_CONTROL_SIZE)
            .height(TgUiTokens.SEARCH_NAV_CONTROL_SIZE)
            .justifyContent(FlexAlign.Center)
            .accessibilityText(localized($r('app.string.search_previous_result').id, 'Previous result'))
            .onClick(() => {
              this.bindings.goToOlderSearchResult();
            })

            Column() {
              SymbolGlyph($r('sys.symbol.chevron_down'))
                .fontSize(TgUiTokens.SEARCH_NAV_ICON_SIZE)
                .fontColor([this.pinnedSearch.searchResultPos > 1
                  ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COMPOSER_ACTION_INACTIVE])
            }
            .width(TgUiTokens.SEARCH_NAV_CONTROL_SIZE)
            .height(TgUiTokens.SEARCH_NAV_CONTROL_SIZE)
            .justifyContent(FlexAlign.Center)
            .accessibilityText(localized($r('app.string.search_next_result').id, 'Next result'))
            .onClick(() => {
              this.bindings.goToNewerSearchResult();
            })
          }
          .height(TgUiTokens.SEARCH_NAV_CAPSULE_HEIGHT)
          .backgroundColor(TgGlassPolicy.shouldUseRealtimeBlur()
            ? TgUiTokens.COMPOSER_CAPSULE_BG : TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG)
          .border({ width: TgUiTokens.SEARCH_NAV_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
          .borderRadius(TgUiTokens.SEARCH_NAV_CAPSULE_RADIUS)
          .backdropBlur(TgGlassPolicy.shouldUseRealtimeBlur() ? TgUiTokens.GLASS_CAPSULE_BACKDROP_BLUR : 0)

          Blank()

          if (this.pinnedSearch.searchQuery.trim().length > 0) {
            Row({ space: TgUiTokens.SPACE_6 }) {
              if (this.pinnedSearch.searchLoading) {
                LoadingProgress()
                  .width(TgUiTokens.SEARCH_NAV_PROGRESS_SIZE)
                  .height(TgUiTokens.SEARCH_NAV_PROGRESS_SIZE)
                  .color(TgUiTokens.COMPOSER_ACTION_ACTIVE)
              }
              if (this.pinnedSearch.searchResultTotal > 0) {
                Text(this.pinnedSearch.searchResultPos.toString() + ' / ' + this.pinnedSearch.searchResultTotal.toString())
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              } else if (this.pinnedSearch.searchLoading) {
                Text(localized($r('app.string.search_searching').id, 'Searching...'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              } else if (this.pinnedSearch.searchError) {
                Text(localized($r('app.string.search_failed').id, 'Search failed'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              } else {
                Text(localized($r('app.string.search_no_results').id, 'No results'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              }
            }
            .height(TgUiTokens.SEARCH_NAV_CAPSULE_HEIGHT)
            .constraintSize({ minWidth: TgUiTokens.SEARCH_NAV_STATUS_MIN_WIDTH })
            .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
            .justifyContent(FlexAlign.Center)
            .backgroundColor(TgGlassPolicy.shouldUseRealtimeBlur()
              ? TgUiTokens.COMPOSER_CAPSULE_BG : TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG)
            .border({ width: TgUiTokens.SEARCH_NAV_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
            .borderRadius(TgUiTokens.SEARCH_NAV_CAPSULE_RADIUS)
            .backdropBlur(TgGlassPolicy.shouldUseRealtimeBlur() ? TgUiTokens.GLASS_CAPSULE_BACKDROP_BLUR : 0)
          }
        }
        .width('100%')
        .height(TgUiTokens.SEARCH_NAV_BAR_HEIGHT)
        .padding({ left: TgUiTokens.SEARCH_NAV_SIDE_INSET, right: TgUiTokens.SEARCH_NAV_SIDE_INSET })
      }
      .width('100%')
      .padding({ bottom: this.chrome.bottomOverlayInset })
    }

  @Builder
  private buildComposerFadeBackdrop() {
      Column()
        .width('100%')
        .height(this.chrome.composerTotalHeight + TgUiTokens.CHROME_FADE_ZONE_HEIGHT)
        .backdropBlur(TgGlassPolicy.shouldUseRealtimeBlur() ? TgUiTokens.CHROME_FADE_BLUR_MID : 0)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [TgUiTokens.CHROME_FADE_ZERO, 0],
            [TgUiTokens.CHROME_FADE_WEAK, 0.6],
            [TgUiTokens.CHROME_FADE_STRONG, 1]
          ]
        })
        .hitTestBehavior(HitTestMode.None)
    }
}
