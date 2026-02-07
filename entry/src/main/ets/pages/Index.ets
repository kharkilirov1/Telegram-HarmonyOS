import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from '../controllers/NotificationCenter';
import { PhoneNumberPage } from './Login/PhoneNumberPage';
import { ChatListPage } from './Chat/ChatListPage';

@Entry
@ComponentV2
struct Index {
  @Local isAuthorized: boolean = false;
  @Provider('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local currentTabIndex: number = 0;

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
        this.navPathStack.pushPath({ name: 'LoginCode' });
        break;
      case 'authorizationStateWaitPassword':
        this.navPathStack.pushPath({ name: 'LoginPassword' });
        break;
      case 'authorizationStateReady':
        this.isAuthorized = true;
        this.navPathStack.clear();
        break;
      case 'authorizationStateClosed':
        this.isAuthorized = false;
        this.navPathStack.clear();
        break;
    }
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.AUTH_STATE_CHANGED, this.authHandler);
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.AUTH_STATE_CHANGED, this.authHandler);
    TDLibClient.getInstance().destroy();
  }

  build() {
    Navigation(this.navPathStack) {
      if (this.isAuthorized) {
        // Authorized: Tab bar like Telegram iOS (Contacts, Calls, Chats, Settings)
        Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
          // Tab 0: Contacts (stub)
          TabContent() {
            this.contactsStub()
          }
          .tabBar(this.tabBarItem(0, $r('app.media.ic_contact'), $r('app.string.contacts_title')))

          // Tab 1: Calls (stub)
          TabContent() {
            this.callsStub()
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
      Image(icon)
        .width(24)
        .height(24)
        .fillColor(this.currentTabIndex === index
          ? $r('app.color.telegram_blue')
          : $r('app.color.text_secondary'))
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

  // Stub: Contacts tab
  @Builder
  contactsStub() {
    Column() {
      // Top bar
      Row() {
        Text($r('app.string.contacts_title'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Image($r('app.media.ic_search'))
          .width(22).height(22)
          .fillColor($r('app.color.telegram_blue'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // Placeholder
      Column() {
        Image($r('app.media.ic_contact'))
          .width(64).height(64)
          .fillColor($r('app.color.text_secondary'))
          .opacity(0.4)
        Text($r('app.string.contacts'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_primary'))
  }

  // Stub: Calls tab
  @Builder
  callsStub() {
    Column() {
      Row() {
        Text($r('app.string.calls_title'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Column() {
        Image($r('app.media.ic_phone_call'))
          .width(64).height(64)
          .fillColor($r('app.color.text_secondary'))
          .opacity(0.4)
        Text($r('app.string.calls_title'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_primary'))
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
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Quick settings list — tapping rows navigates into NavDestination
      Scroll() {
        Column() {
          // Profile card — like Telegram iOS settings header
          Row() {
            Text('U')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(64)
              .height(64)
              .borderRadius(32)
              .backgroundColor($r('app.color.telegram_blue'))
              .textAlign(TextAlign.Center)

            Column() {
              Text('User')
                .fontSize(19)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text('+1 234 567 890')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
            .margin({ left: 16 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.navPathStack.pushPath({ name: 'Profile' });
          })

          Blank().height(16)

          // --- Glass Card 1: Quick actions ---
          Column() {
            this.settingsRow($r('app.media.ic_saved'), $r('app.color.settings_icon_blue'),
              $r('app.string.saved_messages'))
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            this.settingsRow($r('app.media.ic_phone_call'), $r('app.color.settings_icon_green'),
              $r('app.string.settings_recent_calls'))
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            this.settingsRow($r('app.media.ic_channel'), $r('app.color.settings_icon_orange'),
              $r('app.string.settings_devices'))
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            this.settingsRow($r('app.media.ic_group'), $r('app.color.settings_icon_blue'),
              $r('app.string.settings_chat_folders'))
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
            this.settingsRow($r('app.media.ic_unmute'), $r('app.color.settings_icon_red'),
              $r('app.string.settings_notifications_sounds'))
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            this.settingsRow($r('app.media.ic_lock'), $r('app.color.settings_icon_blue'),
              $r('app.string.settings_privacy_security'))
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            this.settingsRow($r('app.media.ic_document'), $r('app.color.settings_icon_green'),
              $r('app.string.settings_data_storage'))
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            this.settingsRow($r('app.media.ic_sticker'), $r('app.color.settings_icon_blue'),
              $r('app.string.settings_appearance'))
              .onClick(() => {
                this.navPathStack.pushPath({ name: 'Settings' });
              })
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
            this.settingsRow($r('app.media.ic_location'), $r('app.color.settings_icon_purple'),
              $r('app.string.settings_language'))
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

          // --- Glass Card 3: Power Saving ---
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
