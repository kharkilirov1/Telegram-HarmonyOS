import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createLoadChatsUseCase, LoadChatsUseCase } from '../../../domain/usecases/loadChats';
import { ChatItemVO, buildChatItemVO } from '../chatlist/ChatItemVO';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { TgChatRow } from '../../tg_ui/atoms/TgChatRow';
import { TgChatSendStatus } from '../../tg_ui/atoms/TgChatMeta';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0044;
const TAG = 'ForwardTargetPicker';

export class ForwardTargetPickerRouteParams {
  sourceChatId: number = 0;

  constructor(sourceChatId: number) {
    this.sourceChatId = sourceChatId;
  }
}

export class ForwardTargetPickerResult {
  chatId: number = 0;
  chatTitle: string = '';

  constructor(chatId: number, chatTitle: string) {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
  }
}

@ComponentV2
export struct TgForwardTargetPickerPage {
  @Local pageStack: NavPathStack = new NavPathStack();
  @Local private sourceChatId: number = 0;
  @Local private searchQuery: string = '';
  @Local private filteredChats: ChatItemVO[] = [];
  @Local private filteredChatsCount: number = 0;
  @Local private isLoading: boolean = false;

  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private rebuildTimerId: number = -1;
  private pageLifecycleToken: number = 0;
  private loadChatsUseCase?: LoadChatsUseCase;
  private autoInitialLoadRequested: boolean = false;
  private isClosing: boolean = false;

