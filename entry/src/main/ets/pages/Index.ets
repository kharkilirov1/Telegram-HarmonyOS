import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from '../controllers/NotificationCenter';
import { MessagesController } from '../controllers/MessagesController';
import { AuthController } from '../controllers/AuthController';
import { UserService } from '../services/UserService';
import { NotificationService } from '../services/NotificationService';
import { PhoneNumberPage } from './Login/PhoneNumberPage';
import { ChatListPage } from './Chat/ChatListPage';
import { ContactsPage } from './Contacts/ContactsPage';
import { CallsPage } from './Calls/CallsPage';

@Entry
@ComponentV2
struct Index {
  @Local isAuthorized: boolean = false;
  @Provider('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local currentTabIndex: number = 2;
  @Local totalUnreadCount: number = 0;

  // User profile for settings tab header
  @Local userFirstName: string = '';
  @Local userLastName: string = '';
  @Local userPhoneNumber: string = '';
  @Local userInitial: string = '';

  // Auth state handler — driven by NotificationCenter, not raw TDLib
  private authHandler = (args?: Record<string, Object>): void => {
    if (!args) return;
    const state = args['state'] as string;

    switch (state) {
      case 'authorizationStateWaitPhoneNumber':
        this.isAuthorized = false;
        this.navPathStack.clear();
        break;
      case 'authorizationStateWaitCode':
        this.navPathStack.pushPath(new NavPathInfo('LoginCode', new Object()));
        break;
      case 'authorizationStateWaitPassword':
        this.navPathStack.pushPath(new NavPathInfo('LoginPassword', new Object()));
        break;
      case 'authorizationStateReady':
        this.isAuthorized = true;
        this.navPathStack.clear();
        this.loadUserProfile();
        break;
      case 'authorizationStateClosed':
        this.isAuthorized = false;
        this.navPathStack.clear();
        break;
    }
  };

  private unreadHandler = (): void => {
    this.updateUnreadCount();
  };

  private userInfoHandler = (args?: Record<string, Object>): void => {
    if (!args) return;
    const userId = args['userId'] as number;
    if (userId === AuthController.getInstance().getMyUserId()) {
      this.loadUserProfile();
    }
  };

  private async loadUserProfile(): Promise<void> {
    try {
      const me = await UserService.getInstance().getMe();
      this.userFirstName = me.first_name || '';
      this.userLastName = me.last_name || '';
      this.userPhoneNumber = me.phone_number || '';
      const fullName = `${this.userFirstName} ${this.userLastName}`.trim();
      this.userInitial = fullName.length > 0 ? fullName.charAt(0).toUpperCase() : 'U';
    } catch (_e) {
      // Profile will show defaults until loaded
    }
  }

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.AUTH_STATE_CHANGED, this.authHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.DIALOGS_UPDATED, this.unreadHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.USER_INFO_UPDATED, this.userInfoHandler);
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.AUTH_STATE_CHANGED, this.authHandler);
    NotificationCenter.getInstance()
      .removeObserver(EventId.DIALOGS_UPDATED, this.unreadHandler);
    NotificationCenter.getInstance()
      .removeObserver(EventId.USER_INFO_UPDATED, this.userInfoHandler);
    TDLibClient.getInstance().destroy();
  }

  private updateUnreadCount(): void {
    const chats = MessagesController.getInstance().getSortedDialogs();
    let total = 0;
    for (const chat of chats) {
      total += chat.unreadCount;
    }
    this.totalUnreadCount = total;
    // Sync HarmonyOS app badge with total unread count
    NotificationService.getInstance().setBadgeNumber(total);
  }

  build() {
    Navigation(this.navPathStack) {
      if (this.isAuthorized) {
        // Authorized: Tab bar like Telegram iOS (Contacts, Calls, Chats, Settings)
        Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
          // Tab 0: Contacts
          TabContent() {
            ContactsPage()
          }
          .tabBar(this.tabBarItem(0, $r('app.media.ic_contact'), $r('app.string.contacts_title')))

          // Tab 1: Calls
          TabContent() {
            CallsPage()
          }
          .tabBar(this.tabBarItem(1, $r('app.media.ic_phone_call'), $r('app.string.calls_title')))

          // Tab 2: Chats (main)
          TabContent() {
            ChatListPage()
          }
          .tabBar(this.tabBarItem(2, $r('app.media.ic_group'), $r('app.string.chats_title')))

          // Tab 3: Settings
          TabContent() {
            this.settingsTab()
          }
          .tabBar(this.tabBarItem(3, $r('app.media.ic_settings'), $r('app.string.settings')))
        }
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        .barBackgroundColor($r('app.color.glass_tab_bg'))
        .barBackgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .animationDuration(200)
        .onChange((index: number) => {
          this.currentTabIndex = index;
        })
      } else {
        PhoneNumberPage()
      }
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }

  @Builder
  tabBarItem(index: number, icon: Resource, title: Resource) {
    Column() {
      // Badge for Chats tab (index 2) — like iOS/Android Telegram
      Stack({ alignContent: Alignment.TopEnd }) {
        Image(icon)
          .width(24)
          .height(24)
          .fillColor(this.currentTabIndex === index
            ? $r('app.color.telegram_blue')
            : $r('app.color.text_secondary'))

        if (index === 2 && this.totalUnreadCount > 0) {
          Text(this.totalUnreadCount > 99 ? '99+' : this.totalUnreadCount.toString())
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.unread_badge'))
            .borderRadius(8)
            .padding({ left: 4, right: 4 })
            .constraintSize({ minWidth: 16 })
            .textAlign(TextAlign.Center)
            .translate({ x: 8, y: -4 })
        }
      }

      Text(title)
        .fontSize(10)
        .fontColor(this.currentTabIndex === index
          ? $r('app.color.telegram_blue')
          : $r('app.color.text_secondary'))
        .margin({ top: 2 })
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
  }

  // Settings as tab content (navigates to full settings on tap)
  @Builder
  settingsTab() {
    Column() {
      // Top bar
      Row() {
        Text($r('app.string.settings'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text($r('app.string.profile_edit'))
          .fontSize(16)
          .fontColor($r('app.color.telegram_blue'))
          .onClick(() => {
            this.navPathStack.pushPath(new NavPathInfo('Profile', new Object()));
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Quick settings list — tapping rows navigates into NavDestination
      Scroll() {
        Column() {
          // Profile card — like Telegram iOS settings header
          Row() {
            Text(this.userInitial.length > 0 ? this.userInitial : 'U')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(64)
              .height(64)
              .borderRadius(32)
              .backgroundColor($r('app.color.telegram_blue'))
              .textAlign(TextAlign.Center)

            Column() {
              Text(this.userFirstName.length > 0
                ? `${this.userFirstName} ${this.userLastName}`.trim()
                : $r('app.string.settings'))
                .fontSize(19)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              if (this.userPhoneNumber.length > 0) {
                Text(`+${this.userPhoneNumber}`)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
            }
            .margin({ left: 16 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.navPathStack.pushPath(new NavPathInfo('Profile', new Object()));
          })

          Blank().height(16)

          // --- Glass Card 1: Quick actions ---
          Column() {
            Column() {
              this.settingsRow($r('app.media.ic_saved'), $r('app.color.settings_icon_blue'),
                $r('app.string.saved_messages'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('SavedMessages', new Object()));
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            Column() {
              this.settingsRow($r('app.media.ic_phone_call'), $r('app.color.settings_icon_green'),
                $r('app.string.settings_recent_calls'))
            }
            .onClick(() => {
              this.currentTabIndex = 1; // Switch to Calls tab
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            Column() {
              this.settingsRow($r('app.media.ic_channel'), $r('app.color.settings_icon_orange'),
                $r('app.string.settings_devices'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('SessionManagement', new Object()));
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            Column() {
              this.settingsRow($r('app.media.ic_group'), $r('app.color.settings_icon_blue'),
                $r('app.string.settings_chat_folders'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('ChatFolders', new Object()));
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.glass_card_bg'))
          .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
          .borderRadius(16)
          .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
          .margin({ left: 16, right: 16 })

          Blank().height(16)

          // --- Glass Card 2: Settings ---
          Column() {
            Column() {
              this.settingsRow($r('app.media.ic_unmute'), $r('app.color.settings_icon_red'),
                $r('app.string.settings_notifications_sounds'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('NotificationsSettings', new Object()));
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            Column() {
              this.settingsRow($r('app.media.ic_lock'), $r('app.color.settings_icon_blue'),
                $r('app.string.settings_privacy_security'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('PrivacySettings', new Object()));
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            Column() {
              this.settingsRow($r('app.media.ic_document'), $r('app.color.settings_icon_green'),
                $r('app.string.settings_data_storage'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('DataStorage', new Object()));
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            Column() {
              this.settingsRow($r('app.media.ic_sticker'), $r('app.color.settings_icon_blue'),
                $r('app.string.settings_appearance'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('Appearance', new Object()));
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            Column() {
              this.settingsRow($r('app.media.ic_location'), $r('app.color.settings_icon_purple'),
                $r('app.string.settings_language'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('Language', new Object()));
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            this.settingsRow($r('app.media.ic_emoji'), $r('app.color.settings_icon_orange'),
              $r('app.string.settings_stickers'))
          }
          .width('100%')
          .backgroundColor($r('app.color.glass_card_bg'))
          .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
          .borderRadius(16)
          .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
          .margin({ left: 16, right: 16 })

          Blank().height(16)

          // --- Glass Card 3: Premium & Features ---
          Column() {
            Column() {
              this.settingsRow($r('app.media.ic_sticker'), $r('app.color.settings_icon_purple'),
                $r('app.string.telegram_premium'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('Premium', new Object()));
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            Column() {
              this.settingsRow($r('app.media.ic_contact'), $r('app.color.settings_icon_blue'),
                $r('app.string.nearby_people'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('NearbyPeople', new Object()));
            })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            Column() {
              this.settingsRow($r('app.media.ic_settings'), $r('app.color.settings_icon_green'),
                $r('app.string.business_account'))
            }
            .onClick(() => {
              this.navPathStack.pushPath(new NavPathInfo('BusinessAccount', new Object()));
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.glass_card_bg'))
          .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
          .borderRadius(16)
          .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
          .margin({ left: 16, right: 16 })

          Blank().height(16)

          // --- Glass Card 4: Power Saving ---
          Column() {
            this.settingsRow($r('app.media.ic_saved'), $r('app.color.settings_icon_green'),
              $r('app.string.settings_power_saving'))
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
    .backgroundColor($r('app.color.background_primary'))
  }

  @Builder
  settingsRow(icon: Resource, iconBg: ResourceColor, label: Resource) {
    Row() {
      Column() {
        Image(icon)
          .width(18).height(18)
          .fillColor(Color.White)
      }
      .width(28).height(28)
      .borderRadius(6)
      .backgroundColor(iconBg)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 14 })

      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Image($r('app.media.ic_forward'))
        .width(14).height(14)
        .fillColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
  }
}
