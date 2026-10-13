// Staged one-shot hydration for group membership, defaults and supergroup boosts. Access stays in
// the store; the page rereads it on async settlement or an explicit retry.
import { Chat } from '../../../core/model/AppState';
import { GroupAccessDto, GroupKind, SupergroupBoostsDto, SupergroupSlowmodeDto } from '../../../core/model/dto/GroupAccessDto';
import { LoadChatAccessUseCase } from '../../../domain/usecases/loadChatAccess';
import { selectChatInputPanel, needsSupergroupBoosts } from './ChatInputPanelPolicy';

export class ChatAccessController {
  private useCase: LoadChatAccessUseCase;
  private onChanged: () => void;
  private key: string = '';
  private groupId: number = 0;
  private groupKind: GroupKind = 'supergroup';
  private chatId: number = 0;
  private loadPermissions: boolean = false;
  private loadBoosts: boolean = false;
  private loadSlowmode: boolean = false;
  private slowAccess?: GroupAccessDto;
  private generation: number = 0;
  private attempted: boolean = false;
  private pending: boolean = false;
  private canLoad: boolean = false;
  private unavailable: boolean = false;
  private disposed: boolean = false;

  constructor(useCase: LoadChatAccessUseCase, onChanged: () => void) {
    // Keep this account's capability, never reacquire a global store or adapter.
    this.useCase = useCase;
    this.onChanged = onChanged;
  }

  observe(chat: Chat, access?: GroupAccessDto, boosts?: SupergroupBoostsDto, slowmode?: SupergroupSlowmodeDto): void {
    if (this.disposed) return;
    const isBasic = chat.type === 'group';
    const isSupergroup = chat.type === 'supergroup';
    const groupId = isBasic ? chat.basicGroupId : chat.supergroupId;
    const groupKind: GroupKind = isBasic ? 'basicGroup' : 'supergroup';
    const known = access !== undefined && access.kind === groupKind && access.groupId === groupId &&
      access.role !== 'unknown' && (!isBasic || typeof access.isActive === 'boolean');
    const needsPermissions = (isBasic || isSupergroup) && known && access !== undefined && access.isActive && access.isMember &&
      access.role !== 'creator' && access.role !== 'administrator' && access.role !== 'banned' &&
      chat.sendPermissions === undefined && (isBasic || selectChatInputPanel(chat, access, false, '', boosts) === 'unknown');
    const needsBoosts = isSupergroup && known && !needsPermissions && needsSupergroupBoosts(chat, access, boosts);
    const boostExempt = boosts !== undefined && boosts.groupId === groupId && boosts.unrestrictBoostCount > 0 &&
      boosts.myBoostCount >= boosts.unrestrictBoostCount;
    const needsSlowmode = isSupergroup && known && !needsPermissions && !needsBoosts &&
      access?.isSlowModeEnabled === true && access.isMember && access.role !== 'creator' &&
      access.role !== 'administrator' && !boostExempt && slowmode === undefined;
    // Invalid runtime values must not alias valid numeric IDs after stringifying.
    const key = `${chat.type}:${typeof chat.id}:${chat.id}:` +
      `${typeof groupId}:${groupId}:${needsPermissions ? 'permissions' : (needsBoosts ? 'boosts' :
        needsSlowmode ? 'slowmode' : 'group')}`;
    if (this.key !== key || (needsSlowmode && this.slowAccess !== access)) {
      this.generation++;
      this.key = key;
      this.groupId = groupId;
      this.groupKind = groupKind;
      this.chatId = chat.id;
      this.loadPermissions = needsPermissions;
      this.loadBoosts = needsBoosts;
      this.loadSlowmode = needsSlowmode;
      this.slowAccess = access;
      this.attempted = false;
      this.pending = false;
      this.canLoad = false;
      this.unavailable = false;
    }
    // An empty Chat also crosses the identity boundary and cancels old UI work.
    if (chat.type !== 'channel' && !isBasic && !isSupergroup) return;
    if (!Number.isSafeInteger(chat.id) || chat.id === 0 ||
      !Number.isSafeInteger(groupId) || groupId <= 0) {
      this.canLoad = false;
      this.unavailable = true;
      return;
    }
    if (known && !needsPermissions && !needsBoosts && !needsSlowmode) {
      // A live known status supersedes this request's UI generation, including
      // failure. A later store rebuild must not restart the consumed one-shot.
      this.generation++;
      this.pending = false;
      this.attempted = true;
      this.canLoad = false;
      this.unavailable = false;
      return;
    }
    this.canLoad = true;
    if (!this.attempted) this.start(false);
    // No synchronous notification here: observe is part of the page's rebuild.
  }

  isUnavailable(): boolean {
    return this.unavailable;
  }

  retry(): void {
    if (this.disposed || !this.canLoad || this.pending || !this.unavailable) return;
    this.start(true);
  }

  dispose(): void {
    this.disposed = true;
    this.generation++;
    this.pending = false;
    this.canLoad = false;
    this.unavailable = false;
  }

  private start(notify: boolean): void {
    const generation = ++this.generation;
    const groupId = this.groupId;
    const groupKind = this.groupKind;
    const chatId = this.chatId;
    const loadPermissions = this.loadPermissions;
    const loadBoosts = this.loadBoosts;
    const loadSlowmode = this.loadSlowmode;
    this.attempted = true;
    this.pending = true;
    this.unavailable = false;
    if (notify) {
      // Publish ownership before a listener can observe/retry/switch/dispose.
      this.onChanged();
      if (!this.isCurrent(generation)) return;
    }
    let request: Promise<void>;
    try {
      request = loadPermissions ? this.useCase.loadPermissions(chatId) :
        (loadBoosts ? this.useCase.loadBoosts(groupId) : loadSlowmode ? this.useCase.loadSlowmode(groupId) :
          this.useCase.load(groupKind, groupId));
    } catch (error) {
      // Even a synchronous capability failure must not notify inside observe.
      request = Promise.reject(error);
    }
    request.then((): void => {
      this.settle(generation, false);
    }).catch((): void => {
      this.settle(generation, true);
    });
  }

  private isCurrent(generation: number): boolean {
    return !this.disposed && this.pending && this.generation === generation;
  }

  private settle(generation: number, failed: boolean): void {
    if (!this.isCurrent(generation)) return;
    this.pending = false;
    this.unavailable = failed;
    // All old-attempt cleanup is complete before a reentrant listener runs.
    this.onChanged();
  }
}
