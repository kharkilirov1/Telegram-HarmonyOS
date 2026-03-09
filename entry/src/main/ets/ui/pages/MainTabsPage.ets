// MainTabsPage — root after auth
// 4 tabs: Contacts, Calls, Chats, Settings — each with independent NavPathStack
// Phase D-1: Custom floating island tab bar (TgTabBar) replaces built-in bar

import { ChatListPage } from './chatlist/ChatListPage';
import { TgChatScreenPage } from './chat/TgChatScreenPage';
import { TgProfilePage } from './profile/TgProfilePage';
import { ContactsPage } from './contacts/ContactsPage';
import { CallsPage } from './calls/CallsPage';
import { SettingsPage } from './settings/SettingsPage';
import { StorageKeys } from '../../app/bridge/AppStoreBridge';
import { TgTabBar } from '../tg_ui/atoms/TgTabBar';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { TgUiTokens } from '../tg_ui/tokens/TgUiTokens';

const DOMAIN = 0x0020;
const TAG = 'MainTabsPage';

declare function px2vp(value: number): number;

@Component
export struct MainTabsPage {
  @StorageLink(StorageKeys.MAIN_TAB_INDEX) @Watch('onStoredTabIndexChanged') selectedIndex: number = 2;
  @StorageLink(StorageKeys.TOTAL_UNREAD_COUNT) totalUnread: number = 0;
  @StorageLink(StorageKeys.CHAT_SCREEN_VISIBLE) chatScreenVisible: boolean = false;
  @StorageLink(StorageKeys.GLASS_MODE) glassMode: string = 'auto';

  // Independent NavPathStack per tab (iOS-like isolated navigation)
  private contactsNavStack: NavPathStack = new NavPathStack();
  private callsNavStack: NavPathStack = new NavPathStack();
  private chatNavStack: NavPathStack = new NavPathStack();
  private settingsNavStack: NavPathStack = new NavPathStack();
  @State private bottomInset: number = 0;
  private mainWindow?: window.Window;

  private controller: TabsController = new TabsController();

  private onStoredTabIndexChanged(): void {
    if (this.selectedIndex < 0 || this.selectedIndex > 3) {
      return;
    }
    this.controller.changeIndex(this.selectedIndex);
  }

  aboutToAppear(): void {
    AppStorage.setOrCreate<number>(StorageKeys.MAIN_TAB_INDEX, this.selectedIndex);
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    this.controller.changeIndex(this.selectedIndex);
    hilog.info(DOMAIN, TAG, 'MainTabsPage appeared with tab index: %{public}d', this.selectedIndex);

    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage: window.WindowStage | undefined = context.windowStage;
      if (windowStage) {
        this.mainWindow = windowStage.getMainWindowSync();
        this.updateBottomInset(this.mainWindow);
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          if (this.mainWindow !== undefined) {
            this.updateBottomInset(this.mainWindow);
          }
        });
      }
    } catch (_error) {
      this.bottomInset = 0;
    }
  }

  aboutToDisappear(): void {
    if (this.mainWindow !== undefined) {
      try {
        this.mainWindow.off('windowSizeChange');
      } catch (_error) {
      }
      this.mainWindow = undefined;
    }
  }

  private updateBottomInset(mainWindow: window.Window): void {
    let computedInset: number = 0;
    try {
      const systemAvoid: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      computedInset = Math.max(computedInset, px2vp(systemAvoid.bottomRect.height));
      try {
        const navAvoid: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        computedInset = Math.max(computedInset, px2vp(navAvoid.bottomRect.height));
      } catch (_error) {
      }
    } catch (_error) {
    }
    this.bottomInset = computedInset;
  }

  private handleTabChange(index: number): void {
    if (index < 0 || index > 3) {
      hilog.warn(DOMAIN, TAG, 'Ignoring invalid tab index: %{public}d', index);
      return;
    }

    if (index === this.selectedIndex) {
      this.controller.changeIndex(index);
      return;
    }

    hilog.info(DOMAIN, TAG, 'Tab change: %{public}d -> %{public}d', this.selectedIndex, index);
    hilog.info(DOMAIN, TAG, 'chatNavStack exists: %{public}s', this.chatNavStack ? 'yes' : 'no');

    // Important: update UI state immediately (do not rely only on AppStorage propagation).
    this.selectedIndex = index;
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
        pageStack: this.chatNavStack
      })
    } else if (name === 'TgProfilePage') {
      TgProfilePage({
        pageStack: this.chatNavStack
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // ── Tab content (fills entire area, no built-in bar) ──
      Tabs({ barPosition: BarPosition.End, controller: this.controller, index: this.selectedIndex }) {
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
      .scrollable(false)
      .animationDuration(0) // Отключаем стандартную анимацию для чистоты
      .onChange((index: number) => {
        hilog.info(DOMAIN, TAG, 'Tabs onChange triggered: %{public}d', index);
        this.handleTabChange(index);
      })
      .onSelected((index: number) => {
        hilog.info(DOMAIN, TAG, 'Tabs onSelected: %{public}d', index);
        if (this.selectedIndex !== index) {
          this.selectedIndex = index;
          AppStorage.set<number>(StorageKeys.MAIN_TAB_INDEX, index);
        }
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
        .margin({ bottom: this.bottomInset > 0 ? this.bottomInset : TgUiTokens.TAB_BAR_ISLAND_BOTTOM_MARGIN })
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
  }
