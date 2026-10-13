// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { navigationUIState } from '../../../core/model/UIStateModels';
import { AppState } from '../../../core/model/AppState';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { LoadChatHistoryUseCase, LoadChatHistoryParams } from '../../../domain/usecases/loadChatHistory';
import { MarkChatReadUseCase } from '../../../domain/usecases/markChatRead';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const PROGRAMMATIC_SCROLL_GUARD_MS = 320;

export interface ChatTimelinePaginationCoordinatorPort {
  activeChatId: number;
  blockAutoPaginationUntilUserScroll: boolean;
  dataSource: ChatTimelineDataSource;
  initialHistoryParams?: LoadChatHistoryParams;
  isApplyingTimelineDiff: boolean;
  isLoadingNewer: boolean;
  isLoadingOlder: boolean;
  isMarkingChatRead: boolean;
  lastMarkReadRequestKey: string;
  lastVisibleEndIndex: number;
  lastVisibleStartIndex: number;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  markChatReadUseCase?: MarkChatReadUseCase;
  pageLifecycleToken: number;
  rebuildScheduled: boolean;
  routeContext?: ChatScreenRouteParams;
  captureInitialHistorySnapshot(state: AppState, scheduleCorrection?: boolean): void;
  isNearBottomPaginationEdge(end: number, totalCount: number): boolean;
  isNearTopPaginationEdge(start: number): boolean;
  loadNewerMessages(): void;
  loadOlderMessages(): void;
  ownsNavigationContext(): boolean;
  schedulePaginationRecheck(delayMs?: number): void;
  shouldSuppressLoadOlder(): boolean;
}

export function loadOlderMessages(host: ChatTimelinePaginationCoordinatorPort): void {
    const chatId = host.activeChatId;
    const useCase = host.loadChatHistoryUseCase;
    if (!useCase || chatId === 0 || host.isLoadingOlder) {
      return;
    }
    if (!useCase.canLoadOlderMessages(chatId)) {
      return;
    }
    const oldestId = useCase.getOldestMessageId(chatId);
    if (oldestId === '0') {
      return;
    }

    host.isLoadingOlder = true;
    hilog.info(DOMAIN, TAG, 'Loading older messages for chat %{public}d from %{public}s', chatId, oldestId);

    const params = new LoadChatHistoryParams();
    params.chatId = chatId;
    params.fromMessageId = oldestId;
    params.limit = 50;
    params.direction = 'older';
    params.reason = 'default';

    const lifecycleToken: number = host.pageLifecycleToken;
    useCase.execute(params)
      .catch((_: Error) => {})
      .finally(() => {
        if (lifecycleToken !== host.pageLifecycleToken ||
          host.loadChatHistoryUseCase !== useCase ||
          host.activeChatId !== chatId) {
          return;
        }
        host.isLoadingOlder = false;
        host.schedulePaginationRecheck();
      });
  }

export function recheckPaginationEdge(host: ChatTimelinePaginationCoordinatorPort): void {
    if (host.rebuildScheduled || host.isApplyingTimelineDiff) {
      return;
    }
    // Respect the cascade block — if prepend compensation just fired,
    // do NOT trigger another load until the user actually scrolls.
    if (host.blockAutoPaginationUntilUserScroll) {
      return;
    }
    if (host.shouldSuppressLoadOlder()) {
      // Suppress-окно временное — не бросаем перепроверку, а откладываем её,
      // иначе на статичном крае onScrollIndex больше не стрельнёт.
      host.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS / 2);
      return;
    }
    const start = host.lastVisibleStartIndex;
    const end = host.lastVisibleEndIndex;
    if (start < 0 || end < 0) {
      return;
    }
    const totalCount = host.dataSource.totalCount();

    if (host.isNearTopPaginationEdge(start) && !host.isLoadingOlder) {
      host.loadOlderMessages();
    }
    if (host.isNearBottomPaginationEdge(end, totalCount) && !host.isLoadingNewer) {
      host.loadNewerMessages();
    }
  }

export function loadNewerMessages(host: ChatTimelinePaginationCoordinatorPort): void {
    const chatId = host.activeChatId;
    const useCase = host.loadChatHistoryUseCase;
    if (!useCase || chatId === 0 || host.isLoadingNewer) {
      return;
    }
    if (!useCase.canLoadNewerMessages(chatId)) {
      return;
    }

    const newestId = useCase.getNewestMessageId(chatId);
    if (newestId === '0') {
      return;
    }

    host.isLoadingNewer = true;
    hilog.info(DOMAIN, TAG, 'Loading newer messages for chat %{public}d from %{public}s', chatId, newestId);

    const params = new LoadChatHistoryParams();
    params.chatId = chatId;
    params.fromMessageId = newestId;
    params.offset = -49;
    params.limit = 50;
    params.direction = 'newer';
    params.reason = 'default';

    const lifecycleToken: number = host.pageLifecycleToken;
    useCase.execute(params)
      .catch((_: Error) => {})
      .finally(() => {
        if (lifecycleToken !== host.pageLifecycleToken ||
          host.loadChatHistoryUseCase !== useCase ||
          host.activeChatId !== chatId) {
          return;
        }
        host.isLoadingNewer = false;
        host.schedulePaginationRecheck();
      });
  }

export function maybeMarkChatRead(host: ChatTimelinePaginationCoordinatorPort, state: AppState): void {
    host.captureInitialHistorySnapshot(state);
    const chatId = host.activeChatId;
    const useCase = host.markChatReadUseCase;
    if (chatId === 0 || !useCase || host.isMarkingChatRead ||
      host.initialHistoryParams === undefined ||
      host.routeContext?.openLease.isOpen() !== true || !host.ownsNavigationContext() ||
      !navigationUIState.chatScreenVisible) {
      return;
    }

    const chat = state.chats.chats.get(chatId);
    if (!chat || chat.unreadCount <= 0) {
      host.lastMarkReadRequestKey = '';
      return;
    }

    const requestKey = chatId.toString() + ':' + chat.unreadCount.toString() + ':' + chat.lastReadInboxMessageId;
    if (host.lastMarkReadRequestKey === requestKey) {
      return;
    }

    host.lastMarkReadRequestKey = requestKey;
    host.isMarkingChatRead = true;
    const lifecycleToken: number = host.pageLifecycleToken;
    useCase.execute({ chatId: chatId })
      .catch((error: Object) => {
        if (lifecycleToken !== host.pageLifecycleToken ||
          host.markChatReadUseCase !== useCase ||
          host.activeChatId !== chatId) {
          return;
        }
        hilog.warn(DOMAIN, TAG, 'markChatRead failed for %{public}d: %{public}s', chatId, String(error));
        if (host.activeChatId === chatId && host.lastMarkReadRequestKey === requestKey) {
          host.lastMarkReadRequestKey = '';
        }
      })
      .finally(() => {
        if (lifecycleToken !== host.pageLifecycleToken ||
          host.markChatReadUseCase !== useCase ||
          host.activeChatId !== chatId) {
          return;
        }
        host.isMarkingChatRead = false;
      });
  }
