// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { chatUIState, navigationUIState } from '../../../core/model/UIStateModels';
import { AppState } from '../../../core/model/AppState';
import { TgChatTopBarSubtitleMode, TgChatTopBarTrailingAction } from '../../tg_ui/atoms/TgChatTopBar';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO, buildChatTimeline } from './ChatTimelineVO';
import { PendingMediaOpenIntent } from './PendingMediaOpenIntent';
import { LoadChatHistoryUseCase } from '../../../domain/usecases/loadChatHistory';
import { localized } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT = 1;
// Matches the visible-end policy in refreshScrollToBottomVisibility.
const TIMELINE_BOTTOM_VISIBLE_GAP = 3;

export interface ChatTimelineTransactionCoordinatorPort {
  activeAudioMessageId: string;
  activeChatId: number;
  activeChatIsChannel: boolean;
  activeChatTitle: string;
  activeVoiceMessageId: string;
  awaitingInitialTimeline: boolean;
  blockAutoPaginationUntilUserScroll: boolean;
  chatAvatarColorIndex: number;
  chatAvatarImageSrc: string;
  chatAvatarInitials: string;
  chatIsOnline: boolean;
  chatSubtitle: string;
  chatSubtitleMode: TgChatTopBarSubtitleMode;
  chatTopBarTrailingAction: TgChatTopBarTrailingAction;
  dataSource: ChatTimelineDataSource;
  hasRestoredUnreadBoundary: boolean;
  isApplyingTimelineDiff: boolean;
  lastVisibleEndIndex: number;
  lastVisibleStartIndex: number;
  listInitialIndex: number;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  locallyListenedVoiceIds: Set<string>;
  needsScrollRestore: boolean;
  pendingMediaOpenIntent: PendingMediaOpenIntent;
  previousDataCount: number;
  routeChatId: number;
  routeChatTitle: string;
  scrollToBottomUnreadCount: number;
  stickyLastReadMessageId: string;
  title: string;
  unreadRestoreIndex: number;
  clearPendingMediaDownloads(): void;
  computeInitialIndex(totalCount: number): void;
  fulfillPendingJump(): void;
  fulfillPendingMediaOpenIntent(entries: ChatTimelineEntryVO[]): void;
  guardProgrammaticScroll(durationMs?: number): void;
  isNearBottom(): boolean;
  refreshBotMenuState(state: AppState): void;
  refreshOpenMediaGalleryItems(): void;
  refreshRestoredReplySnippet(state: AppState): void;
  refreshScrollToBottomVisibility(endIndex: number): void;
  resetBotMenuState(): void;
  restoreScrollPosition(): void;
  scheduleLifecycleTask(delayMs: number, task: () => void): void;
  scheduleMissingReplyHydration(state: AppState): void;
  scrollTimelineToBottomAligned(): void;
  syncResolvedPendingDownloads(entries: ChatTimelineEntryVO[]): void;
  updateChatTopBarData(state: AppState): void;
}

