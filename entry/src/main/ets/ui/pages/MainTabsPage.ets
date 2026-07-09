// MainTabsPage — root after auth
// 4 tabs: Contacts, Calls, Chats, Settings — each with independent NavPathStack
// API 23: HdsTabs floating TabBar replaces custom TgTabBar shell

import { ChatListPage } from './chatlist/ChatListPage';
import { TgChatScreenPage } from './chat/TgChatScreenPage';
import { TgProfilePage } from './profile/TgProfilePage';
import { ContactsPage } from './contacts/ContactsPage';
import { CallsPage } from './calls/CallsPage';
import { SettingsPage } from './settings/SettingsPage';
import { StorageKeys } from '../../app/bridge/AppStoreBridge';
import { navigationUIState, chatsUIState } from '../../core/model/UIStateModels';
import { TgUiTokens } from '../tg_ui/tokens/TgUiTokens';
import {
  bleedIconStyle,
  hdsMaterial,
  HdsNavigation,
  HdsNavigationAttribute,
  HdsTabs,
  HdsTabsAttribute,
  HdsTabsController
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0020;
const TAG = 'MainTabsPage';
const TAB_BAR_FLOATING_VISIBLE_HEIGHT = 48;
// ArkGram: barBottomMargin 30, backplate mask height 110 (theme bg color)
const TAB_BAR_FLOATING_BOTTOM_MARGIN = 30;
const TAB_BAR_BACKPLATE_HEIGHT = 110;

@ComponentV2
export struct MainTabsPage {
  @Local selectedIndex: number = 2;
  private navState = navigationUIState;
  private chatsState = chatsUIState;

  private contactsNavStack: NavPathStack = new NavPathStack();
  private callsNavStack: NavPathStack = new NavPathStack();
  private chatNavStack: NavPathStack = new NavPathStack();
  private settingsNavStack: NavPathStack = new NavPathStack();
  private controller: HdsTabsController = new HdsTabsController();

  private isChatDetailVisible(): boolean {
    return this.selectedIndex === 2 && this.navState.chatScreenVisible;
  }

  private rootTabBarHeight(): number {
    return this.isChatDetailVisible() ? 0 : TAB_BAR_FLOATING_VISIBLE_HEIGHT;
  }

  aboutToAppear(): void {
    this.selectedIndex = this.navState.mainTabIndex;
    AppStorage.setOrCreate<number>(StorageKeys.MAIN_TAB_INDEX, this.selectedIndex);
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    this.navState.chatScreenVisible = false;
    this.controller.changeIndex(this.selectedIndex);
    hilog.info(DOMAIN, TAG, 'MainTabsPage appeared with tab index: %{public}d', this.selectedIndex);
  }

  private handleTabChange(index: number): void {
    if (index < 0 || index > 3) {
      hilog.warn(DOMAIN, TAG, 'Ignoring invalid tab index: %{public}d', index);
      return;
    }

    if (index === this.selectedIndex) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Tab change: %{public}d -> %{public}d', this.selectedIndex, index);

    this.selectedIndex = index;
    navigationUIState.mainTabIndex = index;
    AppStorage.set<number>(StorageKeys.MAIN_TAB_INDEX, index);

    if (index !== 2) {
      navigationUIState.chatScreenVisible = false;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    }
  }

  private tabBadgeText(): string {
    const count = this.chatsState.totalUnreadCount;
    return count > 999 ? '999+' : count.toString();
  }

  // Custom tab bar for Chats: stock BottomTabBarStyle has no badge API,
  // so icon+label metrics are reproduced manually with an unread capsule on top
  @Builder
  buildChatsTabBar() {
    Column() {
      Stack() {
        SymbolGlyph(this.selectedIndex === 2
          ? $r('sys.symbol.ellipsis_message_fill')
          : $r('sys.symbol.ellipsis_message'))
          .fontSize(24)
          .fontColor([this.selectedIndex === 2
            ? TgUiTokens.COMPOSER_ACTION_ACTIVE
            : TgUiTokens.TAB_ITEM_UNSELECTED])
        if (this.chatsState.totalUnreadCount > 0) {
          Text(this.tabBadgeText())
            .fontSize(TgUiTokens.TAB_BADGE_FONT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.TAB_BADGE_TEXT)
            .backgroundColor(TgUiTokens.TAB_BADGE_BG)
            .height(TgUiTokens.TAB_BADGE_HEIGHT)
            .constraintSize({ minWidth: TgUiTokens.TAB_BADGE_MIN_WIDTH })
            .padding({ left: TgUiTokens.TAB_BADGE_PADDING_H, right: TgUiTokens.TAB_BADGE_PADDING_H })
            .borderRadius(TgUiTokens.TAB_BADGE_HEIGHT / 2)
            .textAlign(TextAlign.Center)
            .position({ x: 14, y: -6 })
        }
      }

      Text('Chats')
        .fontSize(10)
        .fontColor(this.selectedIndex === 2
          ? TgUiTokens.COMPOSER_ACTION_ACTIVE
          : TgUiTokens.TAB_ITEM_UNSELECTED)
        .margin({ top: 2 })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder
  chatPageMap(name: string) {
    if (name === 'TgChatScreenPage') {
      TgChatScreenPage()
    } else if (name === 'TgProfilePage') {
      TgProfilePage()
    }
  }

  build() {
    // index обязателен: controller.changeIndex() в aboutToAppear уходит до
    // привязки контроллера и молча игнорируется — без index стартовый таб был 0.
    HdsTabs({ index: this.selectedIndex, controller: this.controller }) {
      // Tab 0: Contacts
      TabContent() {
        HdsNavigation(this.contactsNavStack) {
          ContactsPage()
        }
        .titleBar({
          content: { title: { mainTitle: 'Contacts' } }
        })
        .mode(NavigationMode.Stack)
        .hideBackButton(true)
      }
      .tabBar(new BottomTabBarStyle(
        {
          normal: new SymbolGlyphModifier($r('sys.symbol.person')),
          selected: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
        },
        'Contacts'
      )
        .iconStyle({
          selectedColor: TgUiTokens.COMPOSER_ACTION_ACTIVE,
          unselectedColor: TgUiTokens.TAB_ITEM_UNSELECTED
        })
        .labelStyle({
          selectedColor: TgUiTokens.COMPOSER_ACTION_ACTIVE,
          unselectedColor: TgUiTokens.TAB_ITEM_UNSELECTED
        }))

      // Tab 1: Calls
      TabContent() {
        HdsNavigation(this.callsNavStack) {
          CallsPage()
        }
        .titleBar({
          content: { title: { mainTitle: 'Calls' } }
        })
        .mode(NavigationMode.Stack)
        .hideBackButton(true)
      }
      .tabBar(new BottomTabBarStyle(
        {
          normal: new SymbolGlyphModifier($r('sys.symbol.phone')),
          selected: new SymbolGlyphModifier($r('sys.symbol.phone'))
        },
        'Calls'
      )
        .iconStyle({
          selectedColor: TgUiTokens.COMPOSER_ACTION_ACTIVE,
          unselectedColor: TgUiTokens.TAB_ITEM_UNSELECTED
        })
        .labelStyle({
          selectedColor: TgUiTokens.COMPOSER_ACTION_ACTIVE,
          unselectedColor: TgUiTokens.TAB_ITEM_UNSELECTED
        }))

      // Tab 2: Chats
      TabContent() {
        Navigation(this.chatNavStack) {
          ChatListPage()
        }
        .hideTitleBar(true)
        .hideToolBar(true)
        .navDestination(this.chatPageMap)
        .mode(NavigationMode.Stack)
      }
      .tabBar(bleedIconStyle(() => {
        this.buildChatsTabBar()
      }))

      // Tab 3: Settings
      TabContent() {
        HdsNavigation(this.settingsNavStack) {
          SettingsPage()
        }
        .titleBar({
          content: { title: { mainTitle: 'Settings' } }
        })
        .mode(NavigationMode.Stack)
        .hideBackButton(true)
      }
      .tabBar(new BottomTabBarStyle(
        {
          normal: new SymbolGlyphModifier($r('sys.symbol.gearshape')),
          selected: new SymbolGlyphModifier($r('sys.symbol.gearshape'))
        },
        'Settings'
      )
        .iconStyle({
          selectedColor: TgUiTokens.COMPOSER_ACTION_ACTIVE,
          unselectedColor: TgUiTokens.TAB_ITEM_UNSELECTED
        })
        .labelStyle({
          selectedColor: TgUiTokens.COMPOSER_ACTION_ACTIVE,
          unselectedColor: TgUiTokens.TAB_ITEM_UNSELECTED
        }))
    }
    .barOverlap(!this.isChatDetailVisible())
    .barPosition(BarPosition.End)
    .barHeight(this.rootTabBarHeight())
    .vertical(false)
    // Native HDS floating bar (API 23 immersive material) — matches the
    // iOS 26 Liquid Glass floating tab bar Telegram itself adopted
    // ArkGram recipe (decompiled MainTabBar): floating island with a tall
    // theme-background barBackgroundStyle mask instead of a gradientMask
    .barFloatingStyle({
      barBottomMargin: this.isChatDetailVisible() ? 0 : TAB_BAR_FLOATING_BOTTOM_MARGIN,
      barOpacity: this.isChatDetailVisible() ? 0 : 1,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    })
    .barBackgroundStyle({
      maskColor: TgUiTokens.COLOR_BG_PRIMARY,
      maskHeight: this.isChatDetailVisible() ? 0 : TAB_BAR_BACKPLATE_HEIGHT
    })
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .animationDuration(0)
    .scrollable(false)
    .onChange((index: number) => {
      hilog.info(DOMAIN, TAG, 'HdsTabs onChange: %{public}d', index);
      this.handleTabChange(index);
    })
    .width('100%')
    .height('100%')
  }
}
