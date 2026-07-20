import { ChatMemberRole } from '../../../domain/usecases/chatMembers';

export class TgProfileMemberRowVO {
  stableId: string = '';
  userId: number = 0;
  senderChatId: number = 0;
  title: string = '';
  subtitle: string = '';
  avatarInitials: string = '';
  avatarImageSrc: string = '';
  avatarColorIndex: number = 0;
  isOnline: boolean = false;
  role: ChatMemberRole = 'member';
  roleLabel: string = '';
  isEnabled: boolean = true;
}

export class TgProfileMembersDataSource implements IDataSource {
  private rows: TgProfileMemberRowVO[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.rows.length;
  }

  getData(index: number): TgProfileMemberRowVO {
    return this.rows[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  replace(rows: TgProfileMemberRowVO[]): void {
    this.rows = rows.slice();
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }
}
