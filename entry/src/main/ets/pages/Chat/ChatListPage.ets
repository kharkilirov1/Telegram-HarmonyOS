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

        Image($r('app.media.ic_edit'))
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
          Image(chat.isMuted ? $r('app.media.ic_unmute') : $r('app.media.ic_mute'))
            .width(22).height(22).fillColor(Color.White)
          Text(chat.isMuted ? $r('app.string.unmute') : $r('app.string.mute'))
            .fontSize(11).fontColor(Color.White)
        }
      }
      .width(72)
      .height('100%')
      .backgroundColor(chat.isMuted ? $r('app.color.swipe_unmute') : $r('app.color.swipe_mute'))
    }
  }

  // Trailing swipe: read, pin, delete
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

  private getFilteredChats(): Chat[] {
    if (this.searchText.length === 0) {
      return this.chatList;
    }
    return this.chatList.filter((chat) =>
      chat.title.toLowerCase().includes(this.searchText.toLowerCase())
    );
  }
}