  aboutToAppear(): void {
    try {
      this.isClosing = false;
      this.pageLifecycleToken++;
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.loadChatsUseCase = createLoadChatsUseCase(store, getTdGatewayAdapter());
      this.rebuildChats(store.getState());
      this.maybeLoadInitialChats(store.getState());

      if (this.unsubscribe !== undefined) {
        this.unsubscribe();
        this.unsubscribe = undefined;
      }

      const lifecycleToken: number = this.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = store.subscribe((newState: AppState, prevState: AppState) => {
        if (lifecycleToken !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
          return;
        }
        this.maybeLoadInitialChats(newState);
        if (newState.chats !== prevState.chats || newState.messages !== prevState.messages || newState.users !== prevState.users) {
          if (!this.rebuildScheduled) {
            this.rebuildScheduled = true;
            let scheduledTimerId: number = -1;
            scheduledTimerId = setTimeout(() => {
              if (lifecycleToken !== this.pageLifecycleToken ||
                this.rebuildTimerId !== scheduledTimerId ||
                this.unsubscribe !== activeUnsubscribe) {
                return;
              }
              this.rebuildTimerId = -1;
              this.rebuildScheduled = false;
              try {
                const currentState = getAppCoreRuntime().getStore().getState();
                this.rebuildChats(currentState);
                this.maybeLoadInitialChats(currentState);
              } catch (error) {
                hilog.error(DOMAIN, TAG, 'rebuild failed: %{public}s', String(error));
              }
            }, 0) as number;
            this.rebuildTimerId = scheduledTimerId;
          }
        }
      });
      this.unsubscribe = activeUnsubscribe;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'aboutToAppear failed: %{public}s', String(error));
    }
  }

  aboutToDisappear(): void {
    this.isClosing = false;
    this.pageLifecycleToken++;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    if (this.rebuildTimerId >= 0) {
      clearTimeout(this.rebuildTimerId);
      this.rebuildTimerId = -1;
    }
    this.rebuildScheduled = false;
    this.loadChatsUseCase = undefined;
    this.autoInitialLoadRequested = false;
    this.isLoading = false;
  }

  private maybeLoadInitialChats(state: AppState): void {
    const useCase = this.loadChatsUseCase;
    if (!useCase || this.autoInitialLoadRequested) {
      return;
    }
    if (state.connection.status !== 'ready') {
      return;
    }
    if (state.chats.orderedChatIds.length > 0 || !state.chats.hasMore) {
      return;
    }
    if (useCase.isLoadingInProgress()) {
      return;
    }

    this.autoInitialLoadRequested = true;
    this.isLoading = true;
    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.loadInitial()
      .catch((error: Object) => {
        if (lifecycleToken !== this.pageLifecycleToken || this.loadChatsUseCase !== useCase) {
          return;
        }
        this.autoInitialLoadRequested = false;
        hilog.warn(DOMAIN, TAG, 'initial chat load failed: %{public}s', String(error));
      })
      .finally(() => {
        if (lifecycleToken !== this.pageLifecycleToken || this.loadChatsUseCase !== useCase) {
          return;
        }
        this.isLoading = false;
      });
  }

  private rebuildChats(state: AppState): void {
    const items: ChatItemVO[] = [];
    const seenChatIds: Set<number> = new Set<number>();
    const normalizedQuery = this.searchQuery.trim().toLowerCase();

    for (const chatId of state.chats.orderedChatIds) {
      if (seenChatIds.has(chatId)) {
        continue;
      }
      seenChatIds.add(chatId);
      const chat = state.chats.chats.get(chatId);
      if (!chat) {
        continue;
      }
      const item = buildChatItemVO(chat, state);
      if (normalizedQuery.length === 0 || this.matchesSearch(item, normalizedQuery)) {
        items.push(item);
      }
    }

    this.filteredChats = items;
    this.filteredChatsCount = items.length;
  }

  private matchesSearch(item: ChatItemVO, normalizedQuery: string): boolean {
    if (normalizedQuery.length === 0) {
      return true;
    }
    if (item.title.toLowerCase().includes(normalizedQuery)) {
      return true;
    }
    return `${item.previewPrefix} ${item.lastMessage}`.toLowerCase().includes(normalizedQuery);
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

  private handleBackPress(): void {
    if (!this.canPopPageStack('back')) {
      return;
    }
    try {
      this.isClosing = true;
      this.pageStack.pop();
    } catch (error) {
      this.isClosing = false;
      hilog.error(DOMAIN, TAG, 'Failed to pop forward picker: %{public}s', String(error));
    }
  }

  private handleSearchChange(value: string): void {
    this.searchQuery = value;
    try {
      this.rebuildChats(getAppCoreRuntime().getStore().getState());
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'search rebuild failed: %{public}s', String(error));
    }
  }

  private handleChatSelect(item: ChatItemVO): void {
    if (!this.canPopPageStack('result')) {
      return;
    }
    try {
      this.isClosing = true;
      this.pageStack.pop(new ForwardTargetPickerResult(item.chatId, item.title));
    } catch (error) {
      this.isClosing = false;
      hilog.error(DOMAIN, TAG, 'Failed to pop forward picker with result: %{public}s', String(error));
    }
  }

  private canPopPageStack(action: string): boolean {
    if (this.isClosing) {
      hilog.warn(DOMAIN, TAG, 'Ignoring duplicate forward picker %{public}s pop while closing', action);
      return false;
    }
    try {
      if (this.pageStack.size() > 0) {
        return true;
      }
      hilog.error(DOMAIN, TAG, 'Cannot pop forward picker for %{public}s: pageStack is empty', action);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Cannot inspect forward picker pageStack for %{public}s: %{public}s',
        action, String(error));
    }
    return false;
  }

  @Builder
  private buildSearchRow() {
    Row() {
      Search({
        value: this.searchQuery,
        placeholder: localized($r('app.string.search_placeholder').id, 'Search')
      })
        .width('100%')
        .height(TgUiTokens.SEARCH_BAR_HEIGHT)
        .backgroundColor(TgUiTokens.SEARCH_BAR_BG)
        .borderRadius(TgUiTokens.SEARCH_BAR_RADIUS)
        .placeholderColor(TgUiTokens.SEARCH_BAR_PLACEHOLDER_COLOR)
        .placeholderFont({
          size: TgUiTokens.SEARCH_BAR_FONT_SIZE,
          weight: FontWeight.Regular
        })
        .textFont({
          size: TgUiTokens.SEARCH_BAR_FONT_SIZE,
          weight: FontWeight.Regular
        })
        .fontColor(TgUiTokens.SEARCH_BAR_TEXT_COLOR)
        .searchIcon({
          src: TgUiTokens.ICON_RES_SEARCH,
          size: TgUiTokens.SEARCH_BAR_ICON_SIZE,
          color: TgUiTokens.SEARCH_BAR_ICON_COLOR
        })
        .cancelButton({ style: CancelButtonStyle.INPUT })
        .onChange((value: string) => {
          this.handleSearchChange(value);
        })
        .onSubmit((value: string) => {
          this.handleSearchChange(value);
        })
    }
    .width('100%')
    .height(TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT)
    .padding({
      left: TgUiTokens.SEARCH_BAR_SIDE_INSET,
      right: TgUiTokens.SEARCH_BAR_SIDE_INSET
    })
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildBody() {
    if (this.filteredChatsCount > 0) {
      List({ space: 0 }) {
        ForEach(this.filteredChats, (item: ChatItemVO) => {
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
              avatarImageSrc: item.avatarImagePath.length > 0 ? item.avatarImagePath : $r('app.media.app_icon_transparent'),
              avatarIsOnline: item.avatarOnline,
              isVerified: item.isVerified,
              isScam: item.isScam,
              isFake: item.isFake,
              isSecret: item.isSecret,
              hasMention: item.hasMention,
              showSeparator: true
            })
          }
          .onClick(() => {
            this.handleChatSelect(item);
          })
        }, (item: ChatItemVO) => item.chatId.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    } else {
      Column() {
        Text(this.isLoading
          ? localized($r('app.string.loading').id, 'Loading...')
          : (this.searchQuery.trim().length > 0
            ? localized($r('app.string.search_no_results').id, 'No results found')
            : localized($r('app.string.no_messages').id, 'No messages yet')))
          .fontSize(TgUiTokens.SEARCH_BAR_FONT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
  }

  build() {
    NavDestination() {
      Column() {
        TgTopBar({
          title: localized($r('app.string.action_forward').id, 'Forward'),
          showBackAction: true,
          onBackPress: (): void => {
            this.handleBackPress();
          }
        })
        this.buildSearchRow()
        this.buildBody()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
      const params = context.pathInfo.param as ForwardTargetPickerRouteParams;
      if (params && params.sourceChatId > 0) {
        this.sourceChatId = params.sourceChatId;
      }
    })
    .onBackPressed((): boolean => {
      this.handleBackPress();
      return true;
    })
  }
}

@Builder
export function TgForwardTargetPickerPageBuilder() {
  TgForwardTargetPickerPage()
}
