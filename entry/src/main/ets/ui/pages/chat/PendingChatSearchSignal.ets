// One-shot profile -> chat search intent. Telegram iOS carries the profile's
// AccountContext when returning to message search; this adaptation retains the
// captured store/epoch until the owning chat route consumes it.

import { AppStore } from '../../../core/store/AppStore';

export class PendingChatSearchSignal {
  private static chatId: number = 0;
  private static accountStore?: AppStore;
  private static accountScope?: AppStore;
  private static token: number = 0;
  private static nextToken: number = 0;

  static set(chatId: number, accountStore: AppStore, accountScope: AppStore = accountStore.createScope()): number {
    if (!Number.isSafeInteger(chatId) || chatId === 0 || !accountStore.isScopeCurrent() ||
      !accountScope.isScopeCurrent()) return 0;
    PendingChatSearchSignal.chatId = chatId;
    PendingChatSearchSignal.accountStore = accountStore;
    PendingChatSearchSignal.accountScope = accountScope;
    PendingChatSearchSignal.token = ++PendingChatSearchSignal.nextToken;
    return PendingChatSearchSignal.token;
  }

  // A failed navigation may clear only the intent installed by that caller.
  static clear(token: number): void {
    if (token === 0 || PendingChatSearchSignal.token !== token) return;
    PendingChatSearchSignal.chatId = 0;
    PendingChatSearchSignal.accountStore = undefined;
    PendingChatSearchSignal.accountScope = undefined;
    PendingChatSearchSignal.token = 0;
  }

  static consume(chatId: number, accountStore: AppStore | undefined): boolean {
    const token = PendingChatSearchSignal.token;
    if (token === 0) return false;
    if (accountStore === undefined || PendingChatSearchSignal.accountStore !== accountStore ||
      !accountStore.isScopeCurrent() || PendingChatSearchSignal.accountScope?.isScopeCurrent() !== true) {
      PendingChatSearchSignal.clear(token);
      return false;
    }
    // Wrong chat in the same account leaves the one-shot intent for its target.
    if (chatId === 0 || PendingChatSearchSignal.chatId !== chatId) return false;
    PendingChatSearchSignal.clear(token);
    return true;
  }
}
