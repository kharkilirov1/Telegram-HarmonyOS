// ChatListPage — main chat list tab
// Phase D-3: Stack overlay layout — list scrolls under translucent top bar for blur effect
// V2 migration: @ComponentV2, @Local, chatsUIState/navigationUIState singletons
//
// Data flow: AppStore → subscribe → rebuildList → ChatListDataSource → LazyForEach → TgChatRow

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { chatsUIState, navigationUIState, chatUIState } from '../../../core/model/UIStateModels';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { ChatItemVO, buildChatItemVO } from './ChatItemVO';
import { ChatListDataSource } from './ChatListDataSource';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgUiFeatureFlags } from '../../tg_ui/TgUiFeatureFlags';
import { TgChatRow } from '../../tg_ui/atoms/TgChatRow';
import { TgChatSendStatus } from '../../tg_ui/atoms/TgChatMeta';
import { TgChatListNavigationBar } from '../../tg_ui/atoms/TgChatListNavigationBar';
import { localized } from '../../../core/utils/AppResource';
import {
  computeChatListTopBarHeight,
  computeTabBottomInset,
  getMainWindow,
  removeWindowSizeListener
} from '../../utils/SafeAreaUtils';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createLoadChatsUseCase, LoadChatsUseCase } from '../../../domain/usecases/loadChats';
import { createOpenChatUseCase, OpenChatUseCase, OpenChatParams } from '../../../domain/usecases/openChat';
import { createSetChatMuteUseCase, SetChatMuteUseCase, MUTE_FOREVER } from '../../../domain/usecases/setChatMute';
import { createDeleteChatHistoryUseCase, DeleteChatHistoryUseCase } from '../../../domain/usecases/deleteChatHistory';
import { createToggleChatUnreadUseCase, ToggleChatUnreadUseCase } from '../../../domain/usecases/toggleChatUnread';
import { createToggleChatPinnedUseCase, ToggleChatPinnedUseCase } from '../../../domain/usecases/toggleChatPinned';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiObserver, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0012;
const TAG = 'ChatListPage';
const CHAT_NAV_TRANSITION_LOCK_MS = 760;

class ChatRouteParams {
  chatId: number = 0;
  chatTitle: string = '';

  constructor(chatId: number, chatTitle: string = '') {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
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

@ComponentV2
export struct ChatListPage {
  @Local pageStack: NavPathStack = new NavPathStack();

  // Reactive state from @ObservedV2 model (replaces @StorageLink)
  private chatsState = chatsUIState;
  private navState = navigationUIState;

  @Local private topBarTotalHeight: number = TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT;
  @Local private listBottomInset: number = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
  @Local private searchQuery: string = '';
  @Local private filteredChatsCount: number = 0;
  @Local private isRetryingLoad: boolean = false;
  @Local private isRefreshing: boolean = false;

  private dataSource: ChatListDataSource = new ChatListDataSource();
  private lastVisibleListEndIndex: number = -1;
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private rebuildTimerId: number = -1;
  private pageLifecycleToken: number = 0;
  private autoInitialLoadRequested: boolean = false;
  private mainWindow?: window.Window;
  private loadChatsUseCase?: LoadChatsUseCase;
  private openChatUseCase?: OpenChatUseCase;
  private muteUseCase?: SetChatMuteUseCase;
  private pinUseCase?: ToggleChatPinnedUseCase;
  private deleteChatUseCase?: DeleteChatHistoryUseCase;
  private toggleUnreadUseCase?: ToggleChatUnreadUseCase;
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

  private clearActiveChatContext(): void {
    navigationUIState.activeChatId = 0;
    navigationUIState.activeChatTitle = '';
    chatUIState.activeChatId = 0;
    chatUIState.activeChatTitle = '';
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, 0);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, '');
  }

  private clearRebuildTimer(): void {
    if (this.rebuildTimerId !== -1) {
      clearTimeout(this.rebuildTimerId);
      this.rebuildTimerId = -1;
    }
    this.rebuildScheduled = false;
  }

  private isCurrentLoadChatsContinuation(scheduledToken: number, loadChatsUseCase: LoadChatsUseCase): boolean {
    return scheduledToken === this.pageLifecycleToken && this.loadChatsUseCase === loadChatsUseCase;
  }

  private isCurrentDeferredOpenCallback(scheduledToken: number, scheduledTimerId: number, chatId: number): boolean {
    return scheduledToken === this.pageLifecycleToken &&
      this.deferredOpenTimerId === scheduledTimerId &&
      this.deferredOpenChatId === chatId;
  }

