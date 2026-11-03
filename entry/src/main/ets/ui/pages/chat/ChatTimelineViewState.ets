// Page-owned presentation state. Keep this instance stable for its route lifetime.
@ObservedV2
export class ChatTimelineViewState {
  @Trace messageActionsOpenId: string = '';
  // S3d.1: keys shown in the popup reaction row; seeded from the chat list, replaced by the
  // per-message getMessageAvailableReactions answer.
  @Trace messageActionsReactionKeys: string[] = [];
  // S5b (C9): selection mode. selectionActive is explicit (not derived from the ids) so the panel
  // and row hit-testing can react before the first toggle resolves.
  @Trace selectionActive: boolean = false;
  @Trace selectedMessageIds: string[] = [];
  @Trace messageActionsForwardState: string = 'loading';
  @Trace awaitingInitialTimeline: boolean = false;
  @Trace prependScrollMask: boolean = false;
  @Trace listInitialIndex: number = 0;
  @Trace showScrollToBottom: boolean = false;
  @Trace scrollToBottomUnreadCount: number = 0;
}
