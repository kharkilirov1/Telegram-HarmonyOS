// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { chatUIState, navigationUIState } from '../../../core/model/UIStateModels';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { AppStore } from '../../../core/store/AppStore';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { LoadChatHistoryUseCase } from '../../../domain/usecases/loadChatHistory';
import { localized } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatRouteOwnershipCoordinatorPort {
  activeChatId: number;
  activeChatTitle: string;
  awaitingInitialTimeline: boolean;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  pageLifecycleToken: number;
  routeAccountStore?: AppStore;
  routeActivated: boolean;
  routeChatId: number;
  routeChatTitle: string;
  routeContext?: ChatScreenRouteParams;
  routeDataStarted: boolean;
  activateChatRoute(): void;
  bindNavigationStack(): NavPathStack | undefined;
  captureInitialHistorySnapshot(state: AppState, scheduleCorrection?: boolean): void;
  getChatUIContext(): UIContext;
  isRouteContextCurrent(route: ChatScreenRouteParams): boolean;
  maybeMarkChatRead(state: AppState): void;
  ownsNavigationContext(): boolean;
  resolveOwnedChatTitle(): string;
  scheduleHistoryLoad(chatId: number, attempt: number): void;
  setupMediaPlaybackController(): void;
  showChatOpenFailure(): void;
  syncOwnedChatContext(): void;
}

export function isRouteContextCurrent(host: ChatRouteOwnershipCoordinatorPort, route: ChatScreenRouteParams): boolean {
    try {
      return host.routeContext === route && route.isCurrentAccount(getAppCoreRuntime().getStore()) &&
        !route.openLease.isReleased();
    } catch (_error) {
      return false;
    }
  }

export function bindChatRoute(host: ChatRouteOwnershipCoordinatorPort, params: ChatScreenRouteParams | undefined): void {
    if (!(params instanceof ChatScreenRouteParams) ||
      (host.routeContext !== undefined && host.routeContext !== params)) return;
    try {
      if (!params.isCurrentAccount(getAppCoreRuntime().getStore()) || params.openLease.isReleased() ||
        (host.routeAccountStore !== undefined && host.routeAccountStore !== params.accountStore)) return;
      host.routeContext = params;
      host.routeChatId = params.chatId;
      host.routeChatTitle = params.chatTitle;
      host.activateChatRoute();
    } catch (_error) {
      hilog.warn(DOMAIN, TAG, 'Chat route binding unavailable');
    }
  }

export function syncOwnedChatContext(host: ChatRouteOwnershipCoordinatorPort): void {
    const route = host.routeContext;
    if (route === undefined || !host.isRouteContextCurrent(route)) return;
    const ownedChatId = route.chatId;
    const ownedChatTitle = host.resolveOwnedChatTitle();

    host.activeChatId = ownedChatId;
    host.activeChatTitle = ownedChatTitle;

    // Local initialization of an underlying route must not reclaim globals
    // from a newer push, even when both pages display the same chat.
    if (navigationUIState.activeChatOwnerToken !== route.navigationToken) return;
    navigationUIState.activeChatId = ownedChatId;
    navigationUIState.activeChatTitle = ownedChatTitle;
    chatUIState.activeChatId = ownedChatId;
    chatUIState.activeChatTitle = ownedChatTitle;
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, ownedChatId);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, ownedChatTitle);
  }

export function ownsNavigationContext(host: ChatRouteOwnershipCoordinatorPort): boolean {
    const route = host.routeContext;
    return route !== undefined && host.isRouteContextCurrent(route) &&
      navigationUIState.activeChatOwnerToken === route.navigationToken;
  }

export function clearOwnedChatContext(host: ChatRouteOwnershipCoordinatorPort): void {
    // Only this route may retire its navigation slot, not another same-chat page.
    if (!host.ownsNavigationContext()) return;
    navigationUIState.activeChatOwnerToken = 0;
    navigationUIState.activeChatId = 0;
    navigationUIState.activeChatTitle = '';
    chatUIState.activeChatId = 0;
    chatUIState.activeChatTitle = '';
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, 0);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, '');
  }

