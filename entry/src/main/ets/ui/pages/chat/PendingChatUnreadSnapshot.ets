// One-shot ChatList -> chat snapshot. The list captures this before navigation,
// so the chat page cannot lose the unread boundary when viewMessages updates
// the live Chat while the NavDestination transition is still completing.

export class ChatUnreadEntrySnapshot {
  chatId: number = 0;
  lastReadInboxMessageId: string = '0';
  unreadCount: number = 0;
}

export class PendingChatUnreadSnapshot {
  private static value?: ChatUnreadEntrySnapshot = undefined;

  static set(chatId: number, lastReadInboxMessageId: string, unreadCount: number): void {
    if (chatId === 0 || unreadCount <= 0) {
      PendingChatUnreadSnapshot.value = undefined;
      return;
    }
    const snapshot = new ChatUnreadEntrySnapshot();
    snapshot.chatId = chatId;
    snapshot.lastReadInboxMessageId = lastReadInboxMessageId.length > 0 ? lastReadInboxMessageId : '0';
    snapshot.unreadCount = Math.max(0, Math.floor(unreadCount));
    PendingChatUnreadSnapshot.value = snapshot;
  }

  static consume(chatId: number): ChatUnreadEntrySnapshot | undefined {
    const snapshot = PendingChatUnreadSnapshot.value;
    if (!snapshot || snapshot.chatId !== chatId) {
      return undefined;
    }
    PendingChatUnreadSnapshot.value = undefined;
    return snapshot;
  }

  static clear(chatId: number): void {
    const snapshot = PendingChatUnreadSnapshot.value;
    if (snapshot && snapshot.chatId === chatId) {
      PendingChatUnreadSnapshot.value = undefined;
    }
  }
}
