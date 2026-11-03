// ChatListPage — main chat list tab
// Phase D-3: Stack overlay layout — list scrolls under translucent top bar for blur effect
// V2 migration: @ComponentV2, @Local, chatsUIState/navigationUIState singletons
//
// Data flow: AppStore → subscribe → rebuildList → ChatListDataSource → LazyForEach → TgChatRow

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { chatsUIState, navigationUIState, chatUIState } from '../../../core/model/UIStateModels';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { AppStore } from '../../../core/store/AppStore';
import { TdGatewayPort } from '../../../domain/ports/TdGatewayPort';
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
import { TgChatListFilter, TgChatListFilterTab } from '../../tg_ui/atoms/TgChatListFilterBar';
import { selectChatFolderTabs, selectChatIdsForFolder, ChatFolderTab } from '../../../domain/selectors/chatFolderSelectors';
import { selectChatContextMenuEntries, chatContextActionIcon, ChatContextAction, ChatContextMenuEntry } from '../../../domain/selectors/chatContextMenuSelectors';
import { localized } from '../../../core/utils/AppResource';
import {
  computeTabBottomInset,
  getMainWindow,
  addWindowSizeListener,
  removeWindowSizeListener
} from '../../utils/SafeAreaUtils';
import { ROOT_TAB_BAR_FALLBACK_CONTENT_INSET } from '../../utils/RootTabBarGeometry';
import { ROOT_TAB_BAR_AUTO_HIDE_THRESHOLD } from '../../utils/RootTabBarGeometry';
import { resolveChatHostTopInset } from '../../utils/ChatSplitGeometry';
import { ChatScreenRouteParams } from '../chat/ChatScreenRouteParams';
import { pushChatScreenRoute } from '../chat/ChatOpenTransaction';
import { ComposeResult, ComposeRouteParams } from '../compose/TgComposePage';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createLoadChatsUseCase, LoadChatsUseCase } from '../../../domain/usecases/loadChats';
import { createLoadFolderChatsUseCase, LoadFolderChatsUseCase } from '../../../domain/usecases/loadFolderChats';
import {
  createLoadArchiveChatsUseCase,
  LoadArchiveChatsUseCase
} from '../../../domain/usecases/loadArchiveChats';
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
let lastPortraitChatTopInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

@ComponentV2
export struct ChatListPage {
  @Local pageStack: NavPathStack = new NavPathStack();

  @Param chatDetailStack: NavPathStack = new NavPathStack();
  // Island player body-tap bridge: MainTabsPage ticks this after setting
  // PendingJumpSignal; the full openChat ritual must run HERE (active-chat
  // state triple and account-owned route snapshot) — a bare push from
  // the tabs page renders the split placeholder instead of the chat.
  @Param islandOpenChatTick: number = 0;
  @Param islandOpenChatId: number = 0;

  @Event onKeyboardVisibilityChange: (visible: boolean) => void = (_: boolean): void => {};
  @Param searchQuery: string = '';
  @Event onSearchQueryChange: (value: string) => void = (_: string): void => {};
  @Event onSearchDeactivate: () => void = (): void => {};
  @Event onHeaderSearchWillFocus: () => void = (): void => {};
  @Event onRootBarAutoHide: (hidden: boolean) => void = (_: boolean): void => {};

  // Reactive state from @ObservedV2 model (replaces @StorageLink)
  private chatsState = chatsUIState;
  private navState = navigationUIState;