export function resolveOwnedChatTitle(host: ChatRouteOwnershipCoordinatorPort): string {
    const route = host.routeContext;
    if (route === undefined || !host.isRouteContextCurrent(route)) return '';
    return route.chatTitle.length > 0 ? route.chatTitle
      : (route.accountStore.getState().chats.chats.get(route.chatId)?.title ?? '');
  }

export function showOwnedChatRoute(host: ChatRouteOwnershipCoordinatorPort): boolean {
    const route = host.routeContext;
    if (route === undefined || !host.isRouteContextCurrent(route)) return false;
    try {
      const stack = host.bindNavigationStack();
      // Ignore a delayed onShown if another destination has since become top.
      if (stack === undefined || stack.size() <= 0) return false;
      const top = stack.getParamByIndex(stack.size() - 1) as ChatScreenRouteParams | undefined;
      if (!(top instanceof ChatScreenRouteParams) || top.navigationToken !== route.navigationToken) return false;
      host.activateChatRoute();
      if (!host.routeActivated || !host.isRouteContextCurrent(route)) return false;
      navigationUIState.activeChatOwnerToken = route.navigationToken;
      host.syncOwnedChatContext();
      navigationUIState.chatScreenVisible = true;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
      // A retained route can regain ownership after another chat is popped.
      // Refresh its filtered snapshot and identity-owned registration on show.
      host.setupMediaPlaybackController();
      host.maybeMarkChatRead(route.accountStore.getState());
      return true;
    } catch (_error) {
      return false;
    }
  }

export function createChatRouteParams(host: ChatRouteOwnershipCoordinatorPort, chatId: number, chatTitle: string): ChatScreenRouteParams | undefined {
    const route = host.routeContext;
    if (route === undefined || !host.isRouteContextCurrent(route) || !Number.isSafeInteger(chatId) || chatId === 0) {
      return undefined;
    }
    return new ChatScreenRouteParams(chatId, chatTitle, route.accountStore, route.gateway);
  }

export function getChatRouteToken(host: ChatRouteOwnershipCoordinatorPort): number {
    const route = host.routeContext;
    return route !== undefined && host.isRouteContextCurrent(route) ? route.navigationToken : 0;
  }

export function startOwnedChatData(host: ChatRouteOwnershipCoordinatorPort, route: ChatScreenRouteParams): void {
    const history = host.loadChatHistoryUseCase;
    if (host.routeDataStarted || !history || !host.isRouteContextCurrent(route)) return;
    host.routeDataStarted = true;
    const lifecycle = host.pageLifecycleToken;
    const current = (): boolean => host.routeActivated && lifecycle === host.pageLifecycleToken &&
      host.loadChatHistoryUseCase === history && host.isRouteContextCurrent(route);
    route.openLease.ensureOpen(current).then((opened: boolean) => {
      if (!current()) return;
      if (!opened) {
        host.awaitingInitialTimeline = false;
        host.showChatOpenFailure();
        return;
      }
      const chat = route.accountStore.getState().chats.chats.get(route.chatId);
      host.captureInitialHistorySnapshot(route.accountStore.getState(), false);
      const peer = chat?.peerUserId ?? 0;
      const hydration = peer > 0 ? history.hydrateUsersIfMissing([peer]) : Promise.resolve(0);
      return hydration.catch((error: Object) => {
        hilog.info(DOMAIN, TAG, 'Route peer hydration skipped: %{public}s', String(error));
        return 0;
      }).then(() => {
        if (!current()) return;
        host.scheduleHistoryLoad(route.chatId, 0);
        host.maybeMarkChatRead(route.accountStore.getState());
      });
    }).catch((error: Object) => {
      if (!current()) return;
      host.awaitingInitialTimeline = false;
      host.showChatOpenFailure();
      hilog.warn(DOMAIN, TAG, 'Owned chat initialization failed: %{public}s', String(error));
    });
  }

export function showChatOpenFailure(host: ChatRouteOwnershipCoordinatorPort): void {
    if (!host.ownsNavigationContext()) return;
    try {
      host.getChatUIContext().getPromptAction().showToast({
        message: localized($r('app.string.chat_open_not_confirmed').id,
          'Chat opening was not confirmed. Go back and open the chat again.'),
        duration: 3000
      });
    } catch (_error) {
      hilog.warn(DOMAIN, TAG, 'Chat opening feedback unavailable');
    }
  }
