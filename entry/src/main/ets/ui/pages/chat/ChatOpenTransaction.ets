// Shared chat-screen route transaction.
//
// Every entry point that opens a chat (chat list, Saved Messages from Settings) must write the same
// navigation/chat state and roll it back if the push throws, otherwise the app keeps a stale
// "active chat" and the next tap is swallowed by the navigation lock. The page-local guards
// (lifecycle token, duplicate taps, search deactivation) stay in the page; only the state writes and
// the push live here.

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { navigationUIState, chatUIState } from '../../../core/model/UIStateModels';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { AppStore } from '../../../core/store/AppStore';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0035;
const TAG = 'ChatOpenTransaction';

export const CHAT_NAV_TRANSITION_LOCK_MS: number = 760;
export const CHAT_SCREEN_ROUTE_NAME: string = 'TgChatScreenPage';

function readStoredChatId(fallback: number): number {
  return AppStorage.get<number>(StorageKeys.ACTIVE_CHAT_ID) ?? fallback;
}

function readStoredChatTitle(fallback: string): string {
  return AppStorage.get<string>(StorageKeys.ACTIVE_CHAT_TITLE) ?? fallback;
}

// Pushes the chat screen and returns true when the navigation state was committed. On a throwing push
// the previous state is restored (only if nobody else already owns the navigation slot).
export function pushChatScreenRoute(params: ChatScreenRouteParams, navStack: NavPathStack,
  currentStore: AppStore): boolean {
  if (params.chatId === 0 || !params.isCurrentAccount(currentStore)) {
    return false;
  }

  const prevOwnerToken: number = navigationUIState.activeChatOwnerToken;
  const prevChatId: number = navigationUIState.activeChatId;
  const prevTitle: string = navigationUIState.activeChatTitle;
  const prevVisible: boolean = navigationUIState.chatScreenVisible;
  const prevLockUntil: number = navigationUIState.chatNavLockUntil;
  const prevStoredChatId: number = readStoredChatId(prevChatId);
  const prevStoredTitle: string = readStoredChatTitle(prevTitle);

  navigationUIState.activeChatOwnerToken = params.navigationToken;
  navigationUIState.activeChatId = params.chatId;
  navigationUIState.activeChatTitle = params.chatTitle;

  try {
    const nextNavLockUntil = Date.now() + CHAT_NAV_TRANSITION_LOCK_MS;
    navigationUIState.chatNavLockUntil = nextNavLockUntil;
    AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, nextNavLockUntil);
    chatUIState.activeChatId = params.chatId;
    chatUIState.activeChatTitle = params.chatTitle;
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, params.chatId);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, params.chatTitle);
    navigationUIState.chatScreenVisible = true;
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
    navStack.pushPathByName(CHAT_SCREEN_ROUTE_NAME, params);
    return true;
  } catch (error) {
    if (navigationUIState.activeChatOwnerToken === params.navigationToken &&
      params.isCurrentAccount(currentStore)) {
      navigationUIState.activeChatOwnerToken = prevOwnerToken;
      navigationUIState.activeChatId = prevChatId;
      navigationUIState.activeChatTitle = prevTitle;
      navigationUIState.chatNavLockUntil = prevLockUntil;
      chatUIState.activeChatId = prevChatId;
      chatUIState.activeChatTitle = prevTitle;
      AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, prevLockUntil);
      AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, prevStoredChatId);
      AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, prevStoredTitle);
      navigationUIState.chatScreenVisible = prevVisible;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, prevVisible);
    }
    hilog.error(DOMAIN, TAG, 'Failed to push chat screen: %{public}s', String(error));
    return false;
  }
}
