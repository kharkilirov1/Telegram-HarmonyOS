// Saved Messages page — personal bookmark/notes chat
// Reference: Telegram iOS SavedMessagesController, Android SavedMessagesActivity
// In Telegram, Saved Messages is a private chat with the user's own ID

import { AuthController } from '../../controllers/AuthController';
import { MessagesController } from '../../controllers/MessagesController';
import { TDLibClient } from '../../services/TDLibClient';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Message, GroupedMessage, MessageContentType } from '../../models/Message';
import { MessageBubble } from '../../components/Message/MessageBubble';
import { DateSeparator, formatDateSeparator } from '../../components/Common/DateSeparator';
import { BasicDataSource } from '../../datasources/BasicDataSource';
import { pasteboard } from '@kit.BasicServicesKit';

@Builder
export function SavedMessagesBuilder(name: string, param: Object) {
  SavedMessagesPage()
}

// Flat list item: date separator or message
class SavedListItem {
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
export struct SavedMessagesPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local chatId: number = 0;
  @Local messages: Message[] = [];
  @Local isLoading: boolean = true;
  @Local isLoadingOlder: boolean = false;
  @Local endReachedOlder: boolean = false;
  @Local showScrollToBottom: boolean = false;
  @Local inputText: string = '';
  @Local isSearchMode: boolean = false;
  @Local searchQuery: string = '';
  @Local searchResults: Message[] = [];
  @Local currentSearchIndex: number = -1;

  private listScroller: Scroller = new Scroller();
  private messageDataSource: BasicDataSource<SavedListItem> = new BasicDataSource<SavedListItem>();

  // Event handlers
  private newMessageHandler = (args?: Record<string, Object>): void => {
    if (!args) return;
    const msgChatId = args['chatId'] as number;
    if (msgChatId !== this.chatId) return;

    const msg = args['message'] as Message;
    this.messages.push(msg);
    this.rebuildFlatList();
    this.scrollToBottom();
  };

  private messageDeletedHandler = (args?: Record<string, Object>): void => {
    if (!args) return;
    const msgChatId = args['chatId'] as number;
    if (msgChatId !== this.chatId) return;

    const messageId = args['messageId'] as number;
    this.messages = this.messages.filter((m: Message) => m.id !== messageId);
    this.rebuildFlatList();
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance().observe(EventId.NEW_MESSAGE, this.newMessageHandler);
    NotificationCenter.getInstance().observe(EventId.MESSAGE_DELETED, this.messageDeletedHandler);
    this.initSavedChat();
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance().remove(EventId.NEW_MESSAGE, this.newMessageHandler);
    NotificationCenter.getInstance().remove(EventId.MESSAGE_DELETED, this.messageDeletedHandler);
  }

  private async initSavedChat(): Promise<void> {
    // Get current user ID — saved messages chat ID equals user ID
    const userId = await AuthController.getInstance().fetchMyUserId();
    if (userId <= 0) {
      this.isLoading = false;
      return;
    }

    // Create private chat with self (TDLib returns existing if already created)
    try {
      const chatResult = await TDLibClient.getInstance().send('createPrivateChat', {
        user_id: userId,
        force: false
      }) as Record<string, object>;
      this.chatId = (chatResult['id'] as number) || 0;
    } catch (_e) {
      this.isLoading = false;
      return;
    }

    if (this.chatId === 0) {
      this.isLoading = false;
      return;
    }

    await this.loadInitialMessages();
  }

  private async loadInitialMessages(): Promise<void> {
    this.isLoading = true;
    const loaded = await MessagesController.getInstance().loadMessages(this.chatId, 0, 50);
    this.messages = loaded.slice().sort((a: Message, b: Message) => a.id - b.id);
    this.rebuildFlatList();
    this.isLoading = false;

    // Scroll to bottom after initial load
    setTimeout(() => { this.scrollToBottom(); }, 100);
  }

  private async loadOlderMessages(): Promise<void> {
    if (this.isLoadingOlder || this.endReachedOlder || this.messages.length === 0) return;
    this.isLoadingOlder = true;

    const oldestId = this.messages[0].id;
    const older = await MessagesController.getInstance().loadMessages(this.chatId, oldestId, 30);

    if (older.length === 0) {
      this.endReachedOlder = true;
    } else {
      const existingIds = new Set(this.messages.map((m: Message) => m.id));
      const newMsgs = older.filter((m: Message) => !existingIds.has(m.id));
      if (newMsgs.length === 0) {
        this.endReachedOlder = true;
      } else {
        this.messages = [...newMsgs, ...this.messages].sort((a: Message, b: Message) => a.id - b.id);
        this.rebuildFlatList();
      }
    }
    this.isLoadingOlder = false;
  }

  private async sendMessage(): Promise<void> {
    const text = this.inputText.trim();
    if (text.length === 0 || this.chatId === 0) return;

    this.inputText = '';
    await MessagesController.getInstance().sendTextMessage(this.chatId, text);
  }

  private async deleteMessage(messageId: number): Promise<void> {
    await MessagesController.getInstance().deleteMessage(this.chatId, messageId);
  }

  // --- Search ---

