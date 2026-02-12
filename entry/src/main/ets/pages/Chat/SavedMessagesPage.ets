// Saved Messages page — personal bookmark/notes chat
// Reference: Telegram iOS SavedMessagesController, Android SavedMessagesActivity
// In Telegram, Saved Messages is a private chat with the user's own ID

import { AuthController } from '../../controllers/AuthController';
import { MessagesController } from '../../controllers/MessagesController';
import { ChatService } from '../../services/ChatService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Message, GroupedMessage } from '../../models/Message';
import { DateSeparator, formatDateSeparator } from '../../components/Common/DateSeparator';
import { BasicDataSource } from '../../datasources/BasicDataSource';
import { pasteboard } from '@kit.BasicServicesKit';
import { SavedMessageInputBar } from './components/SavedMessageInputBar';
import { SavedMessagesEmptyState } from './components/SavedMessagesEmptyState';
import { SavedMessagesSearchBar } from './components/SavedMessagesSearchBar';
import { SavedMessageRow } from './components/SavedMessageRow';
import { SavedMessagesTopBar } from './components/SavedMessagesTopBar';

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
  private newMessageHandler = (args?: Record<string, unknown>): void => {
    if (!args) return;
    const msgChatId = args['chatId'] as number;
    if (msgChatId !== this.chatId) return;

    const msg = args['message'] as Message;
    this.messages.push(msg);
    this.rebuildFlatList();
    this.scrollToBottom();
  };

  private messageDeletedHandler = (args?: Record<string, unknown>): void => {
    if (!args) return;
    const msgChatId = args['chatId'] as number;
    if (msgChatId !== this.chatId) return;

    const messageId = args['messageId'] as number;
    this.messages = this.messages.filter((m: Message) => m.id !== messageId);
    this.rebuildFlatList();
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance().addObserver(EventId.NEW_MESSAGE, this.newMessageHandler);
    NotificationCenter.getInstance().addObserver(EventId.MESSAGE_DELETED, this.messageDeletedHandler);
    this.initSavedChat();
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance().removeObserver(EventId.NEW_MESSAGE, this.newMessageHandler);
    NotificationCenter.getInstance().removeObserver(EventId.MESSAGE_DELETED, this.messageDeletedHandler);
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
      this.chatId = await ChatService.getInstance().createPrivateChat(userId);
    } catch (e) {
      hilog.warn(0x0001, 'SavedMessagesPage', 'Failed to create private chat');
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
    try {
      await MessagesController.getInstance().sendTextMessage(this.chatId, text);
    } catch (e) {
      hilog.warn(0x0001, 'SavedMessagesPage', 'Failed to send message');
    }
  }

  private async deleteMessage(messageId: number): Promise<void> {
    try {
      await MessagesController.getInstance().deleteMessage(this.chatId, messageId);
    } catch (e) {
      hilog.warn(0x0001, 'SavedMessagesPage', 'Failed to delete message');
    }
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

    this.messageDataSource.setData(items);
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

  build() {
    NavDestination() {
      Column() {
        if (this.isSearchMode) {
          SavedMessagesSearchBar({
            searchQuery: this.searchQuery,
            resultsCount: this.searchResults.length,
            currentResultIndex: this.currentSearchIndex,
            onBack: () => {
              this.isSearchMode = false;
              this.searchQuery = '';
              this.searchResults = [];
              this.currentSearchIndex = -1;
            },
            onQueryChange: (value: string) => {
              this.searchQuery = value;
            },
            onSubmitSearch: () => {
              this.performSearch();
            },
            onPreviousResult: () => {
              if (this.currentSearchIndex > 0) {
                this.currentSearchIndex--;
                this.scrollToSearchResult();
              }
            },
            onNextResult: () => {
              if (this.currentSearchIndex < this.searchResults.length - 1) {
                this.currentSearchIndex++;
                this.scrollToSearchResult();
              }
            }
          })
        } else {
          SavedMessagesTopBar({
            onBack: () => {
              this.navPathStack.pop();
            },
            onEnterSearch: () => {
              this.isSearchMode = true;
            }
          })
        }

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
          SavedMessagesEmptyState()
        } else {
          List({ scroller: this.listScroller }) {
            LazyForEach(this.messageDataSource, (item: SavedListItem) => {
              ListItem() {
                if (item.isDateSeparator) {
                  DateSeparator({ dateText: item.dateLabel })
                } else if (item.groupedMessage) {
                  SavedMessageRow({
                    groupedMessage: item.groupedMessage,
                    onLongPress: (message: Message) => {
                      this.showMessageActions(message);
                    }
                  })
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

        if (this.showScrollToBottom) {
          Row() {
            Image($r('app.media.ic_arrow_down'))
              .width(20).height(20)
              .fillColor($r('app.color.telegram_blue'))
          }
          .width(36).height(36)
          .borderRadius(20)
          .backgroundColor($r('app.color.background_primary'))
          .shadow({ radius: 4, color: $r('app.color.shadow_color') })
          .justifyContent(FlexAlign.Center)
          .position({ right: 16, bottom: 70 })
          .onClick(() => { this.scrollToBottom(); })
          .accessibilityText($r('app.string.accessibility_scroll_bottom'))
        }

        SavedMessageInputBar({
          inputText: this.inputText,
          onInputChange: (value: string) => {
            this.inputText = value;
          },
          onSend: () => {
            this.sendMessage();
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.KEYBOARD], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
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
