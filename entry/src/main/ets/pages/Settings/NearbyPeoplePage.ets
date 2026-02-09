// NearbyPeoplePage — discover users and groups nearby
// Reference: Telegram iOS PeopleNearbyController, Android PeopleNearbyActivity

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatService } from '../../services/ChatService';
import { TdChatsNearby, TdNearbyChat } from '../../models/TdTypes';

@Builder
export function NearbyPeopleBuilder(name: string, param: Object) {
  NearbyPeoplePage()
}

interface NearbyUser {
  userId: number;
  name: string;
  initial: string;
  distance: number;
}

interface NearbyChat {
  chatId: number;
  title: string;
  initial: string;
  membersCount: number;
  distance: number;
}

@ComponentV2
export struct NearbyPeoplePage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local nearbyUsers: NearbyUser[] = [];
  @Local nearbyGroups: NearbyChat[] = [];
  @Local isVisible: boolean = false;
  @Local isLoading: boolean = false;
  @Local locationPermissionGranted: boolean = false;

  aboutToAppear(): void {
    this.searchNearby();
  }

  private async searchNearby(): Promise<void> {
    this.isLoading = true;

    try {
      const result: TdChatsNearby = await ChatService.getInstance().searchChatsNearby(0.0, 0.0);

      // Parse nearby users
      const rawUsers = result.users_nearby;
      if (rawUsers) {
        this.nearbyUsers = rawUsers.map((u: TdNearbyChat): NearbyUser => {
          const user: NearbyUser = {
            userId: u.user_id || u.chat_id || 0,
            name: '',
            initial: '?',
            distance: u.distance || 0
          };
          return user;
        });
      }

      // Parse nearby groups
      const rawGroups = result.supergroups_nearby;
      if (rawGroups) {
        this.nearbyGroups = rawGroups.map((g: TdNearbyChat): NearbyChat => {
          const group: NearbyChat = {
            chatId: g.chat_id || 0,
            title: '',
            initial: '?',
            membersCount: 0,
            distance: g.distance || 0
          };
          return group;
        });
      }
    } catch (e) {
      hilog.warn(0x0001, 'NearbyPeoplePage', 'Failed to search chats nearby');
    }

    this.isLoading = false;
  }

  private formatDistance(meters: number): string {
    if (meters < 1000) {
      return `${meters} m`;
    }
    return `${(meters / 1000).toFixed(1)} km`;
  }

  build() {
    NavDestination() {
      Column() {
        // Title bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())
            .accessibilityText($r('app.string.accessibility_back'))

          Text($r('app.string.nearby_people'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))

        Scroll() {
          Column() {
            // Description
            Text($r('app.string.nearby_subtitle'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .padding({ left: 24, right: 24, top: 24, bottom: 16 })

            // Make visible toggle
            Column() {
              Row() {
                Text($r('app.string.nearby_make_visible'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.isVisible })
                  .onChange((isOn: boolean) => { this.isVisible = isOn; })
                  .selectedColor($r('app.color.telegram_blue'))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            }
            .backgroundColor($r('app.color.glass_card_bg'))
            .borderRadius(16)
            .margin({ left: 16, right: 16 })

            // Users nearby section
            if (this.nearbyUsers.length > 0) {
              Text($r('app.string.nearby_users'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 32, top: 24, bottom: 8 })
                .width('100%')

              Column() {
                ForEach(this.nearbyUsers, (user: NearbyUser, index: number) => {
                  Row() {
                    Text(user.initial)
                      .fontSize(18)
                      .fontColor($r('app.color.icon_on_primary'))
                      .width(40).height(40)
                      .borderRadius(20)
                      .backgroundColor($r('app.color.telegram_blue'))
                      .textAlign(TextAlign.Center)

                    Column() {
                      Text(user.name.length > 0 ? user.name : `User ${user.userId}`)
                        .fontSize(16)
                        .fontColor($r('app.color.text_primary'))

                      Text(this.formatDistance(user.distance))
                        .fontSize(13)
                        .fontColor($r('app.color.text_secondary'))
                        .margin({ top: 2 })
                    }
                    .margin({ left: 12 })
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 10, bottom: 10 })

                  if (index < this.nearbyUsers.length - 1) {
                    Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 68 })
                  }
                }, (user: NearbyUser, index: number) => `nearby_user_${user.userId}_${index}`)
              }
              .backgroundColor($r('app.color.glass_card_bg'))
              .borderRadius(16)
              .margin({ left: 16, right: 16 })
            }

            // Groups nearby section
            Text($r('app.string.nearby_groups'))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
              .padding({ left: 32, top: 24, bottom: 8 })
              .width('100%')

            Column() {
              // Create local group button
              Row() {
                Column() {
                  Image($r('app.media.ic_group'))
                    .width(20).height(20)
                    .fillColor($r('app.color.icon_on_primary'))
                }
                .width(40).height(40)
                .borderRadius(20)
                .backgroundColor($r('app.color.telegram_blue'))
                .justifyContent(FlexAlign.Center)

                Text($r('app.string.nearby_create_group'))
                  .fontSize(16)
                  .fontColor($r('app.color.telegram_blue'))
                  .margin({ left: 12 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })

              if (this.nearbyGroups.length > 0) {
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 68 })

                ForEach(this.nearbyGroups, (group: NearbyChat, index: number) => {
                  Row() {
                    Text(group.initial)
                      .fontSize(18)
                      .fontColor($r('app.color.icon_on_primary'))
                      .width(40).height(40)
                      .borderRadius(20)
                      .backgroundColor($r('app.color.settings_icon_green'))
                      .textAlign(TextAlign.Center)

                    Column() {
                      Text(group.title.length > 0 ? group.title : `Group ${group.chatId}`)
                        .fontSize(16)
                        .fontColor($r('app.color.text_primary'))

                      Text(this.formatDistance(group.distance))
                        .fontSize(13)
                        .fontColor($r('app.color.text_secondary'))
                        .margin({ top: 2 })
                    }
                    .margin({ left: 12 })
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 10, bottom: 10 })

                  if (index < this.nearbyGroups.length - 1) {
                    Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 68 })
                  }
                }, (group: NearbyChat, index: number) => `nearby_group_${group.chatId}_${index}`)
              }
            }
            .backgroundColor($r('app.color.glass_card_bg'))
            .borderRadius(16)
            .margin({ left: 16, right: 16 })

            Blank().height(40)
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }
}