  private async performSearch(): Promise<void> {
    if (this.searchQuery.length === 0 || this.chatId === 0) return;
    this.searchResults = await MessagesController.getInstance()
      .searchChatMessages(this.chatId, this.searchQuery);
    this.currentSearchIndex = this.searchResults.length > 0 ? 0 : -1;
  }

  private scrollToSearchResult(): void {
    if (this.currentSearchIndex < 0 || this.currentSearchIndex >= this.searchResults.length) return;
    const targetId = this.searchResults[this.currentSearchIndex].id;
    const idx = this.messages.findIndex((m: Message) => m.id === targetId);
    if (idx >= 0) {
      this.listScroller.scrollToIndex(idx);
    }
  }

  // --- List building ---

  private rebuildFlatList(): void {
    const items: SavedListItem[] = [];
    let lastDateLabel = '';

    const grouped = this.groupMessages(this.messages);

    for (const gm of grouped) {
      const dateLabel = formatDateSeparator(gm.message.date);
      if (dateLabel !== lastDateLabel) {
        items.push(new SavedListItem(true, dateLabel));
        lastDateLabel = dateLabel;
      }
      items.push(new SavedListItem(false, '', gm));
    }

    this.messageDataSource.replaceAll(items);
  }

  private groupMessages(msgs: Message[]): GroupedMessage[] {
    const result: GroupedMessage[] = [];
    for (let i = 0; i < msgs.length; i++) {
      const msg = msgs[i];
      const prevSameGroup = i > 0 && this.sameGroup(msgs[i - 1], msg);
      const nextSameGroup = i < msgs.length - 1 && this.sameGroup(msg, msgs[i + 1]);
      result.push(new GroupedMessage(msg, !prevSameGroup, !nextSameGroup));
    }
    return result;
  }

  private sameGroup(a: Message, b: Message): boolean {
    return a.senderId === b.senderId &&
      a.isOutgoing === b.isOutgoing &&
      Math.abs(a.date - b.date) < 300;
  }

