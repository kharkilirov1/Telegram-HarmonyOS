import { MessagesController } from '../../controllers/MessagesController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Message } from '../../models/Message';
import { BasicDataSource } from '../../datasources/BasicDataSource';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
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
  @Local isPeerOnline: boolean = false;
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
  private newMessageHandler = (args?: Record<string, unknown>): void => {
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

  private typingHandler = (args?: Record<string, unknown>): void => {
    if (!args) return;
    const chatId = args['chatId'] as number;
    if (chatId !== this.chatId) return;

    const chat = MessagesController.getInstance().getChat(this.chatId);
    this.isTyping = chat?.isTyping || false;
    this.typingText = chat?.typingDescription || '';
  };

  private dialogsUpdatedHandler = (_args?: Record<string, unknown>): void => {
    this.loadChatInfo();
    const chat = MessagesController.getInstance().getChat(this.chatId);
    if (chat) {
      this.isTyping = chat.isTyping;
      this.typingText = chat.typingDescription;
    }
  };

  private pinnedMessageHandler = (args?: Record<string, unknown>): void => {
    if (!args) return;
    const chatId = args['chatId'] as number;
    if (chatId !== this.chatId) return;
    // Reload pinned message from TDLib
    this.reloadPinnedMessage();
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.NEW_MESSAGE, this.newMessageHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.CHAT_ACTION_UPDATED, this.typingHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.DIALOGS_UPDATED, this.dialogsUpdatedHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.PINNED_MESSAGE_UPDATED, this.pinnedMessageHandler);

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
    NotificationCenter.getInstance()
      .removeObserver(EventId.PINNED_MESSAGE_UPDATED, this.pinnedMessageHandler);
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
            isOnline: this.isPeerOnline,
            onBack: () => { this.navPathStack.pop(); },
            onOpenInfo: () => {
              const privateUserId = this.getPrivatePeerUserId();
              openChatInfo(this.navPathStack, this.chatId, this.isGroupChat, this.isChannelChat, privateUserId);
            },
            onCall: () => {
              const privateUserId = this.getPrivatePeerUserId();
              openCallUi(this.navPathStack, this.chatId, this.chatTitle,
                privateUserId > 0 ? privateUserId : this.chatId);
            },
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
          onMediaTap: (url: string, messageId: number, sourceChatId: number) => {
            openMediaViewer(this.navPathStack, url, messageId, sourceChatId);
          },
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
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
    const info = buildChatInfoSnapshot(chat, '');
    this.chatTitle = info.title;
    this.isGroupChat = info.isGroup;
    this.isChannelChat = info.isChannel;
    this.chatPhoto = info.photo;
    this.chatInitial = info.initial;
    this.lastSeenText = info.lastSeenText;
    this.isPeerOnline = info.isOnline;
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
      this.showActionError();
    } finally {
      this.isLoading = false;
    }
  }

  private async reloadPinnedMessage(): Promise<void> {
    try {
      const pinned = await MessagesController.getInstance().getChatPinnedMessage(this.chatId);
      this.pinnedMessage = pinned;
      this.showPinnedBar = pinned !== null;
    } catch (_e) {
      // Keep existing pinned state on error
    }
  }

  private async loadOlderMessages(): Promise<void> {
    if (this.isLoadingOlder || this.endReachedOlder || this.messages.length === 0) return;
    this.isLoadingOlder = true;

    try {
      const prevCount = this.messageDataSource.totalCount();
      const loaded = await loadOlderMessagesData(this.chatId, this.messages, 50);
      this.messages = loaded.messages;
      this.endReachedOlder = loaded.endReachedOlder;
      this.rebuildFlatList();

      // Anchor-preserving: scroll to the item that was previously at the top
      const newCount = this.messageDataSource.totalCount();
      const insertedCount = newCount - prevCount;
      if (insertedCount > 0) {
        this.listScroller.scrollToIndex(insertedCount);
      }
    } catch (e) {
      this.showActionError();
    } finally {
      this.isLoadingOlder = false;
    }
  }

  private async sendMessage(text: string): Promise<void> {
    const replyId = this.replyMessage?.id || 0;
    this.replyMessage = null;
    try {
      await MessagesController.getInstance()
        .sendTextMessage(this.chatId, text, replyId);
    } catch (e) {
      this.showActionError();
    }
  }

  private async editMessageText(messageId: number, text: string): Promise<void> {
    this.editMessage = null;
    try {
      await MessagesController.getInstance().editMessageText(this.chatId, messageId, text);
      // Update local view
      const msg = this.messages.find(m => m.id === messageId);
      if (msg) {
        msg.text = text;
        this.rebuildFlatList();
      }
    } catch (e) {
      this.showActionError();
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
    try {
      await MessagesController.getInstance().sendGifMessage(this.chatId, gifId);
    } catch (e) {
      this.showActionError();
    }
  }

  private async sendStickerMessage(emoji: string): Promise<void> {
    try {
      await MessagesController.getInstance().sendStickerMessage(this.chatId, emoji);
    } catch (e) {
      this.showActionError();
    }
  }

  private async sendVoiceMessage(duration: number): Promise<void> {
    const replyId = this.replyMessage?.id || 0;
    this.replyMessage = null;
    try {
      await MessagesController.getInstance().sendVoiceMessage(this.chatId, duration, '', replyId);
    } catch (e) {
      this.showActionError();
    }
  }

  private async sendScheduledMessage(text: string, sendDate: number): Promise<void> {
    const replyId = this.replyMessage?.id || 0;
    this.replyMessage = null;
    try {
      await MessagesController.getInstance()
        .sendScheduledMessage(this.chatId, text, sendDate, replyId);
    } catch (e) {
      this.showActionError();
    }
  }

  private saveDraft(text: string): void {
    MessagesController.getInstance().setDraft(this.chatId, text, 0);
  }

  private async votePoll(msg: Message, optionIndex: number): Promise<void> {
    try {
      await MessagesController.getInstance().votePoll(this.chatId, msg.id, [optionIndex]);
    } catch (e) {
      this.showActionError();
    }
  }

  private async toggleReaction(msg: Message, emoji: string): Promise<void> {
    const resolvedEmoji = emoji.length === 0 ? '\u{1F44D}' : emoji;
    const existing = msg.reactions.find((r) => r.emoji === resolvedEmoji);
    const isRemoving = existing !== undefined && existing.isMine;

    // Optimistic local update — use resolvedEmoji so local and server stay in sync
    toggleReactionState(msg, resolvedEmoji);
    this.rebuildFlatList();

    // Send to TDLib
    try {
      await MessagesController.getInstance()
        .toggleMessageReaction(this.chatId, msg.id, resolvedEmoji, !isRemoving);
    } catch (_e) {
      // Revert optimistic update on failure
      toggleReactionState(msg, resolvedEmoji);
      this.rebuildFlatList();
    }
  }

  private async deleteMessage(msg: Message): Promise<void> {
    try {
      await MessagesController.getInstance().deleteMessage(this.chatId, msg.id);
      this.messages = this.messages.filter(m => m.id !== msg.id);
      this.rebuildFlatList();
    } catch (e) {
      this.showActionError();
    }
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

  private getPrivatePeerUserId(): number {
    return MessagesController.getInstance().getPrivateChatUserId(this.chatId);
  }

  private showActionError(): void {
    promptAction.showToast({
      message: getContext(this).resourceManager.getStringByNameSync('action_failed'),
      duration: 1200,
      bottom: 96
    });
  }
}
