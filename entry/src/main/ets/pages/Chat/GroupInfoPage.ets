// Group / Channel info page — view info, members, shared media
// Reference: Telegram iOS PeerInfoScreen (group mode), Android ChatActivity GroupInfo
// HarmonyOS: NavDestination, LazyForEach, expandSafeArea

import { MessagesController } from '../../controllers/MessagesController';
import { GroupService } from '../../services/GroupService';
import { UserService } from '../../services/UserService';
import { Chat } from '../../models/Chat';
import { BasicDataSource } from '../../datasources/BasicDataSource';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Builder
export function GroupInfoBuilder(name: string, param: Object) {
  GroupInfoPage({ chatId: (param as Record<string, number>)['chatId'] ?? 0 })
}

interface GroupMember {
  userId: number;
  name: string;
  status: string;
  photoUrl: string | null;
  isAdmin: boolean;
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
  @Local members: GroupMember[] = [];

  private memberDataSource: BasicDataSource<GroupMember> = new BasicDataSource<GroupMember>();

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

    try {
      const fullInfo = await GroupService.getInstance().getSupergroupFullInfo(Math.abs(this.chatId));
      this.description = fullInfo.description || '';
      this.memberCount = fullInfo.member_count || 0;
    } catch (e) {
      // Stub data
      this.description = this.isChannel
        ? 'Official channel for updates and news'
        : 'A group for friends and colleagues';
      this.memberCount = 15;
    }

    // Load real members from TDLib
    await this.loadMembers();
    this.memberDataSource.setData(this.members);
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
              if (localFile.is_downloading_completed) {
                photoUrl = localFile.path;
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

          this.members.push({ userId: memberId, name, status: userStatus, photoUrl, isAdmin });
        }
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'GroupInfoPage', 'Failed to load members, using stub data');
    }

    this.members = [
      { userId: 1, name: 'Alex Johnson', status: 'online', photoUrl: null, isAdmin: true },
      { userId: 2, name: 'Maria Garcia', status: 'last seen recently', photoUrl: null, isAdmin: true },
      { userId: 3, name: 'John Smith', status: 'last seen within a week', photoUrl: null, isAdmin: false },
      { userId: 4, name: 'Emily Davis', status: 'online', photoUrl: null, isAdmin: false },
      { userId: 5, name: 'Robert Wilson', status: 'last seen recently', photoUrl: null, isAdmin: false },
    ];
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .accessibilityText($r('app.string.accessibility_back'))
            .onClick(() => this.navPathStack.pop())

          Blank()

          Text($r('app.string.edit'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

        Scroll() {
          Column() {
            // --- Header: avatar + title + subtitle ---
            Column() {
              if (this.photoUrl) {
                Image(this.photoUrl)
                  .alt($r('app.media.app_icon'))
                  .autoResize(true)
                  .onError(() => {})
                  .width(100).height(100)
                  .borderRadius(50)
              } else {
                Text(this.title.length > 0 ? this.title.charAt(0) : '?')
                  .fontSize(36)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                  .width(100).height(100)
                  .borderRadius(50)
                  .backgroundColor($r('app.color.telegram_blue'))
                  .textAlign(TextAlign.Center)
              }

              Text(this.title)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 12 })

              Text(this.isChannel
                ? `${this.memberCount} subscribers`
                : `${this.memberCount} members`)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
            .width('100%')
            .padding({ top: 24, bottom: 24 })
            .alignItems(HorizontalAlign.Center)

            // --- Action buttons ---
            Row({ space: 12 }) {
              this.actionButton($r('app.media.ic_unmute'),
                this.isMuted ? $r('app.string.unmute') : $r('app.string.mute'), () => {
                this.isMuted = !this.isMuted;
              })
              this.actionButton($r('app.media.ic_search'), $r('app.string.search_placeholder'), () => {
                this.navPathStack.pushPath(new NavPathInfo('Search', new Object()));
              })
              if (!this.isChannel) {
                this.actionButton($r('app.media.ic_phone_call'), $r('app.string.call_action'), () => {})
              }
              this.actionButton($r('app.media.ic_more'), $r('app.string.more_action'), () => {})
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ bottom: 24 })

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
              .borderRadius(16)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
              .margin({ left: 16, right: 16 })

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
                  .width(14).height(14)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                const navParam: Record<string, Object> = {};
                navParam['chatId'] = this.chatId;
                this.navPathStack.pushPath(new NavPathInfo('SharedMedia', navParam));
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(16)

            // --- Admin & Invite Links ---
            Column() {
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
                  .width(14).height(14)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                const navParam: Record<string, Object> = {};
                navParam['chatId'] = this.chatId;
                this.navPathStack.pushPath(new NavPathInfo('GroupAdmin', navParam));
              })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 48 })

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
                  .width(14).height(14)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                const navParam: Record<string, Object> = {};
                navParam['chatId'] = this.chatId;
                this.navPathStack.pushPath(new NavPathInfo('InviteLinks', navParam));
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(16)

            // --- Members list ---
            if (!this.isChannel) {
              Column() {
                // Header: Members (count) + Add member
                Row() {
                  Text(`Members (${this.members.length})`)
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))

                    .layoutWeight(1)

                  Text($r('app.string.add'))
                    .fontSize(14)
                    .fontColor($r('app.color.telegram_blue'))
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
                ForEach(this.members, (member: GroupMember, index: number) => {
                  if (index > 0) {
                    Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 68 })
                  }
                  this.memberRow(member)
                }, (member: GroupMember) => member.userId.toString())
              }
              .width('100%')
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(16)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
              .margin({ left: 16, right: 16 })
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
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

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

  @Builder
  actionButton(icon: Resource, label: ResourceStr, onTap: () => void) {
    Column() {
      Column() {
        Image(icon)
          .width(22).height(22)
          .fillColor($r('app.color.telegram_blue'))
      }
      .width(52).height(52)
      .borderRadius(26)
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .justifyContent(FlexAlign.Center)
      .onClick(onTap)

      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.telegram_blue'))
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  memberRow(member: GroupMember) {
    Row() {
      // Avatar
      Text(member.name.charAt(0))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(40).height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.telegram_blue'))
        .textAlign(TextAlign.Center)

      Column() {
        Row() {
          Text(member.name)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          if (member.isAdmin) {
            Text($r('app.string.admin_label'))
              .fontSize(12)
              .fontColor($r('app.color.telegram_blue'))
          }
        }
        .width('100%')

        Text(member.status)
          .fontSize(13)
          .fontColor(member.status === 'online'
            ? $r('app.color.online_indicator')
            : $r('app.color.text_secondary'))
          .margin({ top: 1 })
      }
      .margin({ left: 12 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      const navParam: Record<string, Object> = {};
      navParam['userId'] = member.userId;
      this.navPathStack.pushPath(new NavPathInfo('UserInfo', navParam));
    })
  }
}
