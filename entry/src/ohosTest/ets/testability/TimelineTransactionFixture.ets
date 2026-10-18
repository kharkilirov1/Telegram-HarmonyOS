import { systemDateTime } from '@kit.BasicServicesKit';
import { AppState, Chat, Message, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { ChatTimelineDataSource } from '../../../main/ets/ui/pages/chat/ChatTimelineDataSource';
import { ChatTimelineEntryVO } from '../../../main/ets/ui/pages/chat/ChatTimelineVO';
import { PendingMediaOpenIntent } from '../../../main/ets/ui/pages/chat/PendingMediaOpenIntent';
import { LoadChatHistoryUseCase } from '../../../main/ets/domain/usecases/loadChatHistory';
import { TgChatTopBarSubtitleMode, TgChatTopBarTrailingAction } from '../../../main/ets/ui/tg_ui/atoms/TgChatTopBar';
import { ChatTimelineTransactionCoordinatorPort, rebuildTimeline } from '../../../main/ets/ui/pages/chat/ChatTimelineTransactionCoordinator';
import { HandleTimelineScrollIndexPort, handleTimelineScrollIndex } from '../../../main/ets/ui/pages/chat/ChatScreenViewEventHandlers';
import { TimelineUpdateRecorder } from './TimelineUpdateInputs';
import {
  ChatTimelineViewportCoordinatorPort, guardProgrammaticScroll, isNearBottom, isNearTopPaginationEdge,
  isNearBottomPaginationEdge, maybeUnlockAutoPagination, handleTimelineTouch, shouldSuppressLoadOlder,
  refreshScrollToBottomVisibility, schedulePaginationRecheck
} from '../../../main/ets/ui/pages/chat/ChatTimelineViewportCoordinator';

export function timelineTimingNow(): number {
  try { return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false); }
  catch (_) { return -1; }
}

export class TimelineScrollEvent {
  kind: string = '';
  start: number = -1;
  end: number = -1;
  offset: number = 0;
  state: number = 0;
  applying: boolean = false;
  time: number = 0;
}

