// Create New Channel page — set channel name/description, then invite members
// Reference: Telegram Android ChannelCreateActivity, iOS ChannelCreateController

import { ContactsController } from '../../controllers/ContactsController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { TDLibClient } from '../../services/TDLibClient';
import { User } from '../../models/User';
import { AvatarWithStatus, formatLastSeen } from '../../components/Common/AvatarWithStatus';
import { BasicDataSource } from '../../datasources/BasicDataSource';

@Builder
export function CreateChannelBuilder(name: string, param: Object) {
  CreateChannelPage()
}

@ComponentV2
export struct CreateChannelPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local step: number = 0; // 0 = channel info, 1 = invite members
  @Local channelName: string = '';
  @Local channelDescription: string = '';
  @Local isPublic: boolean = true;
  @Local publicLink: string = '';
  @Local selectedUserIds: number[] = [];
  @Local searchText: string = '';
  @Local isCreating: boolean = false;

  private contactDataSource: BasicDataSource<User> = new BasicDataSource<User>();

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.CONTACTS_UPDATED, () => { this.refreshContacts(); });
    ContactsController.getInstance().loadContacts();
    this.refreshContacts();
  }

  build() {
    NavDestination() {
      Column() {
        if (this.step === 0) {
          this.buildChannelInfo()
        } else {
          this.buildInviteMembers()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  buildChannelInfo() {
    Column() {
      // Top bar
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .fillColor($r('app.color.telegram_blue'))
          .onClick(() => this.navPathStack.pop())

        Text($r('app.string.new_channel'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
          .layoutWeight(1)

        if (this.channelName.trim().length > 0) {
          Text($r('app.string.next_button'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
            .onClick(() => { this.step = 1; })
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
          // Channel photo + name
          Row() {
            Column() {
              Image($r('app.media.ic_photo'))
                .width(24).height(24)
                .fillColor(Color.White)
            }
            .width(64).height(64)
            .borderRadius(32)
            .backgroundColor($r('app.color.settings_icon_purple'))
            .justifyContent(FlexAlign.Center)
            .margin({ right: 16 })

            TextInput({ placeholder: 'Channel Name', text: this.channelName })
              .fontSize(17)
              .layoutWeight(1)
              .backgroundColor(Color.Transparent)
              .onChange((value: string) => {
                this.channelName = value;
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 8 })

          // Description
          TextArea({ placeholder: 'Description (optional)', text: this.channelDescription })
            .fontSize(15)
            .width('100%')
            .constraintSize({ minHeight: 60, maxHeight: 120 })
            .backgroundColor(Color.Transparent)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.channelDescription = value;
            })

          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ top: 8 })

          // Channel type selection
          Text('Channel Type')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 16, top: 16, bottom: 8 })

          Column() {
            Row() {
              Radio({ value: 'public', group: 'channelType' })
                .checked(this.isPublic)
                .onChange((isChecked: boolean) => {
                  if (isChecked) this.isPublic = true;
                })
                .margin({ right: 12 })

              Column() {
                Text('Public Channel')
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                Text('Anyone can find and join')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })

            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

            Row() {
              Radio({ value: 'private', group: 'channelType' })
                .checked(!this.isPublic)
                .onChange((isChecked: boolean) => {
                  if (isChecked) this.isPublic = false;
                })
                .margin({ right: 12 })

              Column() {
                Text('Private Channel')
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                Text('Only invited members can join')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .backgroundColor($r('app.color.glass_card_bg'))
          .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
          .borderRadius(16)
          .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
          .margin({ left: 16, right: 16 })

          // Public link input
          if (this.isPublic) {
            Text('Public Link')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 16, top: 16, bottom: 8 })

            Row() {
              Text('t.me/')
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))

              TextInput({ placeholder: 'link', text: this.publicLink })
                .fontSize(16)
                .layoutWeight(1)
                .backgroundColor(Color.Transparent)
                .onChange((value: string) => {
                  this.publicLink = value;
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .height(44)
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .margin({ left: 16, right: 16 })
          }

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
  }

  @Builder
  buildInviteMembers() {
    Column() {
      // Top bar
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .fillColor($r('app.color.telegram_blue'))
          .onClick(() => { this.step = 0; })

        Text('Add Members')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
          .layoutWeight(1)

        if (!this.isCreating) {
          Text($r('app.string.create'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
            .onClick(() => { this.createChannel(); })
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

      // Search
      Search({ placeholder: $r('app.string.search_placeholder'), value: this.searchText })
        .width('100%')
        .height(36)
        .margin({ left: 16, right: 16, top: 4, bottom: 4 })
        .onChange((value: string) => {
          this.searchText = value;
          this.refreshContacts();
        })

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Contact list with checkboxes
      List() {
        LazyForEach(this.contactDataSource, (user: User) => {
          ListItem() {
            Row() {
              Checkbox({ name: `ch_${user.id}` })
                .select(this.selectedUserIds.includes(user.id))
                .selectedColor($r('app.color.telegram_blue'))
                .margin({ left: 16, right: 8 })

              AvatarWithStatus({
                photoUrl: user.photoUrl || '',
                initials: this.getUserInitials(user),
                avatarColor: this.getAvatarColor(user.id),
                avatarSize: 44,
                isOnline: user.isOnline,
                showOnlineDot: true
              })
              .margin({ right: 12 })

              Column() {
                Text(`${user.firstName} ${user.lastName}`.trim())
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)

                Text(formatLastSeen(user.isOnline, user.lastSeenDate))
                  .fontSize(14)
                  .fontColor(user.isOnline
                    ? $r('app.color.telegram_blue')
                    : $r('app.color.text_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .height(56)
            .padding({ right: 16 })
            .onClick(() => {
              const idx = this.selectedUserIds.indexOf(user.id);
              if (idx >= 0) {
                this.selectedUserIds = this.selectedUserIds.filter(id => id !== user.id);
              } else {
                this.selectedUserIds = [...this.selectedUserIds, user.id];
              }
            })
          }
        }, (user: User) => `${user.id}_${this.selectedUserIds.includes(user.id)}`)
      }
      .width('100%')
      .layoutWeight(1)
      .cachedCount(5)
      .edgeEffect(EdgeEffect.Spring)

      if (this.isCreating) {
        Column() {
          LoadingProgress()
            .width(40).height(40).color($r('app.color.telegram_blue'))
        }
        .width('100%')
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
  }

  private async createChannel(): Promise<void> {
    if (this.isCreating) return;
    this.isCreating = true;

    try {
      const createChannelParams: Record<string, Object> = {};
      createChannelParams['title'] = this.channelName.trim();
      createChannelParams['is_channel'] = true;
      createChannelParams['description'] = this.channelDescription;
      const result = await TDLibClient.getInstance().send('createNewSupergroupChat', createChannelParams) as Record<string, number>;

      const chatId = result['id'] || 0;
      this.navPathStack.pop();
      if (chatId !== 0) {
        this.navPathStack.pushPath(new NavPathInfo('ChatDetail', chatId));
      }
    } catch (e) {
      this.isCreating = false;
    }
  }

  private getUserInitials(user: User): string {
    let initials = '';
    if (user.firstName.length > 0) initials += user.firstName.charAt(0);
    if (user.lastName.length > 0) initials += user.lastName.charAt(0);
    return initials.length > 0 ? initials : '?';
  }

  private getAvatarColor(userId: number): ResourceColor {
    const colors: ResourceColor[] = [
      $r('app.color.sender_color_1'), $r('app.color.sender_color_2'),
      $r('app.color.sender_color_3'), $r('app.color.sender_color_8'),
      $r('app.color.sender_color_4'), $r('app.color.sender_color_5'),
      $r('app.color.sender_color_6'), $r('app.color.sender_color_7')
    ];
    return colors[Math.abs(userId) % colors.length];
  }

  private refreshContacts(): void {
    let contacts = ContactsController.getInstance().getContacts();
    if (this.searchText.length > 0) {
      const query = this.searchText.toLowerCase();
      contacts = contacts.filter(u => {
        const name = `${u.firstName} ${u.lastName}`.toLowerCase();
        return name.includes(query);
      });
    }
    this.contactDataSource.setData(contacts);
  }
}
