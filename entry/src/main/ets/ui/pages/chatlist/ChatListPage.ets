// ChatListPage — main chat list tab
// Phase D-3: Stack overlay layout — list scrolls under translucent top bar for blur effect
//
// Data flow: AppStore → subscribe → rebuildList → ChatListDataSource → LazyForEach → TgChatRow

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { ChatItemVO, buildChatItemVO } from './ChatItemVO';
import { ChatListDataSource } from './ChatListDataSource';
import { ChatListItem } from './ChatListItem';
import { AppShellTokens } from '../../theme/AppShellTokens';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgUiFeatureFlags } from '../../tg_ui/TgUiFeatureFlags';
import { TgChatRow, TgChatRowData } from '../../tg_ui/atoms/TgChatRow';
import { TgChatSendStatus } from '../../tg_ui/atoms/TgChatMeta';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { TgSearchBar } from '../../tg_ui/atoms/TgSearchBar';
import { getString } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0012;
const TAG = 'ChatListPage';

declare function px2vp(value: number): number;

@Component
export struct ChatListPage {
  pageStack?: NavPathStack;

  @StorageLink(StorageKeys.CONNECTION_STATUS) connectionStatus: string = 'connecting';
  @StorageLink(StorageKeys.CHATS_COUNT) chatsCount: number = 0;

  @State private topBarTotalHeight: number = 44;
  @State private listBottomInset: number = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;

  private dataSource: ChatListDataSource = new ChatListDataSource();
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private mainWindow?: window.Window;

  aboutToAppear(): void {
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
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
    if (this.mainWindow !== undefined) {
      try {
        this.mainWindow.off('windowSizeChange');
      } catch (_error) {
      }
      this.mainWindow = undefined;
    }
    hilog.info(DOMAIN, TAG, 'Unsubscribed from store');
  }

  private bindWindowSizeListener(): void {
    try {
      if (this.mainWindow !== undefined) {
        try {
          this.mainWindow.off('windowSizeChange');
        } catch (_error) {
        }
      }
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage = context.windowStage;
      if (windowStage) {
        this.mainWindow = windowStage.getMainWindowSync();
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          this.computeSafeInsets();
        });
      }
    } catch (_error) {
      this.mainWindow = undefined;
    }
  }

  private computeSafeInsets(): void {
    this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
    this.listBottomInset = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage = context.windowStage;
      if (windowStage) {
        const mainWindow = windowStage.getMainWindowSync();
        const systemAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        const topInset = px2vp(systemAvoidArea.topRect.height);
        this.topBarTotalHeight = topInset + TgUiTokens.TOP_BAR_HEIGHT;

        let bottomInset = px2vp(systemAvoidArea.bottomRect.height);
        try {
          const navAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
          bottomInset = Math.max(bottomInset, px2vp(navAvoidArea.bottomRect.height));
        } catch (_error) {
        }

        const dynamicBottomInset = TgUiTokens.TAB_BAR_ISLAND_HEIGHT
          + Math.max(bottomInset, TgUiTokens.TAB_BAR_ISLAND_BOTTOM_MARGIN)
          + TgUiTokens.SPACE_6;
        this.listBottomInset = dynamicBottomInset;
      }
    } catch (_error) {
    }
  }

  private localized(resourceId: number, fallback: string): string {
    const value = getString(resourceId);
    return value.length > 0 ? value : fallback;
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

  private getReuseId(item: ChatItemVO): string {
    const pinnedKey: string = item.isPinned ? 'p1' : 'p0';
    const unreadKey: string = item.unreadCount > 0 ? 'u1' : 'u0';
    const timeKey: string = item.formattedTime.length > 0 ? 't1' : 't0';
    return `chat_row_${pinnedKey}_${unreadKey}_${timeKey}`;
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
    if (!TgUiFeatureFlags.USE_TG_CHAT_V2) {
      return;
    }
    if (this.pageStack === undefined) {
      return;
    }
    if (item.chatId <= 0) {
      return;
    }
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, item.chatId);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, item.title);
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
    this.pageStack.pushPathByName('TgChatScreenPage', null);
  }

  @Builder
  private buildListHeader() {
    // Search bar (scrolls with content — hides behind top bar on scroll, iOS style)
    ListItem() {
      TgSearchBar({
        placeholder: this.localized($r('app.string.search_placeholder').id, 'Search'),
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
            .width(AppShellTokens.LIST_ROW_STATUS_ICON_SIZE)
            .height(AppShellTokens.LIST_ROW_STATUS_ICON_SIZE)
            .color(AppShellTokens.ACCENT)
          Text(this.connectionStatus === 'connecting'
            ? this.localized($r('app.string.call_connecting').id, 'Connecting...')
            : this.localized($r('app.string.loading').id, 'Loading...'))
            .fontSize(AppShellTokens.LIST_ROW_STATUS_TEXT_SIZE)
            .fontColor(AppShellTokens.TEXT_SECONDARY)
            .margin({ left: AppShellTokens.LIST_ROW_STATUS_TEXT_GAP })
        }
        .width('100%')
        .padding({
          left: AppShellTokens.LIST_ROW_STATUS_LEFT_PADDING,
          top: AppShellTokens.LIST_ROW_STATUS_TOP_PADDING,
          bottom: AppShellTokens.LIST_ROW_STATUS_BOTTOM_PADDING
        })
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // ── Content layer (list scrolls under top bar for blur) ──
      if (this.chatsCount > 0) {
        if (TgUiFeatureFlags.USE_TG_CHATLIST_V2) {
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
          List() {
            this.buildListHeader()
            LazyForEach(this.dataSource, (item: ChatItemVO) => {
              ListItem() {
                ChatListItem({ item: item }).reuseId(this.getReuseId(item))
              }
              .onClick(() => {
                this.openChat(item);
              })
            }, (item: ChatItemVO) => item.chatId.toString())
          }
          .divider({
            strokeWidth: AppShellTokens.LIST_ROW_SEPARATOR_STROKE,
            startMargin: AppShellTokens.LIST_ROW_CONTENT_START,
            color: AppShellTokens.CHATLIST_SEPARATOR
          })
          .cachedCount(10)
          .width('100%')
          .height('100%')
          .edgeEffect(EdgeEffect.Spring)
          .contentStartOffset(this.topBarTotalHeight)
          .contentEndOffset(this.listBottomInset)
        }
      } else {
        Column() {
          LoadingProgress()
            .width(AppShellTokens.LIST_ROW_LOADING_ICON_SIZE)
            .height(AppShellTokens.LIST_ROW_LOADING_ICON_SIZE)
            .color(AppShellTokens.ACCENT)
          Text(this.localized($r('app.string.loading').id, 'Loading...'))
            .fontSize(AppShellTokens.LIST_ROW_STATUS_TEXT_SIZE)
            .fontColor(AppShellTokens.TEXT_SECONDARY)
            .margin({ top: AppShellTokens.LIST_ROW_STATUS_TEXT_GAP })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      // ── Top bar layer (overlays content, translucent + blur) ──
      TgTopBar({
        title: this.localized($r('app.string.chats_title').id, 'Chats'),
        showRightAction: true,
        rightIcon: $r('app.media.ic_search')
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppShellTokens.BACKGROUND)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
