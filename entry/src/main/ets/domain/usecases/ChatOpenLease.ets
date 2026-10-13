import { createOpenChatCommand, createCloseChatCommand } from '../../core/model/AppCommand';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

// One page/route owns one acknowledged openChat call on a captured, generation-
// fenced gateway. Never look up a replacement gateway or replay an unknown result.
// td_api.tl: openChat/closeChat -> Ok. MessagesManager::open_dialog(DialogId)
// returns OK even when open_dialog(Dialog*) skips open_count++ for missing Read
// access (or counter saturation). This is logical API-call ownership, NOT proof
// of a native increment or of an exactly paired native decrement.
export class ChatOpenLease {
  private readonly chatId: number;
  private readonly gateway: TdGatewayPort;
  private acquisition: Promise<boolean> | undefined = undefined;
  private pending: Promise<boolean> | undefined = undefined;
  private releasePending: Promise<void> | undefined = undefined;
  private openAcknowledged: boolean = false;
  private released: boolean = false;

  constructor(chatId: number, gateway: TdGatewayPort) {
    this.chatId = chatId;
    this.gateway = gateway;
  }

  ensureOpen(canDispatch: () => boolean): Promise<boolean> {
    if (this.released) {
      return Promise.resolve(false);
    }
    if (this.pending !== undefined) {
      return this.pending;
    }
    // Reserve both promises before invoking caller code, including a reentrant
    // canDispatch. A failed preflight/result is terminal for this lease too.
    this.acquisition = Promise.resolve().then(() => this.acquire(canDispatch));
    this.pending = this.acquisition.then(async (acknowledged: boolean): Promise<boolean> => {
      if (!acknowledged || this.released) {
        return false;
      }
      let current = false;
      try {
        current = canDispatch();
      } catch (_) {
        // A revoked/throwing scope cannot retain this acknowledged open.
      }
      if (!current) {
        await this.release();
        return false;
      }
      return !this.released;
    });
    return this.pending;
  }

  release(): Promise<void> {
    // Consume visibility/ownership synchronously, before any await or callback.
    this.released = true;
    if (this.releasePending !== undefined) {
      return this.releasePending;
    }
    this.releasePending = this.closeWhenAcknowledged(this.acquisition);
    return this.releasePending;
  }

  isOpen(): boolean {
    return this.openAcknowledged && !this.released;
  }

  isReleased(): boolean {
    return this.released;
  }

  private async acquire(canDispatch: () => boolean): Promise<boolean> {
    try {
      if (!Number.isSafeInteger(this.chatId) || this.chatId === 0 ||
        this.released || !canDispatch() || this.released) {
        return false;
      }
      const result = await this.gateway.send(createOpenChatCommand(this.chatId));
      const acknowledged = result instanceof TdObject && result.getTopLevelStringStrict('@type') === 'ok';
      this.openAcknowledged = acknowledged;
      return acknowledged;
    } catch (_) {
      // Rejected, unknown or synchronous transport failures never own a close.
      return false;
    }
  }

  private async closeWhenAcknowledged(acquisition: Promise<boolean> | undefined): Promise<void> {
    // Await the raw acquisition, not ensureOpen's public result: its stale-scope
    // continuation can itself await release, and must not form a promise cycle.
    if (acquisition === undefined || !await acquisition) {
      return;
    }
    try {
      await this.gateway.send(createCloseChatCommand(this.chatId));
    } catch (_) {
      // Best effort on the SAME fenced adapter; no retry or replacement client.
    }
  }
}
