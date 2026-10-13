// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { LoadChatHistoryUseCase } from '../../../domain/usecases/loadChatHistory';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatScrollPositionCache } from './ChatScrollPositionCache';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const PROGRAMMATIC_SCROLL_GUARD_MS = 320;
const TIMELINE_TOP_EDGE_TRIGGER_INDEX = 25;
const TIMELINE_BOTTOM_EDGE_TRIGGER_GAP = 5;
const TIMELINE_TOUCH_UNLOCK_DISTANCE = 12;

export interface ChatTimelineViewportCoordinatorPort {
  activeChatId: number;
  awaitingInitialTimeline: boolean;
  blockAutoPaginationUntilUserScroll: boolean;
  currentScrollChatId: number;
  dataSource: ChatTimelineDataSource;
  isApplyingTimelineDiff: boolean;
  isLoadingNewer: boolean;
  isLoadingOlder: boolean;
  lastVisibleStartIndex: number;
  listInitialIndex: number;
  listScroller: Scroller;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  pageLifecycleToken: number;
  paginationRecheckTimerId: number;
  rebuildScheduled: boolean;
  scrollToBottomUnreadCount: number;
  showScrollToBottom: boolean;
  suppressLoadOlderUntil: number;
  timelineTouchStartY: number;
  unreadRestoreIndex: number;
  armAutoPaginationUnlock(targetIndex: number, reason: string): void;
  guardProgrammaticScroll(durationMs?: number): void;
  jumpToMessageId(messageId: string): void;
  recheckPaginationEdge(): void;
  scheduleLifecycleTask(delayMs: number, task: () => void): void;
  schedulePaginationRecheck(delayMs?: number): void;
  scrollTimelineToBottomAligned(): void;
}

export function refreshScrollToBottomVisibility(host: ChatTimelineViewportCoordinatorPort, endIndex: number): void {
    const total = host.dataSource.totalCount();
    if (total === 0) {
      host.showScrollToBottom = false;
      host.scrollToBottomUnreadCount = 0;
      return;
    }
    const nearBottom = total - 1 - endIndex <= 3;
    const midHistory = host.loadChatHistoryUseCase !== undefined &&
      host.loadChatHistoryUseCase.canLoadNewerMessages(host.activeChatId);
    host.showScrollToBottom = !nearBottom || midHistory;
    if (!host.showScrollToBottom) {
      host.scrollToBottomUnreadCount = 0;
    }
  }

export function handleScrollToBottomPress(host: ChatTimelineViewportCoordinatorPort): void {
    host.scrollToBottomUnreadCount = 0;
    const useCase = host.loadChatHistoryUseCase;
    if (useCase && useCase.canLoadNewerMessages(host.activeChatId)) {
      // Mid-history window (after a jump): go straight to the chat's last
      // message instead of paging every window in between
      try {
        const state = getAppCoreRuntime().getStore().getState();
        const chat = state.chats.chats.get(host.activeChatId);
        if (chat && chat.lastMessage && chat.lastMessage.id !== '0') {
          host.jumpToMessageId(chat.lastMessage.id);
          return;
        }
      } catch (_e) {
      }
    }
    host.scrollTimelineToBottomAligned();
  }

