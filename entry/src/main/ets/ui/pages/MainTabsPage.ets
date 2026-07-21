// MainTabsPage — root after auth
// 4 tabs: Contacts, Calls, Chats, Settings — each with independent NavPathStack
// API 23: HdsTabs floating TabBar replaces custom TgTabBar shell

import { ChatListPage } from './chatlist/ChatListPage';
import { TgChatScreenPage } from './chat/TgChatScreenPage';
import { TgArchivedChatsPage } from './chatlist/TgArchivedChatsPage';
import { TgForwardTargetPickerPage } from './forward/TgForwardTargetPickerPage';
import { TgComposePage } from './compose/TgComposePage';
import { TgProfilePage } from './profile/TgProfilePage';
import { ContactsPage } from './contacts/ContactsPage';
import { CallsPage } from './calls/CallsPage';
import { SettingsPage } from './settings/SettingsPage';
import { StorageKeys } from '../../app/bridge/AppStoreBridge';
import { navigationUIState, chatsUIState, NavigationUIState } from '../../core/model/UIStateModels';
import { localized } from '../../core/utils/AppResource';
import { TgUiTokens } from '../tg_ui/tokens/TgUiTokens';
import { TgUiFeatureFlags } from '../tg_ui/TgUiFeatureFlags';
import { TgRootTabUnreadBadge } from '../tg_ui/atoms/TgRootTabUnreadBadge';
import { TgRootSearchDock } from '../tg_ui/atoms/TgRootSearchDock';
import { TgRootMiniPlayer } from '../tg_ui/atoms/TgRootMiniPlayer';
import { globalMediaPlayback, mediaPlaybackUIState, MediaPlaybackUIState } from './chat/GlobalMediaPlayback';
import { TgChatSplitPlaceholder } from '../tg_ui/atoms/TgChatSplitPlaceholder';
import { resolveChatSplitGeometry } from '../utils/ChatSplitGeometry';
import {
  isRootTabBarHidden,
  resolveRootSearchDockGeometry,
  resolveRootTabBarRenderStateFromHidden,
  RootSearchDockGeometry,
  RootTabBarRenderState,
  ROOT_TAB_BAR_TRANSITION_HIDE_MS,
  ROOT_TAB_BAR_TRANSITION_SHOW_MS
} from '../utils/RootTabBarGeometry';
import {
  bleedIconStyle,
  hdsMaterial,
  HdsNavigation,
  HdsNavigationAttribute,
  HdsTabs,
  HdsTabsAttribute,
  HdsBarStyle,
  HdsBarWidthRangeOptions,
  HdsTabsController,
  HdsTabsMiniBar,
  HdsTabsBarChangeMode,
  HdsNavigationTitleMode,
  BottomBuilderShowType,
  TitleSize
} from '@kit.UIDesignKit';
import {
  CapsuleSegmentButtonV2,
  SegmentButtonV2Items,
  SymbolGlyphModifier
} from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0020;
const TAG = 'MainTabsPage';

