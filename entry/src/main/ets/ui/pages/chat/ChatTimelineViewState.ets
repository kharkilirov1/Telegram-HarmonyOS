// Page-owned presentation state. Keep this instance stable for its route lifetime.
@ObservedV2
export class ChatTimelineViewState {
  @Trace messageActionsOpenId: string = '';
  @Trace messageActionsForwardState: string = 'loading';
  @Trace awaitingInitialTimeline: boolean = false;
  @Trace prependScrollMask: boolean = false;
  @Trace listInitialIndex: number = 0;
  @Trace showScrollToBottom: boolean = false;
  @Trace scrollToBottomUnreadCount: number = 0;
}