// Runs the actual transaction, projection, viewport and native-event owners.
// Unrelated top-bar/media/bot actions are explicit inert fixture ports. Pagination
// records intent and must never reach an account, gateway or app bootstrap.
export class TimelineTransactionFixture implements ChatTimelineTransactionCoordinatorPort,
  HandleTimelineScrollIndexPort, ChatTimelineViewportCoordinatorPort {
  private static timingSequence: number = 0;
  readonly timingId: number = ++TimelineTransactionFixture.timingSequence;
  timingEnabled: boolean = false;
  readonly dataSource: ChatTimelineDataSource = new ChatTimelineDataSource();
  readonly recorder: TimelineUpdateRecorder = new TimelineUpdateRecorder(this.dataSource, false);
  readonly events: TimelineScrollEvent[] = [];
  state: AppState = createInitialAppState();
  activeChatId: number = 701;
  activeChatIsChannel: boolean = false;
  activeChatTitle: string = '';
  activeAudioMessageId: string = '';
  activeVoiceMessageId: string = '';
  awaitingInitialTimeline: boolean = false;
  blockAutoPaginationUntilUserScroll: boolean = false;
  chatAvatarColorIndex: number = 0;
  chatAvatarImageSrc: string = '';
  chatAvatarInitials: string = '';
  chatIsOnline: boolean = false;
  chatSubtitle: string = '';
  chatSubtitleMode: TgChatTopBarSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
  chatTopBarTrailingAction: TgChatTopBarTrailingAction = TgChatTopBarTrailingAction.Search;
  currentScrollChatId: number = 701;
  hasRestoredUnreadBoundary: boolean = false;
  isApplyingTimelineDiff: boolean = false;
  isLoadingNewer: boolean = false;
  isLoadingOlder: boolean = false;
  lastVisibleEndIndex: number = -1;
  lastVisibleStartIndex: number = -1;
  listInitialIndex: number = 0;
  listScroller: Scroller = new Scroller();
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  locallyListenedVoiceIds: Set<string> = new Set<string>();
  needsScrollRestore: boolean = false;
  pendingMediaOpenIntent: PendingMediaOpenIntent = new PendingMediaOpenIntent();
  previousDataCount: number = 0;
  routeChatId: number = 701;
  routeChatTitle: string = '';
  scrollToBottomUnreadCount: number = 0;
  stickyLastReadMessageId: string = '';
  title: string = '';
  unreadRestoreIndex: number = -1;
  showScrollToBottom: boolean = false;
  suppressLoadOlderUntil: number = 0;
  timelineTouchStartY: number = -1;
  paginationRecheckTimerId: number = -1;
  rebuildScheduled: boolean = false;
  pageLifecycleToken: number = 1;
  olderCalls: number = 0;
  newerCalls: number = 0;
  bottomCalls: number = 0;
  mounted: boolean = false;
  onActiveDrag?: () => void;
  activeDragUpdateCount: number = 0;
  private lifecycleTimers: number[] = [];
  readonly disappeared: Promise<void>;
  private resolveDisappearance?: () => void;
  queuedApplyDeliveries: number = 0;

  constructor() {
    // Registered before native navigation, resolved only by actual disposal.
    this.disappeared = new Promise<void>((resolve) => { this.resolveDisappearance = resolve; });
    this.dataSource.registerDataChangeListener(this.recorder);
    const chat = new Chat(); chat.id = this.activeChatId; chat.type = 'group';
    chat.title = 'Synthetic timeline'; chat.unreadCount = 0;
    this.state.chats.chats.set(chat.id, chat);
  }
  apply(ids: number[], editedId: number = -1, stamp: number = 0): void {
    const messages = new Map<string, Message>();
    for (const id of ids) {
      const message = new Message(); message.id = id.toString(); message.chatId = this.activeChatId;
      message.timestamp = 1700000000 + id; message.senderId = 0; message.isOutgoing = false;
      message.content.type = 'text'; message.content.text = 'timeline:' + id.toString() + ':v' + (id === editedId ? stamp : 0).toString();
      message.editDate = id === editedId ? stamp : 0; message.sendStatus = 'sent';
      messages.set(message.id, message);
    }
    // The actual selector memoizes Map identity, so every transaction receives
    // a fresh snapshot, just as reducer-owned state does.
    this.state.messages.messages.set(this.activeChatId, messages);
    rebuildTimeline(this, this.state);
  }
  indexOf(id: number): number {
    return this.dataSource.getAllEntries().findIndex((entry: ChatTimelineEntryVO) => entry.stableKey === 'msg_' + id.toString());
  }
  onScrollIndex(start: number, end: number): void {
    if (!this.mounted) return;
    const event = new TimelineScrollEvent(); event.kind = 'index'; event.start = start; event.end = end;
    event.applying = this.isApplyingTimelineDiff; event.time = Date.now(); this.events.push(event);
    handleTimelineScrollIndex(this, start, end);
  }
  onDidScroll(offset: number, state: ScrollState): void {
    if (!this.mounted) return;
    const event = new TimelineScrollEvent(); event.kind = 'scroll'; event.offset = offset; event.state = state;
    event.applying = this.isApplyingTimelineDiff; event.time = Date.now(); this.events.push(event);
    maybeUnlockAutoPagination(this, offset, state);
    if (state === ScrollState.Scroll && this.onActiveDrag !== undefined) {
      const update = this.onActiveDrag;
      this.onActiveDrag = undefined;
      this.activeDragUpdateCount++;
      update();
    }
  }
  loadOlderMessages(): void { this.olderCalls++; }
  loadNewerMessages(): void { this.newerCalls++; }
  isNearTopPaginationEdge(start: number): boolean { return isNearTopPaginationEdge(this, start); }
  isNearBottomPaginationEdge(end: number, total: number): boolean { return isNearBottomPaginationEdge(this, end, total); }
  shouldSuppressLoadOlder(): boolean { return shouldSuppressLoadOlder(this); }
  guardProgrammaticScroll(durationMs?: number): void { guardProgrammaticScroll(this, durationMs); }
  isNearBottom(): boolean { return isNearBottom(this); }
  refreshScrollToBottomVisibility(end: number): void { refreshScrollToBottomVisibility(this, end); }
  schedulePaginationRecheck(delayMs: number = 0): void { schedulePaginationRecheck(this, delayMs); }
  recheckPaginationEdge(): void { handleTimelineScrollIndex(this, this.lastVisibleStartIndex, this.lastVisibleEndIndex); }
  touch(event: TouchEvent): void { handleTimelineTouch(this, event); }
  scrollTimelineToBottomAligned(): void {
    this.bottomCalls++;
    this.listScroller.scrollToIndex(this.dataSource.totalCount() - 1, false, ScrollAlign.END);
  }
  traceTiming(event: string, relatedId: number = -1): void {
    if (!this.timingEnabled) return;
    try {
      console.info('[TimelineTiming] ' + JSON.stringify({ format: 'held-v1', event: event,
        mono: timelineTimingNow(), fixtureId: this.timingId, relatedId: relatedId,
        token: this.pageLifecycleToken, mounted: this.mounted, count: this.dataSource.totalCount(),
        deliveries: this.queuedApplyDeliveries }));
    } catch (_) {}
  }
  captureLifecycleTask(task: () => void): () => void {
    const token = this.pageLifecycleToken;
    return (): void => { if (this.mounted && token === this.pageLifecycleToken) task(); };
  }
  scheduleLifecycleTask(delayMs: number, task: () => void): void {
    const guarded = this.captureLifecycleTask(task);
    const id = setTimeout(guarded, delayMs) as number;
    this.lifecycleTimers.push(id);
  }
  dispose(): void {
    this.traceTiming('dispose-enter');
    this.mounted = false; this.pageLifecycleToken++;
    this.onActiveDrag = undefined;
    for (const id of this.lifecycleTimers) clearTimeout(id);
    this.lifecycleTimers = [];
    if (this.paginationRecheckTimerId >= 0) clearTimeout(this.paginationRecheckTimerId);
    this.paginationRecheckTimerId = -1;
    this.traceTiming('dispose-return');
    this.resolveDisappearance?.();
  }
  // Test-only queued input ownership. This tests the isolated fixture boundary,
  // not the real Session's navigation/account lifecycle.
  queueApply(ids: number[], delayMs: number): void { this.scheduleLifecycleTask(delayMs, () => this.apply(ids)); }
  captureQueuedApply(ids: number[]): () => void {
    this.traceTiming('held-capture');
    const guarded = this.captureLifecycleTask(() => this.apply(ids));
    return (): void => {
      this.queuedApplyDeliveries++; this.traceTiming('held-release-enter');
      guarded();
      this.traceTiming('held-release-return');
    };
  }
  clearPendingMediaDownloads(): void {}
  computeInitialIndex(_total: number): void {}
  fulfillPendingJump(): void {}
  fulfillPendingMediaOpenIntent(_entries: ChatTimelineEntryVO[]): void {}
  refreshBotMenuState(_state: AppState): void {}
  refreshOpenMediaGalleryItems(): void {}
  refreshRestoredReplySnippet(_state: AppState): void {}
  resetBotMenuState(): void {}
  restoreScrollPosition(): void {}
  scheduleMissingReplyHydration(_state: AppState): void {}
  syncResolvedPendingDownloads(_entries: ChatTimelineEntryVO[]): void {}
  updateChatTopBarData(_state: AppState): void {}
  armAutoPaginationUnlock(_index: number, _reason: string): void {}
  jumpToMessageId(_id: string): void {}
}
