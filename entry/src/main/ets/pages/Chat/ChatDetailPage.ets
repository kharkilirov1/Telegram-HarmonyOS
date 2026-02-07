import { MessagesController } from '../../controllers/MessagesController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Message, GroupedMessage, MessageDateGroup } from '../../models/Message';
import { Chat } from '../../models/Chat';
import { MessageBubble } from '../../components/Message/MessageBubble';
import { DateSeparator, formatDateSeparator } from '../../components/Common/DateSeparator';
import { TypingIndicator } from '../../components/Common/TypingIndicator';
import { ChatInputBar } from '../../components/Chat/ChatInputBar';
import { formatLastSeen } from '../../components/Common/AvatarWithStatus';

@Component
export struct ChatDetailPage {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @Prop chatId: number = 0;
  @State chatTitle: string = '';
  @State lastSeenText: string = '';
  @State isTyping: boolean = false;
  @State isGroupChat: boolean = false;
  @State messages: Message[] = [];
  @State messageGroups: MessageDateGroup[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = true;
  @State isLoadingOlder: boolean = false;
  @State endReachedOlder: boolean = false;
  @State showScrollToBottom: boolean = false;
  @State newMessageCount: number = 0;
  @State replyMessage: Message | null = null;

  private listScroller: Scroller = new Scroller();

  // Event handlers
  private newMessageHandler = (args?: Record<string, Object>): void => {
    if (!args) return;
    const msgChatId = args['chatId'] as number;
    if (msgChatId !== this.chatId) return;

    const msg = args['message'] as Message;
    this.messages.push(msg);
    this.rebuildGroups();

    if (this.showScrollToBottom) {
      this.newMessageCount++;
    } else {
      this.scrollToBottom();
    }
  };

  private typingHandler = (args?: Record<string, Object>): void => {
    if (!args) return;
    const chatId = args['chatId'] as number;
    if (chatId !== this.chatId) return;

    const chat = MessagesController.getInstance().getChat(this.chatId);
    this.isTyping = chat?.isTyping || false;
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.NEW_MESSAGE, this.newMessageHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.CHAT_ACTION_UPDATED, this.typingHandler);

    this.loadChatInfo();
    this.loadInitialMessages();
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.NEW_MESSAGE, this.newMessageHandler);
    NotificationCenter.getInstance()
      .removeObserver(EventId.CHAT_ACTION_UPDATED, this.typingHandler);
  }

  build() {
    NavDestination() {
      Column() {
        // --- Top bar ---
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Column() {
            Text(this.chatTitle)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)

            if (this.isTyping) {
              TypingIndicator({ typingText: $r('app.string.typing') })
            } else {
              Text(this.lastSeenText)
                .fontSize(13)
                .fontColor(this.lastSeenText === 'online'
                  ? $r('app.color.online_indicator')
                  : $r('app.color.text_secondary'))
            }
          }
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // Call and more buttons
          Image($r('app.media.ic_phone_call'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.telegram_blue'))
            .margin({ right: 16 })

          Image($r('app.media.ic_more'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.telegram_blue'))
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.background_primary'))

        Divider().strokeWidth(0.5).color($r('app.color.separator'))

        // --- Messages ---
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40).height(40).color($r('app.color.telegram_blue'))
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          Stack() {
            List({ scroller: this.listScroller }) {
              ForEach(this.messageGroups, (group: MessageDateGroup) => {
                // Date separator
                ListItem() {
                  DateSeparator({ dateText: group.dateLabel })
                }

                ForEach(group.messages, (item: GroupedMessage) => {
                  ListItem() {
                    MessageBubble({
                      message: item.message,
                      isFirstInGroup: item.isFirstInGroup,
                      isLastInGroup: item.isLastInGroup,
                      showSenderName: this.isGroupChat
                    })
                  }
                }, (item: GroupedMessage) => item.message.id.toString())
              }, (group: MessageDateGroup) => group.dateLabel)
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor($r('app.color.background_secondary'))
            .padding({ top: 8, bottom: 8 })
            .onScrollIndex((firstIndex: number, lastIndex: number) => {
              // Load older messages when near top
              if (firstIndex < 5 && !this.isLoadingOlder && !this.endReachedOlder) {
                this.loadOlderMessages();
              }
              // Show/hide scroll-to-bottom
              const totalItems = this.getTotalListItems();
              this.showScrollToBottom = (totalItems - lastIndex) > 15;
            })

            // Scroll-to-bottom FAB
            if (this.showScrollToBottom) {
              Column() {
                if (this.newMessageCount > 0) {
                  Text(this.newMessageCount.toString())
                    .fontSize(12)
                    .fontColor(Color.White)
                    .backgroundColor($r('app.color.telegram_blue'))
                    .borderRadius(10)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .margin({ bottom: 4 })
                }
                Image($r('app.media.ic_arrow_down'))
                  .width(36).height(36)
                  .fillColor($r('app.color.text_secondary'))
                  .backgroundColor(Color.White)
                  .borderRadius(18)
                  .shadow({ radius: 4, color: $r('app.color.shadow_color') })
              }
              .position({ right: 16, bottom: 16 })
              .onClick(() => {
                this.newMessageCount = 0;
                this.scrollToBottom();
              })
            }
          }
          .width('100%')
          .layoutWeight(1)
        }

        // --- Input bar ---
        ChatInputBar({
          inputText: $inputText,
          replyMessage: this.replyMessage,
          onSendMessage: (text: string) => this.sendMessage(text),
          onCancelReply: () => { this.replyMessage = null; }
        })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  // --- Data loading ---

  private loadChatInfo(): void {
    const chat = MessagesController.getInstance().getChat(this.chatId);
    if (chat) {
      this.chatTitle = chat.title;
      this.isGroupChat = chat.isGroup;
      this.lastSeenText = chat.isGroup
        ? `${chat.unreadCount} members`
        : formatLastSeen(chat.isUserOnline, 0);
    }
  }

  private async loadInitialMessages(): Promise<void> {
    this.isLoading = true;
    try {
      const msgs = await MessagesController.getInstance()
        .loadMessages(this.chatId, 0, 50);
      this.messages = msgs.reverse();
      if (msgs.length < 50) {
        this.endReachedOlder = true;
      }
      this.rebuildGroups();
      this.scrollToBottom();
    } catch (e) {
      // Handle error
    } finally {
      this.isLoading = false;
    }
  }

  private async loadOlderMessages(): Promise<void> {
    if (this.isLoadingOlder || this.endReachedOlder || this.messages.length === 0) return;
    this.isLoadingOlder = true;

    try {
      const oldestId = this.messages[0].id;
      const older = await MessagesController.getInstance()
        .loadMessages(this.chatId, oldestId, 50);

      if (older.length < 50) {
        this.endReachedOlder = true;
      }
      if (older.length > 0) {
        this.messages = [...older.reverse(), ...this.messages];
        this.rebuildGroups();
      }
    } catch (e) {
      // Handle error
    } finally {
      this.isLoadingOlder = false;
    }
  }

  private async sendMessage(text: string): Promise<void> {
    const replyId = this.replyMessage?.id || 0;
    this.replyMessage = null;
    await MessagesController.getInstance()
      .sendTextMessage(this.chatId, text, replyId);
  }

  // --- Message grouping (sender groups + date groups) ---

  private rebuildGroups(): void {
    const TIME_THRESHOLD = 3 * 60; // 3 minutes
    const dateMap = new Map<string, GroupedMessage[]>();

    // First pass: compute sender grouping flags
    const grouped: GroupedMessage[] = this.messages.map((msg, i) => {
      const prev = i > 0 ? this.messages[i - 1] : null;
      const next = i < this.messages.length - 1 ? this.messages[i + 1] : null;

      const sameSenderAsPrev = prev !== null
        && prev.senderId === msg.senderId
        && prev.isOutgoing === msg.isOutgoing
        && (msg.date - prev.date) < TIME_THRESHOLD
        && this.sameDay(prev.date, msg.date);

      const sameSenderAsNext = next !== null
        && next.senderId === msg.senderId
        && next.isOutgoing === msg.isOutgoing
        && (next.date - msg.date) < TIME_THRESHOLD
        && this.sameDay(msg.date, next.date);

      return new GroupedMessage(msg, !sameSenderAsPrev, !sameSenderAsNext);
    });

    // Second pass: group by date
    for (const item of grouped) {
      const label = formatDateSeparator(item.message.date);
      if (!dateMap.has(label)) {
        dateMap.set(label, []);
      }
      dateMap.get(label)!.push(item);
    }

    // Build final array preserving order
    const result: MessageDateGroup[] = [];
    const seen = new Set<string>();
    for (const item of grouped) {
      const label = formatDateSeparator(item.message.date);
      if (!seen.has(label)) {
        seen.add(label);
        result.push(new MessageDateGroup(label, dateMap.get(label)!));
      }
    }
    this.messageGroups = result;
  }

  private sameDay(ts1: number, ts2: number): boolean {
    const d1 = new Date(ts1 * 1000);
    const d2 = new Date(ts2 * 1000);
    return d1.toDateString() === d2.toDateString();
  }

  private getTotalListItems(): number {
    let count = 0;
    for (const g of this.messageGroups) {
      count += 1 + g.messages.length; // 1 for date separator
    }
    return count;
  }

  private scrollToBottom(): void {
    const total = this.getTotalListItems();
    if (total > 0) {
      this.listScroller.scrollToIndex(total - 1);
    }
  }
}
