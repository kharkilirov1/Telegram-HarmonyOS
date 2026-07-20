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
import { TgArchivedChatsRow } from '../../tg_ui/atoms/TgArchivedChatsRow';
import { TgChatRow } from '../../tg_ui/atoms/TgChatRow';
import { TgChatSendStatus } from '../../tg_ui/atoms/TgChatMeta';
import {
  TgChatListNavigationBar,
  TgChatListStoryPreview
} from '../../tg_ui/atoms/TgChatListNavigationBar';
import { TgChatListFilter } from '../../tg_ui/atoms/TgChatListFilterBar';
import { localized } from '../../../core/utils/AppResource';
import {
  computeTabBottomInset,
  getMainWindow,
  removeWindowSizeListener
} from '../../utils/SafeAreaUtils';
import { ROOT_TAB_BAR_FALLBACK_CONTENT_INSET } from '../../utils/RootTabBarGeometry';
import { resolveChatHostTopInset } from '../../utils/ChatSplitGeometry';
import { PendingChatUnreadSnapshot } from '../chat/PendingChatUnreadSnapshot';
import { ComposeResult, ComposeRouteParams } from '../compose/TgComposePage';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createLoadChatsUseCase, LoadChatsUseCase } from '../../../domain/usecases/loadChats';
import {
  createLoadArchiveChatsUseCase,
  LoadArchiveChatsUseCase
} from '../../../domain/usecases/loadArchiveChats';
import { createOpenChatUseCase, OpenChatUseCase, OpenChatParams } from '../../../domain/usecases/openChat';
import { createSetChatMuteUseCase, SetChatMuteUseCase, MUTE_FOREVER } from '../../../domain/usecases/setChatMute';
import { createDeleteChatHistoryUseCase, DeleteChatHistoryUseCase } from '../../../domain/usecases/deleteChatHistory';
import { createToggleChatUnreadUseCase, ToggleChatUnreadUseCase } from '../../../domain/usecases/toggleChatUnread';
import { createToggleChatPinnedUseCase, ToggleChatPinnedUseCase } from '../../../domain/usecases/toggleChatPinned';
import { createMoveChatToListUseCase, MoveChatToListUseCase } from '../../../domain/usecases/moveChatToList';
import {
  createLoadActiveStoriesUseCase,
  LoadActiveStoriesUseCase
} from '../../../domain/usecases/loadActiveStories';
import {
  hasUnreadActiveStories,
  hasUnreadCloseFriendsStories,
  latestActiveStoryId
} from '../../../core/model/dto/StoryDto';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiObserver, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0012;
const TAG = 'ChatListPage';
const CHAT_NAV_TRANSITION_LOCK_MS = 760;
let lastPortraitChatTopInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

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

  @Param chatDetailStack: NavPathStack = new NavPathStack();

  @Event onKeyboardVisibilityChange: (visible: boolean) => void = (_: boolean): void => {};
  @Param searchQuery: string = '';
  @Event onSearchQueryChange: (value: string) => void = (_: string): void => {};
  @Event onSearchDeactivate: () => void = (): void => {};
  @Event onHeaderSearchWillFocus: () => void = (): void => {};

  // Reactive state from @ObservedV2 model (replaces @StorageLink)
  private chatsState = chatsUIState;
  private navState = navigationUIState;

  @Local private listBottomInset: number = ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;
  @Local private chatTopInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  @Local private selectedFilterIndex: number = TgChatListFilter.All;
  @Local private unreadFilterCount: number = 0;
  @Local private searchCollapseProgress: number = 0;
  @Local private filteredChatsCount: number = 0;
  @Local private archivedChatsCount: number = 0;
  @Local private archivedUnreadCount: number = 0;
  @Local private archivedPreview: string = '';
  @Local private isRetryingLoad: boolean = false;
  @Local private isRefreshing: boolean = false;
  @Local private storyPreviews: TgChatListStoryPreview[] = [];

  private dataSource: ChatListDataSource = new ChatListDataSource();
  private chatListScroller: Scroller = new Scroller();
  private headerCollapseOffset: number = 0;
  private lastVisibleListEndIndex: number = -1;
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private rebuildTimerId: number = -1;
  private pageLifecycleToken: number = 0;
  private autoInitialLoadRequested: boolean = false;
  private archiveInitialLoadRequested: boolean = false;
  private storyInitialLoadRequested: boolean = false;
  private mainWindow?: window.Window;
  private loadChatsUseCase?: LoadChatsUseCase;
  private loadArchiveChatsUseCase?: LoadArchiveChatsUseCase;
  private loadActiveStoriesUseCase?: LoadActiveStoriesUseCase;
  private openChatUseCase?: OpenChatUseCase;
  private muteUseCase?: SetChatMuteUseCase;
  private pinUseCase?: ToggleChatPinnedUseCase;
  private moveChatToListUseCase?: MoveChatToListUseCase;
  private deleteChatUseCase?: DeleteChatHistoryUseCase;
  private toggleUnreadUseCase?: ToggleChatUnreadUseCase;
  private isOpeningChat: boolean = false;
  private isComposePickerOpen: boolean = false;
  private deferredOpenTimerId: number = -1;
  private deferredOpenChatId: number = 0;
  private deferredOpenChatTitle: string = '';

  @Monitor('searchQuery')
  private onSearchQueryChanged(_monitor: IMonitor): void {
    this.updateSearchCollapseProgress(0);
    try {
      this.rebuildList(getAppCoreRuntime().getStore().getState());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Search rebuild failed: %{public}s', String(error));
    }
  }

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
    // A system/back pop can restore ChatList before the NavPathStack result
    // callback is dispatched. The visible page must never retain a stale
    // Compose duplicate guard.
    this.isComposePickerOpen = false;
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
    this.archiveInitialLoadRequested = false;
    this.storyInitialLoadRequested = false;
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
      this.loadArchiveChatsUseCase = createLoadArchiveChatsUseCase(store, getTdGatewayAdapter());
      this.loadActiveStoriesUseCase = createLoadActiveStoriesUseCase(store, getTdGatewayAdapter());
      this.openChatUseCase = createOpenChatUseCase(store, getTdGatewayAdapter());
      this.muteUseCase = createSetChatMuteUseCase(getTdGatewayAdapter());
      this.pinUseCase = createToggleChatPinnedUseCase(getTdGatewayAdapter());
      this.moveChatToListUseCase = createMoveChatToListUseCase(getTdGatewayAdapter());
      this.deleteChatUseCase = createDeleteChatHistoryUseCase(getTdGatewayAdapter());
      this.toggleUnreadUseCase = createToggleChatUnreadUseCase(getTdGatewayAdapter());
      this.rebuildList(store.getState());
      this.maybeLoadInitialChats(store.getState());
      this.maybeLoadInitialArchive(store.getState());
      this.maybeLoadInitialStories(store.getState());

      const subscriptionToken: number = this.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = store.subscribe((newState: AppState, prevState: AppState) => {
        if (subscriptionToken !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
          return;
        }
        this.maybeLoadInitialChats(newState);
        this.maybeLoadInitialArchive(newState);
        this.maybeLoadInitialStories(newState);
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
              this.maybeLoadInitialArchive(currentState);
              this.maybeLoadInitialStories(currentState);
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
    this.onKeyboardVisibilityChange(false);
    this.pageLifecycleToken += 1;
    this.clearRebuildTimer();
    this.clearDeferredOpen();
    this.isOpeningChat = false;
    this.autoInitialLoadRequested = false;
    this.archiveInitialLoadRequested = false;
    this.storyInitialLoadRequested = false;
    this.isRefreshing = false;
    this.isRetryingLoad = false;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    this.loadChatsUseCase = undefined;
    this.loadArchiveChatsUseCase = undefined;
    this.loadActiveStoriesUseCase = undefined;
    this.openChatUseCase = undefined;
    this.muteUseCase = undefined;
    this.pinUseCase = undefined;
    this.moveChatToListUseCase = undefined;
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
        this.computeSafeInsets();
        this.mainWindow.on('windowSizeChange', (size: window.Size) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.mainWindow !== boundWindow) {
            return;
          }
          this.computeSafeInsets(size);
        });
        this.mainWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.mainWindow !== boundWindow) {
            return;
          }
          if (data.type === window.AvoidAreaType.TYPE_KEYBOARD) {
            this.onKeyboardVisibilityChange(data.area.bottomRect.height > 0);
          } else if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            this.computeSafeInsets();
          }
        });
      }
    } catch (_error) {
      this.mainWindow = undefined;
    }
  }

  private chatListTopInset(): number {
    return this.chatTopInset;
  }

  private chatListTopBarTotalHeight(): number {
    return TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT + this.chatListTopInset();
  }

  private restoreChatListStartAfterInsetChange(previousTopInset: number, nextTopInset: number): void {
    if (Math.abs(previousTopInset - nextTopInset) < 0.5 ||
      this.headerCollapseOffset > 0 || this.searchCollapseProgress > 0.001) {
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    setTimeout(() => {
      if (lifecycleToken !== this.pageLifecycleToken) {
        return;
      }
      try {
        this.chatListScroller.scrollToIndex(0, false, ScrollAlign.START);
      } catch (_error) {
      }
    }, 32);
  }

  private computeSafeInsets(size?: window.Size): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const mainWindow = this.mainWindow ?? getMainWindow(context);
      let widthPx: number = 0;
      let heightPx: number = 0;
      if (size !== undefined) {
        widthPx = size.width;
        heightPx = size.height;
      } else if (mainWindow !== undefined) {
        const rect = mainWindow.getWindowProperties().windowRect;
        widthPx = rect.width;
        heightPx = rect.height;
      }
      let measuredTopInset: number = 0;
      if (mainWindow !== undefined) {
        const systemAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        measuredTopInset = this.getUIContext().px2vp(systemAvoidArea.topRect.height);
      }
      if (measuredTopInset > 0 && heightPx >= widthPx) {
        lastPortraitChatTopInset = measuredTopInset;
      }
      const previousTopInset = this.chatTopInset;
      const nextTopInset = resolveChatHostTopInset(
        measuredTopInset,
        widthPx,
        heightPx,
        lastPortraitChatTopInset
      );
      this.chatTopInset = nextTopInset;
      this.restoreChatListStartAfterInsetChange(previousTopInset, nextTopInset);
      this.listBottomInset = computeTabBottomInset(context);
    } catch (_error) {
      this.chatTopInset = resolveChatHostTopInset(
        0,
        0,
        0,
        lastPortraitChatTopInset
      );
      this.listBottomInset = ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;
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

  private maybeLoadInitialArchive(state: AppState): void {
    const useCase = this.loadArchiveChatsUseCase;
    if (!useCase || this.archiveInitialLoadRequested || state.connection.status !== 'ready') {
      return;
    }
    this.archiveInitialLoadRequested = true;
    const lifecycleToken = this.pageLifecycleToken;
    useCase.execute(100)
      .catch((error: Object) => {
        if (lifecycleToken !== this.pageLifecycleToken || this.loadArchiveChatsUseCase !== useCase) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Archive bootstrap completed without more chats: %{public}s', String(error));
      });
  }

  private maybeLoadInitialStories(state: AppState): void {
    const useCase = this.loadActiveStoriesUseCase;
    if (!useCase || this.storyInitialLoadRequested || state.connection.status !== 'ready') {
      return;
    }
    if (state.chats.orderedStoryChatIds.length > 0 || useCase.isLoadingInProgress()) {
      return;
    }

    this.storyInitialLoadRequested = true;
    const lifecycleToken = this.pageLifecycleToken;
    useCase.execute()
      .catch((error: Object) => {
        if (lifecycleToken !== this.pageLifecycleToken || this.loadActiveStoriesUseCase !== useCase) {
          return;
        }
        // TDLib returns 404 when the story list is exhausted; the adapter maps it
        // to a gateway error, so absence of previews remains a valid empty state.
        hilog.info(DOMAIN, TAG, 'Active stories bootstrap settled without more peers: %{public}s', String(error));
      });
  }

  private rebuildStoryPreviews(state: AppState): void {
    const previews: TgChatListStoryPreview[] = [];
    const missingChatIds: number[] = [];
    const storyChatIds = state.chats.orderedStoryChatIds.slice(0, 3);
    for (const chatId of storyChatIds) {
      const activeStories = state.chats.activeStoriesByChatId.get(chatId);
      const chat = state.chats.chats.get(chatId);
      if (!activeStories) {
        continue;
      }
      if (!chat) {
        missingChatIds.push(chatId);
        continue;
      }

      const chatItem = buildChatItemVO(chat, state);
      const preview = new TgChatListStoryPreview();
      preview.chatId = chatId;
      preview.storyId = latestActiveStoryId(activeStories);
      preview.initials = chatItem.initials;
      preview.backgroundColor = chatItem.avatarColor;
      preview.hasUnread = hasUnreadActiveStories(activeStories);
      preview.isCloseFriends = hasUnreadCloseFriendsStories(activeStories);
      if (chatItem.avatarImagePath.length > 0) {
        preview.imageSrc = chatItem.avatarImagePath;
        preview.useImage = true;
      }
      previews.push(preview);
    }
    this.storyPreviews = previews;

    const useCase = this.loadActiveStoriesUseCase;
    if (useCase && missingChatIds.length > 0) {
      const lifecycleToken = this.pageLifecycleToken;
      useCase.hydrateChatsIfMissing(missingChatIds)
        .catch((error: Object) => {
          if (lifecycleToken === this.pageLifecycleToken && this.loadActiveStoriesUseCase === useCase) {
            hilog.info(DOMAIN, TAG, 'Story chat hydration settled: %{public}s', String(error));
          }
        });
    }
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
    this.rebuildStoryPreviews(state);
    const items: ChatItemVO[] = [];
    const seenChatIds: Set<number> = new Set<number>();
    const normalizedQuery = this.searchQuery.trim().toLowerCase();
    const archivePreviewTitles: string[] = [];
    let archiveUnreadCount = 0;
    let unreadDialogsCount = 0;

    for (const archivedChatId of state.chats.archivedChatIds) {
      const archivedChat = state.chats.chats.get(archivedChatId);
      if (!archivedChat || archivedChat.archiveOrder === '0') {
        continue;
      }
      if (archivePreviewTitles.length < 3 && archivedChat.title.trim().length > 0) {
        archivePreviewTitles.push(archivedChat.title.trim());
      }
      // Telegram's archive badge represents unread dialogs, not the sum of
      // every unread message (the latter quickly becomes an unusable 9.6K).
      if (archivedChat.unreadCount > 0) {
        archiveUnreadCount += 1;
      }
    }
    this.archivedChatsCount = state.chats.archivedChatIds.length;
    this.archivedUnreadCount = archiveUnreadCount;
    this.archivedPreview = archivePreviewTitles.join(', ');

    for (const chatId of state.chats.orderedChatIds) {
      if (seenChatIds.has(chatId)) {
        continue;
      }
      seenChatIds.add(chatId);
      const chat = state.chats.chats.get(chatId);
      if (chat) {
        const item = buildChatItemVO(chat, state);
        if (item.unreadCount > 0) {
          unreadDialogsCount++;
        }
        if (this.matchesSelectedFilter(item) &&
          (normalizedQuery.length === 0 || this.matchesSearch(item, normalizedQuery))) {
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
    this.unreadFilterCount = unreadDialogsCount;
  }

  private matchesSelectedFilter(item: ChatItemVO): boolean {
    if (this.selectedFilterIndex === TgChatListFilter.Unread) {
      return item.unreadCount > 0;
    }
    if (this.selectedFilterIndex === TgChatListFilter.Personal) {
      return !item.isGroup;
    }
    return true;
  }

  private selectFilter(index: number): void {
    if (index < TgChatListFilter.All || index > TgChatListFilter.Personal ||
      index === this.selectedFilterIndex) {
      return;
    }
    this.selectedFilterIndex = index;
    try {
      this.rebuildList(getAppCoreRuntime().getStore().getState());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Filter rebuild failed: %{public}s', String(error));
    }
  }

  private updateSearchCollapseProgress(frameOffset: number): void {
    if (this.hasActiveSearch()) {
      this.headerCollapseOffset = 0;
      if (this.searchCollapseProgress !== 0) {
        this.searchCollapseProgress = 0;
      }
      return;
    }

    // List.currentOffset() includes contentStartOffset and therefore remains
    // negative while the first 54vp are consumed. Accumulate the per-frame
    // delta directly, exactly like iOS clips its search scroll offset.
    this.headerCollapseOffset = Math.max(0, this.headerCollapseOffset + frameOffset);
    const nextProgress = Math.max(0, Math.min(1,
      this.headerCollapseOffset / TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT));
    if (Math.abs(nextProgress - this.searchCollapseProgress) >= 0.005) {
      this.searchCollapseProgress = nextProgress;
    }
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

  private shouldShowArchiveRow(): boolean {
    return !this.hasActiveSearch() &&
      this.selectedFilterIndex === TgChatListFilter.All &&
      this.archivedChatsCount > 0;
  }

  private openArchive(): void {
    const navStack = this.bindNavigationStack();
    if (navStack === undefined) {
      hilog.error(DOMAIN, TAG, 'Navigation stack unavailable for archive');
      return;
    }
    this.onSearchDeactivate();
    try {
      navStack.pushPathByName('TgArchivedChatsPage', undefined);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to open archive: %{public}s', String(error));
    }
  }

  private setChatDestinationVisible(visible: boolean): void {
    navigationUIState.chatScreenVisible = visible;
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, visible);
  }

  private openComposePicker(): void {
    if (this.isComposePickerOpen) {
      hilog.info(DOMAIN, TAG, 'Ignoring duplicate Compose activation');
      return;
    }

    this.onSearchDeactivate();
    const previousVisible: boolean = navigationUIState.chatScreenVisible;
    this.isComposePickerOpen = true;
    this.setChatDestinationVisible(true);

    try {
      this.chatDetailStack.pushPathByName(
        'TgComposePage',
        new ComposeRouteParams(),
        (popInfo) => {
          this.isComposePickerOpen = false;
          const result = popInfo.result as ComposeResult | undefined;
          if (!result || result.chatId === 0) {
            this.setChatDestinationVisible(previousVisible);
            return;
          }

          if (result.failedMemberCount > 0) {
            try {
              const message: string = localized(
                $r('app.string.group_members_not_added').id,
                '%d members could not be added. You can invite them with a link.'
              ).replace('%d', result.failedMemberCount.toString());
              this.getUIContext().getPromptAction().showToast({ message: message, duration: 3200 });
            } catch (error) {
              hilog.error(DOMAIN, TAG, 'Compose creation notice failed: %{public}s', String(error));
            }
          }

          try {
            const state: AppState = getAppCoreRuntime().getStore().getState();
            const chat = state.chats.chats.get(result.chatId);
            this.setChatDestinationVisible(previousVisible);
            if (chat) {
              this.openChat(buildChatItemVO(chat, state));
              return;
            }
            // createPrivateChat returns the exact TDLib chat before the reducer's
            // matching update is guaranteed to reach this page. Keep navigation
            // deterministic without inventing an id or selecting another dialog.
            const pendingItem = new ChatItemVO();
            pendingItem.chatId = result.chatId;
            pendingItem.title = result.chatTitle;
            this.openChat(pendingItem);
          } catch (error) {
            this.setChatDestinationVisible(previousVisible);
            hilog.error(DOMAIN, TAG, 'Failed to resolve Compose target: %{public}s', String(error));
          }
        }
      );
    } catch (error) {
      this.isComposePickerOpen = false;
      this.setChatDestinationVisible(previousVisible);
      hilog.error(DOMAIN, TAG, 'Failed to open Compose picker: %{public}s', String(error));
    }
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

      Button(localized($r('app.string.archive').id, 'Archive'))
        .type(ButtonType.Normal)
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor(TgUiTokens.SWIPE_ACTION_ARCHIVE)
        .width(72)
        .height('100%')
        .borderRadius(0)
        .onClick(() => {
          this.handleMoveToArchive(item);
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

  private handleMoveToArchive(item: ChatItemVO): void {
    const useCase = this.moveChatToListUseCase;
    if (!useCase) {
      return;
    }
    useCase.execute(item.chatId, 'archive')
      .catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Archive failed for %{public}d: %{public}s', item.chatId, error.message);
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
    this.onSearchDeactivate();
    const navStack = this.chatDetailStack;
    const snapshotChat = getAppCoreRuntime().getStore().getState().chats.chats.get(item.chatId);
    PendingChatUnreadSnapshot.set(
      item.chatId,
      snapshotChat ? snapshotChat.lastReadInboxMessageId : '0',
      item.unreadCount
    );

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
      PendingChatUnreadSnapshot.clear(item.chatId);
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
      List({ scroller: this.chatListScroller }) {
        this.buildListHeader()
        if (this.shouldShowArchiveRow()) {
          ListItem() {
            TgArchivedChatsRow({
              title: localized($r('app.string.archived_chats').id, 'Archived Chats'),
              preview: this.archivedPreview,
              chatCount: this.archivedChatsCount,
              unreadCount: this.archivedUnreadCount,
              showSeparator: true,
              surfaceColor: TgUiTokens.CHAT_LIST_PINNED_SURFACE_BG,
              separatorColor: TgUiTokens.CHAT_LIST_SEPARATOR
            })
          }
          .onClick(() => {
            this.openArchive();
          })
        }
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
                    surfaceColor: TgUiTokens.CHAT_LIST_SURFACE_BG,
                    pinnedSurfaceColor: TgUiTokens.CHAT_LIST_PINNED_SURFACE_BG,
                    separatorColor: TgUiTokens.CHAT_LIST_SEPARATOR,
                    showSeparator: TgUiFeatureFlags.USE_INTERNAL_CHAT_ROW_SEPARATOR
                  })
                  .reuseId(this.getTgReuseId(item))

                if (item.isLastPinned) {
                  Row()
                    .width('100%')
                    .height(TgUiTokens.CHAT_ROW_SEPARATOR_STROKE)
                    .backgroundColor(TgUiTokens.CHAT_LIST_SEPARATOR)
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
        } else if (!this.shouldShowArchiveRow()) {
          ListItem() {
            this.buildListPlaceholder()
          }
        }
      }
      .cachedCount(10)
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
      .contentStartOffset(this.chatListTopBarTotalHeight())
      .contentEndOffset(this.listBottomInset)
      .onScrollFrameBegin((offset: number, _state: ScrollState) => {
        this.updateSearchCollapseProgress(offset);
        return { offsetRemain: offset };
      })
      .onScrollIndex((_start: number, end: number) => {
        this.maybeLoadMoreChats(end);
      })
      .onReachStart(() => {
        this.headerCollapseOffset = 0;
        this.searchCollapseProgress = 0;
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
        searchCollapseProgress: this.searchCollapseProgress,
        selectedFilterIndex: this.selectedFilterIndex,
        unreadFilterCount: this.unreadFilterCount,
        storyPreviews: this.storyPreviews,
        allFilterText: localized($r('app.string.chat_filter_all').id, 'All'),
        unreadFilterText: localized($r('app.string.chat_filter_unread').id, 'Unread'),
        personalFilterText: localized($r('app.string.chat_filter_personal').id, 'Personal'),
        searchPlaceholder: localized($r('app.string.search_placeholder').id, 'Search'),
        editText: localized($r('app.string.chat_list_edit_compact').id, 'Edit'),
        onComposePress: (): void => {
          this.openComposePicker();
        },
        onFilterChange: (index: number): void => {
          this.selectFilter(index);
        },
        onSearchChange: (value: string): void => {
          if (value === this.searchQuery) {
            return;
          }
          this.onSearchQueryChange(value);
        },
        onSearchWillFocus: (): void => {
          this.onHeaderSearchWillFocus();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.CHAT_LIST_SURFACE_BG)
  }
}
