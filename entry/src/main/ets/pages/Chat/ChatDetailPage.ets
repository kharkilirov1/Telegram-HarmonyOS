import { TDLibClient } from '../../services/TDLibClient';
import { Message, MessageContentType } from '../../models/Message';
import { MessageBubble } from '../../components/Message/MessageBubble';

@Component
export struct ChatDetailPage {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @Prop chatId: number = 0;
  @State chatTitle: string = '';
  @State messages: Message[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = true;

  private listScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadChatInfo();
    this.loadMessages();
    this.subscribeToNewMessages();
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          // Back button
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => {
              this.navPathStack.pop();
            })

          // Chat info
          Column() {
            Text(this.chatTitle)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)

            Text('last seen recently')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Blank()
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.background_primary'))

        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.separator'))

        // Messages list
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
          List({ scroller: this.listScroller }) {
            ForEach(this.messages, (message: Message) => {
              ListItem() {
                MessageBubble({ message: message })
              }
            }, (message: Message) => message.id.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('app.color.background_secondary'))
          .padding({ top: 8, bottom: 8 })
        }

        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.separator'))

        // Input bar
        Row() {
          // Attach button
          Image($r('sys.media.ohos_ic_public_add'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.text_secondary'))
            .margin({ right: 8 })

          // Text input
          TextInput({ placeholder: 'Message', text: this.inputText })
            .fontSize(16)
            .layoutWeight(1)
            .height(40)
            .backgroundColor($r('app.color.background_secondary'))
            .borderRadius(20)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.inputText = value;
            })
            .onSubmit(() => {
              this.sendMessage();
            })

          // Send / Mic button
          if (this.inputText.length > 0) {
            Image($r('sys.media.ohos_ic_public_send'))
              .width(28)
              .height(28)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ left: 8 })
              .onClick(() => {
                this.sendMessage();
              })
          } else {
            Image($r('sys.media.ohos_ic_public_voice'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_secondary'))
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .padding({ left: 8, right: 12, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.background_primary'))
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  private async loadChatInfo(): Promise<void> {
    try {
      const result = await TDLibClient.getInstance().getChat(this.chatId) as Record<string, string>;
      this.chatTitle = result['title'] || '';
    } catch (e) {
      // Handle error
    }
  }

  private async loadMessages(): Promise<void> {
    this.isLoading = true;
    try {
      const result = await TDLibClient.getInstance().getChatHistory(this.chatId) as Record<string, object>;
      const rawMessages = result['messages'] as Record<string, object>[];
      if (rawMessages) {
        this.messages = rawMessages.map((raw) => this.parseMessage(raw)).reverse();
      }
    } catch (e) {
      // Handle error
    } finally {
      this.isLoading = false;
    }
  }

  private subscribeToNewMessages(): void {
    TDLibClient.getInstance().on('updateNewMessage', (update: object) => {
      const data = update as Record<string, object>;
      const rawMessage = data['message'] as Record<string, object>;
      if (rawMessage) {
        const msg = this.parseMessage(rawMessage);
        if (msg.chatId === this.chatId) {
          this.messages.push(msg);
          // Scroll to bottom
          this.listScroller.scrollToIndex(this.messages.length - 1);
        }
      }
    });
  }

  private async sendMessage(): Promise<void> {
    const text = this.inputText.trim();
    if (text.length === 0) return;

    this.inputText = '';
    await TDLibClient.getInstance().sendMessage(this.chatId, text);
  }

  private parseMessage(raw: Record<string, object>): Message {
    const content = raw['content'] as Record<string, object>;
    let text = '';
    let contentType = MessageContentType.UNSUPPORTED;
    let photoUrl: string | null = null;

    if (content) {
      const type = content['@type'] as string;
      if (type === 'messageText') {
        contentType = MessageContentType.TEXT;
        const textObj = content['text'] as Record<string, string>;
        text = textObj?.['text'] || '';
      } else if (type === 'messagePhoto') {
        contentType = MessageContentType.PHOTO;
        const caption = content['caption'] as Record<string, string>;
        text = caption?.['text'] || '';
      } else if (type === 'messageVideo') {
        contentType = MessageContentType.VIDEO;
        text = '[Video]';
      } else if (type === 'messageDocument') {
        contentType = MessageContentType.DOCUMENT;
        text = '[Document]';
      } else if (type === 'messageVoiceNote') {
        contentType = MessageContentType.VOICE;
        text = '[Voice message]';
      } else if (type === 'messageSticker') {
        contentType = MessageContentType.STICKER;
        text = '[Sticker]';
      }
    }

    const senderId = raw['sender_id'] as Record<string, number>;

    return new Message(
      raw['id'] as number,
      raw['chat_id'] as number,
      senderId?.['user_id'] || 0,
      '',
      text,
      raw['date'] as number,
      raw['is_outgoing'] as boolean,
      false,
      0,
      contentType,
      photoUrl
    );
  }
}
