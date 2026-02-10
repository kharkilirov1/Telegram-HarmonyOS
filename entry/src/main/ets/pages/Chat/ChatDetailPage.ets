import { MessagesController } from '../../controllers/MessagesController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Message, GroupedMessage, MessageDateGroup, MessageReaction } from '../../models/Message';
import { Chat } from '../../models/Chat';
import { MessageBubble } from '../../components/Message/MessageBubble';
import { DateSeparator, formatDateSeparator } from '../../components/Common/DateSeparator';
import { TypingIndicator } from '../../components/Common/TypingIndicator';
import { ChatInputBar } from '../../components/Chat/ChatInputBar';
import { ChatSearchBar } from '../../components/Chat/ChatSearchBar';
import { formatLastSeen } from '../../components/Common/AvatarWithStatus';
import { BasicDataSource } from '../../datasources/BasicDataSource';
import { pasteboard } from '@kit.BasicServicesKit';

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
  @Local typingText: string = '';
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

  // Per-chat search
  @Local isSearchMode: boolean = false;

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
    this.typingText = chat?.typingDescription || '';
  };

  private dialogsUpdatedHandler = (_args?: Record<string, Object>): void => {
    this.loadChatInfo();
    const chat = MessagesController.getInstance().getChat(this.chatId);
    if (chat) {
      this.isTyping = chat.isTyping;
      this.typingText = chat.typingDescription;
    }
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.NEW_MESSAGE, this.newMessageHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.CHAT_ACTION_UPDATED, this.typingHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.DIALOGS_UPDATED, this.dialogsUpdatedHandler);

    this.loadChatInfo();
    this.loadInitialMessages();
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.NEW_MESSAGE, this.newMessageHandler);
    NotificationCenter.getInstance()
      .removeObserver(EventId.CHAT_ACTION_UPDATED, this.typingHandler);
    NotificationCenter.getInstance()
      .removeObserver(EventId.DIALOGS_UPDATED, this.dialogsUpdatedHandler);
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

            Text(`${this.selectedMessageIds.length}`)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .accessibilityText($r('app.string.selected_count'))

            Blank()

            // Selection actions: Forward, Delete
            Image($r('app.media.ic_forward'))
              .width(22).height(22)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ right: 16 })
              .onClick(() => {
                if (this.selectedMessageIds.length > 0) {
                  const fwdParam: Record<string, Object> = {};
                  fwdParam['messageId'] = this.selectedMessageIds[0];
                  fwdParam['chatId'] = this.chatId;
                  this.navPathStack.pushPath(new NavPathInfo('ForwardPicker', fwdParam));
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
          .width('100%')
          .height(56)
          .padding({ left: 8, right: 16 })
          .backgroundColor($r('app.color.glass_nav_bg'))
          .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
            colorMode: ThemeColorMode.SYSTEM,
            adaptiveColor: AdaptiveColor.DEFAULT,
            scale: 1.0
          })
        } else {
          Row() {
            Image($r('app.media.ic_back'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.telegram_blue'))
              .accessibilityText($r('app.string.accessibility_back'))
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
                .fontColor($r('app.color.icon_on_primary'))
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
                TypingIndicator({ typingText: this.typingText.length > 0 ? this.typingText : 'typing...' })
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
                const callParam: Record<string, Object> = {};
                callParam['userId'] = this.chatId;
                callParam['userName'] = this.chatTitle;
                callParam['isVideo'] = false;
                callParam['isIncoming'] = false;
                this.navPathStack.pushPath(new NavPathInfo('CallUI', callParam));
              })

            Image($r('app.media.ic_search'))
              .width(22)
              .height(22)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ right: 16 })
              .onClick(() => { this.isSearchMode = true; })

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
        }

        // --- Per-chat search bar ---
        if (this.isSearchMode) {
          ChatSearchBar({
            chatId: this.chatId,
            onClose: () => { this.isSearchMode = false; },
            onScrollToMessage: (messageId: number) => { this.scrollToMessage(messageId); }
          })
        }

        // --- Pinned message bar (like Telegram iOS/Android) ---
        if (this.pinnedMessage !== null && this.showPinnedBar) {
          Row() {
            Divider()
              .vertical(true)
              .strokeWidth(2)
              .color($r('app.color.telegram_blue'))
              .height('100%')

            Column() {
              Text($r('app.string.pinned_message'))
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
                        const mediaParam: Record<string, Object> = {};
                        mediaParam['url'] = url;
                        this.navPathStack.pushPath(new NavPathInfo('MediaViewer', mediaParam));
                      },
                      onVideoPlay: (url: string, duration: number) => {
                        const videoParam: Record<string, Object> = {};
                        videoParam['videoUrl'] = url;
                        videoParam['duration'] = duration;
                        this.navPathStack.pushPath(new NavPathInfo('VideoPlayer', videoParam));
                      },
                      onReactionTap: (msg: Message, emoji: string) => {
                        this.toggleReaction(msg, emoji);
                      },
                      onPollVote: (msg: Message, optionIndex: number) => {
                        this.votePoll(msg, optionIndex);
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
                    .fontColor($r('app.color.icon_on_primary'))
                    .backgroundColor($r('app.color.telegram_blue'))
                    .borderRadius(10)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .margin({ bottom: 4 })
                }
                Image($r('app.media.ic_arrow_down'))
                  .width(36).height(36)
                  .fillColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.background_primary'))
                  .borderRadius(18)
                  .shadow({ radius: 4, color: $r('app.color.shadow_color') })
                  .accessibilityText($r('app.string.accessibility_scroll_bottom'))
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
          chatId: this.chatId,
          onSendMessage: (text: string) => this.sendMessage(text),
          onSendScheduled: (text: string, sendDate: number) => { this.sendScheduledMessage(text, sendDate); },
          onEditMessage: (messageId: number, text: string) => this.editMessageText(messageId, text),
          onCancelReply: () => { this.replyMessage = null; },
          onCancelEdit: () => { this.editMessage = null; },
          onSendSticker: (emoji: string) => { this.sendStickerMessage(emoji); },
          onSendGif: (gifId: number) => { this.sendGifMessage(gifId); },
          onSendVoice: (duration: number) => { this.sendVoiceMessage(duration); },
          onDraftChange: (text: string) => { this.saveDraft(text); },
          onCreatePoll: () => {
            const pollParam: Record<string, Object> = {};
            pollParam['chatId'] = this.chatId;
            this.navPathStack.pushPath(new NavPathInfo('CreatePoll', pollParam));
          }
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
      if (chat.isGroup) {
        const memberStr = getContext(this).resourceManager.getStringByNameSync('group_members_count');
        this.lastSeenText = memberStr.replace('%s', chat.unreadCount.toString());
      } else {
        this.lastSeenText = formatLastSeen(chat.isUserOnline, chat.lastSeenDate);
      }
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
        const r1: MessageReaction = { emoji: '\u{1F44D}', count: 3, isMine: false };
        const r2: MessageReaction = { emoji: '\u{2764}\u{FE0F}', count: 1, isMine: true };
        this.messages[1].reactions = [r1, r2];
      }
      if (this.messages.length > 5) {
        const r3: MessageReaction = { emoji: '\u{1F602}', count: 2, isMine: false };
        this.messages[4].reactions = [r3];
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
    await MessagesController.getInstance().editMessageText(this.chatId, messageId, text);
    // Update local view
    const msg = this.messages.find(m => m.id === messageId);
    if (msg) {
      msg.text = text;
      this.rebuildFlatList();
    }
  }

  private forwardMessage(msg: Message): void {
    // Open ForwardPicker page to select target chat
    const fwdMsgParam: Record<string, Object> = {};
    fwdMsgParam['messageId'] = msg.id;
    fwdMsgParam['chatId'] = this.chatId;
    this.navPathStack.pushPath(new NavPathInfo('ForwardPicker', fwdMsgParam));
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
      const groupParam: Record<string, Object> = {};
      groupParam['chatId'] = this.chatId;
      this.navPathStack.pushPath(new NavPathInfo('GroupInfo', groupParam));
    } else {
      const userParam: Record<string, Object> = {};
      userParam['userId'] = this.chatId;
      this.navPathStack.pushPath(new NavPathInfo('UserInfo', userParam));
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
    await MessagesController.getInstance().sendGifMessage(this.chatId, gifId);
  }

  private async sendStickerMessage(emoji: string): Promise<void> {
    await MessagesController.getInstance().sendStickerMessage(this.chatId, emoji);
  }

  private async sendVoiceMessage(duration: number): Promise<void> {
    const replyId = this.replyMessage?.id || 0;
    this.replyMessage = null;
    await MessagesController.getInstance().sendVoiceMessage(this.chatId, duration, '', replyId);
  }

  private async sendScheduledMessage(text: string, sendDate: number): Promise<void> {
    const replyId = this.replyMessage?.id || 0;
    this.replyMessage = null;
    await MessagesController.getInstance()
      .sendScheduledMessage(this.chatId, text, sendDate, replyId);
  }

  private saveDraft(text: string): void {
    MessagesController.getInstance().setDraft(this.chatId, text, 0);
  }

  private async votePoll(msg: Message, optionIndex: number): Promise<void> {
    await MessagesController.getInstance().votePoll(this.chatId, msg.id, [optionIndex]);
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
        const newReaction: MessageReaction = { emoji: defaultEmoji, count: 1, isMine: true };
        msg.reactions.push(newReaction);
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
        const newReaction: MessageReaction = { emoji: emoji, count: 1, isMine: true };
        msg.reactions.push(newReaction);
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

  private scrollToMessage(messageId: number): void {
    const idx = this.messages.findIndex(m => m.id === messageId);
    if (idx >= 0) {
      // Account for date separators in flat list
      let flatIdx = 0;
      for (let i = 0; i < this.messageDataSource.totalCount(); i++) {
        const item = this.messageDataSource.getData(i) as ChatDetailListItem;
        if (!item.isDateSeparator && item.groupedMessage?.message.id === messageId) {
          flatIdx = i;
          break;
        }
      }
      this.listScroller.scrollToIndex(flatIdx);
    }
  }
}
