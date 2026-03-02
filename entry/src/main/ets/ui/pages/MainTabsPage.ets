// MainTabsPage — root after auth
// 4 tabs: Contacts, Calls, Chats, Settings — each with independent NavPathStack
// Phase D-1: Custom floating island tab bar (TgTabBar) replaces built-in bar

import { ChatListPage } from './chatlist/ChatListPage';
import { TgChatScreenPage } from './chat/TgChatScreenPage';
import { ContactsPage } from './contacts/ContactsPage';
import { CallsPage } from './calls/CallsPage';
import { SettingsPage } from './settings/SettingsPage';
import { StorageKeys } from '../../app/bridge/AppStoreBridge';
import { TgTabBar } from '../tg_ui/atoms/TgTabBar';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0020;
const TAG = 'MainTabsPage';

@Component
export struct MainTabsPage {
  @StorageLink(StorageKeys.MAIN_TAB_INDEX) selectedIndex: number = 2;
  @StorageLink(StorageKeys.TOTAL_UNREAD_COUNT) totalUnread: number = 0;
  @StorageLink(StorageKeys.CHAT_SCREEN_VISIBLE) chatScreenVisible: boolean = false;
  @StorageLink(StorageKeys.GLASS_MODE) glassMode: string = 'auto';
  @State private appliedTabIndex: number = 2;

  // Independent NavPathStack per tab (iOS-like isolated navigation)
  private contactsNavStack: NavPathStack = new NavPathStack();
  private callsNavStack: NavPathStack = new NavPathStack();
  private chatNavStack: NavPathStack = new NavPathStack();
  private settingsNavStack: NavPathStack = new NavPathStack();

  private controller: TabsController = new TabsController();

  aboutToAppear(): void {
    AppStorage.setOrCreate<number>(StorageKeys.MAIN_TAB_INDEX, 2);
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    this.appliedTabIndex = this.selectedIndex;
    this.controller.changeIndex(this.selectedIndex);
    hilog.info(DOMAIN, TAG, 'MainTabsPage appeared with tab index: %{public}d', this.selectedIndex);
  }

  private handleTabChange(index: number): void {
    if (index === this.appliedTabIndex) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Tab change: %{public}d -> %{public}d', this.appliedTabIndex, index);

    this.appliedTabIndex = index;
    AppStorage.set<number>(StorageKeys.MAIN_TAB_INDEX, index);
    this.controller.changeIndex(index);

    if (index !== 2) {
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    }
  }

  @Builder
  chatPageMap(name: string) {
    if (name === 'TgChatScreenPage') {
      TgChatScreenPage({
        navStack: this.chatNavStack
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // ── Tab content (fills entire area, no built-in bar) ──
      Tabs({ barPosition: BarPosition.End, controller: this.controller, index: this.appliedTabIndex }) {
        // Tab 0: Contacts
        TabContent() {
          Navigation(this.contactsNavStack) {
            ContactsPage()
          }
          .hideTitleBar(true)
          .hideToolBar(true)
          .mode(NavigationMode.Stack)
        }

        // Tab 1: Calls
        TabContent() {
          Navigation(this.callsNavStack) {
            CallsPage()
          }
          .hideTitleBar(true)
          .hideToolBar(true)
          .mode(NavigationMode.Stack)
        }

        // Tab 2: Chats
        TabContent() {
          Navigation(this.chatNavStack) {
            ChatListPage({
              pageStack: this.chatNavStack
            })
          }
          .hideTitleBar(true)
          .hideToolBar(true)
          .navDestination(this.chatPageMap)
          .mode(NavigationMode.Stack)
        }

        // Tab 3: Settings
        TabContent() {
          Navigation(this.settingsNavStack) {
            SettingsPage()
          }
          .hideTitleBar(true)
          .hideToolBar(true)
          .mode(NavigationMode.Stack)
        }
      }
      .vertical(false)
      .barHeight(0, true)
      .barOverlap(true)
      .barBackgroundColor(Color.Transparent)
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .barMode(BarMode.Fixed)
      .scrollable(false)
      .animationDuration(0)
      .fadingEdge(false)
      .onChange((index: number) => {
        hilog.info(DOMAIN, TAG, 'Tabs onChange triggered: %{public}d', index);
        this.handleTabChange(index);
      })
      .width('100%')
      .height('100%')

      // ── Floating island tab bar (overlays content) ──
      if (!(this.selectedIndex === 2 && this.chatScreenVisible)) {
        TgTabBar({
          selectedIndex: this.selectedIndex,
          chatBadgeCount: this.totalUnread,
          glassMode: this.glassMode,
          onTabSelect: (index: number) => {
            hilog.info(DOMAIN, TAG, 'TabBar onTabSelect: %{public}d', index);
            this.handleTabChange(index);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}