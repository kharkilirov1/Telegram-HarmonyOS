// Forward message — pick a chat to forward to
// Reference: Telegram Android ShareActivity, iOS ForwardController

import { MessagesController } from '../../controllers/MessagesController';
import { ChatService } from '../../services/ChatService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Chat } from '../../models/Chat';
import { BasicDataSource } from '../../datasources/BasicDataSource';
import { promptAction } from '@kit.ArkUI';

@Builder
export function ForwardPickerBuilder(name: string, param: Object) {
  ForwardPickerPage({ messageId: (param as Record<string, number>)['messageId'] || 0,
    sourceChatId: (param as Record<string, number>)['chatId'] || 0 })
}

@ComponentV2
export struct ForwardPickerPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param messageId: number = 0;
  @Param sourceChatId: number = 0;
  @Local searchText: string = '';
  @Local isForwarding: boolean = false;

  private chatDataSource: BasicDataSource<Chat> = new BasicDataSource<Chat>();

  aboutToAppear(): void {
    if (this.messageId <= 0 || this.sourceChatId <= 0) {
      promptAction.showToast({
        message: getContext(this).resourceManager.getStringByNameSync('forward_unavailable'),
        duration: 2000,
        bottom: 96
      });
      this.navPathStack.pop();
      return;
    }
    this.refreshChats();
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .accessibilityText($r('app.string.accessibility_back'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.forward_to'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 16, bottomRight: 16 })
        .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // Search
        Search({ placeholder: $r('app.string.search_placeholder'), value: this.searchText })
          .width('100%')
          .height(36)
          .margin({ left: 16, right: 16, top: 4, bottom: 4 })
          .onChange((value: string) => {
            this.searchText = value;
            this.refreshChats();
          })

        Divider().strokeWidth(0.5).color($r('app.color.separator'))

        // Chat list
        List() {
          LazyForEach(this.chatDataSource, (chat: Chat) => {
            ListItem() {
              this.chatRow(chat)
            }
          }, (chat: Chat) => chat.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .cachedCount(5)
        .edgeEffect(EdgeEffect.Spring)
        .divider({
          strokeWidth: 0.5,
          color: $r('app.color.separator'),
          startMargin: 72,
          endMargin: 0
        })

        if (this.isForwarding) {
          Column() {
            LoadingProgress()
              .width(32).height(32).color($r('app.color.telegram_blue'))
            Text($r('app.string.sending'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(16)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  chatRow(chat: Chat) {
    Row() {
      // Avatar
      Text(chat.title.length > 0 ? chat.title.charAt(0) : '?')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(48).height(48)
        .borderRadius(24)
        .backgroundColor($r('app.color.telegram_blue'))
        .textAlign(TextAlign.Center)
        .margin({ left: 16, right: 12 })

      Column() {
        Text(chat.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)

        Text(chat.lastMessage)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: 16 })
    }
    .width('100%')
    .height(62)
    .onClick(() => {
      this.forwardToChat(chat.id);
    })
  }

  private async forwardToChat(targetChatId: number): Promise<void> {
    if (this.isForwarding) return;
    this.isForwarding = true;

    try {
      await ChatService.getInstance().forwardMessages(targetChatId, this.sourceChatId, [this.messageId]);

      // Navigate to forwarded chat
      this.navPathStack.pop();
      this.navPathStack.pushPath(new NavPathInfo('ChatDetail', targetChatId));
    } catch (e) {
      hilog.warn(0x0001, 'ForwardPickerPage', 'Failed to forward message to chat %{public}d: %{public}s',
        targetChatId, String(e));
      this.isForwarding = false;
      promptAction.showToast({
        message: getContext(this).resourceManager.getStringByNameSync('action_failed'),
        duration: 1200,
        bottom: 96
      });
    }
  }

  private refreshChats(): void {
    let chats = MessagesController.getInstance().getSortedDialogs();
    if (this.searchText.length > 0) {
      const query = this.searchText.toLowerCase();
      chats = chats.filter(c => c.title.toLowerCase().includes(query));
    }
    this.chatDataSource.setData(chats);
  }
}
