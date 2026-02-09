import { MessagesController } from '../../controllers/MessagesController';
import { TDLibClient } from '../../services/TDLibClient';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Chat } from '../../models/Chat';
import { ChatListItem } from '../../components/Chat/ChatListItem';
import { StoriesBar } from '../../components/Chat/StoriesBar';
import { BasicDataSource } from '../../datasources/BasicDataSource';

@ComponentV2
export struct ChatListPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local searchText: string = '';
  @Local isLoading: boolean = true;
  @Local isRefreshing: boolean = false;
  @Local activeFolderIndex: number = 0;

  private chatDataSource: BasicDataSource<Chat> = new BasicDataSource<Chat>();

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
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Blank()

          Row({ space: 16 }) {
            Image($r('app.media.ic_search'))
              .width(22)
              .height(22)
              .fillColor($r('app.color.telegram_blue'))
              .accessibilityText($r('app.string.accessibility_search'))
              .onClick(() => {
                this.navPathStack.pushPath({ name: 'Search' });
              })

            Image($r('app.media.ic_edit'))
              .width(22)
              .height(22)
              .fillColor($r('app.color.telegram_blue'))
              .accessibilityText($r('app.string.accessibility_compose'))
              .onClick(() => {
                this.navPathStack.pushPath({ name: 'NewChat' });
              })
          }
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

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
                this.activeFolderIndex = index;
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
            this.navPathStack.pushPath({ name: 'StoryViewer', param: chatId });
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
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List() {
              LazyForEach(this.chatDataSource, (chat: Chat) => {
                ListItem() {
                  ChatListItem({
                    chat: chat,
                    onChatClick: (chatId: number) => {
                      this.navPathStack.pushPath({ name: 'ChatDetail', param: chatId });
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
          .onRefreshing(() => {
            MessagesController.getInstance().loadDialogs(30);
            setTimeout(() => {
              this.isRefreshing = false;
            }, 1500);
          })
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))

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
      .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 4 })
      .margin({ right: 16, bottom: 16 })
      .onClick(() => {
        this.navPathStack.pushPath({ name: 'NewChat' });
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
            .width(22).height(22).fillColor(Color.White)
          Text(chat.isMuted ? $r('app.string.unmute') : $r('app.string.mute'))
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor(chat.isMuted ? $r('app.color.swipe_unmute') : $r('app.color.swipe_mute'))

      // Archive button (like iOS/Android Telegram)
      Button() {
        Column() {
          Image($r('app.media.ic_saved'))
            .width(22).height(22).fillColor(Color.White)
          Text($r('app.string.archive'))
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor($r('app.color.telegram_blue'))
      .onClick(() => {
        // Move chat to archive — TDLib: addChatToList(chatListArchive)
        const chatListArchive: Record<string, Object> = {};
        chatListArchive['@type'] = 'chatListArchive';
        const archiveParams: Record<string, Object> = {};
        archiveParams['chat_id'] = chat.id;
        archiveParams['chat_list'] = chatListArchive;
        TDLibClient.getInstance().send('addChatToList', archiveParams);
        // Remove from visible list
        const allChats = MessagesController.getInstance().getSortedDialogs();
        const filtered = allChats.filter(c => c.id !== chat.id);
        this.chatDataSource.setData(filtered);
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
            .width(22).height(22).fillColor(Color.White)
          Text(chat.unreadCount > 0 ? $r('app.string.read') : $r('app.string.unread'))
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor($r('app.color.swipe_read'))

      Button() {
        Column() {
          Image($r('app.media.ic_pin'))
            .width(22).height(22).fillColor(Color.White)
          Text(chat.isPinned ? $r('app.string.unpin') : $r('app.string.pin'))
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor($r('app.color.swipe_pin'))

      Button() {
        Column() {
          Image($r('app.media.ic_delete'))
            .width(22).height(22).fillColor(Color.White)
          Text($r('app.string.delete'))
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor($r('app.color.swipe_delete'))
    }
  }

  private applyFilter(): void {
    const allChats = MessagesController.getInstance().getSortedDialogs();
    if (this.searchText.length === 0) {
      this.applyFolderFilter(allChats);
    } else {
      const filtered = allChats.filter((chat) =>
        chat.title.toLowerCase().includes(this.searchText.toLowerCase())
      );
      this.chatDataSource.setData(filtered);
    }
  }

  private applyFolderFilter(allChats: Chat[]): void {
    let filtered: Chat[];
    switch (this.activeFolderIndex) {
      case 1: // Personal — private chats only
        filtered = allChats.filter(c => !c.isGroup && !c.isChannel);
        break;
      case 2: // Groups
        filtered = allChats.filter(c => c.isGroup && !c.isChannel);
        break;
      case 3: // Channels
        filtered = allChats.filter(c => c.isChannel);
        break;
      case 4: // Bots — filter by title convention (placeholder)
        filtered = allChats.filter(c => !c.isGroup && !c.isChannel);
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
}
