// User info page — view other user's profile
// Reference: Telegram iOS PeerInfoScreen, Android ProfileActivity
// HarmonyOS: NavDestination, expandSafeArea, pageTransition

import { TDLibClient } from '../../services/TDLibClient';
import { User } from '../../models/User';
import { CallsController } from '../../controllers/CallsController';
import { formatLastSeen } from '../../components/Common/AvatarWithStatus';

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
  @Local isBlocked: boolean = false;
  @Local commonGroupsCount: number = 0;

  aboutToAppear(): void {
    this.loadUserInfo();
  }

  private async loadUserInfo(): Promise<void> {
    try {
      const getUserParams: Record<string, Object> = {};
      getUserParams['user_id'] = this.userId;
      const result = await TDLibClient.getInstance().send('getUser', getUserParams);
      this.firstName = (result['first_name'] as string) || 'User';
      this.lastName = (result['last_name'] as string) || '';
      this.username = (result['username'] as string) || '';
      this.phoneNumber = (result['phone_number'] as string) || '';

      // Get user full info (bio, common groups)
      const getFullInfoParams: Record<string, Object> = {};
      getFullInfoParams['user_id'] = this.userId;
      const fullInfo = await TDLibClient.getInstance().send('getUserFullInfo', getFullInfoParams);
      this.bio = (fullInfo['bio'] as string) || '';
      this.commonGroupsCount = (fullInfo['group_in_common_count'] as number) || 0;
    } catch (e) {
      // Stub defaults
      this.firstName = 'Alex';
      this.lastName = 'Johnson';
      this.username = 'alexj';
      this.phoneNumber = '+1 555 123 4567';
      this.bio = 'Life is what happens when you are busy making other plans.';
      this.commonGroupsCount = 3;
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
            .width(22).height(22)
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

              Text(this.isOnline ? 'online' : formatLastSeen(false, this.lastSeenDate))
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
              this.actionButton($r('app.media.ic_group'), 'Message', () => {
                this.navPathStack.pop();
              })
              this.actionButton($r('app.media.ic_phone_call'), 'Call', () => {
                CallsController.getInstance().startCall(this.userId, false);
              })
              this.actionButton($r('app.media.ic_settings'), 'Video', () => {
                CallsController.getInstance().startCall(this.userId, true);
              })
              this.actionButton($r('app.media.ic_unmute'), 'Mute', () => {})
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
                    .fontSize(13)
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
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(16)

            // --- Notifications / Shared media ---
            Column() {
              Row() {
                Image($r('app.media.ic_unmute'))
                  .width(20).height(20)
                  .fillColor($r('app.color.text_secondary'))
                  .margin({ right: 12 })
                Text('Notifications')
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: true })
                  .selectedColor($r('app.color.telegram_blue'))
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
                navParam['chatId'] = this.userId;
                this.navPathStack.pushPath(new NavPathInfo('SharedMedia', navParam));
              })

              // Common groups
              if (this.commonGroupsCount > 0) {
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 48 })
                Row() {
                  Image($r('app.media.ic_group'))
                    .width(20).height(20)
                    .fillColor($r('app.color.text_secondary'))
                    .margin({ right: 12 })
                  Text(`${this.commonGroupsCount} Groups in Common`)
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                  Image($r('app.media.ic_forward'))
                    .width(14).height(14)
                    .fillColor($r('app.color.text_secondary'))
                }
                .width('100%').height(48)
                .padding({ left: 16, right: 16 })
              }
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(16)

            // --- Block user ---
            Column() {
              Text(this.isBlocked ? 'Unblock User' : 'Block User')
                .fontSize(16)
                .fontColor($r('app.color.error_red'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(48)
                .onClick(() => {
                  this.isBlocked = !this.isBlocked;
                })
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
  actionButton(icon: Resource, label: string, onTap: () => void) {
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
  infoRow(label: Resource, value: string) {
    Column() {
      Text(label)
        .fontSize(13)
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
}
