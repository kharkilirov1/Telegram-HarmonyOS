import { TDLibClient } from '../../services/TDLibClient';
import { Chat } from '../../models/Chat';
import { ChatListItem } from '../../components/Chat/ChatListItem';

@Component
export struct ChatListPage {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @State chatList: Chat[] = [];
  @State searchText: string = '';
  @State isLoading: boolean = true;

  aboutToAppear(): void {
    this.loadChats();
    this.subscribeToUpdates();
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

        // Compose button
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
              end: this.swipeActionBuilder(chat)
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

  @Builder
  swipeActionBuilder(chat: Chat) {
    Row() {
      // Mute / Pin / Delete actions (like iOS Telegram)
      Button() {
        Image($r('sys.media.ohos_ic_public_remove'))
          .width(20)
          .height(20)
          .fillColor(Color.White)
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

  private async loadChats(): Promise<void> {
    this.isLoading = true;
    try {
      await TDLibClient.getInstance().loadChats(30);
    } catch (e) {
      // Handle error
    } finally {
      this.isLoading = false;
    }
  }

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateNewChat', (update: object) => {
      const chatData = update as Record<string, object>;
      const rawChat = chatData['chat'] as Record<string, object>;
      const chat = new Chat(
        rawChat['id'] as number,
        rawChat['title'] as string
      );
      this.chatList.push(chat);
    });

    client.on('updateChatLastMessage', (update: object) => {
      const data = update as Record<string, object>;
      const chatId = data['chat_id'] as number;
      const idx = this.chatList.findIndex((c) => c.id === chatId);
      if (idx >= 0) {
        const msg = data['last_message'] as Record<string, object>;
        if (msg) {
          const content = msg['content'] as Record<string, object>;
          if (content && content['@type'] === 'messageText') {
            const textObj = content['text'] as Record<string, string>;
            this.chatList[idx].lastMessage = textObj['text'] || '';
          }
          this.chatList[idx].lastMessageDate = msg['date'] as number;
        }
      }
    });
  }
}
