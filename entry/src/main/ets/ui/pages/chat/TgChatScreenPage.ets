// TgChatScreenPage — chat message timeline
// Phase D-3: Stack overlay — message list scrolls under translucent top bar for blur

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgDateSeparator, TgUnreadMarker } from '../../tg_ui/atoms/TgDateSeparator';
import { TgMessageRouter } from '../../tg_ui/molecules/TgMessageRouter';
import { TgMessageMeta } from '../../tg_ui/atoms/TgMessageMeta';
import { TgReplySnippet } from '../../tg_ui/atoms/TgReplySnippet';
import { TgComposerInput } from '../../tg_ui/atoms/TgComposerInput';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO, buildChatTimeline } from './ChatTimelineVO';
import { SendMessageParams, createSendMessageUseCase, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import {
  LoadChatHistoryUseCase,
  LoadChatHistoryParams,
  createLoadChatHistoryUseCase
} from '../../../domain/usecases/loadChatHistory';
import { createMarkChatReadUseCase, MarkChatReadUseCase } from '../../../domain/usecases/markChatRead';
import { createCloseChatCommand } from '../../../core/model/AppCommand';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { localized } from '../../../core/utils/AppResource';
import { computeTopBarHeight, computeChatBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiObserver, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const CHAT_NAV_TRANSITION_LOCK_MS = 760;
const HISTORY_INITIAL_DELAY_MS = 80;
const HISTORY_MAX_RETRY_ATTEMPTS = 4;
const HISTORY_RETRY_BASE_DELAY_MS = 450;
const PROGRAMMATIC_SCROLL_GUARD_MS = 320;
const TIMELINE_TOP_EDGE_TRIGGER_INDEX = 10;
const TIMELINE_BOTTOM_EDGE_TRIGGER_GAP = 6;
const INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT = 12;

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
  @State private awaitingInitialTimeline: boolean = false;

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
  private previousDataCount: number = 0;
  private needsScrollRestore: boolean = true;
  private currentScrollChatId: number = 0;
  private lastOpenedChatId: number = 0;
  private suppressLoadOlderUntil: number = 0;
  private unreadRestoreIndex: number = -1;
  private lastMarkReadRequestKey: string = '';
  private blockAutoPaginationUntilUserScroll: boolean = false;
  private olderPaginationEdgeArmed: boolean = true;
  private newerPaginationEdgeArmed: boolean = true;
  private static scrollPositionCache: Map<number, number> = new Map<number, number>();

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
      this.previousDataCount = 0;
      this.isLoadingOlder = false;
      this.isLoadingNewer = false;
      this.suppressLoadOlderUntil = 0;
      this.unreadRestoreIndex = -1;
      this.lastMarkReadRequestKey = '';
      this.blockAutoPaginationUntilUserScroll = false;
      this.resetPaginationEdgeLatches();
      this.awaitingInitialTimeline = this.activeChatId !== 0;
      this.currentScrollChatId = this.activeChatId;
      const state = getAppCoreRuntime().getStore().getState();
      this.rebuildTimeline(state);
      this.scheduleHistoryLoad(this.activeChatId, 0);
      this.maybeMarkChatRead(state);
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
      this.previousDataCount = 0;
      this.suppressLoadOlderUntil = 0;
      this.isLoadingNewer = false;
      this.unreadRestoreIndex = -1;
      this.lastMarkReadRequestKey = '';
      this.blockAutoPaginationUntilUserScroll = false;
      this.resetPaginationEdgeLatches();
      this.awaitingInitialTimeline = this.activeChatId !== 0;
      this.rebuildTimeline(store.getState());
      this.scheduleHistoryLoad(this.activeChatId, 0);
      this.maybeMarkChatRead(store.getState());

      this.unsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
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
    AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, Date.now() + CHAT_NAV_TRANSITION_LOCK_MS);
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
    this.lastMarkReadRequestKey = '';
    this.blockAutoPaginationUntilUserScroll = false;
    this.resetPaginationEdgeLatches();
    this.awaitingInitialTimeline = false;
    this.loadChatHistoryUseCase = undefined;
    this.markChatReadUseCase = undefined;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    removeWindowSizeListener(this.mainWindow);
    this.mainWindow = undefined;
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
    this.chatAvatarImageSrc = chat.photoSmall;

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
      this.chatSubtitle = '';
      this.chatIsOnline = false;
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
      return;
    }

    const result = buildChatTimeline(this.activeChatId, state);
    const chat = state.chats.chats.get(this.activeChatId);
    this.title = result.chatTitle.length > 0 ? result.chatTitle : this.activeChatTitle;
    this.updateChatTopBarData(state);
    this.unreadRestoreIndex = result.unreadEntryIndex;
    const prevCount = this.previousDataCount;
    this.dataSource.applyDiff(result.entries);
    const newCount = this.dataSource.totalCount();
    this.previousDataCount = newCount;
    if (newCount >= INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT) {
      this.awaitingInitialTimeline = false;
    } else if (!chat || !chat.lastMessage || chat.lastMessage.id === '0') {
      this.awaitingInitialTimeline = false;
    } else if (this.loadChatHistoryUseCase &&
      !this.loadChatHistoryUseCase.canLoadOlderMessages(this.activeChatId)) {
      this.awaitingInitialTimeline = false;
    }

    if (this.needsScrollRestore && newCount > 0) {
      this.needsScrollRestore = false;
      this.restoreScrollPosition();
    } else {
      const prependCount = this.dataSource.getLastPrependCount();
      if (prependCount > 0 && prevCount > 0 && this.lastVisibleStartIndex >= 0) {
        // Old messages prepended — compensate scroll to keep position stable
        const targetIndex = this.lastVisibleStartIndex + prependCount;
        this.guardProgrammaticScroll();
        setTimeout(() => {
          this.guardProgrammaticScroll();
          this.listScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
        }, 16);
      } else if (prevCount > 0 && newCount > prevCount && this.isNearBottom()) {
        // New messages arrived while user is at bottom — stay at bottom
        setTimeout(() => {
          this.listScroller.scrollEdge(Edge.Bottom);
        }, 16);
      }
    }
  }

  private guardProgrammaticScroll(durationMs: number = PROGRAMMATIC_SCROLL_GUARD_MS): void {
    const guardUntil = Date.now() + durationMs;
    if (guardUntil > this.suppressLoadOlderUntil) {
      this.suppressLoadOlderUntil = guardUntil;
    }
  }

  private resetPaginationEdgeLatches(): void {
    this.olderPaginationEdgeArmed = true;
    this.newerPaginationEdgeArmed = true;
  }

  private isNearTopPaginationEdge(start: number): boolean {
    return start < TIMELINE_TOP_EDGE_TRIGGER_INDEX;
  }

  private isNearBottomPaginationEdge(end: number, totalCount: number): boolean {
    return totalCount > 0 && end >= totalCount - TIMELINE_BOTTOM_EDGE_TRIGGER_GAP;
  }

  private refreshPaginationEdgeLatches(start: number, end: number, totalCount: number): void {
    if (!this.isNearTopPaginationEdge(start)) {
      this.olderPaginationEdgeArmed = true;
    }
    if (!this.isNearBottomPaginationEdge(end, totalCount)) {
      this.newerPaginationEdgeArmed = true;
    }
  }

  private armAutoPaginationUnlock(targetIndex: number, reason: string): void {
    if (targetIndex >= 10) {
      return;
    }
    this.blockAutoPaginationUntilUserScroll = true;
    this.guardProgrammaticScroll(PROGRAMMATIC_SCROLL_GUARD_MS * 2);
    hilog.info(DOMAIN, TAG,
      'Blocking auto pagination after programmatic restore to %{public}d (%{public}s)',
      targetIndex, reason);
  }

  private maybeUnlockAutoPagination(scrollOffset: number, scrollState: ScrollState): void {
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
    params.reason = 'restore';

    useCase.execute(params)
      .catch((_: Error) => {})
      .finally(() => {
        this.isLoadingOlder = false;
      });
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
    params.reason = 'restore';

    useCase.execute(params)
      .catch((_: Error) => {})
      .finally(() => {
        this.isLoadingNewer = false;
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

  private handleSendMessage(text: string): void {
    if (this.isSending || this.activeChatId === 0 || !this.sendUseCase) {
      return;
    }
    this.isSending = true;
    const params = new SendMessageParams();
    params.chatId = this.activeChatId;
    params.text = text;
    this.sendUseCase.execute(params)
      .then(() => {
        setTimeout(() => {
          this.listScroller.scrollEdge(Edge.Bottom);
        }, 100);
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'Send failed: %{public}s', err.message);
      })
      .finally(() => {
        this.isSending = false;
      });
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
    if (chatId !== 0 && this.lastVisibleStartIndex >= 0) {
      TgChatScreenPage.scrollPositionCache.set(chatId, this.lastVisibleStartIndex);
      hilog.info(DOMAIN, TAG, 'Saved scroll position %{public}d for chat %{public}d',
        this.lastVisibleStartIndex, chatId);
    }
  }

  private restoreScrollPosition(): void {
    const chatId = this.activeChatId;
    const totalCount = this.dataSource.totalCount();
    if (totalCount === 0) {
      return;
    }
    this.guardProgrammaticScroll();
    // Small delay to let List layout complete after data change
    setTimeout(() => {
      this.guardProgrammaticScroll();
      const savedIndex = TgChatScreenPage.scrollPositionCache.get(chatId);
      if (savedIndex !== undefined && savedIndex < totalCount) {
        this.armAutoPaginationUnlock(savedIndex, 'savedIndex');
        hilog.info(DOMAIN, TAG, 'Restoring scroll to index %{public}d for chat %{public}d',
          savedIndex, chatId);
        this.lastVisibleStartIndex = savedIndex;
        this.listScroller.scrollToIndex(savedIndex, false, ScrollAlign.START);
      } else if (this.unreadRestoreIndex >= 0 && this.unreadRestoreIndex < totalCount) {
        const targetIndex = Math.max(0, this.unreadRestoreIndex - 1);
        this.armAutoPaginationUnlock(targetIndex, 'unreadBoundary');
        hilog.info(DOMAIN, TAG, 'Restoring scroll to unread boundary %{public}d for chat %{public}d',
          targetIndex, chatId);
        this.lastVisibleStartIndex = targetIndex;
        this.listScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
      } else {
        // First open — scroll to bottom (newest messages)
        hilog.info(DOMAIN, TAG, 'First open, scrolling to bottom for chat %{public}d', chatId);
        this.listScroller.scrollEdge(Edge.Bottom);
      }
    }, 50);
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
    const statusKey = entry.message.sendStatus.toString();
    return `chat_msg_${contentKey}_${outKey}_${replyKey}_${statusKey}`;
  }

  @Builder
  private buildMessageItem(entry: ChatTimelineEntryVO) {
    Column({ space: TgUiTokens.SPACE_4 }) {
      if (entry.message.showReplySnippet) {
        Row() {
          TgReplySnippet({
            author: entry.message.replyAuthor,
            preview: entry.message.replyPreview,
            isOutgoing: entry.message.replyIsOutgoing,
            isQuote: entry.message.replyIsQuote,
            containerWidth: this.timelineContainerWidth
          })
        }
        .width('100%')
        .justifyContent(entry.message.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      }

      TgMessageRouter({
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
        videoThumbPath: entry.message.videoThumbPath,
        videoPath: entry.message.videoPath,
        videoDuration: entry.message.videoDuration,
        videoWidth: entry.message.videoWidth,
        videoHeight: entry.message.videoHeight,
        fileName: entry.message.fileName,
        fileSize: entry.message.fileSize,
        mimeType: entry.message.mimeType,
        voiceDuration: entry.message.voiceDuration,
        voiceWaveform: entry.message.voiceWaveform,
        isVoiceListened: entry.message.isVoiceListened,
        stickerPath: entry.message.stickerPath,
        stickerWidth: entry.message.stickerWidth,
        stickerHeight: entry.message.stickerHeight,
        isAnimatedSticker: entry.message.isAnimatedSticker,
        isVideoSticker: entry.message.isVideoSticker
      })

      Row() {
        TgMessageMeta({
          timeText: entry.message.timeText,
          sendStatus: entry.message.sendStatus,
          isOutgoing: entry.message.isOutgoing
        })
      }
      .width('100%')
      .justifyContent(entry.message.isOutgoing ? FlexAlign.End : FlexAlign.Start)
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_12,
      right: TgUiTokens.SPACE_12,
      top: TgUiTokens.SPACE_4,
      bottom: TgUiTokens.SPACE_4
    })
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
      Stack({ alignContent: Alignment.Top }) {
        // ── Content layer (scrolls under top bar) ──
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
              List({ scroller: this.listScroller }) {
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
              .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
                this.maybeUnlockAutoPagination(scrollOffset, scrollState);
              })
              .onScrollIndex((start: number, end: number) => {
                this.lastVisibleStartIndex = start;
                const totalCount = this.dataSource.totalCount();
                const nearTopEdge = this.isNearTopPaginationEdge(start);
                const nearBottomEdge = this.isNearBottomPaginationEdge(end, totalCount);
                this.refreshPaginationEdgeLatches(start, end, totalCount);
                if (this.blockAutoPaginationUntilUserScroll) {
                  return;
                }
                if (this.shouldSuppressLoadOlder()) {
                  return;
                }
                if (nearTopEdge && this.olderPaginationEdgeArmed && !this.isLoadingOlder) {
                  this.olderPaginationEdgeArmed = false;
                  this.loadOlderMessages();
                  return;
                }
                if (nearBottomEdge && this.newerPaginationEdgeArmed && !this.isLoadingNewer) {
                  this.newerPaginationEdgeArmed = false;
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

          TgComposerInput({
            placeholder: localized($r('app.string.message_placeholder').id, 'Message'),
            isDisabled: this.activeChatId === 0,
            onSendPress: (text: string): void => {
              this.handleSendMessage(text);
            }
          })
          .margin({ bottom: this.bottomOverlayInset })
        }
        .width('100%')
        .height('100%')

        // ── Top bar layer (3 glass capsules, transparent between them) ──
        TgChatTopBar({
          title: this.title,
          subtitle: this.chatSubtitle,
          avatarInitials: this.chatAvatarInitials,
          avatarColorIndex: this.chatAvatarColorIndex,
          avatarImageSrc: this.chatAvatarImageSrc,
          isOnline: this.chatIsOnline,
          onBackPress: (): void => {
            this.handleBackPress();
          }
        })
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true)
  }
}
