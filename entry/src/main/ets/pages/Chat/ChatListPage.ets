import { MessagesController } from '../../controllers/MessagesController';
import { ChatService } from '../../services/ChatService';
import { HapticService } from '../../services/HapticService';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Chat } from '../../models/Chat';
import { ChatListItem } from '../../components/Chat/ChatListItem';
import { StoriesBar } from '../../components/Chat/StoriesBar';
import { BasicDataSource } from '../../datasources/BasicDataSource';
import { promptAction } from '@kit.ArkUI';

@ComponentV2
export struct ChatListPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local searchText: string = '';
  @Local isLoading: boolean = true;
  @Local isRefreshing: boolean = false;
  @Local activeFolderIndex: number = 0;

  private chatDataSource: BasicDataSource<Chat> = new BasicDataSource<Chat>();
  private searchDebounceTimer: number = 0;
  @Local isSearching: boolean = false;

  // Folder tabs: All, Personal, Groups, Channels, Bots (like Android Telegram)
  private readonly folderLabels: Resource[] = [
    $r('app.string.folder_all'),
    $r('app.string.folder_personal'),
    $r('app.string.folder_groups'),
    $r('app.string.folder_channels'),
    $r('app.string.folder_bots')
  ];

  private dialogsHandler = (): void => {
    const chats = MessagesController.getInstance().getSortedDialogs();
    this.applyFolderFilter(chats);
    this.isLoading = false;
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.DIALOGS_UPDATED, this.dialogsHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.CHAT_ACTION_UPDATED, this.dialogsHandler);

    MessagesController.getInstance().loadDialogs(30);
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.DIALOGS_UPDATED, this.dialogsHandler);
    NotificationCenter.getInstance()
      .removeObserver(EventId.CHAT_ACTION_UPDATED, this.dialogsHandler);

    // Clean up debounce timer to prevent late state updates
    if (this.searchDebounceTimer > 0) {
      clearTimeout(this.searchDebounceTimer);
      this.searchDebounceTimer = 0;
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // Top bar — like Telegram iOS: "Edit" left, "Chats" center, "Compose" right
        Row() {
          Text($r('app.string.edit'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))

          Blank()

          Text($r('app.string.chats_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Blank()

          Row({ space: 16 }) {
            Image($r('app.media.ic_search'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.telegram_blue'))
              .accessibilityText($r('app.string.accessibility_search'))
              .onClick(() => {
                this.navPathStack.pushPath(new NavPathInfo('Search', new Object()));
              })

            Image($r('app.media.ic_edit'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.telegram_blue'))
              .accessibilityText($r('app.string.accessibility_compose'))
              .onClick(() => {
                this.navPathStack.pushPath(new NavPathInfo('NewChat', new Object()));
              })
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 12, right: 12 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 24, bottomRight: 24 })
        .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // Search bar — like both platforms
        Search({ placeholder: $r('app.string.search_placeholder'), value: this.searchText })
          .width('100%')
          .height(36)
          .margin({ left: 16, right: 16, bottom: 0 })
          .onChange((value: string) => {
            this.searchText = value;
            this.applyFilter();
          })

        // Folder tabs — like Android Telegram ViewPager tabs
        Scroll() {
          Row({ space: 0 }) {
            ForEach(this.folderLabels, (label: Resource, index: number) => {
              Column() {
                Text(label)
                  .fontSize(14)
                  .fontWeight(this.activeFolderIndex === index ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(this.activeFolderIndex === index
                    ? $r('app.color.telegram_blue')
                    : $r('app.color.text_secondary'))
                  .padding({ left: 16, right: 16, top: 10, bottom: 10 })

                // Active indicator
                Divider()
                  .strokeWidth(2)
                  .color(this.activeFolderIndex === index
                    ? $r('app.color.telegram_blue')
                    : Color.Transparent)
                  .width('80%')
              }
              .onClick(() => {
                animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
                  this.activeFolderIndex = index;
                });
                const allChats = MessagesController.getInstance().getSortedDialogs();
                this.applyFolderFilter(allChats);
              })
            }, (_label: Resource, index: number) => index.toString())
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        Divider().strokeWidth(0.5).color($r('app.color.separator'))

        // Stories bar — horizontal scrollable circles (like iOS/Android Telegram)
        StoriesBar({
          onStoryClick: (chatId: number) => {
            this.navPathStack.pushPath(new NavPathInfo('StoryViewer', chatId));
          }
        })

        // Chat list
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color($r('app.color.telegram_blue'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List() {
              LazyForEach(this.chatDataSource, (chat: Chat) => {
                ListItem() {
                  ChatListItem({
                    chat: chat,
                    onChatClick: (chatId: number) => {
                      this.navPathStack.pushPath(new NavPathInfo('ChatDetail', chatId));
                    }
                  })
                }
                .swipeAction({
                  start: this.swipeStartBuilder(chat),
                  end: this.swipeEndBuilder(chat)
                })
              }, (chat: Chat) => chat.id.toString())
            }
            .width('100%')
            .layoutWeight(1)
            .cachedCount(5)
            .edgeEffect(EdgeEffect.Spring)
            .divider({
              strokeWidth: 0.5,
              color: $r('app.color.separator'),
              startMargin: 82,
              endMargin: 0
            })
          }
          .onRefreshing(async () => {
            try {
              await MessagesController.getInstance().loadDialogs(30);
            } finally {
              this.isRefreshing = false;
            }
          })
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // FAB — like Android Telegram (pencil/compose icon) → opens NewChat
      Button() {
        Image($r('app.media.ic_edit'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
          .accessibilityText($r('app.string.accessibility_compose'))
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor($r('app.color.telegram_blue'))
      .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
      .margin({ right: 16, bottom: 72 })
      .hoverEffect(HoverEffect.Scale)
      .onClick(() => {
        HapticService.getInstance().light();
        this.navPathStack.pushPath(new NavPathInfo('NewChat', new Object()));
      })
      .opacity(1.0)
      .stateStyles({
        pressed: {
          .opacity(0.7)
        },
        normal: {
          .opacity(1.0)
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  // Leading swipe: mute + archive (like iOS Telegram)
  @Builder
  swipeStartBuilder(chat: Chat) {
    Row() {
      Button() {
        Column() {
          Image(chat.isMuted ? $r('app.media.ic_unmute') : $r('app.media.ic_mute'))
            .width(24).height(24).fillColor(Color.White)
          Text(chat.isMuted ? $r('app.string.unmute') : $r('app.string.mute'))
            .fontSize(12).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor(chat.isMuted ? $r('app.color.swipe_unmute') : $r('app.color.swipe_mute'))
      .onClick(() => {
        void this.toggleMuteChat(chat);
      })

      // Archive button (like iOS/Android Telegram)
      Button() {
        Column() {
          Image($r('app.media.ic_saved'))
            .width(24).height(24).fillColor(Color.White)
          Text($r('app.string.archive'))
            .fontSize(12).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor($r('app.color.telegram_blue'))
      .onClick(() => {
        void this.archiveChat(chat);
      })
    }
  }

  // Trailing swipe: read, pin, delete (like iOS Telegram)
  @Builder
  swipeEndBuilder(chat: Chat) {
    Row() {
      Button() {
        Column() {
          Image($r('app.media.ic_check_double'))
            .width(24).height(24).fillColor(Color.White)
          Text((chat.unreadCount > 0 || chat.isMarkedAsUnread) ? $r('app.string.read') : $r('app.string.unread'))
            .fontSize(12).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor($r('app.color.swipe_read'))
      .onClick(() => {
        void this.toggleReadState(chat);
      })

      Button() {
        Column() {
          Image($r('app.media.ic_pin'))
            .width(24).height(24).fillColor(Color.White)
          Text(chat.isPinned ? $r('app.string.unpin') : $r('app.string.pin'))
            .fontSize(12).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor($r('app.color.swipe_pin'))
      .onClick(() => {
        void this.togglePin(chat);
      })

      Button() {
        Column() {
          Image($r('app.media.ic_delete'))
            .width(24).height(24).fillColor(Color.White)
          Text($r('app.string.delete'))
            .fontSize(12).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor($r('app.color.swipe_delete'))
      .onClick(() => {
        void this.deleteChat(chat);
      })
    }
  }

  private applyFilter(): void {
    const allChats = MessagesController.getInstance().getSortedDialogs();
    if (this.searchText.length === 0) {
      this.isSearching = false;
      this.applyFolderFilter(allChats);
    } else {
      // Immediate local filter for responsiveness
      const query = this.searchText.toLowerCase();
      const localFiltered = allChats.filter((chat) =>
        chat.title.toLowerCase().includes(query)
      );
      this.chatDataSource.setData(localFiltered);

      // Debounced server-backed search to merge TDLib results
      if (this.searchDebounceTimer > 0) {
        clearTimeout(this.searchDebounceTimer);
      }
      this.searchDebounceTimer = setTimeout(() => {
        void this.performServerSearch(this.searchText, localFiltered);
      }, 300) as number;
    }
  }

  private async performServerSearch(query: string, localResults: Chat[]): Promise<void> {
    if (query.length === 0 || query !== this.searchText) return;
    this.isSearching = true;
    try {
      const serverResult = await ChatService.getInstance().searchChats(query, 20);
      if (query !== this.searchText) return; // Stale query
      const serverChatIds: number[] = (serverResult.chat_ids as number[]) || [];
      const localIds = new Set(localResults.map((c: Chat): number => c.id));
      const merged = [...localResults];

      for (const chatId of serverChatIds) {
        if (!localIds.has(chatId)) {
          const chat = MessagesController.getInstance().getChat(chatId);
          if (chat) {
            merged.push(chat);
          }
        }
      }
      this.chatDataSource.setData(merged);
    } catch (_e) {
      // Keep local results on error
    } finally {
      this.isSearching = false;
    }
  }

  private applyFolderFilter(allChats: Chat[]): void {
    let filtered: Chat[];
    switch (this.activeFolderIndex) {
      case 1: // Personal — private chats only
        filtered = allChats.filter(c => !c.isGroup && !c.isChannel && !c.isBot);
        break;
      case 2: // Groups
        filtered = allChats.filter(c => c.isGroup && !c.isChannel);
        break;
      case 3: // Channels
        filtered = allChats.filter(c => c.isChannel);
        break;
      case 4: // Bots — private chats where peer type is bot
        filtered = allChats.filter(c => c.isBot);
        break;
      default: // All
        filtered = [...allChats];
        break;
    }

    if (this.searchText.length > 0) {
      filtered = filtered.filter(c =>
        c.title.toLowerCase().includes(this.searchText.toLowerCase())
      );
    }

    this.chatDataSource.setData(filtered);
  }

  private async toggleMuteChat(chat: Chat): Promise<void> {
    const shouldMute: boolean = !chat.isMuted;
    try {
      if (shouldMute) {
        // Mute "forever" (10 years), like Telegram default mute behavior
        await ChatService.getInstance().muteChat(chat.id, 315360000);
      } else {
        await ChatService.getInstance().unmuteChat(chat.id);
      }
      chat.isMuted = shouldMute;
      this.applyFilter();
    } catch (_e) {
      this.showActionError();
    }
  }

  private async toggleReadState(chat: Chat): Promise<void> {
    try {
      if (chat.unreadCount > 0 || chat.isMarkedAsUnread) {
        await ChatService.getInstance().markChatAsRead(chat.id);
        if (chat.isMarkedAsUnread) {
          await ChatService.getInstance().setChatMarkedAsUnread(chat.id, false);
        }
        chat.unreadCount = 0;
        chat.isMarkedAsUnread = false;
      } else {
        await ChatService.getInstance().setChatMarkedAsUnread(chat.id, true);
        chat.isMarkedAsUnread = true;
      }
      this.applyFilter();
    } catch (_e) {
      this.showActionError();
    }
  }

  private async togglePin(chat: Chat): Promise<void> {
    const shouldPin: boolean = !chat.isPinned;
    try {
      if (shouldPin) {
        await ChatService.getInstance().pinChat(chat.id);
      } else {
        await ChatService.getInstance().unpinChat(chat.id);
      }
      chat.isPinned = shouldPin;
      this.applyFilter();
    } catch (_e) {
      this.showActionError();
    }
  }

  private async deleteChat(chat: Chat): Promise<void> {
    try {
      await ChatService.getInstance().deleteChatHistory(chat.id);
      const currentChats = this.chatDataSource.getAllData();
      const filteredAll = currentChats.filter(c => c.id !== chat.id);
      this.chatDataSource.setData(filteredAll);
    } catch (_e) {
      this.showActionError();
    }
  }

  private async archiveChat(chat: Chat): Promise<void> {
    try {
      await ChatService.getInstance().addChatToList(chat.id, 'chatListArchive');
      const currentChats = this.chatDataSource.getAllData();
      const filtered = currentChats.filter(c => c.id !== chat.id);
      this.chatDataSource.setData(filtered);
    } catch (_e) {
      this.showActionError();
    }
  }

  private showActionError(): void {
    promptAction.showToast({
      message: getContext(this).resourceManager.getStringByNameSync('action_failed'),
      duration: 1200,
      bottom: 96
    });
  }
}