  private isCurrentMuteContinuation(scheduledToken: number, muteUseCase: SetChatMuteUseCase): boolean {
    return scheduledToken === this.pageLifecycleToken && this.muteUseCase === muteUseCase;
  }

  private isCurrentDeleteChatContinuation(
    scheduledToken: number,
    deleteChatUseCase: DeleteChatHistoryUseCase
  ): boolean {
    return scheduledToken === this.pageLifecycleToken && this.deleteChatUseCase === deleteChatUseCase;
  }

  private isCurrentToggleUnreadContinuation(
    scheduledToken: number,
    toggleUnreadUseCase: ToggleChatUnreadUseCase
  ): boolean {
    return scheduledToken === this.pageLifecycleToken && this.toggleUnreadUseCase === toggleUnreadUseCase;
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
    const scheduledToken: number = this.pageLifecycleToken;
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (!this.isCurrentDeferredOpenCallback(scheduledToken, scheduledTimerId, chatId)) {
        return;
      }
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
    this.deferredOpenTimerId = scheduledTimerId;

    hilog.info(DOMAIN, TAG, 'Scheduled deferred openChat for %{public}d in %{public}d ms',
      chatId, effectiveDelayMs);
  }

  onPageShow(): void {
    this.clearDeferredOpen();
    this.isOpeningChat = false;
    // Always clear nav lock — ChatListPage is visible, transition is complete
    navigationUIState.chatNavLockUntil = 0;
    AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, 0);
    // Clear active chat — TgChatScreenPage is no longer visible
    this.clearActiveChatContext();
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.clearRebuildTimer();
    navigationUIState.chatScreenVisible = false;
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    this.clearActiveChatContext();
    this.isOpeningChat = false;
    this.autoInitialLoadRequested = false;
    this.bindNavigationStack();
    this.computeSafeInsets();
    this.bindWindowSizeListener();

    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.loadChatsUseCase = createLoadChatsUseCase(store, getTdGatewayAdapter());
      this.openChatUseCase = createOpenChatUseCase(store, getTdGatewayAdapter());
      this.muteUseCase = createSetChatMuteUseCase(getTdGatewayAdapter());
      this.pinUseCase = createToggleChatPinnedUseCase(getTdGatewayAdapter());
      this.deleteChatUseCase = createDeleteChatHistoryUseCase(getTdGatewayAdapter());
      this.toggleUnreadUseCase = createToggleChatUnreadUseCase(getTdGatewayAdapter());
      this.rebuildList(store.getState());
      this.maybeLoadInitialChats(store.getState());