export function rebuildTimeline(host: ChatTimelineTransactionCoordinatorPort, state: AppState): void {
    if (host.activeChatId === 0) {
      host.resetBotMenuState();
      host.activeChatIsChannel = false;
      host.dataSource.applyDiff([]);
      host.title = host.activeChatTitle.length > 0
        ? host.activeChatTitle
        : localized($r('app.string.chats_title').id, 'Chat');
      host.chatSubtitle = '';
      host.chatSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
      host.chatAvatarInitials = '';
      host.chatAvatarColorIndex = 0;
      host.chatAvatarImageSrc = '';
      host.chatIsOnline = false;
      host.chatTopBarTrailingAction = TgChatTopBarTrailingAction.Search;
      host.awaitingInitialTimeline = false;

      host.clearPendingMediaDownloads();
      host.pendingMediaOpenIntent.reset();
      return;
    }

    const result = buildChatTimeline(host.activeChatId, state, host.stickyLastReadMessageId);
    const chat = state.chats.chats.get(host.activeChatId);
    host.activeChatIsChannel = chat?.type === 'channel';
    if (chat && chat.unreadCount > host.scrollToBottomUnreadCount) {
      // Preserve the latest unread count while markChatRead updates TDLib.
      // It is cleared only after the viewport reaches the true bottom.
      host.scrollToBottomUnreadCount = chat.unreadCount;
    }
    const resolvedTitle = result.chatTitle.length > 0 ? result.chatTitle : host.activeChatTitle;
    host.title = resolvedTitle.length > 0 ? resolvedTitle : localized($r('app.string.chats_title').id, 'Chat');
    if (result.chatTitle.length > 0) {
      host.activeChatTitle = result.chatTitle;
      if (host.routeChatId === host.activeChatId) {
        host.routeChatTitle = result.chatTitle;
      }
      if (navigationUIState.activeChatId === host.activeChatId) {
        navigationUIState.activeChatTitle = result.chatTitle;
        chatUIState.activeChatTitle = result.chatTitle;
        AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, result.chatTitle);
      }
    }
    host.updateChatTopBarData(state);
    host.refreshBotMenuState(state);
    host.unreadRestoreIndex = result.unreadEntryIndex;
    const prevCount = host.previousDataCount;

    // ── Capture scroll anchor BEFORE data change ──
    // Structural identity survives a render-key refresh during the same update.
    const savedStartIndex = host.lastVisibleStartIndex;
    const savedEndIndex = host.lastVisibleEndIndex;
    const wasNearBottom = prevCount > 0 && savedEndIndex >= 0 &&
      prevCount - 1 - savedEndIndex <= TIMELINE_BOTTOM_VISIBLE_GAP;
    let anchorStableKey: string | undefined;
    const savedAnchorPrefix: string[] = [];
    if (prevCount > 0 && savedStartIndex >= 0 && savedStartIndex < prevCount) {
      anchorStableKey = host.dataSource.getData(savedStartIndex).stableKey;
      for (let i = 0; i < savedStartIndex; i++) {
        savedAnchorPrefix.push(host.dataSource.getData(i).stableKey);
      }
    }
    host.isApplyingTimelineDiff = true;
    try {
      host.dataSource.applyDiff(result.entries);
    } finally {
      host.isApplyingTimelineDiff = false;
    }

    host.syncResolvedPendingDownloads(result.entries);
    host.fulfillPendingMediaOpenIntent(result.entries);
    host.refreshOpenMediaGalleryItems();
    const newCount = host.dataSource.totalCount();
    host.previousDataCount = newCount;
    if (host.lastVisibleEndIndex >= 0) {
      host.refreshScrollToBottomVisibility(host.lastVisibleEndIndex);
    }

    // Determine if the initial timeline has enough data to release the placeholder.
    // BUT do not set awaitingInitialTimeline = false here. Let restoreScrollPosition
    // handle it so the List appears already scrolled to the correct position.
    const canReleaseTimeline = !host.awaitingInitialTimeline ||
      (newCount >= INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT) ||
      (!chat || !chat.lastMessage || chat.lastMessage.id === '0') ||
      (host.loadChatHistoryUseCase &&
        !host.loadChatHistoryUseCase.canLoadOlderMessages(host.activeChatId));

    if (host.needsScrollRestore && newCount > 0 && canReleaseTimeline) {
      // Set initialIndex BEFORE releasing the placeholder so List is born at the
      // correct position — no programmatic scrollToBottom needed (iOS pattern).
      host.needsScrollRestore = false;
      host.computeInitialIndex(newCount);
      host.hasRestoredUnreadBoundary = host.unreadRestoreIndex >= 0;
      host.restoreScrollPosition();
    } else if (!host.awaitingInitialTimeline && !host.hasRestoredUnreadBoundary &&
      host.unreadRestoreIndex >= 0 && host.unreadRestoreIndex < newCount) {
      // The first short history batch can release the List before the
      // around-unread window arrives. Restore once when that marker appears;
      // otherwise maintainVisibleContentPosition keeps the old viewport and
      // the correctly inserted divider remains off-screen.
      host.hasRestoredUnreadBoundary = true;
      host.listInitialIndex = host.unreadRestoreIndex;
      host.restoreScrollPosition();
    } else if (!host.awaitingInitialTimeline) {
      // Only do prepend/append compensation after initial setup is complete.
      const prependCount = host.dataSource.getLastPrependCount();
      const nextAnchorIndex = anchorStableKey
        ? result.entries.findIndex((entry: ChatTimelineEntryVO) => entry.stableKey === anchorStableKey)
        : -1;
      let anchorPrefixChanged = nextAnchorIndex >= 0 && nextAnchorIndex !== savedStartIndex;
      if (nextAnchorIndex >= 0 && !anchorPrefixChanged) {
        for (let i = 0; i < savedAnchorPrefix.length; i++) {
          if (savedAnchorPrefix[i] !== result.entries[i].stableKey) {
            anchorPrefixChanged = true;
            break;
          }
        }
      }
      if (anchorPrefixChanged || (prependCount > 0 && prevCount > 0 && anchorStableKey)) {
        // Native position maintenance can report insert/delete index callbacks
        // after applyDiff returns, including a net-zero replacement above the
        // surviving anchor. Reuse the existing user-scroll pagination fence.
        host.guardProgrammaticScroll();
        host.blockAutoPaginationUntilUserScroll = true;
        hilog.info(DOMAIN, TAG,
          'Structural timeline change: key=%{public}s prepend=%{public}d start=%{public}d end=%{public}d',
          anchorStableKey, prependCount, savedStartIndex, savedEndIndex);
      } else if (prevCount > 0 && newCount > prevCount && wasNearBottom) {
        // Capture bottom intent before the new rows increase the distance.
        // Native layout may expand the visible end without changing that intent.
        host.scheduleLifecycleTask(16, () => {
          // A newer movement toward older content cancels the captured intent,
          // even when that viewport remains within the bottom threshold.
          if (host.lastVisibleStartIndex < savedStartIndex || host.lastVisibleEndIndex < savedEndIndex) {
            return;
          }
          const sameVisibleRange = host.lastVisibleStartIndex === savedStartIndex &&
            host.lastVisibleEndIndex >= savedEndIndex;
          const stillAtBottom = host.lastVisibleEndIndex >= 0 &&
            host.dataSource.totalCount() - 1 - host.lastVisibleEndIndex <= TIMELINE_BOTTOM_VISIBLE_GAP;
          if (!sameVisibleRange && !stillAtBottom) {
            return;
          }
          host.scrollTimelineToBottomAligned();
        });
      }
    }

    host.fulfillPendingJump();
    host.refreshRestoredReplySnippet(state);
    host.scheduleMissingReplyHydration(state);
  }

export function effectiveVoiceListened(host: ChatTimelineTransactionCoordinatorPort, entry: ChatTimelineEntryVO): boolean {
    return entry.message.isVoiceListened || host.locallyListenedVoiceIds.has(entry.message.messageId);
  }

export function isActiveVoiceEntry(host: ChatTimelineTransactionCoordinatorPort, entry: ChatTimelineEntryVO): boolean {
    return host.activeVoiceMessageId === entry.message.messageId;
  }

export function isActiveAudioEntry(host: ChatTimelineTransactionCoordinatorPort, entry: ChatTimelineEntryVO): boolean {
    return host.activeAudioMessageId === entry.message.messageId;
  }
