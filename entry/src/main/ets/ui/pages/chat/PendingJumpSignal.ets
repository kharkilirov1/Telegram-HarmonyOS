// PendingJumpSignal — cross-page jump intent (Shared Media row → chat).
// The chat page consumes it in onShown after popToName unwinds the stack;
// a plain static slot is enough since only one jump can be in flight.

export class PendingJumpSignal {
  private static chatId: number = 0;
  private static messageId: string = '0';

  static set(chatId: number, messageId: string): void {
    PendingJumpSignal.chatId = chatId;
    PendingJumpSignal.messageId = messageId;
  }

  // Returns the pending message id for this chat ('0' if none) and clears it
  static consume(chatId: number): string {
    if (PendingJumpSignal.chatId !== chatId || PendingJumpSignal.messageId === '0') {
      return '0';
    }
    const messageId = PendingJumpSignal.messageId;
    PendingJumpSignal.chatId = 0;
    PendingJumpSignal.messageId = '0';
    return messageId;
  }
}
