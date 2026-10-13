export class PendingForwardTransferPayload {
  navigationToken: number = 0;
  targetChatId: number = 0;
  sourceChatId: number = 0;
  messageIds: string[] = [];
  author: string = '';
  preview: string = '';
}

class PendingForwardTransferStore {
  private payload?: PendingForwardTransferPayload;

  arm(targetChatId: number, sourceChatId: number, messageIds: string[], author: string, preview: string,
    navigationToken: number = 0): void {
    if (!Number.isSafeInteger(targetChatId) || targetChatId === 0 ||
      !Number.isSafeInteger(sourceChatId) || sourceChatId === 0 || messageIds.length === 0 ||
      !Number.isSafeInteger(navigationToken) || navigationToken < 0) {
      this.clear(navigationToken);
      return;
    }
    const next = new PendingForwardTransferPayload();
    next.navigationToken = navigationToken;
    next.targetChatId = targetChatId;
    next.sourceChatId = sourceChatId;
    next.messageIds = [...messageIds];
    next.author = author;
    next.preview = preview;
    this.payload = next;
  }

  hasPendingFor(chatId: number, navigationToken?: number): boolean {
    return this.payload !== undefined && this.payload.targetChatId === chatId &&
      (navigationToken === undefined || this.payload.navigationToken === navigationToken);
  }

  consumeFor(chatId: number, navigationToken: number = 0): PendingForwardTransferPayload | undefined {
    if (!this.hasPendingFor(chatId, navigationToken) || this.payload === undefined) {
      return undefined;
    }
    const current = this.payload;
    this.payload = undefined;

    const result = new PendingForwardTransferPayload();
    result.navigationToken = current.navigationToken;
    result.targetChatId = current.targetChatId;
    result.sourceChatId = current.sourceChatId;
    result.messageIds = [...current.messageIds];
    result.author = current.author;
    result.preview = current.preview;
    return result;
  }

  clear(navigationToken?: number): void {
    if (navigationToken === undefined || this.payload?.navigationToken === navigationToken) {
      this.payload = undefined;
    }
  }
}

export const pendingForwardTransfer: PendingForwardTransferStore = new PendingForwardTransferStore();
