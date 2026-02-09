// Create New Group page — select members, set name, create
// Reference: Telegram Android GroupCreateActivity, iOS GroupCreateController

import { ContactsController } from '../../controllers/ContactsController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { TDLibClient } from '../../services/TDLibClient';
import { User } from '../../models/User';
import { AvatarWithStatus, formatLastSeen } from '../../components/Common/AvatarWithStatus';
import { BasicDataSource } from '../../datasources/BasicDataSource';

@Builder
export function CreateGroupBuilder(name: string, param: Object) {
  CreateGroupPage()
}

@ComponentV2
export struct CreateGroupPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local step: number = 0; // 0 = select members, 1 = set group info
  @Local searchText: string = '';
  @Local groupName: string = '';
  @Local selectedUserIds: number[] = [];
  @Local isCreating: boolean = false;

  private contactDataSource: BasicDataSource<User> = new BasicDataSource<User>();

  private contactsHandler = (): void => {
    this.refreshContacts();
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.CONTACTS_UPDATED, this.contactsHandler);
    ContactsController.getInstance().loadContacts();
    this.refreshContacts();
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.CONTACTS_UPDATED, this.contactsHandler);
  }

  build() {
    NavDestination() {
      Column() {
        if (this.step === 0) {
          this.buildMemberSelection()
        } else {
          this.buildGroupInfo()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  buildMemberSelection() {
    Column() {
      // Top bar
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .fillColor($r('app.color.telegram_blue'))
          .onClick(() => this.navPathStack.pop())

        Text($r('app.string.new_group'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
          .layoutWeight(1)

        if (this.selectedUserIds.length > 0) {
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

      // Selected member chips
      if (this.selectedUserIds.length > 0) {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.selectedUserIds, (userId: number) => {
              this.memberChip(userId)
            }, (userId: number) => userId.toString())
          }
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }

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

      // Contact list
      List() {
        LazyForEach(this.contactDataSource, (user: User) => {
          ListItem() {
            this.selectableContactRow(user)
          }
        }, (user: User) => `${user.id}_${this.selectedUserIds.includes(user.id)}`)
      }
      .width('100%')
      .layoutWeight(1)
      .cachedCount(5)
      .edgeEffect(EdgeEffect.Spring)
      .divider({
        strokeWidth: 0.5,
        color: $r('app.color.separator'),
        startMargin: 82,
        endMargin: 0
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildGroupInfo() {
    Column() {
      // Top bar
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .fillColor($r('app.color.telegram_blue'))
          .onClick(() => { this.step = 0; })

        Text($r('app.string.new_group'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
          .layoutWeight(1)

        if (this.groupName.trim().length > 0 && !this.isCreating) {
          Text($r('app.string.create'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
            .onClick(() => { this.createGroup(); })
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

      // Group name input with camera icon for photo
      Row() {
        Column() {
          Image($r('app.media.ic_photo'))
            .width(24).height(24)
            .fillColor(Color.White)
        }
        .width(64).height(64)
        .borderRadius(32)
        .backgroundColor($r('app.color.telegram_blue'))
        .justifyContent(FlexAlign.Center)
        .margin({ right: 16 })

        TextInput({ placeholder: 'Group Name', text: this.groupName })
          .fontSize(17)
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => {
            this.groupName = value;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Members count
      Text(`${this.selectedUserIds.length} members`)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: 16, top: 12, bottom: 8 })
        .width('100%')

      // Selected members list
      List() {
        ForEach(this.selectedUserIds, (userId: number) => {
          ListItem() {
            this.memberRow(userId)
          }
        }, (userId: number) => userId.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .divider({
        strokeWidth: 0.5,
        color: $r('app.color.separator'),
        startMargin: 82,
        endMargin: 0
      })

      if (this.isCreating) {
        Column() {
          LoadingProgress()
            .width(40).height(40).color($r('app.color.telegram_blue'))
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  memberChip(userId: number) {
    Row() {
      Text(this.getUserName(userId))
        .fontSize(14)
        .fontColor($r('app.color.telegram_blue'))

      Image($r('app.media.ic_close'))
        .width(14).height(14)
        .fillColor($r('app.color.text_secondary'))
        .margin({ left: 4 })
    }
    .padding({ left: 10, right: 8, top: 4, bottom: 4 })
    .borderRadius(16)
    .backgroundColor($r('app.color.glass_card_bg'))
    .onClick(() => {
      this.toggleSelection(userId);
    })
  }

  @Builder
  selectableContactRow(user: User) {
    Row() {
      // Checkbox
      Checkbox({ name: `user_${user.id}` })
        .select(this.selectedUserIds.includes(user.id))
        .selectedColor($r('app.color.telegram_blue'))
        .margin({ left: 16, right: 8 })
        .onChange((isChecked: boolean) => {
          this.toggleSelection(user.id);
        })

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
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ right: 16 })
    .onClick(() => {
      this.toggleSelection(user.id);
    })
  }

  @Builder
  memberRow(userId: number) {
    Row() {
      Text(this.getUserName(userId).charAt(0))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(44).height(44)
        .borderRadius(22)
        .backgroundColor(this.getAvatarColor(userId))
        .textAlign(TextAlign.Center)
        .margin({ left: 16, right: 12 })

      Text(this.getUserName(userId))
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Image($r('app.media.ic_close'))
        .width(18).height(18)
        .fillColor($r('app.color.text_secondary'))
        .margin({ right: 16 })
        .onClick(() => { this.toggleSelection(userId); })
    }
    .width('100%')
    .height(52)
  }

  private toggleSelection(userId: number): void {
    const idx = this.selectedUserIds.indexOf(userId);
    if (idx >= 0) {
      this.selectedUserIds = this.selectedUserIds.filter(id => id !== userId);
    } else {
      this.selectedUserIds = [...this.selectedUserIds, userId];
    }
    this.refreshContacts();
  }

  private async createGroup(): Promise<void> {
    if (this.isCreating) return;
    this.isCreating = true;

    try {
      const createGroupParams: Record<string, Object> = {};
      createGroupParams['user_ids'] = this.selectedUserIds;
      createGroupParams['title'] = this.groupName.trim();
      const result = await TDLibClient.getInstance().send('createNewBasicGroupChat', createGroupParams) as Record<string, number>;

      const chatId = result['id'] || 0;
      this.navPathStack.pop();
      if (chatId !== 0) {
        this.navPathStack.pushPath({ name: 'ChatDetail', param: chatId });
      }
    } catch (e) {
      this.isCreating = false;
    }
  }

  private getUserName(userId: number): string {
    const user = ContactsController.getInstance().getUser(userId);
    if (user) {
      return `${user.firstName} ${user.lastName}`.trim();
    }
    return 'User';
  }

  private getUserInitials(user: User): string {
    let initials = '';
    if (user.firstName.length > 0) initials += user.firstName.charAt(0);
    if (user.lastName.length > 0) initials += user.lastName.charAt(0);
    return initials.length > 0 ? initials : '?';
  }

  private getAvatarColor(userId: number): string {
    const colors: string[] = [
      '#FF5733', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#00BCD4', '#009688'
    ];
    return colors[Math.abs(userId) % colors.length];
  }

  private refreshContacts(): void {
    let contacts = ContactsController.getInstance().getContacts();
    if (this.searchText.length > 0) {
      const query = this.searchText.toLowerCase();
      contacts = contacts.filter(u => {
        const name = `${u.firstName} ${u.lastName}`.toLowerCase();
        return name.includes(query) || u.username.toLowerCase().includes(query);
      });
    }
    this.contactDataSource.setData(contacts);
  }
}
