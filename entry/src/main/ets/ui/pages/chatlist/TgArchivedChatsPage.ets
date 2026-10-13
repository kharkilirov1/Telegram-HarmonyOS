import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { AppStore } from '../../../core/store/AppStore';
import { TdGatewayPort } from '../../../domain/ports/TdGatewayPort';
import { chatUIState, navigationUIState } from '../../../core/model/UIStateModels';
import { localized } from '../../../core/utils/AppResource';
import { createLoadArchiveChatsUseCase, LoadArchiveChatsUseCase } from '../../../domain/usecases/loadArchiveChats';
import { createMoveChatToListUseCase, MoveChatToListUseCase } from '../../../domain/usecases/moveChatToList';
import { createToggleChatPinnedUseCase, ToggleChatPinnedUseCase } from '../../../domain/usecases/toggleChatPinned';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { TgChatRow } from '../../tg_ui/atoms/TgChatRow';
import { TgChatSendStatus } from '../../tg_ui/atoms/TgChatMeta';
import { TgIcon } from '../../tg_ui/atoms/TgIcon';
import {
  TgChatTopBar,
  TgChatTopBarSubtitleMode,
  TgChatTopBarTrailingAction
} from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import {
  computeTabBottomInset,
  computeTopBarHeight,
  getMainWindow,
  addWindowSizeListener,
  removeWindowSizeListener
} from '../../utils/SafeAreaUtils';
import { ROOT_TAB_BAR_FALLBACK_CONTENT_INSET } from '../../utils/RootTabBarGeometry';
import { ChatItemVO, buildChatItemVO } from './ChatItemVO';
import { ChatListDataSource } from './ChatListDataSource';
import { ChatScreenRouteParams } from '../chat/ChatScreenRouteParams';

const DOMAIN = 0x0012;
const TAG = 'TgArchivedChatsPage';
const CHAT_NAV_TRANSITION_LOCK_MS = 760;

