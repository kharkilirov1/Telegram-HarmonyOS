// I1: a notification tap opens the chat. The ability cannot push routes itself, so it leaves the chat id
// here and MainTabsPage consumes it once the runtime and navigation stack exist.

export class ChatOpenIntakeStore {
  private pendingChatId: number = 0;

  set(chatId: number): void {
    if (!Number.isSafeInteger(chatId) || chatId === 0) {
      return;
    }
    this.pendingChatId = chatId;
  }

  hasPending(): boolean {
    return this.pendingChatId !== 0;
  }

  take(): number {
    const chatId = this.pendingChatId;
    this.pendingChatId = 0;
    return chatId;
  }

  clear(): void {
    this.pendingChatId = 0;
  }
}

export const chatOpenIntake: ChatOpenIntakeStore = new ChatOpenIntakeStore();
