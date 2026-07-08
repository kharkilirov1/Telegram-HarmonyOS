// TgChatScreenPage — chat message timeline
// Phase D-3: Stack overlay — message list scrolls under translucent top bar for blur

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { chatUIState, navigationUIState } from '../../../core/model/UIStateModels';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { fileUri } from '@kit.CoreFileKit';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgDateSeparator, TgUnreadMarker } from '../../tg_ui/atoms/TgDateSeparator';
import { TgMessageRouter } from '../../tg_ui/molecules/TgMessageRouter';
import { TgComposerInput } from '../../tg_ui/atoms/TgComposerInput';
import { TgComposerEmojiPanel } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { TgComposerStickerPanel, StickerCellVO, StickerSetTabVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { TgChatTopBar, TgChatTopBarSubtitleMode } from '../../tg_ui/atoms/TgChatTopBar';
import { ProfileRouteParams } from '../profile/TgProfilePage';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO, buildChatTimeline } from './ChatTimelineVO';
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
  ChatForwardModeState,
  ChatMessageActionsController
} from './ChatMessageActionsController';
import { ChatSearchController } from './ChatSearchController';
import { createSendMessageUseCase, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import {
  createStickerPanelUseCase,
  StickerPanelUseCase,
  StickerPanelEntry,
  StickerSetInfoEntry,
  GifPanelEntry,
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
import { createCloseChatCommand } from '../../../core/model/AppCommand';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { localized } from '../../../core/utils/AppResource';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';
import { TgMediaGalleryPage } from '../../tg_ui/atoms/TgMediaGalleryPage';
import { computeTopBarHeight, computeChatBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiObserver, window } from '@kit.ArkUI';
import { common, Want, wantConstant } from '@kit.AbilityKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const CHAT_NAV_TRANSITION_LOCK_MS = 760;
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

declare function px2vp(value: number): number;

@ComponentV2
export struct TgChatScreenPage {
  @Local pageStack: NavPathStack = new NavPathStack();

  // Reactive state: local copy initialized from route/navigation context.
  @Local activeChatId: number = 0;
  @Local private activeChatTitle: string = '';
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
  @Local private timelineContainerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private bottomOverlayInset: number = TgUiTokens.SPACE_8;
  @Local private composerTotalHeight: number = 52; // default: button(40) + vertical insets(12)
  @Local private composerDraftText: string = '';
  @Local private showComposerEmojiPanel: boolean = false;
  @Local private showComposerStickerPanel: boolean = false;
  @Local private stickerPanelItems: StickerCellVO[] = [];
  @Local private stickerPanelLoading: boolean = false;
  @Local private stickerSetTabs: StickerSetTabVO[] = [];
  @Local private activeStickerTabId: string = 'recent';
  @Local private pendingAttachmentKind: string = '';
  @Local private pendingAttachmentTitle: string = '';
  @Local private pendingAttachmentPreview: string = '';
  @Local private pendingAttachmentUris: string[] = [];
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
  private dataSource: ChatTimelineDataSource = new ChatTimelineDataSource();
  private listScroller: Scroller = new Scroller();
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private rebuildTimerId: number = -1;
  private pageLifecycleToken: number = 0;
  private isClosing: boolean = false;
  private transientTimerIds: Set<number> = new Set<number>();
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
  private stickerSetCache: Map<string, StickerCellVO[]> = new Map<string, StickerCellVO[]>();
  private loadChatHistoryUseCase?: LoadChatHistoryUseCase;
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
  private searchFlashTimerId: number = -1;
  private searchFlashMessageId: string = '';
  private isLoadingOlder: boolean = false;
  private isLoadingNewer: boolean = false;
  private isMarkingChatRead: boolean = false;
  private historyFallbackTimerId: number = -1;
  private lastVisibleStartIndex: number = -1;
  private lastVisibleEndIndex: number = -1;
  private previousDataCount: number = 0;
  private needsScrollRestore: boolean = true;
  private currentScrollChatId: number = 0;
  private lastOpenedChatId: number = 0;
  private suppressLoadOlderUntil: number = 0;
  private unreadRestoreIndex: number = -1;
  private stickyLastReadMessageId: string = '';
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
    this.composerDraftText = value;
  }

  setEmojiPanelVisible(value: boolean): void {
    this.showComposerEmojiPanel = value;
    if (value) {
      this.showComposerStickerPanel = false;
    }
  }

  getEmojiPanelVisible(): boolean {
    return this.showComposerEmojiPanel;
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
      this.listScroller.scrollEdge(Edge.Bottom);
    });
  }

  setEditMode(messageId: string, originalText: string): void {
    this.isEditingMessage = true;
    this.editingMessageId = messageId;
    this.editingOriginalText = originalText;
    // Telegram semantics: the composer is prefilled with the current text
    this.composerDraftText = originalText;
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

  scrollToMessageId(messageId: string): boolean {
    const count = this.dataSource.totalCount();
    for (let i = 0; i < count; i++) {
      const entry: ChatTimelineEntryVO = this.dataSource.getData(i);
      if (entry.kind === 'message' && entry.message.messageId === messageId) {
        this.listScroller.scrollToIndex(i);
        this.flashSearchHit(messageId, i);
        return true;
      }
    }
    return false;
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

  private onActiveChatChanged(): void {
    try {
      // Send closeChat for previous chat before switching
      const prevChatId = this.lastOpenedChatId;
      this.lastOpenedChatId = this.activeChatId;
      if (prevChatId !== 0 && prevChatId !== this.activeChatId) {
        try {
          getTdGatewayAdapter().send(createCloseChatCommand(prevChatId))
            .catch((_: Error) => {});
        } catch (_) {}
      }

      this.saveScrollPosition();
      this.needsScrollRestore = true;
      this.lastVisibleStartIndex = -1;
      this.lastVisibleEndIndex = -1;
      this.previousDataCount = 0;
      this.isLoadingOlder = false;
      this.isLoadingNewer = false;
      this.suppressLoadOlderUntil = 0;
      this.unreadRestoreIndex = -1;
      this.lastMarkReadRequestKey = '';
      this.blockAutoPaginationUntilUserScroll = false;
      this.isApplyingTimelineDiff = false;
      this.listInitialIndex = 0;
      this.composerDraftText = '';
      this.showComposerEmojiPanel = false;
      this.showComposerStickerPanel = false;
      this.clearPendingAttachment();
      if (this.isSearchMode) {
        this.closeSearch();
      }

      this.clearPendingMediaDownloads();
      if (this.paginationRecheckTimerId >= 0) {
        clearTimeout(this.paginationRecheckTimerId);
        this.paginationRecheckTimerId = -1;
      }
      this.resetPaginationState();
      this.teardownMediaPlaybackController();
      if (this.activeChatId !== 0) {
        this.setupMediaPlaybackController();
      }
      this.awaitingInitialTimeline = this.activeChatId !== 0;
      this.currentScrollChatId = this.activeChatId;
      const state = getAppCoreRuntime().getStore().getState();
      // Capture lastReadInboxMessageId at chat entry — survives markChatRead
      const entryChat = state.chats.chats.get(this.activeChatId);
      this.stickyLastReadMessageId = (entryChat && entryChat.unreadCount > 0)
        ? entryChat.lastReadInboxMessageId : '';
      this.rebuildTimeline(state);
      this.scheduleHistoryLoad(this.activeChatId, 0);
      // Do NOT call maybeMarkChatRead here — openChat hasn't reached TDLib yet.
      // The store subscription will call it after history loads.
    } catch (_error) {
    }
  }

  aboutToAppear(): void {
    try {
      this.isClosing = false;
      this.pageLifecycleToken++;
      this.bindNavigationStack();
      this.syncOwnedChatContext();
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
      this.markChatReadUseCase = createMarkChatReadUseCase(store, getTdGatewayAdapter());
      const mediaLifecycleToken: number = this.pageLifecycleToken;
      this.mediaDownloadCtrl.setChangeListener((version: number): void => {
        if (mediaLifecycleToken !== this.pageLifecycleToken) {
          return;
        }
        this.pendingMediaDownloadVersion = version;
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
      this.stickyLastReadMessageId = (entryChat && entryChat.unreadCount > 0)
        ? entryChat.lastReadInboxMessageId : '';
      this.applyPendingForwardTransferIfNeeded();
      this.rebuildTimeline(initialState);
      this.scheduleHistoryLoad(this.activeChatId, 0);
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
    this.pageLifecycleToken++;
    // Send closeChat to TDLib (best effort, fire-and-forget)
    // Use lastOpenedChatId because activeChatId may already be zeroed by handleBackPress
    const closingChatId = this.lastOpenedChatId;
    this.lastOpenedChatId = 0;
    if (closingChatId !== 0) {
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
    const ownedChatId = this.routeChatId > 0 ? this.routeChatId : navigationUIState.activeChatId;
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
    if (this.routeChatId > 0 && navigationUIState.activeChatId === this.routeChatId) {
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
      return 'online';
    }
    if (status === 'recently') {
      return 'last seen recently';
    }
    if (status === 'lastWeek') {
      return 'last seen within a week';
    }
    if (status === 'lastMonth') {
      return 'last seen within a month';
    }
    if (status === 'longTimeAgo') {
      return 'last seen a long time ago';
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
        actionLabel = 'recording video...';
        break;
      case 'uploadingVideo':
        actionLabel = 'sending video...';
        break;
      case 'recordingVoice':
        actionLabel = 'recording voice...';
        break;
      case 'uploadingVoice':
        actionLabel = 'sending voice message...';
        break;
      case 'uploadingPhoto':
        actionLabel = 'sending photo...';
        break;
      case 'uploadingDocument':
        actionLabel = 'sending file...';
        break;
      case 'choosingSticker':
        actionLabel = 'choosing sticker...';
        break;
      case 'choosingLocation':
        actionLabel = 'choosing location...';
        break;
      case 'choosingContact':
        actionLabel = 'choosing contact...';
        break;
      case 'playingGame':
        actionLabel = 'playing game...';
        break;
      case 'recordingVideoNote':
        actionLabel = 'recording video message...';
        break;
      case 'uploadingVideoNote':
        actionLabel = 'sending video message...';
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
      return;
    }

    this.chatAvatarInitials = this.computeInitials(chat.title);
    const colorSeed = chat.peerUserId > 0 ? chat.peerUserId : chat.id;
    this.chatAvatarColorIndex = colorSeed % 8;
    this.chatAvatarImageSrc = chat.photoSmall.length > 0 ? fileUri.getUriFromPath(chat.photoSmall) : '';

    if (chat.peerUserId > 0) {
      const user = state.users.users.get(chat.peerUserId);
      if (user !== undefined) {
        this.chatSubtitle = this.formatUserStatus(user.status);
        this.chatSubtitleMode = user.status === 'online'
          ? TgChatTopBarSubtitleMode.Online
          : TgChatTopBarSubtitleMode.Secondary;
        this.chatIsOnline = user.status === 'online';
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

  private rebuildTimeline(state: AppState): void {
    if (this.activeChatId === 0) {
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
      this.awaitingInitialTimeline = false;

      this.clearPendingMediaDownloads();
      this.pendingMediaOpenIntent.reset();
      return;
    }

    const result = buildChatTimeline(this.activeChatId, state, this.stickyLastReadMessageId);
    const chat = state.chats.chats.get(this.activeChatId);
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
          this.listScroller.scrollEdge(Edge.Bottom);
        });
      }
    }
  }

  private computeInitialIndex(totalCount: number): void {
    if (totalCount <= 0) {
      this.listInitialIndex = 0;
      return;
    }

    const chatId = this.activeChatId;

    // Priority 1: unread boundary
    if (this.unreadRestoreIndex >= 0 && this.unreadRestoreIndex < totalCount) {
      const targetIndex = Math.max(0, this.unreadRestoreIndex - 1);
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

  private requestMediaDownload(fileId: number, messageId: string = ''): void {
    this.mediaDownloadCtrl.requestMediaDownload(fileId, this.pageLifecycleToken);
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
    if (messageId.length > 0) {
      // Мгновенный отклик на тап: LazyForEach-строка перерисовывается сразу
      // (pending-состояние живёт в контроллере и без notify не доезжает до бабла)
      this.dataSource.notifyItemChangedByMessageId(messageId);
    }
  }

  private cancelMediaDownload(fileId: number): void {
    this.mediaDownloadCtrl.cancelMediaDownload(fileId);
    if (this.pendingMediaOpenIntent.matchesFile(fileId)) {
      this.pendingMediaOpenIntent.reset();
    }
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
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
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: documentPath,
        type: mimeType.trim().length > 0 ? mimeType : 'application/octet-stream',
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION |
          wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION
      };
      context.startAbility(want)
        .catch((_error: Object) => {});
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
            albumItem.caption = j === 0 ? entry.message.caption : '';
            albumItem.senderName = entry.message.senderName;
            albumItem.timestamp = entry.message.timeText;
            albumItem.width = j < entry.message.albumPhotoWidths.length ? entry.message.albumPhotoWidths[j] : 0;
            albumItem.height = j < entry.message.albumPhotoHeights.length ? entry.message.albumPhotoHeights[j] : 0;
            albumItem.fileId = albumFileId;
            albumItem.messageId = entry.message.messageId + '_album_' + j.toString();
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
          item.caption = entry.message.caption;
          item.senderName = entry.message.senderName;
          item.timestamp = entry.message.timeText;
          item.width = ct === 'photo' ? entry.message.photoWidth : entry.message.videoWidth;
          item.height = ct === 'photo' ? entry.message.photoHeight : entry.message.videoHeight;
          item.durationSec = entry.message.videoDuration;
          item.fileId = fileId;
          item.messageId = entry.message.messageId;
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
        if (entry.message.messageId === messageId) {
          targetIndex = mediaIndex;
          break;
        }
        mediaIndex += entry.message.albumPhotoPaths.length;
      }
    }
    this.galleryItems = items;
    this.galleryInitialIndex = Math.min(targetIndex, items.length - 1);
    this.galleryCurrentIndex = this.galleryInitialIndex;
    this.showMediaGallery = true;
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
      this.showMediaGallery = false;
      return;
    }
    this.galleryItems = result.items;
    this.galleryCurrentIndex = result.currentIndex;
    this.galleryInitialIndex = result.currentIndex;
  }

  @Builder
  private buildMediaGallery() {
    TgMediaGalleryPage({
      mediaItems: this.galleryItems,
      initialIndex: this.galleryCurrentIndex,
      statusBarHeight: Math.max(0, this.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT - TgUiTokens.TOP_BAR_BOTTOM_PADDING),
      onDismiss: (): void => {
        this.showMediaGallery = false;
        this.galleryCurrentIndex = 0;
      },
      onIndexChange: (index: number): void => {
        this.galleryCurrentIndex = index;
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
    this.messageActionsCtrl.showMessageActions(entry, this);
  }

  private handleSendMessage(text: string): void {
    this.composerCtrl.handleSendMessage(text, this);
  }

  private handleComposerAttachPress(): void {
    this.composerCtrl.handleAttachPress(this);
  }

  private handleComposerEmojiPress(): void {
    this.composerCtrl.handleEmojiPress(this);
  }

  private handleComposerVoicePress(): void {
    this.composerCtrl.handleVoicePress(this);
  }

  private handleComposerEmojiSelected(emoji: string): void {
    this.composerCtrl.handleEmojiSelected(emoji, this);
  }

  private handleComposerStickerPress(): void {
    this.showComposerEmojiPanel = false;
    this.showComposerStickerPanel = true;
    this.loadStickerPanelIfNeeded();
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
      this.stickerPanelItems = cells;
      this.stickerPanelLoading = false;
      this.stickerPanelLoadedOnce = true;
      this.fetchStickerPanelFiles(cells, 'recent');
      this.loadStickerSetTabs();
    }).catch(() => {
      if (token === this.pageLifecycleToken) {
        this.stickerPanelLoading = false;
      }
    });
  }

  private loadStickerSetTabs(): void {
    const useCase = this.stickerPanelUseCase;
    if (!useCase || this.stickerSetTabs.length > 0) {
      return;
    }
    const token = this.pageLifecycleToken;
    useCase.loadInstalledStickerSets().then((sets: StickerSetInfoEntry[]) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      const tabs: StickerSetTabVO[] = [
        new StickerSetTabVO('recent', '', 0, ''),
        new StickerSetTabVO('gifs', 'GIF', 0, '')
      ];
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
        // GIF cells reuse the sticker cell VO: thumbnail preview + tap-to-send
        const cell = new StickerCellVO('gif_' + entry.remoteFileId, entry.remoteFileId,
          entry.fileId, entry.thumbFileId, '', false, true, entry.width, entry.height);
        cell.isGif = true;
        cell.duration = entry.duration;
        if (entry.thumbPath.length > 0) {
          cell.thumbPathUri = fileUri.getUriFromPath(entry.thumbPath);
        }
        cells.push(cell);
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
      useCase.sendAnimation(gifParams);
      this.showComposerStickerPanel = false;
      return;
    }
    const params = new SendStickerParams();
    params.chatId = this.activeChatId;
    params.remoteFileId = cell.remoteFileId;
    params.width = cell.width;
    params.height = cell.height;
    params.emoji = cell.emoji;
    useCase.sendSticker(params);
    this.showComposerStickerPanel = false;
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

  private closeSearch(): void {
    this.clearSearchFlash();
    this.searchCtrl.closeSearch(this);
  }

  // Search-mode replacement for the composer: up/down result navigation plus
  // a "position / total" counter (iOS pattern)
  @Builder
  private buildSearchNavBar() {
    Column() {
      Divider()
        .strokeWidth(0.5)
        .color(TgUiTokens.COLOR_SEPARATOR)
      Row() {
        Image($r('app.media.ic_arrow_up'))
          .width(24)
          .height(24)
          .fillColor(this.searchResultPos < this.searchResultLoaded
            ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COMPOSER_ACTION_INACTIVE)
          .onClick(() => {
            this.searchCtrl.goToOlderResult(this);
          })
        Image($r('app.media.ic_arrow_down'))
          .width(24)
          .height(24)
          .margin({ left: TgUiTokens.SPACE_16 })
          .fillColor(this.searchResultPos > 1
            ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COMPOSER_ACTION_INACTIVE)
          .onClick(() => {
            this.searchCtrl.goToNewerResult(this);
          })
        Blank()
        if (this.searchResultTotal > 0) {
          Text(this.searchResultPos.toString() + ' / ' + this.searchResultTotal.toString())
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        } else if (this.searchQuery.trim().length > 0) {
          Text(localized($r('app.string.search_no_results').id, 'No results'))
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        }
      }
      .width('100%')
      .height(TgUiTokens.SEARCH_NAV_BAR_HEIGHT)
      .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
    }
    .width('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
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
        // Bottom: initialIndex handles position. Schedule pagination recheck
        // after guard expires — onScrollIndex may not re-fire for static lists.
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
          this.listScroller.scrollEdge(Edge.Bottom);
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
        contentType: entry.message.contentType,
        isOutgoing: entry.message.isOutgoing,
        containerWidth: this.timelineContainerWidth,
        groupingFlags: entry.message.groupingFlags,
        text: entry.message.text,
        isEmojiOnly: entry.message.isEmojiOnly,
        forceBreakAll: entry.message.forceBreakAll,
        quoteOffsets: entry.message.quoteOffsets,
        quoteLengths: entry.message.quoteLengths,
        quoteCollapsedFlags: entry.message.quoteCollapsedFlags,
        textEntities: entry.message.textEntities,
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
        sendStatus: entry.message.sendStatus,
        isShortVideo: entry.message.isShortVideo,
        onMediaDownloadRequest: (fileId: number): void => {
          this.requestMediaDownload(fileId, entry.message.messageId);
        },
        onMediaDownloadCancel: (fileId: number): void => {
          this.cancelMediaDownload(fileId);
        },
        onMediaGalleryOpen: (messageId: string): void => {
          this.handleMediaGalleryOpen(messageId);
        },
        onPhotoTap: (): void => {
          this.handleMediaGalleryOpen(entry.message.messageId);
        },
        onAlbumPhotoTap: (photoPath: string, caption: string): void => {
          this.handleMediaGalleryOpen(entry.message.messageId);
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
        .padding({ top: TgUiTokens.SPACE_6, bottom: TgUiTokens.SPACE_6 })
    } else if (entry.kind === 'service') {
      TgDateSeparator({
        text: entry.serviceText,
        containerWidth: this.timelineContainerWidth,
        maxLines: 3
      })
        .padding({ top: TgUiTokens.SPACE_4, bottom: TgUiTokens.SPACE_4 })
    } else {
      this.buildMessageItem(entry)
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        // ── Content layer (scrolls under top bar AND composer) ──
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
              .contentStartOffset(this.topBarTotalHeight)
              .contentEndOffset(this.composerTotalHeight + this.bottomOverlayInset)
              .maintainVisibleContentPosition(true)
              .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
                this.maybeUnlockAutoPagination(scrollOffset, scrollState);
              })
              .onScrollIndex((start: number, end: number) => {
                this.lastVisibleStartIndex = start;
                this.lastVisibleEndIndex = end;
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
            this.isSearchMode = true;
          },
          isSearchMode: this.isSearchMode,
          searchQuery: this.searchQuery,
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
            Column() {
              if (this.isSearchMode) {
                this.buildSearchNavBar()
              } else {
                if (this.showComposerEmojiPanel) {
                  TgComposerEmojiPanel({
                    title: localized($r('app.string.sticker_packs_recent').id, 'Recent'),
                    stickersTitle: localized($r('app.string.stickers_tab').id, 'Stickers'),
                    onEmojiSelected: (emoji: string): void => {
                      this.handleComposerEmojiSelected(emoji);
                    },
                    onStickerPress: (): void => {
                      this.handleComposerStickerPress();
                    }
                  })
                } else if (this.showComposerStickerPanel) {
                  TgComposerStickerPanel({
                    title: localized($r('app.string.stickers_tab').id, 'Stickers'),
                    emojiTitle: localized($r('app.string.emoji_tab').id, 'Emoji'),
                    items: this.stickerPanelItems,
                    tabs: this.stickerSetTabs,
                    activeTabId: this.activeStickerTabId,
                    isLoading: this.stickerPanelLoading,
                    onStickerSelected: (item: StickerCellVO): void => {
                      this.handleStickerSelected(item);
                    },
                    onTabSelected: (tabId: string): void => {
                      this.handleStickerTabSelected(tabId);
                    },
                    onEmojiPress: (): void => {
                      this.setEmojiPanelVisible(true);
                    }
                  })
                }

                TgComposerInput({
                  text: this.composerDraftText,
                  placeholder: localized($r('app.string.message_placeholder').id, 'Message'),
                  isDisabled: this.activeChatId === 0,
                  bottomInset: this.bottomOverlayInset,
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
                  onTextChange: (value: string): void => {
                    this.composerDraftText = value;
                  },
                  onSendPress: (text: string): void => {
                    this.handleSendMessage(text);
                  },
                  onAttachPress: (): void => {
                    this.handleComposerAttachPress();
                  },
                  onEmojiPress: (): void => {
                    this.handleComposerEmojiPress();
                  },
                  onVoicePress: (): void => {
                    this.handleComposerVoicePress();
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
              }
          }
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            const h = newArea.height as number;
            if (h > 0 && h !== this.composerTotalHeight) {
              this.composerTotalHeight = h;
            }
          })
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)

        if (this.showMediaGallery) {
          this.buildMediaGallery()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
      const params = context.pathInfo.param as ChatScreenRouteParams;
      if (params && params.chatId > 0) {
        this.routeChatId = params.chatId;
        this.routeChatTitle = params.chatTitle ? params.chatTitle : '';
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