@ComponentV2
export struct MainTabsPage {
  @Local selectedIndex: number = 2;
  @Local callsFilterIndex: number = 0;
  @Local private keyboardVisible: boolean = false;
  @Local private chatNavigationMode: NavigationMode = NavigationMode.Stack;
  @Local private chatNavBarWidth: number = TgUiTokens.CHAT_SPLIT_NAV_MIN_WIDTH;
  @Local private chatNavBarMaxWidth: number = TgUiTokens.CHAT_SPLIT_NAV_MIN_WIDTH;
  @Local private rootTabsWidth: number = 0;
  @Local private chatListSearchQuery: string = '';
  @Local private chatListSearchActive: boolean = false;
  @Local private chatListSearchClosing: boolean = false;
  @Local private chatListSearchFocusPending: boolean = false;
  @Local private chatListSearchFocusRevision: number = 0;
  @Local private navState: NavigationUIState = navigationUIState;
  @Local private rootBarHidden: boolean = false;
  @Local private rootBarScrollHidden: boolean = false;
  @Local private playback: MediaPlaybackUIState = mediaPlaybackUIState;
  @Local private playerUserCollapsed: boolean = false;
  // True only after applyMiniBarStyle(EXPAND) ran on a visible bar; reset
  // whenever the bar hides so a re-shown bar always mounts COLLAPSE and the
  // expand transaction has a real delta to animate (see rootIslandMiniBar).
  @Local private playerBarStyleApplied: boolean = false;
  private chatsState = chatsUIState;
  private rootSearchTransitionTimerId: number = -1;
  private callsFilterItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.calls_all') },
    { text: $r('app.string.calls_missed') }
  ]);

  private contactsNavStack: NavPathStack = new NavPathStack();
  private callsNavStack: NavPathStack = new NavPathStack();
  private chatListNavStack: NavPathStack = new NavPathStack();
  private chatDetailNavStack: NavPathStack = new NavPathStack();
  private settingsNavStack: NavPathStack = new NavPathStack();
  private controller: HdsTabsController = new HdsTabsController();

  private rootTabBarRenderState(): RootTabBarRenderState {
    return resolveRootTabBarRenderStateFromHidden(this.rootBarHidden);
  }

  private desiredRootBarHidden(): boolean {
    const scrollHidden = TgUiFeatureFlags.USE_ROOT_BAR_AUTO_HIDE_ON_SCROLL &&
      this.rootBarScrollHidden &&
      this.selectedIndex === 2 &&
      this.chatNavigationMode !== NavigationMode.Split &&
      !this.chatListSearchActive && !this.chatListSearchClosing;
    return scrollHidden || isRootTabBarHidden(
      this.selectedIndex,
      this.chatNavigationMode === NavigationMode.Split ? false : this.navState.chatScreenVisible,
      this.keyboardVisible,
      this.chatListSearchActive || this.chatListSearchClosing
    );
  }

  @Monitor('navState.chatScreenVisible', 'keyboardVisible', 'selectedIndex', 'chatNavigationMode',
    'chatListSearchActive', 'chatListSearchClosing')
  private onRootBarInputsChanged(_monitor: IMonitor): void {
    // Entering a chat, leaving the Chats tab or opening Search drops the
    // scroll-hidden latch, so the island is visible again afterwards.
    if (this.navState.chatScreenVisible || this.selectedIndex !== 2 || this.chatListSearchActive) {
      this.rootBarScrollHidden = false;
    }
    this.syncRootBarHidden(true);
  }

  private handleRootBarAutoHide(hidden: boolean): void {
    if (this.rootBarScrollHidden === hidden) {
      return;
    }
    this.rootBarScrollHidden = hidden;
    this.syncRootBarHidden(true);
  }

  // The island used to vanish in one frame: every input was bound directly
  // into HdsTabs attributes as a 0/1 step. Funnel all inputs through a single
  // flag whose change runs inside animateTo, so hide/show follows the shared
  // glass motion policy instead of a step change.
  private syncRootBarHidden(animated: boolean): void {
    const desired = this.desiredRootBarHidden();
    if (desired === this.rootBarHidden) {
      return;
    }
    if (!animated) {
      this.rootBarHidden = desired;
      return;
    }
    try {
      this.getUIContext().animateTo({
        duration: desired ? ROOT_TAB_BAR_TRANSITION_HIDE_MS : ROOT_TAB_BAR_TRANSITION_SHOW_MS,
        curve: desired ? Curve.EaseIn : Curve.EaseOut
      }, () => {
        this.rootBarHidden = desired;
      });
    } catch (_error) {
      this.rootBarHidden = desired;
    }
  }

  private rootTabBarOpacity(): number {
    if (this.chatListSearchActive || this.chatListSearchClosing) {
      return 0;
    }
    return this.rootTabBarRenderState().opacity;
  }

  private shouldShowRootSearchDock(): boolean {
    return TgUiFeatureFlags.USE_HDS_ROOT_SEARCH_MINIBAR &&
      this.selectedIndex === 2 &&
      this.chatNavigationMode !== NavigationMode.Split &&
      !this.navState.chatScreenVisible;
  }

  private rootSearchDockGeometry(): RootSearchDockGeometry {
    return resolveRootSearchDockGeometry(this.rootTabsWidth);
  }

  // The mini player docks into the same single HDS miniBar slot as Search;
  // an active/closing Search always wins the slot, the player returns after.
  private islandPlayerVisible(): boolean {
    return TgUiFeatureFlags.USE_ROOT_ISLAND_MINI_PLAYER &&
      this.playback.hasActive &&
      !this.chatListSearchActive && !this.chatListSearchClosing;
  }

  private rootSearchDockBarWidthRange(): HdsBarWidthRangeOptions | undefined {
    const geometry = this.rootSearchDockGeometry();
    if (this.islandPlayerVisible()) {
      // Expanded player collapses the tab lens exactly like an active Search;
      // a user-collapsed player keeps the full tabs beside its 48vp lens.
      // Gated by the same latch as miniBarStyle: squeezing barWidth while the
      // bar is hidden mounts the tab bar as 48px-wide EXPAND (all five tabs
      // crushed into vertical letter columns, witnessed via bounds dump), and
      // the later style transaction has no width delta left to repack it into
      // the single-tab lens. Width and style must both flip in the same frame
      // as applyMiniBarStyle on a visible bar — the Search activation pattern.
      // Always the FULL tab width: squeezing barWidth to 48 by prop makes HDS
      // crush the still-EXPANDed tab bar into 48px (five tabs as vertical
      // letter columns under the player, witnessed via bounds dump). The
      // 48vp single-tab lens is produced only by the style TRANSACTION in
      // syncIslandPlayerStyle — tab 269.7→48 with a real delta (LESSONS 113).
      const playerWidth = geometry.tabBarWidth;
      return { smallWidth: playerWidth, mediumWidth: playerWidth, largeWidth: playerWidth };
    }
    if (!this.shouldShowRootSearchDock()) {
      return undefined;
    }
    // Telegram iOS collapses the selected-tab lens to 48pt while Search owns
    // the bar. On API23 this also releases the stale full TabBar hit box that
    // otherwise sits above the visually expanded HDS mini bar.
    const width = this.chatListSearchActive && !this.chatListSearchClosing
      ? geometry.activeTabBarWidth
      : geometry.tabBarWidth;
    return { smallWidth: width, mediumWidth: width, largeWidth: width };
  }

  private islandMiniBarExpandedWidthRange(): HdsBarWidthRangeOptions {
    const width = this.rootSearchDockGeometry().miniBarExpandedWidth;
    return { smallWidth: width, mediumWidth: width, largeWidth: width };
  }

  private rootSearchDockExpandedWidthRange(): HdsBarWidthRangeOptions | undefined {
    if (!this.shouldShowRootSearchDock()) {
      return undefined;
    }
    return this.islandMiniBarExpandedWidthRange();
  }

  private rootSearchDockSideMargin(): number | undefined {
    return this.islandPlayerVisible() || this.shouldShowRootSearchDock()
      ? this.rootSearchDockGeometry().sideMargin
      : undefined;
  }

  private playerMiniBarWidthRange(): HdsBarWidthRangeOptions {
    // Witnessed-good expanded player width: full tab width (269.7vp), so the
    // island is [48vp tab lens][player] — slightly narrower than the Search
    // island, wide enough for title/subtitle/controls.
    const width = this.rootSearchDockGeometry().tabBarWidth;
    return { smallWidth: width, mediumWidth: width, largeWidth: width };
  }

  private rootIslandMiniBar(): HdsTabsMiniBar | undefined {
    if (this.islandPlayerVisible()) {
      return {
        miniBarBuilder: () => this.buildRootMiniPlayer(),
        miniBarWidth: this.playerMiniBarWidthRange(),
        // COLLAPSE until the expand transaction has run on a visible bar: a
        // hidden bar that re-renders with an EXPAND prop paints the mini bar
        // wide WITHOUT the width transaction (tab bar stays full), and a later
        // applyMiniBarStyle(EXPAND) is a delta-less no-op. The latch keeps the
        // prop one step behind the transaction, mirroring the Search flow
        // where flag flip + applyMiniBarStyle happen together while visible.
        miniBarStyle: this.playerUserCollapsed || !this.playerBarStyleApplied
          ? HdsBarStyle.COLLAPSE
          : HdsBarStyle.EXPAND,
        enableMiniBarBackground: true,
        enableMiniBarClip: true,
        onBarStyleChange: (miniBarStyle: HdsBarStyle, tabBarStyle: HdsBarStyle,
          miniBarWidth: number, tabBarWidth: number, mode: HdsTabsBarChangeMode): void => {
          hilog.debug(DOMAIN, TAG,
            `islandPlayer barStyleChange mini=${miniBarStyle} tab=${tabBarStyle} ` +
            `miniW=${miniBarWidth} tabW=${tabBarWidth} mode=${mode}`);
          this.handlePlayerBarStyleChange(miniBarStyle, mode);
        },
        onMiniBarAnimationStart: (style: HdsBarStyle, width: number): void => {
          hilog.debug(DOMAIN, TAG, `islandPlayer miniBarAnim style=${style} width=${width}`);
        },
        onTabBarAnimationStart: (style: HdsBarStyle, width: number): void => {
          hilog.debug(DOMAIN, TAG, `islandPlayer tabBarAnim style=${style} width=${width}`);
        }
      };
    }
    return this.rootSearchMiniBar();
  }

  @Builder
  buildRootMiniPlayer() {
    TgRootMiniPlayer({
      title: this.playback.title,
      subtitle: this.playback.subtitle,
      isPlaying: this.playback.isPlaying,
      progress: this.playback.progress,
      collapsed: this.playerUserCollapsed,
      onTogglePlay: (): void => {
        globalMediaPlayback.toggleCurrent().catch((_error: Object) => {});
      },
      onExpandRequest: (): void => {
        this.playerUserCollapsed = false;
        this.playerBarStyleApplied = true;
        this.controller.applyMiniBarStyle(HdsBarStyle.EXPAND);
      },
      onStop: (): void => {
        globalMediaPlayback.stop().catch((_error: Object) => {});
      }
    })
  }

  private handlePlayerBarStyleChange(miniBarStyle: HdsBarStyle, mode: HdsTabsBarChangeMode): void {
    if (!this.islandPlayerVisible() || mode !== HdsTabsBarChangeMode.USER_CLICK) {
      return;
    }
    // Tapping the collapsed tab lens natively re-expands the tabs; mirror the
    // native result into player state so the style prop never disagrees with
    // the actual bar.
    this.playerUserCollapsed = miniBarStyle === HdsBarStyle.COLLAPSE;
  }

  // rootBarHidden is monitored so the expand transaction re-runs every time
  // the bar comes back: while hidden the applied-latch is reset, which forces
  // the miniBarStyle prop back to COLLAPSE (see rootIslandMiniBar for why the
  // prop must never get ahead of the transaction).
  @Monitor('playback.hasActive', 'chatListSearchActive', 'chatListSearchClosing', 'rootBarHidden')
  private onIslandPlayerInputsChanged(monitor: IMonitor): void {
    if (this.rootBarHidden) {
      this.playerBarStyleApplied = false;
      return;
    }
    if (monitor.dirty.includes('rootBarHidden')) {
      // rootBarHidden flips inside the bar show/hide animateTo, so a style
      // transaction issued synchronously here nests into that animation and
      // lands with a broken layout (lens painted under the expanded player,
      // witnessed). Defer until the show animation has finished.
      setTimeout(() => {
        if (!this.rootBarHidden) {
          this.syncIslandPlayerStyle();
        }
      }, ROOT_TAB_BAR_TRANSITION_SHOW_MS + 30);
      return;
    }
    this.syncIslandPlayerStyle();
  }

  private syncIslandPlayerStyle(): void {
    if (this.islandPlayerVisible()) {
      if (!this.playerUserCollapsed) {
        // Latch + transaction together on a visible bar — the Search
        // activation pattern; the bar is COLLAPSE at this point, so the
        // transaction has a delta and animates both bar widths.
        this.playerBarStyleApplied = true;
        hilog.debug(DOMAIN, TAG, 'islandPlayer apply EXPAND (latched)');
        this.controller.applyMiniBarStyle(HdsBarStyle.EXPAND);
      }
      return;
    }
    this.playerUserCollapsed = false;
    this.playerBarStyleApplied = false;
    if (this.playback.hasActive) {
      // Search took the slot; its own activation flow drives the bar style.
      return;
    }
    if (!this.chatListSearchActive && !this.chatListSearchClosing) {
      this.controller.applyMiniBarStyle(HdsBarStyle.COLLAPSE);
    }
  }

  private rootSearchMiniBar(): HdsTabsMiniBar | undefined {
    if (!this.shouldShowRootSearchDock()) {
      return undefined;
    }
    return {
      miniBarBuilder: () => this.buildRootSearchMiniBar(),
      miniBarWidth: this.rootSearchDockExpandedWidthRange(),
      miniBarStyle: this.rootSearchMiniBarStyle(),
      enableMiniBarBackground: true,
      enableMiniBarClip: true,
      onMiniBarAnimationEnd: (style: HdsBarStyle): void => {
        this.handleRootSearchMiniBarAnimationEnd(style);
      }
    };
  }

  private rootSearchMiniBarStyle(): HdsBarStyle {
    return this.chatListSearchActive && !this.chatListSearchClosing
      ? HdsBarStyle.EXPAND
      : HdsBarStyle.COLLAPSE;
  }

  private clearRootSearchTransitionTimer(): void {
    if (this.rootSearchTransitionTimerId !== -1) {
      clearTimeout(this.rootSearchTransitionTimerId);
      this.rootSearchTransitionTimerId = -1;
    }
  }

  private scheduleRootSearchTransitionFallback(expanding: boolean): void {
    this.clearRootSearchTransitionTimer();
    this.rootSearchTransitionTimerId = setTimeout(() => {
      this.rootSearchTransitionTimerId = -1;
      if (expanding) {
        this.finishRootSearchExpand();
        return;
      }
      this.finishRootSearchCollapse();
    }, 320) as number;
  }

  private handleRootSearchMiniBarAnimationEnd(style: HdsBarStyle): void {
    if (style === HdsBarStyle.EXPAND) {
      if (!this.chatListSearchActive || this.chatListSearchClosing ||
        !this.chatListSearchFocusPending) {
        return;
      }
      this.clearRootSearchTransitionTimer();
      this.finishRootSearchExpand();
      return;
    }
    if (style !== HdsBarStyle.COLLAPSE || !this.chatListSearchClosing) {
      return;
    }
    this.clearRootSearchTransitionTimer();
    this.finishRootSearchCollapse();
  }

  private finishRootSearchExpand(): void {
    if (!this.chatListSearchActive || this.chatListSearchClosing ||
      !this.chatListSearchFocusPending) {
      return;
    }
    this.chatListSearchFocusPending = false;
    this.chatListSearchFocusRevision += 1;
  }

  private finishRootSearchCollapse(): void {
    this.chatListSearchFocusPending = false;
    this.chatListSearchActive = false;
    this.chatListSearchClosing = false;
  }

  private clearRootSearchFocus(): void {
    try {
      this.getUIContext().getFocusController().clearFocus();
    } catch (_error) {
    }
  }

  private deferRootSearchFocusClear(): void {
    setTimeout(() => this.clearRootSearchFocus(), 0);
  }

  private activateRootSearchDock(): void {
    if (!this.shouldShowRootSearchDock() || this.chatListSearchClosing) {
      return;
    }
    this.clearRootSearchTransitionTimer();
    this.chatListSearchClosing = false;
    this.chatListSearchActive = true;
    this.chatListSearchFocusPending = true;
    this.controller.applyMiniBarStyle(HdsBarStyle.EXPAND);
    this.scheduleRootSearchTransitionFallback(true);
  }

  private deactivateRootSearchDock(immediate: boolean = false): void {
    if (this.chatListSearchQuery.length > 0) {
      this.chatListSearchQuery = '';
    }
    this.chatListSearchFocusPending = false;
    if (!this.chatListSearchActive && !this.chatListSearchClosing) {
      this.clearRootSearchFocus();
      return;
    }
    this.chatListSearchClosing = true;
    this.controller.applyMiniBarStyle(HdsBarStyle.COLLAPSE);
    if (immediate) {
      this.clearRootSearchFocus();
      this.clearRootSearchTransitionTimer();
      this.finishRootSearchCollapse();
      return;
    }
    this.deferRootSearchFocusClear();
    this.scheduleRootSearchTransitionFallback(false);
  }

  private transferRootSearchToHeader(): void {
    if (!this.chatListSearchActive || this.chatListSearchClosing) {
      return;
    }
    this.clearRootSearchTransitionTimer();
    this.chatListSearchFocusPending = false;
    this.chatListSearchClosing = true;
    this.controller.applyMiniBarStyle(HdsBarStyle.COLLAPSE);
    this.scheduleRootSearchTransitionFallback(false);
  }

  private updateChatListSearchQuery(value: string): void {
    if (value !== this.chatListSearchQuery) {
      this.chatListSearchQuery = value;
    }
  }

  private updateChatSplitGeometry(componentWidth: number): void {
    const geometry = resolveChatSplitGeometry(
      componentWidth,
      TgUiTokens.CHAT_SPLIT_NAV_MIN_WIDTH
    );
    if (geometry.navBarWidth !== this.chatNavBarWidth) {
      this.chatNavBarWidth = geometry.navBarWidth;
    }
    if (geometry.maxNavBarWidth !== this.chatNavBarMaxWidth) {
      this.chatNavBarMaxWidth = geometry.maxNavBarWidth;
    }
  }

  aboutToAppear(): void {
    this.selectedIndex = this.navState.mainTabIndex;
    AppStorage.setOrCreate<number>(StorageKeys.MAIN_TAB_INDEX, this.selectedIndex);
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    this.navState.chatScreenVisible = false;
    this.controller.changeIndex(this.selectedIndex);
    this.syncRootBarHidden(false);
    hilog.info(DOMAIN, TAG, 'MainTabsPage appeared with tab index: %{public}d', this.selectedIndex);
  }

  aboutToDisappear(): void {
    if (this.chatListSearchActive || this.chatListSearchClosing) {
      this.deactivateRootSearchDock(true);
    } else {
      this.clearRootSearchTransitionTimer();
    }
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

    if (index !== 2) {
      this.deactivateRootSearchDock(true);
    }
    this.selectedIndex = index;
    navigationUIState.mainTabIndex = index;
    AppStorage.set<number>(StorageKeys.MAIN_TAB_INDEX, index);

    if (index !== 2) {
      navigationUIState.chatScreenVisible = false;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    }
  }

  // Custom tab bar for Chats: stock BottomTabBarStyle has no badge API,
  // so icon+label metrics are reproduced inside native HdsTabs through bleedIconStyle.
  private chatsTabAccessibilityText(): string {
    const title = localized($r('app.string.chats_title').id, 'Chats');
    const unreadCount = Math.max(0, Math.floor(this.chatsState.totalUnreadCount));
    if (unreadCount === 0) {
      return title;
    }
    const unread = localized($r('app.string.unread').id, 'Unread');
    return `${title}, ${unread}: ${unreadCount}`;
  }

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
          TgRootTabUnreadBadge({ count: this.chatsState.totalUnreadCount })
            .position({
              x: TgUiTokens.TAB_BADGE_OFFSET_X,
              y: TgUiTokens.TAB_BADGE_OFFSET_Y
            })
        }
      }

      Text($r('app.string.chats_title'))
        .fontSize(10)
        .fontColor(this.selectedIndex === 2
          ? TgUiTokens.COMPOSER_ACTION_ACTIVE
          : TgUiTokens.TAB_ITEM_UNSELECTED)
        .margin({ top: 2 })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .accessibilityGroup(true)
    .accessibilityText(this.chatsTabAccessibilityText())
  }

  @Builder
  buildCallsFilterBar() {
    Row() {
      CapsuleSegmentButtonV2({
        items: this.callsFilterItems,
        selectedIndex: this.callsFilterIndex!!
      })
        .width(TgUiTokens.CALLS_FILTER_WIDTH)
    }
    .width('100%')
    .height(TgUiTokens.CALLS_FILTER_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: TgUiTokens.CALLS_FILTER_SIDE_INSET,
      right: TgUiTokens.CALLS_FILTER_SIDE_INSET
    })
  }

  @Builder
  chatDetailPageMap(name: string) {
    if (name === 'TgChatScreenPage') {
      TgChatScreenPage()
    } else if (name === 'TgProfilePage') {
      TgProfilePage()
    } else if (name === 'TgForwardTargetPickerPage') {
      TgForwardTargetPickerPage()
    } else if (name === 'TgComposePage') {
      TgComposePage()
    }
  }

  @Builder
  chatListPageMap(name: string) {
    if (name === 'TgArchivedChatsPage') {
      TgArchivedChatsPage()
    }
  }

  @Builder
  buildRootSearchMiniBar() {
    TgRootSearchDock({
      value: this.chatListSearchQuery,
      placeholder: localized($r('app.string.search_placeholder').id, 'Search'),
      closeText: localized($r('app.string.accessibility_close_search').id, 'Close search'),
      active: this.chatListSearchActive,
      closing: this.chatListSearchClosing,
      focusRequestRevision: this.chatListSearchFocusRevision,
      onActivate: (): void => {
        this.activateRootSearchDock();
      },
      onChange: (value: string): void => {
        this.updateChatListSearchQuery(value);
      },
      onSubmit: (_value: string): void => {
      },
      onClose: (): void => {
        this.deactivateRootSearchDock();
      }
    })
  }

  build() {
    // index обязателен: controller.changeIndex() в aboutToAppear уходит до
    // привязки контроллера и молча игнорируется — без index стартовый таб был 0.
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.chatNavigationMode === NavigationMode.Split) {
        Row() {
          Blank()
            .width(this.chatNavBarWidth)
          TgChatSplitPlaceholder()
            .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
      }

      Navigation(this.chatDetailNavStack) {
        HdsTabs({ index: this.selectedIndex, controller: this.controller }) {
      // Tab 0: Contacts
      TabContent() {
        HdsNavigation(this.contactsNavStack) {
          ContactsPage()
        }
        .titleBar({
          style: {
            originalStyle: {
              backgroundStyle: { backgroundColor: TgUiTokens.COLOR_BG_PRIMARY }
            },
            scrollEffectStyle: {
              backgroundStyle: { backgroundColor: TgUiTokens.COLOR_BG_PRIMARY }
            }
          },
          content: {
            title: {
              mainTitle: $r('app.string.contacts_title'),
              mainTitleSize: TitleSize.TITLE_S
            }
          }
        })
        .mode(NavigationMode.Stack)
        .hideBackButton(true)
      }
      .tabBar(new BottomTabBarStyle(
        {
          normal: new SymbolGlyphModifier($r('sys.symbol.person')),
          selected: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
        },
        $r('app.string.contacts_title')
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
          CallsPage({ onlyMissed: this.callsFilterIndex === 1 })
        }
        .titleBar({
          content: {
            title: {
              mainTitle: $r('app.string.calls_title'),
              mainTitleSize: TitleSize.TITLE_S
            },
            bottomBuilder: {
              builder: () => {
                this.buildCallsFilterBar();
              },
              height: TgUiTokens.CALLS_FILTER_BAR_HEIGHT,
              showType: BottomBuilderShowType.DIRECTLY_SHOW
            }
          }
        })
        .mode(NavigationMode.Stack)
        .hideBackButton(true)
      }
      .tabBar(new BottomTabBarStyle(
        {
          normal: new SymbolGlyphModifier($r('sys.symbol.phone')),
          selected: new SymbolGlyphModifier($r('sys.symbol.phone'))
        },
        $r('app.string.calls_title')
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
        Navigation(this.chatListNavStack) {
          ChatListPage({
            chatDetailStack: this.chatDetailNavStack,
            searchQuery: this.chatListSearchQuery,
            onSearchQueryChange: (value: string): void => {
              this.updateChatListSearchQuery(value);
            },
            onSearchDeactivate: (): void => {
              this.deactivateRootSearchDock();
            },
            onHeaderSearchWillFocus: (): void => {
              this.transferRootSearchToHeader();
            },
            onKeyboardVisibilityChange: (visible: boolean): void => {
              this.keyboardVisible = visible;
            },
            onRootBarAutoHide: (hidden: boolean): void => {
              this.handleRootBarAutoHide(hidden);
            }
          })
        }
        .hideTitleBar(true)
        .hideToolBar(true)
        .navDestination(this.chatListPageMap)
        .mode(NavigationMode.Stack)
      }
      .tabBar(bleedIconStyle(() => {
        this.buildChatsTabBar()
      }))

      // Tab 3: Settings
      TabContent() {
        HdsNavigation(this.settingsNavStack) {
          SettingsPage({
            onOpenCalls: (): void => {
              this.controller.changeIndex(1);
              this.handleTabChange(1);
            }
          })
        }
        .titleBar({
          enableComponentSafeArea: true,
          style: {
            originalStyle: {
              backgroundStyle: { backgroundColor: TgUiTokens.COLOR_BG_SECONDARY }
            },
            scrollEffectStyle: {
              backgroundStyle: { backgroundColor: TgUiTokens.COLOR_BG_SECONDARY }
            }
          },
          content: {
            title: {
              mainTitle: $r('app.string.settings'),
              mainTitleSize: TitleSize.TITLE_S
            }
          }
        })
        .titleMode(HdsNavigationTitleMode.FULL)
        .mode(NavigationMode.Stack)
        .hideBackButton(true)
      }
      .tabBar(new BottomTabBarStyle(
        {
          normal: new SymbolGlyphModifier($r('sys.symbol.gearshape')),
          selected: new SymbolGlyphModifier($r('sys.symbol.gearshape'))
        },
        $r('app.string.settings')
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
        .barOverlap(this.rootTabBarRenderState().overlap)
        .barPosition(BarPosition.End)
        .barHeight(this.rootTabBarRenderState().height)
        .vertical(false)
    // Native HDS floating bar (API 23 immersive material) — matches the
    // iOS 26 Liquid Glass floating tab bar Telegram itself adopted
    // ArkGram recipe (decompiled MainTabBar): floating island with a tall
    // theme-background barBackgroundStyle mask instead of a gradientMask
        .barFloatingStyle({
          barWidth: this.rootSearchDockBarWidthRange(),
          barSideMargin: this.rootSearchDockSideMargin(),
          barBottomMargin: this.rootTabBarRenderState().bottomMargin,
          barOpacity: this.rootTabBarOpacity(),
          miniBar: this.rootIslandMiniBar(),
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        })
        .barBackgroundStyle({
          maskColor: TgUiTokens.COLOR_BG_PRIMARY,
          maskHeight: this.rootTabBarRenderState().maskHeight
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
      .hideTitleBar(true)
      .hideToolBar(true)
      .navDestination(this.chatDetailPageMap)
      .mode(NavigationMode.Auto)
      .navBarWidth(this.chatNavBarWidth)
      .navBarWidthRange([
        TgUiTokens.CHAT_SPLIT_NAV_MIN_WIDTH,
        this.chatNavBarMaxWidth
      ])
      .minContentWidth(TgUiTokens.CHAT_SPLIT_MIN_CONTENT_WIDTH)
      .enableDragBar(false)
      .onNavigationModeChange((mode: NavigationMode) => {
        if (mode !== this.chatNavigationMode) {
          if (mode === NavigationMode.Split &&
            (this.chatListSearchActive || this.chatListSearchClosing)) {
            this.deactivateRootSearchDock(true);
          }
          this.chatNavigationMode = mode;
        }
      })
      .backgroundColor(Color.Transparent)
      .width('100%')
      .height('100%')
    }
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const componentWidth = Number(newArea.width);
      this.updateChatSplitGeometry(componentWidth);
      if (componentWidth > 0 && Math.abs(componentWidth - this.rootTabsWidth) >= 0.5) {
        this.rootTabsWidth = componentWidth;
      }
    })
    .width('100%')
    .height('100%')
  }
}
