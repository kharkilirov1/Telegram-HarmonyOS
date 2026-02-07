import { MessagesController } from '../../controllers/MessagesController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Chat } from '../../models/Chat';
import { ChatListItem } from '../../components/Chat/ChatListItem';

@Component
export struct ChatListPage {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @State chatList: Chat[] = [];
  @State searchText: string = '';
  @State isLoading: boolean = true;

  private dialogsHandler = (): void => {
    this.chatList = [...MessagesController.getInstance().getSortedDialogs()];
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
    Column() {
      // Top bar
      Row() {
        Text($r('app.string.chats_title'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        Image($r('sys.media.ohos_ic_public_edit'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.telegram_blue'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // Search bar
      Search({ placeholder: $r('app.string.search_placeholder'), value: this.searchText })
        .width('100%')
        .height(36)
        .margin({ left: 16, right: 16, bottom: 8 })
        .onChange((value: string) => {
          this.searchText = value;
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
        List() {
          ForEach(this.getFilteredChats(), (chat: Chat) => {
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
        .divider({
          strokeWidth: 0.5,
          color: $r('app.color.separator'),
          startMargin: 82,
          endMargin: 0
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_primary'))
  }

  // Leading swipe: mute/unmute
  @Builder
  swipeStartBuilder(chat: Chat) {
    Row() {
      Button() {
        Column() {
          Image($r('sys.media.ohos_ic_public_mute'))
            .width(22).height(22).fillColor(Color.White)
          Text(chat.isMuted ? 'Unmute' : 'Mute')
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor(chat.isMuted ? '#4DCC5E' : '#8E8E93')
    }
  }

  // Trailing swipe: read, pin, delete
  @Builder
  swipeEndBuilder(chat: Chat) {
    Row() {
      Button() {
        Column() {
          Image($r('sys.media.ohos_ic_public_ok'))
            .width(22).height(22).fillColor(Color.White)
          Text(chat.unreadCount > 0 ? 'Read' : 'Unread')
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor('#3F51B5')

      Button() {
        Column() {
          Image($r('sys.media.ohos_ic_public_push_pin'))
            .width(22).height(22).fillColor(Color.White)
          Text(chat.isPinned ? 'Unpin' : 'Pin')
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor('#8E8E93')

      Button() {
        Column() {
          Image($r('sys.media.ohos_ic_public_remove'))
            .width(22).height(22).fillColor(Color.White)
          Text('Delete')
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor(Color.Red)
    }
  }

  private getFilteredChats(): Chat[] {
    if (this.searchText.length === 0) {
      return this.chatList;
    }
    return this.chatList.filter((chat) =>
      chat.title.toLowerCase().includes(this.searchText.toLowerCase())
    );
  }
}
