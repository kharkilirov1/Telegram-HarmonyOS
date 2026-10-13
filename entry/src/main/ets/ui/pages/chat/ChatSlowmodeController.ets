import { AppState, Chat } from '../../../core/model/AppState';
import { GroupAccessDto, SupergroupBoostsDto, SupergroupSlowmodeDto } from '../../../core/model/dto/GroupAccessDto';
import { AppStore } from '../../../core/store/AppStore';
import { getSlowmodeElapsedMs } from '../../../core/utils/SlowmodeClock';
import { navigationUIState } from '../../../core/model/UIStateModels';

export interface ChatSlowmodeHost {
  accountStore?: AppStore;
  activeChatId: number;
  pageLifecycleToken: number;
  composerSlowmodeSeconds: number;
}

function remainingSlowmodeMs(chat: Chat, access: GroupAccessDto | undefined,
  boosts: SupergroupBoostsDto | undefined, slowmode: SupergroupSlowmodeDto | undefined, nowMs: number): number {
  if (chat.type !== 'supergroup' || slowmode === undefined || slowmode.groupId !== chat.supergroupId ||
    slowmode.delaySeconds <= 0 || slowmode.expiresInSeconds <= 0) return 0;
  if (access?.kind === 'supergroup' && access.groupId === chat.supergroupId &&
    (access.isSlowModeEnabled === false || access.role === 'creator' || access.role === 'administrator')) return 0;
  if (boosts?.groupId === chat.supergroupId && Number.isInteger(boosts.unrestrictBoostCount) &&
    boosts.unrestrictBoostCount > 0 && Number.isInteger(boosts.myBoostCount) &&
    boosts.myBoostCount >= boosts.unrestrictBoostCount) return 0;
  // A clock failure cannot silently grant dispatch from a known live snapshot.
  const elapsed = Number.isFinite(nowMs) ? Math.max(0, nowMs - slowmode.receivedElapsedMs) : 0;
  return Math.max(0, slowmode.expiresInSeconds * 1000 - elapsed);
}

export function remainingSlowmodeSeconds(chat: Chat, access: GroupAccessDto | undefined,
  boosts: SupergroupBoostsDto | undefined, slowmode: SupergroupSlowmodeDto | undefined, nowMs: number): number {
  return Math.ceil(remainingSlowmodeMs(chat, access, boosts, slowmode, nowMs) / 1000);
}

export function currentSlowmodeSeconds(state: AppState, chatId: number): number {
  const chat = state.chats.chats.get(chatId);
  if (chat === undefined) return 0;
  return remainingSlowmodeSeconds(chat, state.chats.supergroupAccess.get(chat.supergroupId),
    state.chats.supergroupBoosts.get(chat.supergroupId), state.chats.supergroupSlowmode.get(chat.supergroupId),
    getSlowmodeElapsedMs());
}

// Per-route presentation timer only. Account-scoped AppStore owns the receipt;
// tick/foreground recomputation never changes composer input or submits work.
export class ChatSlowmodeController {
  private readonly clock: () => number;
  private host?: ChatSlowmodeHost;
  private store?: AppStore;
  private chatId: number = 0;
  private lifecycle: number = 0;
  private generation: number = 0;
  private timerId: number = -1;
  private visible: boolean = true;
  private unsubscribe?: () => void;

  constructor(clock: () => number = getSlowmodeElapsedMs) {
    this.clock = clock;
  }

  observe(host: ChatSlowmodeHost): void {
    if (this.host !== host || this.store !== host.accountStore || this.chatId !== host.activeChatId ||
      this.lifecycle !== host.pageLifecycleToken) {
      this.dispose();
      this.host = host;
      this.store = host.accountStore;
      this.chatId = host.activeChatId;
      this.lifecycle = host.pageLifecycleToken;
      const generation = this.generation;
      const cancel = this.store?.subscribeScopeInvalidation((): void => {
        if (generation !== this.generation) return;
        this.pause();
        if (this.hasSameHost()) host.composerSlowmodeSeconds = 0;
      });
      if (generation === this.generation) this.unsubscribe = cancel;
      else cancel?.();
    }
    this.refresh();
  }

  pause(): void {
    if (this.timerId >= 0) clearTimeout(this.timerId);
    this.timerId = -1;
  }

  suspend(): void {
    this.visible = false;
    this.pause();
  }

  resume(): void {
    this.visible = true;
    this.refresh();
  }

  dispose(): void {
    this.generation++;
    this.pause();
    this.unsubscribe?.();
    this.unsubscribe = undefined;
    if (this.hasSameHost() && this.host !== undefined) this.host.composerSlowmodeSeconds = 0;
    this.host = undefined;
    this.store = undefined;
  }

  private hasSameHost(): boolean {
    return this.host !== undefined && this.host.accountStore === this.store &&
      this.host.activeChatId === this.chatId && this.host.pageLifecycleToken === this.lifecycle;
  }

  private refresh(): void {
    this.pause();
    const host = this.host;
    if (host === undefined || !this.hasSameHost()) return;
    const state = this.store?.getState();
    const chat = state?.chats.chats.get(this.chatId);
    const remaining = state === undefined || chat === undefined || this.store?.isScopeCurrent() !== true ? 0 :
      remainingSlowmodeMs(chat, state.chats.supergroupAccess.get(chat.supergroupId),
        state.chats.supergroupBoosts.get(chat.supergroupId), state.chats.supergroupSlowmode.get(chat.supergroupId),
        this.clock());
    host.composerSlowmodeSeconds = Math.ceil(remaining / 1000);
    if (remaining <= 0 || !this.visible || navigationUIState.applicationForeground === false) return;
    const generation = this.generation;
    const scheduled = setTimeout((): void => {
      if (generation !== this.generation || this.timerId !== scheduled || !this.hasSameHost()) return;
      this.timerId = -1;
      this.refresh();
    }, Math.max(1, Math.min(1000, remaining))) as number;
    this.timerId = scheduled;
  }
}