  private scrollToBottom(): void {
    const count = this.messageDataSource.totalCount();
    if (count > 0) {
      this.listScroller.scrollToIndex(count - 1);
    }
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp * 1000);
    const h = date.getHours().toString().padStart(2, '0');
    const m = date.getMinutes().toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  build() {
    NavDestination() {
      Column() {
        // --- Top bar ---
        if (this.isSearchMode) {
          this.searchBar()
        } else {
          this.titleBar()
        }

        // --- Messages list ---
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(32).height(32)
              .color($r('app.color.telegram_blue'))
            Text($r('app.string.loading'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 8 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.messages.length === 0) {
          this.emptyState()
        } else {
          List({ scroller: this.listScroller }) {
            LazyForEach(this.messageDataSource, (item: SavedListItem) => {
              ListItem() {
                if (item.isDateSeparator) {
                  DateSeparator({ dateLabel: item.dateLabel })
                } else if (item.groupedMessage) {
                  this.savedMessageRow(item.groupedMessage)
                }
              }
            }, (item: SavedListItem, index: number) =>
              item.isDateSeparator ? `date_${item.dateLabel}_${index}` : `msg_${item.groupedMessage?.message?.id ?? index}`)
          }
          .width('100%')
          .layoutWeight(1)
          .cachedCount(5)
          .edgeEffect(EdgeEffect.Spring)
          .onScrollIndex((start: number) => {
            // Load older messages when scrolling near top
            if (start < 5) {
              this.loadOlderMessages();
            }
            this.showScrollToBottom = start < this.messageDataSource.totalCount() - 5;
          })
        }

        // --- Scroll to bottom FAB ---
        if (this.showScrollToBottom) {
          Row() {
            Image($r('app.media.ic_arrow_down'))
              .width(20).height(20)
              .fillColor($r('app.color.telegram_blue'))
          }
          .width(36).height(36)
          .borderRadius(18)
          .backgroundColor($r('app.color.background_primary'))
          .shadow({ radius: 4, color: $r('app.color.shadow_color') })
          .justifyContent(FlexAlign.Center)
          .position({ right: 16, bottom: 70 })
          .onClick(() => { this.scrollToBottom(); })
          .accessibilityText($r('app.string.accessibility_scroll_bottom'))
        }

        // --- Input bar ---
        Row() {
          TextInput({ placeholder: $r('app.string.message_placeholder'), text: this.inputText })
            .onChange((value: string) => { this.inputText = value; })
            .onSubmit(() => { this.sendMessage(); })
            .layoutWeight(1)
            .height(40)
            .borderRadius(20)
            .backgroundColor($r('app.color.background_secondary'))
            .padding({ left: 14, right: 14 })
            .fontSize(15)

          if (this.inputText.trim().length > 0) {
            Image($r('app.media.ic_send'))
              .width(32).height(32)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ left: 8 })
              .onClick(() => { this.sendMessage(); })
              .accessibilityText($r('app.string.accessibility_send'))
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.background_primary'))
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  titleBar() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24).height(24)
        .fillColor($r('app.color.telegram_blue'))
        .onClick(() => this.navPathStack.pop())
        .accessibilityText($r('app.string.accessibility_back'))

      // Bookmark icon
      Image($r('app.media.ic_saved'))
        .width(36).height(36)
        .fillColor($r('app.color.icon_on_primary'))
        .backgroundColor($r('app.color.settings_icon_blue'))
        .borderRadius(18)
        .padding(6)
        .margin({ left: 8 })

      Column() {
        Text($r('app.string.saved_messages'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .margin({ left: 10 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($r('app.media.ic_search'))
        .width(22).height(22)
        .fillColor($r('app.color.telegram_blue'))
        .onClick(() => { this.isSearchMode = true; })
        .accessibilityText($r('app.string.accessibility_search'))
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

  @Builder
  searchBar() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24).height(24)
        .fillColor($r('app.color.telegram_blue'))
        .onClick(() => {
          this.isSearchMode = false;
          this.searchQuery = '';
          this.searchResults = [];
          this.currentSearchIndex = -1;
        })
        .accessibilityText($r('app.string.accessibility_back'))

      TextInput({ placeholder: $r('app.string.search_messages_placeholder'), text: this.searchQuery })
        .onChange((value: string) => { this.searchQuery = value; })
        .onSubmit(() => { this.performSearch(); })
        .layoutWeight(1)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.background_secondary'))
        .padding({ left: 12, right: 12 })
        .fontSize(14)
        .margin({ left: 8 })

      if (this.searchResults.length > 0) {
        Text(`${this.currentSearchIndex + 1}/${this.searchResults.length}`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })

        Image($r('app.media.ic_arrow_up'))
          .width(20).height(20)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ left: 4 })
          .accessibilityText($r('app.string.search_previous_result'))
          .onClick(() => {
            if (this.currentSearchIndex > 0) {
              this.currentSearchIndex--;
              this.scrollToSearchResult();
            }
          })

        Image($r('app.media.ic_arrow_down'))
          .width(20).height(20)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ left: 4 })
          .accessibilityText($r('app.string.search_next_result'))
          .onClick(() => {
            if (this.currentSearchIndex < this.searchResults.length - 1) {
              this.currentSearchIndex++;
              this.scrollToSearchResult();
            }
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 12 })
    .backgroundColor($r('app.color.glass_nav_bg'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
  }

  @Builder
  emptyState() {
    Column() {
      Image($r('app.media.ic_saved'))
        .width(64).height(64)
        .fillColor($r('app.color.text_secondary'))
        .opacity(0.5)

      Text($r('app.string.saved_messages'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16 })

      Text($r('app.string.saved_messages_hint'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
        .padding({ left: 40, right: 40 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  savedMessageRow(gm: GroupedMessage) {
    Column() {
      Row() {
        Column() {
          // Forward source indicator
          if (gm.message.forwardedFrom.length > 0) {
            Row() {
              Text($r('app.string.forwarded_from', gm.message.forwardedFrom))
                .fontSize(12)
                .fontColor($r('app.color.telegram_blue'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .margin({ bottom: 4 })
          }

          // Message content
          if (gm.message.contentType === MessageContentType.TEXT) {
            Text(gm.message.text)
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .wordBreak(WordBreak.BREAK_ALL)
          } else if (gm.message.contentType === MessageContentType.PHOTO) {
            if (gm.message.photoUrl && gm.message.photoUrl.length > 0) {
              Image(gm.message.photoUrl)
                .width('100%')
                .constraintSize({ maxHeight: 200 })
                .borderRadius(8)
                .objectFit(ImageFit.Contain)
                .alt($r('app.string.photo'))
                .autoResize(true)
                .onError(() => {})
            }
            if (gm.message.text.length > 0) {
              Text(gm.message.text)
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 4 })
            }
          } else if (gm.message.contentType === MessageContentType.DOCUMENT) {
            Row() {
              Image($r('app.media.ic_document'))
                .width(20).height(20)
                .fillColor($r('app.color.telegram_blue'))
              Text(gm.message.fileName || $r('app.string.document_label'))
                .fontSize(14)
                .fontColor($r('app.color.telegram_blue'))
                .margin({ left: 6 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          } else if (gm.message.contentType === MessageContentType.STICKER) {
            Text(gm.message.text)
              .fontSize(48)
          } else {
            // Fallback for other content types
            Text(`[${gm.message.contentType}]`)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .fontStyle(FontStyle.Italic)
          }

          // Timestamp
          Row() {
            Text(this.formatTime(gm.message.date))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .margin({ top: 4 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: gm.isFirstInGroup ? 6 : 1, bottom: gm.isLastInGroup ? 6 : 1 })
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(gm.isFirstInGroup || gm.isLastInGroup ? 12 : 4)
    .margin({ left: 8, right: 8, top: gm.isFirstInGroup ? 4 : 0, bottom: gm.isLastInGroup ? 4 : 0 })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          this.showMessageActions(gm.message);
        })
    )
  }

  private showMessageActions(msg: Message): void {
    // Copy message text to clipboard
    if (msg.text.length > 0) {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, msg.text);
      const systemBoard = pasteboard.getSystemPasteboard();
      systemBoard.setData(pasteData);
    }
  }
}
