export class PendingForwardTransferPayload {
  targetChatId: number = 0;
  sourceChatId: number = 0;
  messageIds: string[] = [];
  author: string = '';
  preview: string = '';
}

class PendingForwardTransferStore {
  private payload?: PendingForwardTransferPayload;

  arm(targetChatId: number, sourceChatId: number, messageIds: string[], author: string, preview: string): void {
    if (targetChatId === 0 || sourceChatId === 0 || messageIds.length === 0) {
      this.payload = undefined;
      return;
    }
    const next = new PendingForwardTransferPayload();
    next.targetChatId = targetChatId;
    next.sourceChatId = sourceChatId;
    next.messageIds = [...messageIds];
    next.author = author;
    next.preview = preview;
    this.payload = next;
  }

  hasPendingFor(chatId: number): boolean {
    return this.payload !== undefined && this.payload.targetChatId === chatId;
  }

  consumeFor(chatId: number): PendingForwardTransferPayload | undefined {
    if (!this.hasPendingFor(chatId) || this.payload === undefined) {
      return undefined;
    }
    const current = this.payload;
    this.payload = undefined;

    const result = new PendingForwardTransferPayload();
    result.targetChatId = current.targetChatId;
    result.sourceChatId = current.sourceChatId;
    result.messageIds = [...current.messageIds];
    result.author = current.author;
    result.preview = current.preview;
    return result;
  }

  clear(): void {
    this.payload = undefined;
  }
}

export const pendingForwardTransfer: PendingForwardTransferStore = new PendingForwardTransferStore();