      const subscriptionToken: number = this.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = store.subscribe((newState: AppState, prevState: AppState) => {
        if (subscriptionToken !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
          return;
        }
        this.maybeLoadInitialChats(newState);
        if (!this.shouldScheduleListRebuild(newState, prevState)) {
          return;
        }
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          const scheduledToken: number = this.pageLifecycleToken;
          let scheduledTimerId: number = -1;
          scheduledTimerId = setTimeout(() => {
            if (scheduledToken !== this.pageLifecycleToken ||
              this.rebuildTimerId !== scheduledTimerId ||
              this.unsubscribe !== activeUnsubscribe) {
              return;
            }
            this.rebuildTimerId = -1;
            this.rebuildScheduled = false;
            try {
              const currentState = getAppCoreRuntime().getStore().getState();
              this.rebuildList(currentState);
              this.maybeLoadInitialChats(currentState);
            } catch (e) {
              hilog.error(DOMAIN, TAG, 'Rebuild failed: %{public}s', String(e));
            }
          }, 300) as number;
          this.rebuildTimerId = scheduledTimerId;
        }
      });
      this.unsubscribe = activeUnsubscribe;

      hilog.info(DOMAIN, TAG, 'Subscribed to store');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.clearRebuildTimer();
    this.clearDeferredOpen();
    this.isOpeningChat = false;
    this.autoInitialLoadRequested = false;
    this.isRefreshing = false;
    this.isRetryingLoad = false;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    this.loadChatsUseCase = undefined;
    this.openChatUseCase = undefined;
    this.muteUseCase = undefined;
    this.deleteChatUseCase = undefined;
    this.toggleUnreadUseCase = undefined;
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
        const lifecycleToken: number = this.pageLifecycleToken;
        const boundWindow: window.Window = this.mainWindow;
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.mainWindow !== boundWindow) {
            return;
          }
          this.computeSafeInsets();
        });
        this.mainWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.mainWindow !== boundWindow) {
            return;
          }
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            this.computeSafeInsets();
          }
        });
      }
    } catch (_error) {
      this.mainWindow = undefined;
    }
  }

  private chatListTopInset(): number {
    return Math.max(0, this.topBarTotalHeight - TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT);
  }

  private computeSafeInsets(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeChatListTopBarHeight(context);
      this.listBottomInset = computeTabBottomInset(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.STATUS_BAR_FALLBACK_INSET + TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT;
      this.listBottomInset = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
    }
  }

  private shouldScheduleListRebuild(newState: AppState, prevState: AppState): boolean {
    return newState.chats !== prevState.chats ||
      newState.messages !== prevState.messages ||
      newState.users !== prevState.users;
  }

  private maybeLoadInitialChats(state: AppState): void {
    const loadChatsUseCase = this.loadChatsUseCase;
    if (!loadChatsUseCase || this.autoInitialLoadRequested) {
      return;
    }
    if (state.connection.status !== 'ready') {
      return;
    }
    if (state.chats.orderedChatIds.length > 0 || !state.chats.hasMore) {
      return;
    }
    if (loadChatsUseCase.isLoadingInProgress()) {
      return;
    }

    const scheduledToken: number = this.pageLifecycleToken;
    this.autoInitialLoadRequested = true;
    loadChatsUseCase.loadInitial()
      .then(() => {
        if (!this.isCurrentLoadChatsContinuation(scheduledToken, loadChatsUseCase)) {
          return;
        }
        try {
          const currentState = getAppCoreRuntime().getStore().getState();
          if (currentState.chats.orderedChatIds.length === 0 &&
            loadChatsUseCase.hasMoreChats()) {
            this.autoInitialLoadRequested = false;
            hilog.info(DOMAIN, TAG, 'Initial load finished without visible dialogs growth, auto-load unlocked');
          }
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Initial load post-check failed: %{public}s', String(error));
        }
      })
      .catch((error: Object) => {
        if (!this.isCurrentLoadChatsContinuation(scheduledToken, loadChatsUseCase)) {
          return;
        }
        this.autoInitialLoadRequested = false;
        hilog.warn(DOMAIN, TAG, 'Auto initial chat load failed: %{public}s', String(error));
      });
  }

  private maybeLoadMoreChats(endIndex: number): void {
    this.lastVisibleListEndIndex = endIndex;
    const loadChatsUseCase = this.loadChatsUseCase;
    if (!loadChatsUseCase) {
      return;
    }
    if (this.chatsState.connectionStatus !== 'ready' || this.hasActiveSearch()) {
      return;
    }
    if (this.filteredChatsCount === 0) {
      return;
    }
    if (loadChatsUseCase.isLoadingInProgress() || !loadChatsUseCase.hasMoreChats()) {
      return;
    }

    const totalListItemsApprox = this.dataSource.totalCount() + 1;
    if (endIndex < totalListItemsApprox - 5) {
      return;
    }

    const scheduledToken: number = this.pageLifecycleToken;
    loadChatsUseCase.loadMore()
      .catch((error: Object) => {
        if (!this.isCurrentLoadChatsContinuation(scheduledToken, loadChatsUseCase)) {
          return;
        }
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
    const preview = (item.previewPrefix + ' ' + item.lastMessage).toLowerCase();
    return preview.includes(normalizedQuery);
  }

  private hasActiveSearch(): boolean {
    return this.searchQuery.trim().length > 0;
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

  // iOS ref: swipe right reveals Read/Unread (grey/blue).
  // Buttons (not Column.onClick) — clicks inside swipeAction only land on Button
  // (witness: Codelabs PersonalAssistantPro ContactListPage pattern)
  @Builder
  private buildSwipeStartActions(item: ChatItemVO) {
    Row() {
      Button(item.unreadCount > 0 ? 'Read' : 'Unread')
        .type(ButtonType.Normal)
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor(item.unreadCount > 0 ? TgUiTokens.COLOR_TEXT_PREVIEW : TgUiTokens.COLOR_ICON_PRIMARY)
        .width(72)
        .height('100%')
        .borderRadius(0)
        .onClick(() => {
          this.handleToggleUnread(item);
        })
    }
    .height('100%')
  }

  // iOS ref: swipe left reveals Pin (green), Mute (orange), Delete (red)
  @Builder
  private buildSwipeEndActions(item: ChatItemVO) {
    Row() {
      // Pin/Unpin — green
      Button(item.isPinned ? 'Unpin' : 'Pin')
        .type(ButtonType.Normal)
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor(TgUiTokens.SWIPE_ACTION_PIN)
        .width(72)
        .height('100%')
        .borderRadius(0)
        .onClick(() => {
          this.handlePinToggle(item);
        })

      // Mute/Unmute — orange
      Button(item.isMuted ? 'Unmute' : 'Mute')
        .type(ButtonType.Normal)
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor(TgUiTokens.SWIPE_ACTION_MUTE)
        .width(72)
        .height('100%')
        .borderRadius(0)
        .onClick(() => {
          this.handleMuteToggle(item);
        })

      // Delete — red
      Button('Delete')
        .type(ButtonType.Normal)
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor(TgUiTokens.SWIPE_ACTION_DELETE)
        .width(72)
        .height('100%')
        .borderRadius(0)
        .onClick(() => {
          this.handleDeleteChat(item);
      })
    }
    .height('100%')
  }

  // TDLib confirms with updateChatPosition → chatsReducer reorders; list rebuilds via subscription
  private handlePinToggle(item: ChatItemVO): void {
    const pinUseCase = this.pinUseCase;
    if (!pinUseCase) return;
    pinUseCase.setPinned(item.chatId, !item.isPinned)
      .catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Pin toggle failed for %{public}d: %{public}s', item.chatId, error.message);
      });
  }

  private handleMuteToggle(item: ChatItemVO): void {
    const muteUseCase = this.muteUseCase;
    if (!muteUseCase) return;
    const scheduledToken: number = this.pageLifecycleToken;
    const chatId: number = item.chatId;
    if (item.isMuted) {
      muteUseCase.unmute(chatId)
        .then(() => {
          if (!this.isCurrentMuteContinuation(scheduledToken, muteUseCase)) {
            return;
          }
          hilog.info(DOMAIN, TAG, 'Chat %{public}d unmuted', chatId);
        })
        .catch((err: Error) => {
          if (!this.isCurrentMuteContinuation(scheduledToken, muteUseCase)) {
            return;
          }
          hilog.error(DOMAIN, TAG, 'Unmute failed: %{public}s', err.message);
        });
    } else {
      muteUseCase.mute(chatId, MUTE_FOREVER)
        .then(() => {
          if (!this.isCurrentMuteContinuation(scheduledToken, muteUseCase)) {
            return;
          }
          hilog.info(DOMAIN, TAG, 'Chat %{public}d muted', chatId);
        })
        .catch((err: Error) => {
          if (!this.isCurrentMuteContinuation(scheduledToken, muteUseCase)) {
            return;
          }
          hilog.error(DOMAIN, TAG, 'Mute failed: %{public}s', err.message);
        });
    }
  }

  private handlePullToRefresh(): void {
    hilog.info(DOMAIN, TAG, 'Pull-to-refresh triggered');
    const loadChatsUseCase = this.loadChatsUseCase;
    if (loadChatsUseCase) {
      const scheduledToken: number = this.pageLifecycleToken;
      loadChatsUseCase.execute()
        .then(() => {
          if (!this.isCurrentLoadChatsContinuation(scheduledToken, loadChatsUseCase)) {
            return;
          }
          this.isRefreshing = false;
        })
        .catch((err: Error) => {
          if (!this.isCurrentLoadChatsContinuation(scheduledToken, loadChatsUseCase)) {
            return;
          }
          hilog.error(DOMAIN, TAG, 'Refresh failed: %{public}s', err.message);
          this.isRefreshing = false;
        });
    } else {
      this.isRefreshing = false;
    }
  }

  private handleDeleteChat(item: ChatItemVO): void {
    const deleteChatUseCase = this.deleteChatUseCase;
    if (!deleteChatUseCase) return;
    const scheduledToken: number = this.pageLifecycleToken;
    const chatId: number = item.chatId;
    deleteChatUseCase.execute(chatId, true, false)
      .then(() => {
        if (!this.isCurrentDeleteChatContinuation(scheduledToken, deleteChatUseCase)) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Chat %{public}d deleted', chatId);
      })
      .catch((err: Error) => {
        if (!this.isCurrentDeleteChatContinuation(scheduledToken, deleteChatUseCase)) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Delete chat failed: %{public}s', err.message);
      });
  }

  private handleToggleUnread(item: ChatItemVO): void {
    const toggleUnreadUseCase = this.toggleUnreadUseCase;
    if (!toggleUnreadUseCase) return;
    const scheduledToken: number = this.pageLifecycleToken;
    const chatId: number = item.chatId;
    if (item.unreadCount > 0) {
      toggleUnreadUseCase.markAsRead(chatId)
        .then(() => {
          if (!this.isCurrentToggleUnreadContinuation(scheduledToken, toggleUnreadUseCase)) {
            return;
          }
          hilog.info(DOMAIN, TAG, 'Chat %{public}d marked read', chatId);
        })
        .catch((err: Error) => {
          if (!this.isCurrentToggleUnreadContinuation(scheduledToken, toggleUnreadUseCase)) {
            return;
          }
          hilog.error(DOMAIN, TAG, 'Mark read failed: %{public}s', err.message);
        });
    } else {
      toggleUnreadUseCase.markAsUnread(chatId)
        .then(() => {
          if (!this.isCurrentToggleUnreadContinuation(scheduledToken, toggleUnreadUseCase)) {
            return;
          }
          hilog.info(DOMAIN, TAG, 'Chat %{public}d marked unread', chatId);
        })
        .catch((err: Error) => {
          if (!this.isCurrentToggleUnreadContinuation(scheduledToken, toggleUnreadUseCase)) {
            return;
          }
          hilog.error(DOMAIN, TAG, 'Mark unread failed: %{public}s', err.message);
        });
    }
  }

  private openChat(item: ChatItemVO): void {
    hilog.info(DOMAIN, TAG, 'openChat called for chatId: %{public}d', item.chatId);
    const nowMs = Date.now();
    const navLockUntil = navigationUIState.chatNavLockUntil;
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

    const prevChatId: number = navigationUIState.activeChatId;
    const prevTitle: string = navigationUIState.activeChatTitle;
    const prevStoredChatId: number = AppStorage.get<number>(StorageKeys.ACTIVE_CHAT_ID) ?? prevChatId;
    const prevStoredTitle: string = AppStorage.get<string>(StorageKeys.ACTIVE_CHAT_TITLE) ?? prevTitle;
    hilog.info(DOMAIN, TAG, 'Setting active chat and pushing TgChatScreenPage');
    navigationUIState.activeChatId = item.chatId;
    navigationUIState.activeChatTitle = item.title;

    try {
      this.isOpeningChat = true;
      const nextNavLockUntil = Date.now() + CHAT_NAV_TRANSITION_LOCK_MS;
      navigationUIState.chatNavLockUntil = nextNavLockUntil;
      AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, nextNavLockUntil);
      // Set chatUIState so TgChatScreenPage route initialization and lastOpenedChatId work correctly.
      chatUIState.activeChatId = item.chatId;
      chatUIState.activeChatTitle = item.title;
      AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, item.chatId);
      AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, item.title);
      navStack.pushPathByName('TgChatScreenPage', new ChatRouteParams(item.chatId, item.title));
      navigationUIState.chatScreenVisible = true;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
      this.requestOpenChatData(item.chatId);
      this.isOpeningChat = false;
    } catch (e) {
      this.isOpeningChat = false;
      navigationUIState.activeChatId = prevChatId;
      navigationUIState.activeChatTitle = prevTitle;
      navigationUIState.chatNavLockUntil = 0;
      chatUIState.activeChatId = prevChatId;
      chatUIState.activeChatTitle = prevTitle;
      AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, 0);
      AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, prevStoredChatId);
      AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, prevStoredTitle);
      navigationUIState.chatScreenVisible = false;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
      hilog.error(DOMAIN, TAG, 'Failed to push TgChatScreenPage: %{public}s', String(e));
    }
  }

  private requestOpenChatData(chatId: number): void {
    const openChatUseCase = this.openChatUseCase;
    if (!openChatUseCase) {
      hilog.warn(DOMAIN, TAG, 'openChatUseCase is unavailable');
      return;
    }
    const lifecycleToken: number = this.pageLifecycleToken;
    openChatUseCase.execute(new OpenChatRequest(chatId))
      .catch((error: Object) => {
        if (lifecycleToken !== this.pageLifecycleToken || this.openChatUseCase !== openChatUseCase) {
          return;
        }
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
    // Connection status banner
    if (this.chatsState.connectionStatus !== 'ready') {
      ListItem() {
        Row() {
          LoadingProgress()
            .width(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
            .height(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
          Text(this.chatsState.connectionStatus === 'connecting'
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
    if (this.chatsState.chatsLoadPhase === 'bootstrap' && !this.hasActiveSearch()) {
      return true;
    }
    return !this.hasActiveSearch() &&
      this.chatsState.chatsCount === 0 &&
      (this.chatsState.connectionStatus !== 'ready' || this.chatsState.chatsIsLoading);
  }

  private shouldShowRetryAction(): boolean {
    return !this.shouldShowListLoading() &&
      this.chatsState.connectionStatus === 'ready' &&
      !this.hasActiveSearch() &&
      this.filteredChatsCount === 0 &&
      !this.chatsState.chatsIsLoading &&
      this.chatsState.chatsHasMore;
  }

  private shouldShowPaginationFooter(): boolean {
    return !this.hasActiveSearch() &&
      this.filteredChatsCount > 0 &&
      (this.chatsState.chatsLoadPhase === 'pagination' ||
        (!this.chatsState.chatsHasMore && !this.chatsState.chatsIsLoading));
  }

  @Builder
  private buildPaginationFooter() {
    Row() {
      if (this.chatsState.chatsLoadPhase === 'pagination') {
        LoadingProgress()
          .width(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
          .height(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
          .color(TgUiTokens.COLOR_ICON_PRIMARY)
      }
      Text(this.chatsState.chatsLoadPhase === 'pagination'
        ? localized($r('app.string.loading').id, 'Loading...')
        : localized($r('app.string.no_more_chats').id, 'No more chats'))
        .fontSize(TgUiTokens.CHATLIST_STATUS_TEXT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .margin({ left: this.chatsState.chatsLoadPhase === 'pagination' ? TgUiTokens.CHATLIST_STATUS_GAP : 0 })
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
    const loadChatsUseCase = this.loadChatsUseCase;
    if (!loadChatsUseCase) {
      hilog.warn(DOMAIN, TAG, 'loadChatsUseCase is unavailable for retry');
      return;
    }
    const scheduledToken: number = this.pageLifecycleToken;
    this.isRetryingLoad = true;
    loadChatsUseCase.refresh()
      .then(() => {
        if (!this.isCurrentLoadChatsContinuation(scheduledToken, loadChatsUseCase)) {
          return;
        }
        this.isRetryingLoad = false;
      })
      .catch((error: Object) => {
        if (!this.isCurrentLoadChatsContinuation(scheduledToken, loadChatsUseCase)) {
          return;
        }
        this.isRetryingLoad = false;
        hilog.warn(DOMAIN, TAG, 'loadChats retry failed: %{public}s', String(error));
      });
  }

  private getListPlaceholderText(): string {
    if (this.shouldShowListLoading()) {
      return localized($r('app.string.loading').id, 'Loading...');
    }
    if (this.hasActiveSearch()) {
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
      Refresh({ refreshing: $$this.isRefreshing }) {
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
                  previewPrefix: item.previewPrefix,
                  previewPrefixStyle: item.previewPrefixStyle,
                  isDraft: item.isTyping ? false : item.isDraft,
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
                    isVerified: item.isVerified,
                    isScam: item.isScam,
                    isFake: item.isFake,
                    isSecret: item.isSecret,
                    hasMention: item.hasMention,
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
            .swipeAction({
              // Direct CustomBuilder form — the SwipeActionItem{builder} form left
              // buttons unclickable (taps landed on the ListItem pressed-state only)
              start: () => {
                this.buildSwipeStartActions(item);
              },
              end: () => {
                this.buildSwipeEndActions(item);
              }
            })
            // NB: no stateStyles here — a pressed-state on the ListItem swallowed
            // taps meant for swipeAction buttons (row press feedback lives in TgChatRow)
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
      } // end Refresh content
      .onRefreshing(() => {
        this.handlePullToRefresh();
      })
      .pullToRefresh(true)
      .refreshOffset(64)

      // ── Top bar layer (overlays content, translucent + blur) ──
      TgChatListNavigationBar({
        topInset: this.chatListTopInset(),
        title: localized($r('app.string.chats_title').id, 'Chats'),
        searchValue: this.searchQuery,
        searchPlaceholder: localized($r('app.string.search_placeholder').id, 'Search'),
        editText: localized($r('app.string.edit').id, 'Edit'),
        onSearchChange: (value: string): void => {
          if (value === this.searchQuery) {
            return;
          }
          this.searchQuery = value;
          try {
            const state = getAppCoreRuntime().getStore().getState();
            this.rebuildList(state);
          } catch (error) {
            hilog.error(DOMAIN, TAG, 'Search rebuild failed: %{public}s', String(error));
          }
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
