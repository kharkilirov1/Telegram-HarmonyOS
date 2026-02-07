import { MessagesController } from '../../controllers/MessagesController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Message, GroupedMessage, MessageDateGroup } from '../../models/Message';
import { Chat } from '../../models/Chat';
import { MessageBubble } from '../../components/Message/MessageBubble';
import { DateSeparator, formatDateSeparator } from '../../components/Common/DateSeparator';
import { TypingIndicator } from '../../components/Common/TypingIndicator';
import { ChatInputBar } from '../../components/Chat/ChatInputBar';
import { formatLastSeen } from '../../components/Common/AvatarWithStatus';
import { BasicDataSource } from '../../datasources/BasicDataSource';
import { pasteboard } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Builder
export function ChatDetailBuilder(name: string, param: Object) {
  ChatDetailPage({ chatId: param as number })
}

// Flat list item: either a date separator or a message
export class ChatDetailListItem {
  isDateSeparator: boolean;
  dateLabel: string;
  groupedMessage: GroupedMessage | null;

  constructor(isDateSeparator: boolean, dateLabel: string = '', groupedMessage: GroupedMessage | null = null) {
    this.isDateSeparator = isDateSeparator;
    this.dateLabel = dateLabel;
    this.groupedMessage = groupedMessage;
  }
}

@ComponentV2
export struct ChatDetailPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param chatId: number = 0;
  @Local chatTitle: string = '';
  @Local lastSeenText: string = '';
  @Local isTyping: boolean = false;
  @Local isGroupChat: boolean = false;
  @Local messages: Message[] = [];
  @Local isLoading: boolean = true;
  @Local isLoadingOlder: boolean = false;
  @Local endReachedOlder: boolean = false;
  @Local showScrollToBottom: boolean = false;
  @Local newMessageCount: number = 0;
  @Local replyMessage: Message | null = null;
  @Local chatPhoto: string | null = null;
  @Local chatInitial: string = '';

  private listScroller: Scroller = new Scroller();
  private messageDataSource: BasicDataSource<ChatDetailListItem> = new BasicDataSource<ChatDetailListItem>();

  // Event handlers
  private newMessageHandler = (args?: Record<string, Object>): void => {
    if (!args) return;
    const msgChatId = args['chatId'] as number;
    if (msgChatId !== this.chatId) return;

    const msg = args['message'] as Message;
    this.messages.push(msg);
    this.rebuildFlatList();

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

          // Chat avatar (like both iOS and Android Telegram)
          if (this.chatPhoto) {
            Image(this.chatPhoto)
              .alt($r('app.media.app_icon'))
              .autoResize(true)
              .onError(() => {})
              .width(36)
              .height(36)
              .borderRadius(18)
              .margin({ left: 8 })
          } else {
            Text(this.chatInitial)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor($r('app.color.telegram_blue'))
              .textAlign(TextAlign.Center)
              .margin({ left: 8 })
          }

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
          .margin({ left: 10 })
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
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

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
              LazyForEach(this.messageDataSource, (item: ChatDetailListItem) => {
                ListItem() {
                  if (item.isDateSeparator) {
                    DateSeparator({ dateText: item.dateLabel })
                  } else if (item.groupedMessage !== null) {
                    MessageBubble({
                      message: item.groupedMessage.message,
                      isFirstInGroup: item.groupedMessage.isFirstInGroup,
                      isLastInGroup: item.groupedMessage.isLastInGroup,
                      showSenderName: this.isGroupChat,
                      onReply: (msg: Message) => { this.replyMessage = msg; },
                      onForward: (msg: Message) => { this.forwardMessage(msg); },
                      onCopy: (msg: Message) => { this.copyMessageText(msg); },
                      onDelete: (msg: Message) => { this.deleteMessage(msg); },
                      onMediaTap: (url: string) => {
                        this.navPathStack.pushPath({
                          name: 'MediaViewer',
                          param: { url: url } as Record<string, string>
                        });
                      }
                    })
                  }
                }
              }, (item: ChatDetailListItem) => {
                if (item.isDateSeparator) {
                  return `date_${item.dateLabel}`;
                }
                return `msg_${item.groupedMessage?.message.id.toString() ?? '0'}`;
              })
            }
            .width('100%')
            .layoutWeight(1)
            .cachedCount(5)
            .edgeEffect(EdgeEffect.Spring)
            .backgroundColor($r('app.color.background_secondary'))
            .padding({ top: 8, bottom: 8 })
            .onScrollIndex((firstIndex: number, lastIndex: number) => {
              // Load older messages when near top
              if (firstIndex < 5 && !this.isLoadingOlder && !this.endReachedOlder) {
                this.loadOlderMessages();
              }
              // Show/hide scroll-to-bottom
              const totalItems = this.messageDataSource.totalCount();
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
      this.chatPhoto = chat.photo;
      this.chatInitial = chat.title.length > 0 ? chat.title.charAt(0) : '?';
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
      this.rebuildFlatList();
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
        this.rebuildFlatList();
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

  private forwardMessage(msg: Message): void {
    // TODO: open chat picker for forwarding
    hilog.info(0x0001, 'ChatDetail', 'Forward message: %{public}d', msg.id);
  }

  private copyMessageText(msg: Message): void {
    // Copy text content to clipboard via pasteboard
    if (msg.text.length > 0) {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, msg.text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setDataSync(pasteData);
    }
  }

  private async deleteMessage(msg: Message): Promise<void> {
    await MessagesController.getInstance().deleteMessage(this.chatId, msg.id);
    this.messages = this.messages.filter(m => m.id !== msg.id);
    this.rebuildFlatList();
  }

  // --- Build flat list from messages (sender groups + date groups → flat items) ---

  private rebuildFlatList(): void {
    const TIME_THRESHOLD = 3 * 60; // 3 minutes

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

    // Build flat list: interleave date separators and messages
    const flatItems: ChatDetailListItem[] = [];
    let currentDateLabel = '';

    for (const item of grouped) {
      const dateLabel = formatDateSeparator(item.message.date);
      if (dateLabel !== currentDateLabel) {
        flatItems.push(new ChatDetailListItem(true, dateLabel));
        currentDateLabel = dateLabel;
      }
      flatItems.push(new ChatDetailListItem(false, '', item));
    }

    this.messageDataSource.setData(flatItems);
  }

  private sameDay(ts1: number, ts2: number): boolean {
    const d1 = new Date(ts1 * 1000);
    const d2 = new Date(ts2 * 1000);
    return d1.toDateString() === d2.toDateString();
  }

  private scrollToBottom(): void {
    const total = this.messageDataSource.totalCount();
    if (total > 0) {
      this.listScroller.scrollToIndex(total - 1);
    }
  }
}
