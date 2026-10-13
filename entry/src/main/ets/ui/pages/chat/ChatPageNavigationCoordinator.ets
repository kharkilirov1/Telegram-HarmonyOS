// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { chatUIState, navigationUIState } from '../../../core/model/UIStateModels';
import { ProfileRouteParams } from '../profile/TgProfilePage';
import { ProfileLoadContext } from '../../../domain/usecases/loadProfileInfo';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiObserver } from '@kit.ArkUI';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const CHAT_NAV_TRANSITION_LOCK_MS = 760;

export interface ChatPageNavigationCoordinatorPort {
  activeChatId: number;
  isClosing: boolean;
  pageStack: NavPathStack;
  pinnedMessagesListVisible: boolean;
  routeContext?: ChatScreenRouteParams;
  bindNavigationStack(): NavPathStack | undefined;
  clearOwnedChatContext(): void;
  isRouteContextCurrent(route: ChatScreenRouteParams): boolean;
  ownsNavigationContext(): boolean;
  saveScrollPosition(): void;
  setPinnedMessagesListVisible(visible: boolean): void;
  queryNavigationInfo(): uiObserver.NavigationInfo | undefined;
}

export function openProfile(host: ChatPageNavigationCoordinatorPort): void {
    if (host.activeChatId === 0 || !host.ownsNavigationContext()) return; // groups/channels have negative ids
    const route = host.routeContext;
    if (route === undefined || route.chatId !== host.activeChatId || !host.isRouteContextCurrent(route)) return;
    hilog.info(DOMAIN, TAG, 'openProfile chatId=%{public}d', host.activeChatId);
    const navStack: NavPathStack | undefined = host.bindNavigationStack();
    if (navStack === undefined) {
      hilog.error(DOMAIN, TAG, 'Navigation stack unavailable for profile page');
      return;
    }
    // Stack lookup can invoke callbacks; revalidate before preserving push ownership.
    if (!host.ownsNavigationContext() || host.routeContext !== route || !host.isRouteContextCurrent(route)) return;
    const params = new ProfileRouteParams(host.activeChatId, 0, new ProfileLoadContext(route.accountStore, route.gateway));
    try {
      navStack.pushPathByName('TgProfilePage', params);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to push profile page: %{public}s', String(error));
    }
  }

export function handleBackPress(host: ChatPageNavigationCoordinatorPort): void {
    hilog.info(DOMAIN, TAG, 'handleBackPress called');
    if (!host.ownsNavigationContext()) return;
    if (host.pinnedMessagesListVisible) {
      host.setPinnedMessagesListVisible(false);
      return;
    }
    if (host.isClosing) {
      hilog.warn(DOMAIN, TAG, 'Ignoring duplicate chat screen back pop while closing');
      return;
    }
    const navStack: NavPathStack | undefined = host.bindNavigationStack();
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
    const prevNavigationOwner = navigationUIState.activeChatOwnerToken;
    const prevChatScreenVisible: boolean = navigationUIState.chatScreenVisible;
    const prevNavigationChatId: number = navigationUIState.activeChatId;
    const prevNavigationTitle: string = navigationUIState.activeChatTitle;
    const prevChatStateId: number = chatUIState.activeChatId;
    const prevChatStateTitle: string = chatUIState.activeChatTitle;
    const prevStoredChatId: number = AppStorage.get<number>(StorageKeys.ACTIVE_CHAT_ID) ?? prevNavigationChatId;
    const prevStoredTitle: string = AppStorage.get<string>(StorageKeys.ACTIVE_CHAT_TITLE) ?? prevNavigationTitle;

    host.saveScrollPosition();
    host.isClosing = true;
    const navLockUntil = Date.now() + CHAT_NAV_TRANSITION_LOCK_MS;
    navigationUIState.chatNavLockUntil = navLockUntil;
    AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, navLockUntil);
    navigationUIState.chatScreenVisible = false;
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    host.clearOwnedChatContext();

    try {
      hilog.info(DOMAIN, TAG, 'Popping from pageStack');
      navStack.pop();
    } catch (error) {
      host.isClosing = false;
      const route = host.routeContext;
      // A failed pop may have triggered another navigation/account change.
      // Restore only the slot we cleared, never a replacement route's state.
      if (route === undefined || !host.isRouteContextCurrent(route) ||
        navigationUIState.activeChatOwnerToken !== 0) return;
      navigationUIState.activeChatOwnerToken = prevNavigationOwner;
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

export function bindNavigationStack(host: ChatPageNavigationCoordinatorPort): NavPathStack | undefined {
    try {
      const navigationInfo: uiObserver.NavigationInfo | undefined = host.queryNavigationInfo();
      if (navigationInfo !== undefined) {
        host.pageStack = navigationInfo.pathStack;
      }
    } catch (_error) {
    }
    return host.pageStack;
  }
