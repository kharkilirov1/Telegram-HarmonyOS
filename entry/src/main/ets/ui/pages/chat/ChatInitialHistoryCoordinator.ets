// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { AppState } from '../../../core/model/AppState';
import { AppError, AppErrorKind } from '../../../core/model/AppError';
import { AppStore } from '../../../core/store/AppStore';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { LoadChatHistoryUseCase, LoadChatHistoryParams } from '../../../domain/usecases/loadChatHistory';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const HISTORY_INITIAL_DELAY_MS = 600;
const HISTORY_MAX_RETRY_ATTEMPTS = 4;
const HISTORY_RETRY_BASE_DELAY_MS = 450;
const INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT = 1;

export interface ChatInitialHistoryCoordinatorPort {
  accountStore?: AppStore;
  activeChatId: number;
  awaitingInitialTimeline: boolean;
  dataSource: ChatTimelineDataSource;
  historyFallbackTimerId: number;
  initialHistoryFallbackRequested: boolean;
  initialHistoryParams?: LoadChatHistoryParams;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  pageLifecycleToken: number;
  routeActivated: boolean;
  routeContext?: ChatScreenRouteParams;
  stickyLastReadMessageId: string;
  buildInitialHistoryParams(chatId: number, state?: AppState): LoadChatHistoryParams;
  captureInitialHistorySnapshot(state: AppState, scheduleCorrection?: boolean): void;
  isRouteContextCurrent(route: ChatScreenRouteParams): boolean;
  requestHistoryWithRetry(chatId: number, attempt: number): void;
  scheduleHistoryLoad(chatId: number, attempt: number): void;
  shouldRetryHistoryLoad(chatId: number): boolean;
}

export function scheduleHistoryLoad(host: ChatInitialHistoryCoordinatorPort, chatId: number, attempt: number): void {
    const route = host.routeContext;
    if (route === undefined || !host.isRouteContextCurrent(route) || !route.openLease.isOpen()) return;
    if (host.historyFallbackTimerId >= 0) {
      clearTimeout(host.historyFallbackTimerId);
      host.historyFallbackTimerId = -1;
    }
    if (chatId === 0) {
      return;
    }
    const delayMs = attempt === 0
      ? HISTORY_INITIAL_DELAY_MS
      : HISTORY_RETRY_BASE_DELAY_MS * attempt;
    const lifecycleToken: number = host.pageLifecycleToken;
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (lifecycleToken !== host.pageLifecycleToken ||
        host.historyFallbackTimerId !== scheduledTimerId ||
        host.activeChatId !== chatId || !host.isRouteContextCurrent(route)) {
        return;
      }
      host.historyFallbackTimerId = -1;
      host.requestHistoryWithRetry(chatId, attempt);
    }, delayMs) as number;
    host.historyFallbackTimerId = scheduledTimerId;
  }

export function shouldRetryHistoryLoad(host: ChatInitialHistoryCoordinatorPort, chatId: number): boolean {
    if (!host.loadChatHistoryUseCase) {
      return false;
    }
    return host.loadChatHistoryUseCase.shouldRetry(chatId);
  }

export function shouldShowHistoryLoadingPlaceholder(host: ChatInitialHistoryCoordinatorPort): boolean {
    if (!host.awaitingInitialTimeline || host.activeChatId === 0) {
      return false;
    }
    const count = host.dataSource.totalCount();
    if (count >= INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT) {
      return false;
    }
    if (!host.loadChatHistoryUseCase) {
      return count === 0;
    }
    return host.loadChatHistoryUseCase.canLoadOlderMessages(host.activeChatId);
  }