@ComponentV2
export struct TgArchivedChatsPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private listBottomInset: number = ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;
  @Local private searchQuery: string = '';
  @Local private isSearchMode: boolean = false;
  @Local private filteredChatsCount: number = 0;

  private dataSource: ChatListDataSource = new ChatListDataSource();
  private unsubscribe?: () => void;
  private pageLifecycleToken: number = 0;
  private loadArchiveUseCase?: LoadArchiveChatsUseCase;
  private accountStore?: AppStore;
  private accountScope?: AppStore;
  private chatGateway?: TdGatewayPort;
  private moveChatToListUseCase?: MoveChatToListUseCase;
  private pinUseCase?: ToggleChatPinnedUseCase;
  private archiveLoadInFlight: boolean = false;
  private archiveHasMore: boolean = true;
  private mainWindow?: window.Window;
  private windowSizeListener?: () => void;

  onPageShow(): void {
    navigationUIState.chatNavLockUntil = 0;
    navigationUIState.chatScreenVisible = false;
    navigationUIState.activeChatId = 0;
    navigationUIState.activeChatTitle = '';
    chatUIState.activeChatId = 0;
    chatUIState.activeChatTitle = '';
    AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, 0);
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, 0);
    AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, '');
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.computeSafeInsets();
    this.bindWindowSizeListener();
    const runtime = getAppCoreRuntime();
    const store = runtime.getStore();
    const gateway = getTdGatewayAdapter();
    this.accountStore = store;
    this.accountScope = store.createScope();
    this.chatGateway = gateway;
    this.loadArchiveUseCase = createLoadArchiveChatsUseCase(store, gateway);
    this.moveChatToListUseCase = createMoveChatToListUseCase(gateway);
    this.pinUseCase = createToggleChatPinnedUseCase(gateway);
    this.rebuildList(store.getState());

    const subscriptionToken = this.pageLifecycleToken;
    let activeUnsubscribe: (() => void) | undefined = undefined;
    activeUnsubscribe = store.subscribe((newState: AppState, prevState: AppState) => {
      if (subscriptionToken !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
        return;
      }
      if (newState.chats !== prevState.chats || newState.messages !== prevState.messages ||
        newState.users !== prevState.users) {
        this.rebuildList(newState);
      }
    });
    this.unsubscribe = activeUnsubscribe;
    this.loadMoreArchiveChats();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    this.loadArchiveUseCase = undefined;
    this.accountStore = undefined;
    this.accountScope = undefined;
    this.chatGateway = undefined;
    this.moveChatToListUseCase = undefined;
    this.pinUseCase = undefined;
    this.archiveLoadInFlight = false;
    removeWindowSizeListener(this.windowSizeListener);
    this.windowSizeListener = undefined;
    this.mainWindow = undefined;
  }

  private computeSafeInsets(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.listBottomInset = computeTabBottomInset(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.STATUS_BAR_FALLBACK_INSET + TgUiTokens.TOP_BAR_HEIGHT +
        TgUiTokens.TOP_BAR_BOTTOM_PADDING;
      this.listBottomInset = ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;
    }
  }

  private bindWindowSizeListener(): void {
    try {
      removeWindowSizeListener(this.windowSizeListener);
      this.windowSizeListener = undefined;
      this.mainWindow = undefined;
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.mainWindow = getMainWindow(context);
      if (this.mainWindow !== undefined) {
        const lifecycleToken = this.pageLifecycleToken;
        const boundWindow = this.mainWindow;
        this.windowSizeListener = addWindowSizeListener(boundWindow, (_size: window.Size) => {
          if (lifecycleToken === this.pageLifecycleToken && this.mainWindow === boundWindow) {
            this.computeSafeInsets();
          }
        });
      }
    } catch (_error) {
      this.mainWindow = undefined;
    }
  }

  private chatTopInset(): number {
    return Math.max(0, this.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT - TgUiTokens.TOP_BAR_BOTTOM_PADDING);
  }

  private rebuildList(state: AppState): void {
    const items: ChatItemVO[] = [];
    const normalizedQuery = this.searchQuery.trim().toLowerCase();
    for (const chatId of state.chats.archivedChatIds) {
      const chat = state.chats.chats.get(chatId);
      if (!chat || chat.archiveOrder === '0') {
        continue;
      }
      const item = buildChatItemVO(chat, state);
      item.isPinned = chat.isArchivePinned;
      if (normalizedQuery.length === 0 || item.title.toLowerCase().includes(normalizedQuery) ||
        (item.previewPrefix + ' ' + item.lastMessage).toLowerCase().includes(normalizedQuery)) {
        items.push(item);
      }
    }
    this.dataSource.applyDiff(items);
    this.filteredChatsCount = items.length;
  }

  private loadMoreArchiveChats(): void {
    const useCase = this.loadArchiveUseCase;
    if (!useCase || this.archiveLoadInFlight || !this.archiveHasMore) {
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    const baselineCount = getAppCoreRuntime().getStore().getState().chats.archivedChatIds.length;
    this.archiveLoadInFlight = true;
    useCase.execute(50)
      .then(() => {
        if (lifecycleToken !== this.pageLifecycleToken || this.loadArchiveUseCase !== useCase) {
          return;
        }
        this.archiveLoadInFlight = false;
        const nextCount = getAppCoreRuntime().getStore().getState().chats.archivedChatIds.length;
        if (nextCount <= baselineCount) {
          this.archiveHasMore = false;
        }
      })
      .catch((error: Object) => {
        if (lifecycleToken !== this.pageLifecycleToken || this.loadArchiveUseCase !== useCase) {
          return;
        }
        this.archiveLoadInFlight = false;
        this.archiveHasMore = false;
        hilog.info(DOMAIN, TAG, 'Archive end/load result: %{public}s', String(error));
      });
  }

  private openChat(item: ChatItemVO): void {
    if (item.chatId === 0 || Date.now() < navigationUIState.chatNavLockUntil) {
      return;
    }
    const store = this.accountStore;
    const gateway = this.chatGateway;
    if (store === undefined || gateway === undefined || this.accountScope === undefined ||
      !this.accountScope.isScopeCurrent() || getAppCoreRuntime().getStore() !== store) return;
    const params = new ChatScreenRouteParams(item.chatId, item.title, store, gateway);
    if (!params.isCurrentAccount(getAppCoreRuntime().getStore())) return;
    const previousOwnerToken = navigationUIState.activeChatOwnerToken;
    const previousChatId = navigationUIState.activeChatId;
    const previousTitle = navigationUIState.activeChatTitle;
    const previousVisible = navigationUIState.chatScreenVisible;
    const previousLockUntil = navigationUIState.chatNavLockUntil;
    const previousStoredChatId = AppStorage.get<number>(StorageKeys.ACTIVE_CHAT_ID) ?? previousChatId;
    const previousStoredTitle = AppStorage.get<string>(StorageKeys.ACTIVE_CHAT_TITLE) ?? previousTitle;
    try {
      const navLockUntil = Date.now() + CHAT_NAV_TRANSITION_LOCK_MS;
      navigationUIState.activeChatOwnerToken = params.navigationToken;
      navigationUIState.chatNavLockUntil = navLockUntil;
      navigationUIState.activeChatId = item.chatId;
      navigationUIState.activeChatTitle = item.title;
      chatUIState.activeChatId = item.chatId;
      chatUIState.activeChatTitle = item.title;
      AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, navLockUntil);
      AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, item.chatId);
      AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, item.title);
      navigationUIState.chatScreenVisible = true;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
      this.pageStack.pushPathByName('TgChatScreenPage', params);
    } catch (error) {
      if (navigationUIState.activeChatOwnerToken === params.navigationToken &&
        params.isCurrentAccount(getAppCoreRuntime().getStore())) {
        navigationUIState.activeChatOwnerToken = previousOwnerToken;
        navigationUIState.chatNavLockUntil = previousLockUntil;
        navigationUIState.activeChatId = previousChatId;
        navigationUIState.activeChatTitle = previousTitle;
        chatUIState.activeChatId = previousChatId;
        chatUIState.activeChatTitle = previousTitle;
        navigationUIState.chatScreenVisible = previousVisible;
        AppStorage.set<number>(StorageKeys.CHAT_NAV_LOCK_UNTIL, previousLockUntil);
        AppStorage.set<number>(StorageKeys.ACTIVE_CHAT_ID, previousStoredChatId);
        AppStorage.set<string>(StorageKeys.ACTIVE_CHAT_TITLE, previousStoredTitle);
        AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, previousVisible);
      }
      hilog.error(DOMAIN, TAG, 'Failed to open archived chat: %{public}s', String(error));
    }
  }

  private closeOrBack(): void {
    if (this.isSearchMode) {
      this.isSearchMode = false;
      this.searchQuery = '';
      this.rebuildList(getAppCoreRuntime().getStore().getState());
      return;
    }
    this.pageStack.pop();
  }

  private mapSendStatus(status: 'none' | 'pending' | 'sent' | 'read' | 'failed'): TgChatSendStatus {
    switch (status) {
      case 'pending': return TgChatSendStatus.Sending;
      case 'sent': return TgChatSendStatus.Sent;
      case 'read': return TgChatSendStatus.Read;
      case 'failed': return TgChatSendStatus.Failed;
      default: return TgChatSendStatus.None;
    }
  }

  @Builder
  private buildArchiveSwipeActions(item: ChatItemVO) {
    Row() {
      Button() {
        Column({ space: 3 }) {
          TgIcon({
            src: TgUiTokens.ICON_RES_PIN,
            iconSize: TgUiTokens.ICON_SIZE_MD,
            tintColor: TgUiTokens.COLOR_UNREAD_TEXT
          })

          Text(item.isPinned
            ? localized($r('app.string.unpin').id, 'Unpin')
            : localized($r('app.string.pin').id, 'Pin'))
            .fontSize(11)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
        .type(ButtonType.Normal)
        .backgroundColor(TgUiTokens.SWIPE_ACTION_PIN)
        .width(88)
        .height('100%')
        .padding(0)
        .borderRadius(0)
        .onClick(() => {
          this.toggleArchivePin(item);
        })

      Button() {
        Column({ space: 3 }) {
          TgIcon({
            src: TgUiTokens.ICON_RES_ARCHIVE,
            iconSize: TgUiTokens.ICON_SIZE_MD,
            tintColor: TgUiTokens.COLOR_UNREAD_TEXT
          })

          Text(localized($r('app.string.unarchive').id, 'Unarchive'))
            .fontSize(11)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
        .type(ButtonType.Normal)
        .backgroundColor(TgUiTokens.SWIPE_ACTION_ARCHIVE)
        .width(88)
        .height('100%')
        .padding(0)
        .borderRadius(0)
        .onClick(() => {
          this.unarchive(item);
        })
    }
    .height('100%')
  }

  private toggleArchivePin(item: ChatItemVO): void {
    const useCase = this.pinUseCase;
    if (!useCase) {
      return;
    }
    useCase.setPinned(item.chatId, !item.isPinned, 'archive')
      .catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Archive pin failed for %{public}d: %{public}s', item.chatId, error.message);
      });
  }

  private unarchive(item: ChatItemVO): void {
    const useCase = this.moveChatToListUseCase;
    if (!useCase) {
      return;
    }
    useCase.execute(item.chatId, 'main')
      .catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Unarchive failed for %{public}d: %{public}s', item.chatId, error.message);
      });
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          if (this.filteredChatsCount > 0) {
            LazyForEach(this.dataSource, (item: ChatItemVO) => {
              ListItem() {
                TgChatRow({
                  chatId: item.chatId,
                  title: item.title,
                  preview: item.isTyping ? item.typingText : item.lastMessage,
                  previewPrefix: item.previewPrefix,
                  previewPrefixStyle: item.previewPrefixStyle,
                  isDraft: item.isTyping ? false : item.isDraft,
                  isTyping: item.isTyping,
                  timeText: item.formattedTime,
                  unreadCount: item.unreadCount,
                  isMuted: item.isMuted,
                  isPinned: item.isPinned,
                  sendStatus: this.mapSendStatus(item.sendStatus),
                  avatarInitials: item.initials,
                  avatarBackgroundColor: item.avatarColor,
                  avatarUseImage: item.avatarImagePath.length > 0,
                  avatarImageSrc: item.avatarImagePath.length > 0
                    ? item.avatarImagePath : $r('app.media.app_icon_transparent'),
                  avatarIsOnline: item.avatarOnline,
                  isVerified: item.isVerified,
                  isScam: item.isScam,
                  isFake: item.isFake,
                  isSecret: item.isSecret,
                  hasMention: item.hasMention,
                  showSeparator: true
                })
                  .reuseId('tg_archive_row_' + item.chatId.toString())
              }
              .swipeAction({
                end: () => {
                  this.buildArchiveSwipeActions(item);
                }
              })
              .onClick(() => this.openChat(item))
            }, (item: ChatItemVO) => 'archive_' + item.chatId.toString())
          } else {
            ListItem() {
              Text(this.searchQuery.trim().length > 0
                ? localized($r('app.string.search_no_results').id, 'No results found')
                : localized($r('app.string.no_messages').id, 'No messages yet'))
                .width('100%')
                .padding(TgUiTokens.SPACE_16)
                .fontSize(TgUiTokens.CHATLIST_STATUS_TEXT_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .textAlign(TextAlign.Center)
            }
          }
        }
        .width('100%')
        .height('100%')
        .cachedCount(10)
        .edgeEffect(EdgeEffect.Spring)
        .contentStartOffset(this.topBarTotalHeight)
        .contentEndOffset(this.listBottomInset)
        .onScrollIndex((_start: number, end: number) => {
          if (end >= this.dataSource.totalCount() - 5) {
            this.loadMoreArchiveChats();
          }
        })

        TgChatTopBar({
          topInset: this.chatTopInset(),
          title: localized($r('app.string.archived_chats').id, 'Archived Chats'),
          subtitle: `${this.filteredChatsCount}`,
          subtitleMode: TgChatTopBarSubtitleMode.Secondary,
          trailingAction: TgChatTopBarTrailingAction.Search,
          isSearchMode: this.isSearchMode,
          searchQuery: this.searchQuery,
          onBackPress: (): void => this.closeOrBack(),
          onSearchPress: (): void => {
            this.isSearchMode = true;
          },
          onSearchQueryChange: (query: string): void => {
            this.searchQuery = query;
            this.rebuildList(getAppCoreRuntime().getStore().getState());
          },
          onSearchClose: (): void => this.closeOrBack()
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
  }
}
