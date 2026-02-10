// Group / Channel admin panel — manage settings, permissions, administrators, bans
// Reference: Telegram Android ChatEditActivity, iOS ChannelAdminController
// HarmonyOS: NavDestination, @ComponentV2, V2 decorators, glass card styling

import { MessagesController } from '../../controllers/MessagesController';
import { GroupService } from '../../services/GroupService';
import { UserService } from '../../services/UserService';
import { ChatService } from '../../services/ChatService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GroupAdminAdminsSection } from './components/GroupAdminAdminsSection';
import { GroupAdminBannedSection } from './components/GroupAdminBannedSection';
import { GroupAdminHeaderSection } from './components/GroupAdminHeaderSection';
import { GroupAdminMember, GroupBannedMember } from './components/GroupAdminModels';
import { GroupAdminPermissionsSection } from './components/GroupAdminPermissionsSection';
import { GroupAdminRecentActionsSection } from './components/GroupAdminRecentActionsSection';
import { GroupAdminTopBar } from './components/GroupAdminTopBar';
import { GroupAdminTypeSection } from './components/GroupAdminTypeSection';

@Builder
export function GroupAdminBuilder(name: string, param: Object) {
  GroupAdminPage({ chatId: (param as Record<string, number>)['chatId'] ?? 0 })
}

