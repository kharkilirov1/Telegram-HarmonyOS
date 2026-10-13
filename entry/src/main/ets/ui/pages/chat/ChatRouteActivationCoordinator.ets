// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { navigationUIState } from '../../../core/model/UIStateModels';
import { AppState } from '../../../core/model/AppState';
import { AppStore } from '../../../core/store/AppStore';
import { TdGatewayPort } from '../../../domain/ports/TdGatewayPort';
import { ChatMediaDownloadController } from './ChatMediaDownloadController';
import { ChatAccessController } from './ChatAccessController';
import { createLoadChatAccessUseCase } from '../../../domain/usecases/loadChatAccess';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { PendingSharedMediaAction } from './PendingSharedMediaActionSignal';
import { createSendMessageUseCase, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { createStickerPanelUseCase, StickerPanelUseCase } from '../../../domain/usecases/stickerPanel';
import { SendMediaMessageUseCase, createSendMediaMessageUseCase } from '../../../domain/usecases/sendMediaMessage';
import { createEditMessageUseCase, EditMessageUseCase } from '../../../domain/usecases/editMessage';
import { createDeleteMessagesUseCase, DeleteMessagesUseCase } from '../../../domain/usecases/deleteMessages';
import { ForwardMessagesUseCase, createForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { createSetChatMuteUseCase, SetChatMuteUseCase } from '../../../domain/usecases/setChatMute';
import { createJoinChatUseCase, JoinChatUseCase } from '../../../domain/usecases/joinChat';
import { SearchChatMessagesUseCase, createSearchChatMessagesUseCase } from '../../../domain/usecases/searchChatMessages';
import { PinChatMessageUseCase, createPinChatMessageUseCase } from '../../../domain/usecases/pinChatMessage';
import { LoadChatHistoryUseCase, LoadChatHistoryParams, createLoadChatHistoryUseCase } from '../../../domain/usecases/loadChatHistory';
import { createMarkChatReadUseCase, MarkChatReadUseCase } from '../../../domain/usecases/markChatRead';
import { createLoadRepliedMessageUseCase, LoadRepliedMessageUseCase } from '../../../domain/usecases/loadRepliedMessage';
import { ReplyHydrationCoordinator } from './ReplyHydrationCoordinator';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatRouteActivationCoordinatorPort {
  accountStore?: AppStore;
  activeChatId: number;
  awaitingInitialTimeline: boolean;
  blockAutoPaginationUntilUserScroll: boolean;
  chatAccessController?: ChatAccessController;
  chatGateway?: TdGatewayPort;
  chatJoinUseCase?: JoinChatUseCase;
  chatMuteUseCase?: SetChatMuteUseCase;
  currentScrollChatId: number;
  deleteUseCase?: DeleteMessagesUseCase;
  editUseCase?: EditMessageUseCase;
  forwardUseCase?: ForwardMessagesUseCase;
  hasRestoredUnreadBoundary: boolean;
  initialHistoryFallbackRequested: boolean;
  initialHistoryParams?: LoadChatHistoryParams;
  isApplyingTimelineDiff: boolean;
  isClosing: boolean;
  isLoadingNewer: boolean;
  lastMarkReadRequestKey: string;
  lastVisibleEndIndex: number;
  lastVisibleStartIndex: number;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  loadRepliedMessageUseCase?: LoadRepliedMessageUseCase;
  markChatReadUseCase?: MarkChatReadUseCase;
  mediaDownloadCtrl: ChatMediaDownloadController;
  needsScrollRestore: boolean;
  pageLifecycleToken: number;
  paginationRecheckTimerId: number;
  pendingMediaDownloadVersion: number;
  pendingSharedMediaAction: PendingSharedMediaAction | undefined;
  pinUseCase?: PinChatMessageUseCase;
  pinnedMessageDismissedId: string;
  previousDataCount: number;
  rebuildScheduled: boolean;
  rebuildTimerId: number;
  replyHydrationCoordinator: ReplyHydrationCoordinator;
  routeAccountStore?: AppStore;
  routeActivated: boolean;
  routeContext?: ChatScreenRouteParams;
  routeDataStarted: boolean;
  scrollToBottomUnreadCount: number;
  searchUseCase?: SearchChatMessagesUseCase;
  sendMediaUseCase?: SendMediaMessageUseCase;
  sendUseCase?: SendMessageUseCase;
  stickerPanelUseCase?: StickerPanelUseCase;
  stickyLastReadMessageId: string;
  suppressLoadOlderUntil: number;
  transientTimerIds: Set<number>;
  unreadRestoreIndex: number;
  unsubscribe?: () => void;
  aboutToDisappear(): void;
  activateChatRoute(): void;
  applyPendingForwardTransferIfNeeded(): void;
  bindNavigationStack(): NavPathStack | undefined;
  bindWindowSizeListener(): void;
  captureInitialHistorySnapshot(state: AppState, scheduleCorrection?: boolean): void;
  computeSafeInsets(): void;
  isRouteContextCurrent(route: ChatScreenRouteParams): boolean;
  loadPinnedMessage(): void;
  maybeMarkChatRead(state: AppState): void;
  notifyMediaDownloadStateChanged(fileId: number): void;
  ownsNavigationContext(): boolean;
  rebuildTimeline(state: AppState): void;
  refreshGroupedStickerHomePreviews(state: AppState): void;
  refreshOpenMediaGalleryItems(): void;
  resetPaginationState(): void;
  restoreDraftFromChat(): void;
  setupMediaPlaybackController(): void;
  shouldReactToStoreChange(newState: AppState, prevState: AppState): boolean;
  startOwnedChatData(route: ChatScreenRouteParams): void;
  syncOwnedChatContext(): void;
  updateChatTopBarData(state: AppState): void;
}

export function aboutToAppear(host: ChatRouteActivationCoordinatorPort): void {
    // NavDestination.onReady supplies the account-bound route. Reading
    // globals here would bind a delayed A intent to whichever account is B.
    host.activateChatRoute();
  }

export function activateChatRoute(host: ChatRouteActivationCoordinatorPort): void {
    const route = host.routeContext;
    if (host.routeActivated || route === undefined || !host.isRouteContextCurrent(route)) return;
    try {
      host.isClosing = false;
      host.pendingSharedMediaAction = undefined;
      host.pageLifecycleToken++;
      const store = route.accountStore;
      if (!store.isScopeCurrent() ||
        (host.routeAccountStore !== undefined && host.routeAccountStore !== store)) return;
      const gateway = route.gateway;
      if (!host.isRouteContextCurrent(route)) return;
      host.routeAccountStore = store;
      host.accountStore = store;
      host.chatGateway = gateway;
      host.routeActivated = true;
      host.routeDataStarted = false;
      host.initialHistoryParams = undefined;
      host.initialHistoryFallbackRequested = false;
      host.bindNavigationStack();
      host.syncOwnedChatContext();
      host.restoreDraftFromChat();
      if (host.ownsNavigationContext()) {
        navigationUIState.chatScreenVisible = true;
        AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
      }
      host.computeSafeInsets();

      host.chatAccessController?.dispose();
      const accessLifecycleToken = host.pageLifecycleToken;
      host.chatAccessController = new ChatAccessController(createLoadChatAccessUseCase(store, gateway),
        (): void => {
          if (accessLifecycleToken !== host.pageLifecycleToken || host.accountStore !== store) return;
          host.updateChatTopBarData(store.getState());
        });
      host.sendUseCase = createSendMessageUseCase(gateway);
      host.sendMediaUseCase = createSendMediaMessageUseCase(gateway);
      host.editUseCase = createEditMessageUseCase(gateway);
      host.deleteUseCase = createDeleteMessagesUseCase(gateway);
      host.forwardUseCase = createForwardMessagesUseCase(gateway);
      host.chatMuteUseCase = createSetChatMuteUseCase(gateway);
      host.chatJoinUseCase = createJoinChatUseCase(gateway);
      host.searchUseCase = createSearchChatMessagesUseCase(gateway);
      host.pinUseCase = createPinChatMessageUseCase(gateway);
      host.stickerPanelUseCase = createStickerPanelUseCase(gateway);
      host.loadChatHistoryUseCase = createLoadChatHistoryUseCase(store, gateway);
      host.loadRepliedMessageUseCase = createLoadRepliedMessageUseCase(
        store,
        gateway,
        host.loadChatHistoryUseCase
      );
      host.replyHydrationCoordinator.reset();
      host.markChatReadUseCase = createMarkChatReadUseCase(store, gateway);
      const mediaLifecycleToken: number = host.pageLifecycleToken;
      host.mediaDownloadCtrl.setChangeListener((version: number, fileId: number): void => {
        if (mediaLifecycleToken !== host.pageLifecycleToken) {
          return;
        }
        host.pendingMediaDownloadVersion = version;
        host.notifyMediaDownloadStateChanged(fileId);
        host.refreshOpenMediaGalleryItems();
      });
      host.currentScrollChatId = host.activeChatId;
      host.needsScrollRestore = true;
      host.lastVisibleStartIndex = -1;
      host.lastVisibleEndIndex = -1;
      host.previousDataCount = 0;
      host.suppressLoadOlderUntil = 0;
      host.isLoadingNewer = false;
      host.unreadRestoreIndex = -1;
      host.hasRestoredUnreadBoundary = false;
      host.lastMarkReadRequestKey = '';
      host.blockAutoPaginationUntilUserScroll = false;
      host.isApplyingTimelineDiff = false;
      if (host.paginationRecheckTimerId >= 0) {
        clearTimeout(host.paginationRecheckTimerId);
        host.paginationRecheckTimerId = -1;
      }
      host.resetPaginationState();
      host.setupMediaPlaybackController();
      host.awaitingInitialTimeline = host.activeChatId !== 0;
      // Capture lastReadInboxMessageId at chat entry — survives markChatRead
      const initialState = store.getState();
      const entryChat = initialState.chats.chats.get(host.activeChatId);
      const entryUnreadCount = route.entryUnreadCount ?? (entryChat ? entryChat.unreadCount : 0);
      host.stickyLastReadMessageId = entryUnreadCount > 0
        ? (route.entryLastReadInboxMessageId ?? (entryChat ? entryChat.lastReadInboxMessageId : '0'))
        : '';
      host.scrollToBottomUnreadCount = entryChat ? Math.max(0, entryChat.unreadCount) : 0;
      host.captureInitialHistorySnapshot(initialState, false);
      host.applyPendingForwardTransferIfNeeded();
      host.rebuildTimeline(initialState);
      host.pinnedMessageDismissedId = '0';
      host.loadPinnedMessage();
      // Do NOT call maybeMarkChatRead here — openChat hasn't reached TDLib yet.
      // The store subscription will call it after history loads (openChat is done by then).

      if (host.unsubscribe !== undefined) {
        host.unsubscribe();
        host.unsubscribe = undefined;
      }

      const lifecycleToken: number = host.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (lifecycleToken !== host.pageLifecycleToken || host.unsubscribe !== activeUnsubscribe) {
          return;
        }
        // Preserve the first owned state before coalescing can skip over a read update.
        host.captureInitialHistorySnapshot(_newState);
        if (_newState.files.transfers !== _prevState.files.transfers) {
          host.refreshGroupedStickerHomePreviews(_newState);
        }
        if (!host.shouldReactToStoreChange(_newState, _prevState)) {
          return;
        }
        if (!host.rebuildScheduled) {
          host.rebuildScheduled = true;
          let scheduledTimerId: number = -1;
          scheduledTimerId = setTimeout(() => {
            if (lifecycleToken !== host.pageLifecycleToken ||
              host.rebuildTimerId !== scheduledTimerId ||
              host.unsubscribe !== activeUnsubscribe) {
              return;
            }
            host.rebuildTimerId = -1;
            host.rebuildScheduled = false;
            try {
              const currentState = store.getState();
              host.rebuildTimeline(currentState);
              host.maybeMarkChatRead(currentState);
            } catch (e) {
              hilog.error(DOMAIN, TAG, 'Timeline rebuild failed: %{public}s', String(e));
            }
          }, 0) as number;
          host.rebuildTimerId = scheduledTimerId;
        }
      });
      host.unsubscribe = activeUnsubscribe;

      host.bindWindowSizeListener();
      host.startOwnedChatData(route);
    } catch (e) {
      host.aboutToDisappear();
      hilog.error(DOMAIN, TAG, 'Chat route activation failed: %{public}s', String(e));
    }
  }

