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
import { TgChatRow, TgChatRowData } from '../../tg_ui/atoms/TgChatRow';
import { TgChatSendStatus } from '../../tg_ui/atoms/TgChatMeta';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { TgSearchBar } from '../../tg_ui/atoms/TgSearchBar';
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
  loadMessages?: boolean = false;
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

  @State private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @State private listBottomInset: number = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
  @State private searchQuery: string = '';
  @State private filteredChatsCount: number = 0;
  @State private isRetryingLoad: boolean = false;

  private dataSource: ChatListDataSource = new ChatListDataSource();
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
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
    this.bindNavigationStack();
    this.computeSafeInsets();
    this.bindWindowSizeListener();

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.loadChatsUseCase = createLoadChatsUseCase(store, getTdGatewayAdapter());
      this.openChatUseCase = createOpenChatUseCase(store, getTdGatewayAdapter());
      this.rebuildList(store.getState());

      this.unsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          setTimeout(() => {
            this.rebuildScheduled = false;
            try {
              const currentState = getAppCoreRuntime().getStore().getState();
              this.rebuildList(currentState);
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
    const pinnedKey: string = item.isPinned ? 'p1' : 'p0';
    const mutedKey: string = item.isMuted ? 'm1' : 'm0';
    const unreadKey: string = item.unreadCount > 99 ? 'u99p' : (item.unreadCount > 0 ? 'u1' : 'u0');
    const timeKey: string = item.formattedTime.length > 0 ? 't1' : 't0';
    return `tg_chat_row_${pinnedKey}_${mutedKey}_${unreadKey}_${timeKey}_${item.sendStatus}`;
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

  private toTgRowData(item: ChatItemVO): TgChatRowData {
    const row = new TgChatRowData();
    row.chatId = item.chatId;
    row.title = item.title;
    row.preview = item.lastMessage;
    row.timeText = item.formattedTime;
    row.unreadCount = item.unreadCount;
    row.isMuted = item.isMuted;
    row.isPinned = item.isPinned;
    row.sendStatus = this.mapSendStatus(item.sendStatus);
    row.avatarInitials = item.initials;
    row.avatarBackgroundColor = item.avatarColor;
    row.avatarUseImage = item.avatarImagePath.length > 0;
    if (item.avatarImagePath.length > 0) {
      row.avatarImageSrc = item.avatarImagePath;
    }
    row.avatarIsOnline = item.avatarOnline;
    return row;
  }

  private openChat(item: ChatItemVO): void {
    hilog.info(DOMAIN, TAG, 'openChat called for chatId: %{public}d', item.chatId);
    const nowMs = Date.now();
    const navLockUntil = AppStorage.get<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL) || 0;
    if (nowMs < navLockUntil) {
      hilog.info(DOMAIN, TAG, 'openChat blocked by nav lock until %{public}d', navLockUntil);
      this.scheduleDeferredOpen(item.chatId, item.title, navLockUntil - nowMs + 16);
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
      TgSearchBar({
        placeholder: localized($r('app.string.search_placeholder').id, 'Search'),
        onTextChange: (value: string) => {
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
        }
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
    return this.connectionStatus !== 'ready' && this.searchQuery.length === 0 && this.chatsCount === 0;
  }

  private shouldShowRetryAction(): boolean {
    return !this.shouldShowListLoading() &&
      this.connectionStatus !== 'ready' &&
      this.searchQuery.length === 0 &&
      this.filteredChatsCount === 0;
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
              TgChatRow({
                data: this.toTgRowData(item),
                showSeparator: TgUiFeatureFlags.USE_INTERNAL_CHAT_ROW_SEPARATOR
              })
                .reuseId(this.getTgReuseId(item))
            }
            .onClick(() => {
              this.openChat(item);
            })
          }, (item: ChatItemVO) => item.chatId.toString())
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

      // ── Top bar layer (overlays content, translucent + blur) ──
      TgTopBar({
        title: localized($r('app.string.chats_title').id, 'Chats'),
        showRightAction: true,
        rightIcon: $r('app.media.ic_search')
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