export function requestHistoryWithRetry(host: ChatInitialHistoryCoordinatorPort, chatId: number, attempt: number): void {
    const historyUseCase = host.loadChatHistoryUseCase;
    const route = host.routeContext;
    if (!historyUseCase || chatId === 0 || host.activeChatId !== chatId ||
      route === undefined || !host.isRouteContextCurrent(route) || !route.openLease.isOpen()) {
      return;
    }
    host.captureInitialHistorySnapshot(route.accountStore.getState(), false);
    if (historyUseCase.isLoading(chatId, 'initial')) {
      return;
    }
    const effectiveAttempt = host.initialHistoryFallbackRequested &&
      host.initialHistoryParams?.reason === 'aroundUnread' ? 0 : attempt;
    if (effectiveAttempt > 0 && historyUseCase.hasHistoryBeenFetched(chatId)) {
      return;
    }

    const params = host.buildInitialHistoryParams(chatId);
    // Missing chat may use the bounded default loader, but never seals a snapshot.
    // A real around-unread request consumes the correction even if it later fails.
    host.initialHistoryFallbackRequested = host.initialHistoryParams === undefined;
    const lifecycleToken: number = host.pageLifecycleToken;
    // execute reserves synchronously before its first await; a skipped load owns no new identity.
    // The existing sequence survives completion, fencing even a completed newer request.
    const previousRequestIdentity = historyUseCase.captureRequestIdentity(chatId, 'initial');
    const historyRequest = historyUseCase.execute(params);
    const requestIdentity = historyUseCase.captureRequestIdentity(chatId, 'initial');
    historyRequest
      .then(() => {
        if (lifecycleToken !== host.pageLifecycleToken ||
          host.loadChatHistoryUseCase !== historyUseCase ||
          host.activeChatId !== chatId || !host.isRouteContextCurrent(route)) {
          return;
        }
        if (requestIdentity === '' || requestIdentity === previousRequestIdentity ||
          !historyUseCase.isRequestIdentityCurrent(chatId, 'initial', requestIdentity)) {
          return;
        }
        if (host.initialHistoryFallbackRequested && host.initialHistoryParams?.reason === 'aroundUnread') {
          host.scheduleHistoryLoad(chatId, 0);
          return;
        }
        if (host.shouldRetryHistoryLoad(chatId) &&
          effectiveAttempt + 1 < HISTORY_MAX_RETRY_ATTEMPTS &&
          host.activeChatId === chatId) {
          host.scheduleHistoryLoad(chatId, effectiveAttempt + 1);
        }
      })
      .catch((error: Object) => {
        if (lifecycleToken !== host.pageLifecycleToken ||
          host.loadChatHistoryUseCase !== historyUseCase ||
          host.activeChatId !== chatId || !host.isRouteContextCurrent(route)) {
          return;
        }
        if (requestIdentity === '' || requestIdentity === previousRequestIdentity ||
          !historyUseCase.isRequestIdentityCurrent(chatId, 'initial', requestIdentity)) {
          return;
        }
        hilog.warn(DOMAIN, TAG, 'history load attempt %{public}d failed: %{public}s',
          effectiveAttempt + 1, String(error));
        if (error instanceof AppError && (!error.retryable || error.kind === AppErrorKind.AUTH ||
          error.kind === AppErrorKind.RATE_LIMIT)) {
          host.initialHistoryFallbackRequested = false;
          if (host.historyFallbackTimerId >= 0) {
            clearTimeout(host.historyFallbackTimerId);
            host.historyFallbackTimerId = -1;
          }
          return;
        }
        if (host.initialHistoryFallbackRequested && host.initialHistoryParams?.reason === 'aroundUnread') {
          host.scheduleHistoryLoad(chatId, 0);
          return;
        }
        if (host.shouldRetryHistoryLoad(chatId) &&
          effectiveAttempt + 1 < HISTORY_MAX_RETRY_ATTEMPTS &&
          host.activeChatId === chatId) {
          host.scheduleHistoryLoad(chatId, effectiveAttempt + 1);
        }
      });
  }

export function captureInitialHistorySnapshot(host: ChatInitialHistoryCoordinatorPort, state: AppState, scheduleCorrection: boolean = true): void {
    const route = host.routeContext;
    if (host.initialHistoryParams !== undefined || !host.routeActivated ||
      route === undefined || !host.isRouteContextCurrent(route)) return;
    const chat = state.chats.chats.get(route.chatId);
    if (route.entryUnreadCount === undefined && chat === undefined) return;
    host.initialHistoryParams = host.buildInitialHistoryParams(route.chatId, state);
    if (route.entryUnreadCount === undefined && chat !== undefined) {
      host.stickyLastReadMessageId = chat.unreadCount > 0 ? chat.lastReadInboxMessageId : '';
    }
    if (scheduleCorrection && host.initialHistoryFallbackRequested &&
      host.initialHistoryParams.reason === 'aroundUnread' && route.openLease.isOpen()) {
      host.scheduleHistoryLoad(route.chatId, 0);
    }
  }

export function buildInitialHistoryParams(host: ChatInitialHistoryCoordinatorPort, chatId: number, state?: AppState): LoadChatHistoryParams {
    if (host.initialHistoryParams?.chatId === chatId) return host.initialHistoryParams;
    const params = new LoadChatHistoryParams();
    params.chatId = chatId;
    params.limit = 50;
    params.direction = 'initial';
    params.reason = 'default';
    const route = host.routeContext;
    const chat = (state ?? host.accountStore?.getState())?.chats.chats.get(chatId);
    const unread = route?.entryUnreadCount ?? chat?.unreadCount ?? 0;
    const boundary = route?.entryLastReadInboxMessageId ?? chat?.lastReadInboxMessageId ?? '0';
    // Preserve OpenChatUseCase's around-unread contract after moving acquisition
    // out of the three callers. A cached latest page must not bypass this request.
    if (unread > 0 && boundary !== '0' && (!chat?.lastMessage || chat.lastMessage.id !== boundary)) {
      params.fromMessageId = boundary;
      params.offset = -10;
      params.limit = 60;
      params.reason = 'aroundUnread';
    }
    return params;
  }