export function computeInitialIndex(host: ChatTimelineViewportCoordinatorPort, totalCount: number): void {
    if (totalCount <= 0) {
      host.listInitialIndex = 0;
      return;
    }

    const chatId = host.activeChatId;

    // Priority 1: unread boundary
    if (host.unreadRestoreIndex >= 0 && host.unreadRestoreIndex < totalCount) {
      // Anchor the semantic marker itself. The preceding date key can remain
      // at the start of the day while same-day history prepends above it.
      const targetIndex = host.unreadRestoreIndex;
      host.listInitialIndex = targetIndex;
      hilog.info(DOMAIN, TAG, 'initialIndex set to unread boundary %{public}d for chat %{public}d',
        targetIndex, chatId);
      return;
    }

    // Priority 2: saved scroll position
    const savedKey = ChatScrollPositionCache.positions.get(chatId);
    if (savedKey !== undefined) {
      const savedIndex = host.dataSource.findIndexByKey(savedKey);
      if (savedIndex >= 0) {
        host.listInitialIndex = savedIndex;
        hilog.info(DOMAIN, TAG, 'initialIndex set to saved key=%{public}s index=%{public}d for chat %{public}d',
          savedKey, savedIndex, chatId);
        return;
      }
    }

    // Priority 3: bottom (newest messages)
    host.listInitialIndex = totalCount - 1;
    hilog.info(DOMAIN, TAG, 'initialIndex set to bottom %{public}d for chat %{public}d',
      host.listInitialIndex, chatId);
  }

export function guardProgrammaticScroll(host: ChatTimelineViewportCoordinatorPort, durationMs: number = PROGRAMMATIC_SCROLL_GUARD_MS): void {
    const guardUntil = Date.now() + durationMs;
    if (guardUntil > host.suppressLoadOlderUntil) {
      host.suppressLoadOlderUntil = guardUntil;
    }
  }

export function resetPaginationState(host: ChatTimelineViewportCoordinatorPort): void {
    host.isLoadingOlder = false;
    host.isLoadingNewer = false;
  }

export function isNearTopPaginationEdge(host: ChatTimelineViewportCoordinatorPort, start: number): boolean {
    return start < TIMELINE_TOP_EDGE_TRIGGER_INDEX;
  }

export function isNearBottomPaginationEdge(host: ChatTimelineViewportCoordinatorPort, end: number, totalCount: number): boolean {
    return totalCount > 0 && end >= totalCount - TIMELINE_BOTTOM_EDGE_TRIGGER_GAP;
  }

export function armAutoPaginationUnlock(host: ChatTimelineViewportCoordinatorPort, targetIndex: number, reason: string): void {
    if (targetIndex >= TIMELINE_TOP_EDGE_TRIGGER_INDEX) {
      return;
    }
    host.blockAutoPaginationUntilUserScroll = true;
    host.guardProgrammaticScroll(PROGRAMMATIC_SCROLL_GUARD_MS * 2);
    hilog.info(DOMAIN, TAG,
      'Blocking auto pagination after programmatic restore to %{public}d (%{public}s)',
      targetIndex, reason);
  }

export function maybeUnlockAutoPagination(host: ChatTimelineViewportCoordinatorPort, scrollOffset: number, scrollState: ScrollState): void {
    if (host.isApplyingTimelineDiff) {
      return;
    }
    if (!host.blockAutoPaginationUntilUserScroll) {
      return;
    }
    if (scrollState === ScrollState.Idle || Math.abs(scrollOffset) < 0.5) {
      return;
    }
    host.blockAutoPaginationUntilUserScroll = false;
    hilog.info(DOMAIN, TAG,
      'Auto pagination unlocked by user scroll: state=%{public}d offset=%{public}s',
      scrollState, scrollOffset.toString());
  }

export function handleTimelineTouch(host: ChatTimelineViewportCoordinatorPort, event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    const touchY = event.touches[0].y;
    if (event.type === TouchType.Down) {
      host.timelineTouchStartY = touchY;
      return;
    }
    if (event.type !== TouchType.Move) {
      return;
    }
    if (!host.blockAutoPaginationUntilUserScroll || host.isApplyingTimelineDiff) {
      return;
    }
    if (host.timelineTouchStartY < 0 ||
      Math.abs(touchY - host.timelineTouchStartY) < TIMELINE_TOUCH_UNLOCK_DISTANCE) {
      return;
    }
    host.blockAutoPaginationUntilUserScroll = false;
    hilog.info(DOMAIN, TAG, 'Auto pagination unlocked by touch drag at edge');
    host.schedulePaginationRecheck(0);
  }

export function shouldSuppressLoadOlder(host: ChatTimelineViewportCoordinatorPort): boolean {
    return Date.now() < host.suppressLoadOlderUntil;
  }

