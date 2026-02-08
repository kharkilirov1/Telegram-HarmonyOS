import { MessagesController } from '../../controllers/MessagesController';
import { TDLibClient } from '../../services/TDLibClient';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Message, GroupedMessage, MessageDateGroup, MessageReaction } from '../../models/Message';
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
  @Local editMessage: Message | null = null;
  @Local chatPhoto: string | null = null;
  @Local chatInitial: string = '';
  @Local pinnedMessage: Message | null = null;
  @Local showPinnedBar: boolean = true;
  @Local isSelectionMode: boolean = false;
  @Local selectedMessageIds: number[] = [];
  @Local isChannelChat: boolean = false;

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
        // --- Top bar (selection mode or normal) ---
        if (this.isSelectionMode) {
          Row() {
            Text($r('app.string.cancel'))
              .fontSize(16)
              .fontColor($r('app.color.telegram_blue'))
              .onClick(() => {
                this.isSelectionMode = false;
                this.selectedMessageIds = [];
              })

            Blank()

            Text(`${this.selectedMessageIds.length} selected`)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))

            Blank()

            // Selection actions: Forward, Delete
            Image($r('app.media.ic_forward'))
              .width(22).height(22)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ right: 16 })
              .onClick(() => {
                if (this.selectedMessageIds.length > 0) {
                  this.navPathStack.pushPath({
                    name: 'ForwardPicker',
                    param: { messageId: this.selectedMessageIds[0], chatId: this.chatId } as Record<string, number>
                  });
                  this.isSelectionMode = false;
                  this.selectedMessageIds = [];
                }
              })

            Image($r('app.media.ic_delete'))
              .width(22).height(22)
              .fillColor($r('app.color.error_red'))
              .onClick(() => {
                for (const msgId of this.selectedMessageIds) {
                  MessagesController.getInstance().deleteMessage(this.chatId, msgId);
                }
                this.messages = this.messages.filter(m => !this.selectedMessageIds.includes(m.id));
                this.isSelectionMode = false;
                this.selectedMessageIds = [];
                this.rebuildFlatList();
              })
          }
        } else {
          Row() {
            Image($r('app.media.ic_back'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.telegram_blue'))
              .onClick(() => this.navPathStack.pop())

            // Chat avatar — clickable to open info (like Telegram iOS/Android)
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
            .onClick(() => { this.openChatInfo(); })

            // Call and more buttons
            Image($r('app.media.ic_phone_call'))
              .width(22)
              .height(22)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ right: 16 })
              .onClick(() => {
                this.navPathStack.pushPath({
                  name: 'CallUI',
                  param: { userId: this.chatId, userName: this.chatTitle, isVideo: false, isIncoming: false }
                    as Record<string, Object>
                });
              })

            Image($r('app.media.ic_more'))
              .width(22)
              .height(22)
              .fillColor($r('app.color.telegram_blue'))
          }
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

        // --- Pinned message bar (like Telegram iOS/Android) ---
        if (this.pinnedMessage !== null && this.showPinnedBar) {
          Row() {
            Divider()
              .vertical(true)
              .strokeWidth(2)
              .color($r('app.color.telegram_blue'))
              .height('100%')

            Column() {
              Text('Pinned Message')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.telegram_blue'))
              Text(this.pinnedMessage.text)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .margin({ left: 8 })
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('app.media.ic_close'))
              .width(16).height(16)
              .fillColor($r('app.color.text_secondary'))
              .onClick(() => { this.showPinnedBar = false; })
          }
          .width('100%')
          .height(36)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('app.color.glass_nav_bg'))
          .onClick(() => {
            // Scroll to pinned message
            const idx = this.messages.findIndex(m => m.id === this.pinnedMessage?.id);
            if (idx >= 0) {
              this.listScroller.scrollToIndex(idx);
            }
          })
        }

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
                      isSelectionMode: this.isSelectionMode,
                      isSelected: this.selectedMessageIds.includes(item.groupedMessage.message.id),
                      onSelect: (msg: Message) => { this.toggleMessageSelection(msg); },
                      onReply: (msg: Message) => { this.replyMessage = msg; },
                      onForward: (msg: Message) => { this.forwardMessage(msg); },
                      onCopy: (msg: Message) => { this.copyMessageText(msg); },
                      onDelete: (msg: Message) => { this.deleteMessage(msg); },
                      onEdit: (msg: Message) => { this.editMessage = msg; },
                      onMediaTap: (url: string) => {
                        this.navPathStack.pushPath({
                          name: 'MediaViewer',
                          param: { url: url } as Record<string, string>
                        });
                      },
                      onReactionTap: (msg: Message, emoji: string) => {
                        this.toggleReaction(msg, emoji);
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
          editMessage: this.editMessage,
          onSendMessage: (text: string) => this.sendMessage(text),
          onEditMessage: (messageId: number, text: string) => this.editMessageText(messageId, text),
          onCancelReply: () => { this.replyMessage = null; },
          onCancelEdit: () => { this.editMessage = null; },
          onSendSticker: (emoji: string) => { this.sendStickerMessage(emoji); },
          onSendGif: (gifId: number) => { this.sendGifMessage(gifId); }
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
      this.isChannelChat = chat.isChannel;
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
      // Detect first pinned-style message (stub: use first non-outgoing message with text)
      if (this.messages.length > 2) {
        const candidate = this.messages.find(m => !m.isOutgoing && m.text.length > 10);
        if (candidate) {
          this.pinnedMessage = candidate;
        }
      }
      // Add stub reactions to some messages for demo purposes
      if (this.messages.length > 3) {
        this.messages[1].reactions = [
          { emoji: '\u{1F44D}', count: 3, isMine: false },
          { emoji: '\u{2764}\u{FE0F}', count: 1, isMine: true }
        ];
      }
      if (this.messages.length > 5) {
        this.messages[4].reactions = [
          { emoji: '\u{1F602}', count: 2, isMine: false }
        ];
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

  private async editMessageText(messageId: number, text: string): Promise<void> {
    this.editMessage = null;
    await TDLibClient.getInstance().send('editMessageText', {
      chat_id: this.chatId,
      message_id: messageId,
      input_message_content: {
        '@type': 'inputMessageText',
        text: { '@type': 'formattedText', text: text }
      }
    });
    // Update local message
    const msg = this.messages.find(m => m.id === messageId);
    if (msg) {
      msg.text = text;
      this.rebuildFlatList();
    }
  }

  private forwardMessage(msg: Message): void {
    // Open ForwardPicker page to select target chat
    this.navPathStack.pushPath({
      name: 'ForwardPicker',
      param: { messageId: msg.id, chatId: this.chatId } as Record<string, number>
    });
  }

  private copyMessageText(msg: Message): void {
    // Copy text content to clipboard via pasteboard
    if (msg.text.length > 0) {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, msg.text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setDataSync(pasteData);
    }
  }

  private openChatInfo(): void {
    if (this.isGroupChat || this.isChannelChat) {
      this.navPathStack.pushPath({
        name: 'GroupInfo',
        param: { chatId: this.chatId } as Record<string, number>
      });
    } else {
      this.navPathStack.pushPath({
        name: 'UserInfo',
        param: { userId: this.chatId } as Record<string, number>
      });
    }
  }

  private toggleMessageSelection(msg: Message): void {
    if (!this.isSelectionMode) {
      this.isSelectionMode = true;
      this.selectedMessageIds = [msg.id];
    } else {
      const idx = this.selectedMessageIds.indexOf(msg.id);
      if (idx >= 0) {
        this.selectedMessageIds = this.selectedMessageIds.filter(id => id !== msg.id);
        if (this.selectedMessageIds.length === 0) {
          this.isSelectionMode = false;
        }
      } else {
        this.selectedMessageIds = [...this.selectedMessageIds, msg.id];
      }
    }
  }

  private async sendGifMessage(gifId: number): Promise<void> {
    // Send GIF animation as a message via TDLib
    await TDLibClient.getInstance().send('sendMessage', {
      chat_id: this.chatId,
      input_message_content: {
        '@type': 'inputMessageAnimation',
        animation: { '@type': 'inputFileId', id: gifId }
      }
    });
  }

  private async sendStickerMessage(emoji: string): Promise<void> {
    // Send sticker as a message via TDLib
    await TDLibClient.getInstance().send('sendMessage', {
      chat_id: this.chatId,
      input_message_content: {
        '@type': 'inputMessageSticker',
        sticker: { '@type': 'inputFileId', id: 0 },
        emoji: emoji
      }
    });
  }

  private toggleReaction(msg: Message, emoji: string): void {
    // If empty emoji, add a default reaction
    if (emoji.length === 0) {
      const defaultEmoji = '\u{1F44D}'; // thumbs up
      const existing = msg.reactions.find(r => r.emoji === defaultEmoji);
      if (existing) {
        existing.count++;
        existing.isMine = true;
      } else {
        msg.reactions.push({ emoji: defaultEmoji, count: 1, isMine: true });
      }
    } else {
      // Toggle the specific reaction
      const existing = msg.reactions.find(r => r.emoji === emoji);
      if (existing && existing.isMine) {
        existing.isMine = false;
        existing.count = Math.max(0, existing.count - 1);
        if (existing.count === 0) {
          msg.reactions = msg.reactions.filter(r => r.emoji !== emoji);
        }
      } else if (existing) {
        existing.count++;
        existing.isMine = true;
      } else {
        msg.reactions.push({ emoji: emoji, count: 1, isMine: true });
      }
    }
    this.rebuildFlatList();
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
