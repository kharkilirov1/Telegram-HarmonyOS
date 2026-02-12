// Group / Channel info page — view info, members, shared media
// Reference: Telegram iOS PeerInfoScreen (group mode), Android ChatActivity GroupInfo
// HarmonyOS: NavDestination, LazyForEach, expandSafeArea

import { MessagesController } from '../../controllers/MessagesController';
import { AuthController } from '../../controllers/AuthController';
import { FileController } from '../../controllers/FileController';
import { GroupService } from '../../services/GroupService';
import { UserService } from '../../services/UserService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GroupInfoActionButton } from './components/GroupInfoActionButton';
import { GroupInfoHeaderSection } from './components/GroupInfoHeaderSection';
import { GroupInfoMember } from './components/GroupInfoModels';
import { GroupInfoMemberRow } from './components/GroupInfoMemberRow';
import { GroupInfoTopBar } from './components/GroupInfoTopBar';

@Builder
export function GroupInfoBuilder(name: string, param: Object) {
  GroupInfoPage({ chatId: (param as Record<string, number>)['chatId'] ?? 0 })
}

@ComponentV2
export struct GroupInfoPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param chatId: number = 0;

  @Local title: string = '';
  @Local description: string = '';
  @Local photoUrl: string | null = null;
  @Local memberCount: number = 0;
  @Local isChannel: boolean = false;
  @Local isGroup: boolean = true;
  @Local isMuted: boolean = false;
  @Local canEditGroupInfo: boolean = false;
  @Local canManageInviteLinks: boolean = false;
  @Local members: GroupInfoMember[] = [];
  @Local scrollY: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadGroupInfo();
  }

  private async loadGroupInfo(): Promise<void> {
    const chat = MessagesController.getInstance().getChat(this.chatId);
    if (chat) {
      this.title = chat.title;
      this.photoUrl = chat.photo;
      this.isChannel = chat.isChannel;
      this.isGroup = chat.isGroup;
      this.isMuted = chat.isMuted;
    }

    await this.loadAdminAccess();

    try {
      const fullInfo = await GroupService.getInstance().getSupergroupFullInfo(Math.abs(this.chatId));
      this.description = fullInfo.description || '';
      this.memberCount = fullInfo.member_count || 0;
    } catch (_e) {
      this.description = '';
      this.memberCount = 0;
    }

    // Load real members from TDLib
    await this.loadMembers();
    if (this.memberCount <= 0) {
      this.memberCount = this.members.length;
    }
  }

  private async loadAdminAccess(): Promise<void> {
    this.canEditGroupInfo = false;
    this.canManageInviteLinks = false;
    try {
      const myUserId = await AuthController.getInstance().fetchMyUserId();
      if (myUserId <= 0) {
        return;
      }

      const result = await GroupService.getInstance()
        .getSupergroupMembers(Math.abs(this.chatId), 'supergroupMembersFilterAdministrators', 0, 200);
      const rawMembers = result.members;
      if (!rawMembers || rawMembers.length === 0) {
        return;
      }

      for (const member of rawMembers) {
        if ((member.member_id?.user_id || 0) !== myUserId) {
          continue;
        }
        const statusRecord = member.status as Record<string, unknown> | undefined;
        const statusType = (statusRecord?.['@type'] as string) || '';
        if (statusType === 'chatMemberStatusCreator') {
          this.canEditGroupInfo = true;
          this.canManageInviteLinks = true;
          return;
        }
        if (statusType === 'chatMemberStatusAdministrator') {
          const rightsRecord = statusRecord?.['rights'] as Record<string, unknown> | undefined;
          const hasExplicitRights = rightsRecord !== undefined ||
            statusRecord?.['can_change_info'] !== undefined ||
            statusRecord?.['can_invite_users'] !== undefined;
          if (hasExplicitRights) {
            const canChange = ((rightsRecord?.['can_change_info'] as boolean) || false) ||
              ((statusRecord?.['can_change_info'] as boolean) || false);
            const canInvite = ((rightsRecord?.['can_invite_users'] as boolean) || false) ||
              ((statusRecord?.['can_invite_users'] as boolean) || false);
            this.canEditGroupInfo = canChange;
            this.canManageInviteLinks = canInvite;
          } else {
            // Old TDLib payloads can omit split rights here.
            this.canEditGroupInfo = true;
            this.canManageInviteLinks = true;
          }
        }
        return;
      }
    } catch (_e) {
      hilog.warn(0x0001, 'GroupInfoPage', 'Failed to resolve admin access for chat %{public}d', this.chatId);
    }
  }

  private async loadMembers(): Promise<void> {
    try {
      const result = await GroupService.getInstance()
        .getSupergroupMembers(Math.abs(this.chatId), 'supergroupMembersFilterRecent', 0, 50);
      const rawMembers = result.members;
      if (rawMembers && rawMembers.length > 0) {
        this.members = [];
        for (const m of rawMembers) {
          const memberId = m.member_id?.user_id || 0;
          const statusRecord = m.status as Record<string, string> | undefined;
          const statusType = statusRecord?.['@type'] || '';
          const isAdmin = statusType === 'chatMemberStatusAdministrator' || statusType === 'chatMemberStatusCreator';

          let name = '';
          let photoUrl: string | null = null;
          let userStatus = 'last seen recently';
          try {
            const user = await UserService.getInstance().getUser(memberId);
            name = `${user.first_name || ''} ${user.last_name || ''}`.trim();
            const photo = user.profile_photo;
            if (photo?.small?.local) {
              const localFile = photo.small.local;
              if (localFile.is_downloading_completed && localFile.path) {
                photoUrl = localFile.path;
              } else if (photo.small.id && photo.small.id > 0) {
                const memberIdx = this.members.length;
                FileController.getInstance().requestFile(photo.small.id, 3, (path: string) => {
                  if (path.length > 0 && memberIdx < this.members.length) {
                    this.members[memberIdx].photoUrl = path;
                    this.members = this.members.slice();
                  }
                });
              }
            }
            const userStatusObj = user.status as Record<string, string> | undefined;
            if (userStatusObj) {
              const st = userStatusObj['@type'] || '';
              if (st === 'userStatusOnline') userStatus = 'online';
              else if (st === 'userStatusRecently') userStatus = 'last seen recently';
              else if (st === 'userStatusLastWeek') userStatus = 'last seen within a week';
              else if (st === 'userStatusLastMonth') userStatus = 'last seen within a month';
              else userStatus = 'last seen a long time ago';
            }
          } catch (e) {
            hilog.warn(0x0001, 'GroupInfoPage', 'Failed to get user %{public}d', memberId);
            name = `User ${memberId}`;
          }

          this.members.push(new GroupInfoMember(memberId, name, userStatus, photoUrl, isAdmin));
        }
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'GroupInfoPage', 'Failed to load members for chat %{public}d', this.chatId);
    }

    this.members = [];
  }

  build() {
    NavDestination() {
      Column() {
        GroupInfoTopBar({
          canEdit: this.canEditGroupInfo,
          onBack: () => {
            this.navPathStack.pop();
          },
          onEdit: () => {
            if (!this.canEditGroupInfo) {
              return;
            }
            const navParam: Record<string, unknown> = {};
            navParam['chatId'] = this.chatId;
            this.navPathStack.pushPath(new NavPathInfo('GroupAdmin', navParam));
          }
        })

        Scroll(this.scroller) {
          Column() {
            GroupInfoHeaderSection({
              title: this.title,
              photoUrl: this.photoUrl,
              isChannel: this.isChannel,
              memberCount: this.memberCount
            })
            .translate({ y: this.scrollY * 0.4 })
            .opacity(Math.max(0.0, 1.0 - this.scrollY / 300))

            Row({ space: 12 }) {
              GroupInfoActionButton({
                icon: $r('app.media.ic_unmute'),
                label: this.isMuted ? $r('app.string.unmute') : $r('app.string.mute'),
                onTap: () => {
                  this.isMuted = !this.isMuted;
                }
              })
              GroupInfoActionButton({
                icon: $r('app.media.ic_search'),
                label: $r('app.string.search_placeholder'),
                onTap: () => {
                  this.navPathStack.pushPath(new NavPathInfo('Search', new Object()));
                }
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ bottom: 24 })
            .translate({ y: this.scrollY * 0.4 })
            .opacity(Math.max(0.0, 1.0 - this.scrollY / 300))

            // --- Description ---
            if (this.description.length > 0) {
              Column() {
                Text(this.description)
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .lineHeight(22)
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(24)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
              .margin({ left: 12, right: 12 })

              Blank().height(16)
            }

            // --- Notifications / Shared media ---
            Column() {
              Row() {
                Image($r('app.media.ic_unmute'))
                  .width(20).height(20)
                  .fillColor($r('app.color.text_secondary'))
                  .margin({ right: 12 })
                Text($r('app.string.notifications_label'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: !this.isMuted })
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange((isOn: boolean) => { this.isMuted = !isOn; })
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 48 })

              Row() {
                Image($r('app.media.ic_photo'))
                  .width(20).height(20)
                  .fillColor($r('app.color.text_secondary'))
                  .margin({ right: 12 })
                Text($r('app.string.profile_shared_media'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Image($r('app.media.ic_forward'))
                  .width(16).height(16)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                const navParam: Record<string, unknown> = {};
                navParam['chatId'] = this.chatId;
                this.navPathStack.pushPath(new NavPathInfo('SharedMedia', navParam));
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(16)

            // --- Admin & Invite Links ---
            if (this.canEditGroupInfo || this.canManageInviteLinks) {
              Column() {
                if (this.canEditGroupInfo) {
                  Row() {
                    Image($r('app.media.ic_edit'))
                      .width(20).height(20)
                      .fillColor($r('app.color.text_secondary'))
                      .margin({ right: 12 })
                    Text($r('app.string.admin_settings'))
                      .fontSize(16)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                    Image($r('app.media.ic_forward'))
                      .width(16).height(16)
                      .fillColor($r('app.color.text_secondary'))
                  }
                  .width('100%').height(48)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => {
                    const navParam: Record<string, unknown> = {};
                    navParam['chatId'] = this.chatId;
                    this.navPathStack.pushPath(new NavPathInfo('GroupAdmin', navParam));
                  })
                  .hoverEffect(HoverEffect.Highlight)
                  .opacity(1.0)
                  .stateStyles({
                    pressed: {
                      .opacity(0.6)
                    },
                    normal: {
                      .opacity(1.0)
                    }
                  })
                }
                if (this.canEditGroupInfo && this.canManageInviteLinks) {
                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 48 })
                }
                if (this.canManageInviteLinks) {
                  Row() {
                    Image($r('app.media.ic_forward'))
                      .width(20).height(20)
                      .fillColor($r('app.color.text_secondary'))
                      .margin({ right: 12 })
                    Text($r('app.string.invite_links'))
                      .fontSize(16)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                    Image($r('app.media.ic_forward'))
                      .width(16).height(16)
                      .fillColor($r('app.color.text_secondary'))
                  }
                  .width('100%').height(48)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => {
                    const navParam: Record<string, unknown> = {};
                    navParam['chatId'] = this.chatId;
                    this.navPathStack.pushPath(new NavPathInfo('InviteLinks', navParam));
                  })
                }
              }
              .width('100%')
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(24)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
              .margin({ left: 12, right: 12 })

              Blank().height(16)
            }

            // --- Members list ---
            if (!this.isChannel) {
              Column() {
                // Header: Members (count) + Add member
                Row() {
                  Text(`Members (${this.memberCount > 0 ? this.memberCount : this.members.length})`)
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))

                    .layoutWeight(1)

                  if (this.canManageInviteLinks) {
                    Text($r('app.string.add'))
                      .fontSize(14)
                      .fontColor($r('app.color.telegram_blue'))
                  }
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 8 })

                // Search members
                Row() {
                  Image($r('app.media.ic_search'))
                    .width(16).height(16)
                    .fillColor($r('app.color.text_secondary'))
                    .margin({ right: 8 })
                  Text($r('app.string.search_members'))
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')
                .height(36)
                .padding({ left: 16, right: 16 })
                .margin({ left: 16, right: 16, bottom: 4 })
                .backgroundColor($r('app.color.search_bar_bg'))
                .borderRadius(10)

                // Member rows
                ForEach(this.members, (member: GroupInfoMember, index: number) => {
                  if (index > 0) {
                    Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 68 })
                  }
                  GroupInfoMemberRow({
                    member: member,
                    onOpenUser: (userId: number) => {
                      const navParam: Record<string, unknown> = {};
                      navParam['userId'] = userId;
                      this.navPathStack.pushPath(new NavPathInfo('UserInfo', navParam));
                    }
                  })
                }, (member: GroupInfoMember) => member.userId.toString())
              }
              .width('100%')
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(24)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
              .margin({ left: 12, right: 12 })
            }

            Blank().height(16)

            // --- Leave / Report ---
            Column() {
              Text(this.isChannel ? $r('app.string.leave_channel') : $r('app.string.leave_group'))
                .fontSize(16)
                .fontColor($r('app.color.error_red'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(48)

              Divider().strokeWidth(0.5).color($r('app.color.separator'))

              Text($r('app.string.report'))
                .fontSize(16)
                .fontColor($r('app.color.error_red'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(48)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .onDidScroll(() => {
          this.scrollY = this.scroller.currentOffset().yOffset;
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }

}
