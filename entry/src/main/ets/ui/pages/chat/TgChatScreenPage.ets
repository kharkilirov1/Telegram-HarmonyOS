// TgChatScreenPage — chat message timeline
// Phase D-3: Stack overlay — message list scrolls under translucent top bar for blur

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { fileUri } from '@kit.CoreFileKit';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgDateSeparator, TgUnreadMarker } from '../../tg_ui/atoms/TgDateSeparator';
import { TgMessageRouter } from '../../tg_ui/molecules/TgMessageRouter';
import { TgComposerInput } from '../../tg_ui/atoms/TgComposerInput';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { ProfileRouteParams } from '../profile/TgProfilePage';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO, buildChatTimeline } from './ChatTimelineVO';
import { VoicePlaybackController, VoicePlaybackSnapshot } from './VoicePlaybackController';
import { SendMessageParams, createSendMessageUseCase, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import {
  LoadChatHistoryUseCase,
  LoadChatHistoryParams,
  createLoadChatHistoryUseCase
} from '../../../domain/usecases/loadChatHistory';
import { createMarkChatReadUseCase, MarkChatReadUseCase } from '../../../domain/usecases/markChatRead';
import { createCloseChatCommand, createDownloadFileCommand } from '../../../core/model/AppCommand';
import { FileDownloadedEvent } from '../../../core/model/AppEvent';
import { TdObject } from '../../../models/td/common/index';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { TgPhotoViewerPage } from './TgPhotoViewerPage';
import { TgVideoPlayerPage } from './TgVideoPlayerPage';
import { localized } from '../../../core/utils/AppResource';
import { computeTopBarHeight, computeChatBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction, uiObserver, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
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

@Component
export struct TgChatScreenPage {
  pageStack: NavPathStack = new NavPathStack();

  @StorageLink(StorageKeys.ACTIVE_CHAT_ID) @Watch('onActiveChatChanged') activeChatId: number = 0;
  @StorageLink(StorageKeys.ACTIVE_CHAT_TITLE) activeChatTitle: string = '';

  @State private title: string = 'Chat';
  @State private chatSubtitle: string = '';
  @State private chatAvatarInitials: string = '';
  @State private chatAvatarColorIndex: number = 0;
  @State private chatAvatarImageSrc: string = '';
  @State private chatIsOnline: boolean = false;
  @State private timelineContainerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @State private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @State private bottomOverlayInset: number = TgUiTokens.SPACE_8;
  @State private composerTotalHeight: number = 52; // default: button(40) + vertical insets(12)
  @State private composerDraftText: string = '';
  @State private awaitingInitialTimeline: boolean = false;
  @State private prependScrollMask: boolean = false;
  @State private listInitialIndex: number = 0;
  @State private replyToMessageId: string = '0';
  @State private replyToAuthor: string = '';
  @State private replyToPreview: string = '';
  // ── Media viewer state ──
  @State private showPhotoViewer: boolean = false;
  @State private viewerPhotoPath: string = '';
  @State private viewerPhotoCaption: string = '';
  @State private showVideoPlayer: boolean = false;
  @State private viewerVideoPath: string = '';
  @State private viewerVideoCaption: string = '';
  @State private viewerVideoThumbPath: string = '';
  @State private activeVoiceMessageId: string = '0';
  @State private activeVoiceProgress: number = 0;
  @State private activeVoicePlaying: boolean = false;
  private dataSource: ChatTimelineDataSource = new ChatTimelineDataSource();
  private listScroller: Scroller = new Scroller();
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private mainWindow?: window.Window;
  private sendUseCase?: SendMessageUseCase;
  private loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  private markChatReadUseCase?: MarkChatReadUseCase;
  private isSending: boolean = false;
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
  private voicePlaybackController?: VoicePlaybackController;
  private locallyListenedVoiceIds: Set<string> = new Set<string>();
  private pendingVideoOpenFileId: number = 0;
  private pendingVideoOpenCaption: string = '';
  private pendingVideoOpenThumbPath: string = '';

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
      this.clearPendingVideoOpen();
      if (this.paginationRecheckTimerId >= 0) {
        clearTimeout(this.paginationRecheckTimerId);
        this.paginationRecheckTimerId = -1;
      }
      this.resetPaginationState();
      this.teardownVoicePlaybackController();
      if (this.activeChatId !== 0) {
        this.setupVoicePlaybackController();
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
      this.bindNavigationStack();
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
      this.computeSafeInsets();

      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.sendUseCase = createSendMessageUseCase(getTdGatewayAdapter());
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
      this.setupVoicePlaybackController();
      this.awaitingInitialTimeline = this.activeChatId !== 0;
      // Capture lastReadInboxMessageId at chat entry — survives markChatRead
      const initialState = store.getState();
      const entryChat = initialState.chats.chats.get(this.activeChatId);
      this.stickyLastReadMessageId = (entryChat && entryChat.unreadCount > 0)
        ? entryChat.lastReadInboxMessageId : '';
      this.rebuildTimeline(initialState);
      this.scheduleHistoryLoad(this.activeChatId, 0);
      // Do NOT call maybeMarkChatRead here — openChat hasn't reached TDLib yet.
      // The store subscription will call it after history loads (openChat is done by then).

      this.unsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (!this.shouldReactToStoreChange(_newState, _prevState)) {
          return;
        }
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          setTimeout(() => {
            this.rebuildScheduled = false;
            try {
              const currentState = getAppCoreRuntime().getStore().getState();
              this.rebuildTimeline(currentState);
              this.maybeMarkChatRead(currentState);
            } catch (e) {
              hilog.error(DOMAIN, TAG, 'Timeline rebuild failed: %{public}s', String(e));
            }
          }, 0);
        }
      });

      this.bindWindowSizeListener();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'aboutToAppear failed: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
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
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, 0);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, '');
    if (this.historyFallbackTimerId >= 0) {
      clearTimeout(this.historyFallbackTimerId);
      this.historyFallbackTimerId = -1;
    }
    this.isLoadingOlder = false;
    this.isLoadingNewer = false;
    this.isMarkingChatRead = false;
    this.suppressLoadOlderUntil = 0;
    this.unreadRestoreIndex = -1;
    this.stickyLastReadMessageId = '';
    this.lastMarkReadRequestKey = '';
    this.blockAutoPaginationUntilUserScroll = false;
    this.isApplyingTimelineDiff = false;
    this.clearPendingVideoOpen();
    if (this.paginationRecheckTimerId >= 0) {
      clearTimeout(this.paginationRecheckTimerId);
      this.paginationRecheckTimerId = -1;
    }
    this.resetPaginationState();
    this.awaitingInitialTimeline = false;
    this.loadChatHistoryUseCase = undefined;
    this.markChatReadUseCase = undefined;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    removeWindowSizeListener(this.mainWindow);
    this.mainWindow = undefined;
    this.teardownVoicePlaybackController();
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
    return newState.users.users !== prevState.users.users;
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
      this.mainWindow = getMainWindow(context);
      if (this.mainWindow !== undefined) {
        this.updateTimelineContainerWidth(this.mainWindow.getWindowProperties().windowRect.width);
        this.mainWindow.on('windowSizeChange', (size: window.Size) => {
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

  private resetVoicePlaybackState(): void {
    this.activeVoiceMessageId = '0';
    this.activeVoiceProgress = 0;
    this.activeVoicePlaying = false;
    this.locallyListenedVoiceIds.clear();
  }

  private setupVoicePlaybackController(): void {
    const previous = this.voicePlaybackController;
    if (previous) {
      this.voicePlaybackController = undefined;
      previous.release().catch((_error: Object) => {});
    }
    this.resetVoicePlaybackState();
    const controller = new VoicePlaybackController();
    this.voicePlaybackController = controller;
    controller.setListener((snapshot: VoicePlaybackSnapshot): void => {
      if (this.voicePlaybackController !== controller) {
        return;
      }
      this.activeVoiceMessageId = snapshot.messageId;
      this.activeVoiceProgress = snapshot.progress;
      this.activeVoicePlaying = snapshot.isPlaying;
    });
  }

  private teardownVoicePlaybackController(): void {
    const controller = this.voicePlaybackController;
    this.voicePlaybackController = undefined;
    this.resetVoicePlaybackState();
    if (!controller) {
      return;
    }
    controller.release()
      .catch((_error: Object) => {});
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

  private updateChatTopBarData(state: AppState): void {
    const chat = state.chats.chats.get(this.activeChatId);
    if (chat === undefined) {
      this.chatSubtitle = '';
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
        this.chatIsOnline = user.status === 'online';
      } else {
        this.chatSubtitle = '';
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
      this.chatIsOnline = false;
    }

    // Typing indicator overrides subtitle
    const typingInfo = state.chats.typingActions.get(this.activeChatId);
    if (typingInfo && (Date.now() - typingInfo.timestamp) < 6000) {
      this.chatSubtitle = 'typing...';
    }
  }

  private rebuildTimeline(state: AppState): void {
    if (this.activeChatId === 0) {
      this.dataSource.applyDiff([]);
      this.title = this.activeChatTitle.length > 0
        ? this.activeChatTitle
        : localized($r('app.string.chats_title').id, 'Chat');
      this.chatSubtitle = '';
      this.chatAvatarInitials = '';
      this.chatAvatarColorIndex = 0;
      this.chatAvatarImageSrc = '';
      this.chatIsOnline = false;
      this.awaitingInitialTimeline = false;
      this.clearPendingVideoOpen();
      return;
    }

    const result = buildChatTimeline(this.activeChatId, state, this.stickyLastReadMessageId);
    const chat = state.chats.chats.get(this.activeChatId);
    this.title = result.chatTitle.length > 0 ? result.chatTitle : this.activeChatTitle;
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
    this.maybeOpenPendingVideo(result.entries);
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
        setTimeout(() => {
          this.listScroller.scrollEdge(Edge.Bottom);
        }, 16);
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
    this.paginationRecheckTimerId = setTimeout(() => {
      this.paginationRecheckTimerId = -1;
      if (this.rebuildScheduled || this.isApplyingTimelineDiff) {
        this.schedulePaginationRecheck(16);
        return;
      }
      this.recheckPaginationEdge();
    }, delayMs);
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

    useCase.execute(params)
      .catch((_: Error) => {})
      .finally(() => {
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

    useCase.execute(params)
      .catch((_: Error) => {})
      .finally(() => {
        this.isLoadingNewer = false;
        this.schedulePaginationRecheck();
      });
  }

  private maybeMarkChatRead(state: AppState): void {
    const chatId = this.activeChatId;
    if (chatId === 0 || !this.markChatReadUseCase || this.isMarkingChatRead) {
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
    this.markChatReadUseCase.execute({ chatId: chatId })
      .catch((error: Object) => {
        hilog.warn(DOMAIN, TAG, 'markChatRead failed for %{public}d: %{public}s', chatId, String(error));
        if (this.activeChatId === chatId && this.lastMarkReadRequestKey === requestKey) {
          this.lastMarkReadRequestKey = '';
        }
      })
      .finally(() => {
        this.isMarkingChatRead = false;
      });
  }

  private requestMediaDownload(fileId: number): void {
    if (fileId <= 0) return;
    hilog.info(DOMAIN, TAG, 'On-demand media download requested: fileId=%{public}d', fileId);
    const command = createDownloadFileCommand(fileId, 5, false);
    getTdGatewayAdapter().send(command)
      .then((response: Object): void => {
        try {
          const tdResponse = response as TdObject;
          const local = tdResponse.getObject('local');
          const isComplete = local.getBool('is_downloading_completed');
          const path = local.getString('path');
          if (isComplete && path.length > 0) {
            hilog.info(DOMAIN, TAG, 'On-demand file ready: fileId=%{public}d', fileId);
            const event = new FileDownloadedEvent();
            event.fileId = fileId;
            event.localPath = path;
            event.isComplete = true;
            event.timestamp = Date.now();
            getAppCoreRuntime().getStore().dispatch(event);
          }
        } catch (_e) {}
      })
      .catch((error: Error): void => {
        hilog.warn(DOMAIN, TAG, 'On-demand download failed: fileId=%{public}d: %{public}s', fileId, error.message);
      });
  }

  private queuePendingVideoOpen(fileId: number, caption: string, thumbPath: string): void {
    this.pendingVideoOpenFileId = fileId;
    this.pendingVideoOpenCaption = caption;
    this.pendingVideoOpenThumbPath = thumbPath;
  }

  private clearPendingVideoOpen(): void {
    this.pendingVideoOpenFileId = 0;
    this.pendingVideoOpenCaption = '';
    this.pendingVideoOpenThumbPath = '';
  }

  private maybeOpenPendingVideo(entries: ChatTimelineEntryVO[]): void {
    if (this.pendingVideoOpenFileId <= 0 || entries.length === 0) {
      return;
    }
    for (const entry of entries) {
      if (entry.kind !== 'message') {
        continue;
      }
      if (entry.message.videoFileId !== this.pendingVideoOpenFileId) {
        continue;
      }
      if (entry.message.videoPath.length === 0) {
        continue;
      }
      this.viewerVideoPath = entry.message.videoPath;
      this.viewerVideoCaption = entry.message.caption.length > 0
        ? entry.message.caption
        : this.pendingVideoOpenCaption;
      this.viewerVideoThumbPath = entry.message.videoThumbPath.length > 0
        ? entry.message.videoThumbPath
        : this.pendingVideoOpenThumbPath;
      this.showVideoPlayer = true;
      this.clearPendingVideoOpen();
      break;
    }
  }

  private handleVoiceTap(messageId: string, voicePath: string, voiceFileId: number): void {
    if (voicePath.trim().length === 0) {
      if (voiceFileId > 0) {
        this.requestMediaDownload(voiceFileId);
      }
      return;
    }
    if (!this.voicePlaybackController) {
      this.setupVoicePlaybackController();
    }
    this.locallyListenedVoiceIds.add(messageId);
    const controller = this.voicePlaybackController;
    if (!controller) {
      return;
    }
    controller.toggle(messageId, voicePath)
      .catch((_error: Object) => {});
  }

  private openPhotoViewer(photoPath: string, caption: string): void {
    if (photoPath.length === 0) return;
    this.viewerPhotoPath = photoPath;
    this.viewerPhotoCaption = caption;
    this.showPhotoViewer = true;
  }

  private openVideoPlayer(videoPath: string, caption: string, thumbPath: string, videoFileId: number): void {
    if (videoPath.length > 0) {
      this.viewerVideoPath = videoPath;
      this.viewerVideoCaption = caption;
      this.viewerVideoThumbPath = thumbPath;
      this.showVideoPlayer = true;
      this.clearPendingVideoOpen();
      return;
    }
    if (videoFileId > 0) {
      this.queuePendingVideoOpen(videoFileId, caption, thumbPath);
      this.requestMediaDownload(videoFileId);
    }
  }

  @Builder
  private buildPhotoViewer() {
    TgPhotoViewerPage({
      photoPath: this.viewerPhotoPath,
      caption: this.viewerPhotoCaption,
      onDismiss: (): void => {
        this.showPhotoViewer = false;
      }
    })
  }

  @Builder
  private buildVideoPlayer() {
    TgVideoPlayerPage({
      videoPath: this.viewerVideoPath,
      caption: this.viewerVideoCaption,
      thumbnailPath: this.viewerVideoThumbPath,
      onDismiss: (): void => {
        this.showVideoPlayer = false;
      }
    })
  }

  private startReply(messageId: string, author: string, preview: string): void {
    this.replyToMessageId = messageId;
    this.replyToAuthor = author.length > 0 ? author : 'Message';
    const trimmed = preview.trim();
    this.replyToPreview = trimmed.length > 0 ? trimmed : 'Message';
  }

  private cancelReply(): void {
    this.replyToMessageId = '0';
    this.replyToAuthor = '';
    this.replyToPreview = '';
  }

  private copyMessageText(text: string): void {
    if (text.trim().length === 0) {
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setDataSync(data);
      promptAction.showToast({ message: localized($r('app.string.copied').id, 'Copied'), duration: 1500 });
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

  private resolveReplyPreviewForEntry(entry: ChatTimelineEntryVO): string {
    if (entry.message.text.length > 0) {
      return entry.message.text;
    }
    if (entry.message.caption.length > 0) {
      return entry.message.caption;
    }
    return entry.message.contentType;
  }

  private showMessageActions(entry: ChatTimelineEntryVO): void {
    const messageText = entry.message.text.length > 0 ? entry.message.text :
      (entry.message.caption.length > 0 ? entry.message.caption : '');
    const hasText = messageText.trim().length > 0;
    const author = entry.message.isOutgoing ? 'You' :
      (entry.message.senderName.length > 0 ? entry.message.senderName : 'Message');
    const preview = this.resolveReplyPreviewForEntry(entry);
    const messageId = entry.message.messageId;

    const replyBtn: promptAction.Button = { text: localized($r('app.string.action_reply').id, 'Reply'), color: '#0088CC' };
    const copyBtn: promptAction.Button = { text: localized($r('app.string.action_copy').id, 'Copy'), color: '#000000' };

    promptAction.showActionMenu({
      title: '',
      buttons: hasText ? [replyBtn, copyBtn] : [replyBtn]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index === 0) {
        this.startReply(messageId, author, preview);
      } else if (result.index === 1 && hasText) {
        this.copyMessageText(messageText);
      }
    }).catch((_: Error) => {
      // User dismissed — no action needed
    });
  }

  private handleSendMessage(text: string): void {
    if (this.isSending || this.activeChatId === 0 || !this.sendUseCase) {
      return;
    }
    this.isSending = true;
    const params = new SendMessageParams();
    params.chatId = this.activeChatId;
    params.text = text;
    if (this.replyToMessageId !== '0') {
      params.replyToMessageId = this.replyToMessageId;
    }
    const sentText = text;
    this.composerDraftText = '';
    this.cancelReply();
    // Snapshot near-bottom state before async send completes.
    const wasNearBottom = this.isNearBottom();
    this.sendUseCase.execute(params)
      .then(() => {
        // Only auto-scroll to bottom if user was already near bottom.
        // If reading old messages, don't yank viewport away.
        if (wasNearBottom) {
          setTimeout(() => {
            this.listScroller.scrollEdge(Edge.Bottom);
          }, 100);
        }
      })
      .catch((err: Error) => {
        if (this.composerDraftText.trim().length === 0 && this.activeChatId === params.chatId) {
          this.composerDraftText = sentText;
        }
        hilog.error(DOMAIN, TAG, 'Send failed: %{public}s', err.message);
      })
      .finally(() => {
        this.isSending = false;
      });
  }

  private openProfile(): void {
    if (this.activeChatId <= 0) return;
    hilog.info(DOMAIN, TAG, 'openProfile chatId=%{public}d', this.activeChatId);
    const navStack: NavPathStack | undefined = this.bindNavigationStack();
    if (navStack !== undefined) {
      const params = new ProfileRouteParams(this.activeChatId);
      navStack.pushPathByName('TgProfilePage', params);
    }
  }

  private handleBackPress(): void {
    hilog.info(DOMAIN, TAG, 'handleBackPress called');
    this.saveScrollPosition();
    AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, Date.now() + CHAT_NAV_TRANSITION_LOCK_MS);
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, 0);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, '');
    const navStack: NavPathStack | undefined = this.bindNavigationStack();
    if (navStack !== undefined) {
      hilog.info(DOMAIN, TAG, 'Popping from pageStack');
      navStack.pop();
    } else {
      hilog.error(DOMAIN, TAG, 'pageStack is undefined in handleBackPress!');
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
        setTimeout(() => {
          this.guardProgrammaticScroll();
          this.listScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
          // After guard expires, check if near edge → trigger pagination
          this.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
        }, 16);
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
        setTimeout(() => {
          this.guardProgrammaticScroll();
          this.listScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
          this.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
        }, 16);
      } else {
        setTimeout(() => {
          this.listScroller.scrollEdge(Edge.Bottom);
        }, 16);
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
    this.historyFallbackTimerId = setTimeout(() => {
      this.historyFallbackTimerId = -1;
      this.requestHistoryWithRetry(chatId, attempt);
    }, delayMs);
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
    historyUseCase.execute(params)
      .then(() => {
        if (this.shouldRetryHistoryLoad(chatId) &&
          attempt + 1 < HISTORY_MAX_RETRY_ATTEMPTS &&
          this.activeChatId === chatId) {
          this.scheduleHistoryLoad(chatId, attempt + 1);
        }
      })
      .catch((error: Object) => {
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
    const statusKey = entry.message.sendStatus.toString();
    return `chat_msg_${contentKey}_${outKey}_${replyKey}_${senderKey}_${statusKey}`;
  }

  @Builder
  private buildReplyBar() {
    if (this.replyToMessageId !== '0') {
      Row() {
        // Blue reply indicator bar (iOS: 2pt bar)
        Column()
          .width(TgUiTokens.REPLY_SNIPPET_BAR_WIDTH)
          .height('100%')
          .backgroundColor(TgUiTokens.REPLY_SNIPPET_BAR_INCOMING)
          .borderRadius(TgUiTokens.REPLY_SNIPPET_BAR_RADIUS)

        // Reply content
        Column({ space: 2 }) {
          Text(this.replyToAuthor)
            .fontSize(TgUiTokens.REPLY_SNIPPET_TITLE_SIZE)
            .fontWeight(TgUiTokens.REPLY_SNIPPET_TITLE_WEIGHT)
            .fontColor(TgUiTokens.COLOR_ICON_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.replyToPreview)
            .fontSize(TgUiTokens.REPLY_SNIPPET_PREVIEW_SIZE)
            .fontWeight(FontWeight.Regular)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .margin({ left: TgUiTokens.REPLY_SNIPPET_BAR_GAP })

        // Close button
        Image($r('app.media.ic_close'))
          .width(20)
          .height(20)
          .fillColor(TgUiTokens.COLOR_ICON_SECONDARY)
          .onClick(() => {
            this.cancelReply();
          })
          .margin({ left: TgUiTokens.REPLY_SNIPPET_BAR_GAP })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.COMPOSER_SIDE_INSET + 4,
        right: TgUiTokens.COMPOSER_SIDE_INSET + 4,
        top: 8,
        bottom: 4
      })
      .height(45) // iOS: ReplyAccessoryPanelNode = 45pt
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private buildMessageItem(entry: ChatTimelineEntryVO) {
    Column() {
      TgMessageRouter({
        messageId: entry.message.messageId,
        contentType: entry.message.contentType,
        isOutgoing: entry.message.isOutgoing,
        containerWidth: this.timelineContainerWidth,
        text: entry.message.text,
        isEmojiOnly: entry.message.isEmojiOnly,
        forceBreakAll: entry.message.forceBreakAll,
        caption: entry.message.caption,
        photoPath: entry.message.photoPath,
        photoWidth: entry.message.photoWidth,
        photoHeight: entry.message.photoHeight,
        albumPhotoPaths: entry.message.albumPhotoPaths,
        albumPhotoWidths: entry.message.albumPhotoWidths,
        albumPhotoHeights: entry.message.albumPhotoHeights,
        videoThumbPath: entry.message.videoThumbPath,
        videoPath: entry.message.videoPath,
        videoDuration: entry.message.videoDuration,
        videoWidth: entry.message.videoWidth,
        videoHeight: entry.message.videoHeight,
        documentPath: entry.message.documentPath,
        documentFileId: entry.message.documentFileId,
        audioPath: entry.message.audioPath,
        audioFileId: entry.message.audioFileId,
        fileName: entry.message.fileName,
        fileSize: entry.message.fileSize,
        mimeType: entry.message.mimeType,
        voicePath: entry.message.voicePath,
        voiceFileId: entry.message.voiceFileId,
        voiceDuration: entry.message.voiceDuration,
        voiceWaveform: entry.message.voiceWaveform,
        isVoiceListened: this.effectiveVoiceListened(entry),
        isVoicePlaying: this.isActiveVoiceEntry(entry) ? this.activeVoicePlaying : false,
        voicePlaybackProgress: this.isActiveVoiceEntry(entry) ? this.activeVoiceProgress : 0,
        stickerPath: entry.message.stickerPath,
        stickerWidth: entry.message.stickerWidth,
        stickerHeight: entry.message.stickerHeight,
        isAnimatedSticker: entry.message.isAnimatedSticker,
        isVideoSticker: entry.message.isVideoSticker,
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
        replyPreview: entry.message.replyPreview,
        replyIsOutgoing: entry.message.replyIsOutgoing,
        replyIsQuote: entry.message.replyIsQuote,
        timeText: entry.message.timeText,
        sendStatus: entry.message.sendStatus,
        onMediaDownloadRequest: (fileId: number): void => {
          this.requestMediaDownload(fileId);
        },
        onPhotoTap: (): void => {
          this.openPhotoViewer(entry.message.photoPath, entry.message.caption);
        },
        onAlbumPhotoTap: (photoPath: string, caption: string): void => {
          this.openPhotoViewer(photoPath, caption);
        },
        onVideoTap: (): void => {
          this.openVideoPlayer(
            entry.message.videoPath,
            entry.message.caption,
            entry.message.videoThumbPath,
            entry.message.videoFileId
          );
        },
        onVoiceTap: (messageId: string, voicePath: string, voiceFileId: number): void => {
          this.handleVoiceTap(messageId, voicePath, voiceFileId);
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
          }
        })
        .hitTestBehavior(HitTestMode.Transparent)

        // ── Composer overlay (glass, floats over content at bottom) ──
        Column() {
          Blank()
          Column() {
            this.buildReplyBar()
            TgComposerInput({
              text: this.composerDraftText,
              placeholder: localized($r('app.string.message_placeholder').id, 'Message'),
              isDisabled: this.activeChatId === 0,
              bottomInset: this.bottomOverlayInset,
              onTextChange: (value: string): void => {
                this.composerDraftText = value;
              },
              onSendPress: (text: string): void => {
                this.handleSendMessage(text);
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

        if (this.showPhotoViewer) {
          this.buildPhotoViewer()
        }

        if (this.showVideoPlayer) {
          this.buildVideoPlayer()
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
  }
}