@ComponentV2
export struct GroupAdminPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param chatId: number = 0;

  @Local title: string = '';
  @Local isPublic: boolean = false;
  @Local isSaving: boolean = false;

  @Local canSendMessages: boolean = true;
  @Local canSendMedia: boolean = true;
  @Local canSendPolls: boolean = true;
  @Local canSendStickers: boolean = true;
  @Local canAddMembers: boolean = true;
  @Local canPinMessages: boolean = true;
  @Local canChangeInfo: boolean = true;

  @Local administrators: GroupAdminMember[] = [];
  @Local bannedUsers: GroupBannedMember[] = [];

  aboutToAppear(): void {
    this.loadAdminData();
  }

  private async loadAdminData(): Promise<void> {
    const chat = MessagesController.getInstance().getChat(this.chatId);
    if (chat) {
      this.title = chat.title;
    }

    try {
      const chatResult = await GroupService.getInstance().getChat(this.chatId);
      const permissions = chatResult['permissions'] as Record<string, boolean>;
      if (permissions) {
        this.canSendMessages = permissions['can_send_basic_messages'] ?? true;
        this.canSendMedia = permissions['can_send_audios'] ?? true;
        this.canSendPolls = permissions['can_send_polls'] ?? true;
        this.canSendStickers = permissions['can_send_other_messages'] ?? true;
        this.canAddMembers = permissions['can_invite_users'] ?? true;
        this.canPinMessages = permissions['can_pin_messages'] ?? true;
        this.canChangeInfo = permissions['can_change_info'] ?? true;
      }

      const sgInfo = await GroupService.getInstance().getSupergroup(Math.abs(this.chatId));
      const hasUsername = (sgInfo.usernames?.editable_username || '').length > 0;
      this.isPublic = hasUsername;
    } catch (e) {
      hilog.warn(0x0001, 'GroupAdminPage', 'Failed to load admin data, using defaults');
    }

    await this.loadAdministrators();
    await this.loadBannedUsers();
  }

  private async loadAdministrators(): Promise<void> {
    try {
      const result = await GroupService.getInstance()
        .getSupergroupMembers(Math.abs(this.chatId), 'supergroupMembersFilterAdministrators', 0, 100);
      const rawMembers = result.members;
      if (rawMembers && rawMembers.length > 0) {
        this.administrators = [];
        for (const m of rawMembers) {
          const memberId = m.member_id?.user_id || 0;
          const statusRecord = m.status as Record<string, string> | undefined;
          const statusType = statusRecord?.['@type'] || '';
          const role = statusType === 'chatMemberStatusCreator'
            ? getContext(this).resourceManager.getStringByNameSync('owner_role')
            : getContext(this).resourceManager.getStringByNameSync('admin_label');

          let name = '';
          let photoUrl: string | null = null;
          try {
            const user = await UserService.getInstance().getUser(memberId);
            name = `${user.first_name || ''} ${user.last_name || ''}`.trim();
            const photo = user.profile_photo;
            if (photo?.small?.local) {
              const localFile = photo.small.local;
              if (localFile.is_downloading_completed) {
                photoUrl = localFile.path;
              }
            }
          } catch (e) {
            hilog.warn(0x0001, 'GroupAdminPage', 'Failed to get admin user %{public}d', memberId);
            const fallback = getContext(this).resourceManager.getStringByNameSync('user_fallback');
            name = `${fallback} ${memberId}`;
          }

          this.administrators.push({ userId: memberId, name, role, photoUrl });
        }
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'GroupAdminPage', 'Failed to load admins, using stub data');
    }

    const ownerLabel = getContext(this).resourceManager.getStringByNameSync('owner_role');
    const adminLabel = getContext(this).resourceManager.getStringByNameSync('admin_label');
    this.administrators = [
      { userId: 1, name: 'Alex Johnson', role: ownerLabel, photoUrl: null },
      { userId: 2, name: 'Maria Garcia', role: adminLabel, photoUrl: null }
    ];
  }

  private async loadBannedUsers(): Promise<void> {
    try {
      const result = await GroupService.getInstance()
        .getSupergroupMembers(Math.abs(this.chatId), 'supergroupMembersFilterBanned', 0, 100);
      const rawMembers = result.members;
      if (rawMembers && rawMembers.length > 0) {
        this.bannedUsers = [];
        for (const m of rawMembers) {
          const memberId = m.member_id?.user_id || 0;
          let name = '';
          try {
            const user = await UserService.getInstance().getUser(memberId);
            name = `${user.first_name || ''} ${user.last_name || ''}`.trim();
          } catch (e) {
            hilog.warn(0x0001, 'GroupAdminPage', 'Failed to get banned user %{public}d', memberId);
            const fallback = getContext(this).resourceManager.getStringByNameSync('user_fallback');
            name = `${fallback} ${memberId}`;
          }

          const statusRecord = m.status as Record<string, number> | undefined;
          const bannedUntil = (statusRecord?.['banned_until_date'] || 0) === 0
            ? getContext(this).resourceManager.getStringByNameSync('forever_ban')
            : getContext(this).resourceManager.getStringByNameSync('temporary_ban');
          this.bannedUsers.push({ userId: memberId, name, bannedUntil });
        }
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'GroupAdminPage', 'Failed to load banned users, using stub data');
    }

    this.bannedUsers = [
      { userId: 100, name: 'Spammer Bot', bannedUntil: 'Forever' }
    ];
  }

  private async toggleGroupType(): Promise<void> {
    this.isPublic = !this.isPublic;
    try {
      await GroupService.getInstance()
        .toggleSupergroupIsAllHistoryAvailable(Math.abs(this.chatId), this.isPublic);
    } catch (e) {
      hilog.warn(0x0001, 'GroupAdminPage', 'Failed to toggle group type');
      this.isPublic = !this.isPublic;
    }
  }

  private async savePermissions(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;

    try {
      const permissions: Record<string, Object> = {};
      permissions['@type'] = 'chatPermissions';
      permissions['can_send_basic_messages'] = this.canSendMessages;
      permissions['can_send_audios'] = this.canSendMedia;
      permissions['can_send_documents'] = this.canSendMedia;
      permissions['can_send_photos'] = this.canSendMedia;
      permissions['can_send_videos'] = this.canSendMedia;
      permissions['can_send_video_notes'] = this.canSendMedia;
      permissions['can_send_voice_notes'] = this.canSendMedia;
      permissions['can_send_polls'] = this.canSendPolls;
      permissions['can_send_other_messages'] = this.canSendStickers;
      permissions['can_invite_users'] = this.canAddMembers;
      permissions['can_pin_messages'] = this.canPinMessages;
      permissions['can_change_info'] = this.canChangeInfo;
      await ChatService.getInstance().setChatPermissions(this.chatId, permissions);
    } catch (e) {
      hilog.warn(0x0001, 'GroupAdminPage', 'Failed to save permissions');
    }

    this.isSaving = false;
  }

  build() {
    NavDestination() {
      Column() {
        GroupAdminTopBar({
          isSaving: this.isSaving,
          onBack: () => {
            this.navPathStack.pop();
          },
          onSave: () => {
            this.savePermissions();
          }
        })

        Scroll() {
          Column() {
            GroupAdminHeaderSection({ title: this.title })

            GroupAdminTypeSection({
              isPublic: this.isPublic,
              onToggle: () => {
                this.toggleGroupType();
              }
            })

            Blank().height(24)

            GroupAdminPermissionsSection({
              canSendMessages: this.canSendMessages,
              canSendMedia: this.canSendMedia,
              canSendPolls: this.canSendPolls,
              canSendStickers: this.canSendStickers,
              canAddMembers: this.canAddMembers,
              canPinMessages: this.canPinMessages,
              canChangeInfo: this.canChangeInfo,
              onSendMessagesChange: (isOn: boolean) => {
                this.canSendMessages = isOn;
              },
              onSendMediaChange: (isOn: boolean) => {
                this.canSendMedia = isOn;
              },
              onSendPollsChange: (isOn: boolean) => {
                this.canSendPolls = isOn;
              },
              onSendStickersChange: (isOn: boolean) => {
                this.canSendStickers = isOn;
              },
              onAddMembersChange: (isOn: boolean) => {
                this.canAddMembers = isOn;
              },
              onPinMessagesChange: (isOn: boolean) => {
                this.canPinMessages = isOn;
              },
              onChangeInfoChange: (isOn: boolean) => {
                this.canChangeInfo = isOn;
              }
            })

            Blank().height(24)

            GroupAdminAdminsSection({
              administrators: this.administrators,
              onOpenUser: (userId: number) => {
                const navParam: Record<string, Object> = {};
                navParam['userId'] = userId;
                this.navPathStack.pushPath(new NavPathInfo('UserInfo', navParam));
              }
            })

            Blank().height(24)

            GroupAdminBannedSection({ bannedUsers: this.bannedUsers })

            Blank().height(24)

            GroupAdminRecentActionsSection({
              onOpen: () => {
              }
            })

            Blank().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }
}
