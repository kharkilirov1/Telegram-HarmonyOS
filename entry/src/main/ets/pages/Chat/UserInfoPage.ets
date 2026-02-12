// User info page — view other user's profile
// Reference: Telegram iOS PeerInfoScreen, Android ProfileActivity
// HarmonyOS: NavDestination, expandSafeArea, pageTransition

import { UserService } from '../../services/UserService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { User } from '../../models/User';
import { CallsController } from '../../controllers/CallsController';
import { ChatService } from '../../services/ChatService';
import { FileController } from '../../controllers/FileController';
import { GroupService } from '../../services/GroupService';
import { formatLastSeen } from '../../components/Common/AvatarWithStatus';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { ContactsController } from '../../controllers/ContactsController';

@Builder
export function UserInfoBuilder(name: string, param: Object) {
  UserInfoPage({ userId: (param as Record<string, number>)['userId'] ?? 0 })
}

@ComponentV2
export struct UserInfoPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param userId: number = 0;

  @Local firstName: string = '';
  @Local lastName: string = '';
  @Local username: string = '';
  @Local phoneNumber: string = '';
  @Local bio: string = '';
  @Local photoUrl: string | null = null;
  @Local isOnline: boolean = false;
  @Local lastSeenDate: number = 0;
  @Local notificationsEnabled: boolean = true;
  @Local commonGroupsCount: number = 0;
  @Local privateChatId: number = 0;

  private userInfoUpdatedHandler = (args?: Record<string, unknown>): void => {
    const updatedUserId = args ? ((args['userId'] as number) || 0) : 0;
    if (updatedUserId !== this.userId) return;
    this.applyCachedUser();
    this.applyCachedFullInfo();
  };

  private userStatusUpdatedHandler = (args?: Record<string, unknown>): void => {
    const updatedUserId = args ? ((args['userId'] as number) || 0) : 0;
    if (updatedUserId !== this.userId) return;
    this.applyCachedUser();
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.USER_INFO_UPDATED, this.userInfoUpdatedHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.USER_STATUS_UPDATED, this.userStatusUpdatedHandler);
    this.loadUserInfo();
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.USER_INFO_UPDATED, this.userInfoUpdatedHandler);
    NotificationCenter.getInstance()
      .removeObserver(EventId.USER_STATUS_UPDATED, this.userStatusUpdatedHandler);
  }

  private applyCachedUser(): boolean {
    const user: User | undefined = ContactsController.getInstance().getUser(this.userId);
    if (!user) return false;

    this.firstName = user.firstName;
    this.lastName = user.lastName;
    this.username = user.username;
    this.phoneNumber = user.phoneNumber;
    this.photoUrl = user.photoUrl;
    this.isOnline = user.isOnline;
    this.lastSeenDate = user.lastSeenDate;
    return true;
  }

  private applyCachedFullInfo(): boolean {
    const fullInfo = ContactsController.getInstance().getUserFullInfo(this.userId);
    if (!fullInfo) return false;

    const bio = fullInfo['bio'] as Record<string, unknown> | undefined;
    this.bio = bio ? ((bio['text'] as string) || '') : '';
    this.commonGroupsCount = (fullInfo['group_in_common_count'] as number) || 0;
    return true;
  }

  private async loadUserInfo(): Promise<void> {
    const hasCachedUser: boolean = this.applyCachedUser();
    const hasCachedFullInfo: boolean = this.applyCachedFullInfo();

    try {
      if (!hasCachedUser) {
        const result = await UserService.getInstance().getUser(this.userId);
        this.firstName = result.first_name || '';
        this.lastName = result.last_name || '';
        this.username = result.username || '';
        this.phoneNumber = result.phone_number || '';
        const userPhoto = result.profile_photo;
        if (userPhoto?.small?.local?.is_downloading_completed && userPhoto.small.local.path) {
          this.photoUrl = userPhoto.small.local.path;
        } else if (userPhoto?.small?.id && userPhoto.small.id > 0) {
          this.photoUrl = null;
          FileController.getInstance().requestFile(userPhoto.small.id, 5, (path: string) => {
            if (path.length > 0) {
              this.photoUrl = path;
            }
          });
        } else {
          this.photoUrl = null;
        }

        const status = result.status as Record<string, unknown> | undefined;
        if (status) {
          const statusType = (status['@type'] as string) || '';
          this.isOnline = statusType === 'userStatusOnline';
          this.lastSeenDate = statusType === 'userStatusOffline'
            ? ((status['was_online'] as number) || 0)
            : 0;
        } else {
          this.isOnline = false;
          this.lastSeenDate = 0;
        }
      }

      if (!hasCachedFullInfo) {
        const fullInfo = await UserService.getInstance().getUserFullInfo(this.userId);
        this.bio = fullInfo.bio?.text || '';
        this.commonGroupsCount = fullInfo.group_in_common_count || 0;
      }
      await this.syncNotificationState();
    } catch (e) {
      hilog.warn(0x0001, 'UserInfoPage', 'Failed to load user info');
      if (!hasCachedUser) {
        this.firstName = '';
        this.lastName = '';
        this.username = '';
        this.phoneNumber = '';
        this.photoUrl = null;
        this.isOnline = false;
        this.lastSeenDate = 0;
      }
      if (!hasCachedFullInfo) {
        this.bio = '';
        this.commonGroupsCount = 0;
      }
    }
  }

  private async ensurePrivateChatId(): Promise<number> {
    if (this.privateChatId > 0) {
      return this.privateChatId;
    }
    try {
      const chatId = await ChatService.getInstance().createPrivateChat(this.userId);
      this.privateChatId = chatId > 0 ? chatId : 0;
    } catch (_e) {
      this.privateChatId = 0;
    }
    return this.privateChatId;
  }

  private async syncNotificationState(): Promise<void> {
    try {
      const chatId = await this.ensurePrivateChatId();
      if (chatId <= 0) {
        this.notificationsEnabled = true;
        return;
      }
      const chatResult = await GroupService.getInstance().getChat(chatId);
      const settings = chatResult['notification_settings'] as Record<string, unknown> | undefined;
      const muteFor = settings ? ((settings['mute_for'] as number) || 0) : 0;
      this.notificationsEnabled = muteFor <= 0;
    } catch (_e) {
      this.notificationsEnabled = true;
    }
  }

  private async openPrivateChat(): Promise<void> {
    try {
      const chatId = await this.ensurePrivateChatId();
      if (chatId > 0) {
        this.navPathStack.pushPath(new NavPathInfo('ChatDetail', chatId));
      }
    } catch (_e) {
      hilog.warn(0x0001, 'UserInfoPage', 'Failed to open private chat for %{public}d', this.userId);
    }
  }

  private async toggleNotifications(isOn: boolean): Promise<void> {
    this.notificationsEnabled = isOn;
    try {
      const chatId = await this.ensurePrivateChatId();
      if (chatId <= 0) {
        return;
      }
      if (isOn) {
        await ChatService.getInstance().unmuteChat(chatId);
      } else {
        // 10 years mute like Telegram "mute forever"
        await ChatService.getInstance().muteChat(chatId, 315360000);
      }
    } catch (_e) {
      this.notificationsEnabled = !isOn;
    }
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar with back and more
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Blank()

          Image($r('app.media.ic_more'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
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
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Scroll() {
          Column() {
            // --- Avatar + name header (like iOS PeerInfoScreen) ---
            Column() {
              if (this.photoUrl) {
                Image(this.photoUrl)
                  .alt($r('app.media.app_icon'))
                  .autoResize(true)
                  .onError(() => {})
                  .width(100).height(100)
                  .borderRadius(50)
              } else {
                Text(this.firstName.length > 0 ? this.firstName.charAt(0) : '?')
                  .fontSize(36)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                  .width(100).height(100)
                  .borderRadius(50)
                  .backgroundColor($r('app.color.telegram_blue'))
                  .textAlign(TextAlign.Center)
              }

              Text(`${this.firstName} ${this.lastName}`.trim())
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 12 })

              Text(this.isOnline ? $r('app.string.online') : formatLastSeen(false, this.lastSeenDate))
                .fontSize(14)
                .fontColor(this.isOnline
                  ? $r('app.color.online_indicator')
                  : $r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
            .width('100%')
            .padding({ top: 24, bottom: 24 })
            .alignItems(HorizontalAlign.Center)

            // --- Action buttons row (like Telegram iOS: Message, Audio, Video, More) ---
            Row({ space: 12 }) {
              this.actionButton($r('app.media.ic_group'), $r('app.string.message_action'), () => {
                void this.openPrivateChat();
              })
              this.actionButton($r('app.media.ic_phone_call'), $r('app.string.call_action'), () => {
                CallsController.getInstance().startCall(this.userId, false);
              })
              this.actionButton($r('app.media.ic_settings'), $r('app.string.calls_video_label'), () => {
                CallsController.getInstance().startCall(this.userId, true);
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ bottom: 24 })

            // --- Info section ---
            Column() {
              // Phone
              if (this.phoneNumber.length > 0) {
                this.infoRow($r('app.string.profile_phone'), this.phoneNumber)
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              }

              // Username
              if (this.username.length > 0) {
                this.infoRow($r('app.string.profile_username'), `@${this.username}`)
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              }

              // Bio
              if (this.bio.length > 0) {
                Column() {
                  Text($r('app.string.profile_bio'))
                    .fontSize(14)
                    .fontColor($r('app.color.telegram_blue'))
                  Text(this.bio)
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .margin({ top: 2 })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .alignItems(HorizontalAlign.Start)
              }
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(16)

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
                Toggle({ type: ToggleType.Switch, isOn: this.notificationsEnabled })
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange((isOn: boolean) => {
                    this.toggleNotifications(isOn);
                  })
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
                void this.openSharedMedia();
              })

              // Common groups
              if (this.commonGroupsCount > 0) {
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 48 })
                Row() {
                  Image($r('app.media.ic_group'))
                    .width(20).height(20)
                    .fillColor($r('app.color.text_secondary'))
                    .margin({ right: 12 })
                  Text(this.formatCommonGroupsLabel())
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                  Image($r('app.media.ic_forward'))
                    .width(16).height(16)
                    .fillColor($r('app.color.text_secondary'))
                }
                .width('100%').height(48)
                .padding({ left: 16, right: 16 })
              }
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
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  actionButton(icon: Resource, label: Resource, onTap: () => void) {
    Column() {
      Column() {
        Image(icon)
          .width(24).height(24)
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
  infoRow(label: Resource, value: string) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.telegram_blue'))
      Text(value)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 2 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  private formatCommonGroupsLabel(): string {
    const template = this.getString('groups_in_common', '%d Groups in Common');
    return template.replace('%d', this.commonGroupsCount.toString());
  }

  private async openSharedMedia(): Promise<void> {
    try {
      const chatId = await this.ensurePrivateChatId();
      if (chatId <= 0) {
        return;
      }
      const navParam: Record<string, unknown> = {};
      navParam['chatId'] = chatId;
      this.navPathStack.pushPath(new NavPathInfo('SharedMedia', navParam));
    } catch (_e) {
      // Ignore navigation failure.
    }
  }

  private getString(name: string, fallback: string): string {
    try {
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (_e) {
      return fallback;
    }
  }
}
