// ChatListPage — main chat list tab
// Phase D-3: Stack overlay layout — list scrolls under translucent top bar for blur effect
//
// Data flow: AppStore → subscribe → rebuildList → ChatListDataSource → LazyForEach → TgChatRow

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { ChatItemVO, buildChatItemVO } from './ChatItemVO';
import { ChatListDataSource } from './ChatListDataSource';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgUiFeatureFlags } from '../../tg_ui/TgUiFeatureFlags';
import { TgChatRow } from '../../tg_ui/atoms/TgChatRow';
import { TgChatSendStatus } from '../../tg_ui/atoms/TgChatMeta';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { localized } from '../../../core/utils/AppResource';
import { computeTopBarHeight, computeTabBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createLoadChatsUseCase, LoadChatsUseCase } from '../../../domain/usecases/loadChats';
import { createOpenChatUseCase, OpenChatUseCase, OpenChatParams } from '../../../domain/usecases/openChat';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiObserver, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0012;
const TAG = 'ChatListPage';
const CHAT_NAV_TRANSITION_LOCK_MS = 760;

class ChatRouteParams {
  chatId: number = 0;

  constructor(chatId: number) {
    this.chatId = chatId;
  }
}

class OpenChatRequest implements OpenChatParams {
  chatId: number = 0;
  loadMessages?: boolean = true;
  limit?: number = 50;

  constructor(chatId: number) {
    this.chatId = chatId;
  }
}

@Component
export struct ChatListPage {
  pageStack: NavPathStack = new NavPathStack();

  @StorageLink(StorageKeys.CONNECTION_STATUS) connectionStatus: string = 'connecting';
  @StorageLink(StorageKeys.CHATS_COUNT) chatsCount: number = 0;
  @StorageLink(StorageKeys.CHATS_IS_LOADING) chatsIsLoading: boolean = false;
  @StorageLink(StorageKeys.CHATS_HAS_MORE) chatsHasMore: boolean = true;
  @StorageLink(StorageKeys.CHATS_LOAD_PHASE) chatsLoadPhase: string = 'idle';

  @State private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @State private listBottomInset: number = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
  @State private searchQuery: string = '';
  @State private filteredChatsCount: number = 0;
  @State private isRetryingLoad: boolean = false;

  private dataSource: ChatListDataSource = new ChatListDataSource();
  private lastVisibleListEndIndex: number = -1;
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private autoInitialLoadRequested: boolean = false;
  private mainWindow?: window.Window;
  private loadChatsUseCase?: LoadChatsUseCase;
  private openChatUseCase?: OpenChatUseCase;
  private isOpeningChat: boolean = false;
  private deferredOpenTimerId: number = -1;
  private deferredOpenChatId: number = 0;
  private deferredOpenChatTitle: string = '';

  private clearDeferredOpen(): void {
    if (this.deferredOpenTimerId !== -1) {
      clearTimeout(this.deferredOpenTimerId);
      this.deferredOpenTimerId = -1;
    }
    this.deferredOpenChatId = 0;
    this.deferredOpenChatTitle = '';
  }

  private scheduleDeferredOpen(chatId: number, title: string, delayMs: number): void {
    if (chatId === 0) {
      return;
    }
    if (this.deferredOpenTimerId !== -1 && this.deferredOpenChatId === chatId) {
      return;
    }

    this.clearDeferredOpen();
    this.deferredOpenChatId = chatId;
    this.deferredOpenChatTitle = title;
    const effectiveDelayMs = Math.max(16, delayMs);
    this.deferredOpenTimerId = setTimeout(() => {
      this.deferredOpenTimerId = -1;
      const pendingChatId = this.deferredOpenChatId;
      const pendingTitle = this.deferredOpenChatTitle;
      this.deferredOpenChatId = 0;
      this.deferredOpenChatTitle = '';
      if (pendingChatId === 0) {
        return;
      }
      const pendingItem = new ChatItemVO();
      pendingItem.chatId = pendingChatId;
      pendingItem.title = pendingTitle;
      this.openChat(pendingItem);
    }, effectiveDelayMs) as number;

    hilog.info(DOMAIN, TAG, 'Scheduled deferred openChat for %{public}d in %{public}d ms',
      chatId, effectiveDelayMs);
  }