export function schedulePaginationRecheck(host: ChatTimelineViewportCoordinatorPort, delayMs: number = 0): void {
    if (host.paginationRecheckTimerId >= 0) {
      clearTimeout(host.paginationRecheckTimerId);
    }
    const lifecycleToken: number = host.pageLifecycleToken;
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (lifecycleToken !== host.pageLifecycleToken || host.paginationRecheckTimerId !== scheduledTimerId) {
        return;
      }
      host.paginationRecheckTimerId = -1;
      if (host.rebuildScheduled || host.isApplyingTimelineDiff) {
        host.schedulePaginationRecheck(16);
        return;
      }
      host.recheckPaginationEdge();
    }, delayMs) as number;
    host.paginationRecheckTimerId = scheduledTimerId;
  }

export function saveScrollPosition(host: ChatTimelineViewportCoordinatorPort): void {
    const chatId = host.currentScrollChatId;
    const idx = host.lastVisibleStartIndex;
    if (chatId !== 0 && idx >= 0 && idx < host.dataSource.totalCount()) {
      const key = host.dataSource.getData(idx).key;
      ChatScrollPositionCache.positions.set(chatId, key);
      hilog.info(DOMAIN, TAG, 'Saved scroll position key=%{public}s idx=%{public}d for chat %{public}d',
        key, idx, chatId);
    }
  }

export function restoreScrollPosition(host: ChatTimelineViewportCoordinatorPort): void {
    const chatId = host.activeChatId;
    const totalCount = host.dataSource.totalCount();
    if (totalCount === 0) {
      return;
    }
    host.guardProgrammaticScroll();

    const wasAwaiting = host.awaitingInitialTimeline;

    // With initialIndex set by computeInitialIndex(), the List is born at
    // the correct position. For unread/saved positions that are NOT the
    // bottom, we still need a scrollToIndex for sub-item alignment (START).
    // For bottom (default), initialIndex alone is sufficient — no scroll needed.
    const needsExplicitScroll = host.listInitialIndex < totalCount - 1;

    if (wasAwaiting) {
      // Release placeholder — List will be created with initialIndex already set.
      // No prependScrollMask needed: List starts at the right position natively.
      host.awaitingInitialTimeline = false;

      if (needsExplicitScroll) {
        // For unread/saved: refine alignment after List renders (one frame).
        const targetIndex = host.listInitialIndex;
        host.armAutoPaginationUnlock(targetIndex, 'initialRestore');
        host.lastVisibleStartIndex = targetIndex;
        host.scheduleLifecycleTask(16, () => {
          host.guardProgrammaticScroll();
          host.listScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
          // After guard expires, check if near edge → trigger pagination
          host.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
        });
      } else {
        // Re-align after List creation so the last item attaches to the
        // viewport edge already shortened by composerTotalHeight.
        host.scheduleLifecycleTask(16, () => {
          host.scrollTimelineToBottomAligned();
        });
        host.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
      }
    } else {
      // List already visible (chat switch without re-creation).
      if (needsExplicitScroll) {
        const targetIndex = host.listInitialIndex;
        host.armAutoPaginationUnlock(targetIndex, 'switchRestore');
        host.lastVisibleStartIndex = targetIndex;
        host.scheduleLifecycleTask(16, () => {
          host.guardProgrammaticScroll();
          host.listScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
          host.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
        });
      } else {
        host.scheduleLifecycleTask(16, () => {
          host.scrollTimelineToBottomAligned();
        });
        host.schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50);
      }
    }
  }

export function isNearBottom(host: ChatTimelineViewportCoordinatorPort): boolean {
    const total = host.dataSource.totalCount();
    if (total === 0) {
      return true;
    }
    // Consider "near bottom" if last visible index is within 3 items of the end
    return host.lastVisibleStartIndex < 0 || (total - host.lastVisibleStartIndex) < 15;
  }
