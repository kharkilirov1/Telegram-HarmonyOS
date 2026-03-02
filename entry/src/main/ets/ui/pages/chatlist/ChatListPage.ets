// ChatListPage — main chat list tab
// Phase D-3: Stack overlay layout — list scrolls under translucent top bar for blur effect
//
// Data flow: AppStore → subscribe → rebuildList → ChatListDataSource → LazyForEach → TgChatRow

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { ChatItemVO, buildChatItemVO } from './ChatItemVO';
import { ChatListDataSource } from './ChatListDataSource';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgUiFeatureFlags } from '../../tg_ui/TgUiFeatureFlags';
import { TgChatRow, TgChatRowData } from '../../tg_ui/atoms/TgChatRow';
import { TgChatSendStatus } from '../../tg_ui/atoms/TgChatMeta';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { TgSearchBar } from '../../tg_ui/atoms/TgSearchBar';
import { localized } from '../../../core/utils/AppResource';
import { computeTopBarHeight, computeTabBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { uiObserver, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0012;
const TAG = 'ChatListPage';

class ChatRouteParams {
  chatId: number = 0;

  constructor(chatId: number) {
    this.chatId = chatId;
  }
}

@Component
export struct ChatListPage {
  pageStack: NavPathStack = new NavPathStack();

  @StorageLink(StorageKeys.CONNECTION_STATUS) connectionStatus: string = 'connecting';
  @StorageLink(StorageKeys.CHATS_COUNT) chatsCount: number = 0;

  @State private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @State private listBottomInset: number = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;

  private dataSource: ChatListDataSource = new ChatListDataSource();
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private mainWindow?: window.Window;

  aboutToAppear(): void {
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    this.bindNavigationStack();
    this.computeSafeInsets();
    this.bindWindowSizeListener();

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.rebuildList(store.getState());

      this.unsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          setTimeout(() => {
            this.rebuildScheduled = false;
            try {
              const currentState = getAppCoreRuntime().getStore().getState();
              this.rebuildList(currentState);
            } catch (e) {
              hilog.error(DOMAIN, TAG, 'Rebuild failed: %{public}s', String(e));
            }
          }, 0);
        }
      });

      hilog.info(DOMAIN, TAG, 'Subscribed to store');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    removeWindowSizeListener(this.mainWindow);
    this.mainWindow = undefined;
    hilog.info(DOMAIN, TAG, 'Unsubscribed from store');
  }

  private bindWindowSizeListener(): void {
    try {
      removeWindowSizeListener(this.mainWindow);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.mainWindow = getMainWindow(context);
      if (this.mainWindow !== undefined) {
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          this.computeSafeInsets();
        });
      }
    } catch (_error) {
      this.mainWindow = undefined;
    }
  }

  private computeSafeInsets(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.listBottomInset = computeTabBottomInset(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.listBottomInset = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
    }
  }

  private rebuildList(state: AppState): void {
    const items: ChatItemVO[] = [];
    const seenChatIds: Set<number> = new Set<number>();
    for (const chatId of state.chats.orderedChatIds) {
      if (seenChatIds.has(chatId)) {
        continue;
      }
      seenChatIds.add(chatId);
      const chat = state.chats.chats.get(chatId);
      if (chat) {
        items.push(buildChatItemVO(chat, state));
      }
    }
    this.dataSource.applyDiff(items);
  }

  private getTgReuseId(item: ChatItemVO): string {
    const pinnedKey: string = item.isPinned ? 'p1' : 'p0';
    const mutedKey: string = item.isMuted ? 'm1' : 'm0';
    const unreadKey: string = item.unreadCount > 99 ? 'u99p' : (item.unreadCount > 0 ? 'u1' : 'u0');
    const timeKey: string = item.formattedTime.length > 0 ? 't1' : 't0';
    return `tg_chat_row_${pinnedKey}_${mutedKey}_${unreadKey}_${timeKey}_${item.sendStatus}`;
  }

  private mapSendStatus(status: 'none' | 'pending' | 'sent' | 'read' | 'failed'): TgChatSendStatus {
    switch (status) {
      case 'pending':
        return TgChatSendStatus.Sending;
      case 'sent':
        return TgChatSendStatus.Sent;
      case 'read':
        return TgChatSendStatus.Read;
      case 'failed':
        return TgChatSendStatus.Failed;
      default:
        return TgChatSendStatus.None;
    }
  }

  private toTgRowData(item: ChatItemVO): TgChatRowData {
    const row = new TgChatRowData();
    row.chatId = item.chatId;
    row.title = item.title;
    row.preview = item.lastMessage;
    row.timeText = item.formattedTime;
    row.unreadCount = item.unreadCount;
    row.isMuted = item.isMuted;
    row.isPinned = item.isPinned;
    row.sendStatus = this.mapSendStatus(item.sendStatus);
    row.avatarInitials = item.initials;
    row.avatarBackgroundColor = item.avatarColor;
    row.avatarUseImage = item.avatarImagePath.length > 0;
    if (item.avatarImagePath.length > 0) {
      row.avatarImageSrc = item.avatarImagePath;
    }
    row.avatarIsOnline = item.avatarOnline;
    return row;
  }

  private openChat(item: ChatItemVO): void {
    hilog.info(DOMAIN, TAG, 'openChat called for chatId: %{public}d', item.chatId);
    if (!TgUiFeatureFlags.USE_TG_CHAT_V2) {
      hilog.info(DOMAIN, TAG, 'TgChatV2 feature flag is disabled');
      return;
    }
    if (item.chatId <= 0) {
      hilog.error(DOMAIN, TAG, 'Invalid chatId: %{public}d', item.chatId);
      return;
    }
    const navStack = this.bindNavigationStack();
    if (navStack === undefined) {
      hilog.error(DOMAIN, TAG, 'Navigation stack unavailable');
      return;
    }

    const prevChatId: number = AppStorage.get<number>(StorageKeys.ACTIVE_CHAT_ID) || 0;
    const prevTitle: string = AppStorage.get<string>(StorageKeys.ACTIVE_CHAT_TITLE) || '';
    hilog.info(DOMAIN, TAG, 'Setting active chat and pushing TgChatScreenPage');
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, item.chatId);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, item.title);

    try {
      navStack.pushPathByName('TgChatScreenPage', new ChatRouteParams(item.chatId));
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
    } catch (e) {
      AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, prevChatId);
      AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, prevTitle);
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
      hilog.error(DOMAIN, TAG, 'Failed to push TgChatScreenPage: %{public}s', String(e));
    }
  }

  private bindNavigationStack(): NavPathStack | undefined {
    try {
      const navigationInfo: uiObserver.NavigationInfo | undefined = this.queryNavigationInfo();
      if (navigationInfo !== undefined) {
        this.pageStack = navigationInfo.pathStack;
      }
    } catch (_error) {
    }
    return this.pageStack;
  }

  @Builder
  private buildListHeader() {
    // Search bar (scrolls with content — hides behind top bar on scroll, iOS style)
    ListItem() {
      TgSearchBar({
        placeholder: localized($r('app.string.search_placeholder').id, 'Search'),
        onTextChange: (_value: string) => {
          // TODO: filter chat list by search text
        }
      })
    }

    // Connection status banner
    if (this.connectionStatus !== 'ready') {
      ListItem() {
        Row() {
          LoadingProgress()
            .width(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
            .height(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
          Text(this.connectionStatus === 'connecting'
            ? localized($r('app.string.call_connecting').id, 'Connecting...')
            : localized($r('app.string.loading').id, 'Loading...'))
            .fontSize(TgUiTokens.CHATLIST_STATUS_TEXT_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ left: TgUiTokens.CHATLIST_STATUS_GAP })
        }
        .width('100%')
        .padding({
          left: TgUiTokens.SPACE_16,
          top: TgUiTokens.SPACE_8,
          bottom: TgUiTokens.SPACE_4
        })
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // ── Content layer (list scrolls under top bar for blur) ──
      if (this.chatsCount > 0) {
        List() {
          this.buildListHeader()
          LazyForEach(this.dataSource, (item: ChatItemVO) => {
            ListItem() {
              TgChatRow({
                data: this.toTgRowData(item),
                showSeparator: TgUiFeatureFlags.USE_INTERNAL_CHAT_ROW_SEPARATOR
              })
                .reuseId(this.getTgReuseId(item))
            }
            .onClick(() => {
              this.openChat(item);
            })
          }, (item: ChatItemVO) => item.chatId.toString())
        }
        .cachedCount(10)
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring)
        .contentStartOffset(this.topBarTotalHeight)
        .contentEndOffset(this.listBottomInset)
      } else {
        Column() {
          LoadingProgress()
            .width(TgUiTokens.CHATLIST_LOADING_SIZE)
            .height(TgUiTokens.CHATLIST_LOADING_SIZE)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
          Text(localized($r('app.string.loading').id, 'Loading...'))
            .fontSize(TgUiTokens.CHATLIST_STATUS_TEXT_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ top: TgUiTokens.CHATLIST_STATUS_GAP })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      // ── Top bar layer (overlays content, translucent + blur) ──
      TgTopBar({
        title: localized($r('app.string.chats_title').id, 'Chats'),
        showRightAction: true,
        rightIcon: $r('app.media.ic_search')
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
