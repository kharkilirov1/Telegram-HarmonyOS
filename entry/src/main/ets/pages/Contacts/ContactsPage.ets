import { ContactsController } from '../../controllers/ContactsController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { User } from '../../models/User';
import { AvatarWithStatus, formatLastSeen } from '../../components/Common/AvatarWithStatus';
import { BasicDataSource } from '../../datasources/BasicDataSource';

@ComponentV2
export struct ContactsPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local searchText: string = '';
  @Local isLoading: boolean = true;
  @Local sectionLetters: string[] = [];

  private contactDataSource: BasicDataSource<User> = new BasicDataSource<User>();
  private listScroller: Scroller = new Scroller();
  private searchTimerId: number = -1;

  private contactsHandler = (): void => {
    this.refreshContacts();
    this.isLoading = false;
  };

  private statusHandler = (): void => {
    this.refreshContacts();
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.CONTACTS_UPDATED, this.contactsHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.USER_STATUS_UPDATED, this.statusHandler);

    ContactsController.getInstance().loadContacts();
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.CONTACTS_UPDATED, this.contactsHandler);
    NotificationCenter.getInstance()
      .removeObserver(EventId.USER_STATUS_UPDATED, this.statusHandler);
  }

  build() {
    Column() {
      // Top bar with glass effect
      Row() {
        Button() {
          Text($r('app.string.contacts_sort'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
        }
        .backgroundColor(Color.Transparent)

        Blank()

        Text($r('app.string.contacts_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        Button() {
          Image($r('app.media.ic_contact_add'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
        }
        .backgroundColor(Color.Transparent)
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('app.color.glass_nav_bg'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 24, bottomRight: 24 })
      .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // Search bar
      Search({ placeholder: $r('app.string.search_placeholder'), value: this.searchText })
        .width('100%')
        .height(36)
        .margin({ left: 16, right: 16, top: 4, bottom: 4 })
        .onChange((value: string) => {
          this.searchText = value;
          if (this.searchTimerId >= 0) {
            clearTimeout(this.searchTimerId);
          }
          this.searchTimerId = setTimeout(() => {
            this.refreshContacts();
          }, 300);
        })

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Content
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color($r('app.color.telegram_blue'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Stack({ alignContent: Alignment.End }) {
          List({ scroller: this.listScroller }) {
            // Action rows at top
            ListItem() {
              this.actionRow($r('app.media.ic_contact_add'), $r('app.string.contacts_invite_friends'))
            }
            ListItem() {
              this.actionRow($r('app.media.ic_location'), $r('app.string.contacts_find_nearby'))
            }

            // Contact list
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

          // Alphabetical index on right edge
          if (this.sectionLetters.length > 0) {
            Column() {
              ForEach(this.sectionLetters, (letter: string) => {
                Text(letter)
                  .fontSize(10)
                  .fontColor($r('app.color.telegram_blue'))
                  .fontWeight(FontWeight.Medium)
                  .textAlign(TextAlign.Center)
                  .width(16)
                  .height(14)
                  .onClick(() => {
                    this.scrollToLetter(letter);
                  })
              }, (letter: string) => letter)
            }
            .justifyContent(FlexAlign.Center)
            .padding({ right: 2 })
          }
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_primary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  actionRow(icon: Resource, label: Resource) {
    Row() {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor($r('app.color.telegram_blue'))
        .margin({ left: 16, right: 16 })

      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.telegram_blue'))
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
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
      // Navigate to private chat with this user
      this.navPathStack.pushPath(new NavPathInfo('ChatDetail', user.id));
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

  private getInitials(user: User): string {
    let initials = '';
    if (user.firstName.length > 0) {
      initials += user.firstName.charAt(0);
    }
    if (user.lastName.length > 0) {
      initials += user.lastName.charAt(0);
    }
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

  private scrollToLetter(letter: string): void {
    const contacts = this.contactDataSource.getAllData() as User[];
    // +2 offset for the two action rows at top
    const idx = contacts.findIndex(u => u.firstName.charAt(0).toUpperCase() === letter);
    if (idx >= 0) {
      this.listScroller.scrollToIndex(idx + 2);
    }
  }

  private refreshContacts(): void {
    let contacts = ContactsController.getInstance().getContacts();

    // Apply search filter
    if (this.searchText.length > 0) {
      const query = this.searchText.toLowerCase();
      contacts = contacts.filter(u => {
        const fullName = `${u.firstName} ${u.lastName}`.toLowerCase();
        return fullName.includes(query) || u.username.toLowerCase().includes(query);
      });
    }

    this.contactDataSource.setData(contacts);

    // Build section letters
    const letters = new Set<string>();
    for (const user of contacts) {
      const firstChar = user.firstName.charAt(0).toUpperCase();
      if (firstChar.length > 0) {
        letters.add(firstChar);
      }
    }
    this.sectionLetters = Array.from(letters).sort();
  }
}