  onPageShow(): void {
    this.clearDeferredOpen();
    this.isOpeningChat = false;
    const navLockUntil = AppStorage.get<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL) || 0;
    if (Date.now() >= navLockUntil && navLockUntil !== 0) {
      AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, 0);
    }
  }

  aboutToAppear(): void {
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    this.isOpeningChat = false;
    this.autoInitialLoadRequested = false;
    this.bindNavigationStack();
    this.computeSafeInsets();
    this.bindWindowSizeListener();

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.loadChatsUseCase = createLoadChatsUseCase(store, getTdGatewayAdapter());
      this.openChatUseCase = createOpenChatUseCase(store, getTdGatewayAdapter());
      this.rebuildList(store.getState());
      this.maybeLoadInitialChats(store.getState());

      this.unsubscribe = store.subscribe((newState: AppState, prevState: AppState) => {
        this.maybeLoadInitialChats(newState);
        if (!this.shouldScheduleListRebuild(newState, prevState)) {
          return;
        }
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          setTimeout(() => {
            this.rebuildScheduled = false;
            try {
              const currentState = getAppCoreRuntime().getStore().getState();
              this.rebuildList(currentState);
              this.maybeLoadInitialChats(currentState);
            } catch (e) {
              hilog.error(DOMAIN, TAG, 'Rebuild failed: %{public}s', String(e));
            }
          }, 0);
        }
      });

      hilog.info(DOMAIN, TAG, 'Subscribed to store');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
    this.clearDeferredOpen();
    this.isOpeningChat = false;
    this.autoInitialLoadRequested = false;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    this.loadChatsUseCase = undefined;
    this.openChatUseCase = undefined;
    removeWindowSizeListener(this.mainWindow);
    this.mainWindow = undefined;
    hilog.info(DOMAIN, TAG, 'Unsubscribed from store');
  }

  private bindWindowSizeListener(): void {
    try {
      removeWindowSizeListener(this.mainWindow);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.mainWindow = getMainWindow(context);
      if (this.mainWindow !== undefined) {
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          this.computeSafeInsets();
        });
      }
    } catch (_error) {
      this.mainWindow = undefined;
    }
  }

  private computeSafeInsets(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.listBottomInset = computeTabBottomInset(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.listBottomInset = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
    }
  }

  private shouldScheduleListRebuild(newState: AppState, prevState: AppState): boolean {
    return newState.chats !== prevState.chats ||
      newState.messages !== prevState.messages ||
      newState.users !== prevState.users;
  }

  private maybeLoadInitialChats(state: AppState): void {
    if (!this.loadChatsUseCase || this.autoInitialLoadRequested) {
      return;
    }
    if (state.connection.status !== 'ready') {
      return;
    }
    if (state.chats.orderedChatIds.length > 0 || !state.chats.hasMore) {
      return;
    }
    if (this.loadChatsUseCase.isLoadingInProgress()) {
      return;
    }

    this.autoInitialLoadRequested = true;
    this.loadChatsUseCase.loadInitial()
      .then(() => {
        try {
          const currentState = getAppCoreRuntime().getStore().getState();
          if (currentState.chats.orderedChatIds.length === 0 &&
            this.loadChatsUseCase !== undefined &&
            this.loadChatsUseCase.hasMoreChats()) {
            this.autoInitialLoadRequested = false;
            hilog.info(DOMAIN, TAG, 'Initial load finished without visible dialogs growth, auto-load unlocked');
          }
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Initial load post-check failed: %{public}s', String(error));
        }
      })
      .catch((error: Object) => {
        this.autoInitialLoadRequested = false;
        hilog.warn(DOMAIN, TAG, 'Auto initial chat load failed: %{public}s', String(error));
      });
  }

  private maybeLoadMoreChats(endIndex: number): void {
    this.lastVisibleListEndIndex = endIndex;
    if (!this.loadChatsUseCase) {
      return;
    }
    if (this.connectionStatus !== 'ready' || this.searchQuery.length > 0) {
      return;
    }
    if (this.filteredChatsCount === 0) {
      return;
    }
    if (this.loadChatsUseCase.isLoadingInProgress() || !this.loadChatsUseCase.hasMoreChats()) {
      return;
    }

    const totalListItemsApprox = this.dataSource.totalCount() + 1;
    if (endIndex < totalListItemsApprox - 5) {
      return;
    }

    this.loadChatsUseCase.loadMore()
      .catch((error: Object) => {
        hilog.warn(DOMAIN, TAG, 'loadMore chats failed: %{public}s', String(error));
      });
  }

  private rebuildList(state: AppState): void {
    const items: ChatItemVO[] = [];
    const seenChatIds: Set<number> = new Set<number>();
    const normalizedQuery = this.searchQuery.trim().toLowerCase();

    for (const chatId of state.chats.orderedChatIds) {
      if (seenChatIds.has(chatId)) {
        continue;
      }
      seenChatIds.add(chatId);
      const chat = state.chats.chats.get(chatId);
      if (chat) {
        const item = buildChatItemVO(chat, state);
        if (normalizedQuery.length === 0 || this.matchesSearch(item, normalizedQuery)) {
          items.push(item);
        }
      }
    }
    if (items.length > 0 && items.length <= 5) {
      for (let i = 0; i < items.length; i++) {
        hilog.info(DOMAIN, TAG, 'rebuildList[%{public}d] chatId=%{public}d title="%{public}s" preview="%{public}s"',
          i, items[i].chatId, items[i].title, items[i].lastMessage.substring(0, 30));
      }
    } else if (items.length > 5) {
      hilog.info(DOMAIN, TAG, 'rebuildList: %{public}d items, first="%{public}s", last="%{public}s"',
        items.length, items[0].title, items[items.length - 1].title);
    }
    // Mark last pinned item for visual separator
    for (let i = 0; i < items.length; i++) {
      if (items[i].isPinned && (i + 1 >= items.length || !items[i + 1].isPinned)) {
        items[i].isLastPinned = true;
        break;
      }
    }

    this.dataSource.applyDiff(items);
    this.filteredChatsCount = items.length;
  }

  private matchesSearch(item: ChatItemVO, normalizedQuery: string): boolean {
    if (normalizedQuery.length === 0) {
      return true;
    }
    const title = item.title.toLowerCase();
    if (title.includes(normalizedQuery)) {
      return true;
    }
    const preview = item.lastMessage.toLowerCase();
    return preview.includes(normalizedQuery);
  }

  private getTgReuseId(item: ChatItemVO): string {
    return 'tg_chat_row_' + item.chatId.toString();
  }

  private getChatListKey(item: ChatItemVO, index: number): string {
    if (item.chatId !== 0) {
      return item.chatId.toString();
    }
    return 'chat_row_' + index.toString();
  }

  private mapSendStatus(status: 'none' | 'pending' | 'sent' | 'read' | 'failed'): TgChatSendStatus {
    switch (status) {
      case 'pending':
        return TgChatSendStatus.Sending;
      case 'sent':
        return TgChatSendStatus.Sent;
      case 'read':
        return TgChatSendStatus.Read;
      case 'failed':
        return TgChatSendStatus.Failed;
      default:
        return TgChatSendStatus.None;
    }
  }

  private openChat(item: ChatItemVO): void {
    hilog.info(DOMAIN, TAG, 'openChat called for chatId: %{public}d', item.chatId);
    const nowMs = Date.now();
    const navLockUntil = AppStorage.get<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL) || 0;
    if (nowMs < navLockUntil) {
      hilog.info(DOMAIN, TAG, 'openChat blocked by nav lock until %{public}d', navLockUntil);
      this.clearDeferredOpen();
      return;
    }
    if (item.chatId === this.deferredOpenChatId) {
      this.clearDeferredOpen();
    }
    if (this.isOpeningChat) {
      hilog.info(DOMAIN, TAG, 'Ignoring duplicate openChat tap for %{public}d', item.chatId);
      return;
    }
    if (!TgUiFeatureFlags.USE_TG_CHAT_V2) {
      hilog.info(DOMAIN, TAG, 'TgChatV2 feature flag is disabled');
      return;
    }
    if (item.chatId === 0) {
      hilog.error(DOMAIN, TAG, 'Invalid chatId: %{public}d', item.chatId);
      return;
    }
    const navStack = this.bindNavigationStack();
    if (navStack === undefined) {
      hilog.error(DOMAIN, TAG, 'Navigation stack unavailable');
      return;
    }

    const prevChatId: number = AppStorage.get<number>(StorageKeys.ACTIVE_CHAT_ID) || 0;
    const prevTitle: string = AppStorage.get<string>(StorageKeys.ACTIVE_CHAT_TITLE) || '';
    hilog.info(DOMAIN, TAG, 'Setting active chat and pushing TgChatScreenPage');
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, item.chatId);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, item.title);

    try {
      this.isOpeningChat = true;
      AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, Date.now() + CHAT_NAV_TRANSITION_LOCK_MS);
      navStack.pushPathByName('TgChatScreenPage', new ChatRouteParams(item.chatId));
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
      this.requestOpenChatData(item.chatId);
      this.isOpeningChat = false;
    } catch (e) {
      this.isOpeningChat = false;
      AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, 0);
      AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, prevChatId);
      AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, prevTitle);
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
      hilog.error(DOMAIN, TAG, 'Failed to push TgChatScreenPage: %{public}s', String(e));
    }
  }

  private requestOpenChatData(chatId: number): void {
    if (!this.openChatUseCase) {
      hilog.warn(DOMAIN, TAG, 'openChatUseCase is unavailable');
      return;
    }
    this.openChatUseCase.execute(new OpenChatRequest(chatId))
      .catch((error: Object) => {
        hilog.warn(DOMAIN, TAG, 'openChat flow failed: %{public}s', String(error));
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

  @Builder
  private buildListHeader() {
    // Search bar (scrolls with content — hides behind top bar on scroll, iOS style)
    ListItem() {
      Row() {
        Search({ placeholder: localized($r('app.string.search_placeholder').id, 'Search') })
          .searchIcon({
            src: TgUiTokens.ICON_RES_SEARCH,
            size: TgUiTokens.SEARCH_BAR_ICON_SIZE,
            color: TgUiTokens.SEARCH_BAR_ICON_COLOR
          })
          .cancelButton({ style: CancelButtonStyle.INPUT })
          .searchButton('')
          .height(TgUiTokens.SEARCH_BAR_HEIGHT)
          .backgroundColor(TgUiTokens.SEARCH_BAR_BG)
          .borderRadius(TgUiTokens.SEARCH_BAR_RADIUS)
          .placeholderColor(TgUiTokens.SEARCH_BAR_PLACEHOLDER_COLOR)
          .placeholderFont({ size: TgUiTokens.SEARCH_BAR_FONT_SIZE })
          .textFont({ size: TgUiTokens.SEARCH_BAR_FONT_SIZE })
          .fontColor(TgUiTokens.SEARCH_BAR_TEXT_COLOR)
          .onChange((value: string) => {
            const normalized = value.trim().toLowerCase();
            if (normalized === this.searchQuery) {
              return;
            }
            this.searchQuery = normalized;
            try {
              const state = getAppCoreRuntime().getStore().getState();
              this.rebuildList(state);
            } catch (error) {
              hilog.error(DOMAIN, TAG, 'Search rebuild failed: %{public}s', String(error));
            }
          })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SEARCH_BAR_SIDE_INSET,
        right: TgUiTokens.SEARCH_BAR_SIDE_INSET,
        top: TgUiTokens.SEARCH_BAR_VERTICAL_INSET,
        bottom: TgUiTokens.SEARCH_BAR_VERTICAL_INSET
      })
    }

    // Connection status banner
    if (this.connectionStatus !== 'ready') {
      ListItem() {
        Row() {
          LoadingProgress()
            .width(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
            .height(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
          Text(this.connectionStatus === 'connecting'
            ? localized($r('app.string.call_connecting').id, 'Connecting...')
            : localized($r('app.string.loading').id, 'Loading...'))
            .fontSize(TgUiTokens.CHATLIST_STATUS_TEXT_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ left: TgUiTokens.CHATLIST_STATUS_GAP })
        }
        .width('100%')
        .padding({
          left: TgUiTokens.SPACE_16,
          top: TgUiTokens.SPACE_8,
          bottom: TgUiTokens.SPACE_4
        })
      }
    }
  }

  private shouldShowListLoading(): boolean {
    if (this.chatsLoadPhase === 'bootstrap' && this.searchQuery.length === 0) {
      return true;
    }
    return this.searchQuery.length === 0 &&
      this.chatsCount === 0 &&
      (this.connectionStatus !== 'ready' || this.chatsIsLoading);
  }

  private shouldShowRetryAction(): boolean {
    return !this.shouldShowListLoading() &&
      this.connectionStatus === 'ready' &&
      this.searchQuery.length === 0 &&
      this.filteredChatsCount === 0 &&
      !this.chatsIsLoading &&
      this.chatsHasMore;
  }

  private shouldShowPaginationFooter(): boolean {
    return this.searchQuery.length === 0 &&
      this.filteredChatsCount > 0 &&
      (this.chatsLoadPhase === 'pagination' || (!this.chatsHasMore && !this.chatsIsLoading));
  }

  @Builder
  private buildPaginationFooter() {
    Row() {
      if (this.chatsLoadPhase === 'pagination') {
        LoadingProgress()
          .width(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
          .height(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
          .color(TgUiTokens.COLOR_ICON_PRIMARY)
      }
      Text(this.chatsLoadPhase === 'pagination'
        ? localized($r('app.string.loading').id, 'Loading...')
        : localized($r('app.string.no_more_chats').id, 'No more chats'))
        .fontSize(TgUiTokens.CHATLIST_STATUS_TEXT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .margin({ left: this.chatsLoadPhase === 'pagination' ? TgUiTokens.CHATLIST_STATUS_GAP : 0 })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_8,
      bottom: TgUiTokens.SPACE_12
    })
    .justifyContent(FlexAlign.Center)
  }

  private retryLoadChats(): void {
    if (this.isRetryingLoad) {
      return;
    }
    if (!this.loadChatsUseCase) {
      hilog.warn(DOMAIN, TAG, 'loadChatsUseCase is unavailable for retry');
      return;
    }
    this.isRetryingLoad = true;
    this.loadChatsUseCase.refresh()
      .then(() => {
        this.isRetryingLoad = false;
      })
      .catch((error: Object) => {
        this.isRetryingLoad = false;
        hilog.warn(DOMAIN, TAG, 'loadChats retry failed: %{public}s', String(error));
      });
  }

  private getListPlaceholderText(): string {
    if (this.shouldShowListLoading()) {
      return localized($r('app.string.loading').id, 'Loading...');
    }
    if (this.searchQuery.length > 0) {
      return localized($r('app.string.search_no_results').id, 'No results found');
    }
    return localized($r('app.string.no_messages').id, 'No messages yet');
  }

  @Builder
  private buildListPlaceholder() {
    Column() {
      if (this.shouldShowListLoading()) {
        LoadingProgress()
          .width(TgUiTokens.CHATLIST_LOADING_SIZE)
          .height(TgUiTokens.CHATLIST_LOADING_SIZE)
          .color(TgUiTokens.COLOR_ICON_PRIMARY)
      }
      Text(this.getListPlaceholderText())
        .fontSize(TgUiTokens.CHATLIST_STATUS_TEXT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .margin({ top: this.shouldShowListLoading() ? TgUiTokens.CHATLIST_STATUS_GAP : 0 })

      if (this.shouldShowRetryAction()) {
        Text(this.isRetryingLoad
          ? localized($r('app.string.loading').id, 'Loading...')
          : localized($r('app.string.retry').id, 'Retry'))
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.COLOR_ICON_PRIMARY)
          .margin({ top: TgUiTokens.SPACE_12 })
          .opacity(this.isRetryingLoad ? TgUiTokens.COMPOSER_DISABLED_OPACITY : 1)
          .onClick(() => {
            this.retryLoadChats();
          })
      }
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_12,
      bottom: TgUiTokens.SPACE_12
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // ── Content layer (list scrolls under top bar for blur) ──
      List() {
        this.buildListHeader()
        if (this.filteredChatsCount > 0) {
          LazyForEach(this.dataSource, (item: ChatItemVO) => {
            ListItem() {
              Column() {
                TgChatRow({
                  chatId: item.chatId,
                  title: item.title,
                  preview: item.isTyping ? item.typingText : item.lastMessage,
                  isTyping: item.isTyping,
                  timeText: item.formattedTime,
                  unreadCount: item.unreadCount,
                  isMuted: item.isMuted,
                  isPinned: item.isPinned,
                  sendStatus: this.mapSendStatus(item.sendStatus),
                  avatarInitials: item.initials,
                  avatarBackgroundColor: item.avatarColor,
                  avatarUseImage: item.avatarImagePath.length > 0,
                  avatarImageSrc: item.avatarImagePath.length > 0 ? item.avatarImagePath : $r('app.media.app_icon_transparent'),
                  avatarIsOnline: item.avatarOnline,
                  showSeparator: TgUiFeatureFlags.USE_INTERNAL_CHAT_ROW_SEPARATOR
                })
                  .reuseId(this.getTgReuseId(item))

                if (item.isLastPinned) {
                  Row()
                    .width('100%')
                    .height(TgUiTokens.SPACE_8)
                    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
                }
              }
            }
            .onClick(() => {
              this.openChat(item);
            })
          }, (item: ChatItemVO, index?: number) => this.getChatListKey(item, index ?? 0))
          if (this.shouldShowPaginationFooter()) {
            ListItem() {
              this.buildPaginationFooter()
            }
          }
        } else {
          ListItem() {
            this.buildListPlaceholder()
          }
        }
      }
      .cachedCount(10)
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
      .contentStartOffset(this.topBarTotalHeight)
      .contentEndOffset(this.listBottomInset)
      .onScrollIndex((_start: number, end: number) => {
        this.maybeLoadMoreChats(end);
      })

      // ── Top bar layer (overlays content, translucent + blur) ──
      TgTopBar({
        title: localized($r('app.string.chats_title').id, 'Chats'),
        showLeftText: true,
        leftText: localized($r('app.string.edit').id, 'Edit'),
        showRightAction: true,
        rightIcon: $r('app.media.ic_search'),
        showSecondRightAction: true,
        secondRightIcon: $r('app.media.ic_edit')
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
