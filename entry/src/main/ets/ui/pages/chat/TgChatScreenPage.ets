// TgChatScreenPage — chat message timeline
// Phase D-3: Stack overlay — message list scrolls under translucent top bar for blur

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { chatUIState, navigationUIState } from '../../../core/model/UIStateModels';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, Message, TextEntity } from '../../../core/model/AppState';
import { fileUri } from '@kit.CoreFileKit';
import { filePreview } from '@kit.PreviewKit';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgGlassPolicy } from '../../tg_ui/tokens/TgGlassPolicy';
import { composerPopupTransition } from '../../tg_ui/utils/TgComposerMotionPolicy';
import { TgDateSeparator, TgUnreadMarker } from '../../tg_ui/atoms/TgDateSeparator';
import { TgMessageRouter } from '../../tg_ui/molecules/TgMessageRouter';
import { TgComposerInput } from '../../tg_ui/atoms/TgComposerInput';
import { TgAttachmentRecentItem } from '../../tg_ui/atoms/TgAttachmentSheet';
import {
  TgComposerEmojiPanel,
  CustomEmojiCellVO,
  CustomEmojiPackTabVO
} from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { TgComposerStickerPanel, StickerCellVO, StickerSetTabVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { TgStickerSettingsSheet } from '../../tg_ui/atoms/TgStickerSettingsSheet';
import {
  TgChatTopBar,
  TgChatTopBarSubtitleMode,
  TgChatTopBarTrailingAction,
  TG_CHAT_SEARCH_INPUT_ID
} from '../../tg_ui/atoms/TgChatTopBar';
import { TgChatBackground } from '../../tg_ui/atoms/TgChatBackground';
import { TgPinnedMessagePanel } from '../../tg_ui/atoms/TgPinnedMessagePanel';
import {
  TgPinnedMessageList,
  TgPinnedMessageListItem
} from '../../tg_ui/atoms/TgPinnedMessageList';
import { TgScrollToBottomButton } from '../../tg_ui/atoms/TgScrollToBottomButton';
import { ProfileRouteParams } from '../profile/TgProfilePage';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import {
  ChatTimelineEntryVO,
  buildChatTimeline,
  resolveSenderName,
  resolveReplyPreview,
  timelineEntryContainsMessageId
} from './ChatTimelineVO';
import { MediaPlaybackController, MediaPlaybackSnapshot, MediaContentType } from './VoicePlaybackController';
import { ChatMediaDownloadController } from './ChatMediaDownloadController';
import {
  PendingMediaOpenIntent,
  PendingMediaOpenKind,
  PendingMediaOpenResolution,
  resolvePendingMediaOpenIntent
} from './PendingMediaOpenIntent';
import { resolveRefreshedMediaGalleryState } from './MediaGalleryState';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { ChatComposerController } from './ChatComposerController';
import {
  ChatVoiceRecordingController
} from './ChatVoiceRecordingController';
import { TgVoiceRecordingState } from '../../tg_ui/utils/TgVoiceRecordingPolicy';
import {
  customEmojiEntitiesEqual,
  normalizeCustomEmojiEntitiesForSubstring,
  reconcileCustomEmojiEntities
} from '../../tg_ui/utils/TgCustomEmojiDraftPolicy';
import {
  ChatForwardModeState,
  ChatMessageActionItem,
  ChatMessageActionsController
} from './ChatMessageActionsController';
import { ChatSearchController } from './ChatSearchController';
import { PendingJumpSignal } from './PendingJumpSignal';
import {
  PendingSharedMediaAction,
  PendingSharedMediaActionSignal
} from './PendingSharedMediaActionSignal';
import { PendingChatSearchSignal } from './PendingChatSearchSignal';
import { ChatUnreadEntrySnapshot, PendingChatUnreadSnapshot } from './PendingChatUnreadSnapshot';
import { createSendMessageUseCase, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import {
  createStickerPanelUseCase,
  StickerPanelUseCase,
  StickerPanelEntry,
  StickerSetInfoEntry,
  GifPanelEntry,
  GifSearchPage,
  EmojiKeyboardSearchResult,
  SendStickerParams,
  SendAnimationParams
} from '../../../domain/usecases/stickerPanel';
import {
  SendMediaMessageUseCase,
  createSendMediaMessageUseCase
} from '../../../domain/usecases/sendMediaMessage';
import { createEditMessageUseCase, EditMessageUseCase } from '../../../domain/usecases/editMessage';
import { createDeleteMessagesUseCase, DeleteMessagesUseCase } from '../../../domain/usecases/deleteMessages';
import { ForwardMessagesUseCase, createForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { createOpenChatUseCase, OpenChatUseCase } from '../../../domain/usecases/openChat';
import { SearchChatMessagesUseCase, createSearchChatMessagesUseCase } from '../../../domain/usecases/searchChatMessages';
import { PinChatMessageUseCase, createPinChatMessageUseCase } from '../../../domain/usecases/pinChatMessage';
import {
  LoadChatHistoryUseCase,
  LoadChatHistoryParams,
  createLoadChatHistoryUseCase
} from '../../../domain/usecases/loadChatHistory';
import { createMarkChatReadUseCase, MarkChatReadUseCase } from '../../../domain/usecases/markChatRead';
import { BotMenuCommandEntry, BotMenuInfo, loadBotMenuInfo } from '../../../domain/usecases/loadBotMenu';
import {
  loadPinnedMessageInfo,
  loadPinnedMessagesPage,
  PinnedMessagesPage,
  PinnedMessageInfo
} from '../../../domain/usecases/loadPinnedMessage';
import {
  createLoadRepliedMessageUseCase,
  LoadRepliedMessageUseCase
} from '../../../domain/usecases/loadRepliedMessage';
import {
  ReplyHydrationCoordinator,
  ReplyHydrationRequest
} from './ReplyHydrationCoordinator';
import {
  createCloseChatCommand,
  createSetChatDraftCommand,
  CustomEmojiTextEntity
} from '../../../core/model/AppCommand';
import { TdObject } from '../../../models/TdTypes';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { localized } from '../../../core/utils/AppResource';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';
import { TgMediaGalleryPage } from '../../tg_ui/atoms/TgMediaGalleryPage';
import { albumMediaSourceId } from '../../tg_ui/utils/TgMediaGeometryTransition';
import { computeTopBarHeight, computeChatBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { curves, uiObserver, window } from '@kit.ArkUI';
import { common, Want, wantConstant } from '@kit.AbilityKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const EMOJI_SEARCH_DEBOUNCE_MS: number = 250;
const STICKER_SEARCH_DEBOUNCE_MS: number = 250;
const GIF_SEARCH_DEBOUNCE_MS: number = 250;
const CHAT_NAV_TRANSITION_LOCK_MS = 760;
const MAX_PARALLEL_REPLY_HYDRATION_REQUESTS: number = 4;
// Give OpenChatUseCase time to send openChat + getChatHistory first.
// TgChatScreenPage is the fallback loader — if OpenChatUseCase already loaded,
// requestHistoryWithRetry will see hasHistoryBeenFetched=true and skip.
const HISTORY_INITIAL_DELAY_MS = 600;
const HISTORY_MAX_RETRY_ATTEMPTS = 4;
const HISTORY_RETRY_BASE_DELAY_MS = 450;
const PROGRAMMATIC_SCROLL_GUARD_MS = 320;
// Android: 25 items when scrolling, 5 when idle. iOS: 5 items.
// Use 25 for scroll trigger (aggressive prefetch like Android).
const TIMELINE_TOP_EDGE_TRIGGER_INDEX = 25;
const TIMELINE_BOTTOM_EDGE_TRIGGER_GAP = 5;
const TIMELINE_TOUCH_UNLOCK_DISTANCE = 12;
const INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT = 1;
const COMPOSER_KEYBOARD_SETTLE_MS = 320;

declare function px2vp(value: number): number;

@ComponentV2
export struct TgChatScreenPage {
  @Local pageStack: NavPathStack = new NavPathStack();

  // Reactive state: local copy initialized from route/navigation context.
  @Local activeChatId: number = 0;
  @Local private activeChatTitle: string = '';
  @Local private activeChatIsChannel: boolean = false;
  @Local private routeChatId: number = 0;
  @Local private routeChatTitle: string = '';

  @Local private title: string = 'Chat';
  @Local private chatSubtitle: string = '';
  @Local private chatSubtitleMode: TgChatTopBarSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
  @Local private chatSubtitleSpinner: boolean = false;
  @Local private chatAvatarInitials: string = '';
  @Local private chatAvatarColorIndex: number = 0;
  @Local private chatAvatarImageSrc: string = '';
  @Local private chatIsOnline: boolean = false;
  @Local private chatTopBarTrailingAction: TgChatTopBarTrailingAction = TgChatTopBarTrailingAction.Search;
  @Local private pinnedMessageVisible: boolean = false;
  @Local private pinnedMessageId: string = '0';
  @Local private pinnedMessagePreview: string = '';
  @Local private pinnedMessageHasThumbnail: boolean = false;
  @Local private pinnedMessageThumbnailPath: string = '';
  @Local private pinnedMessageIndex: number = 0;
  @Local private pinnedMessageTotalCount: number = 1;
  @Local private pinnedMessages: PinnedMessageInfo[] = [];
  @Local private pinnedMessagesNextFromMessageId: string = '0';
  @Local private pinnedMessagesListVisible: boolean = false;
  @Local private pinnedMessagesListLoading: boolean = false;
  @Local private timelineContainerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private bottomOverlayInset: number = TgUiTokens.SPACE_8;
  @Local private composerTotalHeight: number = TgUiTokens.COMPOSER_MIN_CAPSULE_HEIGHT +
    TgUiTokens.COMPOSER_VERTICAL_INSET * 2 + TgUiTokens.SPACE_8;
  @Local private composerDraftText: string = '';
  @Local private composerSelectionStart: number = 0;
  @Local private composerSelectionEnd: number = 0;
  @Local private composerCaretRequestRevision: number = 0;
  @Local private showComposerEmojiPanel: boolean = false;
  @Local private showComposerStickerPanel: boolean = false;
  @Local private stickerSettingsOpen: boolean = false;
  @Local private attachmentRecentItems: TgAttachmentRecentItem[] = [];
  @Local private attachmentRecentLoading: boolean = false;
  @Local private stickerPanelItems: StickerCellVO[] = [];
  @Local private premiumStickerItems: StickerCellVO[] = [];
  @Local private favoriteStickerItems: StickerCellVO[] = [];
  @Local private stickerPanelLoading: boolean = false;
  @Local private stickerSearchItems: StickerCellVO[] = [];
  @Local private stickerSearchLoading: boolean = false;
  @Local private gifSearchItems: StickerCellVO[] = [];
  @Local private gifSearchLoading: boolean = false;
  @Local private gifSearchHasMore: boolean = false;
  @Local private gifSearchPageLoading: boolean = false;
  @Local private stickerSetTabs: StickerSetTabVO[] = [];
  @Local private activeStickerTabId: string = 'recent';
  @Local private customEmojiPanelItems: CustomEmojiCellVO[] = [];
  @Local private customEmojiPanelLoading: boolean = false;
  @Local private customEmojiPackTabs: CustomEmojiPackTabVO[] = [];
  @Local private activeCustomEmojiPackId: string = 'unicode';
  @Local private emojiSearchUnicodeResults: string[] = [];
  @Local private emojiSearchCustomItems: CustomEmojiCellVO[] = [];
  @Local private emojiSearchLoading: boolean = false;
  @Local private pendingAttachmentKind: string = '';
  @Local private pendingAttachmentTitle: string = '';
  @Local private pendingAttachmentPreview: string = '';
  @Local private pendingAttachmentUris: string[] = [];
  @Local private voiceRecordingState: TgVoiceRecordingState = 'idle';
  @Local private voiceRecordingDurationMs: number = 0;
  @Local private showBotMenu: boolean = false;
  @Local private botMenuOpen: boolean = false;
  @Local private botMenuTitle: string = '';
  private botMenuUrl: string = '';
  private botMenuCommands: BotMenuCommandEntry[] = [];
  private botMenuPeerUserId: number = 0;
  private botMenuLoadingUserId: number = 0;
  @Local private messageActionsOpenId: string = '';
  private messageActionsEntry: ChatTimelineEntryVO | undefined = undefined;
  @Local private awaitingInitialTimeline: boolean = false;
  @Local private prependScrollMask: boolean = false;
  @Local private listInitialIndex: number = 0;
  @Local private replyToMessageId: string = '0';
  @Local private replyToAuthor: string = '';
  @Local private replyToPreview: string = '';
  @Local private replyToIsQuote: boolean = false;
  @Local private isForwardingMessages: boolean = false;
  @Local private forwardingMessageIds: string[] = [];
  @Local private forwardSourceChatId: number = 0;
  @Local private forwardTitle: string = '';
  @Local private forwardPreview: string = '';
  // ── Media viewer state ──
  @Local private activeVoiceMessageId: string = '0';
  @Local private activeVoiceProgress: number = 0;
  @Local private activeVoicePlaying: boolean = false;
  @Local private activeAudioMessageId: string = '0';
  @Local private activeAudioProgress: number = 0;
  @Local private activeAudioPlaying: boolean = false;
  @Local private pendingMediaDownloadVersion: number = 0;
  @Local private showMediaGallery: boolean = false;
  @Local private galleryItems: MediaGalleryItem[] = [];
  @Local private galleryInitialIndex: number = 0;
  @Local private galleryCurrentIndex: number = 0;
  @Local private gallerySourceMessageId: string = '0';
  private dataSource: ChatTimelineDataSource = new ChatTimelineDataSource();
  private listScroller: Scroller = new Scroller();
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private rebuildTimerId: number = -1;
  private pageLifecycleToken: number = 0;
  private pinnedMessageRequestId: number = 0;
  private pinnedMessagesListRequestId: number = 0;
  private pinnedMessageDismissedId: string = '0';
  private isClosing: boolean = false;
  private transientTimerIds: Set<number> = new Set<number>();
  // Telegram persists the draft while typing (not only on exit) — debounced
  private draftDebounceTimerId: number = -1;
  private mainWindow?: window.Window;
  private sendUseCase?: SendMessageUseCase;
  private sendMediaUseCase?: SendMediaMessageUseCase;
  private editUseCase?: EditMessageUseCase;
  private deleteUseCase?: DeleteMessagesUseCase;
  private forwardUseCase?: ForwardMessagesUseCase;
  private openChatUseCase?: OpenChatUseCase;
  private searchUseCase?: SearchChatMessagesUseCase;
  private pinUseCase?: PinChatMessageUseCase;
  private stickerPanelUseCase?: StickerPanelUseCase;
  private stickerPanelLoadedOnce: boolean = false;
  private premiumStickerHomeLoaded: boolean = false;
  private premiumStickerHomeLoading: boolean = false;
  private favoriteStickerHomeLoaded: boolean = false;
  private favoriteStickerHomeLoading: boolean = false;
  private groupedStickerPreviewRequests: Set<number> = new Set<number>();
  private customEmojiPanelLoadedOnce: boolean = false;
  private attachmentRecentLoadToken: number = 0;
  private stickerSetCache: Map<string, StickerCellVO[]> = new Map<string, StickerCellVO[]>();
  private customEmojiSetCache: Map<string, CustomEmojiCellVO[]> = new Map<string, CustomEmojiCellVO[]>();
  private customEmojiDraftEntities: CustomEmojiTextEntity[] = [];
  private expectedProgrammaticCustomEmojiText: string = '';
  private emojiSearchQuery: string = '';
  private emojiSearchRequestId: number = 0;
  private emojiSearchDebounceTimerId: number = -1;
  private stickerSearchQuery: string = '';
  private stickerSearchRequestId: number = 0;
  private stickerSearchDebounceTimerId: number = -1;
  private gifSearchQuery: string = '';
  private gifSearchNextOffset: string = '';
  private gifSearchRequestId: number = 0;
  private gifSearchDebounceTimerId: number = -1;
  private loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  private loadRepliedMessageUseCase?: LoadRepliedMessageUseCase;
  private replyHydrationCoordinator: ReplyHydrationCoordinator = new ReplyHydrationCoordinator();
  private markChatReadUseCase?: MarkChatReadUseCase;
  private isSending: boolean = false;
  // Edit mode state
  @Local private isEditingMessage: boolean = false;
  @Local private editingMessageId: string = '0';
  @Local private editingOriginalText: string = '';
  // Search mode state
  @Local private isSearchMode: boolean = false;
  @Local private searchQuery: string = '';
  @Local private searchResultPos: number = 0;
  @Local private searchResultTotal: number = 0;
  @Local private searchResultLoaded: number = 0;
  @Local private searchLoading: boolean = false;
  @Local private searchError: boolean = false;
  private searchFlashTimerId: number = -1;
  private searchFlashMessageId: string = '';
  // Jump-to-message: target waiting for its history window to arrive
  private pendingJumpMessageId: string = '';
  private pendingJumpAttempts: number = 0;
  private pendingSharedMediaAction: PendingSharedMediaAction | undefined = undefined;
  @Local private showScrollToBottom: boolean = false;
  @Local private scrollToBottomUnreadCount: number = 0;
  private isLoadingOlder: boolean = false;
  private isLoadingNewer: boolean = false;
  private isMarkingChatRead: boolean = false;
  private historyFallbackTimerId: number = -1;
  private lastVisibleStartIndex: number = -1;
  private lastVisibleEndIndex: number = -1;
  private composerResizeKeepsBottomAligned: boolean = false;
  private chatViewportHeight: number = 0;
  private previousDataCount: number = 0;
  private needsScrollRestore: boolean = true;
  private currentScrollChatId: number = 0;
  private lastOpenedChatId: number = 0;
  private suppressLoadOlderUntil: number = 0;
  private unreadRestoreIndex: number = -1;
  private stickyLastReadMessageId: string = '';
  private hasRestoredUnreadBoundary: boolean = false;
  private lastMarkReadRequestKey: string = '';
  private blockAutoPaginationUntilUserScroll: boolean = false;
  private timelineTouchStartY: number = -1;
  private isApplyingTimelineDiff: boolean = false;
  private paginationRecheckTimerId: number = -1;
  private static scrollPositionCache: Map<number, string> = new Map<number, string>();
  private mediaPlaybackController?: MediaPlaybackController;
  private locallyListenedVoiceIds: Set<string> = new Set<string>();
  private mediaDownloadCtrl: ChatMediaDownloadController = new ChatMediaDownloadController();
  private pendingMediaOpenIntent: PendingMediaOpenIntent = new PendingMediaOpenIntent();
  private composerCtrl: ChatComposerController = new ChatComposerController();
  private voiceRecordingCtrl: ChatVoiceRecordingController = new ChatVoiceRecordingController();
  private messageActionsCtrl: ChatMessageActionsController = new ChatMessageActionsController();
  private searchCtrl: ChatSearchController = new ChatSearchController();

  getActiveChatId(): number {
    return this.activeChatId;
  }

  getLifecycleToken(): number {
    return this.pageLifecycleToken;
  }

  getChatUIContext(): UIContext {
    return this.getUIContext();
  }

  getSendUseCase(): SendMessageUseCase | undefined {
    return this.sendUseCase;
  }

  getSendMediaUseCase(): SendMediaMessageUseCase | undefined {
    return this.sendMediaUseCase;
  }

  setVoiceRecordingState(state: TgVoiceRecordingState, durationMs: number): void {
    this.voiceRecordingState = state;
    this.voiceRecordingDurationMs = durationMs;
  }

  getEditUseCase(): EditMessageUseCase | undefined {
    return this.editUseCase;
  }

  getDeleteUseCase(): DeleteMessagesUseCase | undefined {
    return this.deleteUseCase;
  }

  getForwardUseCase(): ForwardMessagesUseCase | undefined {
    return this.forwardUseCase;
  }

  getPinUseCase(): PinChatMessageUseCase | undefined {
    return this.pinUseCase;
  }

  onPinnedMessageChanged(): void {
    this.loadPinnedMessage();
  }

  getSearchUseCase(): SearchChatMessagesUseCase | undefined {
    return this.searchUseCase;
  }

  isSendingMessage(): boolean {
    return this.isSending;
  }

  setSendingMessage(value: boolean): void {
    this.isSending = value;
  }

  isEditModeActive(): boolean {
    return this.isEditingMessage;
  }

  isForwardModeActive(): boolean {
    return this.isForwardingMessages;
  }

  submitEditMessage(text: string): void {
    this.handleEditMessage(text);
  }

  submitForwardMessages(commentText: string): void {
    this.handleForwardMessages(commentText);
  }

  getDraftText(): string {
    return this.composerDraftText;
  }

  setDraftText(value: string): void {
    if (value.length === 0) {
      this.customEmojiDraftEntities = [];
    }
    if (this.customEmojiDraftEntities.length > 0) {
      this.expectedProgrammaticCustomEmojiText = value;
    } else {
      this.expectedProgrammaticCustomEmojiText = '';
    }
    this.composerDraftText = value;
  }

  getDraftSelectionStart(): number {
    return this.composerSelectionStart;
  }

  getDraftSelectionEnd(): number {
    return this.composerSelectionEnd;
  }

  setDraftSelection(start: number, end: number): void {
    this.composerSelectionStart = Math.max(0, Math.min(this.composerDraftText.length, start));
    this.composerSelectionEnd = Math.max(0, Math.min(this.composerDraftText.length, end));
    this.composerCaretRequestRevision++;
  }

  getCustomEmojiEntities(): CustomEmojiTextEntity[] {
    return this.customEmojiDraftEntities;
  }

  setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void {
    this.customEmojiDraftEntities = value.slice();
  }

  setEmojiPanelVisible(value: boolean): void {
    this.showComposerEmojiPanel = value;
    if (value) {
      this.setStickerPanelVisible(false);
      this.loadCustomEmojiPanelIfNeeded();
    } else {
      this.resetEmojiSearchState();
    }
  }

  getEmojiPanelVisible(): boolean {
    return this.showComposerEmojiPanel;
  }

  private setStickerPanelVisible(value: boolean): void {
    this.showComposerStickerPanel = value;
    if (!value) {
      this.resetStickerSearchState();
      this.resetGifSearchState();
    }
  }

  private openStickerSettings(): void {
    this.composerResizeKeepsBottomAligned = this.shouldKeepTimelineBottomAligned();
    this.loadStickerPanelIfNeeded();
    this.setEmojiPanelVisible(false);
    this.setStickerPanelVisible(false);
    this.stickerSettingsOpen = true;
  }

  getReplyToMessageId(): string {
    return this.replyToMessageId;
  }

  setReplyMode(messageId: string, author: string, preview: string, isQuote: boolean): void {
    this.replyToMessageId = messageId;
    this.replyToAuthor = author;
    this.replyToPreview = preview;
    this.replyToIsQuote = isQuote;
  }

  clearReplyMode(): void {
    this.replyToMessageId = '0';
    this.replyToAuthor = '';
    this.replyToPreview = '';
    this.replyToIsQuote = false;
  }

  getPendingAttachmentUris(): string[] {
    return this.pendingAttachmentUris;
  }

  getPendingAttachmentKind(): string {
    return this.pendingAttachmentKind;
  }

  setPendingAttachmentState(kind: string, title: string, preview: string, uris: string[]): void {
    this.pendingAttachmentKind = kind;
    this.pendingAttachmentTitle = title;
    this.pendingAttachmentPreview = preview;
    this.pendingAttachmentUris = uris;
  }

  clearPendingAttachmentState(): void {
    this.pendingAttachmentKind = '';
    this.pendingAttachmentTitle = '';
    this.pendingAttachmentPreview = '';
    this.pendingAttachmentUris = [];
  }

  scrollToBottomSoon(): void {
    this.scheduleLifecycleTask(100, () => {
      this.scrollTimelineToBottomAligned();
    });
  }

  private scrollTimelineToBottomAligned(): void {
    const lastIndex = this.dataSource.totalCount() - 1;
    if (lastIndex < 0) {
      return;
    }
    // The List viewport already ends above the composer. END keeps the last
    // bubble attached to that moving edge while the keyboard/input grows.
    this.listScroller.scrollToIndex(lastIndex, false, ScrollAlign.END);
  }

  private shouldKeepTimelineBottomAligned(): boolean {
    const total = this.dataSource.totalCount();
    if (total === 0 || this.lastVisibleEndIndex < 0) {
      return true;
    }
    return total - 1 - this.lastVisibleEndIndex <= 3;
  }

  private scheduleComposerBottomAlignment(): void {
    this.scheduleLifecycleTask(16, () => {
      this.scrollTimelineToBottomAligned();
    });
    // RESIZE changes the page throughout the IME transition. Re-attach once
    // after it settles so the final bubble cannot remain below the new edge.
    this.scheduleLifecycleTask(COMPOSER_KEYBOARD_SETTLE_MS, () => {
      this.scrollTimelineToBottomAligned();
    });
  }

  private handleComposerFocusChange(focused: boolean): void {
    if (!focused) {
      this.composerResizeKeepsBottomAligned = false;
      return;
    }
    if (!this.composerResizeKeepsBottomAligned) {
      this.composerResizeKeepsBottomAligned = this.shouldKeepTimelineBottomAligned();
    }
    if (this.composerResizeKeepsBottomAligned) {
      this.scheduleComposerBottomAlignment();
    }
  }

  private handleComposerWillFocus(): void {
    // Touch down arrives before ArkUI starts the IME RESIZE pass. Capture the
    // old viewport here; onFocus can already observe the shortened List.
    this.composerResizeKeepsBottomAligned = this.shouldKeepTimelineBottomAligned();
    // Telegram's custom emoji/sticker panel and the system IME share one slot.
    // Clear custom mode on touch-down so it is removed before focus opens IME.
    this.setEmojiPanelVisible(false);
    this.setStickerPanelVisible(false);
  }

  private handleChatViewportAreaChange(newArea: Area): void {
    const h = newArea.height as number;
    if (h <= 0 || h === this.chatViewportHeight) {
      return;
    }
    this.chatViewportHeight = h;
    if (this.composerResizeKeepsBottomAligned) {
      this.scheduleLifecycleTask(16, () => {
        this.scrollTimelineToBottomAligned();
      });
    }
  }

  setEditMode(messageId: string, originalText: string): void {
    this.isEditingMessage = true;
    this.editingMessageId = messageId;
    this.editingOriginalText = originalText;
    this.customEmojiDraftEntities = [];
    this.expectedProgrammaticCustomEmojiText = '';
    // Telegram semantics: the composer is prefilled with the current text
    this.composerDraftText = originalText;
    this.setDraftSelection(originalText.length, originalText.length);
  }

  getEditingMessageId(): string {
    return this.editingMessageId;
  }

  getEditingOriginalText(): string {
    return this.editingOriginalText;
  }

  clearEditMode(clearDraft: boolean): void {
    this.isEditingMessage = false;
    this.editingMessageId = '0';
    this.editingOriginalText = '';
    if (clearDraft) {
      this.composerDraftText = '';
      this.customEmojiDraftEntities = [];
      this.expectedProgrammaticCustomEmojiText = '';
      this.setDraftSelection(0, 0);
      // Kill any pending debounce so the programmatic text reset cannot
      // fire a stray setChatDraftMessage clear after the edit submits
      if (this.draftDebounceTimerId >= 0) {
        clearTimeout(this.draftDebounceTimerId);
        this.draftDebounceTimerId = -1;
      }
    }
  }

  setForwardMode(messageIds: string[], sourceChatId: number, title: string, preview: string): void {
    this.isForwardingMessages = true;
    this.forwardingMessageIds = [...messageIds];
    this.forwardSourceChatId = sourceChatId;
    this.forwardTitle = title;
    this.forwardPreview = preview;
  }

  getForwardModeState(): ChatForwardModeState {
    const state = new ChatForwardModeState();
    state.isForwardingMessages = this.isForwardingMessages;
    state.messageIds = [...this.forwardingMessageIds];
    state.sourceChatId = this.forwardSourceChatId;
    state.title = this.forwardTitle;
    state.preview = this.forwardPreview;
    return state;
  }

  clearForwardMode(): void {
    this.isForwardingMessages = false;
    this.forwardingMessageIds = [];
    this.forwardSourceChatId = 0;
    this.forwardTitle = '';
    this.forwardPreview = '';
  }

  isSearchModeActive(): boolean {
    return this.isSearchMode;
  }

  getSearchQuery(): string {
    return this.searchQuery;
  }

  setSearchQuery(value: string): void {
    this.searchQuery = value;
  }

  setSearchModeActive(value: boolean): void {
    this.isSearchMode = value;
  }

  onSearchResultsUpdated(position: number, total: number, loadedCount: number): void {
    this.searchResultPos = position;
    this.searchResultTotal = total;
    this.searchResultLoaded = loadedCount;
  }

  onSearchLoadingChanged(value: boolean): void {
    this.searchLoading = value;
  }

  onSearchErrorChanged(value: boolean): void {
    this.searchError = value;
  }

  scrollToMessageId(messageId: string): boolean {
    const count = this.dataSource.totalCount();
    for (let i = 0; i < count; i++) {
      const entry: ChatTimelineEntryVO = this.dataSource.getData(i);
      if (timelineEntryContainsMessageId(entry, messageId)) {
        // Center keeps the target clear of the floating top bar/pinned panel
        // and also works for a member collapsed into a photo-album row.
        this.listScroller.scrollToIndex(i, false, ScrollAlign.CENTER);
        this.flashSearchHit(messageId, i);
        return true;
      }
    }
    return false;
  }

  // Scroll if the message is loaded; otherwise reset + load a history window
  // around it and finish the scroll when the rebuilt timeline arrives
  jumpToMessageId(messageId: string): void {
    if (this.scrollToMessageId(messageId)) {
      hilog.info(DOMAIN, TAG, 'Jump: scrolled to %{public}s in loaded timeline', messageId);
      return;
    }
    const useCase = this.loadChatHistoryUseCase;
    if (!useCase || this.activeChatId === 0) {
      return;
    }
    const token = this.pageLifecycleToken;
    this.pendingJumpMessageId = messageId;
    this.pendingJumpAttempts = 0;
    this.blockAutoPaginationUntilUserScroll = true;
    useCase.loadAroundMessage(this.activeChatId, messageId)
      .then((ok: boolean) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        if (!ok) {
          this.pendingJumpMessageId = '';
        }
      })
      .catch((error: Error) => {
        if (token === this.pageLifecycleToken) {
          this.pendingJumpMessageId = '';
          hilog.warn(DOMAIN, TAG, 'Jump failed: %{public}s', error.message);
        }
      });
  }

  // Visible when the viewport is away from the true bottom. After a jump the
  // loaded window sits mid-history, so canLoadNewer keeps the button up even
  // at the loaded edge — the real bottom is further down.
  private refreshScrollToBottomVisibility(endIndex: number): void {
    const total = this.dataSource.totalCount();
    if (total === 0) {
      this.showScrollToBottom = false;
      this.scrollToBottomUnreadCount = 0;
      return;
    }
    const nearBottom = total - 1 - endIndex <= 3;
    const midHistory = this.loadChatHistoryUseCase !== undefined &&
      this.loadChatHistoryUseCase.canLoadNewerMessages(this.activeChatId);
    this.showScrollToBottom = !nearBottom || midHistory;
    if (!this.showScrollToBottom) {
      this.scrollToBottomUnreadCount = 0;
    }
  }

  private handleScrollToBottomPress(): void {
    this.scrollToBottomUnreadCount = 0;
    const useCase = this.loadChatHistoryUseCase;
    if (useCase && useCase.canLoadNewerMessages(this.activeChatId)) {
      // Mid-history window (after a jump): go straight to the chat's last
      // message instead of paging every window in between
      try {
        const state = getAppCoreRuntime().getStore().getState();
        const chat = state.chats.chats.get(this.activeChatId);
        if (chat && chat.lastMessage && chat.lastMessage.id !== '0') {
          this.jumpToMessageId(chat.lastMessage.id);
          return;
        }
      } catch (_e) {
      }
    }
    this.scrollTimelineToBottomAligned();
  }

  // Called after every timeline diff: finish a pending jump once the target
  // message is present. Bounded attempts — the target may have been deleted.
  private fulfillPendingJump(): void {
    if (this.pendingJumpMessageId === '') {
      return;
    }
    const targetId = this.pendingJumpMessageId;
    this.pendingJumpAttempts++;
    // scrollToIndex right after a full reload needs the List to settle first
    this.scheduleLifecycleTask(16, () => {
      if (this.pendingJumpMessageId !== targetId) {
        return;
      }
      if (this.scrollToMessageId(targetId)) {
        this.pendingJumpMessageId = '';
        this.fulfillPendingSharedMediaAction();
      } else if (this.pendingJumpAttempts >= 4) {
        this.pendingJumpMessageId = '';
        this.pendingSharedMediaAction = undefined;
      }
    });
  }

  private normalizeSharedMediaLink(value: string): string {
    const link = value.trim();
    return link.startsWith('www.') ? 'https://' + link : link;
  }

  private resolveEntityLink(text: string, entities: TextEntity[]): string {
    for (let i = 0; i < entities.length; i++) {
      const entity = entities[i];
      if (entity.type === 'textUrl' && entity.url.trim().length > 0) {
        return this.normalizeSharedMediaLink(entity.url);
      }
      if (entity.type === 'url') {
        const offset = Math.max(0, entity.offset);
        const target = text.substring(offset, Math.min(text.length, offset + Math.max(0, entity.length)));
        if (target.trim().length > 0) {
          return this.normalizeSharedMediaLink(target);
        }
      }
    }
    return '';
  }

  private openSharedMediaLink(value: string): boolean {
    const link = this.normalizeSharedMediaLink(value);
    if (link.length === 0) {
      return false;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      context.openLink(link)
        .catch((error: Object): void => {
          hilog.warn(DOMAIN, TAG, 'Shared Media link open failed: %{public}s', String(error));
        });
      return true;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Shared Media link dispatch failed: %{public}s', String(error));
      return false;
    }
  }

  private executeSharedMediaAction(action: PendingSharedMediaAction): boolean {
    if (action.kind === 'link' && this.openSharedMediaLink(action.linkUrl)) {
      return true;
    }
    const entries = this.dataSource.getAllEntries();
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.kind !== 'message' || !timelineEntryContainsMessageId(entry, action.messageId)) {
        continue;
      }
      const message = entry.message;
      if (action.kind === 'media') {
        if (message.contentType === 'photo' || message.contentType === 'photoAlbum' ||
          message.contentType === 'video' || message.contentType === 'animation' ||
          message.contentType === 'videoNote') {
          this.handleMediaGalleryOpen(action.messageId);
          return true;
        }
        return false;
      }
      if (action.kind === 'file' && message.contentType === 'document') {
        this.handleDocumentTap(message.documentPath, message.documentFileId, message.mimeType, message.messageId);
        return true;
      }
      if (action.kind === 'voice' && message.contentType === 'voice') {
        this.handleVoiceTap(message.messageId, message.voicePath, message.voiceFileId);
        return true;
      }
      if (action.kind === 'link') {
        let link = message.linkPreviewUrl;
        if (link.trim().length === 0) {
          link = this.resolveEntityLink(message.text, message.textEntities);
        }
        if (link.trim().length === 0) {
          link = this.resolveEntityLink(message.caption, message.captionEntities);
        }
        return this.openSharedMediaLink(link);
      }
      return false;
    }
    return false;
  }

  private fulfillPendingSharedMediaAction(): void {
    const action = this.pendingSharedMediaAction;
    if (!action || action.chatId !== this.activeChatId) {
      return;
    }
    if (this.executeSharedMediaAction(action)) {
      this.pendingSharedMediaAction = undefined;
    }
  }

  private beginSharedMediaAction(action: PendingSharedMediaAction): void {
    if (action.chatId !== this.activeChatId || action.messageId === '0') {
      return;
    }
    this.pendingSharedMediaAction = action;
    if (action.kind === 'link' && action.linkUrl.trim().length > 0) {
      this.fulfillPendingSharedMediaAction();
      return;
    }
    this.jumpToMessageId(action.messageId);
    this.scheduleLifecycleTask(16, (): void => {
      this.fulfillPendingSharedMediaAction();
    });
  }

  // Flash the found bubble. Rows are plain VOs: only a key change rebuilds a
  // LazyForEach item, so flag + key bump + notify, then revert after a pause.
  private flashSearchHit(messageId: string, index: number): void {
    this.clearSearchFlash();
    const entry: ChatTimelineEntryVO = this.dataSource.getData(index);
    entry.searchFlash = true;
    entry.key = entry.key + '_hl';
    this.dataSource.notifyItemChangedByMessageId(messageId);
    this.searchFlashMessageId = messageId;
    this.searchFlashTimerId = setTimeout(() => {
      this.searchFlashTimerId = -1;
      this.clearSearchFlash();
    }, 1600) as number;
  }

  private clearSearchFlash(): void {
    if (this.searchFlashTimerId !== -1) {
      clearTimeout(this.searchFlashTimerId);
      this.searchFlashTimerId = -1;
    }
    const messageId = this.searchFlashMessageId;
    if (messageId.length === 0) {
      return;
    }
    this.searchFlashMessageId = '';
    const count = this.dataSource.totalCount();
    for (let i = 0; i < count; i++) {
      const entry: ChatTimelineEntryVO = this.dataSource.getData(i);
      if (entry.kind === 'message' && entry.message.messageId === messageId) {
        // A timeline diff may have rebuilt the entry without the flag already
        if (entry.searchFlash) {
          entry.searchFlash = false;
          if (entry.key.endsWith('_hl')) {
            entry.key = entry.key.substring(0, entry.key.length - 3);
          }
          this.dataSource.notifyItemChangedByMessageId(messageId);
        }
        return;
      }
    }
  }

  aboutToAppear(): void {
    try {
      this.isClosing = false;
      this.pendingSharedMediaAction = undefined;
      this.pageLifecycleToken++;
      this.bindNavigationStack();
      this.syncOwnedChatContext();
      this.restoreDraftFromChat();
      navigationUIState.chatScreenVisible = true;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
      this.computeSafeInsets();

      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.sendUseCase = createSendMessageUseCase(getTdGatewayAdapter());
      this.sendMediaUseCase = createSendMediaMessageUseCase(getTdGatewayAdapter());
      this.editUseCase = createEditMessageUseCase(getTdGatewayAdapter());
      this.deleteUseCase = createDeleteMessagesUseCase(getTdGatewayAdapter());
      this.forwardUseCase = createForwardMessagesUseCase(getTdGatewayAdapter());
      this.openChatUseCase = createOpenChatUseCase(store, getTdGatewayAdapter());
      this.searchUseCase = createSearchChatMessagesUseCase(getTdGatewayAdapter());
      this.pinUseCase = createPinChatMessageUseCase(getTdGatewayAdapter());
      this.stickerPanelUseCase = createStickerPanelUseCase(getTdGatewayAdapter());
      this.loadChatHistoryUseCase = createLoadChatHistoryUseCase(store, getTdGatewayAdapter());
      this.loadRepliedMessageUseCase = createLoadRepliedMessageUseCase(
        store,
        getTdGatewayAdapter(),
        this.loadChatHistoryUseCase
      );
      this.replyHydrationCoordinator.reset();
      this.markChatReadUseCase = createMarkChatReadUseCase(store, getTdGatewayAdapter());
      const mediaLifecycleToken: number = this.pageLifecycleToken;
      this.mediaDownloadCtrl.setChangeListener((version: number, fileId: number): void => {
        if (mediaLifecycleToken !== this.pageLifecycleToken) {
          return;
        }
        this.pendingMediaDownloadVersion = version;
        this.notifyMediaDownloadStateChanged(fileId);
        this.refreshOpenMediaGalleryItems();
      });
      this.currentScrollChatId = this.activeChatId;
      this.lastOpenedChatId = this.activeChatId;
      this.needsScrollRestore = true;
      this.lastVisibleStartIndex = -1;
      this.lastVisibleEndIndex = -1;
      this.previousDataCount = 0;
      this.suppressLoadOlderUntil = 0;
      this.isLoadingNewer = false;
      this.unreadRestoreIndex = -1;
      this.hasRestoredUnreadBoundary = false;
      this.lastMarkReadRequestKey = '';
      this.blockAutoPaginationUntilUserScroll = false;
      this.isApplyingTimelineDiff = false;
      if (this.paginationRecheckTimerId >= 0) {
        clearTimeout(this.paginationRecheckTimerId);
        this.paginationRecheckTimerId = -1;
      }
      this.resetPaginationState();
      this.setupMediaPlaybackController();
      this.awaitingInitialTimeline = this.activeChatId !== 0;
      // Capture lastReadInboxMessageId at chat entry — survives markChatRead
      const initialState = store.getState();
      const entryChat = initialState.chats.chats.get(this.activeChatId);
      const pendingUnreadSnapshot: ChatUnreadEntrySnapshot | undefined =
        PendingChatUnreadSnapshot.consume(this.activeChatId);
      const entryUnreadCount = pendingUnreadSnapshot
        ? pendingUnreadSnapshot.unreadCount
        : (entryChat ? entryChat.unreadCount : 0);
      this.stickyLastReadMessageId = entryUnreadCount > 0
        ? (pendingUnreadSnapshot ? pendingUnreadSnapshot.lastReadInboxMessageId
          : (entryChat ? entryChat.lastReadInboxMessageId : '0'))
        : '';
      this.scrollToBottomUnreadCount = entryChat ? Math.max(0, entryChat.unreadCount) : 0;
      this.applyPendingForwardTransferIfNeeded();
      this.rebuildTimeline(initialState);
      this.scheduleHistoryLoad(this.activeChatId, 0);
      this.pinnedMessageDismissedId = '0';
      this.loadPinnedMessage();
      // Do NOT call maybeMarkChatRead here — openChat hasn't reached TDLib yet.
      // The store subscription will call it after history loads (openChat is done by then).

      if (this.unsubscribe !== undefined) {
        this.unsubscribe();
        this.unsubscribe = undefined;
      }

      const lifecycleToken: number = this.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (lifecycleToken !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
          return;
        }
        if (_newState.files.transfers !== _prevState.files.transfers) {
          this.refreshGroupedStickerHomePreviews(_newState);
        }
        if (!this.shouldReactToStoreChange(_newState, _prevState)) {
          return;
        }
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          let scheduledTimerId: number = -1;
          scheduledTimerId = setTimeout(() => {
            if (lifecycleToken !== this.pageLifecycleToken ||
              this.rebuildTimerId !== scheduledTimerId ||
              this.unsubscribe !== activeUnsubscribe) {
              return;
            }
            this.rebuildTimerId = -1;
            this.rebuildScheduled = false;
            try {
              const currentState = getAppCoreRuntime().getStore().getState();
              this.rebuildTimeline(currentState);
              this.maybeMarkChatRead(currentState);
            } catch (e) {
              hilog.error(DOMAIN, TAG, 'Timeline rebuild failed: %{public}s', String(e));
            }
          }, 0) as number;
          this.rebuildTimerId = scheduledTimerId;
        }
      });
      this.unsubscribe = activeUnsubscribe;

      this.bindWindowSizeListener();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'aboutToAppear failed: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
    this.isClosing = false;
    this.pendingSharedMediaAction = undefined;
    this.voiceRecordingCtrl.dispose();
    this.voiceRecordingState = 'idle';
    this.voiceRecordingDurationMs = 0;
    this.resetBotMenuState();
    this.resetEmojiSearchState();
    this.resetStickerSearchState();
    this.resetGifSearchState();
    this.pinnedMessageRequestId++;
    this.resetPinnedMessageState();
    this.pageLifecycleToken++;
    // Send closeChat to TDLib (best effort, fire-and-forget)
    // Use lastOpenedChatId because activeChatId may already be zeroed by handleBackPress
    const closingChatId = this.lastOpenedChatId;
    this.lastOpenedChatId = 0;
    if (this.draftDebounceTimerId >= 0) {
      clearTimeout(this.draftDebounceTimerId);
      this.draftDebounceTimerId = -1;
    }
    if (closingChatId !== 0) {
      this.persistDraft(closingChatId);
      try {
        getTdGatewayAdapter().send(createCloseChatCommand(closingChatId))
          .catch((_: Error) => {});
      } catch (_) {}
    }

    this.saveScrollPosition();
    // Nav lock is set by handleBackPress — do not re-extend in aboutToDisappear
    navigationUIState.chatScreenVisible = false;
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    this.clearOwnedChatContext();
    if (this.historyFallbackTimerId >= 0) {
      clearTimeout(this.historyFallbackTimerId);
      this.historyFallbackTimerId = -1;
    }
    if (this.rebuildTimerId >= 0) {
      clearTimeout(this.rebuildTimerId);
      this.rebuildTimerId = -1;
    }
    this.searchCtrl.clearPendingTimer();
    this.clearTransientTimers();
    this.rebuildScheduled = false;
    this.isLoadingOlder = false;
    this.isLoadingNewer = false;
    this.isMarkingChatRead = false;
    this.isSending = false;
    this.suppressLoadOlderUntil = 0;
    this.unreadRestoreIndex = -1;
    this.stickyLastReadMessageId = '';
    this.hasRestoredUnreadBoundary = false;
    this.scrollToBottomUnreadCount = 0;
    this.lastMarkReadRequestKey = '';
    this.blockAutoPaginationUntilUserScroll = false;
    this.isApplyingTimelineDiff = false;

    this.clearPendingMediaDownloads();
    this.mediaDownloadCtrl.setChangeListener(undefined);
    if (this.paginationRecheckTimerId >= 0) {
      clearTimeout(this.paginationRecheckTimerId);
      this.paginationRecheckTimerId = -1;
    }
    this.resetPaginationState();
    this.awaitingInitialTimeline = false;
    this.sendUseCase = undefined;
    this.sendMediaUseCase = undefined;
    this.stickerPanelUseCase = undefined;
    this.editUseCase = undefined;
    this.deleteUseCase = undefined;
    this.forwardUseCase = undefined;
    this.searchUseCase = undefined;
    this.pinUseCase = undefined;
    this.loadChatHistoryUseCase = undefined;
    this.loadRepliedMessageUseCase = undefined;
    this.replyHydrationCoordinator.reset();
    this.markChatReadUseCase = undefined;
    this.openChatUseCase = undefined;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    removeWindowSizeListener(this.mainWindow);
    this.mainWindow = undefined;
    this.teardownMediaPlaybackController();
  }

  private shouldReactToStoreChange(newState: AppState, prevState: AppState): boolean {
    const chatId = this.activeChatId;
    if (chatId === 0) {
      return false;
    }
    if (newState.messages.messages.get(chatId) !== prevState.messages.messages.get(chatId)) {
      return true;
    }
    if (newState.messages.associatedMessages.get(chatId) !== prevState.messages.associatedMessages.get(chatId)) {
      return true;
    }
    if (newState.chats.chats.get(chatId) !== prevState.chats.chats.get(chatId)) {
      return true;
    }
    if (newState.chats.typingActions.get(chatId) !== prevState.chats.typingActions.get(chatId)) {
      return true;
    }
    // File transfer progress updates (download indicators for media bubbles)
    if (newState.files.transfers !== prevState.files.transfers) {
      return true;
    }
    return newState.users.users !== prevState.users.users;
  }

  private scheduleLifecycleTask(delayMs: number, task: () => void): void {
    const lifecycleToken: number = this.pageLifecycleToken;
    let timerId: number = -1;
    timerId = setTimeout(() => {
      if (lifecycleToken !== this.pageLifecycleToken || !this.transientTimerIds.has(timerId)) {
        return;
      }
      this.transientTimerIds.delete(timerId);
      task();
    }, delayMs) as number;
    this.transientTimerIds.add(timerId);
  }

  private clearTransientTimers(): void {
    this.transientTimerIds.forEach((timerId: number): void => {
      clearTimeout(timerId);
    });
    this.transientTimerIds.clear();
  }

  private syncOwnedChatContext(): void {
    // Group/channel chat ids are negative — the route param is "set" whenever non-zero
    const ownedChatId = this.routeChatId !== 0 ? this.routeChatId : navigationUIState.activeChatId;
    const ownedChatTitle = this.resolveOwnedChatTitle();

    this.activeChatId = ownedChatId;
    this.activeChatTitle = ownedChatTitle;

    navigationUIState.activeChatId = ownedChatId;
    navigationUIState.activeChatTitle = ownedChatTitle;
    chatUIState.activeChatId = ownedChatId;
    chatUIState.activeChatTitle = ownedChatTitle;
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, ownedChatId);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, ownedChatTitle);
  }

  private clearOwnedChatContext(): void {
    navigationUIState.activeChatId = 0;
    navigationUIState.activeChatTitle = '';
    chatUIState.activeChatId = 0;
    chatUIState.activeChatTitle = '';
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, 0);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, '');
  }

  private resolveOwnedChatTitle(): string {
    if (this.routeChatTitle.length > 0) {
      return this.routeChatTitle;
    }
    if (this.routeChatId !== 0 && navigationUIState.activeChatId === this.routeChatId) {
      return navigationUIState.activeChatTitle;
    }
    if (this.routeChatId === 0) {
      return navigationUIState.activeChatTitle;
    }
    return this.activeChatTitle;
  }

  // Single source of truth for the status-bar inset, derived from the reactively
  // recomputed topBarTotalHeight and passed down into TgChatTopBar as @Param.
  private chatTopInset(): number {
    return Math.max(0, this.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT - TgUiTokens.TOP_BAR_BOTTOM_PADDING);
  }

  private shouldShowPinnedMessagePanel(): boolean {
    return this.pinnedMessageVisible && !this.isSearchMode && !this.showMediaGallery &&
      !this.pinnedMessagesListVisible;
  }

  private chatContentStartOffset(): number {
    if (!this.shouldShowPinnedMessagePanel()) {
      return this.topBarTotalHeight;
    }
    return this.topBarTotalHeight + TgUiTokens.PINNED_PANEL_HEIGHT + TgUiTokens.SPACE_4;
  }

  private resetPinnedMessageState(): void {
    this.pinnedMessagesListRequestId++;
    this.pinnedMessageVisible = false;
    this.pinnedMessageId = '0';
    this.pinnedMessagePreview = '';
    this.pinnedMessageHasThumbnail = false;
    this.pinnedMessageThumbnailPath = '';
    this.pinnedMessageIndex = 0;
    this.pinnedMessageTotalCount = 1;
    this.pinnedMessages = [];
    this.pinnedMessagesNextFromMessageId = '0';
    this.pinnedMessagesListVisible = false;
    this.pinnedMessagesListLoading = false;
  }

  private applyPinnedMessageInfo(info: PinnedMessageInfo, index: number, totalCount: number): void {
    this.pinnedMessageId = info.messageId;
    this.pinnedMessagePreview = info.preview;
    this.pinnedMessageHasThumbnail = info.hasThumbnail;
    this.pinnedMessageThumbnailPath = info.thumbnailPath;
    this.pinnedMessageTotalCount = Math.max(1, totalCount);
    this.pinnedMessageIndex = Math.max(0, Math.min(index, this.pinnedMessageTotalCount - 1));
    this.pinnedMessageVisible = info.messageId !== this.pinnedMessageDismissedId;
  }

  private loadSinglePinnedMessageFallback(chatId: number, lifecycleToken: number, requestId: number): void {
    loadPinnedMessageInfo(chatId)
      .then((info: PinnedMessageInfo): void => {
        if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.pinnedMessageRequestId ||
          chatId !== this.activeChatId) {
          return;
        }
        if (!info.isAvailable) {
          this.resetPinnedMessageState();
          return;
        }
        this.pinnedMessages = [info];
        this.applyPinnedMessageInfo(info, 0, 1);
      })
      .catch((_error: Error): void => {
        if (lifecycleToken === this.pageLifecycleToken && requestId === this.pinnedMessageRequestId &&
          chatId === this.activeChatId) {
          this.resetPinnedMessageState();
        }
      });
  }

  private loadPinnedMessage(): void {
    const chatId: number = this.activeChatId;
    const lifecycleToken: number = this.pageLifecycleToken;
    const requestId: number = ++this.pinnedMessageRequestId;
    this.pinnedMessageVisible = false;
    if (chatId === 0) {
      this.resetPinnedMessageState();
      return;
    }

    loadPinnedMessagesPage(chatId)
      .then((page: PinnedMessagesPage): void => {
        if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.pinnedMessageRequestId ||
          chatId !== this.activeChatId) {
          return;
        }
        if (page.items.length === 0) {
          this.loadSinglePinnedMessageFallback(chatId, lifecycleToken, requestId);
          return;
        }
        this.pinnedMessages = page.items;
        this.pinnedMessagesNextFromMessageId = page.nextFromMessageId;
        const totalCount: number = Math.max(page.totalCount, page.items.length);
        this.applyPinnedMessageInfo(page.items[0], totalCount - 1, totalCount);
      })
      .catch((_error: Error): void => {
        if (lifecycleToken === this.pageLifecycleToken && requestId === this.pinnedMessageRequestId &&
          chatId === this.activeChatId) {
          this.loadSinglePinnedMessageFallback(chatId, lifecycleToken, requestId);
        }
      });
  }

  private handlePinnedMessagePress(): void {
    if (this.pinnedMessageId !== '0') {
      this.jumpToMessageId(this.pinnedMessageId);
    }
  }

  private handlePinnedMessageClose(): void {
    this.pinnedMessageDismissedId = this.pinnedMessageId;
    this.pinnedMessageVisible = false;
  }

  private pinnedMessageTitle(index: number, totalCount: number): string {
    const defaultTitle: string = localized($r('app.string.pinned_message').id, 'Pinned Message');
    if (totalCount === 2 && index === 0) {
      return localized($r('app.string.previous_pinned_message').id, 'Previous Pinned Message');
    }
    if (totalCount > 2 && index < totalCount - 1) {
      return `${defaultTitle} #${index + 1}`;
    }
    return defaultTitle;
  }

  private pinnedMessageListItems(): TgPinnedMessageListItem[] {
    const items: TgPinnedMessageListItem[] = [];
    for (let i = 0; i < this.pinnedMessages.length; i++) {
      const source: PinnedMessageInfo = this.pinnedMessages[i];
      const item = new TgPinnedMessageListItem();
      const stripeIndex: number = Math.max(0, this.pinnedMessageTotalCount - 1 - i);
      item.messageId = source.messageId;
      item.title = this.pinnedMessageTitle(stripeIndex, this.pinnedMessageTotalCount);
      item.preview = source.preview;
      item.stripeIndex = stripeIndex;
      item.totalCount = this.pinnedMessageTotalCount;
      item.hasThumbnail = source.hasThumbnail;
      item.thumbnailSrc = source.thumbnailPath;
      items.push(item);
    }
    return items;
  }

  private setPinnedMessagesListVisible(visible: boolean): void {
    this.getUIContext().animateTo({
      curve: curves.responsiveSpringMotion(
        TgUiTokens.PINNED_LIST_MOTION_RESPONSE,
        TgUiTokens.PINNED_LIST_MOTION_DAMPING,
        TgUiTokens.PINNED_LIST_MOTION_OVERLAP
      )
    }, () => {
      this.pinnedMessagesListVisible = visible;
    });
  }

  private handlePinnedMessageListPress(): void {
    if (this.pinnedMessageTotalCount <= 1) {
      this.handlePinnedMessagePress();
      return;
    }
    this.setPinnedMessagesListVisible(true);
  }

  private handlePinnedListItemPress(index: number): void {
    if (index < 0 || index >= this.pinnedMessages.length) {
      return;
    }
    const info: PinnedMessageInfo = this.pinnedMessages[index];
    const stripeIndex: number = Math.max(0, this.pinnedMessageTotalCount - 1 - index);
    this.applyPinnedMessageInfo(info, stripeIndex, this.pinnedMessageTotalCount);
    this.setPinnedMessagesListVisible(false);
    this.scheduleLifecycleTask(0, (): void => {
      this.jumpToMessageId(info.messageId);
    });
  }

  private loadMorePinnedMessages(): void {
    if (this.pinnedMessagesListLoading || this.pinnedMessagesNextFromMessageId === '0' ||
      this.activeChatId === 0) {
      return;
    }

    const chatId: number = this.activeChatId;
    const cursor: string = this.pinnedMessagesNextFromMessageId;
    const lifecycleToken: number = this.pageLifecycleToken;
    const requestId: number = ++this.pinnedMessagesListRequestId;
    this.pinnedMessagesListLoading = true;
    loadPinnedMessagesPage(chatId, cursor)
      .then((page: PinnedMessagesPage): void => {
        if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.pinnedMessagesListRequestId ||
          chatId !== this.activeChatId) {
          return;
        }
        const seenIds: Set<string> = new Set<string>();
        for (let i = 0; i < this.pinnedMessages.length; i++) {
          seenIds.add(this.pinnedMessages[i].messageId);
        }
        const merged: PinnedMessageInfo[] = this.pinnedMessages.slice();
        for (let i = 0; i < page.items.length; i++) {
          if (!seenIds.has(page.items[i].messageId)) {
            seenIds.add(page.items[i].messageId);
            merged.push(page.items[i]);
          }
        }
        this.pinnedMessages = merged;
        this.pinnedMessageTotalCount = Math.max(this.pinnedMessageTotalCount, page.totalCount, merged.length);
        this.pinnedMessagesNextFromMessageId = page.nextFromMessageId === cursor
          ? '0' : page.nextFromMessageId;
        this.pinnedMessagesListLoading = false;
      })
      .catch((_error: Error): void => {
        if (lifecycleToken === this.pageLifecycleToken && requestId === this.pinnedMessagesListRequestId &&
          chatId === this.activeChatId) {
          this.pinnedMessagesListLoading = false;
        }
      });
  }

  private computeSafeInsets(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.bottomOverlayInset = computeChatBottomInset(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.bottomOverlayInset = TgUiTokens.SPACE_8;
    }
  }

  private bindWindowSizeListener(): void {
    try {
      removeWindowSizeListener(this.mainWindow);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const boundWindow = getMainWindow(context);
      this.mainWindow = boundWindow;
      if (boundWindow !== undefined) {
        const lifecycleToken: number = this.pageLifecycleToken;
        this.updateTimelineContainerWidth(boundWindow.getWindowProperties().windowRect.width);
        boundWindow.on('windowSizeChange', (size: window.Size) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.mainWindow !== boundWindow) {
            return;
          }
          this.updateTimelineContainerWidth(size.width);
          this.computeSafeInsets();
        });
        // Status-bar / safe-area height changes are not guaranteed by windowSizeChange.
        boundWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.mainWindow !== boundWindow) {
            return;
          }
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            this.computeSafeInsets();
          }
        });
      }
    } catch (_error) {
      this.timelineContainerWidth = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
    }
  }

  private updateTimelineContainerWidth(windowWidthPx: number): void {
    const widthVp: number = px2vp(windowWidthPx);
    const horizontalInsets: number = TgUiTokens.SPACE_12 * 2;
    const computed: number = Math.floor(widthVp - horizontalInsets);
    this.timelineContainerWidth = Math.max(1, computed);
  }

  private resetPlaybackState(): void {
    this.activeVoiceMessageId = '0';
    this.activeVoiceProgress = 0;
    this.activeVoicePlaying = false;
    this.activeAudioMessageId = '0';
    this.activeAudioProgress = 0;
    this.activeAudioPlaying = false;
    this.locallyListenedVoiceIds.clear();
  }

  private setupMediaPlaybackController(): void {
    const previous = this.mediaPlaybackController;
    if (previous) {
      this.mediaPlaybackController = undefined;
      previous.release().catch((_error: Object) => {});
    }
    this.resetPlaybackState();
    const controller = new MediaPlaybackController();
    this.mediaPlaybackController = controller;
    const lifecycleToken: number = this.pageLifecycleToken;
    const chatId: number = this.activeChatId;
    controller.setListener((snapshot: MediaPlaybackSnapshot): void => {
      if (lifecycleToken !== this.pageLifecycleToken ||
        this.mediaPlaybackController !== controller ||
        this.activeChatId !== chatId) {
        return;
      }
      const prevVoiceId: string = this.activeVoiceMessageId;
      const prevAudioId: string = this.activeAudioMessageId;
      if (snapshot.contentType === 'voice') {
        this.activeVoiceMessageId = snapshot.messageId;
        this.activeVoiceProgress = snapshot.progress;
        this.activeVoicePlaying = snapshot.isPlaying;
        // Clear audio state when voice is active
        if (snapshot.isPlaying) {
          this.activeAudioMessageId = '0';
          this.activeAudioProgress = 0;
          this.activeAudioPlaying = false;
        }
      } else {
        this.activeAudioMessageId = snapshot.messageId;
        this.activeAudioProgress = snapshot.progress;
        this.activeAudioPlaying = snapshot.isPlaying;
        // Clear voice state when audio is active
        if (snapshot.isPlaying) {
          this.activeVoiceMessageId = '0';
          this.activeVoiceProgress = 0;
          this.activeVoicePlaying = false;
        }
      }
      // Playback state lives on the page — LazyForEach rows only repaint via
      // an explicit notify (lesson 65), so poke every affected row.
      this.notifyPlaybackRows(prevVoiceId, prevAudioId, snapshot.messageId);
    });
    controller.setOnCompleted((messageId: string, contentType: MediaContentType): void => {
      if (lifecycleToken !== this.pageLifecycleToken ||
        this.mediaPlaybackController !== controller ||
        this.activeChatId !== chatId) {
        return;
      }
      this.handlePlaybackCompleted(messageId, contentType);
    });
  }

  private notifyPlaybackRows(prevVoiceId: string, prevAudioId: string, currentId: string): void {
    const ids = new Set<string>();
    if (prevVoiceId !== '0') {
      ids.add(prevVoiceId);
    }
    if (prevAudioId !== '0') {
      ids.add(prevAudioId);
    }
    if (currentId !== '0') {
      ids.add(currentId);
    }
    ids.forEach((id: string): void => {
      this.dataSource.notifyItemChangedByMessageId(id);
    });
  }

  private teardownMediaPlaybackController(): void {
    const controller = this.mediaPlaybackController;
    this.mediaPlaybackController = undefined;
    this.resetPlaybackState();
    if (!controller) {
      return;
    }
    controller.release()
      .catch((_error: Object) => {});
  }

  private handlePlaybackCompleted(messageId: string, contentType: MediaContentType): void {
    // Auto-advance: find next voice/audio message and play it
    const entries = this.dataSource.getAllEntries();
    let foundCurrent = false;
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.kind !== 'message') continue;
      if (entry.message.messageId === messageId) {
        foundCurrent = true;
        continue;
      }
      if (!foundCurrent) continue;
      // Found next message after current — check if same type
      const msg = entry.message;
      if (contentType === 'voice' && msg.contentType === 'voice' && msg.voicePath.length > 0) {
        this.locallyListenedVoiceIds.add(msg.messageId);
        const controller = this.mediaPlaybackController;
        if (controller) {
          controller.toggle(msg.messageId, msg.voicePath, 'voice')
            .catch((_error: Object) => {});
        }
        return;
      }
      if (contentType === 'audio' && msg.contentType === 'audio' && msg.audioPath.length > 0) {
        const controller = this.mediaPlaybackController;
        if (controller) {
          controller.toggle(msg.messageId, msg.audioPath, 'audio')
            .catch((_error: Object) => {});
        }
        return;
      }
      // Different type or no local file — stop auto-advance
      break;
    }
  }

  private computeInitials(title: string): string {
    const trimmed = title.trim();
    if (trimmed.length === 0) {
      return '';
    }
    const parts = trimmed.split(' ');
    if (parts.length >= 2 && parts[1].length > 0) {
      return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
    }
    return trimmed.charAt(0).toUpperCase();
  }

  private formatUserStatus(status: string): string {
    if (status === 'online') {
      return localized($r('app.string.online').id, 'online');
    }
    if (status === 'recently') {
      return localized($r('app.string.last_seen_recently').id, 'last seen recently');
    }
    if (status === 'lastWeek') {
      return localized($r('app.string.last_seen_within_week').id, 'last seen within a week');
    }
    if (status === 'lastMonth') {
      return localized($r('app.string.last_seen_within_month').id, 'last seen within a month');
    }
    if (status === 'longTimeAgo') {
      return localized($r('app.string.last_seen_long_ago').id, 'last seen a long time ago');
    }
    return '';
  }

  private formatTypingSubtitle(actionType: string, subjectName: string = ''): string {
    let actionLabel: string = '';
    switch (actionType) {
      case 'typing':
        actionLabel = localized($r('app.string.typing').id, 'typing...');
        break;
      case 'recordingVideo':
        actionLabel = localized($r('app.string.chat_preview_recording_video').id, 'recording video...');
        break;
      case 'uploadingVideo':
        actionLabel = localized($r('app.string.chat_preview_sending_video').id, 'sending video...');
        break;
      case 'recordingVoice':
        actionLabel = localized($r('app.string.chat_preview_recording_voice').id, 'recording voice...');
        break;
      case 'uploadingVoice':
        actionLabel = localized($r('app.string.chat_preview_sending_voice').id, 'sending voice...');
        break;
      case 'uploadingPhoto':
        actionLabel = localized($r('app.string.chat_preview_sending_photo').id, 'sending photo...');
        break;
      case 'uploadingDocument':
        actionLabel = localized($r('app.string.chat_preview_sending_file').id, 'sending file...');
        break;
      case 'choosingSticker':
        actionLabel = localized($r('app.string.chat_preview_choosing_sticker').id, 'choosing sticker...');
        break;
      case 'choosingLocation':
        actionLabel = localized($r('app.string.chat_preview_choosing_location').id, 'choosing location...');
        break;
      case 'choosingContact':
        actionLabel = localized($r('app.string.chat_preview_choosing_contact').id, 'choosing contact...');
        break;
      case 'playingGame':
        actionLabel = localized($r('app.string.chat_preview_playing_game').id, 'playing game...');
        break;
      case 'recordingVideoNote':
        actionLabel = localized($r('app.string.chat_preview_recording_video_note').id, 'recording video message...');
        break;
      case 'uploadingVideoNote':
        actionLabel = localized($r('app.string.chat_preview_sending_video_note').id, 'sending video message...');
        break;
      default:
        actionLabel = localized($r('app.string.typing').id, 'typing...');
        break;
    }
    return subjectName.length > 0 ? `${subjectName} ${actionLabel}` : actionLabel;
  }

  private formatConnectionSubtitle(status: string): string {
    switch (status) {
      case 'connecting':
        return localized($r('app.string.call_connecting').id, 'Connecting...');
      case 'updating':
        return localized($r('app.string.connection_updating').id, 'Updating...');
      case 'waitingForNetwork':
        return localized($r('app.string.connection_waiting_network').id, 'Waiting for network...');
      default:
        return '';
    }
  }

  private updateChatTopBarData(state: AppState): void {
    const chat = state.chats.chats.get(this.activeChatId);
    if (chat === undefined) {
      this.chatSubtitle = '';
      this.chatSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
      this.chatSubtitleSpinner = false;
      this.chatAvatarInitials = '';
      this.chatAvatarColorIndex = 0;
      this.chatAvatarImageSrc = '';
      this.chatIsOnline = false;
      this.chatTopBarTrailingAction = TgChatTopBarTrailingAction.Search;
      return;
    }

    this.chatAvatarInitials = this.computeInitials(chat.title);
    const colorSeed = chat.peerUserId > 0 ? chat.peerUserId : chat.id;
    this.chatAvatarColorIndex = colorSeed % 8;
    this.chatAvatarImageSrc = chat.photoSmall.length > 0 ? fileUri.getUriFromPath(chat.photoSmall) : '';
    this.chatTopBarTrailingAction = chat.peerUserId > 0
      ? TgChatTopBarTrailingAction.Search
      : TgChatTopBarTrailingAction.Avatar;

    if (chat.peerUserId > 0) {
      const user = state.users.users.get(chat.peerUserId);
      if (user !== undefined) {
        if (user.isBot) {
          this.chatSubtitle = localized($r('app.string.member_role_bot').id, 'bot');
          this.chatSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
          this.chatIsOnline = false;
        } else {
          this.chatSubtitle = this.formatUserStatus(user.status);
          this.chatSubtitleMode = user.status === 'online'
            ? TgChatTopBarSubtitleMode.Online
            : TgChatTopBarSubtitleMode.Secondary;
          this.chatIsOnline = user.status === 'online';
        }
      } else {
        this.chatSubtitle = '';
        this.chatSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
        this.chatIsOnline = false;
      }
    } else {
      // Groups/supergroups/channels: show member count
      if (chat.memberCount > 0) {
        if (chat.type === 'channel') {
          const fmt = localized($r('app.string.subscribers_count').id, '%s subscribers');
          this.chatSubtitle = fmt.replace('%s', chat.memberCount.toString());
        } else {
          const fmt = localized($r('app.string.group_members_count').id, '%s members');
          this.chatSubtitle = fmt.replace('%s', chat.memberCount.toString());
        }
      } else {
        this.chatSubtitle = chat.type === 'channel'
          ? localized($r('app.string.channel_label').id, 'channel')
          : localized($r('app.string.group_label').id, 'group');
      }
      this.chatSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
      this.chatIsOnline = false;
    }

    // Telegram-like activity states override the secondary subtitle semantics.
    const typingInfo = state.chats.typingActions.get(this.activeChatId);
    if (typingInfo && (Date.now() - typingInfo.timestamp) < 6000) {
      let actorName: string = '';
      if (chat.peerUserId <= 0 && typingInfo.senderUserId > 0) {
        const sender = state.users.users.get(typingInfo.senderUserId);
        actorName = sender
          ? (sender.firstName.length > 0 ? sender.firstName : sender.username)
          : '';
      }
      this.chatSubtitle = this.formatTypingSubtitle(typingInfo.actionType, actorName);
      this.chatSubtitleMode = TgChatTopBarSubtitleMode.Activity;
    }

    // Connection problems override status/activity (Telegram/ArkGram parity: highest priority)
    if (state.connection.status !== 'ready') {
      this.chatSubtitle = this.formatConnectionSubtitle(state.connection.status);
      this.chatSubtitleMode = TgChatTopBarSubtitleMode.Activity;
      this.chatSubtitleSpinner = true;
    } else {
      this.chatSubtitleSpinner = false;
    }
  }

  private resetBotMenuState(): void {
    this.showBotMenu = false;
    this.botMenuOpen = false;
    this.botMenuTitle = '';
    this.botMenuUrl = '';
    this.botMenuCommands = [];
    this.botMenuPeerUserId = 0;
    this.botMenuLoadingUserId = 0;
  }

  private refreshBotMenuState(state: AppState): void {
    const chat = state.chats.chats.get(this.activeChatId);
    if (chat === undefined || chat.type !== 'private' || chat.peerUserId <= 0) {
      this.resetBotMenuState();
      return;
    }
    const user = state.users.users.get(chat.peerUserId);
    if (user === undefined || !user.isBot) {
      this.resetBotMenuState();
      return;
    }
    if (this.botMenuPeerUserId === chat.peerUserId || this.botMenuLoadingUserId === chat.peerUserId) {
      return;
    }

    const peerUserId = chat.peerUserId;
    const chatId = this.activeChatId;
    const lifecycleToken = this.pageLifecycleToken;
    this.botMenuLoadingUserId = peerUserId;
    loadBotMenuInfo(peerUserId)
      .then((info: BotMenuInfo) => {
        if (this.pageLifecycleToken !== lifecycleToken || this.activeChatId !== chatId) {
          return;
        }
        this.botMenuLoadingUserId = 0;
        this.botMenuPeerUserId = peerUserId;
        this.botMenuOpen = false;
        this.botMenuUrl = info.url;
        this.botMenuCommands = info.commands;
        this.botMenuTitle = info.title.length > 0
          ? info.title
          : localized($r('app.string.composer_bot_menu').id, 'Menu');
        this.showBotMenu = info.isAvailable;
      })
      .catch((error: Error) => {
        if (this.pageLifecycleToken !== lifecycleToken || this.activeChatId !== chatId) {
          return;
        }
        this.botMenuLoadingUserId = 0;
        this.botMenuPeerUserId = 0;
        hilog.warn(DOMAIN, TAG, 'Bot menu load failed: %{public}s', error.message);
      });
  }

  private handleBotMenuPress(): void {
    if (!this.showBotMenu) {
      return;
    }
    if (this.botMenuUrl.length > 0) {
      this.botMenuOpen = false;
      try {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const want: Want = {
          action: 'ohos.want.action.viewData',
          uri: this.botMenuUrl
        };
        context.startAbility(want).catch((_error: Object) => {});
      } catch (_error) {}
      return;
    }
    if (this.botMenuCommands.length === 0) {
      return;
    }

    this.botMenuOpen = !this.botMenuOpen;
  }

  private botMenuCommandNames(): string[] {
    const result: string[] = [];
    for (const entry of this.botMenuCommands) {
      result.push(entry.command);
    }
    return result;
  }

  private botMenuCommandDescriptions(): string[] {
    const result: string[] = [];
    for (const entry of this.botMenuCommands) {
      result.push(entry.description);
    }
    return result;
  }

  private handleBotMenuOpenChange(isOpen: boolean): void {
    this.botMenuOpen = isOpen && this.showBotMenu && this.botMenuUrl.length === 0 &&
      this.botMenuCommands.length > 0;
  }

  private handleBotMenuCommandPress(index: number): void {
    this.botMenuOpen = false;
    if (index < 0 || index >= this.botMenuCommands.length) {
      return;
    }
    this.handleSendMessage(`/${this.botMenuCommands[index].command}`);
  }

  private rebuildTimeline(state: AppState): void {
    if (this.activeChatId === 0) {
      this.resetBotMenuState();
      this.activeChatIsChannel = false;
      this.dataSource.applyDiff([]);
      this.title = this.activeChatTitle.length > 0
        ? this.activeChatTitle
        : localized($r('app.string.chats_title').id, 'Chat');
      this.chatSubtitle = '';
      this.chatSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
      this.chatAvatarInitials = '';
      this.chatAvatarColorIndex = 0;
      this.chatAvatarImageSrc = '';
      this.chatIsOnline = false;
      this.chatTopBarTrailingAction = TgChatTopBarTrailingAction.Search;
      this.awaitingInitialTimeline = false;

      this.clearPendingMediaDownloads();
      this.pendingMediaOpenIntent.reset();
      return;
    }

    const result = buildChatTimeline(this.activeChatId, state, this.stickyLastReadMessageId);
    const chat = state.chats.chats.get(this.activeChatId);
    this.activeChatIsChannel = chat?.type === 'channel';
    if (chat && chat.unreadCount > this.scrollToBottomUnreadCount) {
      // Preserve the latest unread count while markChatRead updates TDLib.
      // It is cleared only after the viewport reaches the true bottom.
      this.scrollToBottomUnreadCount = chat.unreadCount;
    }
    const resolvedTitle = result.chatTitle.length > 0 ? result.chatTitle : this.activeChatTitle;
    this.title = resolvedTitle.length > 0 ? resolvedTitle : localized($r('app.string.chats_title').id, 'Chat');
    if (result.chatTitle.length > 0) {
      this.activeChatTitle = result.chatTitle;
      if (this.routeChatId === this.activeChatId) {
        this.routeChatTitle = result.chatTitle;
      }
      if (navigationUIState.activeChatId === this.activeChatId) {
        navigationUIState.activeChatTitle = result.chatTitle;
        chatUIState.activeChatTitle = result.chatTitle;
        AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, result.chatTitle);
      }
    }
    this.updateChatTopBarData(state);
    this.refreshBotMenuState(state);
    this.unreadRestoreIndex = result.unreadEntryIndex;
    const prevCount = this.previousDataCount;

    // ── Capture scroll anchor BEFORE data change ──
    // Save anchor by KEY (not just index) — robust against reorders/inserts.
    const savedStartIndex = this.lastVisibleStartIndex;
    const savedEndIndex = this.lastVisibleEndIndex;
    let anchorKey: string | undefined;
    if (prevCount > 0 && savedStartIndex >= 0 && savedStartIndex < prevCount) {
      anchorKey = this.dataSource.getData(savedStartIndex).key;
    }
    this.isApplyingTimelineDiff = true;
    try {
      this.dataSource.applyDiff(result.entries);
    } finally {
      this.isApplyingTimelineDiff = false;
    }

    this.syncResolvedPendingDownloads(result.entries);
    this.fulfillPendingMediaOpenIntent(result.entries);
    this.refreshOpenMediaGalleryItems();
    const newCount = this.dataSource.totalCount();
    this.previousDataCount = newCount;
    if (this.lastVisibleEndIndex >= 0) {
      this.refreshScrollToBottomVisibility(this.lastVisibleEndIndex);
    }

    // Determine if the initial timeline has enough data to release the placeholder.
    // BUT do not set awaitingInitialTimeline = false here. Let restoreScrollPosition
    // handle it so the List appears already scrolled to the correct position.
    const canReleaseTimeline = !this.awaitingInitialTimeline ||
      (newCount >= INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT) ||
      (!chat || !chat.lastMessage || chat.lastMessage.id === '0') ||
      (this.loadChatHistoryUseCase &&
        !this.loadChatHistoryUseCase.canLoadOlderMessages(this.activeChatId));

    if (this.needsScrollRestore && newCount > 0 && canReleaseTimeline) {
      // Set initialIndex BEFORE releasing the placeholder so List is born at the
      // correct position — no programmatic scrollToBottom needed (iOS pattern).
      this.needsScrollRestore = false;
      this.computeInitialIndex(newCount);
      this.hasRestoredUnreadBoundary = this.unreadRestoreIndex >= 0;
      this.restoreScrollPosition();
    } else if (!this.awaitingInitialTimeline && !this.hasRestoredUnreadBoundary &&
      this.unreadRestoreIndex >= 0 && this.unreadRestoreIndex < newCount) {
      // The first short history batch can release the List before the
      // around-unread window arrives. Restore once when that marker appears;
      // otherwise maintainVisibleContentPosition keeps the old viewport and
      // the correctly inserted divider remains off-screen.
      this.hasRestoredUnreadBoundary = true;
      this.listInitialIndex = this.unreadRestoreIndex;
      this.restoreScrollPosition();
    } else if (!this.awaitingInitialTimeline) {
      // Only do prepend/append compensation after initial setup is complete.
      const prependCount = this.dataSource.getLastPrependCount();
      if (prependCount > 0 && prevCount > 0 && anchorKey) {
        // HarmonyOS List has native maintainVisibleContentPosition(true) for
        // LazyForEach prepends. Let the platform preserve the viewport instead
        // of fighting it with a programmatic scroll (Lesson #37, #35).
        this.guardProgrammaticScroll();
        this.blockAutoPaginationUntilUserScroll = true;
        hilog.info(DOMAIN, TAG,
          'Prepend handled by native maintainVisibleContentPosition: key=%{public}s prepend=%{public}d start=%{public}d end=%{public}d',
          anchorKey, prependCount, savedStartIndex, savedEndIndex);
      } else if (prevCount > 0 && newCount > prevCount && this.isNearBottom()) {
        // New messages arrived while user is at bottom — stay at bottom
        this.scheduleLifecycleTask(16, () => {
          this.scrollTimelineToBottomAligned();
        });
      }
    }

    this.fulfillPendingJump();
    this.refreshRestoredReplySnippet(state);
    this.scheduleMissingReplyHydration(state);
  }

  private scheduleMissingReplyHydration(state: AppState): void {
    const useCase = this.loadRepliedMessageUseCase;
    const chatMessages = state.messages.messages.get(this.activeChatId);
    if (!useCase || !chatMessages || chatMessages.size === 0) {
      return;
    }

    const associatedMessages = state.messages.associatedMessages.get(this.activeChatId);
    const replyLookup = associatedMessages
      ? new Map<string, Message>(associatedMessages)
      : new Map<string, Message>();
    chatMessages.forEach((message: Message, messageId: string): void => {
      replyLookup.set(messageId, message);
    });
    const requests = this.replyHydrationCoordinator.collect(
      this.activeChatId,
      chatMessages,
      replyLookup
    );
    if (requests.length === 0) {
      return;
    }

    const lifecycleToken = this.pageLifecycleToken;
    const chatId = this.activeChatId;
    this.runMissingReplyHydration(useCase, requests, lifecycleToken, chatId)
      .catch((error: Error): void => {
        if (lifecycleToken === this.pageLifecycleToken && chatId === this.activeChatId) {
          hilog.debug(DOMAIN, TAG, 'Reply hydration batch failed: %{public}s', error.message);
        }
      });
  }

  private async runMissingReplyHydration(
    useCase: LoadRepliedMessageUseCase,
    requests: ReplyHydrationRequest[],
    lifecycleToken: number,
    chatId: number
  ): Promise<void> {
    for (let index = 0; index < requests.length; index += MAX_PARALLEL_REPLY_HYDRATION_REQUESTS) {
      const chunk = requests.slice(index, index + MAX_PARALLEL_REPLY_HYDRATION_REQUESTS);
      await Promise.all(chunk.map((request: ReplyHydrationRequest): Promise<boolean> =>
        useCase.execute(
          request.chatId,
          request.replyingMessageId,
          request.targetMessageId,
          request.targetChatId
        )));

      if (lifecycleToken !== this.pageLifecycleToken || chatId !== this.activeChatId) {
        return;
      }
      for (const request of chunk) {
        this.replyHydrationCoordinator.complete(request);
      }
    }
  }

  // A draft reply restored before history loaded degrades to a generic
  // "Message / Message" chip — re-resolve it once the target arrives
  private refreshRestoredReplySnippet(state: AppState): void {
    // The degraded chip is produced with the localized generic label, so the
    // detection must compare against the same localized value in every locale.
    const generic = localized($r('app.string.message_action').id, 'Message');
    if (this.replyToMessageId === '0'
      || this.replyToAuthor !== generic || this.replyToPreview !== generic) {
      return;
    }
    const chatMessages = state.messages.messages.get(this.activeChatId);
    const target = chatMessages ? chatMessages.get(this.replyToMessageId) : undefined;
    if (!chatMessages || !target) {
      return;
    }
    this.replyToAuthor = resolveSenderName(target, state);
    this.replyToPreview = resolveReplyPreview(chatMessages, this.replyToMessageId);
  }

  private computeInitialIndex(totalCount: number): void {
    if (totalCount <= 0) {
      this.listInitialIndex = 0;
      return;
    }

    const chatId = this.activeChatId;

    // Priority 1: unread boundary
    if (this.unreadRestoreIndex >= 0 && this.unreadRestoreIndex < totalCount) {
      // Anchor the semantic marker itself. The preceding date key can remain
      // at the start of the day while same-day history prepends above it.
      const targetIndex = this.unreadRestoreIndex;
      this.listInitialIndex = targetIndex;
      hilog.info(DOMAIN, TAG, 'initialIndex set to unread boundary %{public}d for chat %{public}d',
        targetIndex, chatId);
      return;
    }

    // Priority 2: saved scroll position
    const savedKey = TgChatScreenPage.scrollPositionCache.get(chatId);
    if (savedKey !== undefined) {
      const savedIndex = this.dataSource.findIndexByKey(savedKey);
      if (savedIndex >= 0) {
        this.listInitialIndex = savedIndex;
        hilog.info(DOMAIN, TAG, 'initialIndex set to saved key=%{public}s index=%{public}d for chat %{public}d',
          savedKey, savedIndex, chatId);
        return;
      }
    }

    // Priority 3: bottom (newest messages)
    this.listInitialIndex = totalCount - 1;
    hilog.info(DOMAIN, TAG, 'initialIndex set to bottom %{public}d for chat %{public}d',
      this.listInitialIndex, chatId);
  }

  private guardProgrammaticScroll(durationMs: number = PROGRAMMATIC_SCROLL_GUARD_MS): void {
    const guardUntil = Date.now() + durationMs;
    if (guardUntil > this.suppressLoadOlderUntil) {
      this.suppressLoadOlderUntil = guardUntil;
    }
  }

  private resetPaginationState(): void {
    this.isLoadingOlder = false;
    this.isLoadingNewer = false;
  }

  private isNearTopPaginationEdge(start: number): boolean {
    return start < TIMELINE_TOP_EDGE_TRIGGER_INDEX;
  }

  private isNearBottomPaginationEdge(end: number, totalCount: number): boolean {
    return totalCount > 0 && end >= totalCount - TIMELINE_BOTTOM_EDGE_TRIGGER_GAP;
  }

  private armAutoPaginationUnlock(targetIndex: number, reason: string): void {
    if (targetIndex >= TIMELINE_TOP_EDGE_TRIGGER_INDEX) {
      return;
    }
    this.blockAutoPaginationUntilUserScroll = true;
    this.guardProgrammaticScroll(PROGRAMMATIC_SCROLL_GUARD_MS * 2);
    hilog.info(DOMAIN, TAG,
      'Blocking auto pagination after programmatic restore to %{public}d (%{public}s)',
      targetIndex, reason);
  }

  private maybeUnlockAutoPagination(scrollOffset: number, scrollState: ScrollState): void {
    if (this.isApplyingTimelineDiff) {
      return;
    }
    if (!this.blockAutoPaginationUntilUserScroll) {
      return;
    }
    if (scrollState === ScrollState.Idle || Math.abs(scrollOffset) < 0.5) {
      return;
    }
    this.blockAutoPaginationUntilUserScroll = false;
    hilog.info(DOMAIN, TAG,
      'Auto pagination unlocked by user scroll: state=%{public}d offset=%{public}s',
      scrollState, scrollOffset.toString());
  }

  // На краю списка перетаскивание не двигает контент, onDidScroll не стреляет,
  // и blockAutoPaginationUntilUserScroll никогда не снимается — разблокируем
  // по самому жесту и принудительно перепроверяем край.
  private handleTimelineTouch(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    const touchY = event.touches[0].y;
    if (event.type === TouchType.Down) {
      this.timelineTouchStartY = touchY;
      return;
    }
    if (event.type !== TouchType.Move) {
      return;
    }
    if (!this.blockAutoPaginationUntilUserScroll || this.isApplyingTimelineDiff) {
      return;
    }
    if (this.timelineTouchStartY < 0 ||
      Math.abs(touchY - this.timelineTouchStartY) < TIMELINE_TOUCH_UNLOCK_DISTANCE) {
      return;
    }
    this.blockAutoPaginationUntilUserScroll = false;
    hilog.info(DOMAIN, TAG, 'Auto pagination unlocked by touch drag at edge');
    this.schedulePaginationRecheck(0);
  }

  private shouldSuppressLoadOlder(): boolean {
    return Date.now() < this.suppressLoadOlderUntil;
  }

  private schedulePaginationRecheck(delayMs: number = 0): void {
    if (this.paginationRecheckTimerId >= 0) {
      clearTimeout(this.paginationRecheckTimerId);
    }
    const lifecycleToken: number = this.pageLifecycleToken;
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (lifecycleToken !== this.pageLifecycleToken || this.paginationRecheckTimerId !== scheduledTimerId) {
        return;
      }
      this.paginationRecheckTimerId = -1;
      if (this.rebuildScheduled || this.isApplyingTimelineDiff) {
        this.schedulePaginationRecheck(16);
        return;
      }
      this.recheckPaginationEdge();
    }, delayMs) as number;
    this.paginationRecheckTimerId = scheduledTimerId;
  }

  private loadOlderMessages(): void {
    const chatId = this.activeChatId;
    const useCase = this.loadChatHistoryUseCase;
    if (!useCase || chatId === 0 || this.isLoadingOlder) {
      return;
    }
    if (!useCase.canLoadOlderMessages(chatId)) {
      return;
    }
    const oldestId = useCase.getOldestMessageId(chatId);
    if (oldestId === '0') {
      return;
    }

    this.isLoadingOlder = true;
    hilog.info(DOMAIN, TAG, 'Loading older messages for chat %{public}d from %{public}s', chatId, oldestId);

    const params = new LoadChatHistoryParams();
    params.chatId = chatId;
    params.fromMessageId = oldestId;
    params.limit = 50;
    params.direction = 'older';
    params.reason = 'default';

    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.execute(params)
      .catch((_: Error) => {})
      .finally(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.loadChatHistoryUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        this.isLoadingOlder = false;
        this.schedulePaginationRecheck();
      });
  }

  // Android pattern: after each load completes, immediately check if still near edge
  // and fire next load without requiring scroll-away (no latch).
  private recheckPaginationEdge(): void {
    if (this.rebuildScheduled || this.isApplyingTimelineDiff) {
      return;
    }
    // Respect the cascade block — if prepend compensation just fired,
    // do NOT trigger another load until the user actually scrolls.
    if (this.blockAutoPaginationUntilUserScroll) {
      return;
    }
    if (this.shouldSuppressLoadOlder()) {
      // Suppress-окно временное — не бросаем перепроверку, а откладываем её,
      // иначе на статичном крае onScrollIndex больше не стрельнёт.
      this.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS / 2);
      return;
    }
    const start = this.lastVisibleStartIndex;
    const end = this.lastVisibleEndIndex;
    if (start < 0 || end < 0) {
      return;
    }
    const totalCount = this.dataSource.totalCount();

    if (this.isNearTopPaginationEdge(start) && !this.isLoadingOlder) {
      this.loadOlderMessages();
    }
    if (this.isNearBottomPaginationEdge(end, totalCount) && !this.isLoadingNewer) {
      this.loadNewerMessages();
    }
  }

  private loadNewerMessages(): void {
    const chatId = this.activeChatId;
    const useCase = this.loadChatHistoryUseCase;
    if (!useCase || chatId === 0 || this.isLoadingNewer) {
      return;
    }
    if (!useCase.canLoadNewerMessages(chatId)) {
      return;
    }

    const newestId = useCase.getNewestMessageId(chatId);
    if (newestId === '0') {
      return;
    }

    this.isLoadingNewer = true;
    hilog.info(DOMAIN, TAG, 'Loading newer messages for chat %{public}d from %{public}s', chatId, newestId);

    const params = new LoadChatHistoryParams();
    params.chatId = chatId;
    params.fromMessageId = newestId;
    params.offset = -49;
    params.limit = 50;
    params.direction = 'newer';
    params.reason = 'default';

    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.execute(params)
      .catch((_: Error) => {})
      .finally(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.loadChatHistoryUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        this.isLoadingNewer = false;
        this.schedulePaginationRecheck();
      });
  }

  private maybeMarkChatRead(state: AppState): void {
    const chatId = this.activeChatId;
    const useCase = this.markChatReadUseCase;
    if (chatId === 0 || !useCase || this.isMarkingChatRead) {
      return;
    }

    const chat = state.chats.chats.get(chatId);
    if (!chat || chat.unreadCount <= 0) {
      this.lastMarkReadRequestKey = '';
      return;
    }

    const requestKey = chatId.toString() + ':' + chat.unreadCount.toString() + ':' + chat.lastReadInboxMessageId;
    if (this.lastMarkReadRequestKey === requestKey) {
      return;
    }

    this.lastMarkReadRequestKey = requestKey;
    this.isMarkingChatRead = true;
    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.execute({ chatId: chatId })
      .catch((error: Object) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.markChatReadUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        hilog.warn(DOMAIN, TAG, 'markChatRead failed for %{public}d: %{public}s', chatId, String(error));
        if (this.activeChatId === chatId && this.lastMarkReadRequestKey === requestKey) {
          this.lastMarkReadRequestKey = '';
        }
      })
      .finally(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.markChatReadUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        this.isMarkingChatRead = false;
      });
  }

  private notifyMediaDownloadStateChanged(fileId: number): void {
    if (fileId <= 0) {
      return;
    }
    const entries = this.dataSource.getAllEntries();
    for (let entryIndex = 0; entryIndex < entries.length; entryIndex++) {
      const entry = entries[entryIndex];
      if (entry.kind !== 'message') {
        continue;
      }
      const message = entry.message;
      let ownsFile = message.photoFileId === fileId || message.videoFileId === fileId ||
        message.documentFileId === fileId || message.audioFileId === fileId || message.voiceFileId === fileId;
      if (!ownsFile) {
        for (let albumIndex = 0; albumIndex < message.albumPhotoFileIds.length; albumIndex++) {
          if (message.albumPhotoFileIds[albumIndex] === fileId) {
            ownsFile = true;
            break;
          }
        }
      }
      if (ownsFile) {
        this.dataSource.notifyItemChangedByMessageId(message.messageId);
      }
    }
  }

  private requestMediaDownload(fileId: number, messageId: string = ''): void {
    this.mediaDownloadCtrl.requestMediaDownload(fileId, this.pageLifecycleToken);
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
    if (messageId.length > 0) {
      // Мгновенный отклик на тап: LazyForEach-строка перерисовывается сразу
      // (pending-состояние живёт в контроллере и без notify не доезжает до бабла)
      this.dataSource.notifyItemChangedByMessageId(messageId);
    }
  }

  private cancelMediaDownload(fileId: number, messageId: string = ''): void {
    this.mediaDownloadCtrl.cancelMediaDownload(fileId);
    if (this.pendingMediaOpenIntent.matchesFile(fileId)) {
      this.pendingMediaOpenIntent.reset();
    }
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
    if (messageId.length > 0) {
      this.dataSource.notifyItemChangedByMessageId(messageId);
    }
  }

  private clearPendingMediaDownloads(): void {
    this.mediaDownloadCtrl.clearPendingDownloads();
    this.pendingMediaOpenIntent.reset();
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
  }

  private isMediaDownloadPending(fileId: number): boolean {
    return this.mediaDownloadCtrl.isDownloadPending(fileId);
  }

  private isMediaDownloadFailed(fileId: number): boolean {
    return this.mediaDownloadCtrl.isDownloadFailed(fileId);
  }

  private effectiveAlbumPhotoDownloading(entry: ChatTimelineEntryVO): boolean[] {
    const result: boolean[] = [];
    const count = Math.max(entry.message.albumPhotoPaths.length, entry.message.albumPhotoFileIds.length);
    for (let index = 0; index < count; index++) {
      const fileId = index < entry.message.albumPhotoFileIds.length ? entry.message.albumPhotoFileIds[index] : 0;
      const timelineDownloading = index < entry.message.albumPhotoDownloading.length
        ? entry.message.albumPhotoDownloading[index] : false;
      result.push(timelineDownloading || this.isMediaDownloadPending(fileId));
    }
    return result;
  }

  private effectiveAlbumPhotoDownloadFailed(entry: ChatTimelineEntryVO): boolean[] {
    const result: boolean[] = [];
    const count = Math.max(entry.message.albumPhotoPaths.length, entry.message.albumPhotoFileIds.length);
    for (let index = 0; index < count; index++) {
      const fileId = index < entry.message.albumPhotoFileIds.length ? entry.message.albumPhotoFileIds[index] : 0;
      result.push(this.isMediaDownloadFailed(fileId));
    }
    return result;
  }

  private syncResolvedPendingDownloads(entries: ChatTimelineEntryVO[]): void {
    this.mediaDownloadCtrl.syncResolvedDownloads(entries);
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
  }

  private rememberPendingMediaOpenIntent(kind: PendingMediaOpenKind, fileId: number, messageId: string,
    mimeType: string = ''): void {
    this.pendingMediaOpenIntent.set(kind, fileId, messageId, mimeType, this.activeChatId, this.pageLifecycleToken);
  }

  private clearPendingMediaOpenIntent(fileId: number): void {
    if (this.pendingMediaOpenIntent.matchesFile(fileId)) {
      this.pendingMediaOpenIntent.reset();
    }
  }

  private fulfillPendingMediaOpenIntent(entries: ChatTimelineEntryVO[]): void {
    const resolution: PendingMediaOpenResolution | undefined =
      resolvePendingMediaOpenIntent(this.pendingMediaOpenIntent, entries, this.activeChatId, this.pageLifecycleToken);
    if (!resolution) {
      return;
    }
    this.pendingMediaOpenIntent.reset();
    if (resolution.kind === 'document') {
      this.openDocumentFile(resolution.path, resolution.mimeType);
      return;
    }
    if (resolution.kind === 'audio') {
      this.handleAudioTap(resolution.path, resolution.fileId, resolution.mimeType, resolution.messageId);
      return;
    }
    this.handleVoiceTap(resolution.messageId, resolution.path, resolution.fileId);
  }


  private handleVoiceTap(messageId: string, voicePath: string, voiceFileId: number): void {
    if (voicePath.trim().length === 0) {
      if (voiceFileId > 0) {
        this.rememberPendingMediaOpenIntent('voice', voiceFileId, messageId);
        this.requestMediaDownload(voiceFileId);
      }
      return;
    }
    this.clearPendingMediaOpenIntent(voiceFileId);
    if (!this.mediaPlaybackController) {
      this.setupMediaPlaybackController();
    }
    this.locallyListenedVoiceIds.add(messageId);
    const controller = this.mediaPlaybackController;
    if (!controller) {
      return;
    }
    controller.toggle(messageId, voicePath, 'voice')
      .catch((_error: Object) => {});
  }


  private openAudioFile(audioPath: string, mimeType: string): void {
    if (audioPath.trim().length === 0) {
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: audioPath,
        type: mimeType.trim().length > 0 ? mimeType : 'audio/*',
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION |
          wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION
      };
      context.startAbility(want)
        .catch((_error: Object) => {});
    } catch (_error) {}
  }

  private openDocumentFile(documentPath: string, mimeType: string): void {
    if (documentPath.trim().length === 0) {
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const normalizedMimeType = mimeType.trim().length > 0 ? mimeType : 'application/octet-stream';
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: documentPath,
        type: normalizedMimeType,
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION |
          wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION
      };
      const openExternal = (): void => {
        context.startAbility(want)
          .catch((error: Object): void => {
            hilog.warn(DOMAIN, TAG, 'Document viewer start failed: %{public}s', String(error));
          });
      };
      const lastSeparator = Math.max(documentPath.lastIndexOf('/'), documentPath.lastIndexOf('\\'));
      const previewInfo: filePreview.PreviewInfo = {
        title: lastSeparator >= 0 ? documentPath.substring(lastSeparator + 1) : 'Document',
        uri: documentPath,
        mimeType: normalizedMimeType
      };
      filePreview.canPreview(context, documentPath)
        .then((supported: boolean): void => {
          if (!supported) {
            openExternal();
            return;
          }
          filePreview.openPreview(context, previewInfo)
            .catch((_error: Object): void => {
              openExternal();
            });
        })
        .catch((_error: Object): void => {
          openExternal();
        });
    } catch (_error) {}
  }

  private handleDocumentTap(documentPath: string, documentFileId: number, mimeType: string,
    messageId: string = '0'): void {
    if (documentPath.trim().length === 0) {
      if (documentFileId > 0) {
        this.rememberPendingMediaOpenIntent('document', documentFileId, messageId, mimeType);
        this.requestMediaDownload(documentFileId);
      }
      return;
    }
    this.clearPendingMediaOpenIntent(documentFileId);
    this.openDocumentFile(documentPath, mimeType);
  }

  private handleAudioTap(audioPath: string, audioFileId: number, mimeType: string, messageId: string = '0'): void {
    if (audioPath.trim().length === 0) {
      if (audioFileId > 0) {
        this.rememberPendingMediaOpenIntent('audio', audioFileId, messageId, mimeType);
        this.requestMediaDownload(audioFileId);
      }
      return;
    }
    this.clearPendingMediaOpenIntent(audioFileId);
    // Inline playback via unified MediaPlaybackController (like Telegram iOS/Android)
    if (!this.mediaPlaybackController) {
      this.setupMediaPlaybackController();
    }
    const controller = this.mediaPlaybackController;
    if (!controller) {
      return;
    }
    // MediaPlaybackController uses fs.openSync which needs raw sandbox path, not file:// URI.
    // documentPath arrives as file:// URI (needed for Want-based file opening),
    // so convert back to raw path for playback.
    let rawPath = audioPath;
    if (rawPath.startsWith('file://')) {
      try {
        rawPath = new fileUri.FileUri(rawPath).path;
      } catch (_e) {
        rawPath = audioPath;
      }
    }
    controller.toggle(messageId, rawPath, 'audio')
      .catch((_error: Object) => {});
  }

  private handleAudioSeek(messageId: string, progress: number): void {
    const controller = this.mediaPlaybackController;
    if (!controller || controller.getActiveMessageId() !== messageId) {
      return;
    }
    controller.seekToProgress(progress).catch((_error: Object) => {});
  }

  private handleVoiceSeek(messageId: string, progress: number): void {
    const controller = this.mediaPlaybackController;
    if (!controller || controller.getActiveMessageId() !== messageId) {
      return;
    }
    controller.seekToProgress(progress).catch((_error: Object) => {});
  }

  private buildMediaGalleryItems(): MediaGalleryItem[] {
    const items: MediaGalleryItem[] = [];
    const entries = this.dataSource.getAllEntries();
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.kind !== 'message') continue;
      const ct = entry.message.contentType;
      if (ct === 'photo' || ct === 'video' || ct === 'animation' || ct === 'videoNote' || ct === 'photoAlbum') {
        if (ct === 'photoAlbum') {
          for (let j = 0; j < entry.message.albumPhotoPaths.length; j++) {
            const albumItem = new MediaGalleryItem();
            const albumFileId = j < entry.message.albumPhotoFileIds.length ? entry.message.albumPhotoFileIds[j] : 0;
            const albumHasLocal = j < entry.message.albumPhotoHasLocal.length ? entry.message.albumPhotoHasLocal[j] : false;
            albumItem.type = 'photo';
            albumItem.path = albumHasLocal ? entry.message.albumPhotoPaths[j] : '';
            albumItem.thumbnailPath = entry.message.albumPhotoPaths[j];
            albumItem.minithumb = j < entry.message.albumPhotoMinithumbs.length
              ? entry.message.albumPhotoMinithumbs[j] : '';
            albumItem.caption = j === 0 ? entry.message.caption : '';
            albumItem.senderName = entry.message.senderName;
            albumItem.timestamp = entry.message.timeText;
            albumItem.width = j < entry.message.albumPhotoWidths.length ? entry.message.albumPhotoWidths[j] : 0;
            albumItem.height = j < entry.message.albumPhotoHeights.length ? entry.message.albumPhotoHeights[j] : 0;
            albumItem.fileId = albumFileId;
            const memberMessageId = j < entry.message.sourceMessageIds.length
              ? entry.message.sourceMessageIds[j] : '';
            albumItem.messageId = albumMediaSourceId(entry.message.messageId, memberMessageId, j);
            albumItem.sourceMessageId = albumItem.messageId;
            albumItem.isDownloading =
              (j < entry.message.albumPhotoDownloading.length ? entry.message.albumPhotoDownloading[j] : false) ||
                this.isMediaDownloadPending(albumFileId);
            albumItem.isDownloadFailed = this.isMediaDownloadFailed(albumFileId);
            albumItem.downloadProgress =
              j < entry.message.albumPhotoDownloadProgress.length ? entry.message.albumPhotoDownloadProgress[j] : -1;
            items.push(albumItem);
          }
        } else {
          const item = new MediaGalleryItem();
          const fileId = ct === 'photo' ? entry.message.photoFileId : entry.message.videoFileId;
          item.type = ct;
          item.path = ct === 'photo'
            ? (entry.message.hasLocalPhoto ? entry.message.photoPath : '')
            : entry.message.videoPath;
          item.thumbnailPath = ct === 'photo' ? entry.message.photoPath : entry.message.videoThumbPath;
          item.minithumb = ct === 'photo' ? entry.message.photoMinithumb : entry.message.videoMinithumb;
          item.caption = entry.message.caption;
          item.senderName = entry.message.senderName;
          item.timestamp = entry.message.timeText;
          item.width = ct === 'photo' ? entry.message.photoWidth : entry.message.videoWidth;
          item.height = ct === 'photo' ? entry.message.photoHeight : entry.message.videoHeight;
          item.durationSec = entry.message.videoDuration;
          item.fileId = fileId;
          item.messageId = entry.message.messageId;
          item.sourceMessageId = entry.message.messageId;
          item.isDownloading = (ct === 'photo' ? entry.message.isPhotoDownloading : entry.message.isVideoDownloading) ||
            this.isMediaDownloadPending(fileId);
          item.isDownloadFailed = this.isMediaDownloadFailed(fileId);
          item.downloadProgress = ct === 'photo' ? entry.message.photoDownloadProgress : entry.message.videoDownloadProgress;
          items.push(item);
        }
      }
    }
    return items;
  }

  private handleMediaGalleryOpen(messageId: string): void {
    const items = this.buildMediaGalleryItems();
    if (items.length === 0) return;
    let targetIndex = 0;
    const entries = this.dataSource.getAllEntries();
    let mediaIndex = 0;
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.kind !== 'message') continue;
      const ct = entry.message.contentType;
      if (ct === 'photo' || ct === 'video' || ct === 'animation' || ct === 'videoNote') {
        if (entry.message.messageId === messageId) {
          targetIndex = mediaIndex;
          break;
        }
        mediaIndex++;
      } else if (ct === 'photoAlbum') {
        let memberIndex = -1;
        for (let j = 0; j < entry.message.albumPhotoPaths.length; j++) {
          const memberMessageId = j < entry.message.sourceMessageIds.length
            ? entry.message.sourceMessageIds[j] : '';
          if (albumMediaSourceId(entry.message.messageId, memberMessageId, j) === messageId) {
            memberIndex = j;
            break;
          }
        }
        if (entry.message.messageId === messageId || memberIndex >= 0) {
          targetIndex = mediaIndex + Math.max(0, memberIndex);
          break;
        }
        mediaIndex += entry.message.albumPhotoPaths.length;
      }
    }
    this.galleryItems = items;
    this.galleryInitialIndex = Math.min(targetIndex, items.length - 1);
    this.galleryCurrentIndex = this.galleryInitialIndex;
    const sourceMessageId = items[this.galleryInitialIndex].sourceMessageId;
    this.animateMediaGalleryState(true, sourceMessageId);
  }

  private animateMediaGalleryState(isVisible: boolean, sourceMessageId: string = '0'): void {
    const normalizedSourceMessageId = isVisible && sourceMessageId.trim().length > 0 ? sourceMessageId : '0';
    this.getUIContext().animateTo({
      curve: curves.responsiveSpringMotion(
        TgUiTokens.MEDIA_GALLERY_GEOMETRY_RESPONSE,
        TgUiTokens.MEDIA_GALLERY_GEOMETRY_DAMPING,
        TgUiTokens.MEDIA_GALLERY_GEOMETRY_OVERLAP
      )
    }, () => {
      this.gallerySourceMessageId = normalizedSourceMessageId;
      this.showMediaGallery = isVisible;
    });
  }

  private refreshOpenMediaGalleryItems(): void {
    if (!this.showMediaGallery) {
      return;
    }
    const result = resolveRefreshedMediaGalleryState(
      this.galleryItems,
      this.galleryCurrentIndex,
      this.buildMediaGalleryItems()
    );
    if (result.shouldClose) {
      this.galleryItems = [];
      this.galleryInitialIndex = 0;
      this.galleryCurrentIndex = 0;
      this.animateMediaGalleryState(false);
      return;
    }
    this.gallerySourceMessageId = result.sourceMessageId.trim().length > 0 ? result.sourceMessageId : '0';
    this.galleryItems = result.items;
    this.galleryCurrentIndex = result.currentIndex;
    this.galleryInitialIndex = result.currentIndex;
  }

  @Builder
  private buildMediaGallery() {
    TgMediaGalleryPage({
      mediaItems: this.galleryItems,
      initialIndex: this.galleryCurrentIndex,
      downloadStateVersion: this.pendingMediaDownloadVersion,
      statusBarHeight: Math.max(0, this.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT - TgUiTokens.TOP_BAR_BOTTOM_PADDING),
      onDismiss: (): void => {
        this.animateMediaGalleryState(false);
      },
      onIndexChange: (index: number): void => {
        this.galleryCurrentIndex = index;
        if (index >= 0 && index < this.galleryItems.length) {
          this.gallerySourceMessageId = this.galleryItems[index].sourceMessageId;
        }
      },
      onDownloadRequest: (fileId: number): void => {
        this.requestMediaDownload(fileId);
      },
      onDownloadCancel: (fileId: number): void => {
        this.cancelMediaDownload(fileId);
      }
    })
  }

  private startReply(messageId: string, author: string, preview: string, isQuote: boolean = false): void {
    this.messageActionsCtrl.startReply(messageId, author, preview, isQuote, this);
  }


  private cancelReply(): void {
    this.messageActionsCtrl.cancelReply(this);
  }



  private applyPendingForwardTransferIfNeeded(): void {
    this.messageActionsCtrl.applyPendingForwardTransferIfNeeded(this);
  }

  requestOpenChatData(chatId: number): void {
    const openChatUseCase = this.openChatUseCase;
    if (!openChatUseCase || chatId === 0) {
      return;
    }
    const lifecycleToken: number = this.pageLifecycleToken;
    openChatUseCase.execute({
      chatId: chatId,
      loadMessages: true,
      limit: 50
    }).catch((error: Object) => {
      if (lifecycleToken !== this.pageLifecycleToken || this.openChatUseCase !== openChatUseCase) {
        return;
      }
      hilog.warn(DOMAIN, TAG, 'openChat flow failed: %{public}s', String(error));
    });
  }

  private startForwardMessages(messageIds: string[], author: string, preview: string, fromChatId: number): void {
    this.messageActionsCtrl.startForwardMessages(messageIds, author, preview, fromChatId,
      this);
  }

  private cancelForwardMessages(): void {
    this.messageActionsCtrl.cancelForwardMessages(this);
  }

  private openForwardTargetPicker(messageIds: string[], author: string, preview: string): void {
    this.messageActionsCtrl.openForwardTargetPicker(messageIds, author, preview, this);
  }

  private copyMessageText(text: string): void {
    this.messageActionsCtrl.copyMessageText(text, this);
  }

  private effectiveVoiceListened(entry: ChatTimelineEntryVO): boolean {
    return entry.message.isVoiceListened || this.locallyListenedVoiceIds.has(entry.message.messageId);
  }

  private isActiveVoiceEntry(entry: ChatTimelineEntryVO): boolean {
    return this.activeVoiceMessageId === entry.message.messageId;
  }

  private isActiveAudioEntry(entry: ChatTimelineEntryVO): boolean {
    return this.activeAudioMessageId === entry.message.messageId;
  }

  private showMessageActions(entry: ChatTimelineEntryVO): void {
    this.botMenuOpen = false;
    this.messageActionsEntry = entry;
    this.messageActionsOpenId = entry.message.messageId;
  }

  private messageActionItems(): ChatMessageActionItem[] {
    if (this.messageActionsEntry === undefined) {
      return [];
    }
    return this.messageActionsCtrl.buildMessageActionItems(this.messageActionsEntry);
  }

  private messageActionsPopupWidth(): number {
    return Math.min(260, this.timelineContainerWidth - TgUiTokens.COMPOSER_SIDE_INSET * 2);
  }

  private messageActionsPopupHeight(): number {
    return Math.min(this.messageActionItems().length, TgUiTokens.COMPOSER_BOT_POPUP_MAX_VISIBLE_ROWS) *
      TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT;
  }

  private handleMessageActionPress(index: number): void {
    const entry = this.messageActionsEntry;
    this.messageActionsOpenId = '';
    this.messageActionsEntry = undefined;
    if (entry === undefined) {
      return;
    }
    this.messageActionsCtrl.handleMessageActionPress(index, entry, this);
  }

  @Builder
  private buildMessageActionsPopup() {
    List() {
      ForEach(this.messageActionItems(), (item: ChatMessageActionItem, index: number) => {
        ListItem() {
          Column() {
            Row() {
              Text(item.title)
                .fontSize(TgUiTokens.COMPOSER_BOT_POPUP_PRIMARY_TEXT_SIZE)
                .fontWeight(FontWeight.Regular)
                .fontColor(item.destructive ? TgUiTokens.COLOR_TEXT_ERROR : TgUiTokens.COLOR_TEXT_TITLE)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .height(TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT -
              TgUiTokens.COMPOSER_BOT_POPUP_SEPARATOR_WIDTH)
            .padding({
              left: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H,
              right: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H
            })
            .alignItems(VerticalAlign.Center)

            Divider()
              .height(TgUiTokens.COMPOSER_BOT_POPUP_SEPARATOR_WIDTH)
              .color(index < this.messageActionItems().length - 1
                ? TgUiTokens.COLOR_SEPARATOR
                : Color.Transparent)
              .margin({ left: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H })
          }
          .width('100%')
          .height(TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT)
          .onClick(() => {
            this.handleMessageActionPress(index);
          })
        }
      }, (item: ChatMessageActionItem) => item.id)
    }
    .width(this.messageActionsPopupWidth())
    .height(this.messageActionsPopupHeight())
    .scrollBar(BarState.Off)
  }

  private handleSendMessage(text: string): void {
    this.composerCtrl.handleSendMessage(text, this);
  }

  private handleComposerAttachPress(): void {
    this.setEmojiPanelVisible(false);
    this.setStickerPanelVisible(false);
  }

  private handleAttachmentMenuOpenChange(isOpen: boolean): void {
    if (!isOpen) {
      return;
    }
    const token = ++this.attachmentRecentLoadToken;
    this.attachmentRecentLoading = true;
    this.composerCtrl.loadRecentAttachmentMedia(this)
      .then((items: TgAttachmentRecentItem[]) => {
        if (token !== this.attachmentRecentLoadToken) {
          return;
        }
        this.attachmentRecentItems = items;
      })
      .catch((error: Error) => {
        hilog.warn(DOMAIN, TAG, 'Attachment recent UI load failed: %{public}s', error.message);
      })
      .finally(() => {
        if (token === this.attachmentRecentLoadToken) {
          this.attachmentRecentLoading = false;
        }
      });
  }

  private composerKeyboardPanelVisible(): boolean {
    return this.showComposerEmojiPanel || this.showComposerStickerPanel;
  }

  private composerAttachmentMenuLabels(): string[] {
    return [
      localized($r('app.string.attach_camera').id, 'Camera'),
      localized($r('app.string.photo').id, 'Photo'),
      localized($r('app.string.video').id, 'Video'),
      localized($r('app.string.document_label').id, 'Document')
    ];
  }

  private handleComposerAttachmentMenuItemPress(index: number): void {
    this.composerCtrl.handleAttachmentMenuItemPress(index, this);
  }

  private handleAttachmentRecentPress(item: TgAttachmentRecentItem): void {
    this.composerCtrl.handleRecentAttachmentPress(item, this);
  }

  private handleComposerEmojiPress(): void {
    this.composerCtrl.handleEmojiPress(this);
  }

  private handleComposerKeyboardModePress(): void {
    this.setEmojiPanelVisible(false);
    this.setStickerPanelVisible(false);
  }

  private handleComposerVoicePress(): void {
    this.composerCtrl.handleVoicePress(this);
  }

  private handleVoiceRecordStart(): void {
    this.setEmojiPanelVisible(false);
    this.setStickerPanelVisible(false);
    this.voiceRecordingCtrl.begin(this);
  }

  private handleVoiceRecordSend(): void {
    this.voiceRecordingCtrl.finishAndSend(this);
  }

  private handleVoiceRecordCancel(): void {
    this.voiceRecordingCtrl.cancel(this);
  }

  private handleVoiceRecordLock(): void {
    this.voiceRecordingCtrl.lock(this);
  }

  private handleComposerEmojiSelected(emoji: string): void {
    this.composerCtrl.handleEmojiSelected(emoji, this);
    this.scheduleDraftDebounce();
  }

  private handleComposerSelectionChange(start: number, end: number): void {
    this.composerSelectionStart = Math.max(0, Math.min(this.composerDraftText.length, start));
    this.composerSelectionEnd = Math.max(0, Math.min(this.composerDraftText.length, end));
  }

  private handleCustomEmojiSelected(item: CustomEmojiCellVO): void {
    this.composerCtrl.handleCustomEmojiSelected(item.fallbackEmoji, item.customEmojiId, this);
    this.scheduleDraftDebounce();
  }

  private toCustomEmojiCellVO(entry: StickerPanelEntry): CustomEmojiCellVO | undefined {
    if (entry.customEmojiId === '0' || entry.emoji.length === 0) {
      return undefined;
    }
    const cell = new CustomEmojiCellVO(entry.customEmojiId, entry.emoji, entry.fileId,
      entry.thumbFileId, entry.isAnimated, entry.isVideo);
    if (entry.localPath.length > 0) {
      cell.pathUri = fileUri.getUriFromPath(entry.localPath);
    }
    if (entry.thumbPath.length > 0) {
      cell.thumbPathUri = fileUri.getUriFromPath(entry.thumbPath);
    }
    return cell;
  }

  private async fetchCustomEmojiFiles(cells: CustomEmojiCellVO[], tabId: string): Promise<void> {
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const token = this.pageLifecycleToken;
    for (const cell of cells) {
      if (token !== this.pageLifecycleToken || this.activeCustomEmojiPackId !== tabId) {
        return;
      }
      if (cell.thumbPathUri.length === 0 && cell.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(cell.thumbFileId);
        if (path.length > 0) {
          cell.thumbPathUri = fileUri.getUriFromPath(path);
        }
      }
      if (cell.pathUri.length === 0 && !cell.isAnimated && !cell.isVideo && cell.fileId > 0) {
        const path = await useCase.downloadStickerFile(cell.fileId);
        if (path.length > 0) {
          cell.pathUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

  private async fetchCustomEmojiTabThumbs(tabs: CustomEmojiPackTabVO[]): Promise<void> {
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const token = this.pageLifecycleToken;
    for (const tab of tabs) {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      if (tab.tabId !== 'unicode' && tab.thumbUri.length === 0 && tab.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(tab.thumbFileId);
        if (path.length > 0) {
          tab.thumbUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

  private loadCustomEmojiPanelIfNeeded(): void {
    const useCase = this.stickerPanelUseCase;
    if (!useCase || this.customEmojiPanelLoadedOnce || this.customEmojiPanelLoading) {
      return;
    }
    this.customEmojiPackTabs = [new CustomEmojiPackTabVO('unicode',
      localized($r('app.string.emoji_tab').id, 'Emoji'), 0, '')];
    this.customEmojiPanelLoading = true;
    const token = this.pageLifecycleToken;
    const trendingPromise: Promise<StickerSetInfoEntry[]> = useCase.loadTrendingCustomEmojiSets(0, 12)
      .catch((error: Error): StickerSetInfoEntry[] => {
        hilog.warn(DOMAIN, TAG, 'Trending custom emoji packs load failed: %{public}s', error.message);
        return [];
      });
    const requests: Promise<StickerSetInfoEntry[]>[] = [
      useCase.loadInstalledCustomEmojiSets(),
      trendingPromise
    ];
    Promise.all(requests).then((sources: StickerSetInfoEntry[][]) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      const tabs: CustomEmojiPackTabVO[] = [new CustomEmojiPackTabVO('unicode',
        localized($r('app.string.emoji_tab').id, 'Emoji'), 0, '')];
      const addedSetIds: Set<string> = new Set<string>();
      for (const sets of sources) {
        for (const set of sets) {
          if (addedSetIds.has(set.setId)) {
            continue;
          }
          addedSetIds.add(set.setId);
          const tab = new CustomEmojiPackTabVO(set.setId, set.title, set.thumbFileId, set.coverEmoji);
          if (set.thumbPath.length > 0) {
            tab.thumbUri = fileUri.getUriFromPath(set.thumbPath);
          }
          tabs.push(tab);
        }
      }
      this.customEmojiPackTabs = tabs;
      this.customEmojiPanelLoading = false;
      this.customEmojiPanelLoadedOnce = true;
      this.fetchCustomEmojiTabThumbs(tabs);
    }).catch((error: Error) => {
      if (token === this.pageLifecycleToken) {
        this.customEmojiPanelLoading = false;
      }
      hilog.warn(DOMAIN, TAG, 'Custom emoji packs load failed: %{public}s', error.message);
    });
  }

  private handleCustomEmojiTabSelected(tabId: string): void {
    if (this.activeCustomEmojiPackId === tabId) {
      return;
    }
    this.activeCustomEmojiPackId = tabId;
    if (tabId === 'unicode') {
      this.customEmojiPanelItems = [];
      this.customEmojiPanelLoading = false;
      return;
    }
    const cached = this.customEmojiSetCache.get(tabId);
    if (cached !== undefined) {
      this.customEmojiPanelItems = cached;
      this.fetchCustomEmojiFiles(cached, tabId);
      return;
    }
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    this.customEmojiPanelItems = [];
    this.customEmojiPanelLoading = true;
    const token = this.pageLifecycleToken;
    useCase.loadStickerSet(tabId).then((entries: StickerPanelEntry[]) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      const cells: CustomEmojiCellVO[] = [];
      for (const entry of entries) {
        const cell = this.toCustomEmojiCellVO(entry);
        if (cell !== undefined) {
          cells.push(cell);
        }
      }
      this.customEmojiSetCache.set(tabId, cells);
      this.customEmojiPanelLoading = false;
      if (this.activeCustomEmojiPackId === tabId) {
        this.customEmojiPanelItems = cells;
        this.fetchCustomEmojiFiles(cells, tabId);
      }
    }).catch((error: Error) => {
      if (token === this.pageLifecycleToken) {
        this.customEmojiPanelLoading = false;
      }
      hilog.warn(DOMAIN, TAG, 'Custom emoji pack load failed: %{public}s', error.message);
    });
  }

  private emojiSearchLanguageCodes(): string[] {
    const codes: string[] = [];
    try {
      const locale = Intl.DateTimeFormat().resolvedOptions().locale;
      if (locale && locale.length > 0) {
        codes.push(locale);
      }
    } catch (_) {
    }
    if (codes.length === 0 || !codes[0].toLowerCase().startsWith('en')) {
      codes.push('en-US');
    }
    return codes;
  }

  private resetEmojiSearchState(): void {
    if (this.emojiSearchDebounceTimerId >= 0) {
      clearTimeout(this.emojiSearchDebounceTimerId);
      this.emojiSearchDebounceTimerId = -1;
    }
    this.emojiSearchRequestId++;
    this.emojiSearchQuery = '';
    this.emojiSearchUnicodeResults = [];
    this.emojiSearchCustomItems = [];
    this.emojiSearchLoading = false;
  }

  private handleEmojiSearchQueryChange(query: string): void {
    if (this.emojiSearchDebounceTimerId >= 0) {
      clearTimeout(this.emojiSearchDebounceTimerId);
      this.emojiSearchDebounceTimerId = -1;
    }
    const normalized = query.trim();
    const requestId = ++this.emojiSearchRequestId;
    this.emojiSearchQuery = normalized;
    this.emojiSearchUnicodeResults = [];
    this.emojiSearchCustomItems = [];
    if (normalized.length < 2) {
      this.emojiSearchLoading = false;
      return;
    }
    this.emojiSearchLoading = true;
    const lifecycleToken = this.pageLifecycleToken;
    this.emojiSearchDebounceTimerId = setTimeout(() => {
      this.emojiSearchDebounceTimerId = -1;
      const useCase = this.stickerPanelUseCase;
      if (!useCase || lifecycleToken !== this.pageLifecycleToken ||
        requestId !== this.emojiSearchRequestId || !this.showComposerEmojiPanel) {
        return;
      }
      useCase.searchEmojiKeyboard(normalized, this.emojiSearchLanguageCodes())
        .then((result: EmojiKeyboardSearchResult) => {
          if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.emojiSearchRequestId ||
            normalized !== this.emojiSearchQuery || !this.showComposerEmojiPanel) {
            return;
          }
          const customItems: CustomEmojiCellVO[] = [];
          for (const entry of result.customEmoji) {
            const cell = this.toCustomEmojiCellVO(entry);
            if (cell !== undefined) {
              customItems.push(cell);
            }
          }
          this.emojiSearchUnicodeResults = result.unicodeEmoji;
          this.emojiSearchCustomItems = customItems;
          this.emojiSearchLoading = false;
          this.fetchEmojiSearchFiles(customItems, requestId);
        })
        .catch((error: Error) => {
          if (requestId === this.emojiSearchRequestId) {
            this.emojiSearchLoading = false;
          }
          hilog.warn(DOMAIN, TAG, 'Emoji keyboard search failed: %{public}s', error.message);
        });
    }, EMOJI_SEARCH_DEBOUNCE_MS) as number;
  }

  private async fetchEmojiSearchFiles(cells: CustomEmojiCellVO[], requestId: number): Promise<void> {
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    for (const cell of cells) {
      if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.emojiSearchRequestId ||
        !this.showComposerEmojiPanel) {
        return;
      }
      if (cell.thumbPathUri.length === 0 && cell.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(cell.thumbFileId);
        if (path.length > 0) {
          cell.thumbPathUri = fileUri.getUriFromPath(path);
        }
      }
      if (cell.pathUri.length === 0 && !cell.isAnimated && !cell.isVideo && cell.fileId > 0) {
        const path = await useCase.downloadStickerFile(cell.fileId);
        if (path.length > 0) {
          cell.pathUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

  private handleComposerStickerPress(): void {
    this.handleComposerStickerModePress();
  }

  private handleComposerStickerModePress(): void {
    this.setEmojiPanelVisible(false);
    this.setStickerPanelVisible(true);
    this.loadStickerPanelIfNeeded();
    if (this.activeStickerTabId === 'gifs') {
      this.resetGifSearchState();
      this.handleStickerTabSelected('recent');
    }
  }

  private handleComposerGifPress(): void {
    this.setEmojiPanelVisible(false);
    this.setStickerPanelVisible(true);
    this.resetStickerSearchState();
    this.loadStickerPanelIfNeeded();
    this.handleStickerTabSelected('gifs');
  }

  private toStickerCellVO(entry: StickerPanelEntry): StickerCellVO {
    const cell = new StickerCellVO(entry.stickerId, entry.remoteFileId, entry.fileId,
      entry.thumbFileId, entry.emoji, entry.isAnimated, entry.isVideo, entry.width, entry.height);
    if (entry.localPath.length > 0) {
      cell.pathUri = fileUri.getUriFromPath(entry.localPath);
    }
    if (entry.thumbPath.length > 0) {
      cell.thumbPathUri = fileUri.getUriFromPath(entry.thumbPath);
    }
    return cell;
  }

  private toGifCellVO(entry: GifPanelEntry): StickerCellVO {
    const cellId = entry.inlineResultId.length > 0
      ? 'gif_inline_' + entry.inlineQueryId + '_' + entry.inlineResultId
      : 'gif_' + entry.remoteFileId;
    const cell = new StickerCellVO(cellId, entry.remoteFileId, entry.fileId,
      entry.thumbFileId, '', false, true, entry.width, entry.height);
    cell.isGif = true;
    cell.duration = entry.duration;
    cell.inlineQueryId = entry.inlineQueryId;
    cell.inlineResultId = entry.inlineResultId;
    if (entry.minithumbnailData.length > 0) {
      cell.minithumbnailUri = 'data:image/jpeg;base64,' + entry.minithumbnailData;
    }
    if (entry.thumbPath.length > 0) {
      cell.thumbPathUri = fileUri.getUriFromPath(entry.thumbPath);
    }
    return cell;
  }

  // Fills missing preview files one by one (a pack can hold 100+ stickers —
  // parallel downloadFile calls would storm TDLib). Stops when the user
  // leaves the tab or the page dies.
  private async fetchStickerPanelFiles(cells: StickerCellVO[], tabId: string): Promise<void> {
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const token = this.pageLifecycleToken;
    for (const cell of cells) {
      if (token !== this.pageLifecycleToken || this.activeStickerTabId !== tabId) {
        return;
      }
      if (cell.thumbPathUri.length === 0 && cell.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(cell.thumbFileId);
        if (path.length > 0) {
          cell.thumbPathUri = fileUri.getUriFromPath(path);
        }
      }
      if (cell.pathUri.length === 0 && !cell.isAnimated && !cell.isVideo && cell.fileId > 0) {
        const path = await useCase.downloadStickerFile(cell.fileId);
        if (path.length > 0) {
          cell.pathUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

  private async fetchStickerTabThumbs(tabs: StickerSetTabVO[]): Promise<void> {
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const token = this.pageLifecycleToken;
    for (const tab of tabs) {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      if (tab.thumbUri.length === 0 && tab.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(tab.thumbFileId);
        if (path.length > 0) {
          tab.thumbUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

  private loadStickerPanelIfNeeded(): void {
    const useCase = this.stickerPanelUseCase;
    this.loadPremiumStickerHomeIfNeeded();
    this.loadFavoriteStickerTab();
    if (!useCase || this.stickerPanelLoadedOnce || this.stickerPanelLoading) {
      return;
    }
    this.stickerPanelLoading = true;
    const token = this.pageLifecycleToken;
    useCase.loadRecentStickers().then((entries: StickerPanelEntry[]) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(this.toStickerCellVO(entry));
      }
      this.stickerSetCache.set('recent', cells);
      if (this.activeStickerTabId === 'recent') {
        this.stickerPanelItems = cells;
      }
      this.stickerPanelLoading = false;
      this.stickerPanelLoadedOnce = true;
      this.fetchStickerPanelFiles(cells, 'recent');
    }).catch(() => {
      if (token === this.pageLifecycleToken) {
        this.stickerPanelLoading = false;
      }
    });
  }

  private resetStickerSearchState(): void {
    if (this.stickerSearchDebounceTimerId >= 0) {
      clearTimeout(this.stickerSearchDebounceTimerId);
      this.stickerSearchDebounceTimerId = -1;
    }
    this.stickerSearchRequestId++;
    this.stickerSearchQuery = '';
    this.stickerSearchItems = [];
    this.stickerSearchLoading = false;
  }

  private handleStickerSearchQueryChange(query: string): void {
    if (this.stickerSearchDebounceTimerId >= 0) {
      clearTimeout(this.stickerSearchDebounceTimerId);
      this.stickerSearchDebounceTimerId = -1;
    }
    const normalized = query.trim();
    const requestId = ++this.stickerSearchRequestId;
    this.stickerSearchQuery = normalized;
    this.stickerSearchItems = [];
    if (normalized.length < 2 || this.activeStickerTabId === 'gifs') {
      this.stickerSearchLoading = false;
      return;
    }
    this.stickerSearchLoading = true;
    const lifecycleToken = this.pageLifecycleToken;
    this.stickerSearchDebounceTimerId = setTimeout(() => {
      this.stickerSearchDebounceTimerId = -1;
      const useCase = this.stickerPanelUseCase;
      if (!useCase || lifecycleToken !== this.pageLifecycleToken ||
        requestId !== this.stickerSearchRequestId || !this.showComposerStickerPanel ||
        this.activeStickerTabId === 'gifs') {
        return;
      }
      useCase.searchRegularStickers(normalized, this.emojiSearchLanguageCodes())
        .then((entries: StickerPanelEntry[]) => {
          if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.stickerSearchRequestId ||
            normalized !== this.stickerSearchQuery || !this.showComposerStickerPanel ||
            this.activeStickerTabId === 'gifs') {
            return;
          }
          const cells: StickerCellVO[] = [];
          for (const entry of entries) {
            cells.push(this.toStickerCellVO(entry));
          }
          this.stickerSearchItems = cells;
          this.stickerSearchLoading = false;
          this.fetchStickerSearchFiles(cells, requestId);
        })
        .catch((error: Error) => {
          if (requestId === this.stickerSearchRequestId) {
            this.stickerSearchLoading = false;
          }
          hilog.warn(DOMAIN, TAG, 'Sticker search failed: %{public}s', error.message);
        });
    }, STICKER_SEARCH_DEBOUNCE_MS) as number;
  }

  private async fetchStickerSearchFiles(cells: StickerCellVO[], requestId: number): Promise<void> {
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    for (const cell of cells) {
      if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.stickerSearchRequestId ||
        !this.showComposerStickerPanel || this.activeStickerTabId === 'gifs') {
        return;
      }
      if (cell.thumbPathUri.length === 0 && cell.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(cell.thumbFileId);
        if (path.length > 0) {
          cell.thumbPathUri = fileUri.getUriFromPath(path);
        }
      }
      if (cell.pathUri.length === 0 && !cell.isAnimated && !cell.isVideo && cell.fileId > 0) {
        const path = await useCase.downloadStickerFile(cell.fileId);
        if (path.length > 0) {
          cell.pathUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

  private applyGroupedStickerPreviewPath(cell: StickerCellVO, fileId: number, path: string): void {
    if (path.length === 0) {
      return;
    }
    const uri = fileUri.getUriFromPath(path);
    if (fileId === cell.thumbFileId) {
      cell.thumbPathUri = uri;
    } else if (!cell.isAnimated && !cell.isVideo) {
      cell.pathUri = uri;
    }
  }

  private refreshGroupedStickerHomePreviews(state: AppState): void {
    const cells: StickerCellVO[] = this.premiumStickerItems.concat(this.favoriteStickerItems);
    for (const cell of cells) {
      const fileId = cell.thumbFileId > 0 ? cell.thumbFileId : cell.fileId;
      if (fileId <= 0 || cell.previewUri().length > 0) {
        continue;
      }
      const transfer = state.files.transfers.get(fileId);
      if (transfer && transfer.isDownloadingCompleted && transfer.localPath.length > 0) {
        this.applyGroupedStickerPreviewPath(cell, fileId, transfer.localPath);
      }
    }
  }

  private requestGroupedStickerHomePreviews(cells: StickerCellVO[], visibleLimit: number): void {
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    if (cells.length > 0) {
      hilog.info(DOMAIN, TAG,
        'Grouped sticker previews cells=%{public}d firstFile=%{public}d firstThumb=%{public}d',
        Math.min(cells.length, visibleLimit), cells[0].fileId, cells[0].thumbFileId);
    }
    this.refreshGroupedStickerHomePreviews(getAppCoreRuntime().getStore().getState());
    const token = this.pageLifecycleToken;
    for (const cell of cells.slice(0, visibleLimit)) {
      const fileId = cell.thumbFileId > 0 ? cell.thumbFileId : cell.fileId;
      if (fileId <= 0 || cell.previewUri().length > 0 || this.groupedStickerPreviewRequests.has(fileId)) {
        continue;
      }
      this.groupedStickerPreviewRequests.add(fileId);
      useCase.requestStickerFileDownload(fileId, 16).then((path: string) => {
        if (token === this.pageLifecycleToken) {
          this.applyGroupedStickerPreviewPath(cell, fileId, path);
        }
      });
    }
  }

  private resetGifSearchState(): void {
    if (this.gifSearchDebounceTimerId >= 0) {
      clearTimeout(this.gifSearchDebounceTimerId);
      this.gifSearchDebounceTimerId = -1;
    }
    this.gifSearchRequestId++;
    this.gifSearchQuery = '';
    this.gifSearchNextOffset = '';
    this.gifSearchItems = [];
    this.gifSearchLoading = false;
    this.gifSearchHasMore = false;
    this.gifSearchPageLoading = false;
  }

  private handleGifSearchQueryChange(query: string): void {
    if (this.gifSearchDebounceTimerId >= 0) {
      clearTimeout(this.gifSearchDebounceTimerId);
      this.gifSearchDebounceTimerId = -1;
    }
    const normalized = query.trim();
    const requestId = ++this.gifSearchRequestId;
    this.gifSearchQuery = normalized;
    this.gifSearchNextOffset = '';
    this.gifSearchItems = [];
    this.gifSearchHasMore = false;
    this.gifSearchPageLoading = false;
    if (normalized.length === 0 || this.activeChatId === 0 || this.activeStickerTabId !== 'gifs') {
      this.gifSearchLoading = false;
      return;
    }
    this.gifSearchLoading = true;
    const lifecycleToken = this.pageLifecycleToken;
    this.gifSearchDebounceTimerId = setTimeout(() => {
      this.gifSearchDebounceTimerId = -1;
      const useCase = this.stickerPanelUseCase;
      if (!useCase || lifecycleToken !== this.pageLifecycleToken ||
        requestId !== this.gifSearchRequestId || normalized !== this.gifSearchQuery ||
        !this.showComposerStickerPanel || this.activeStickerTabId !== 'gifs') {
        return;
      }
      useCase.searchGifs(normalized, this.activeChatId)
        .then((page: GifSearchPage) => {
          if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.gifSearchRequestId ||
            normalized !== this.gifSearchQuery || !this.showComposerStickerPanel ||
            this.activeStickerTabId !== 'gifs') {
            return;
          }
          const cells: StickerCellVO[] = [];
          for (const entry of page.items) {
            cells.push(this.toGifCellVO(entry));
          }
          this.gifSearchItems = cells;
          this.gifSearchNextOffset = page.nextOffset;
          this.gifSearchHasMore = page.nextOffset.length > 0;
          this.gifSearchLoading = false;
          this.fetchGifSearchFiles(cells, requestId);
        })
        .catch((error: Error) => {
          if (requestId === this.gifSearchRequestId) {
            this.gifSearchLoading = false;
          }
          hilog.warn(DOMAIN, TAG, 'GIF search failed: %{public}s', error.message);
        });
    }, GIF_SEARCH_DEBOUNCE_MS) as number;
  }

  private loadMoreGifSearch(): void {
    const useCase = this.stickerPanelUseCase;
    const query = this.gifSearchQuery;
    const offset = this.gifSearchNextOffset;
    if (!useCase || query.length === 0 || offset.length === 0 || this.gifSearchLoading ||
      this.gifSearchPageLoading || !this.showComposerStickerPanel || this.activeStickerTabId !== 'gifs' ||
      this.activeChatId === 0) {
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    const requestId = this.gifSearchRequestId;
    this.gifSearchPageLoading = true;
    useCase.searchGifs(query, this.activeChatId, offset)
      .then((page: GifSearchPage) => {
        if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.gifSearchRequestId ||
          query !== this.gifSearchQuery || offset !== this.gifSearchNextOffset ||
          !this.showComposerStickerPanel || this.activeStickerTabId !== 'gifs') {
          return;
        }
        const knownIds: Set<string> = new Set<string>();
        for (const existing of this.gifSearchItems) {
          knownIds.add(existing.stickerId);
        }
        const appended: StickerCellVO[] = [];
        for (const entry of page.items) {
          const cell = this.toGifCellVO(entry);
          if (!knownIds.has(cell.stickerId)) {
            knownIds.add(cell.stickerId);
            appended.push(cell);
          }
        }
        this.gifSearchItems = this.gifSearchItems.concat(appended);
        this.gifSearchNextOffset = page.nextOffset;
        this.gifSearchHasMore = page.nextOffset.length > 0 && page.nextOffset !== offset;
        this.fetchGifSearchFiles(appended, requestId);
      })
      .catch((error: Error) => {
        hilog.warn(DOMAIN, TAG, 'GIF search pagination failed: %{public}s', error.message);
      })
      .finally(() => {
        if (requestId === this.gifSearchRequestId) {
          this.gifSearchPageLoading = false;
        }
      });
  }

  private async fetchGifSearchFiles(cells: StickerCellVO[], requestId: number): Promise<void> {
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    for (const cell of cells) {
      if (lifecycleToken !== this.pageLifecycleToken || requestId !== this.gifSearchRequestId ||
        !this.showComposerStickerPanel || this.activeStickerTabId !== 'gifs' ||
        this.gifSearchQuery.length === 0) {
        return;
      }
      if (cell.thumbPathUri.length === 0 && cell.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(cell.thumbFileId);
        if (path.length > 0) {
          cell.thumbPathUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

  private loadFavoriteStickerTab(): void {
    const useCase = this.stickerPanelUseCase;
    if (!useCase || this.favoriteStickerHomeLoading) {
      return;
    }
    if (this.favoriteStickerHomeLoaded) {
      this.requestGroupedStickerHomePreviews(this.favoriteStickerItems, 4);
      return;
    }
    this.favoriteStickerHomeLoading = true;
    const token = this.pageLifecycleToken;
    useCase.loadFavoriteStickers().then((entries: StickerPanelEntry[]) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(this.toStickerCellVO(entry));
      }
      this.favoriteStickerItems = cells;
      this.favoriteStickerHomeLoaded = true;
      this.favoriteStickerHomeLoading = false;
      if (cells.length > 0) {
        this.stickerSetCache.set('favorites', cells);
        this.requestGroupedStickerHomePreviews(cells, 4);
      }
      this.loadStickerSetTabs(cells.length > 0);
    }).catch(() => {
      if (token === this.pageLifecycleToken) {
        this.favoriteStickerHomeLoading = false;
        this.loadStickerSetTabs(false);
      }
    });
  }

  private loadPremiumStickerHomeIfNeeded(): void {
    const useCase = this.stickerPanelUseCase;
    if (!useCase || this.premiumStickerHomeLoading) {
      return;
    }
    if (this.premiumStickerHomeLoaded) {
      this.requestGroupedStickerHomePreviews(this.premiumStickerItems, 8);
      return;
    }
    this.premiumStickerHomeLoading = true;
    const token = this.pageLifecycleToken;
    useCase.loadPremiumStickers(16).then((entries: StickerPanelEntry[]) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(this.toStickerCellVO(entry));
      }
      this.premiumStickerItems = cells;
      this.premiumStickerHomeLoaded = true;
      this.premiumStickerHomeLoading = false;
      this.requestGroupedStickerHomePreviews(cells, 8);
    }).catch(() => {
      if (token === this.pageLifecycleToken) {
        this.premiumStickerHomeLoading = false;
      }
    });
  }

  private loadStickerSetTabs(includeFavorites: boolean): void {
    const useCase = this.stickerPanelUseCase;
    if (!useCase || this.stickerSetTabs.length > 0) {
      return;
    }
    const token = this.pageLifecycleToken;
    useCase.loadInstalledStickerSets().then((sets: StickerSetInfoEntry[]) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      const tabs: StickerSetTabVO[] = [];
      if (includeFavorites) {
        tabs.push(new StickerSetTabVO('favorites',
          localized($r('app.string.sticker_packs_favorites').id, 'Favorites'), 0, ''));
      }
      tabs.push(new StickerSetTabVO('recent',
        localized($r('app.string.sticker_packs_recent').id, 'Recent'), 0, ''));
      for (const set of sets) {
        const tab = new StickerSetTabVO(set.setId, set.title, set.thumbFileId, set.coverEmoji);
        if (set.thumbPath.length > 0) {
          tab.thumbUri = fileUri.getUriFromPath(set.thumbPath);
        }
        tabs.push(tab);
      }
      this.stickerSetTabs = tabs;
      this.fetchStickerTabThumbs(tabs);
    });
  }

  private handleStickerTabSelected(tabId: string): void {
    if (this.activeStickerTabId === tabId) {
      return;
    }
    this.activeStickerTabId = tabId;
    const cached = this.stickerSetCache.get(tabId);
    if (cached !== undefined) {
      this.stickerPanelItems = cached;
      this.fetchStickerPanelFiles(cached, tabId);
      return;
    }
    const useCase = this.stickerPanelUseCase;
    if (!useCase || tabId === 'recent') {
      return;
    }
    if (tabId === 'gifs') {
      this.loadGifPanel();
      return;
    }
    this.stickerPanelItems = [];
    this.stickerPanelLoading = true;
    const token = this.pageLifecycleToken;
    useCase.loadStickerSet(tabId).then((entries: StickerPanelEntry[]) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(this.toStickerCellVO(entry));
      }
      this.stickerSetCache.set(tabId, cells);
      this.stickerPanelLoading = false;
      if (this.activeStickerTabId === tabId) {
        this.stickerPanelItems = cells;
        this.fetchStickerPanelFiles(cells, tabId);
      }
    }).catch(() => {
      if (token === this.pageLifecycleToken) {
        this.stickerPanelLoading = false;
      }
    });
  }

  private loadGifPanel(): void {
    const useCase = this.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const cached = this.stickerSetCache.get('gifs');
    if (cached !== undefined) {
      this.stickerPanelItems = cached;
      this.fetchStickerPanelFiles(cached, 'gifs');
      return;
    }
    this.stickerPanelItems = [];
    this.stickerPanelLoading = true;
    const token = this.pageLifecycleToken;
    useCase.loadSavedAnimations().then((entries: GifPanelEntry[]) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(this.toGifCellVO(entry));
      }
      this.stickerSetCache.set('gifs', cells);
      this.stickerPanelLoading = false;
      if (this.activeStickerTabId === 'gifs') {
        this.stickerPanelItems = cells;
        this.fetchStickerPanelFiles(cells, 'gifs');
      }
    }).catch(() => {
      if (token === this.pageLifecycleToken) {
        this.stickerPanelLoading = false;
      }
    });
  }

  private handleStickerSelected(cell: StickerCellVO): void {
    const useCase = this.stickerPanelUseCase;
    if (!useCase || this.activeChatId === 0) {
      return;
    }
    if (cell.isGif) {
      const gifParams = new SendAnimationParams();
      gifParams.chatId = this.activeChatId;
      gifParams.remoteFileId = cell.remoteFileId;
      gifParams.duration = cell.duration;
      gifParams.width = cell.width;
      gifParams.height = cell.height;
      gifParams.inlineQueryId = cell.inlineQueryId;
      gifParams.inlineResultId = cell.inlineResultId;
      useCase.sendAnimation(gifParams);
      this.setStickerPanelVisible(false);
      return;
    }
    const params = new SendStickerParams();
    params.chatId = this.activeChatId;
    params.remoteFileId = cell.remoteFileId;
    params.width = cell.width;
    params.height = cell.height;
    params.emoji = cell.emoji;
    useCase.sendSticker(params);
    this.setStickerPanelVisible(false);
  }

  private clearPendingAttachment(): void {
    this.composerCtrl.clearPendingAttachment(this);
  }

  private startEditMessage(messageId: string, originalText: string): void {
    this.messageActionsCtrl.startEditMessage(messageId, originalText, this);
  }

  private cancelEditMessage(): void {
    this.messageActionsCtrl.cancelEditMessage(this);
  }

  private handleEditMessage(newText: string): void {
    this.messageActionsCtrl.handleEditMessage(newText, this);
  }

  private handleForwardMessages(commentText: string): void {
    this.messageActionsCtrl.handleForwardMessages(commentText, this);
  }

  private handlePinMessage(messageId: string): void {
    this.messageActionsCtrl.handlePinMessage(messageId, this);
  }

  private handleDeleteMessage(messageId: string): void {
    this.messageActionsCtrl.handleDeleteMessage(messageId, this);
  }

  private handleSearchQueryChange(query: string): void {
    this.searchCtrl.handleSearchQueryChange(query, this);
  }

  private openSearch(): void {
    this.isSearchMode = true;
    // The conditional TextInput exists on the next frame. FocusController is
    // the documented path that also opens the system IME for TextInput.
    this.scheduleLifecycleTask(16, () => {
      this.getUIContext().getFocusController().requestFocus(TG_CHAT_SEARCH_INPUT_ID);
    });
  }

  private closeSearch(): void {
    this.clearSearchFlash();
    this.searchCtrl.closeSearch(this);
  }

  private useSearchFlashOutline(entry: ChatTimelineEntryVO): boolean {
    return entry.kind === 'message' && entry.message.contentType === 'sticker';
  }

  // Telegram drafts: the composer text survives leaving the chat. Skips the
  // TDLib call when nothing changed vs the stored draft.
  private normalizedDraftCustomEmojiEntities(text: string): CustomEmojiTextEntity[] {
    return normalizeCustomEmojiEntitiesForSubstring(
      this.composerDraftText,
      text,
      this.customEmojiDraftEntities
    );
  }

  private persistDraft(chatId: number): void {
    // Leaving the chat mid-edit must not overwrite the server draft with
    // the edit buffer (same rule as scheduleDraftDebounce)
    if (chatId === 0 || this.isEditingMessage) {
      return;
    }
    const text = this.composerDraftText.trim();
    try {
      const chat = getAppCoreRuntime().getStore().getState().chats.chats.get(chatId);
      const storedDraft = chat ? chat.draftText.trim() : '';
      const storedReply = chat ? chat.draftReplyToMessageId : '0';
      const normalizedEntities = this.normalizedDraftCustomEmojiEntities(text);
      const storedEntities = chat ? chat.draftCustomEmojiEntities : [];
      // Empty text serializes as an explicit clear, so the reply id only
      // matters for the skip-check when there is text to keep
      if (text === storedDraft && customEmojiEntitiesEqual(normalizedEntities, storedEntities) &&
        (text.length === 0 || this.replyToMessageId === storedReply)) {
        return;
      }
      getTdGatewayAdapter().send(createSetChatDraftCommand(
        chatId, text, this.replyToMessageId, normalizedEntities))
        .then((response: Object) => {
          const obj = response as TdObject;
          hilog.info(DOMAIN, TAG, 'Draft response: %{public}s', obj.getType());
        })
        .catch((error: Error) => {
          hilog.warn(DOMAIN, TAG, 'Draft send failed: %{public}s', error.message);
        });
      hilog.info(DOMAIN, TAG, 'Draft %{public}s for chat %{public}d',
        text.length > 0 ? 'saved' : 'cleared', chatId);
    } catch (_e) {
    }
  }

  private restoreDraftFromChat(): void {
    if (this.activeChatId === 0 || this.composerDraftText.length > 0) {
      return;
    }
    try {
      const state = getAppCoreRuntime().getStore().getState();
      const chat = state.chats.chats.get(this.activeChatId);
      if (chat && chat.draftText.length > 0) {
        this.setCustomEmojiEntities(chat.draftCustomEmojiEntities);
        this.setDraftText(chat.draftText);
        this.setDraftSelection(chat.draftText.length, chat.draftText.length);
        // Telegram restores the reply target together with the draft text
        if (chat.draftReplyToMessageId !== '0' && this.replyToMessageId === '0') {
          const chatMessages = state.messages.messages.get(this.activeChatId);
          const target = chatMessages ? chatMessages.get(chat.draftReplyToMessageId) : undefined;
          const author = target ? resolveSenderName(target, state) : '';
          const preview = chatMessages
            ? resolveReplyPreview(chatMessages, chat.draftReplyToMessageId) : '';
          this.startReply(chat.draftReplyToMessageId, author, preview);
        }
        hilog.info(DOMAIN, TAG, 'Draft restored for chat %{public}d (reply %{public}s)',
          this.activeChatId, chat.draftReplyToMessageId);
      }
    } catch (_e) {
    }
  }

  private scheduleDraftDebounce(): void {
    // Edit mode reuses the composer for the message being edited — that text
    // is NOT the chat draft and must never be persisted as one
    if (this.isEditingMessage) {
      return;
    }
    if (this.draftDebounceTimerId >= 0) {
      clearTimeout(this.draftDebounceTimerId);
    }
    const lifecycleToken = this.pageLifecycleToken;
    this.draftDebounceTimerId = setTimeout(() => {
      this.draftDebounceTimerId = -1;
      if (lifecycleToken !== this.pageLifecycleToken) {
        return;
      }
      this.persistDraft(this.activeChatId);
    }, 1500);
  }

  // Search-mode replacement for the composer: up/down result navigation plus
  // a "position / total" counter (iOS pattern)
  @Builder
  private buildSearchNavBar() {
    Column() {
      Row() {
        Row() {
          Column() {
            SymbolGlyph($r('sys.symbol.chevron_up'))
              .fontSize(TgUiTokens.SEARCH_NAV_ICON_SIZE)
              .fontColor([this.searchResultPos < this.searchResultTotal
                ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COMPOSER_ACTION_INACTIVE])
          }
          .width(TgUiTokens.SEARCH_NAV_CONTROL_SIZE)
          .height(TgUiTokens.SEARCH_NAV_CONTROL_SIZE)
          .justifyContent(FlexAlign.Center)
          .accessibilityText(localized($r('app.string.search_previous_result').id, 'Previous result'))
          .onClick(() => {
            this.searchCtrl.goToOlderResult(this);
          })

          Column() {
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(TgUiTokens.SEARCH_NAV_ICON_SIZE)
              .fontColor([this.searchResultPos > 1
                ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COMPOSER_ACTION_INACTIVE])
          }
          .width(TgUiTokens.SEARCH_NAV_CONTROL_SIZE)
          .height(TgUiTokens.SEARCH_NAV_CONTROL_SIZE)
          .justifyContent(FlexAlign.Center)
          .accessibilityText(localized($r('app.string.search_next_result').id, 'Next result'))
          .onClick(() => {
            this.searchCtrl.goToNewerResult(this);
          })
        }
        .height(TgUiTokens.SEARCH_NAV_CAPSULE_HEIGHT)
        .backgroundColor(TgUiTokens.COMPOSER_CAPSULE_BG)
        .border({ width: 0.5, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
        .borderRadius(TgUiTokens.SEARCH_NAV_CAPSULE_RADIUS)
        .backgroundBlurStyle(TgGlassPolicy.composerBlurStyle(), TgGlassPolicy.glassOptions())

        Blank()

        if (this.searchQuery.trim().length > 0) {
          Row({ space: TgUiTokens.SPACE_6 }) {
            if (this.searchLoading) {
              LoadingProgress()
                .width(TgUiTokens.SEARCH_NAV_PROGRESS_SIZE)
                .height(TgUiTokens.SEARCH_NAV_PROGRESS_SIZE)
                .color(TgUiTokens.COMPOSER_ACTION_ACTIVE)
            }
            if (this.searchResultTotal > 0) {
              Text(this.searchResultPos.toString() + ' / ' + this.searchResultTotal.toString())
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            } else if (this.searchLoading) {
              Text(localized($r('app.string.search_searching').id, 'Searching...'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            } else if (this.searchError) {
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
          .backgroundColor(TgUiTokens.COMPOSER_CAPSULE_BG)
          .border({ width: 0.5, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
          .borderRadius(TgUiTokens.SEARCH_NAV_CAPSULE_RADIUS)
          .backgroundBlurStyle(TgGlassPolicy.composerBlurStyle(), TgGlassPolicy.glassOptions())
        }
      }
      .width('100%')
      .height(TgUiTokens.SEARCH_NAV_BAR_HEIGHT)
      .padding({ left: TgUiTokens.SEARCH_NAV_SIDE_INSET, right: TgUiTokens.SEARCH_NAV_SIDE_INSET })
    }
    .width('100%')
    .padding({ bottom: this.bottomOverlayInset })
  }

  private openProfile(): void {
    if (this.activeChatId === 0) return; // groups/channels have negative ids
    hilog.info(DOMAIN, TAG, 'openProfile chatId=%{public}d', this.activeChatId);
    const navStack: NavPathStack | undefined = this.bindNavigationStack();
    if (navStack === undefined) {
      hilog.error(DOMAIN, TAG, 'Navigation stack unavailable for profile page');
      return;
    }
    const params = new ProfileRouteParams(this.activeChatId);
    try {
      navStack.pushPathByName('TgProfilePage', params);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to push profile page: %{public}s', String(error));
    }
  }

  private handleBackPress(): void {
    hilog.info(DOMAIN, TAG, 'handleBackPress called');
    if (this.pinnedMessagesListVisible) {
      this.setPinnedMessagesListVisible(false);
      return;
    }
    if (this.isClosing) {
      hilog.warn(DOMAIN, TAG, 'Ignoring duplicate chat screen back pop while closing');
      return;
    }
    const navStack: NavPathStack | undefined = this.bindNavigationStack();
    if (navStack === undefined) {
      hilog.error(DOMAIN, TAG, 'pageStack is undefined in handleBackPress!');
      return;
    }
    try {
      if (navStack.size() <= 0) {
        hilog.error(DOMAIN, TAG, 'Cannot pop chat screen: pageStack is empty');
        return;
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Cannot inspect chat screen pageStack before pop: %{public}s', String(error));
      return;
    }

    const prevNavLockUntil: number = navigationUIState.chatNavLockUntil;
    const prevChatScreenVisible: boolean = navigationUIState.chatScreenVisible;
    const prevNavigationChatId: number = navigationUIState.activeChatId;
    const prevNavigationTitle: string = navigationUIState.activeChatTitle;
    const prevChatStateId: number = chatUIState.activeChatId;
    const prevChatStateTitle: string = chatUIState.activeChatTitle;
    const prevStoredChatId: number = AppStorage.get<number>(StorageKeys.ACTIVE_CHAT_ID) ?? prevNavigationChatId;
    const prevStoredTitle: string = AppStorage.get<string>(StorageKeys.ACTIVE_CHAT_TITLE) ?? prevNavigationTitle;

    this.saveScrollPosition();
    this.isClosing = true;
    const navLockUntil = Date.now() + CHAT_NAV_TRANSITION_LOCK_MS;
    navigationUIState.chatNavLockUntil = navLockUntil;
    AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, navLockUntil);
    navigationUIState.chatScreenVisible = false;
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    this.clearOwnedChatContext();

    try {
      hilog.info(DOMAIN, TAG, 'Popping from pageStack');
      navStack.pop();
    } catch (error) {
      this.isClosing = false;
      navigationUIState.chatNavLockUntil = prevNavLockUntil;
      AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, prevNavLockUntil);
      navigationUIState.chatScreenVisible = prevChatScreenVisible;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, prevChatScreenVisible);
      navigationUIState.activeChatId = prevNavigationChatId;
      navigationUIState.activeChatTitle = prevNavigationTitle;
      chatUIState.activeChatId = prevChatStateId;
      chatUIState.activeChatTitle = prevChatStateTitle;
      AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, prevStoredChatId);
      AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, prevStoredTitle);
      hilog.error(DOMAIN, TAG, 'Failed to pop chat screen: %{public}s', String(error));
    }
  }

  private saveScrollPosition(): void {
    const chatId = this.currentScrollChatId;
    const idx = this.lastVisibleStartIndex;
    if (chatId !== 0 && idx >= 0 && idx < this.dataSource.totalCount()) {
      const key = this.dataSource.getData(idx).key;
      TgChatScreenPage.scrollPositionCache.set(chatId, key);
      hilog.info(DOMAIN, TAG, 'Saved scroll position key=%{public}s idx=%{public}d for chat %{public}d',
        key, idx, chatId);
    }
  }

  private restoreScrollPosition(): void {
    const chatId = this.activeChatId;
    const totalCount = this.dataSource.totalCount();
    if (totalCount === 0) {
      return;
    }
    this.guardProgrammaticScroll();

    const wasAwaiting = this.awaitingInitialTimeline;

    // With initialIndex set by computeInitialIndex(), the List is born at
    // the correct position. For unread/saved positions that are NOT the
    // bottom, we still need a scrollToIndex for sub-item alignment (START).
    // For bottom (default), initialIndex alone is sufficient — no scroll needed.
    const needsExplicitScroll = this.listInitialIndex < totalCount - 1;

    if (wasAwaiting) {
      // Release placeholder — List will be created with initialIndex already set.
      // No prependScrollMask needed: List starts at the right position natively.
      this.awaitingInitialTimeline = false;

      if (needsExplicitScroll) {
        // For unread/saved: refine alignment after List renders (one frame).
        const targetIndex = this.listInitialIndex;
        this.armAutoPaginationUnlock(targetIndex, 'initialRestore');
        this.lastVisibleStartIndex = targetIndex;
        this.scheduleLifecycleTask(16, () => {
          this.guardProgrammaticScroll();
          this.listScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
          // After guard expires, check if near edge → trigger pagination
          this.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
        });
      } else {
        // Re-align after List creation so the last item attaches to the
        // viewport edge already shortened by composerTotalHeight.
        this.scheduleLifecycleTask(16, () => {
          this.scrollTimelineToBottomAligned();
        });
        this.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
      }
    } else {
      // List already visible (chat switch without re-creation).
      if (needsExplicitScroll) {
        const targetIndex = this.listInitialIndex;
        this.armAutoPaginationUnlock(targetIndex, 'switchRestore');
        this.lastVisibleStartIndex = targetIndex;
        this.scheduleLifecycleTask(16, () => {
          this.guardProgrammaticScroll();
          this.listScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
          this.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
        });
      } else {
        this.scheduleLifecycleTask(16, () => {
          this.scrollTimelineToBottomAligned();
        });
        this.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
      }
    }
  }

  isNearBottom(): boolean {
    const total = this.dataSource.totalCount();
    if (total === 0) {
      return true;
    }
    // Consider "near bottom" if last visible index is within 3 items of the end
    return this.lastVisibleStartIndex < 0 || (total - this.lastVisibleStartIndex) < 15;
  }

  private scheduleHistoryLoad(chatId: number, attempt: number): void {
    if (this.historyFallbackTimerId >= 0) {
      clearTimeout(this.historyFallbackTimerId);
      this.historyFallbackTimerId = -1;
    }
    if (chatId === 0) {
      return;
    }
    const delayMs = attempt === 0
      ? HISTORY_INITIAL_DELAY_MS
      : HISTORY_RETRY_BASE_DELAY_MS * attempt;
    const lifecycleToken: number = this.pageLifecycleToken;
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (lifecycleToken !== this.pageLifecycleToken ||
        this.historyFallbackTimerId !== scheduledTimerId ||
        this.activeChatId !== chatId) {
        return;
      }
      this.historyFallbackTimerId = -1;
      this.requestHistoryWithRetry(chatId, attempt);
    }, delayMs) as number;
    this.historyFallbackTimerId = scheduledTimerId;
  }

  private shouldRetryHistoryLoad(chatId: number): boolean {
    if (!this.loadChatHistoryUseCase) {
      return false;
    }
    return this.loadChatHistoryUseCase.shouldRetry(chatId);
  }

  private shouldShowHistoryLoadingPlaceholder(): boolean {
    if (!this.awaitingInitialTimeline || this.activeChatId === 0) {
      return false;
    }
    const count = this.dataSource.totalCount();
    if (count >= INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT) {
      return false;
    }
    if (!this.loadChatHistoryUseCase) {
      return count === 0;
    }
    return this.loadChatHistoryUseCase.canLoadOlderMessages(this.activeChatId);
  }

  private requestHistoryWithRetry(chatId: number, attempt: number): void {
    const historyUseCase = this.loadChatHistoryUseCase;
    if (!historyUseCase || chatId === 0 || this.activeChatId !== chatId) {
      return;
    }
    if (historyUseCase.isLoading(chatId, 'initial')) {
      return;
    }
    if (historyUseCase.hasHistoryBeenFetched(chatId)) {
      return;
    }

    const params = new LoadChatHistoryParams();
    params.chatId = chatId;
    params.limit = 50;
    params.direction = 'initial';
    params.reason = 'restore';
    const lifecycleToken: number = this.pageLifecycleToken;
    historyUseCase.execute(params)
      .then(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.loadChatHistoryUseCase !== historyUseCase ||
          this.activeChatId !== chatId) {
          return;
        }
        if (this.shouldRetryHistoryLoad(chatId) &&
          attempt + 1 < HISTORY_MAX_RETRY_ATTEMPTS &&
          this.activeChatId === chatId) {
          this.scheduleHistoryLoad(chatId, attempt + 1);
        }
      })
      .catch((error: Object) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.loadChatHistoryUseCase !== historyUseCase ||
          this.activeChatId !== chatId) {
          return;
        }
        hilog.warn(DOMAIN, TAG, 'history load attempt %{public}d failed: %{public}s',
          attempt + 1, String(error));
        if (this.shouldRetryHistoryLoad(chatId) &&
          attempt + 1 < HISTORY_MAX_RETRY_ATTEMPTS &&
          this.activeChatId === chatId) {
          this.scheduleHistoryLoad(chatId, attempt + 1);
        }
      });
  }

  bindNavigationStack(): NavPathStack | undefined {
    try {
      const navigationInfo: uiObserver.NavigationInfo | undefined = this.queryNavigationInfo();
      if (navigationInfo !== undefined) {
        this.pageStack = navigationInfo.pathStack;
      }
    } catch (_error) {
    }
    return this.pageStack;
  }

  private entryReuseId(entry: ChatTimelineEntryVO): string {
    if (entry.kind === 'date') {
      return 'chat_date_separator';
    }
    if (entry.kind === 'unread') {
      return 'chat_unread_marker';
    }
    if (entry.kind === 'service') {
      return 'chat_service_line';
    }
    const contentKey = entry.message.contentType;
    const outKey = entry.message.isOutgoing ? 'out' : 'in';
    const replyKey = entry.message.showReplySnippet ? 'r1' : 'r0';
    const senderKey = entry.message.showSenderName ? 's1' : 's0';
    const groupKey = entry.message.groupingFlags;
    const statusKey = entry.message.sendStatus.toString();
    return `chat_msg_${contentKey}_${outKey}_${replyKey}_${senderKey}_${groupKey}_${statusKey}`;
  }

  @Builder
  private buildMessageItem(entry: ChatTimelineEntryVO) {
    Column() {
      TgMessageRouter({
        messageId: entry.message.messageId,
        hiddenMediaMessageId: this.gallerySourceMessageId,
        contentType: entry.message.contentType,
        isOutgoing: entry.message.isOutgoing,
        containerWidth: this.timelineContainerWidth,
        isBroadcastChannel: this.activeChatIsChannel,
        groupingFlags: entry.message.groupingFlags,
        text: entry.message.text,
        isEmojiOnly: entry.message.isEmojiOnly,
        forceBreakAll: entry.message.forceBreakAll,
        quoteOffsets: entry.message.quoteOffsets,
        quoteLengths: entry.message.quoteLengths,
        quoteCollapsedFlags: entry.message.quoteCollapsedFlags,
        textEntities: entry.message.textEntities,
        linkPreviewUrl: entry.message.linkPreviewUrl,
        linkPreviewDisplayUrl: entry.message.linkPreviewDisplayUrl,
        linkPreviewSiteName: entry.message.linkPreviewSiteName,
        linkPreviewTitle: entry.message.linkPreviewTitle,
        linkPreviewDescription: entry.message.linkPreviewDescription,
        linkPreviewAuthor: entry.message.linkPreviewAuthor,
        linkPreviewPhotoPath: entry.message.linkPreviewPhotoPath,
        linkPreviewPhotoMinithumb: entry.message.linkPreviewPhotoMinithumb,
        linkPreviewShowLargeMedia: entry.message.linkPreviewShowLargeMedia,
        linkPreviewShowMediaAboveDescription: entry.message.linkPreviewShowMediaAboveDescription,
        linkPreviewShowAboveText: entry.message.linkPreviewShowAboveText,
        caption: entry.message.caption,
        captionQuoteOffsets: entry.message.captionQuoteOffsets,
        captionQuoteLengths: entry.message.captionQuoteLengths,
        captionQuoteCollapsedFlags: entry.message.captionQuoteCollapsedFlags,
        captionEntities: entry.message.captionEntities,
        photoPath: entry.message.photoPath,
        photoFileId: entry.message.photoFileId,
        photoMinithumb: entry.message.photoMinithumb,
        hasLocalPhoto: entry.message.hasLocalPhoto,
        isPhotoDownloading: entry.message.isPhotoDownloading || this.isMediaDownloadPending(entry.message.photoFileId),
        isPhotoDownloadFailed: this.isMediaDownloadFailed(entry.message.photoFileId),
        photoDownloadProgress: entry.message.photoDownloadProgress,
        photoWidth: entry.message.photoWidth,
        photoHeight: entry.message.photoHeight,
        albumPhotoPaths: entry.message.albumPhotoPaths,
        albumPhotoMinithumbs: entry.message.albumPhotoMinithumbs,
        albumPhotoMessageIds: entry.message.sourceMessageIds,
        albumPhotoFileIds: entry.message.albumPhotoFileIds,
        albumPhotoHasLocal: entry.message.albumPhotoHasLocal,
        albumPhotoDownloading: this.effectiveAlbumPhotoDownloading(entry),
        albumPhotoDownloadFailed: this.effectiveAlbumPhotoDownloadFailed(entry),
        albumPhotoDownloadProgress: entry.message.albumPhotoDownloadProgress,
        albumPhotoWidths: entry.message.albumPhotoWidths,
        albumPhotoHeights: entry.message.albumPhotoHeights,
        videoThumbPath: entry.message.videoThumbPath,
        videoMinithumb: entry.message.videoMinithumb,
        videoPath: entry.message.videoPath,
        videoFileId: entry.message.videoFileId,
        isVideoDownloading: entry.message.isVideoDownloading || this.isMediaDownloadPending(entry.message.videoFileId),
        isVideoDownloadFailed: this.isMediaDownloadFailed(entry.message.videoFileId),
        videoDownloadProgress: entry.message.videoDownloadProgress,
        videoDuration: entry.message.videoDuration,
        videoWidth: entry.message.videoWidth,
        videoHeight: entry.message.videoHeight,
        documentPath: entry.message.documentPath,
        documentFileId: entry.message.documentFileId,
        isDocumentDownloading: entry.message.isDocumentDownloading ||
          this.isMediaDownloadPending(entry.message.documentFileId),
        isDocumentDownloadFailed: this.isMediaDownloadFailed(entry.message.documentFileId),
        documentDownloadProgress: entry.message.documentDownloadProgress,
        audioPath: entry.message.audioPath,
        audioFileId: entry.message.audioFileId,
        isAudioDownloading: entry.message.isAudioDownloading || this.isMediaDownloadPending(entry.message.audioFileId),
        isAudioDownloadFailed: this.isMediaDownloadFailed(entry.message.audioFileId),
        audioDownloadProgress: entry.message.audioDownloadProgress,
        audioDuration: entry.message.audioDuration,
        audioTitle: entry.message.audioTitle,
        audioPerformer: entry.message.audioPerformer,
        fileName: entry.message.fileName,
        fileSize: entry.message.fileSize,
        mimeType: entry.message.mimeType,
        voicePath: entry.message.voicePath,
        voiceFileId: entry.message.voiceFileId,
        isVoiceDownloading: entry.message.isVoiceDownloading || this.isMediaDownloadPending(entry.message.voiceFileId),
        isVoiceDownloadFailed: this.isMediaDownloadFailed(entry.message.voiceFileId),
        voiceDownloadProgress: entry.message.voiceDownloadProgress,
        voiceDuration: entry.message.voiceDuration,
        voiceWaveform: entry.message.voiceWaveform,
        isVoiceListened: this.effectiveVoiceListened(entry),
        isVoicePlaying: this.isActiveVoiceEntry(entry) ? this.activeVoicePlaying : false,
        voicePlaybackProgress: this.isActiveVoiceEntry(entry) ? this.activeVoiceProgress : 0,
        isAudioPlaying: this.isActiveAudioEntry(entry) ? this.activeAudioPlaying : false,
        audioPlaybackProgress: this.isActiveAudioEntry(entry) ? this.activeAudioProgress : 0,
        stickerPath: entry.message.stickerPath,
        stickerThumbnailPath: entry.message.stickerThumbnailPath,
        stickerWidth: entry.message.stickerWidth,
        stickerHeight: entry.message.stickerHeight,
        isAnimatedSticker: entry.message.isAnimatedSticker,
        isVideoSticker: entry.message.isVideoSticker,
        stickerEmoji: entry.message.stickerEmoji,
        contactFirstName: entry.message.contactFirstName,
        contactLastName: entry.message.contactLastName,
        contactPhoneNumber: entry.message.contactPhoneNumber,
        contactUserId: entry.message.contactUserId,
        locationLatitude: entry.message.locationLatitude,
        locationLongitude: entry.message.locationLongitude,
        locationVenueTitle: entry.message.locationVenueTitle,
        locationVenueAddress: entry.message.locationVenueAddress,
        pollQuestion: entry.message.pollQuestion,
        pollOptions: entry.message.pollOptions,
        pollTotalVoterCount: entry.message.pollTotalVoterCount,
        pollIsClosed: entry.message.pollIsClosed,
        pollIsAnonymous: entry.message.pollIsAnonymous,
        pollType: entry.message.pollType,
        showSenderName: entry.message.showSenderName,
        senderName: entry.message.senderName,
        senderColorHex: entry.message.senderColorHex,
        reserveAvatarLane: entry.message.reserveAvatarLane,
        showAvatar: entry.message.showAvatar,
        avatarImageSrc: entry.message.avatarImageSrc,
        avatarInitials: entry.message.avatarInitials,
        avatarColorIndex: entry.message.avatarColorIndex,
        showReplySnippet: entry.message.showReplySnippet,
        replyAuthor: entry.message.replyAuthor,
        replyAuthorColorHex: entry.message.replyAuthorColorHex,
        replyPreview: entry.message.replyPreview,
        replyIsOutgoing: entry.message.replyIsOutgoing,
        replyIsQuote: entry.message.replyIsQuote,
        replyHasThumbnail: entry.message.replyHasThumbnail,
        replyThumbnailSrc: entry.message.replyThumbnailSrc,
        timeText: entry.message.timeText,
        editedText: entry.message.editedText,
        sendStatus: entry.message.sendStatus,
        isShortVideo: entry.message.isShortVideo,
        onMediaDownloadRequest: (fileId: number): void => {
          this.requestMediaDownload(fileId, entry.message.messageId);
        },
        onMediaDownloadCancel: (fileId: number): void => {
          this.cancelMediaDownload(fileId, entry.message.messageId);
        },
        onMediaGalleryOpen: (messageId: string): void => {
          this.handleMediaGalleryOpen(messageId);
        },
        onPhotoTap: (): void => {
          this.handleMediaGalleryOpen(entry.message.messageId);
        },
        onAlbumPhotoTap: (albumIndex: number): void => {
          const memberMessageId = albumIndex >= 0 && albumIndex < entry.message.sourceMessageIds.length
            ? entry.message.sourceMessageIds[albumIndex] : '';
          const sourceMessageId = albumIndex >= 0 && albumIndex < entry.message.albumPhotoPaths.length
            ? albumMediaSourceId(entry.message.messageId, memberMessageId, albumIndex)
            : entry.message.messageId;
          this.handleMediaGalleryOpen(sourceMessageId);
        },
        onVideoTap: (): void => {
          this.handleMediaGalleryOpen(entry.message.messageId);
        },
        onDocumentTap: (documentPath: string, documentFileId: number, mimeType: string): void => {
          this.handleDocumentTap(documentPath, documentFileId, mimeType, entry.message.messageId);
        },
        onAudioTap: (audioPath: string, audioFileId: number, mimeType: string): void => {
          this.handleAudioTap(audioPath, audioFileId, mimeType, entry.message.messageId);
        },
        onReplyPress: (): void => {
          if (entry.message.replyToMessageId !== '0') {
            this.jumpToMessageId(entry.message.replyToMessageId);
          }
        },
        onChannelSharePress: (): void => {
          this.messageActionsCtrl.openForwardTargetPickerForEntry(entry, this);
        },
        onVoiceTap: (messageId: string, voicePath: string, voiceFileId: number): void => {
          this.handleVoiceTap(messageId, voicePath, voiceFileId);
        },
        onAudioSeek: (messageId: string, progress: number): void => {
          this.handleAudioSeek(messageId, progress);
        },
        onVoiceSeek: (messageId: string, progress: number): void => {
          this.handleVoiceSeek(messageId, progress);
        }
      })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_12,
      right: TgUiTokens.SPACE_12,
      top: entry.message.topSpacing,
      bottom: 0
    })
    .bindPopup(this.messageActionsOpenId === entry.message.messageId, {
      builder: this.buildMessageActionsPopup,
      placement: Placement.Top,
      popupColor: TgUiTokens.COMPOSER_CAPSULE_BG,
      enableArrow: false,
      autoCancel: true,
      mask: false,
      targetSpace: TgUiTokens.COMPOSER_BOT_POPUP_TARGET_GAP,
      width: this.messageActionsPopupWidth(),
      radius: TgUiTokens.COMPOSER_CAPSULE_RADIUS,
      shadow: ShadowStyle.OUTER_DEFAULT_MD,
      backgroundBlurStyle: TgGlassPolicy.composerBlurStyle(),
      transition: composerPopupTransition(),
      onStateChange: (event) => {
        if (!event.isVisible && this.messageActionsOpenId === entry.message.messageId) {
          this.messageActionsOpenId = '';
          this.messageActionsEntry = undefined;
        }
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 300 })
        .onAction(() => {
          this.showMessageActions(entry);
        })
    )
  }

  @Builder
  private buildTimelineEntry(entry: ChatTimelineEntryVO) {
    if (entry.kind === 'date') {
      TgDateSeparator({
        text: entry.dateText,
        containerWidth: this.timelineContainerWidth
      })
        .padding({ top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_4 })
    } else if (entry.kind === 'unread') {
      TgUnreadMarker({
        text: entry.unreadText,
        containerWidth: this.timelineContainerWidth
      })
        .padding({
          top: TgUiTokens.UNREAD_MARKER_MARGIN_TOP,
          bottom: TgUiTokens.UNREAD_MARKER_MARGIN_BOTTOM
        })
    } else if (entry.kind === 'service') {
      TgDateSeparator({
        text: entry.serviceText,
        containerWidth: this.timelineContainerWidth,
        maxLines: 3,
        isService: true
      })
        .padding({ top: TgUiTokens.SPACE_4, bottom: TgUiTokens.SPACE_4 })
    } else {
      this.buildMessageItem(entry)
    }
  }

  @Builder
  private buildStickerSettingsSheet() {
    TgStickerSettingsSheet({
      packs: this.stickerSetTabs,
      installedTitle: localized($r('app.string.sticker_packs_installed').id, 'Installed Sticker Packs'),
      emptyTitle: localized($r('app.string.sticker_packs_empty').id, 'No installed sticker packs')
    })
  }

  @Builder
  private buildPinnedMessagesListOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      TgChatBackground()

      TgPinnedMessageList({
        items: this.pinnedMessageListItems(),
        contentStartOffset: this.topBarTotalHeight,
        bottomInset: this.bottomOverlayInset,
        isLoading: this.pinnedMessagesListLoading,
        emptyText: localized($r('app.string.no_pinned_messages').id, 'No pinned messages'),
        onItemPress: (index: number): void => {
          this.handlePinnedListItemPress(index);
        },
        onLoadMore: (): void => {
          this.loadMorePinnedMessages();
        }
      })

      TgChatTopBar({
        topInset: this.chatTopInset(),
        title: localized($r('app.string.notifications_pinned_messages').id, 'Pinned Messages'),
        subtitle: `${this.pinnedMessageTotalCount}`,
        trailingAction: TgChatTopBarTrailingAction.None,
        onBackPress: (): void => {
          this.setPinnedMessagesListVisible(false);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .transition(
      TransitionEffect.move(TransitionEdge.END).animation({
        curve: curves.responsiveSpringMotion(
          TgUiTokens.PINNED_LIST_MOTION_RESPONSE,
          TgUiTokens.PINNED_LIST_MOTION_DAMPING,
          TgUiTokens.PINNED_LIST_MOTION_OVERLAP
        )
      })
    )
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        TgChatBackground()

        // ── Content layer (under top bar, physically ends above composer) ──
        Column() {
          if (this.activeChatId !== 0) {
            if (this.shouldShowHistoryLoadingPlaceholder()) {
              Column({ space: TgUiTokens.SPACE_8 }) {
                LoadingProgress()
                  .width(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
                  .height(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
                  .color(TgUiTokens.COLOR_ICON_PRIMARY)
                Text(localized($r('app.string.loading').id, 'Loading...'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              }
              .layoutWeight(1)
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else if (this.dataSource.totalCount() > 0) {
              List({ scroller: this.listScroller, initialIndex: this.listInitialIndex }) {
                LazyForEach(this.dataSource, (entry: ChatTimelineEntryVO) => {
                  ListItem() {
                    Row() {
                      this.buildTimelineEntry(entry)
                    }
                    .width('100%')
                    .backgroundColor(entry.searchFlash ? TgUiTokens.SEARCH_HIT_FLASH : Color.Transparent)
                    .border({
                      width: entry.searchFlash && this.useSearchFlashOutline(entry)
                        ? TgUiTokens.SEARCH_HIT_OUTLINE_WIDTH : 0,
                      color: TgUiTokens.SEARCH_HIT_OUTLINE
                    })
                    .borderRadius(entry.searchFlash && this.useSearchFlashOutline(entry)
                      ? TgUiTokens.SEARCH_HIT_OUTLINE_RADIUS : 0)
                    // NO .reuseId here: V1 reuse on a @ComponentV2 row silently skips
                    // @Param re-init — notifyDataChange re-rendered a STALE bubble
                    // (download button survived a completed download; Monitor probe
                    // confirmed fresh videoPath never reached the reused component).
                    // Proper V2 reuse would be @ReusableV2 + .reuse() (API 18+) — a
                    // separate migration if scroll perf ever demands it.
                  }
                }, (entry: ChatTimelineEntryVO) => entry.key)
              }
              .cachedCount(30)
              .listDirection(Axis.Vertical)
              .layoutWeight(1)
              .edgeEffect(EdgeEffect.Spring)
              .scrollBar(BarState.Off)
              .contentStartOffset(this.chatContentStartOffset())
              .maintainVisibleContentPosition(true)
              .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
                this.maybeUnlockAutoPagination(scrollOffset, scrollState);
              })
              .onScrollIndex((start: number, end: number) => {
                this.lastVisibleStartIndex = start;
                this.lastVisibleEndIndex = end;
                this.refreshScrollToBottomVisibility(end);
                if (this.isApplyingTimelineDiff) {
                  return;
                }
                // Android pattern: simple !isLoading guard, no latch required.
                if (this.blockAutoPaginationUntilUserScroll) {
                  return;
                }
                if (this.shouldSuppressLoadOlder()) {
                  return;
                }
                const totalCount = this.dataSource.totalCount();
                if (this.isNearTopPaginationEdge(start) && !this.isLoadingOlder) {
                  this.loadOlderMessages();
                }
                if (this.isNearBottomPaginationEdge(end, totalCount) && !this.isLoadingNewer) {
                  this.loadNewerMessages();
                }
              })
              .onTouch((event: TouchEvent) => {
                this.handleTimelineTouch(event);
              })
            } else {
              Column({ space: TgUiTokens.SPACE_8 }) {
                Text(localized($r('app.string.no_messages').id, 'No messages yet'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              }
              .layoutWeight(1)
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
          } else {
            Column({ space: TgUiTokens.SPACE_8 }) {
              Text(localized($r('app.string.chat_not_selected').id, 'Chat is not selected'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: this.composerTotalHeight })

        // ── Pinned-message overlay (custom Telegram content below native/hybrid chrome) ──
        if (this.shouldShowPinnedMessagePanel()) {
          TgPinnedMessagePanel({
            title: this.pinnedMessageTitle(this.pinnedMessageIndex, this.pinnedMessageTotalCount),
            preview: this.pinnedMessagePreview,
            index: this.pinnedMessageIndex,
            totalCount: this.pinnedMessageTotalCount,
            hasThumbnail: this.pinnedMessageHasThumbnail,
            thumbnailSrc: this.pinnedMessageThumbnailPath,
            onPress: (): void => {
              this.handlePinnedMessagePress();
            },
            onClosePress: (): void => {
              this.handlePinnedMessageClose();
            },
            onListPress: (): void => {
              this.handlePinnedMessageListPress();
            }
          })
            .position({ x: 0, y: this.topBarTotalHeight })
        }

        // ── Top bar overlay (glass capsules, floats over content) ──
        TgChatTopBar({
          topInset: this.chatTopInset(),
          title: this.title,
          subtitle: this.chatSubtitle,
          subtitleMode: this.chatSubtitleMode,
          showSubtitleSpinner: this.chatSubtitleSpinner,
          avatarInitials: this.chatAvatarInitials,
          avatarColorIndex: this.chatAvatarColorIndex,
          avatarImageSrc: this.chatAvatarImageSrc,
          isOnline: this.chatIsOnline,
          trailingAction: this.chatTopBarTrailingAction,
          onBackPress: (): void => {
            this.handleBackPress();
          },
          onTitlePress: (): void => {
            this.openProfile();
          },
          onAvatarPress: (): void => {
            this.openProfile();
          },
          onSearchPress: (): void => {
            this.openSearch();
          },
          isSearchMode: this.isSearchMode,
          searchQuery: this.searchQuery,
          searchPlaceholder: localized($r('app.string.search_messages_placeholder').id, 'Search messages'),
          onSearchQueryChange: (query: string): void => {
            this.handleSearchQueryChange(query);
          },
          onSearchClose: (): void => {
            this.closeSearch();
          }
        })
        // Default hit-test: Transparent let the list underneath steal taps —
        // title/avatar onClick never fired, profile would not open

        // ── Composer overlay (glass, floats over content at bottom) ──
        Column() {
            Blank()
              .hitTestBehavior(HitTestMode.None)
            if (this.showScrollToBottom && !this.isSearchMode && !this.showMediaGallery) {
              Row() {
                Blank()
                  .hitTestBehavior(HitTestMode.None)
                TgScrollToBottomButton({
                  unreadCount: this.scrollToBottomUnreadCount,
                  onPress: (): void => {
                    this.handleScrollToBottomPress();
                  }
                })
              }
              .width('100%')
              .padding({ right: TgUiTokens.SCROLL_FAB_MARGIN, bottom: TgUiTokens.SCROLL_FAB_MARGIN })
              .hitTestBehavior(HitTestMode.Transparent)
            }
            Column() {
              if (this.isSearchMode) {
                this.buildSearchNavBar()
              } else {
                TgComposerInput({
                  text: this.composerDraftText,
                  requestedCaretPosition: this.composerSelectionEnd,
                  caretRequestRevision: this.composerCaretRequestRevision,
                  placeholder: localized($r('app.string.message_placeholder').id, 'Message'),
                  isDisabled: this.activeChatId === 0,
                  bottomInset: this.composerKeyboardPanelVisible() ? 0 : this.bottomOverlayInset,
                  showReplySnippet: this.replyToMessageId !== '0',
                  replyAuthor: this.replyToAuthor,
                  replyPreview: this.replyToPreview,
                  replyIsOutgoing: false,
                  replyIsQuote: this.replyToIsQuote,
                  replyHasThumbnail: false,
                  showEditSnippet: this.isEditingMessage,
                  editPreview: this.editingOriginalText,
                  showForwardSnippet: this.isForwardingMessages,
                  forwardTitle: this.forwardTitle,
                  forwardPreview: this.forwardPreview,
                  showAttachmentSnippet: this.pendingAttachmentUris.length > 0,
                  attachmentKind: this.pendingAttachmentKind,
                  attachmentTitle: this.pendingAttachmentTitle,
                  attachmentPreview: this.pendingAttachmentPreview,
                  attachmentMenuLabels: this.composerAttachmentMenuLabels(),
                  attachmentRecentItems: this.attachmentRecentItems,
                  attachmentRecentLoading: this.attachmentRecentLoading,
                  emojiPanelOpen: this.composerKeyboardPanelVisible(),
                  showBotMenu: this.showBotMenu,
                  botMenuTitle: this.botMenuTitle,
                  botMenuOpen: this.botMenuOpen,
                  botMenuCommands: this.botMenuCommandNames(),
                  botMenuDescriptions: this.botMenuCommandDescriptions(),
                  containerWidth: this.timelineContainerWidth,
                  voiceRecordingState: this.voiceRecordingState,
                  voiceRecordingDurationMs: this.voiceRecordingDurationMs,
                  voiceSlideLabel: localized($r('app.string.composer_voice_slide_cancel').id, 'Slide to cancel'),
                  voiceLockedLabel: localized($r('app.string.composer_voice_locked').id, 'Recording'),
                  voicePreparingLabel: localized($r('app.string.composer_voice_preparing').id, 'Starting...'),
                  voiceSendingLabel: localized($r('app.string.composer_voice_sending').id, 'Sending...'),
                  onTextChange: (value: string): void => {
                    this.composerResizeKeepsBottomAligned = this.shouldKeepTimelineBottomAligned();
                    if (value === this.expectedProgrammaticCustomEmojiText) {
                      this.expectedProgrammaticCustomEmojiText = '';
                    } else if (value !== this.composerDraftText && this.customEmojiDraftEntities.length > 0) {
                      this.customEmojiDraftEntities = reconcileCustomEmojiEntities(
                        this.composerDraftText,
                        value,
                        this.customEmojiDraftEntities
                      );
                      this.expectedProgrammaticCustomEmojiText = '';
                    }
                    this.composerDraftText = value;
                    this.scheduleDraftDebounce();
                  },
                  onTextSelectionChange: (start: number, end: number): void => {
                    this.handleComposerSelectionChange(start, end);
                  },
                  onInputWillFocus: (): void => {
                    this.handleComposerWillFocus();
                  },
                  onInputFocusChange: (focused: boolean): void => {
                    this.handleComposerFocusChange(focused);
                  },
                  onSendPress: (text: string): void => {
                    this.handleSendMessage(text);
                  },
                  onAttachPress: (): void => {
                    this.handleComposerAttachPress();
                  },
                  onAttachmentMenuItemPress: (index: number): void => {
                    this.handleComposerAttachmentMenuItemPress(index);
                  },
                  onAttachmentMenuOpenChange: (isOpen: boolean): void => {
                    this.handleAttachmentMenuOpenChange(isOpen);
                  },
                  onAttachmentRecentPress: (item: TgAttachmentRecentItem): void => {
                    this.handleAttachmentRecentPress(item);
                  },
                  onEmojiPress: (): void => {
                    this.handleComposerEmojiPress();
                  },
                  onKeyboardModePress: (): void => {
                    this.handleComposerKeyboardModePress();
                  },
                  onVoicePress: (): void => {
                    this.handleComposerVoicePress();
                  },
                  onVoiceRecordStart: (): void => {
                    this.handleVoiceRecordStart();
                  },
                  onVoiceRecordSend: (): void => {
                    this.handleVoiceRecordSend();
                  },
                  onVoiceRecordCancel: (): void => {
                    this.handleVoiceRecordCancel();
                  },
                  onVoiceRecordLock: (): void => {
                    this.handleVoiceRecordLock();
                  },
                  onBotMenuPress: (): void => {
                    this.handleBotMenuPress();
                  },
                  onBotMenuOpenChange: (isOpen: boolean): void => {
                    this.handleBotMenuOpenChange(isOpen);
                  },
                  onBotMenuCommandPress: (index: number): void => {
                    this.handleBotMenuCommandPress(index);
                  },
                  onReplyCancelPress: (): void => {
                    this.cancelReply();
                  },
                  onEditCancelPress: (): void => {
                    this.cancelEditMessage();
                  },
                  onForwardCancelPress: (): void => {
                    this.cancelForwardMessages();
                  },
                  onAttachmentCancelPress: (): void => {
                    this.clearPendingAttachment();
                  }
                })

                if (this.showComposerEmojiPanel) {
                  TgComposerEmojiPanel({
                    title: localized($r('app.string.sticker_packs_recent').id, 'Recent'),
                    searchTitle: localized($r('app.string.accessibility_search').id, 'Search'),
                    gifTitle: localized($r('app.string.gifs_tab').id, 'GIF'),
                    stickersTitle: localized($r('app.string.stickers_tab').id, 'Stickers'),
                    emojiTitle: localized($r('app.string.emoji_tab').id, 'Emoji'),
                    settingsTitle: localized($r('app.string.settings_stickers').id, 'Stickers and Emoji'),
                    customEmojiItems: this.customEmojiPanelItems,
                    searchUnicodeResults: this.emojiSearchUnicodeResults,
                    searchCustomEmojiItems: this.emojiSearchCustomItems,
                    customEmojiTabs: this.customEmojiPackTabs,
                    activePackId: this.activeCustomEmojiPackId,
                    isLoading: this.customEmojiPanelLoading,
                    searchLoading: this.emojiSearchLoading,
                    bottomInset: this.bottomOverlayInset,
                    onEmojiSelected: (emoji: string): void => {
                      this.handleComposerEmojiSelected(emoji);
                    },
                    onCustomEmojiSelected: (item: CustomEmojiCellVO): void => {
                      this.handleCustomEmojiSelected(item);
                    },
                    onCustomEmojiTabSelected: (tabId: string): void => {
                      this.handleCustomEmojiTabSelected(tabId);
                    },
                    onSearchQueryChange: (query: string): void => {
                      this.handleEmojiSearchQueryChange(query);
                    },
                    onStickerPress: (): void => {
                      this.handleComposerStickerPress();
                    },
                    onGifPress: (): void => {
                      this.handleComposerGifPress();
                    },
                    onSettingsPress: (): void => {
                      this.openStickerSettings();
                    }
                  })
                  .transition(composerPopupTransition())
                } else if (this.showComposerStickerPanel) {
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
                    items: this.stickerPanelItems,
                    premiumItems: this.premiumStickerItems,
                    favoriteItems: this.favoriteStickerItems,
                    searchItems: this.activeStickerTabId === 'gifs'
                      ? this.gifSearchItems : this.stickerSearchItems,
                    tabs: this.stickerSetTabs,
                    activeTabId: this.activeStickerTabId,
                    isLoading: this.stickerPanelLoading,
                    searchLoading: this.activeStickerTabId === 'gifs'
                      ? this.gifSearchLoading || this.gifSearchPageLoading : this.stickerSearchLoading,
                    searchHasMore: this.activeStickerTabId === 'gifs' ? this.gifSearchHasMore : false,
                    bottomInset: this.bottomOverlayInset,
                    onStickerSelected: (item: StickerCellVO): void => {
                      this.handleStickerSelected(item);
                    },
                    onTabSelected: (tabId: string): void => {
                      this.handleStickerTabSelected(tabId);
                    },
                    onSearchQueryChange: (query: string): void => {
                      this.handleStickerSearchQueryChange(query);
                    },
                    onGifSearchQueryChange: (query: string): void => {
                      this.handleGifSearchQueryChange(query);
                    },
                    onSearchLoadMore: (): void => {
                      this.loadMoreGifSearch();
                    },
                    onGifPress: (): void => {
                      this.handleComposerGifPress();
                    },
                    onStickerPress: (): void => {
                      this.handleComposerStickerModePress();
                    },
                    onEmojiPress: (): void => {
                      this.setEmojiPanelVisible(true);
                    },
                    onSettingsPress: (): void => {
                      this.openStickerSettings();
                    }
                  })
                  .transition(composerPopupTransition())
                }
              }
          }
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            const h = newArea.height as number;
            if (h > 0 && h !== this.composerTotalHeight) {
              const keepBottomAligned = this.composerResizeKeepsBottomAligned ||
                this.shouldKeepTimelineBottomAligned();
              this.composerTotalHeight = h;
              this.composerResizeKeepsBottomAligned = false;
              if (keepBottomAligned) {
                this.scheduleComposerBottomAlignment();
              }
            }
          })
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)

        if (this.showMediaGallery) {
          this.buildMediaGallery()
        }

        if (this.pinnedMessagesListVisible) {
          this.buildPinnedMessagesListOverlay()
        }
      }
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.handleChatViewportAreaChange(newArea);
      })
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .bindSheet(this.stickerSettingsOpen, this.buildStickerSettingsSheet(), {
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
          if (this.stickerSettingsOpen) {
            this.stickerSettingsOpen = false;
          }
        }
      })
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
      const params = context.pathInfo.param as ChatScreenRouteParams;
      // Group/channel ids are NEGATIVE — only 0 means "no chat" (lesson 87)
      if (params && params.chatId !== 0) {
        this.routeChatId = params.chatId;
        this.routeChatTitle = params.chatTitle ? params.chatTitle : '';
      }
    })
    .onShown(() => {
      // Shared Media actions reuse the exact chat gallery/download/playback
      // paths after the profile stack unwinds. Plain jump intent remains for
      // older callers and reply/search navigation.
      const pendingAction = PendingSharedMediaActionSignal.consume(this.activeChatId);
      if (pendingAction !== undefined) {
        this.beginSharedMediaAction(pendingAction);
      } else {
        const pendingId = PendingJumpSignal.consume(this.activeChatId);
        if (pendingId !== '0') {
          this.jumpToMessageId(pendingId);
        }
      }
      if (PendingChatSearchSignal.consume(this.activeChatId)) {
        this.openSearch();
      }
    })
    .onBackPressed(() => {
      this.handleBackPress();
      return true;
    })
  }
}

// System route table builder — referenced by route_map.json
@Builder
export function TgChatScreenPageBuilder() {
  TgChatScreenPage()
}
