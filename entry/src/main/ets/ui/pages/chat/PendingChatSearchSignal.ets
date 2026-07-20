// One-shot profile -> chat search intent. Telegram iOS keeps the avatar/info
// button in group chat bars and exposes message search from PeerInfoScreen;
// the chat page consumes this signal after the profile stack is unwound.

export class PendingChatSearchSignal {
  private static chatId: number = 0;

  static set(chatId: number): void {
    PendingChatSearchSignal.chatId = chatId;
  }

  static consume(chatId: number): boolean {
    if (chatId === 0 || PendingChatSearchSignal.chatId !== chatId) {
      return false;
    }
    PendingChatSearchSignal.chatId = 0;
    return true;
  }
}
