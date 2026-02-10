import { MessagesController } from '../../controllers/MessagesController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Message } from '../../models/Message';
import { BasicDataSource } from '../../datasources/BasicDataSource';
import { pasteboard } from '@kit.BasicServicesKit';
import { ChatDetailListItem } from './components/ChatDetailListItem';
import { SelectionToolbar } from './components/SelectionToolbar';
import { ChatHeader } from './components/ChatHeader';
import { SearchOverlay } from './components/SearchOverlay';
import { PinnedMessageBar } from './components/PinnedMessageBar';
import { MessageListContainer } from './components/MessageListContainer';
import { ComposerContainer } from './components/ComposerContainer';
import {
  buildFlatItems,
  findFlatIndexByMessageId,
  toggleMessageSelectionState,
  toggleReactionState
} from './components/ChatDetailStateUtils';
import {
  openCallUi,
  openChatInfo,
  openCreatePoll,
  openForwardPicker,
  openMediaViewer,
  openVideoPlayer
} from './components/ChatDetailNavigationUtils';
import {
  buildChatInfoSnapshot,
  loadInitialMessages as loadInitialMessagesData,
  loadOlderMessages as loadOlderMessagesData
} from './components/ChatDetailDataLoader';

@Builder
export function ChatDetailBuilder(name: string, param: Object) {
  ChatDetailPage({ chatId: param as number })
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
        if (this.isSelectionMode) {
          SelectionToolbar({
            selectedCount: this.selectedMessageIds.length,
            onCancel: () => { this.cancelSelectionMode(); },
            onForward: () => { this.forwardSelectedMessages(); },
            onDelete: () => { this.deleteSelectedMessages(); }
          })
        } else {
          ChatHeader({
            chatPhoto: this.chatPhoto,
            chatInitial: this.chatInitial,
            chatTitle: this.chatTitle,
            isTyping: this.isTyping,
            typingText: this.typingText,
            lastSeenText: this.lastSeenText,
            onBack: () => { this.navPathStack.pop(); },
            onOpenInfo: () => {
              openChatInfo(this.navPathStack, this.chatId, this.isGroupChat, this.isChannelChat);
            },
            onCall: () => { openCallUi(this.navPathStack, this.chatId, this.chatTitle); },
            onSearch: () => { this.isSearchMode = true; }
          })
        }

        SearchOverlay({
          isSearchMode: this.isSearchMode,
          chatId: this.chatId,
          onClose: () => { this.isSearchMode = false; },
          onScrollToMessage: (messageId: number) => { this.scrollToMessage(messageId); }
        })

        PinnedMessageBar({
          pinnedMessage: this.pinnedMessage,
          showPinnedBar: this.showPinnedBar,
          onClose: () => { this.showPinnedBar = false; },
          onOpenPinnedMessage: () => { this.scrollToPinnedMessage(); }
        })

        MessageListContainer({
          isLoading: this.isLoading,
          isGroupChat: this.isGroupChat,
          isSelectionMode: this.isSelectionMode,
          selectedMessageIds: this.selectedMessageIds,
          showScrollToBottom: this.showScrollToBottom,
          newMessageCount: this.newMessageCount,
          listScroller: this.listScroller,
          messageDataSource: this.messageDataSource,
          onListScroll: (firstIndex: number, lastIndex: number, totalItems: number) => {
            this.handleListScroll(firstIndex, lastIndex, totalItems);
          },
          onScrollToBottomTap: () => { this.handleScrollToBottomTap(); },
          onSelectMessage: (msg: Message) => { this.toggleMessageSelection(msg); },
          onReplyMessage: (msg: Message) => { this.replyMessage = msg; },
          onForwardMessage: (msg: Message) => { openForwardPicker(this.navPathStack, this.chatId, msg.id); },
          onCopyMessage: (msg: Message) => { this.copyMessageText(msg); },
          onDeleteMessage: (msg: Message) => { this.deleteMessage(msg); },
          onEditMessage: (msg: Message) => { this.editMessage = msg; },
          onMediaTap: (url: string) => { openMediaViewer(this.navPathStack, url); },
          onVideoPlay: (url: string, duration: number) => { openVideoPlayer(this.navPathStack, url, duration); },
          onReactionTap: (msg: Message, emoji: string) => { this.toggleReaction(msg, emoji); },
          onPollVote: (msg: Message, optionIndex: number) => { this.votePoll(msg, optionIndex); }
        })

        ComposerContainer({
          chatId: this.chatId,
          replyMessage: this.replyMessage,
          editMessage: this.editMessage,
          onSendMessage: (text: string) => { this.sendMessage(text); },
          onSendScheduled: (text: string, sendDate: number) => { this.sendScheduledMessage(text, sendDate); },
          onEditMessage: (messageId: number, text: string) => { this.editMessageText(messageId, text); },
          onCancelReply: () => { this.replyMessage = null; },
          onCancelEdit: () => { this.editMessage = null; },
          onSendSticker: (emoji: string) => { this.sendStickerMessage(emoji); },
          onSendGif: (gifId: number) => { this.sendGifMessage(gifId); },
          onSendVoice: (duration: number) => { this.sendVoiceMessage(duration); },
          onDraftChange: (text: string) => { this.saveDraft(text); },
          onCreatePoll: () => { openCreatePoll(this.navPathStack, this.chatId); }
        })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  private cancelSelectionMode(): void {
    this.isSelectionMode = false;
    this.selectedMessageIds = [];
  }

  private forwardSelectedMessages(): void {
    if (this.selectedMessageIds.length === 0) return;
    openForwardPicker(this.navPathStack, this.chatId, this.selectedMessageIds[0]);
    this.cancelSelectionMode();
  }

  private deleteSelectedMessages(): void {
    for (const msgId of this.selectedMessageIds) {
      void MessagesController.getInstance().deleteMessage(this.chatId, msgId);
    }
    this.messages = this.messages.filter((m: Message) => !this.selectedMessageIds.includes(m.id));
    this.cancelSelectionMode();
    this.rebuildFlatList();
  }

  private handleListScroll(firstIndex: number, lastIndex: number, totalItems: number): void {
    if (firstIndex < 5 && !this.isLoadingOlder && !this.endReachedOlder) {
      this.loadOlderMessages();
    }
    this.showScrollToBottom = (totalItems - lastIndex) > 15;
  }

  private handleScrollToBottomTap(): void {
    this.newMessageCount = 0;
    this.scrollToBottom();
  }

  private scrollToPinnedMessage(): void {
    const pinnedId = this.pinnedMessage?.id || 0;
    if (pinnedId === 0) return;
    this.scrollToMessage(pinnedId);
  }

  // --- Data loading ---

  private loadChatInfo(): void {
    const chat = MessagesController.getInstance().getChat(this.chatId);
    if (!chat) return;
    const memberStr = getContext(this).resourceManager.getStringByNameSync('group_members_count');
    const info = buildChatInfoSnapshot(chat, memberStr);
    this.chatTitle = info.title;
    this.isGroupChat = info.isGroup;
    this.isChannelChat = info.isChannel;
    this.chatPhoto = info.photo;
    this.chatInitial = info.initial;
    this.lastSeenText = info.lastSeenText;
  }

  private async loadInitialMessages(): Promise<void> {
    this.isLoading = true;
    try {
      const loaded = await loadInitialMessagesData(this.chatId, 50);
      this.messages = loaded.messages;
      this.endReachedOlder = loaded.endReachedOlder;
      this.pinnedMessage = loaded.pinnedMessage;
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
      const loaded = await loadOlderMessagesData(this.chatId, this.messages, 50);
      this.messages = loaded.messages;
      this.endReachedOlder = loaded.endReachedOlder;
      this.rebuildFlatList();
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

  private copyMessageText(msg: Message): void {
    // Copy text content to clipboard via pasteboard
    if (msg.text.length > 0) {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, msg.text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setDataSync(pasteData);
    }
  }

  private toggleMessageSelection(msg: Message): void {
    const next = toggleMessageSelectionState(this.isSelectionMode, this.selectedMessageIds, msg.id);
    this.isSelectionMode = next.isSelectionMode;
    this.selectedMessageIds = next.selectedMessageIds;
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
    toggleReactionState(msg, emoji);
    this.rebuildFlatList();
  }

  private async deleteMessage(msg: Message): Promise<void> {
    await MessagesController.getInstance().deleteMessage(this.chatId, msg.id);
    this.messages = this.messages.filter(m => m.id !== msg.id);
    this.rebuildFlatList();
  }

  // --- Build flat list from messages (sender groups + date groups → flat items) ---

  private rebuildFlatList(): void {
    this.messageDataSource.setData(buildFlatItems(this.messages));
  }

  private scrollToBottom(): void {
    const total = this.messageDataSource.totalCount();
    if (total > 0) {
      this.listScroller.scrollToIndex(total - 1);
    }
  }

  private scrollToMessage(messageId: number): void {
    const flatIdx = findFlatIndexByMessageId(this.messageDataSource, messageId);
    if (flatIdx >= 0) {
      this.listScroller.scrollToIndex(flatIdx);
    }
  }
}