export function shouldReactToStoreChange(host: ChatRouteActivationCoordinatorPort, newState: AppState, prevState: AppState): boolean {
    const chatId = host.activeChatId;
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
    const chat = newState.chats.chats.get(chatId);
    if ((chat?.type === 'channel' || chat?.type === 'supergroup') && newState.chats.supergroupAccess.get(chat.supergroupId) !==
      prevState.chats.supergroupAccess.get(chat.supergroupId)) return true;
    if (chat?.type === 'supergroup' && newState.chats.supergroupBoosts.get(chat.supergroupId) !==
      prevState.chats.supergroupBoosts.get(chat.supergroupId)) return true;
    if (chat?.type === 'supergroup' && newState.chats.supergroupSlowmode.get(chat.supergroupId) !==
      prevState.chats.supergroupSlowmode.get(chat.supergroupId)) return true;
    if (chat?.type === 'group' && newState.chats.basicGroupAccess.get(chat.basicGroupId) !==
      prevState.chats.basicGroupAccess.get(chat.basicGroupId)) return true;
    if (newState.chats.typingActions.get(chatId) !== prevState.chats.typingActions.get(chatId)) {
      return true;
    }
    // File transfer progress updates (download indicators for media bubbles)
    if (newState.files.transfers !== prevState.files.transfers) {
      return true;
    }
    return newState.users.users !== prevState.users.users;
  }

export function scheduleLifecycleTask(host: ChatRouteActivationCoordinatorPort, delayMs: number, task: () => void): void {
    const lifecycleToken: number = host.pageLifecycleToken;
    let timerId: number = -1;
    timerId = setTimeout(() => {
      if (lifecycleToken !== host.pageLifecycleToken || !host.transientTimerIds.has(timerId)) {
        return;
      }
      host.transientTimerIds.delete(timerId);
      task();
    }, delayMs) as number;
    host.transientTimerIds.add(timerId);
  }