  @Local private listBottomInset: number = ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;
  @Local private chatTopInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  @Local private selectedFilterIndex: number = TgChatListFilter.All;
  // TDLib folder strip (0 = "All chats"), mirrored from state.chatFilters through the selector.
  @Local private folderTabs: TgChatListFilterTab[] = [];
  @Local private selectedFolderId: number = 0;
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
  private rootBarAutoHideAccum: number = 0;
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
  private windowSizeListener?: () => void;
  private loadChatsUseCase?: LoadChatsUseCase;
  private loadFolderChatsUseCase?: LoadFolderChatsUseCase;
  private loadArchiveChatsUseCase?: LoadArchiveChatsUseCase;
  private loadActiveStoriesUseCase?: LoadActiveStoriesUseCase;
  private accountStore?: AppStore;
  private accountScope?: AppStore;
  private chatGateway?: TdGatewayPort;
  private muteUseCase?: SetChatMuteUseCase;
  private pinUseCase?: ToggleChatPinnedUseCase;
  private moveChatToListUseCase?: MoveChatToListUseCase;
  private deleteChatUseCase?: DeleteChatHistoryUseCase;
  private toggleUnreadUseCase?: ToggleChatUnreadUseCase;
  private isOpeningChat: boolean = false;
  private isComposePickerOpen: boolean = false;
  private composePickerGeneration: number = 0;
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
    const params = this.createChatRouteParams(chatId, title);
    if (params === undefined) return;

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
      this.deferredOpenChatId = 0;
      this.deferredOpenChatTitle = '';
      this.openChatRoute(params);
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
      const gateway = getTdGatewayAdapter();
      this.accountStore = store;
      this.accountScope = store.createScope();
      this.chatGateway = gateway;
      this.loadChatsUseCase = createLoadChatsUseCase(store, gateway);
      this.loadFolderChatsUseCase = createLoadFolderChatsUseCase(store, gateway);
      this.loadArchiveChatsUseCase = createLoadArchiveChatsUseCase(store, gateway);
      this.loadActiveStoriesUseCase = createLoadActiveStoriesUseCase(store, gateway);
      this.muteUseCase = createSetChatMuteUseCase(gateway);
      this.pinUseCase = createToggleChatPinnedUseCase(gateway);
      this.moveChatToListUseCase = createMoveChatToListUseCase(gateway);
      this.deleteChatUseCase = createDeleteChatHistoryUseCase(gateway);
      this.toggleUnreadUseCase = createToggleChatUnreadUseCase(gateway);
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
    this.loadFolderChatsUseCase?.cancel();
    this.loadFolderChatsUseCase = undefined;
    this.loadChatsUseCase = undefined;
    this.loadArchiveChatsUseCase = undefined;
    this.loadActiveStoriesUseCase = undefined;
    this.accountStore = undefined;
    this.accountScope = undefined;
    this.chatGateway = undefined;
    this.muteUseCase = undefined;
    this.pinUseCase = undefined;
    this.moveChatToListUseCase = undefined;
    this.deleteChatUseCase = undefined;
    this.toggleUnreadUseCase = undefined;
    removeWindowSizeListener(this.windowSizeListener);
    this.windowSizeListener = undefined;
    this.mainWindow = undefined;
    hilog.info(DOMAIN, TAG, 'Unsubscribed from store');
  }

  private bindWindowSizeListener(): void {
    try {
      removeWindowSizeListener(this.windowSizeListener);
      this.windowSizeListener = undefined;
      this.mainWindow = undefined;
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.mainWindow = getMainWindow(context);
      if (this.mainWindow !== undefined) {
        const lifecycleToken: number = this.pageLifecycleToken;
        const boundWindow: window.Window = this.mainWindow;
        this.computeSafeInsets();
        this.windowSizeListener = addWindowSizeListener(boundWindow, (size: window.Size) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.mainWindow !== boundWindow) {
            return;
          }
          this.computeSafeInsets(size);
        }, (data: window.AvoidAreaOptions) => {
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
    if (this.selectedFolderId !== 0 && !this.hasActiveSearch() &&
      this.chatsState.connectionStatus === 'ready') {
      this.loadFolderChatsUseCase?.request(this.selectedFolderId);
      return;
    }
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

    this.folderTabs = this.buildFolderTabs(state);
    const folderId: number = this.selectedFolderId;
    const sourceChatIds: number[] = folderId !== 0 ?
      selectChatIdsForFolder(state, folderId) : state.chats.orderedChatIds;
    for (const chatId of sourceChatIds) {
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
        if ((folderId !== 0 || this.matchesSelectedFilter(item)) &&
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

  private buildFolderTabs(state: AppState): TgChatListFilterTab[] {
    const source: ChatFolderTab[] = selectChatFolderTabs(state);
    const tabs: TgChatListFilterTab[] = [];
    for (const tab of source) {
      const item = new TgChatListFilterTab();
      item.id = tab.id;
      item.title = tab.isAllChats ? localized($r('app.string.chat_folders_all').id, 'All') : tab.title;
      item.unreadCount = tab.unreadCount;
      tabs.push(item);
    }
    // A single "All" tab is not a choice: keep the legacy rail in that case.
    return tabs.length > 1 ? tabs : [];
  }

  private selectFolder(folderId: number): void {
    if (folderId === this.selectedFolderId) {
      return;
    }
    this.selectedFolderId = folderId;
    this.rebuildList(getAppCoreRuntime().getStore().getState());
    if (folderId !== 0) {
      this.loadFolderChatsUseCase?.request(folderId);
    }
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

  // Deliberately latch-free: the host may force-show the island (return from
  // chat, search activation), so every threshold crossing re-emits and the
  // host deduplicates against its own state.
  private emitRootBarAutoHide(hidden: boolean): void {
    this.rootBarAutoHideAccum = 0;
    this.onRootBarAutoHide(hidden);
  }

  // Direction hysteresis: only an accumulated same-direction run of
  // ROOT_TAB_BAR_AUTO_HIDE_THRESHOLD vp flips the island, so bounce and
  // micro-jitter never toggle it. onReachStart force-shows at the top.
  private trackRootBarAutoHide(frameOffset: number): void {
    if (!TgUiFeatureFlags.USE_ROOT_BAR_AUTO_HIDE_ON_SCROLL || this.hasActiveSearch()) {
      return;
    }
    if (frameOffset > 0) {
      this.rootBarAutoHideAccum = Math.max(0, this.rootBarAutoHideAccum) + frameOffset;
      if (this.rootBarAutoHideAccum >= ROOT_TAB_BAR_AUTO_HIDE_THRESHOLD) {
        this.emitRootBarAutoHide(true);
      }
      return;
    }
    if (frameOffset < 0) {
      this.rootBarAutoHideAccum = Math.min(0, this.rootBarAutoHideAccum) + frameOffset;
      if (this.rootBarAutoHideAccum <= -ROOT_TAB_BAR_AUTO_HIDE_THRESHOLD) {
        this.emitRootBarAutoHide(false);
      }
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

    const store = this.accountStore;
    const gateway = this.chatGateway;
    if (store === undefined || gateway === undefined || !this.isCurrentAccountOwner()) return;
    const lifecycleToken = this.pageLifecycleToken;
    const generation = ++this.composePickerGeneration;
    const previousOwnerToken = navigationUIState.activeChatOwnerToken;
    let resultConsumed = false;
    const current = (): boolean => lifecycleToken === this.pageLifecycleToken &&
      generation === this.composePickerGeneration && this.accountStore === store &&
      this.chatGateway === gateway && this.isCurrentAccountOwner() &&
      navigationUIState.activeChatOwnerToken === previousOwnerToken;

    this.onSearchDeactivate();
    if (!current()) return;
    const previousVisible: boolean = navigationUIState.chatScreenVisible;
    this.isComposePickerOpen = true;
    this.setChatDestinationVisible(true);

    try {
      this.chatDetailStack.pushPathByName(
        'TgComposePage',
        new ComposeRouteParams(),
        (popInfo) => {
          if (resultConsumed || !current()) return;
          resultConsumed = true;
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
            const state: AppState = store.getState();
            const chat = state.chats.chats.get(result.chatId);
            const params = new ChatScreenRouteParams(result.chatId, chat ? chat.title : result.chatTitle, store, gateway);
            if (!current() || !params.isCurrentAccount(getAppCoreRuntime().getStore())) return;
            this.setChatDestinationVisible(previousVisible);
            // createPrivateChat returns the exact TDLib chat before the reducer's
            // matching update is guaranteed to reach this page. Keep navigation
            // deterministic without inventing an id or selecting another dialog.
            this.openChatRoute(params);
          } catch (error) {
            if (current()) this.setChatDestinationVisible(previousVisible);
            hilog.error(DOMAIN, TAG, 'Failed to resolve Compose target: %{public}s', String(error));
          }
        }
      );
    } catch (error) {
      if (current()) {
        this.isComposePickerOpen = false;
        this.setChatDestinationVisible(previousVisible);
      }
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
  // Long-press menu (iOS ChatContextMenus.swift order): the list decides nothing, it renders the
  // selector's entries and forwards the tapped action to the use case that already owns the change.
  private contextMenuSelfUserId(): number {
    const store = this.accountStore;
    return store === undefined ? 0 : store.getState().auth.userId;
  }

  private contextMenuEntryLabel(action: ChatContextAction): Resource {
    switch (action) {
      case ChatContextAction.MarkRead: return $r('app.string.chat_context_mark_read');
      case ChatContextAction.MarkUnread: return $r('app.string.chat_context_mark_unread');
      case ChatContextAction.Archive: return $r('app.string.chat_context_archive');
      case ChatContextAction.Unarchive: return $r('app.string.chat_context_unarchive');
      case ChatContextAction.Pin: return $r('app.string.chat_context_pin');
      case ChatContextAction.Unpin: return $r('app.string.chat_context_unpin');
      case ChatContextAction.Mute: return $r('app.string.chat_context_mute');
      case ChatContextAction.Unmute: return $r('app.string.chat_context_unmute');
      default: return $r('app.string.chat_context_delete');
    }
  }

  private contextMenuIcon(action: ChatContextAction): Resource {
    switch (chatContextActionIcon(action)) {
      case 'ic_eye': return $r('app.media.ic_eye');
      case 'ic_eye_off': return $r('app.media.ic_eye_off');
      case 'ic_archive': return $r('app.media.ic_archive');
      case 'ic_folder': return $r('app.media.ic_folder');
      case 'ic_pin': return $r('app.media.ic_pin');
      case 'ic_mute': return $r('app.media.ic_mute');
      case 'ic_unmute': return $r('app.media.ic_unmute');
      default: return $r('app.media.ic_delete');
    }
  }

  private contextMenuEntries(item: ChatItemVO): ChatContextMenuEntry[] {
    const state = this.accountStore === undefined ? undefined : this.accountStore.getState();
    if (state === undefined) {
      return [];
    }
    return selectChatContextMenuEntries(state.chats.chats.get(item.chatId), state.auth.userId);
  }

  private handleContextAction(action: ChatContextAction, item: ChatItemVO): void {
    switch (action) {
      case ChatContextAction.MarkRead:
      case ChatContextAction.MarkUnread:
        this.handleToggleUnread(item);
        break;
      case ChatContextAction.Archive:
        this.handleMoveToArchive(item);
        break;
      case ChatContextAction.Unarchive:
        this.handleMoveToMain(item);
        break;
      case ChatContextAction.Pin:
      case ChatContextAction.Unpin:
        this.handlePinToggle(item);
        break;
      case ChatContextAction.Mute:
      case ChatContextAction.Unmute:
        this.handleMuteToggle(item);
        break;
      case ChatContextAction.Delete:
        this.handleDeleteChat(item);
        break;
      default:
        break;
    }
  }

  private handleMoveToMain(item: ChatItemVO): void {
    const useCase = this.moveChatToListUseCase;
    if (!useCase) {
      return;
    }
    useCase.execute(item.chatId, 'main')
      .catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Unarchive failed for %{public}d: %{public}s', item.chatId, error.message);
      });
  }

  @Builder
  buildChatContextMenu(item: ChatItemVO) {
    Column() {
      ForEach(this.contextMenuEntries(item), (entry: ChatContextMenuEntry) => {
        Row() {
          Image(this.contextMenuIcon(entry.action))
            .width(TgUiTokens.CHAT_CONTEXT_MENU_ICON_SIZE)
            .height(TgUiTokens.CHAT_CONTEXT_MENU_ICON_SIZE)
            .fillColor(entry.destructive ? TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE : TgUiTokens.CHAT_CONTEXT_MENU_TEXT)
          Text(localized(this.contextMenuEntryLabel(entry.action).id, ''))
            .fontSize(TgUiTokens.CHAT_CONTEXT_MENU_FONT_SIZE)
            .fontColor(entry.destructive ? TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE : TgUiTokens.CHAT_CONTEXT_MENU_TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: TgUiTokens.CHAT_CONTEXT_MENU_ICON_GAP })
            .layoutWeight(1)
        }
        .width('100%')
        .height(TgUiTokens.CHAT_CONTEXT_MENU_ITEM_HEIGHT)
        .padding({ left: TgUiTokens.CHAT_CONTEXT_MENU_PADDING_H, right: TgUiTokens.CHAT_CONTEXT_MENU_PADDING_H })
        .onClick(() => {
          this.handleContextAction(entry.action, item);
        })
      }, (entry: ChatContextMenuEntry) => entry.action.toString() + item.chatId.toString())
    }
    .width(TgUiTokens.CHAT_CONTEXT_MENU_WIDTH)
    .backgroundColor(TgUiTokens.CHAT_CONTEXT_MENU_BG)
    .borderRadius(TgUiTokens.CHAT_CONTEXT_MENU_RADIUS)
    .clip(true)
  }

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
    if (item.unreadCount > 0 || item.isMarkedAsUnread) {
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

  @Monitor('islandOpenChatTick')
  private onIslandOpenChatRequested(_monitor: IMonitor): void {
    const chatId = this.islandOpenChatId;
    if (this.islandOpenChatTick === 0 || chatId === 0) {
      return;
    }
    const store = this.accountStore;
    if (store === undefined || !this.isCurrentAccountOwner()) return;
    const state: AppState = store.getState();
    const chat = state.chats.chats.get(chatId);
    if (chat) {
      this.openChat(buildChatItemVO(chat, state));
    }
  }

  private openChat(item: ChatItemVO): void {
    const params = this.createChatRouteParams(item.chatId, item.title);
    if (params !== undefined) this.openChatRoute(params);
  }

  private isCurrentAccountOwner(): boolean {
    return this.accountStore !== undefined && this.accountScope !== undefined &&
      this.accountScope.isScopeCurrent() && getAppCoreRuntime().getStore() === this.accountStore;
  }

  private createChatRouteParams(chatId: number, title: string): ChatScreenRouteParams | undefined {
    const store = this.accountStore;
    const gateway = this.chatGateway;
    if (chatId === 0 || store === undefined || gateway === undefined || !this.isCurrentAccountOwner()) return undefined;
    return new ChatScreenRouteParams(chatId, title, store, gateway);
  }

  private openChatRoute(params: ChatScreenRouteParams): void {
    if (!this.isCurrentAccountOwner() || params.accountStore !== this.accountStore ||
      !params.isCurrentAccount(getAppCoreRuntime().getStore())) return;
    hilog.info(DOMAIN, TAG, 'openChat called for chatId: %{public}d', params.chatId);
    const nowMs = Date.now();
    const navLockUntil = navigationUIState.chatNavLockUntil;
    if (nowMs < navLockUntil) {
      hilog.info(DOMAIN, TAG, 'openChat blocked by nav lock until %{public}d', navLockUntil);
      this.clearDeferredOpen();
      return;
    }
    if (params.chatId === this.deferredOpenChatId) {
      this.clearDeferredOpen();
    }
    if (this.isOpeningChat) {
      hilog.info(DOMAIN, TAG, 'Ignoring duplicate openChat tap for %{public}d', params.chatId);
      return;
    }
    if (!TgUiFeatureFlags.USE_TG_CHAT_V2) {
      hilog.info(DOMAIN, TAG, 'TgChatV2 feature flag is disabled');
      return;
    }
    if (params.chatId === 0) {
      hilog.error(DOMAIN, TAG, 'Invalid chatId: %{public}d', params.chatId);
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    this.onSearchDeactivate();
    if (lifecycleToken !== this.pageLifecycleToken || !this.isCurrentAccountOwner() ||
      !params.isCurrentAccount(getAppCoreRuntime().getStore())) return;
    const navStack = this.chatDetailStack;

    this.isOpeningChat = true;
    const pushed = pushChatScreenRoute(params, navStack, getAppCoreRuntime().getStore());
    this.isOpeningChat = false;
    if (!pushed) {
      return;
    }
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
                  avatarIsSavedMessages: item.isSavedMessages,
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
            .bindContextMenu(this.buildChatContextMenu(item), ResponseType.LongPress)
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
      .onScrollFrameBegin((offset: number, state: ScrollState) => {
        this.updateSearchCollapseProgress(offset);
        // Layout/data-storm adjustments arrive as Idle frames — only a real
        // drag or fling may auto-hide the island (witnessed startup self-hide).
        if (state === ScrollState.Scroll || state === ScrollState.Fling) {
          this.trackRootBarAutoHide(offset);
        }
        return { offsetRemain: offset };
      })
      .onScrollIndex((_start: number, end: number) => {
        this.maybeLoadMoreChats(end);
      })
      .onReachStart(() => {
        this.headerCollapseOffset = 0;
        this.searchCollapseProgress = 0;
        this.emitRootBarAutoHide(false);
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
        filterTabs: this.folderTabs,
        selectedFolderId: this.selectedFolderId,
        onFolderFilterChange: (folderId: number): void => {
          this.selectFolder(folderId);
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
