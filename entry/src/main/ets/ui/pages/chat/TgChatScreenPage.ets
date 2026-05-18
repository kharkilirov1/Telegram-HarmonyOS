// TgChatScreenPage — chat message timeline
// Phase D-3: Stack overlay — message list scrolls under translucent top bar for blur

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { chatUIState, navigationUIState } from '../../../core/model/UIStateModels';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgDateSeparator, TgUnreadMarker } from '../../tg_ui/atoms/TgDateSeparator';
import { TgMessageRouter } from '../../tg_ui/molecules/TgMessageRouter';
import { TgComposerInput } from '../../tg_ui/atoms/TgComposerInput';
import { TgComposerEmojiPanel } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { TgChatTopBar, TgChatTopBarSubtitleMode } from '../../tg_ui/atoms/TgChatTopBar';
import { ProfileRouteParams } from '../profile/TgProfilePage';
import { ForwardTargetPickerResult, ForwardTargetPickerRouteParams } from '../forward/TgForwardTargetPickerPage';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO, buildChatTimeline } from './ChatTimelineVO';
import { MediaPlaybackController, MediaPlaybackSnapshot, MediaContentType } from './VoicePlaybackController';
import { pendingForwardTransfer } from './PendingForwardTransfer';
import { ChatMediaDownloadController } from './ChatMediaDownloadController';
import { SendMessageParams, createSendMessageUseCase, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import {
  SendMediaMessageParams,
  SendMediaMessageUseCase,
  createSendMediaMessageUseCase
} from '../../../domain/usecases/sendMediaMessage';
import { EditMessageParams, createEditMessageUseCase, EditMessageUseCase } from '../../../domain/usecases/editMessage';
import { DeleteMessagesParams, createDeleteMessagesUseCase, DeleteMessagesUseCase } from '../../../domain/usecases/deleteMessages';
import { ForwardMessagesParams, ForwardMessagesUseCase, createForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { createOpenChatUseCase, OpenChatUseCase } from '../../../domain/usecases/openChat';
import { SearchChatMessagesUseCase, SearchChatMessagesResult, createSearchChatMessagesUseCase } from '../../../domain/usecases/searchChatMessages';
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
import { promptAction, uiObserver, window } from '@kit.ArkUI';
import { common, Want, wantConstant } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { pasteboard } from '@kit.BasicServicesKit';

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
const INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT = 1;

declare function px2vp(value: number): number;

class ChatScreenRouteParams {
  chatId: number = 0;
  chatTitle: string = '';

  constructor(chatId: number, chatTitle: string = '') {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
  }
}

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
  private searchDebounceTimerId: number = -1;
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
  private isApplyingTimelineDiff: boolean = false;
  private paginationRecheckTimerId: number = -1;
  private static scrollPositionCache: Map<number, string> = new Map<number, string>();
  private mediaPlaybackController?: MediaPlaybackController;
  private locallyListenedVoiceIds: Set<string> = new Set<string>();
  private mediaDownloadCtrl: ChatMediaDownloadController = new ChatMediaDownloadController();

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
      this.clearPendingAttachment();

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
      this.loadChatHistoryUseCase = createLoadChatHistoryUseCase(store, getTdGatewayAdapter());
      this.markChatReadUseCase = createMarkChatReadUseCase(store, getTdGatewayAdapter());
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
    if (this.searchDebounceTimerId !== -1) {
      clearTimeout(this.searchDebounceTimerId);
      this.searchDebounceTimerId = -1;
    }
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
    if (this.paginationRecheckTimerId >= 0) {
      clearTimeout(this.paginationRecheckTimerId);
      this.paginationRecheckTimerId = -1;
    }
    this.resetPaginationState();
    this.awaitingInitialTimeline = false;
    this.sendUseCase = undefined;
    this.sendMediaUseCase = undefined;
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

  private updateChatTopBarData(state: AppState): void {
    const chat = state.chats.chats.get(this.activeChatId);
    if (chat === undefined) {
      this.chatSubtitle = '';
      this.chatSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
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

  private requestMediaDownload(fileId: number): void {
    this.mediaDownloadCtrl.requestMediaDownload(fileId, this.pageLifecycleToken);
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
  }

  private cancelMediaDownload(fileId: number): void {
    this.mediaDownloadCtrl.cancelMediaDownload(fileId);
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
  }

  private clearPendingMediaDownloads(): void {
    this.mediaDownloadCtrl.clearPendingDownloads();
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
  }

  private isMediaDownloadPending(fileId: number): boolean {
    return this.mediaDownloadCtrl.isDownloadPending(fileId);
  }

  private syncResolvedPendingDownloads(entries: ChatTimelineEntryVO[]): void {
    this.mediaDownloadCtrl.syncResolvedDownloads(entries);
    this.pendingMediaDownloadVersion = this.mediaDownloadCtrl.getVersion();
  }


  private handleVoiceTap(messageId: string, voicePath: string, voiceFileId: number): void {
    if (voicePath.trim().length === 0) {
      if (voiceFileId > 0) {
        this.requestMediaDownload(voiceFileId);
      }
      return;
    }
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

  private handleDocumentTap(documentPath: string, documentFileId: number, mimeType: string): void {
    if (documentPath.trim().length === 0) {
      if (documentFileId > 0) {
        this.requestMediaDownload(documentFileId);
      }
      return;
    }
    this.openDocumentFile(documentPath, mimeType);
  }

  private handleAudioTap(audioPath: string, audioFileId: number, mimeType: string, messageId: string = '0'): void {
    if (audioPath.trim().length === 0) {
      if (audioFileId > 0) {
        this.requestMediaDownload(audioFileId);
      }
      return;
    }
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
    this.showMediaGallery = true;
  }

  @Builder
  private buildMediaGallery() {
    TgMediaGalleryPage({
      mediaItems: this.galleryItems,
      initialIndex: this.galleryInitialIndex,
      statusBarHeight: Math.max(0, this.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT - TgUiTokens.TOP_BAR_BOTTOM_PADDING),
      onDismiss: (): void => {
        this.showMediaGallery = false;
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
    this.clearEditMode(false);
    this.clearForwardMode();
    this.replyToMessageId = messageId;
    this.replyToAuthor = author.length > 0 ? author : 'Message';
    const trimmed = preview.trim();
    this.replyToPreview = trimmed.length > 0 ? trimmed : 'Message';
    this.replyToIsQuote = isQuote;
  }

  private clearReplyMode(): void {
    this.replyToMessageId = '0';
    this.replyToAuthor = '';
    this.replyToPreview = '';
    this.replyToIsQuote = false;
  }

  private cancelReply(): void {
    this.clearReplyMode();
  }

  private clearEditMode(clearDraft: boolean): void {
    this.isEditingMessage = false;
    this.editingMessageId = '0';
    this.editingOriginalText = '';
    if (clearDraft) {
      this.composerDraftText = '';
    }
  }

  private clearForwardMode(): void {
    this.isForwardingMessages = false;
    this.forwardingMessageIds = [];
    this.forwardSourceChatId = 0;
    this.forwardTitle = '';
    this.forwardPreview = '';
  }

  private buildForwardTitle(messageCount: number): string {
    if (messageCount <= 1) {
      return localized($r('app.string.forwarded_message').id, 'Forwarded message');
    }
    return `${localized($r('app.string.action_forward').id, 'Forward')} ${messageCount}`;
  }

  private buildForwardPreview(author: string, preview: string): string {
    const safeAuthor = author.trim().length > 0 ? author.trim() : 'Message';
    const safePreview = preview.trim().length > 0 ? preview.trim() : 'Message';
    return `${safeAuthor}: ${safePreview}`;
  }

  private applyPendingForwardTransferIfNeeded(): void {
    const payload = pendingForwardTransfer.consumeFor(this.activeChatId);
    if (payload === undefined) {
      return;
    }
    this.startForwardMessages(payload.messageIds, payload.author, payload.preview, payload.sourceChatId);
  }

  private requestOpenChatData(chatId: number): void {
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
    if (messageIds.length === 0 || fromChatId === 0) {
      return;
    }
    this.clearReplyMode();
    this.clearEditMode(false);
    this.isForwardingMessages = true;
    this.forwardingMessageIds = [...messageIds];
    this.forwardSourceChatId = fromChatId;
    this.forwardTitle = this.buildForwardTitle(messageIds.length);
    this.forwardPreview = this.buildForwardPreview(author, preview);
  }

  private cancelForwardMessages(): void {
    this.clearForwardMode();
  }

  private openForwardTargetPicker(messageIds: string[], author: string, preview: string): void {
    if (messageIds.length === 0 || this.activeChatId === 0) {
      return;
    }
    const navStack: NavPathStack | undefined = this.bindNavigationStack();
    if (navStack === undefined) {
      hilog.error(DOMAIN, TAG, 'Navigation stack unavailable for forward picker');
      return;
    }

    const sourceChatId = this.activeChatId;
    const lifecycleToken: number = this.pageLifecycleToken;
    try {
      navStack.pushPathByName(
        'TgForwardTargetPickerPage',
        new ForwardTargetPickerRouteParams(sourceChatId),
        (popInfo) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.activeChatId !== sourceChatId) {
            return;
          }
          const result = popInfo.result as ForwardTargetPickerResult | undefined;
          if (!result || result.chatId === 0) {
            return;
          }
          if (result.chatId === sourceChatId) {
            this.startForwardMessages(messageIds, author, preview, sourceChatId);
            return;
          }

          const prevChatId: number = navigationUIState.activeChatId;
          const prevTitle: string = navigationUIState.activeChatTitle;
          const prevChatScreenVisible: boolean = navigationUIState.chatScreenVisible;
          pendingForwardTransfer.arm(result.chatId, sourceChatId, messageIds, author, preview);
          navigationUIState.activeChatId = result.chatId;
          navigationUIState.activeChatTitle = result.chatTitle;
          navigationUIState.chatScreenVisible = true;
          AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);

          try {
            navStack.pushPathByName('TgChatScreenPage', new ChatScreenRouteParams(result.chatId, result.chatTitle));
            this.requestOpenChatData(result.chatId);
          } catch (error) {
            pendingForwardTransfer.clear();
            navigationUIState.activeChatId = prevChatId;
            navigationUIState.activeChatTitle = prevTitle;
            navigationUIState.chatScreenVisible = prevChatScreenVisible;
            AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, prevChatScreenVisible);
            hilog.error(DOMAIN, TAG, 'Failed to push forwarded target chat: %{public}s', String(error));
          }
        }
      );
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to push forward target picker: %{public}s', String(error));
    }
  }

  private copyMessageText(text: string): void {
    if (text.trim().length === 0) {
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setDataSync(data);
      this.getUIContext().getPromptAction().showToast({ message: localized($r('app.string.copied').id, 'Copied'), duration: 1500 });
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Copy failed: %{public}s', String(e));
    }
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

  private resolveReplyPreviewForEntry(entry: ChatTimelineEntryVO): string {
    if (entry.message.text.length > 0) {
      return entry.message.text;
    }
    if (entry.message.caption.length > 0) {
      return entry.message.caption;
    }
    switch (entry.message.contentType) {
      case 'photo':
        return localized($r('app.string.photo').id, 'Photo');
      case 'video':
        return localized($r('app.string.video').id, 'Video');
      case 'animation':
        return localized($r('app.string.gif').id, 'GIF');
      case 'voice':
        return localized($r('app.string.voice_message').id, 'Voice message');
      case 'videoNote':
        return localized($r('app.string.video_note').id, 'Video message');
      case 'sticker':
        return localized($r('app.string.sticker').id, 'Sticker');
      case 'audio':
        return entry.message.audioTitle.length > 0 ? entry.message.audioTitle : 'Audio';
      case 'document':
        return entry.message.fileName.length > 0
          ? entry.message.fileName
          : localized($r('app.string.file_label').id, 'File');
      default:
        return localized($r('app.string.message_action').id, 'Message');
    }
  }

  private showMessageActions(entry: ChatTimelineEntryVO): void {
    const messageText = entry.message.text.length > 0 ? entry.message.text :
      (entry.message.caption.length > 0 ? entry.message.caption : '');
    const hasText = messageText.trim().length > 0;
    const author = entry.message.isOutgoing ? 'You' :
      (entry.message.senderName.length > 0 ? entry.message.senderName : 'Message');
    const preview = this.resolveReplyPreviewForEntry(entry);
    const messageId = entry.message.messageId;

    const replyBtn: promptAction.Button = {
      text: localized($r('app.string.action_reply').id, 'Reply'),
      color: TgUiTokens.COLOR_ICON_PRIMARY
    };
    const copyBtn: promptAction.Button = {
      text: localized($r('app.string.action_copy').id, 'Copy'),
      color: TgUiTokens.COLOR_TEXT_TITLE
    };
    const deleteBtn: promptAction.Button = {
      text: localized($r('app.string.action_delete').id, 'Delete'),
      color: TgUiTokens.COLOR_TEXT_ERROR
    };
    const forwardBtn: promptAction.Button = {
      text: localized($r('app.string.action_forward').id, 'Forward'),
      color: TgUiTokens.COLOR_TEXT_TITLE
    };

    // iOS ref: Reply → Edit → Copy → [media] → Forward → separator → Select → Pin → separator → Delete
    // HarmonyOS promptAction.showActionMenu: max 6 buttons, no icons, no separators.
    // Editable content types (iOS: not sticker, videoNote, contact, poll, game, invoice)
    const nonEditableTypes: string[] = ['sticker', 'videoNote', 'contact', 'poll', 'location', 'game'];
    const canEdit = entry.message.isOutgoing && hasText &&
      !nonEditableTypes.includes(entry.message.contentType);

    // Build ordered button list + parallel action registry
    const buttons: promptAction.Button[] = [];
    const actions: (() => void)[] = [];

    // 1. Reply (always)
    buttons.push(replyBtn);
    actions.push(() => {
      this.startReply(messageId, author, preview, entry.message.replyIsQuote);
    });

    // 2. Edit (own editable messages — iOS order: before Copy)
    if (canEdit) {
      buttons.push({
        text: localized($r('app.string.action_edit').id, 'Edit'),
        color: TgUiTokens.COLOR_ICON_PRIMARY
      });
      actions.push(() => {
        this.startEditMessage(messageId, messageText);
      });
    }

    // 3. Copy (if has text)
    if (hasText) {
      buttons.push(copyBtn);
      actions.push(() => {
        this.copyMessageText(messageText);
      });
    }

    // 4. Forward
    buttons.push(forwardBtn);
    actions.push(() => {
      this.openForwardTargetPicker([messageId], author, preview);
    });

    // 5. Pin (iOS: after Select, before Delete)
    buttons.push({
      text: localized($r('app.string.action_pin').id, 'Pin'),
      color: TgUiTokens.COLOR_TEXT_TITLE
    });
    actions.push(() => {
      this.handlePinMessage(messageId);
    });

    // 6. Delete (always last, destructive — iOS pattern)
    buttons.push(deleteBtn);
    actions.push(() => {
      this.handleDeleteMessage(messageId);
    });

    const lifecycleToken: number = this.pageLifecycleToken;
    const chatId: number = this.activeChatId;
    this.getUIContext().getPromptAction().showActionMenu({
      title: '',
      buttons: buttons as [promptAction.Button, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (lifecycleToken !== this.pageLifecycleToken || this.activeChatId !== chatId) {
        return;
      }
      if (result.index >= 0 && result.index < actions.length) {
        actions[result.index]();
      }
    }).catch((_: Error) => {
      // User dismissed — no action needed
    });
  }

  private handleSendMessage(text: string): void {
    // Edit mode — redirect to edit handler
    if (this.isEditingMessage) {
      this.handleEditMessage(text);
      return;
    }
    if (this.isForwardingMessages) {
      this.handleForwardMessages(text);
      return;
    }
    if (this.pendingAttachmentUris.length > 0) {
      this.handleSendPendingAttachment(text);
      return;
    }
    const useCase = this.sendUseCase;
    const chatId = this.activeChatId;
    if (this.isSending || chatId === 0 || !useCase) {
      return;
    }
    this.showComposerEmojiPanel = false;
    this.isSending = true;
    const params = new SendMessageParams();
    params.chatId = chatId;
    params.text = text;
    if (this.replyToMessageId !== '0') {
      params.replyToMessageId = this.replyToMessageId;
    }
    const sentText = text;
    this.composerDraftText = '';
    this.clearReplyMode();
    // Snapshot near-bottom state before async send completes.
    const wasNearBottom = this.isNearBottom();
    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.execute(params)
      .then(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.sendUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        // Only auto-scroll to bottom if user was already near bottom.
        // If reading old messages, don't yank viewport away.
        if (wasNearBottom) {
          this.scheduleLifecycleTask(100, () => {
            this.listScroller.scrollEdge(Edge.Bottom);
          });
        }
      })
      .catch((err: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.sendUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        if (this.composerDraftText.trim().length === 0 && this.activeChatId === params.chatId) {
          this.composerDraftText = sentText;
        }
        hilog.error(DOMAIN, TAG, 'Send failed: %{public}s', err.message);
      })
      .finally(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.sendUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        this.isSending = false;
      });
  }

  private handleSendPendingAttachment(caption: string): void {
    const useCase = this.sendMediaUseCase;
    const chatId = this.activeChatId;
    if (this.isSending || chatId === 0 || !useCase || this.pendingAttachmentUris.length === 0) {
      return;
    }

    const sourceUri = this.pendingAttachmentUris[0];
    const mediaKind = this.pendingAttachmentKind.length > 0 ? this.pendingAttachmentKind : 'document';
    const replyToMessageId = this.replyToMessageId;
    const wasNearBottom = this.isNearBottom();
    const lifecycleToken: number = this.pageLifecycleToken;

    this.showComposerEmojiPanel = false;
    this.isSending = true;

    this.preparePickedAttachmentLocalPath(mediaKind, sourceUri)
      .then((localPath: string) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.sendMediaUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return Promise.resolve();
        }

        const params = new SendMediaMessageParams();
        params.chatId = chatId;
        params.mediaKind = mediaKind;
        params.localPath = localPath;
        params.caption = caption;
        if (replyToMessageId !== '0') {
          params.replyToMessageId = replyToMessageId;
        }
        return useCase.execute(params);
      })
      .then(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.sendMediaUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        this.composerDraftText = '';
        this.clearPendingAttachment();
        this.clearReplyMode();
        if (wasNearBottom) {
          this.scheduleLifecycleTask(100, () => {
            this.listScroller.scrollEdge(Edge.Bottom);
          });
        }
      })
      .catch((err: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.sendMediaUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Media send failed: %{public}s', err.message);
        this.showComposerPendingToast(localized($r('app.string.composer_media_send_failed').id,
          'Could not send media'));
      })
      .finally(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.sendMediaUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        this.isSending = false;
      });
  }

  private showComposerPendingToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
    } catch (_error) {
      // Composer auxiliary actions are non-critical; ignore toast failures.
    }
  }

  private handleComposerAttachPress(): void {
    this.showComposerEmojiPanel = false;
    const buttons: promptAction.Button[] = [
      { text: localized($r('app.string.photo').id, 'Photo'), color: TgUiTokens.COLOR_TEXT_TITLE },
      { text: localized($r('app.string.video').id, 'Video'), color: TgUiTokens.COLOR_TEXT_TITLE },
      { text: localized($r('app.string.document_label').id, 'Document'), color: TgUiTokens.COLOR_TEXT_TITLE }
    ];
    const actions: (() => void)[] = [
      () => {
        this.openPhotoAttachmentPicker('photo');
      },
      () => {
        this.openPhotoAttachmentPicker('video');
      },
      () => {
        this.openDocumentAttachmentPicker();
      }
    ];
    const lifecycleToken: number = this.pageLifecycleToken;
    const chatId: number = this.activeChatId;
    this.getUIContext().getPromptAction().showActionMenu({
      title: '',
      buttons: buttons as [promptAction.Button, promptAction.Button?, promptAction.Button?,
        promptAction.Button?, promptAction.Button?, promptAction.Button?]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (lifecycleToken !== this.pageLifecycleToken || this.activeChatId !== chatId) {
        return;
      }
      if (result.index >= 0 && result.index < actions.length) {
        actions[result.index]();
      }
    }).catch((_: Error) => {
      // User dismissed — no action needed.
    });
  }

  private handleComposerEmojiPress(): void {
    if (this.activeChatId === 0) {
      return;
    }
    this.showComposerEmojiPanel = !this.showComposerEmojiPanel;
  }

  private handleComposerVoicePress(): void {
    this.showComposerEmojiPanel = false;
    this.showComposerPendingToast(localized($r('app.string.composer_voice_unavailable').id,
      'Voice recording is not available yet'));
  }

  private handleComposerEmojiSelected(emoji: string): void {
    if (this.activeChatId === 0 || emoji.length === 0) {
      return;
    }
    this.composerDraftText = `${this.composerDraftText}${emoji}`;
  }

  private handleComposerStickerPress(): void {
    this.showComposerPendingToast(localized($r('app.string.composer_stickers_unavailable').id,
      'Stickers are not available yet'));
  }

  private async openPhotoAttachmentPicker(kind: string): Promise<void> {
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: kind === 'video'
          ? photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE
          : photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
        isSearchSupported: true,
        isPhotoTakingSupported: true
      });
      if (result.photoUris.length === 0) {
        return;
      }
      const title = kind === 'video'
        ? localized($r('app.string.video').id, 'Video')
        : localized($r('app.string.photo').id, 'Photo');
      this.setPendingAttachment(kind, title, result.photoUris);
    } catch (error) {
      this.handleAttachmentPickerError(error);
    }
  }

  private async openDocumentAttachmentPicker(): Promise<void> {
    try {
      const documentOptions = new picker.DocumentSelectOptions();
      documentOptions.maxSelectNumber = 1;
      const documentPicker = new picker.DocumentViewPicker();
      const result: string[] = await documentPicker.select(documentOptions);
      if (!result || result.length === 0) {
        return;
      }
      this.setPendingAttachment('document',
        localized($r('app.string.document_label').id, 'Document'),
        result);
    } catch (error) {
      this.handleAttachmentPickerError(error);
    }
  }

  private handleAttachmentPickerError(error: Object): void {
    const message = String(error);
    if (message.toLowerCase().includes('cancel')) {
      return;
    }
    hilog.error(DOMAIN, TAG, 'Attachment picker failed: %{public}s', message);
    this.showComposerPendingToast(localized($r('app.string.composer_attachment_unavailable').id,
      'Attachment picker is not available yet'));
  }

  private setPendingAttachment(kind: string, title: string, uris: string[]): void {
    this.pendingAttachmentKind = kind;
    this.pendingAttachmentTitle = title;
    this.pendingAttachmentUris = uris;
    this.pendingAttachmentPreview = this.buildAttachmentPreview(uris);
    this.showComposerEmojiPanel = false;
  }

  private clearPendingAttachment(): void {
    this.pendingAttachmentKind = '';
    this.pendingAttachmentTitle = '';
    this.pendingAttachmentPreview = '';
    this.pendingAttachmentUris = [];
  }

  private async preparePickedAttachmentLocalPath(kind: string, sourceUri: string): Promise<string> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const targetDir = this.ensureComposerSendMediaDir(context);
    const targetPath = `${targetDir}/${this.buildComposerSendMediaFileName(kind, sourceUri)}`;
    let sourceFile: fileIo.File | undefined = undefined;

    try {
      sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      fileIo.copyFileSync(sourceFile.fd, targetPath);
      return targetPath;
    } catch (error) {
      const err = error as Error;
      throw new Error(`Prepare picked attachment failed: ${err.message}`);
    } finally {
      if (sourceFile !== undefined) {
        try {
          fileIo.closeSync(sourceFile);
        } catch (closeError) {
          hilog.warn(DOMAIN, TAG, 'Attachment source close failed: %{public}s', String(closeError));
        }
      }
    }
  }

  private ensureComposerSendMediaDir(context: common.UIAbilityContext): string {
    const targetDir = `${context.filesDir}/composer_send_media`;
    try {
      if (fileIo.accessSync(targetDir)) {
        return targetDir;
      }
    } catch (_error) {
      // Directory does not exist or cannot be accessed; mkdir below will surface real failures.
    }
    try {
      fileIo.mkdirSync(targetDir, true);
    } catch (error) {
      const err = error as Error;
      throw new Error(`Create composer media directory failed: ${err.message}`);
    }
    return targetDir;
  }

  private buildComposerSendMediaFileName(kind: string, sourceUri: string): string {
    const rawName = this.safeAttachmentFileName(this.lastUriSegment(sourceUri));
    const extension = this.attachmentFileExtension(kind, rawName);
    const baseName = this.attachmentFileStem(rawName);
    return `tg_send_${kind}_${Date.now()}_${baseName}${extension}`;
  }

  private safeAttachmentFileName(name: string): string {
    let decoded = name;
    try {
      decoded = decodeURIComponent(name);
    } catch (_error) {
      decoded = name;
    }
    const safe = decoded.replace(/[^A-Za-z0-9._-]/g, '_');
    return safe.length > 0 ? safe.substring(0, 48) : 'attachment';
  }

  private attachmentFileStem(fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.');
    const stem = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    return stem.length > 0 ? stem : 'attachment';
  }

  private attachmentFileExtension(kind: string, fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.');
    if (dotIndex >= 0 && dotIndex < fileName.length - 1 && fileName.length - dotIndex <= 12) {
      return fileName.substring(dotIndex);
    }
    switch (kind) {
      case 'photo':
        return '.jpg';
      case 'video':
        return '.mp4';
      default:
        return '.bin';
    }
  }

  private buildAttachmentPreview(uris: string[]): string {
    if (uris.length === 0) {
      return '';
    }
    const first = this.lastUriSegment(uris[0]);
    if (uris.length === 1) {
      return first;
    }
    return `${first} +${uris.length - 1}`;
  }

  private lastUriSegment(uri: string): string {
    const withoutQuery = uri.split('?')[0];
    const parts = withoutQuery.split('/');
    const last = parts.length > 0 ? parts[parts.length - 1] : uri;
    return last.length > 0 ? last : uri;
  }

  private startEditMessage(messageId: string, originalText: string): void {
    this.clearReplyMode();
    this.clearForwardMode();
    this.isEditingMessage = true;
    this.editingMessageId = messageId;
    this.editingOriginalText = originalText;
    this.composerDraftText = originalText;
    hilog.info(DOMAIN, TAG, 'Edit mode started for message %{public}s', messageId);
  }

  private cancelEditMessage(): void {
    this.clearEditMode(true);
  }

  private handleEditMessage(newText: string): void {
    const useCase = this.editUseCase;
    const chatId = this.activeChatId;
    const messageId = this.editingMessageId;
    if (!useCase || chatId === 0 || messageId === '0') {
      return;
    }
    if (newText.trim().length === 0) {
      // Empty edit = cancel
      this.cancelEditMessage();
      return;
    }
    if (newText === this.editingOriginalText) {
      // No changes = cancel
      this.cancelEditMessage();
      return;
    }

    const params = new EditMessageParams();
    params.chatId = chatId;
    params.messageId = messageId;
    params.text = newText;
    const editId = messageId;

    this.clearEditMode(true);

    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.execute(params)
      .then(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.editUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Message %{public}s edited', editId);
      })
      .catch((err: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.editUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Edit failed: %{public}s', err.message);
      });
  }

  private handleForwardMessages(commentText: string): void {
    const forwardUseCase = this.forwardUseCase;
    const sendUseCase = this.sendUseCase;
    if (this.isSending || this.activeChatId === 0 || !forwardUseCase) {
      return;
    }
    if (this.forwardSourceChatId === 0 || this.forwardingMessageIds.length === 0) {
      return;
    }

    const targetChatId = this.activeChatId;
    const sourceChatId = this.forwardSourceChatId;
    const messageIds = [...this.forwardingMessageIds];
    const previewTitle = this.forwardTitle;
    const previewText = this.forwardPreview;
    const trimmedComment = commentText.trim();
    const wasNearBottom = this.isNearBottom();
    let commentSent = false;

    this.isSending = true;
    this.composerDraftText = '';
    this.clearReplyMode();
    this.clearEditMode(false);
    this.clearForwardMode();

    const lifecycleToken: number = this.pageLifecycleToken;
    Promise.resolve()
      .then(async () => {
        if (trimmedComment.length > 0 && sendUseCase) {
          const sendParams = new SendMessageParams();
          sendParams.chatId = targetChatId;
          sendParams.text = trimmedComment;
          await sendUseCase.execute(sendParams);
          commentSent = true;
        }

        const params = new ForwardMessagesParams();
        params.chatId = targetChatId;
        params.fromChatId = sourceChatId;
        params.messageIds = messageIds;
        await forwardUseCase.execute(params);

        if (lifecycleToken !== this.pageLifecycleToken ||
          this.forwardUseCase !== forwardUseCase ||
          this.activeChatId !== targetChatId ||
          (sendUseCase !== undefined && this.sendUseCase !== sendUseCase)) {
          return;
        }
        if (wasNearBottom) {
          this.scheduleLifecycleTask(100, () => {
            this.listScroller.scrollEdge(Edge.Bottom);
          });
        }
      })
      .then(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.forwardUseCase !== forwardUseCase ||
          this.activeChatId !== targetChatId ||
          (sendUseCase !== undefined && this.sendUseCase !== sendUseCase)) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Forwarded %{public}d messages into chat %{public}d', messageIds.length, targetChatId);
      })
      .catch((err: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.forwardUseCase !== forwardUseCase ||
          this.activeChatId !== targetChatId ||
          (sendUseCase !== undefined && this.sendUseCase !== sendUseCase)) {
          return;
        }
        this.isForwardingMessages = true;
        this.forwardingMessageIds = [...messageIds];
        this.forwardSourceChatId = sourceChatId;
        this.forwardTitle = previewTitle;
        this.forwardPreview = previewText;
        if (!commentSent && trimmedComment.length > 0) {
          this.composerDraftText = trimmedComment;
        }
        hilog.error(DOMAIN, TAG, 'Forward failed: %{public}s', err.message);
      })
      .finally(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.forwardUseCase !== forwardUseCase ||
          this.activeChatId !== targetChatId ||
          (sendUseCase !== undefined && this.sendUseCase !== sendUseCase)) {
          return;
        }
        this.isSending = false;
      });
  }

  private handlePinMessage(messageId: string): void {
    const useCase = this.pinUseCase;
    const chatId = this.activeChatId;
    if (!useCase || chatId === 0) return;

    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.pin(chatId, messageId, false, false)
      .then(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.pinUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Message %{public}s pinned', messageId);
      })
      .catch((err: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.pinUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Pin failed: %{public}s', err.message);
      });
  }

  private handleDeleteMessage(messageId: string): void {
    const useCase = this.deleteUseCase;
    const chatId = this.activeChatId;
    if (!useCase || chatId === 0) {
      return;
    }

    const params = new DeleteMessagesParams();
    params.chatId = chatId;
    params.messageIds = [messageId];
    params.revoke = true;

    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.execute(params)
      .then(() => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.deleteUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Message %{public}s deleted', messageId);
      })
      .catch((err: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.deleteUseCase !== useCase ||
          this.activeChatId !== chatId) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Delete failed: %{public}s', err.message);
      });
  }

  private handleSearchQueryChange(query: string): void {
    this.searchQuery = query;
    // iOS ref: 0.2s debounce before sending search request
    if (this.searchDebounceTimerId !== -1) {
      clearTimeout(this.searchDebounceTimerId);
      this.searchDebounceTimerId = -1;
    }
    if (query.trim().length === 0) {
      return;
    }
    const lifecycleToken: number = this.pageLifecycleToken;
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (lifecycleToken !== this.pageLifecycleToken || this.searchDebounceTimerId !== scheduledTimerId) {
        return;
      }
      this.searchDebounceTimerId = -1;
      this.executeSearch(query);
    }, 200) as number;
    this.searchDebounceTimerId = scheduledTimerId;
  }

  private executeSearch(query: string): void {
    const useCase = this.searchUseCase;
    const chatId = this.activeChatId;
    if (!useCase || chatId === 0) return;

    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.execute(chatId, query)
      .then((result: SearchChatMessagesResult) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.searchUseCase !== useCase ||
          this.activeChatId !== chatId ||
          !this.isSearchMode ||
          this.searchQuery !== query) {
          return;
        }
        if (result.messageIds.length > 0) {
          // Auto-navigate to first result (iOS pattern)
          const firstId = result.messageIds[0];
          const count = this.dataSource.totalCount();
          for (let i = 0; i < count; i++) {
            const entry: ChatTimelineEntryVO = this.dataSource.getData(i);
            if (entry.kind === 'message' && entry.message.messageId === firstId) {
              this.listScroller.scrollToIndex(i);
              break;
            }
          }
          hilog.info(DOMAIN, TAG, 'Search: navigated to first of %{public}d results', result.totalCount);
        } else {
          hilog.info(DOMAIN, TAG, 'Search: no results for "%{public}s"', query);
        }
      })
      .catch((err: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken ||
          this.searchUseCase !== useCase ||
          this.activeChatId !== chatId ||
          !this.isSearchMode ||
          this.searchQuery !== query) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Search failed: %{public}s', err.message);
      });
  }

  private closeSearch(): void {
    this.isSearchMode = false;
    this.searchQuery = '';
    if (this.searchDebounceTimerId !== -1) {
      clearTimeout(this.searchDebounceTimerId);
      this.searchDebounceTimerId = -1;
    }
  }

  private openProfile(): void {
    if (this.activeChatId <= 0) return;
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

  private isNearBottom(): boolean {
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

  private bindNavigationStack(): NavPathStack | undefined {
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
        hasLocalPhoto: entry.message.hasLocalPhoto,
        isPhotoDownloading: entry.message.isPhotoDownloading || this.isMediaDownloadPending(entry.message.photoFileId),
        photoDownloadProgress: entry.message.photoDownloadProgress,
        photoWidth: entry.message.photoWidth,
        photoHeight: entry.message.photoHeight,
        albumPhotoPaths: entry.message.albumPhotoPaths,
        albumPhotoWidths: entry.message.albumPhotoWidths,
        albumPhotoHeights: entry.message.albumPhotoHeights,
        videoThumbPath: entry.message.videoThumbPath,
        videoPath: entry.message.videoPath,
        isVideoDownloading: entry.message.isVideoDownloading || this.isMediaDownloadPending(entry.message.videoFileId),
        videoDownloadProgress: entry.message.videoDownloadProgress,
        videoDuration: entry.message.videoDuration,
        videoWidth: entry.message.videoWidth,
        videoHeight: entry.message.videoHeight,
        documentPath: entry.message.documentPath,
        documentFileId: entry.message.documentFileId,
        isDocumentDownloading: entry.message.isDocumentDownloading ||
          this.isMediaDownloadPending(entry.message.documentFileId),
        documentDownloadProgress: entry.message.documentDownloadProgress,
        audioPath: entry.message.audioPath,
        audioFileId: entry.message.audioFileId,
        isAudioDownloading: entry.message.isAudioDownloading || this.isMediaDownloadPending(entry.message.audioFileId),
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
        voiceDownloadProgress: entry.message.voiceDownloadProgress,
        voiceDuration: entry.message.voiceDuration,
        voiceWaveform: entry.message.voiceWaveform,
        isVoiceListened: this.effectiveVoiceListened(entry),
        isVoicePlaying: this.isActiveVoiceEntry(entry) ? this.activeVoicePlaying : false,
        voicePlaybackProgress: this.isActiveVoiceEntry(entry) ? this.activeVoiceProgress : 0,
        isAudioPlaying: this.isActiveAudioEntry(entry) ? this.activeAudioPlaying : false,
        audioPlaybackProgress: this.isActiveAudioEntry(entry) ? this.activeAudioProgress : 0,
        stickerPath: entry.message.stickerPath,
        stickerWidth: entry.message.stickerWidth,
        stickerHeight: entry.message.stickerHeight,
        isAnimatedSticker: entry.message.isAnimatedSticker,
        isVideoSticker: entry.message.isVideoSticker,
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
          this.requestMediaDownload(fileId);
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
          this.handleDocumentTap(documentPath, documentFileId, mimeType);
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
                    .reuseId(this.entryReuseId(entry))
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
          title: this.title,
          subtitle: this.chatSubtitle,
          subtitleMode: this.chatSubtitleMode,
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
          isSearchMode: this.isSearchMode,
          searchQuery: this.searchQuery,
          onSearchQueryChange: (query: string): void => {
            this.handleSearchQueryChange(query);
          },
          onSearchClose: (): void => {
            this.closeSearch();
          }
        })
        .hitTestBehavior(HitTestMode.Transparent)

        // ── Composer overlay (glass, floats over content at bottom) ──
        Column() {
            Blank()
              .hitTestBehavior(HitTestMode.None)
            Column() {
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
