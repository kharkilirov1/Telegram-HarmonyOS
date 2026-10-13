import { AppState, Chat, TextEntity } from '../../../core/model/AppState';
import { TgAttachmentRecentItem } from '../../tg_ui/atoms/TgAttachmentSheet';
import { CustomEmojiCellVO, CustomEmojiPackTabVO } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { StickerCellVO, StickerSetTabVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { TgPinnedMessageListItem } from '../../tg_ui/atoms/TgPinnedMessageList';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { MediaContentType } from './VoicePlaybackController';
import { MediaPlaybackPageHandle } from './GlobalMediaPlayback';
import { PendingMediaOpenKind } from './PendingMediaOpenIntent';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { TgVoiceRecordingState } from '../../tg_ui/utils/TgVoiceRecordingPolicy';
import { ChatForwardModeState, ChatMessageActionItem } from './ChatMessageActionsController';
import { ChatAvatarPresentation, ChatSubtitlePresentation } from './ChatTopBarPresentation';
import { PendingSharedMediaAction } from './PendingSharedMediaActionSignal';
import { SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { StickerPanelUseCase, StickerPanelEntry, GifPanelEntry } from '../../../domain/usecases/stickerPanel';
import { SendMediaMessageUseCase } from '../../../domain/usecases/sendMediaMessage';
import { EditMessageUseCase } from '../../../domain/usecases/editMessage';
import { DeleteMessagesUseCase } from '../../../domain/usecases/deleteMessages';
import { ForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { SearchChatMessagesUseCase } from '../../../domain/usecases/searchChatMessages';
import { PinChatMessageUseCase } from '../../../domain/usecases/pinChatMessage';
import { LoadChatHistoryParams } from '../../../domain/usecases/loadChatHistory';
import { PinnedMessageInfo } from '../../../domain/usecases/loadPinnedMessage';
import { LoadRepliedMessageUseCase } from '../../../domain/usecases/loadRepliedMessage';
import { ReplyHydrationRequest } from './ReplyHydrationCoordinator';
import { CustomEmojiTextEntity } from '../../../core/model/AppCommand';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';
import { uiObserver } from '@kit.ArkUI';
import { ChatScreenContext } from './ChatScreenContext';
import { ChatScreenViewState } from './ChatScreenViewState';
import { ChatScreenSessionPorts } from './ChatScreenSessionPorts';
import {
  getActiveChatId as delegateGetActiveChatId, getLifecycleToken as delegateGetLifecycleToken, getChatUIContext as delegateGetChatUIContext, getSendUseCase as delegateGetSendUseCase,
  getSendMediaUseCase as delegateGetSendMediaUseCase, setVoiceRecordingState as delegateSetVoiceRecordingState, isSendingMessage as delegateIsSendingMessage, setSendingMessage as delegateSetSendingMessage,
  getSendOperationToken as delegateGetSendOperationToken, hasActiveChatState as delegateHasActiveChatState, isEditModeActive as delegateIsEditModeActive, isForwardModeActive as delegateIsForwardModeActive,
  submitEditMessage as delegateSubmitEditMessage, submitForwardMessages as delegateSubmitForwardMessages, getComposerInputRevision as delegateGetComposerInputRevision, getDraftText as delegateGetDraftText, setDraftText as delegateSetDraftText,
  getDraftSelectionStart as delegateGetDraftSelectionStart, getDraftSelectionEnd as delegateGetDraftSelectionEnd, setDraftSelection as delegateSetDraftSelection, getCustomEmojiEntities as delegateGetCustomEmojiEntities,
  setCustomEmojiEntities as delegateSetCustomEmojiEntities, setEmojiPanelVisible as delegateSetEmojiPanelVisible, getEmojiPanelVisible as delegateGetEmojiPanelVisible, getReplyToMessageId as delegateGetReplyToMessageId,
  setReplyMode as delegateSetReplyMode, clearReplyMode as delegateClearReplyMode, getPendingAttachmentUris as delegateGetPendingAttachmentUris, getPendingAttachmentKind as delegateGetPendingAttachmentKind,
  setPendingAttachmentState as delegateSetPendingAttachmentState, clearPendingAttachmentState as delegateClearPendingAttachmentState
} from './ChatComposerHostAdapters';
import {
  getEditUseCase as delegateGetEditUseCase, getDeleteUseCase as delegateGetDeleteUseCase, getSourceForwardUseCase as delegateGetSourceForwardUseCase, getForwardUseCase as delegateGetForwardUseCase,
  getPinUseCase as delegateGetPinUseCase, onPinnedMessageChanged as delegateOnPinnedMessageChanged, setEditMode as delegateSetEditMode, getEditingMessageId as delegateGetEditingMessageId,
  getEditingOriginalText as delegateGetEditingOriginalText, rebaseEditingMessage as delegateRebaseEditingMessage, clearEditMode as delegateClearEditMode, setForwardMode as delegateSetForwardMode,
  getForwardModeState as delegateGetForwardModeState, clearForwardMode as delegateClearForwardMode
} from './ChatMessageActionHostAdapters';
import {
  refreshChatInputPanel as delegateRefreshChatInputPanel, canUseComposer as delegateCanUseComposer, canSendNewMessages as delegateCanSendNewMessages, composerCanSubmit as delegateComposerCanSubmit,
  composerAllows as delegateComposerAllows, deriveChatBottomBar as delegateDeriveChatBottomBar, bottomBarActionLabel as delegateBottomBarActionLabel, retryChatAccess as delegateRetryChatAccess,
  bottomBarMessage as delegateBottomBarMessage, handleChatBottomBarAction as delegateHandleChatBottomBarAction
} from './ChatPermissionCoordinator';
import {
  scrollToMessageId as delegateScrollToMessageId, jumpToMessageId as delegateJumpToMessageId, fulfillPendingJump as delegateFulfillPendingJump
} from './ChatMessageJumpCoordinator';
import {
  normalizeSharedMediaLink as delegateNormalizeSharedMediaLink, resolveEntityLink as delegateResolveEntityLink, openSharedMediaLink as delegateOpenSharedMediaLink, executeSharedMediaAction as delegateExecuteSharedMediaAction,
  fulfillPendingSharedMediaAction as delegateFulfillPendingSharedMediaAction, beginSharedMediaAction as delegateBeginSharedMediaAction
} from './ChatSharedMediaActionCoordinator';
import {
  getSearchUseCase as delegateGetSearchUseCase, isSearchModeActive as delegateIsSearchModeActive, getSearchQuery as delegateGetSearchQuery, setSearchQuery as delegateSetSearchQuery,
  setSearchModeActive as delegateSetSearchModeActive, onSearchResultsUpdated as delegateOnSearchResultsUpdated, onSearchLoadingChanged as delegateOnSearchLoadingChanged, onSearchErrorChanged as delegateOnSearchErrorChanged,
  flashSearchHit as delegateFlashSearchHit, clearSearchFlash as delegateClearSearchFlash, handleSearchQueryChange as delegateHandleSearchQueryChange, openSearch as delegateOpenSearch,
  closeSearch as delegateCloseSearch, useSearchFlashOutline as delegateUseSearchFlashOutline
} from './ChatSearchPresentationCoordinator';
import {
  aboutToAppear as delegateAboutToAppear, activateChatRoute as delegateActivateChatRoute, shouldReactToStoreChange as delegateShouldReactToStoreChange, scheduleLifecycleTask as delegateScheduleLifecycleTask
} from './ChatRouteActivationCoordinator';
import {
  isRouteContextCurrent as delegateIsRouteContextCurrent, bindChatRoute as delegateBindChatRoute, syncOwnedChatContext as delegateSyncOwnedChatContext, ownsNavigationContext as delegateOwnsNavigationContext,
  clearOwnedChatContext as delegateClearOwnedChatContext, resolveOwnedChatTitle as delegateResolveOwnedChatTitle, showOwnedChatRoute as delegateShowOwnedChatRoute, createChatRouteParams as delegateCreateChatRouteParams,
  getChatRouteToken as delegateGetChatRouteToken, startOwnedChatData as delegateStartOwnedChatData, showChatOpenFailure as delegateShowChatOpenFailure
} from './ChatRouteOwnershipCoordinator';
import {
  aboutToDisappear as delegateAboutToDisappear, clearTransientTimers as delegateClearTransientTimers
} from './ChatPageTeardownCoordinator';
import {
  scrollToBottomSoon as delegateScrollToBottomSoon, scrollTimelineToBottomAligned as delegateScrollTimelineToBottomAligned, shouldKeepTimelineBottomAligned as delegateShouldKeepTimelineBottomAligned, scheduleComposerBottomAlignment as delegateScheduleComposerBottomAlignment,
  handleComposerFocusChange as delegateHandleComposerFocusChange, handleComposerWillFocus as delegateHandleComposerWillFocus, handleChatViewportAreaChange as delegateHandleChatViewportAreaChange, chatTopInset as delegateChatTopInset,
  shouldShowPinnedMessagePanel as delegateShouldShowPinnedMessagePanel, chatContentStartOffset as delegateChatContentStartOffset, computeSafeInsets as delegateComputeSafeInsets, bindWindowSizeListener as delegateBindWindowSizeListener,
  updateTimelineContainerWidth as delegateUpdateTimelineContainerWidth
} from './ChatWindowGeometryCoordinator';
import {
  resetPinnedMessageState as delegateResetPinnedMessageState, applyPinnedMessageInfo as delegateApplyPinnedMessageInfo, loadSinglePinnedMessageFallback as delegateLoadSinglePinnedMessageFallback, loadPinnedMessage as delegateLoadPinnedMessage,
  handlePinnedMessagePress as delegateHandlePinnedMessagePress, handlePinnedMessageClose as delegateHandlePinnedMessageClose, pinnedMessageTitle as delegatePinnedMessageTitle, pinnedMessageListItems as delegatePinnedMessageListItems,
  setPinnedMessagesListVisible as delegateSetPinnedMessagesListVisible, handlePinnedMessageListPress as delegateHandlePinnedMessageListPress, handlePinnedListItemPress as delegateHandlePinnedListItemPress, loadMorePinnedMessages as delegateLoadMorePinnedMessages
} from './ChatPinnedMessagesCoordinator';
import {
  resetPlaybackState as delegateResetPlaybackState, setupMediaPlaybackController as delegateSetupMediaPlaybackController, getCurrentMediaPlaybackHandle as delegateGetCurrentMediaPlaybackHandle, notifyPlaybackRows as delegateNotifyPlaybackRows,
  teardownMediaPlaybackController as delegateTeardownMediaPlaybackController, publishNowPlayingMeta as delegatePublishNowPlayingMeta, handlePlaybackCompleted as delegateHandlePlaybackCompleted
} from './ChatPlaybackCoordinator';
import {
  applyChatAvatarPresentation as delegateApplyChatAvatarPresentation, applyChatSubtitlePresentation as delegateApplyChatSubtitlePresentation, updateChatTopBarData as delegateUpdateChatTopBarData
} from './ChatTopBarCoordinator';
import {
  resetBotMenuState as delegateResetBotMenuState, refreshBotMenuState as delegateRefreshBotMenuState, handleBotMenuPress as delegateHandleBotMenuPress, botMenuCommandNames as delegateBotMenuCommandNames,
  botMenuCommandDescriptions as delegateBotMenuCommandDescriptions, handleBotMenuOpenChange as delegateHandleBotMenuOpenChange, handleBotMenuCommandPress as delegateHandleBotMenuCommandPress
} from './ChatBotMenuCoordinator';
import {
  rebuildTimeline as delegateRebuildTimeline, effectiveVoiceListened as delegateEffectiveVoiceListened, isActiveVoiceEntry as delegateIsActiveVoiceEntry, isActiveAudioEntry as delegateIsActiveAudioEntry
} from './ChatTimelineTransactionCoordinator';
import {
  scheduleMissingReplyHydration as delegateScheduleMissingReplyHydration, runMissingReplyHydration as delegateRunMissingReplyHydration, refreshRestoredReplySnippet as delegateRefreshRestoredReplySnippet
} from './ChatReplyHydrationCoordinator';
import {
  refreshScrollToBottomVisibility as delegateRefreshScrollToBottomVisibility, handleScrollToBottomPress as delegateHandleScrollToBottomPress, computeInitialIndex as delegateComputeInitialIndex, guardProgrammaticScroll as delegateGuardProgrammaticScroll,
  resetPaginationState as delegateResetPaginationState, isNearTopPaginationEdge as delegateIsNearTopPaginationEdge, isNearBottomPaginationEdge as delegateIsNearBottomPaginationEdge, armAutoPaginationUnlock as delegateArmAutoPaginationUnlock,
  maybeUnlockAutoPagination as delegateMaybeUnlockAutoPagination, handleTimelineTouch as delegateHandleTimelineTouch, shouldSuppressLoadOlder as delegateShouldSuppressLoadOlder, schedulePaginationRecheck as delegateSchedulePaginationRecheck,
  saveScrollPosition as delegateSaveScrollPosition, restoreScrollPosition as delegateRestoreScrollPosition, isNearBottom as delegateIsNearBottom
} from './ChatTimelineViewportCoordinator';
import {
  loadOlderMessages as delegateLoadOlderMessages, recheckPaginationEdge as delegateRecheckPaginationEdge, loadNewerMessages as delegateLoadNewerMessages, maybeMarkChatRead as delegateMaybeMarkChatRead
} from './ChatTimelinePaginationCoordinator';
import {
  notifyMediaDownloadStateChanged as delegateNotifyMediaDownloadStateChanged, requestMediaDownload as delegateRequestMediaDownload, cancelMediaDownload as delegateCancelMediaDownload, clearPendingMediaDownloads as delegateClearPendingMediaDownloads,
  isMediaDownloadPending as delegateIsMediaDownloadPending, isMediaDownloadFailed as delegateIsMediaDownloadFailed, effectiveAlbumPhotoDownloading as delegateEffectiveAlbumPhotoDownloading, effectiveAlbumPhotoDownloadFailed as delegateEffectiveAlbumPhotoDownloadFailed,
  syncResolvedPendingDownloads as delegateSyncResolvedPendingDownloads
} from './ChatMediaDownloadCoordinator';
import {
  rememberPendingMediaOpenIntent as delegateRememberPendingMediaOpenIntent, clearPendingMediaOpenIntent as delegateClearPendingMediaOpenIntent, fulfillPendingMediaOpenIntent as delegateFulfillPendingMediaOpenIntent, handleVoiceTap as delegateHandleVoiceTap,
  openAudioFile as delegateOpenAudioFile, openDocumentFile as delegateOpenDocumentFile, handleDocumentTap as delegateHandleDocumentTap, handleAudioTap as delegateHandleAudioTap,
  handleAudioSeek as delegateHandleAudioSeek, handleVoiceSeek as delegateHandleVoiceSeek
} from './ChatMediaOpenCoordinator';
import {
  buildMediaGalleryItems as delegateBuildMediaGalleryItems, handleMediaGalleryOpen as delegateHandleMediaGalleryOpen, animateMediaGalleryState as delegateAnimateMediaGalleryState, refreshOpenMediaGalleryItems as delegateRefreshOpenMediaGalleryItems
} from './ChatMediaGalleryCoordinator';
import {
  startReply as delegateStartReply, cancelReply as delegateCancelReply, applyPendingForwardTransferIfNeeded as delegateApplyPendingForwardTransferIfNeeded, startForwardMessages as delegateStartForwardMessages,
  cancelForwardMessages as delegateCancelForwardMessages, openForwardTargetPicker as delegateOpenForwardTargetPicker, copyMessageText as delegateCopyMessageText, showMessageActions as delegateShowMessageActions,
  messageActionsPopupStateHandler as delegateMessageActionsPopupStateHandler, closeMessageActions as delegateCloseMessageActions, refreshForwardActionAvailability as delegateRefreshForwardActionAvailability, messageActionItems as delegateMessageActionItems,
  messageActionsPopupWidth as delegateMessageActionsPopupWidth, messageActionsPopupHeight as delegateMessageActionsPopupHeight, handleMessageActionPress as delegateHandleMessageActionPress, startEditMessage as delegateStartEditMessage,
  cancelEditMessage as delegateCancelEditMessage, handleEditMessage as delegateHandleEditMessage, handleForwardMessages as delegateHandleForwardMessages, handlePinMessage as delegateHandlePinMessage,
  handleDeleteMessage as delegateHandleDeleteMessage
} from './ChatMessagePopupCoordinator';
import {
  setStickerPanelVisible as delegateSetStickerPanelVisible, openStickerSettings as delegateOpenStickerSettings, handleSendMessage as delegateHandleSendMessage, handleComposerAttachPress as delegateHandleComposerAttachPress,
  handleAttachmentMenuOpenChange as delegateHandleAttachmentMenuOpenChange, composerKeyboardPanelVisible as delegateComposerKeyboardPanelVisible, composerAttachmentMenuLabels as delegateComposerAttachmentMenuLabels, handleComposerAttachmentMenuItemPress as delegateHandleComposerAttachmentMenuItemPress,
  handleAttachmentRecentPress as delegateHandleAttachmentRecentPress, handleComposerEmojiPress as delegateHandleComposerEmojiPress, handleComposerKeyboardModePress as delegateHandleComposerKeyboardModePress, handleComposerVoicePress as delegateHandleComposerVoicePress,
  handleVoiceRecordStart as delegateHandleVoiceRecordStart, handleVoiceRecordSend as delegateHandleVoiceRecordSend, handleVoiceRecordCancel as delegateHandleVoiceRecordCancel, handleVoiceRecordLock as delegateHandleVoiceRecordLock,
  handleComposerEmojiSelected as delegateHandleComposerEmojiSelected, handleComposerSelectionChange as delegateHandleComposerSelectionChange, handleCustomEmojiSelected as delegateHandleCustomEmojiSelected, handleComposerStickerPress as delegateHandleComposerStickerPress,
  handleComposerStickerModePress as delegateHandleComposerStickerModePress, handleComposerGifPress as delegateHandleComposerGifPress, clearPendingAttachment as delegateClearPendingAttachment,
  removePendingPhoto as delegateRemovePendingPhoto, movePendingPhoto as delegateMovePendingPhoto
} from './ChatComposerActionBindings';
import {
  toCustomEmojiCellVO as delegateToCustomEmojiCellVO, fetchCustomEmojiFiles as delegateFetchCustomEmojiFiles, fetchCustomEmojiTabThumbs as delegateFetchCustomEmojiTabThumbs, loadCustomEmojiPanelIfNeeded as delegateLoadCustomEmojiPanelIfNeeded,
  handleCustomEmojiTabSelected as delegateHandleCustomEmojiTabSelected
} from './ChatCustomEmojiCatalogCoordinator';
import {
  emojiSearchLanguageCodes as delegateEmojiSearchLanguageCodes, resetEmojiSearchState as delegateResetEmojiSearchState, handleEmojiSearchQueryChange as delegateHandleEmojiSearchQueryChange, fetchEmojiSearchFiles as delegateFetchEmojiSearchFiles
} from './ChatEmojiSearchCoordinator';
import {
  toStickerCellVO as delegateToStickerCellVO, toGifCellVO as delegateToGifCellVO, fetchStickerPanelFiles as delegateFetchStickerPanelFiles, fetchStickerTabThumbs as delegateFetchStickerTabThumbs,
  loadStickerPanelIfNeeded as delegateLoadStickerPanelIfNeeded, loadFavoriteStickerTab as delegateLoadFavoriteStickerTab, loadPremiumStickerHomeIfNeeded as delegateLoadPremiumStickerHomeIfNeeded, loadStickerSetTabs as delegateLoadStickerSetTabs,
  handleStickerTabSelected as delegateHandleStickerTabSelected, loadGifPanel as delegateLoadGifPanel, handleStickerSelected as delegateHandleStickerSelected
} from './ChatStickerCatalogCoordinator';
import {
  resetStickerSearchState as delegateResetStickerSearchState, handleStickerSearchQueryChange as delegateHandleStickerSearchQueryChange, getStickerSearchUseCase as delegateGetStickerSearchUseCase, isStickerSearchPanelActive as delegateIsStickerSearchPanelActive,
  getStickerSearchLanguageCodes as delegateGetStickerSearchLanguageCodes, toStickerSearchCell as delegateToStickerSearchCell, setStickerSearchItems as delegateSetStickerSearchItems, setStickerSearchLoading as delegateSetStickerSearchLoading
} from './ChatStickerSearchBindings';
import {
  applyGroupedStickerPreviewPath as delegateApplyGroupedStickerPreviewPath, refreshGroupedStickerHomePreviews as delegateRefreshGroupedStickerHomePreviews, requestGroupedStickerHomePreviews as delegateRequestGroupedStickerHomePreviews
} from './ChatGroupedStickerPreviewCoordinator';
import {
  resetGifSearchState as delegateResetGifSearchState, handleGifSearchQueryChange as delegateHandleGifSearchQueryChange, loadMoreGifSearch as delegateLoadMoreGifSearch, fetchGifSearchFiles as delegateFetchGifSearchFiles
} from './ChatGifSearchCoordinator';
import {
  normalizedDraftCustomEmojiEntities as delegateNormalizedDraftCustomEmojiEntities, persistDraft as delegatePersistDraft, restoreDraftFromChat as delegateRestoreDraftFromChat, scheduleDraftDebounce as delegateScheduleDraftDebounce
} from './ChatDraftCoordinator';
import {
  openProfile as delegateOpenProfile, handleBackPress as delegateHandleBackPress, bindNavigationStack as delegateBindNavigationStack
} from './ChatPageNavigationCoordinator';
import {
  scheduleHistoryLoad as delegateScheduleHistoryLoad, shouldRetryHistoryLoad as delegateShouldRetryHistoryLoad, shouldShowHistoryLoadingPlaceholder as delegateShouldShowHistoryLoadingPlaceholder, requestHistoryWithRetry as delegateRequestHistoryWithRetry,
  captureInitialHistorySnapshot as delegateCaptureInitialHistorySnapshot, buildInitialHistoryParams as delegateBuildInitialHistoryParams
} from './ChatInitialHistoryCoordinator';
import {
  handleTimelineScrollIndex as delegateHandleTimelineScrollIndex, handleComposerTextChange as delegateHandleComposerTextChange, handleComposerAreaChange as delegateHandleComposerAreaChange, handleGalleryIndexChange as delegateHandleGalleryIndexChange,
  handleNavReady as delegateHandleNavReady, handleNavShown as delegateHandleNavShown, handleNavBackPressed as delegateHandleNavBackPressed
} from './ChatScreenViewEventHandlers';

const PROGRAMMATIC_SCROLL_GUARD_MS = 320;

// Owns one context and delegates each operation to its cohesive feature module.
export class ChatScreenSession extends ChatScreenContext implements ChatScreenSessionPorts {
  constructor(
    view: ChatScreenViewState,
    uiContextCallback: () => UIContext,
    queryNavigationInfoCallback: () => uiObserver.NavigationInfo | undefined
  ) {
    super(view, uiContextCallback, queryNavigationInfoCallback);
  }

  getActiveChatId(): number { return delegateGetActiveChatId(this); }
  getLifecycleToken(): number { return delegateGetLifecycleToken(this); }
  getChatUIContext(): UIContext { return delegateGetChatUIContext(this); }
  getSendUseCase(): SendMessageUseCase | undefined { return delegateGetSendUseCase(this); }
  getSendMediaUseCase(mediaKind: string = ''): SendMediaMessageUseCase | undefined { return delegateGetSendMediaUseCase(this, mediaKind); }
  setVoiceRecordingState(state: TgVoiceRecordingState, durationMs: number): void { delegateSetVoiceRecordingState(this, state, durationMs); }
  isSendingMessage(): boolean { return delegateIsSendingMessage(this); }
  setSendingMessage(value: boolean): void { delegateSetSendingMessage(this, value); }
  getSendOperationToken(): number { return delegateGetSendOperationToken(this); }
  hasActiveChatState(): boolean { return delegateHasActiveChatState(this); }
  isEditModeActive(): boolean { return delegateIsEditModeActive(this); }
  isForwardModeActive(): boolean { return delegateIsForwardModeActive(this); }
  submitEditMessage(text: string): void { delegateSubmitEditMessage(this, text); }
  submitForwardMessages(commentText: string): void { delegateSubmitForwardMessages(this, commentText); }
  getComposerInputRevision(): number { return delegateGetComposerInputRevision(this); }
  getDraftText(): string { return delegateGetDraftText(this); }
  setDraftText(value: string): void { delegateSetDraftText(this, value); }
  getDraftSelectionStart(): number { return delegateGetDraftSelectionStart(this); }
  getDraftSelectionEnd(): number { return delegateGetDraftSelectionEnd(this); }
  setDraftSelection(start: number, end: number): void { delegateSetDraftSelection(this, start, end); }
  getCustomEmojiEntities(): CustomEmojiTextEntity[] { return delegateGetCustomEmojiEntities(this); }
  setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void { delegateSetCustomEmojiEntities(this, value); }
  setEmojiPanelVisible(value: boolean): void { delegateSetEmojiPanelVisible(this, value); }
  getEmojiPanelVisible(): boolean { return delegateGetEmojiPanelVisible(this); }
  getReplyToMessageId(): string { return delegateGetReplyToMessageId(this); }
  setReplyMode(messageId: string, author: string, preview: string, isQuote: boolean): void { delegateSetReplyMode(this, messageId, author, preview, isQuote); }
  clearReplyMode(): void { delegateClearReplyMode(this); }
  getPendingAttachmentUris(): string[] { return delegateGetPendingAttachmentUris(this); }
  getPendingAttachmentKind(): string { return delegateGetPendingAttachmentKind(this); }
  setPendingAttachmentState(kind: string, title: string, preview: string, uris: string[]): void { delegateSetPendingAttachmentState(this, kind, title, preview, uris); }
  clearPendingAttachmentState(): void { delegateClearPendingAttachmentState(this); }
  getEditUseCase(): EditMessageUseCase | undefined { return delegateGetEditUseCase(this); }
  getDeleteUseCase(): DeleteMessagesUseCase | undefined { return delegateGetDeleteUseCase(this); }
  getSourceForwardUseCase(): ForwardMessagesUseCase | undefined { return delegateGetSourceForwardUseCase(this); }
  getForwardUseCase(sourceChatId: number = this.forwardSourceChatId, messageIds: string[] = this.forwardingMessageIds): ForwardMessagesUseCase | undefined { return delegateGetForwardUseCase(this, sourceChatId, messageIds); }
  getPinUseCase(): PinChatMessageUseCase | undefined { return delegateGetPinUseCase(this); }
  onPinnedMessageChanged(): void { delegateOnPinnedMessageChanged(this); }
  setEditMode(messageId: string, originalText: string, allowEmptyEdit: boolean = false): void { delegateSetEditMode(this, messageId, originalText, allowEmptyEdit); }
  getEditingMessageId(): string { return delegateGetEditingMessageId(this); }
  getEditingOriginalText(): string { return delegateGetEditingOriginalText(this); }
  rebaseEditingMessage(messageId: string, text: string): void { delegateRebaseEditingMessage(this, messageId, text); }
  clearEditMode(clearDraft: boolean): void { delegateClearEditMode(this, clearDraft); }
  setForwardMode(messageIds: string[], sourceChatId: number, title: string, preview: string): void { delegateSetForwardMode(this, messageIds, sourceChatId, title, preview); }
  getForwardModeState(): ChatForwardModeState { return delegateGetForwardModeState(this); }
  clearForwardMode(): void { delegateClearForwardMode(this); }
  refreshChatInputPanel(): void { delegateRefreshChatInputPanel(this); }
  canUseComposer(isEditing: boolean, sendKind: string = ''): boolean { return delegateCanUseComposer(this, isEditing, sendKind); }
  canSendNewMessages(sendKind: string = ''): boolean { return delegateCanSendNewMessages(this, sendKind); }
  composerCanSubmit(): boolean { return delegateComposerCanSubmit(this); }
  composerAllows(kind: string): boolean { return delegateComposerAllows(this, kind); }
  deriveChatBottomBar(chat: Chat, state: AppState): void { delegateDeriveChatBottomBar(this, chat, state); }
  bottomBarActionLabel(): string { return delegateBottomBarActionLabel(this); }
  retryChatAccess(): void { delegateRetryChatAccess(this); }
  bottomBarMessage(): string { return delegateBottomBarMessage(this); }
  handleChatBottomBarAction(): void { delegateHandleChatBottomBarAction(this); }
  scrollToMessageId(messageId: string): boolean { return delegateScrollToMessageId(this, messageId); }
  jumpToMessageId(messageId: string): void { delegateJumpToMessageId(this, messageId); }
  fulfillPendingJump(): void { delegateFulfillPendingJump(this); }
  normalizeSharedMediaLink(value: string): string { return delegateNormalizeSharedMediaLink(this, value); }
  resolveEntityLink(text: string, entities: TextEntity[]): string { return delegateResolveEntityLink(this, text, entities); }
  openSharedMediaLink(value: string): boolean { return delegateOpenSharedMediaLink(this, value); }
  executeSharedMediaAction(action: PendingSharedMediaAction): boolean { return delegateExecuteSharedMediaAction(this, action); }
  fulfillPendingSharedMediaAction(): void { delegateFulfillPendingSharedMediaAction(this); }
  beginSharedMediaAction(action: PendingSharedMediaAction): void { delegateBeginSharedMediaAction(this, action); }
  getSearchUseCase(): SearchChatMessagesUseCase | undefined { return delegateGetSearchUseCase(this); }
  isSearchModeActive(): boolean { return delegateIsSearchModeActive(this); }
  getSearchQuery(): string { return delegateGetSearchQuery(this); }
  setSearchQuery(value: string): void { delegateSetSearchQuery(this, value); }
  setSearchModeActive(value: boolean): void { delegateSetSearchModeActive(this, value); }
  onSearchResultsUpdated(position: number, total: number, loadedCount: number): void { delegateOnSearchResultsUpdated(this, position, total, loadedCount); }
  onSearchLoadingChanged(value: boolean): void { delegateOnSearchLoadingChanged(this, value); }
  onSearchErrorChanged(value: boolean): void { delegateOnSearchErrorChanged(this, value); }
  flashSearchHit(messageId: string, index: number): void { delegateFlashSearchHit(this, messageId, index); }
  clearSearchFlash(): void { delegateClearSearchFlash(this); }
  handleSearchQueryChange(query: string): void { delegateHandleSearchQueryChange(this, query); }
  openSearch(): void { delegateOpenSearch(this); }
  closeSearch(): void { delegateCloseSearch(this); }
  useSearchFlashOutline(entry: ChatTimelineEntryVO): boolean { return delegateUseSearchFlashOutline(this, entry); }
  aboutToAppear(): void { delegateAboutToAppear(this); }
  activateChatRoute(): void { delegateActivateChatRoute(this); }
  shouldReactToStoreChange(newState: AppState, prevState: AppState): boolean { return delegateShouldReactToStoreChange(this, newState, prevState); }
  scheduleLifecycleTask(delayMs: number, task: () => void): void { delegateScheduleLifecycleTask(this, delayMs, task); }
  isRouteContextCurrent(route: ChatScreenRouteParams): boolean { return delegateIsRouteContextCurrent(this, route); }
  bindChatRoute(params: ChatScreenRouteParams | undefined): void { delegateBindChatRoute(this, params); }
  syncOwnedChatContext(): void { delegateSyncOwnedChatContext(this); }
  ownsNavigationContext(): boolean { return delegateOwnsNavigationContext(this); }
  clearOwnedChatContext(): void { delegateClearOwnedChatContext(this); }
  resolveOwnedChatTitle(): string { return delegateResolveOwnedChatTitle(this); }
  showOwnedChatRoute(): boolean { return delegateShowOwnedChatRoute(this); }
  createChatRouteParams(chatId: number, chatTitle: string): ChatScreenRouteParams | undefined { return delegateCreateChatRouteParams(this, chatId, chatTitle); }
  getChatRouteToken(): number { return delegateGetChatRouteToken(this); }
  startOwnedChatData(route: ChatScreenRouteParams): void { delegateStartOwnedChatData(this, route); }
  showChatOpenFailure(): void { delegateShowChatOpenFailure(this); }
  aboutToDisappear(): void { delegateAboutToDisappear(this); }
  clearTransientTimers(): void { delegateClearTransientTimers(this); }
  scrollToBottomSoon(): void { delegateScrollToBottomSoon(this); }
  scrollTimelineToBottomAligned(): void { delegateScrollTimelineToBottomAligned(this); }
  shouldKeepTimelineBottomAligned(): boolean { return delegateShouldKeepTimelineBottomAligned(this); }
  scheduleComposerBottomAlignment(): void { delegateScheduleComposerBottomAlignment(this); }
  handleComposerFocusChange(focused: boolean): void { delegateHandleComposerFocusChange(this, focused); }
  handleComposerWillFocus(): void { delegateHandleComposerWillFocus(this); }
  handleChatViewportAreaChange(newArea: Area): void { delegateHandleChatViewportAreaChange(this, newArea); }
  chatTopInset(): number { return delegateChatTopInset(this); }
  shouldShowPinnedMessagePanel(): boolean { return delegateShouldShowPinnedMessagePanel(this); }
  chatContentStartOffset(): number { return delegateChatContentStartOffset(this); }
  computeSafeInsets(): void { delegateComputeSafeInsets(this); }
  bindWindowSizeListener(): void { delegateBindWindowSizeListener(this); }
  updateTimelineContainerWidth(windowWidthPx: number): void { delegateUpdateTimelineContainerWidth(this, windowWidthPx); }
  resetPinnedMessageState(): void { delegateResetPinnedMessageState(this); }
  applyPinnedMessageInfo(info: PinnedMessageInfo, index: number, totalCount: number): void { delegateApplyPinnedMessageInfo(this, info, index, totalCount); }
  loadSinglePinnedMessageFallback(chatId: number, lifecycleToken: number, requestId: number): void { delegateLoadSinglePinnedMessageFallback(this, chatId, lifecycleToken, requestId); }
  loadPinnedMessage(): void { delegateLoadPinnedMessage(this); }
  handlePinnedMessagePress(): void { delegateHandlePinnedMessagePress(this); }
  handlePinnedMessageClose(): void { delegateHandlePinnedMessageClose(this); }
  pinnedMessageTitle(index: number, totalCount: number): string { return delegatePinnedMessageTitle(this, index, totalCount); }
  pinnedMessageListItems(): TgPinnedMessageListItem[] { return delegatePinnedMessageListItems(this); }
  setPinnedMessagesListVisible(visible: boolean): void { delegateSetPinnedMessagesListVisible(this, visible); }
  handlePinnedMessageListPress(): void { delegateHandlePinnedMessageListPress(this); }
  handlePinnedListItemPress(index: number): void { delegateHandlePinnedListItemPress(this, index); }
  loadMorePinnedMessages(): void { delegateLoadMorePinnedMessages(this); }
  resetPlaybackState(preserveListened: boolean = false): void { delegateResetPlaybackState(this, preserveListened); }
  setupMediaPlaybackController(): void { delegateSetupMediaPlaybackController(this); }
  getCurrentMediaPlaybackHandle(): MediaPlaybackPageHandle | undefined { return delegateGetCurrentMediaPlaybackHandle(this); }
  notifyPlaybackRows(prevVoiceId: string, prevAudioId: string, currentId: string): void { delegateNotifyPlaybackRows(this, prevVoiceId, prevAudioId, currentId); }
  teardownMediaPlaybackController(preserveListened: boolean = false): void { delegateTeardownMediaPlaybackController(this, preserveListened); }
  publishNowPlayingMeta(messageId: string, contentType: MediaContentType): void { delegatePublishNowPlayingMeta(this, messageId, contentType); }
  handlePlaybackCompleted(messageId: string, contentType: MediaContentType): void { delegateHandlePlaybackCompleted(this, messageId, contentType); }
  applyChatAvatarPresentation(value: ChatAvatarPresentation): void { delegateApplyChatAvatarPresentation(this, value); }
  applyChatSubtitlePresentation(value: ChatSubtitlePresentation): void { delegateApplyChatSubtitlePresentation(this, value); }
  updateChatTopBarData(state: AppState): void { delegateUpdateChatTopBarData(this, state); }
  resetBotMenuState(): void { delegateResetBotMenuState(this); }
  refreshBotMenuState(state: AppState): void { delegateRefreshBotMenuState(this, state); }
  handleBotMenuPress(): void { delegateHandleBotMenuPress(this); }
  botMenuCommandNames(): string[] { return delegateBotMenuCommandNames(this); }
  botMenuCommandDescriptions(): string[] { return delegateBotMenuCommandDescriptions(this); }
  handleBotMenuOpenChange(isOpen: boolean): void { delegateHandleBotMenuOpenChange(this, isOpen); }
  handleBotMenuCommandPress(index: number): void { delegateHandleBotMenuCommandPress(this, index); }
  rebuildTimeline(state: AppState): void { delegateRebuildTimeline(this, state); }
  effectiveVoiceListened(entry: ChatTimelineEntryVO): boolean { return delegateEffectiveVoiceListened(this, entry); }
  isActiveVoiceEntry(entry: ChatTimelineEntryVO): boolean { return delegateIsActiveVoiceEntry(this, entry); }
  isActiveAudioEntry(entry: ChatTimelineEntryVO): boolean { return delegateIsActiveAudioEntry(this, entry); }
  scheduleMissingReplyHydration(state: AppState): void { delegateScheduleMissingReplyHydration(this, state); }
  async runMissingReplyHydration( useCase: LoadRepliedMessageUseCase, requests: ReplyHydrationRequest[], lifecycleToken: number, chatId: number ): Promise<void> { return delegateRunMissingReplyHydration(this, useCase, requests, lifecycleToken, chatId); }
  refreshRestoredReplySnippet(state: AppState): void { delegateRefreshRestoredReplySnippet(this, state); }
  refreshScrollToBottomVisibility(endIndex: number): void { delegateRefreshScrollToBottomVisibility(this, endIndex); }
  handleScrollToBottomPress(): void { delegateHandleScrollToBottomPress(this); }
  computeInitialIndex(totalCount: number): void { delegateComputeInitialIndex(this, totalCount); }
  guardProgrammaticScroll(durationMs: number = PROGRAMMATIC_SCROLL_GUARD_MS): void { delegateGuardProgrammaticScroll(this, durationMs); }
  resetPaginationState(): void { delegateResetPaginationState(this); }
  isNearTopPaginationEdge(start: number): boolean { return delegateIsNearTopPaginationEdge(this, start); }
  isNearBottomPaginationEdge(end: number, totalCount: number): boolean { return delegateIsNearBottomPaginationEdge(this, end, totalCount); }
  armAutoPaginationUnlock(targetIndex: number, reason: string): void { delegateArmAutoPaginationUnlock(this, targetIndex, reason); }
  maybeUnlockAutoPagination(scrollOffset: number, scrollState: ScrollState): void { delegateMaybeUnlockAutoPagination(this, scrollOffset, scrollState); }
  handleTimelineTouch(event: TouchEvent): void { delegateHandleTimelineTouch(this, event); }
  shouldSuppressLoadOlder(): boolean { return delegateShouldSuppressLoadOlder(this); }
  schedulePaginationRecheck(delayMs: number = 0): void { delegateSchedulePaginationRecheck(this, delayMs); }
  saveScrollPosition(): void { delegateSaveScrollPosition(this); }
  restoreScrollPosition(): void { delegateRestoreScrollPosition(this); }
  isNearBottom(): boolean { return delegateIsNearBottom(this); }
  loadOlderMessages(): void { delegateLoadOlderMessages(this); }
  recheckPaginationEdge(): void { delegateRecheckPaginationEdge(this); }
  loadNewerMessages(): void { delegateLoadNewerMessages(this); }
  maybeMarkChatRead(state: AppState): void { delegateMaybeMarkChatRead(this, state); }
  notifyMediaDownloadStateChanged(fileId: number): void { delegateNotifyMediaDownloadStateChanged(this, fileId); }
  requestMediaDownload(fileId: number, messageId: string = ''): void { delegateRequestMediaDownload(this, fileId, messageId); }
  cancelMediaDownload(fileId: number, messageId: string = ''): void { delegateCancelMediaDownload(this, fileId, messageId); }
  clearPendingMediaDownloads(): void { delegateClearPendingMediaDownloads(this); }
  isMediaDownloadPending(fileId: number): boolean { return delegateIsMediaDownloadPending(this, fileId); }
  isMediaDownloadFailed(fileId: number): boolean { return delegateIsMediaDownloadFailed(this, fileId); }
  effectiveAlbumPhotoDownloading(entry: ChatTimelineEntryVO): boolean[] { return delegateEffectiveAlbumPhotoDownloading(this, entry); }
  effectiveAlbumPhotoDownloadFailed(entry: ChatTimelineEntryVO): boolean[] { return delegateEffectiveAlbumPhotoDownloadFailed(this, entry); }
  syncResolvedPendingDownloads(entries: ChatTimelineEntryVO[]): void { delegateSyncResolvedPendingDownloads(this, entries); }
  rememberPendingMediaOpenIntent(kind: PendingMediaOpenKind, fileId: number, messageId: string, mimeType: string = ''): void { delegateRememberPendingMediaOpenIntent(this, kind, fileId, messageId, mimeType); }
  clearPendingMediaOpenIntent(fileId: number): void { delegateClearPendingMediaOpenIntent(this, fileId); }
  fulfillPendingMediaOpenIntent(entries: ChatTimelineEntryVO[]): void { delegateFulfillPendingMediaOpenIntent(this, entries); }
  handleVoiceTap(messageId: string, voicePath: string, voiceFileId: number): void { delegateHandleVoiceTap(this, messageId, voicePath, voiceFileId); }
  openAudioFile(audioPath: string, mimeType: string): void { delegateOpenAudioFile(this, audioPath, mimeType); }
  openDocumentFile(documentPath: string, mimeType: string): void { delegateOpenDocumentFile(this, documentPath, mimeType); }
  handleDocumentTap(documentPath: string, documentFileId: number, mimeType: string, messageId: string = '0'): void { delegateHandleDocumentTap(this, documentPath, documentFileId, mimeType, messageId); }
  handleAudioTap(audioPath: string, audioFileId: number, mimeType: string, messageId: string = '0'): void { delegateHandleAudioTap(this, audioPath, audioFileId, mimeType, messageId); }
  handleAudioSeek(messageId: string, progress: number): void { delegateHandleAudioSeek(this, messageId, progress); }
  handleVoiceSeek(messageId: string, progress: number): void { delegateHandleVoiceSeek(this, messageId, progress); }
  buildMediaGalleryItems(): MediaGalleryItem[] { return delegateBuildMediaGalleryItems(this); }
  handleMediaGalleryOpen(messageId: string): void { delegateHandleMediaGalleryOpen(this, messageId); }
  animateMediaGalleryState(isVisible: boolean, sourceMessageId: string = '0'): void { delegateAnimateMediaGalleryState(this, isVisible, sourceMessageId); }
  refreshOpenMediaGalleryItems(): void { delegateRefreshOpenMediaGalleryItems(this); }
  startReply(messageId: string, author: string, preview: string, isQuote: boolean = false): void { delegateStartReply(this, messageId, author, preview, isQuote); }
  cancelReply(): void { delegateCancelReply(this); }
  applyPendingForwardTransferIfNeeded(): void { delegateApplyPendingForwardTransferIfNeeded(this); }
  startForwardMessages(messageIds: string[], author: string, preview: string, fromChatId: number): void { delegateStartForwardMessages(this, messageIds, author, preview, fromChatId); }
  cancelForwardMessages(): void { delegateCancelForwardMessages(this); }
  openForwardTargetPicker(messageIds: string[], author: string, preview: string): void { delegateOpenForwardTargetPicker(this, messageIds, author, preview); }
  copyMessageText(text: string): void { delegateCopyMessageText(this, text); }
  showMessageActions(entry: ChatTimelineEntryVO): void { delegateShowMessageActions(this, entry); }
  messageActionsPopupStateHandler(messageId: string): (event: PopupStateChangeParam) => void { return delegateMessageActionsPopupStateHandler(this, messageId); }
  closeMessageActions(): void { delegateCloseMessageActions(this); }
  refreshForwardActionAvailability(): void { delegateRefreshForwardActionAvailability(this); }
  messageActionItems(): ChatMessageActionItem[] { return delegateMessageActionItems(this); }
  messageActionsPopupWidth(): number { return delegateMessageActionsPopupWidth(this); }
  messageActionsPopupHeight(): number { return delegateMessageActionsPopupHeight(this); }
  handleMessageActionPress(item: ChatMessageActionItem): void { delegateHandleMessageActionPress(this, item); }
  startEditMessage(messageId: string, originalText: string): void { delegateStartEditMessage(this, messageId, originalText); }
  cancelEditMessage(): void { delegateCancelEditMessage(this); }
  handleEditMessage(newText: string): void { delegateHandleEditMessage(this, newText); }
  handleForwardMessages(commentText: string): void { delegateHandleForwardMessages(this, commentText); }
  handlePinMessage(messageId: string): void { delegateHandlePinMessage(this, messageId); }
  handleDeleteMessage(messageId: string): void { delegateHandleDeleteMessage(this, messageId); }
  setStickerPanelVisible(value: boolean): void { delegateSetStickerPanelVisible(this, value); }
  openStickerSettings(): void { delegateOpenStickerSettings(this); }
  handleSendMessage(text: string): void { delegateHandleSendMessage(this, text); }
  handleComposerAttachPress(): void { delegateHandleComposerAttachPress(this); }
  handleAttachmentMenuOpenChange(isOpen: boolean): void { delegateHandleAttachmentMenuOpenChange(this, isOpen); }
  composerKeyboardPanelVisible(): boolean { return delegateComposerKeyboardPanelVisible(this); }
  composerAttachmentMenuLabels(): string[] { return delegateComposerAttachmentMenuLabels(this); }
  handleComposerAttachmentMenuItemPress(index: number): void { delegateHandleComposerAttachmentMenuItemPress(this, index); }
  handleAttachmentRecentPress(item: TgAttachmentRecentItem): void { delegateHandleAttachmentRecentPress(this, item); }
  handleComposerEmojiPress(): void { delegateHandleComposerEmojiPress(this); }
  handleComposerKeyboardModePress(): void { delegateHandleComposerKeyboardModePress(this); }
  handleComposerVoicePress(): void { delegateHandleComposerVoicePress(this); }
  handleVoiceRecordStart(): void { delegateHandleVoiceRecordStart(this); }
  handleVoiceRecordSend(): void { delegateHandleVoiceRecordSend(this); }
  handleVoiceRecordCancel(): void { delegateHandleVoiceRecordCancel(this); }
  handleVoiceRecordLock(): void { delegateHandleVoiceRecordLock(this); }
  handleComposerEmojiSelected(emoji: string): void { delegateHandleComposerEmojiSelected(this, emoji); }
  handleComposerSelectionChange(start: number, end: number): void { delegateHandleComposerSelectionChange(this, start, end); }
  handleCustomEmojiSelected(item: CustomEmojiCellVO): void { delegateHandleCustomEmojiSelected(this, item); }
  handleComposerStickerPress(): void { delegateHandleComposerStickerPress(this); }
  handleComposerStickerModePress(): void { delegateHandleComposerStickerModePress(this); }
  handleComposerGifPress(): void { delegateHandleComposerGifPress(this); }
  clearPendingAttachment(): void { delegateClearPendingAttachment(this); }
  removePendingPhoto(uri: string): void { delegateRemovePendingPhoto(this, uri); }
  movePendingPhoto(uri: string, direction: number): void { delegateMovePendingPhoto(this, uri, direction); }
  toCustomEmojiCellVO(entry: StickerPanelEntry): CustomEmojiCellVO | undefined { return delegateToCustomEmojiCellVO(this, entry); }
  async fetchCustomEmojiFiles(cells: CustomEmojiCellVO[], tabId: string): Promise<void> { return delegateFetchCustomEmojiFiles(this, cells, tabId); }
  async fetchCustomEmojiTabThumbs(tabs: CustomEmojiPackTabVO[]): Promise<void> { return delegateFetchCustomEmojiTabThumbs(this, tabs); }
  loadCustomEmojiPanelIfNeeded(): void { delegateLoadCustomEmojiPanelIfNeeded(this); }
  handleCustomEmojiTabSelected(tabId: string): void { delegateHandleCustomEmojiTabSelected(this, tabId); }
  emojiSearchLanguageCodes(): string[] { return delegateEmojiSearchLanguageCodes(this); }
  resetEmojiSearchState(): void { delegateResetEmojiSearchState(this); }
  handleEmojiSearchQueryChange(query: string): void { delegateHandleEmojiSearchQueryChange(this, query); }
  async fetchEmojiSearchFiles(cells: CustomEmojiCellVO[], requestId: number): Promise<void> { return delegateFetchEmojiSearchFiles(this, cells, requestId); }
  toStickerCellVO(entry: StickerPanelEntry): StickerCellVO { return delegateToStickerCellVO(this, entry); }
  toGifCellVO(entry: GifPanelEntry): StickerCellVO { return delegateToGifCellVO(this, entry); }
  async fetchStickerPanelFiles(cells: StickerCellVO[], tabId: string): Promise<void> { return delegateFetchStickerPanelFiles(this, cells, tabId); }
  async fetchStickerTabThumbs(tabs: StickerSetTabVO[]): Promise<void> { return delegateFetchStickerTabThumbs(this, tabs); }
  loadStickerPanelIfNeeded(): void { delegateLoadStickerPanelIfNeeded(this); }
  loadFavoriteStickerTab(): void { delegateLoadFavoriteStickerTab(this); }
  loadPremiumStickerHomeIfNeeded(): void { delegateLoadPremiumStickerHomeIfNeeded(this); }
  loadStickerSetTabs(includeFavorites: boolean): void { delegateLoadStickerSetTabs(this, includeFavorites); }
  handleStickerTabSelected(tabId: string): void { delegateHandleStickerTabSelected(this, tabId); }
  loadGifPanel(): void { delegateLoadGifPanel(this); }
  handleStickerSelected(cell: StickerCellVO): void { delegateHandleStickerSelected(this, cell); }
  resetStickerSearchState(): void { delegateResetStickerSearchState(this); }
  handleStickerSearchQueryChange(query: string): void { delegateHandleStickerSearchQueryChange(this, query); }
  getStickerSearchUseCase(): StickerPanelUseCase | undefined { return delegateGetStickerSearchUseCase(this); }
  isStickerSearchPanelActive(): boolean { return delegateIsStickerSearchPanelActive(this); }
  getStickerSearchLanguageCodes(): string[] { return delegateGetStickerSearchLanguageCodes(this); }
  toStickerSearchCell(entry: StickerPanelEntry): StickerCellVO { return delegateToStickerSearchCell(this, entry); }
  setStickerSearchItems(items: StickerCellVO[]): void { delegateSetStickerSearchItems(this, items); }
  setStickerSearchLoading(value: boolean): void { delegateSetStickerSearchLoading(this, value); }
  applyGroupedStickerPreviewPath(cell: StickerCellVO, fileId: number, path: string): void { delegateApplyGroupedStickerPreviewPath(this, cell, fileId, path); }
  refreshGroupedStickerHomePreviews(state: AppState): void { delegateRefreshGroupedStickerHomePreviews(this, state); }
  requestGroupedStickerHomePreviews(cells: StickerCellVO[], visibleLimit: number): void { delegateRequestGroupedStickerHomePreviews(this, cells, visibleLimit); }
  resetGifSearchState(): void { delegateResetGifSearchState(this); }
  handleGifSearchQueryChange(query: string): void { delegateHandleGifSearchQueryChange(this, query); }
  loadMoreGifSearch(): void { delegateLoadMoreGifSearch(this); }
  async fetchGifSearchFiles(cells: StickerCellVO[], requestId: number): Promise<void> { return delegateFetchGifSearchFiles(this, cells, requestId); }
  normalizedDraftCustomEmojiEntities(text: string): CustomEmojiTextEntity[] { return delegateNormalizedDraftCustomEmojiEntities(this, text); }
  persistDraft(chatId: number): void { delegatePersistDraft(this, chatId); }
  restoreDraftFromChat(): void { delegateRestoreDraftFromChat(this); }
  scheduleDraftDebounce(): void { delegateScheduleDraftDebounce(this); }
  openProfile(): void { delegateOpenProfile(this); }
  handleBackPress(): void { delegateHandleBackPress(this); }
  bindNavigationStack(): NavPathStack | undefined { return delegateBindNavigationStack(this); }
  scheduleHistoryLoad(chatId: number, attempt: number): void { delegateScheduleHistoryLoad(this, chatId, attempt); }
  shouldRetryHistoryLoad(chatId: number): boolean { return delegateShouldRetryHistoryLoad(this, chatId); }
  shouldShowHistoryLoadingPlaceholder(): boolean { return delegateShouldShowHistoryLoadingPlaceholder(this); }
  requestHistoryWithRetry(chatId: number, attempt: number): void { delegateRequestHistoryWithRetry(this, chatId, attempt); }
  captureInitialHistorySnapshot(state: AppState, scheduleCorrection: boolean = true): void { delegateCaptureInitialHistorySnapshot(this, state, scheduleCorrection); }
  buildInitialHistoryParams(chatId: number, state?: AppState): LoadChatHistoryParams { return delegateBuildInitialHistoryParams(this, chatId, state); }
  handleTimelineScrollIndex(start: number, end: number): void { delegateHandleTimelineScrollIndex(this, start, end); }
  handleComposerTextChange(value: string): void { delegateHandleComposerTextChange(this, value); }
  handleComposerAreaChange(height: number): void { delegateHandleComposerAreaChange(this, height); }
  handleGalleryIndexChange(index: number): void { delegateHandleGalleryIndexChange(this, index); }
  handleNavReady(context: NavDestinationContext): void { delegateHandleNavReady(this, context); }
  handleNavShown(): void { delegateHandleNavShown(this); }
  handleNavBackPressed(): boolean { return delegateHandleNavBackPressed(this); }
}
