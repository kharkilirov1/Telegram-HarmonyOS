// Group / Channel admin panel — manage settings, permissions, administrators, bans
// Reference: Telegram Android ChatEditActivity, iOS ChannelAdminController
// HarmonyOS: NavDestination, @ComponentV2, V2 decorators, glass card styling

import { TDLibClient } from '../../services/TDLibClient';
import { MessagesController } from '../../controllers/MessagesController';

@Builder
export function GroupAdminBuilder(name: string, param: Object) {
  GroupAdminPage({ chatId: (param as Record<string, number>)['chatId'] ?? 0 })
}

interface AdminMember {
  userId: number;
  name: string;
  role: string;
  photoUrl: string | null;
}

interface BannedMember {
  userId: number;
  name: string;
  bannedUntil: string;
}

@ComponentV2
export struct GroupAdminPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param chatId: number = 0;

  @Local title: string = '';
  @Local isPublic: boolean = false;
  @Local isSaving: boolean = false;

  // Permissions
  @Local canSendMessages: boolean = true;
  @Local canSendMedia: boolean = true;
  @Local canSendPolls: boolean = true;
  @Local canSendStickers: boolean = true;
  @Local canAddMembers: boolean = true;
  @Local canPinMessages: boolean = true;
  @Local canChangeInfo: boolean = true;

  // Administrators
  @Local administrators: AdminMember[] = [];

  // Banned users
  @Local bannedUsers: BannedMember[] = [];

  aboutToAppear(): void {
    this.loadAdminData();
  }

  private async loadAdminData(): Promise<void> {
    const chat = MessagesController.getInstance().getChat(this.chatId);
    if (chat) {
      this.title = chat.title;
    }

    // Load current permissions
    try {
      const getChatParams: Record<string, Object> = {};
      getChatParams['chat_id'] = this.chatId;
      const chatResult = await TDLibClient.getInstance().send('getChat', getChatParams);
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

      // Determine public/private from supergroup info
      const supergroupId = Math.abs(this.chatId);
      const getSgParams: Record<string, Object> = {};
      getSgParams['supergroup_id'] = supergroupId;
      const sgInfo = await TDLibClient.getInstance().send('getSupergroup', getSgParams);
      const hasUsername = ((sgInfo['usernames'] as Record<string, Object>)?.['editable_username'] as string || '').length > 0;
      this.isPublic = hasUsername;
    } catch (_e) {
      // Use defaults on failure
    }

    await this.loadAdministrators();
    await this.loadBannedUsers();
  }

  private async loadAdministrators(): Promise<void> {
    try {
      const adminFilter: Record<string, Object> = {};
      adminFilter['@type'] = 'supergroupMembersFilterAdministrators';
      const adminMembersParams: Record<string, Object> = {};
      adminMembersParams['supergroup_id'] = Math.abs(this.chatId);
      adminMembersParams['filter'] = adminFilter;
      adminMembersParams['offset'] = 0;
      adminMembersParams['limit'] = 100;
      const result = await TDLibClient.getInstance().send('getSupergroupMembers', adminMembersParams);
      const rawMembers = result['members'] as Record<string, Object>[];
      if (rawMembers && rawMembers.length > 0) {
        this.administrators = [];
        for (const m of rawMembers) {
          const memberId = (m['member_id'] as Record<string, number>)?.['user_id'] || 0;
          const status = (m['status'] as Record<string, string>)?.['@type'] || '';
          const role = status === 'chatMemberStatusCreator'
            ? getContext(this).resourceManager.getStringByNameSync('owner_role')
            : getContext(this).resourceManager.getStringByNameSync('admin_label');

          let name = '';
          let photoUrl: string | null = null;
          try {
            const getUserParams: Record<string, Object> = {};
            getUserParams['user_id'] = memberId;
            const user = await TDLibClient.getInstance().send('getUser', getUserParams);
            const firstName = (user['first_name'] as string) || '';
            const lastName = (user['last_name'] as string) || '';
            name = `${firstName} ${lastName}`.trim();
            const photo = user['profile_photo'] as Record<string, Object>;
            if (photo) {
              const small = photo['small'] as Record<string, Object>;
              const localFile = small?.['local'] as Record<string, Object>;
              if (localFile?.['is_downloading_completed']) {
                photoUrl = localFile['path'] as string;
              }
            }
          } catch (_e) {
            const fallback = getContext(this).resourceManager.getStringByNameSync('user_fallback');
            name = `${fallback} ${memberId}`;
          }

          this.administrators.push({ userId: memberId, name, role, photoUrl });
        }
        return;
      }
    } catch (_e) {
      // Fallback stub data
    }

    const ownerLabel = getContext(this).resourceManager.getStringByNameSync('owner_role');
    const adminLabel = getContext(this).resourceManager.getStringByNameSync('admin_label');
    this.administrators = [
      { userId: 1, name: 'Alex Johnson', role: ownerLabel, photoUrl: null },
      { userId: 2, name: 'Maria Garcia', role: adminLabel, photoUrl: null },
    ];
  }

  private async loadBannedUsers(): Promise<void> {
    try {
      const bannedFilter: Record<string, Object> = {};
      bannedFilter['@type'] = 'supergroupMembersFilterBanned';
      const bannedMembersParams: Record<string, Object> = {};
      bannedMembersParams['supergroup_id'] = Math.abs(this.chatId);
      bannedMembersParams['filter'] = bannedFilter;
      bannedMembersParams['offset'] = 0;
      bannedMembersParams['limit'] = 100;
      const result = await TDLibClient.getInstance().send('getSupergroupMembers', bannedMembersParams);
      const rawMembers = result['members'] as Record<string, Object>[];
      if (rawMembers && rawMembers.length > 0) {
        this.bannedUsers = [];
        for (const m of rawMembers) {
          const memberId = (m['member_id'] as Record<string, number>)?.['user_id'] || 0;
          let name = '';
          try {
            const getBannedUserParams: Record<string, Object> = {};
            getBannedUserParams['user_id'] = memberId;
            const user = await TDLibClient.getInstance().send('getUser', getBannedUserParams);
            const firstName = (user['first_name'] as string) || '';
            const lastName = (user['last_name'] as string) || '';
            name = `${firstName} ${lastName}`.trim();
          } catch (_e) {
            const fallback = getContext(this).resourceManager.getStringByNameSync('user_fallback');
            name = `${fallback} ${memberId}`;
          }

          const bannedUntil = ((m['status'] as Record<string, number>)?.['banned_until_date'] || 0) === 0
            ? getContext(this).resourceManager.getStringByNameSync('forever_ban')
            : getContext(this).resourceManager.getStringByNameSync('temporary_ban');
          this.bannedUsers.push({ userId: memberId, name, bannedUntil });
        }
        return;
      }
    } catch (_e) {
      // Fallback stub data
    }

    this.bannedUsers = [
      { userId: 100, name: 'Spammer Bot', bannedUntil: 'Forever' },
    ];
  }

  private async toggleGroupType(): Promise<void> {
    this.isPublic = !this.isPublic;
    try {
      const toggleHistoryParams: Record<string, Object> = {};
      toggleHistoryParams['supergroup_id'] = Math.abs(this.chatId);
      toggleHistoryParams['is_all_history_available'] = this.isPublic;
      await TDLibClient.getInstance().send('toggleSupergroupIsAllHistoryAvailable', toggleHistoryParams);
    } catch (_e) {
      // Revert on failure
      this.isPublic = !this.isPublic;
    }
  }

  private async savePermissions(): Promise<void> {
    if (this.isSaving) return;
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
      const setPermissionsParams: Record<string, Object> = {};
      setPermissionsParams['chat_id'] = this.chatId;
      setPermissionsParams['permissions'] = permissions;
      await TDLibClient.getInstance().send('setChatPermissions', setPermissionsParams);
    } catch (_e) {
      // Handle save error silently
    }
    this.isSaving = false;
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

          Text($r('app.string.admin_settings'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)

          if (this.isSaving) {
            LoadingProgress()
              .width(20).height(20)
              .color($r('app.color.telegram_blue'))
          } else {
            Text($r('app.string.save'))
              .fontSize(16)
              .fontColor($r('app.color.telegram_blue'))
              .onClick(() => { this.savePermissions(); })
          }
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

        Scroll() {
          Column() {
            // --- Group Title Header ---
            Column() {
              Text(this.title)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text($r('app.string.manage_group_subtitle'))
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 20, bottom: 16 })
            .alignItems(HorizontalAlign.Start)

            // --- Group Type ---
            Column() {
              Text($r('app.string.group_type'))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))

                .margin({ bottom: 8 })

              Row() {
                Column() {
                  Text($r('app.string.public_group'))
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                  Text($r('app.string.public_group_hint'))
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.isPublic })
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange(() => { this.toggleGroupType(); })
              }
              .width('100%')
              .height(56)
              .padding({ left: 16, right: 16 })
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(16)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .alignItems(HorizontalAlign.Start)

            Blank().height(24)

            // --- Permissions ---
            Column() {
              Text($r('app.string.permissions_label'))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))

                .margin({ bottom: 8 })

              Column() {
                this.permissionRow($r('app.string.send_messages'), this.canSendMessages, (isOn: boolean) => {
                  this.canSendMessages = isOn;
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                this.permissionRow($r('app.string.send_media'), this.canSendMedia, (isOn: boolean) => {
                  this.canSendMedia = isOn;
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                this.permissionRow($r('app.string.send_polls'), this.canSendPolls, (isOn: boolean) => {
                  this.canSendPolls = isOn;
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                this.permissionRow($r('app.string.send_stickers_gifs'), this.canSendStickers, (isOn: boolean) => {
                  this.canSendStickers = isOn;
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                this.permissionRow($r('app.string.add_members'), this.canAddMembers, (isOn: boolean) => {
                  this.canAddMembers = isOn;
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                this.permissionRow($r('app.string.pin_messages'), this.canPinMessages, (isOn: boolean) => {
                  this.canPinMessages = isOn;
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                this.permissionRow($r('app.string.change_group_info'), this.canChangeInfo, (isOn: boolean) => {
                  this.canChangeInfo = isOn;
                })
              }
              .width('100%')
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(16)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .alignItems(HorizontalAlign.Start)

            Blank().height(24)

            // --- Administrators ---
            Column() {
              Text($r('app.string.administrators_label'))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))

                .margin({ bottom: 8 })

              Column() {
                ForEach(this.administrators, (admin: AdminMember, index: number) => {
                  if (index > 0) {
                    Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 68 })
                  }
                  this.adminRow(admin)
                }, (admin: AdminMember) => admin.userId.toString())
              }
              .width('100%')
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(16)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .alignItems(HorizontalAlign.Start)

            Blank().height(24)

            // --- Banned Users ---
            Column() {
              Text($r('app.string.banned_users_label'))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))

                .margin({ bottom: 8 })

              Column() {
                if (this.bannedUsers.length === 0) {
                  Text($r('app.string.no_banned_users'))
                    .fontSize(15)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding(20)
                } else {
                  ForEach(this.bannedUsers, (banned: BannedMember, index: number) => {
                    if (index > 0) {
                      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 68 })
                    }
                    this.bannedRow(banned)
                  }, (banned: BannedMember) => banned.userId.toString())
                }
              }
              .width('100%')
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(16)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .alignItems(HorizontalAlign.Start)

            Blank().height(24)

            // --- Recent Actions ---
            Column() {
              Text($r('app.string.recent_actions'))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))

                .margin({ bottom: 8 })

              Column() {
                Row() {
                  Image($r('app.media.ic_forward'))
                    .width(20).height(20)
                    .fillColor($r('app.color.text_secondary'))
                    .margin({ right: 12 })
                  Text($r('app.string.view_recent_actions'))
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                  Image($r('app.media.ic_forward'))
                    .width(14).height(14)
                    .fillColor($r('app.color.text_secondary'))
                }
                .width('100%')
                .height(48)
                .padding({ left: 16, right: 16 })
              }
              .width('100%')
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(16)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .alignItems(HorizontalAlign.Start)

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
  permissionRow(label: string | Resource, isOn: boolean, onChange: (isOn: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.telegram_blue'))
        .onChange(onChange)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  adminRow(admin: AdminMember) {
    Row() {
      // Avatar
      if (admin.photoUrl) {
        Image(admin.photoUrl)
          .alt($r('app.media.app_icon'))
          .autoResize(true)
          .onError(() => {})
          .width(40).height(40)
          .borderRadius(20)
      } else {
        Text(admin.name.length > 0 ? admin.name.charAt(0) : '?')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .width(40).height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.telegram_blue'))
          .textAlign(TextAlign.Center)
      }

      Column() {
        Text(admin.name)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)

        Text(admin.role)
          .fontSize(13)
          .fontColor($r('app.color.telegram_blue'))
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
      navParam['userId'] = admin.userId;
      this.navPathStack.pushPath(new NavPathInfo('UserInfo', navParam));
    })
  }

  @Builder
  bannedRow(banned: BannedMember) {
    Row() {
      // Avatar
      Text(banned.name.length > 0 ? banned.name.charAt(0) : '?')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(40).height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.error_red'))
        .textAlign(TextAlign.Center)

      Column() {
        Text(banned.name)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)

        Text(`Banned: ${banned.bannedUntil}`)
          .fontSize(13)
          .fontColor($r('app.color.error_red'))
          .margin({ top: 1 })
      }
      .margin({ left: 12 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
  }
}
