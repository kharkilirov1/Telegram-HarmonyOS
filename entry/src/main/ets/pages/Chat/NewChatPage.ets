// New chat page — contact selection for starting a new private/group chat
// Reference: Telegram iOS ComposeController, Android NewContactActivity

import { ContactsController } from '../../controllers/ContactsController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { TDLibClient } from '../../services/TDLibClient';
import { User } from '../../models/User';
import { AvatarWithStatus, formatLastSeen } from '../../components/Common/AvatarWithStatus';
import { BasicDataSource } from '../../datasources/BasicDataSource';

@Builder
export function NewChatBuilder(name: string, param: Object) {
  NewChatPage()
}

@ComponentV2
export struct NewChatPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local searchText: string = '';
  @Local isLoading: boolean = true;

  private contactDataSource: BasicDataSource<User> = new BasicDataSource<User>();

  private contactsHandler = (): void => {
    this.refreshContacts();
    this.isLoading = false;
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.CONTACTS_UPDATED, this.contactsHandler);
    ContactsController.getInstance().loadContacts();
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.CONTACTS_UPDATED, this.contactsHandler);
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.new_message'))
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

        // Quick action rows — navigate to create pages
        this.quickActionClickable($r('app.media.ic_group'), $r('app.string.new_group'), () => {
          this.navPathStack.pushPath(new NavPathInfo('CreateGroup'));
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
        this.quickActionClickable($r('app.media.ic_channel'), $r('app.string.new_channel'), () => {
          this.navPathStack.pushPath(new NavPathInfo('CreateChannel'));
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
        this.quickAction($r('app.media.ic_lock'), $r('app.string.secret_chat'))
        Divider().strokeWidth(0.5).color($r('app.color.separator'))

        // Contact list
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40).height(40).color($r('app.color.telegram_blue'))
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List() {
            LazyForEach(this.contactDataSource, (user: User) => {
              ListItem() {
                this.contactRow(user)
              }
            }, (user: User) => user.id.toString())
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
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  quickAction(icon: Resource, label: Resource) {
    Row() {
      Column() {
        Image(icon)
          .width(20).height(20)
          .fillColor(Color.White)
      }
      .width(40).height(40)
      .borderRadius(20)
      .backgroundColor($r('app.color.telegram_blue'))
      .justifyContent(FlexAlign.Center)
      .margin({ left: 16, right: 12 })

      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.telegram_blue'))
    }
    .width('100%').height(50)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  quickActionClickable(icon: Resource, label: Resource, onTap: () => void) {
    Row() {
      Column() {
        Image(icon)
          .width(20).height(20)
          .fillColor(Color.White)
      }
      .width(40).height(40)
      .borderRadius(20)
      .backgroundColor($r('app.color.telegram_blue'))
      .justifyContent(FlexAlign.Center)
      .margin({ left: 16, right: 12 })

      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.telegram_blue'))
    }
    .width('100%').height(50)
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  @Builder
  contactRow(user: User) {
    Row() {
      AvatarWithStatus({
        photoUrl: user.photoUrl || '',
        initials: this.getInitials(user),
        avatarColor: this.getAvatarColor(user.id),
        avatarSize: 50,
        isOnline: user.isOnline,
        showOnlineDot: true
      })
      .margin({ left: 16, right: 12 })

      Column() {
        Text(`${user.firstName} ${user.lastName}`.trim())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

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
    .height(60)
    .padding({ right: 16 })
    .onClick(() => {
      this.openPrivateChat(user.id);
    })
  }

  private async openPrivateChat(userId: number): Promise<void> {
    try {
      const privateChatParams: Record<string, Object> = {};
      privateChatParams['user_id'] = userId;
      privateChatParams['force'] = false;
      const result = await TDLibClient.getInstance().send('createPrivateChat', privateChatParams) as Record<string, number>;

      const chatId = result['id'] || -userId;
      this.navPathStack.pop();
      this.navPathStack.pushPath(new NavPathInfo('ChatDetail', chatId));
    } catch (e) {
      // Fallback: use negative userId as chatId convention
      this.navPathStack.pop();
      this.navPathStack.pushPath(new NavPathInfo('ChatDetail', -userId));
    }
  }

  private getInitials(user: User): string {
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
        return name.includes(query) || u.username.toLowerCase().includes(query);
      });
    }
    this.contactDataSource.setData(contacts);
  }
}
