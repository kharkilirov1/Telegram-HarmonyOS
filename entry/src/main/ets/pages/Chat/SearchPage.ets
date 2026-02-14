// Global search page — contacts, chats, messages
// Reference: Telegram Android SearchActivity, iOS ChatSearchController

import { MessagesController } from '../../controllers/MessagesController';
import { ContactsController } from '../../controllers/ContactsController';
import { ChatService } from '../../services/ChatService';
import { Message, MessageContentType } from '../../models/Message';
import { User } from '../../models/User';
import { Chat } from '../../models/Chat';
import { SearchChatRow } from './components/SearchChatRow';
import { SearchContactRow } from './components/SearchContactRow';
import { SearchMessageRow } from './components/SearchMessageRow';
import { SearchSectionHeader } from './components/SearchSectionHeader';

@Builder
export function SearchBuilder(name: string, param: Object) {
  SearchPage()
}

@ComponentV2
export struct SearchPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local searchText: string = '';
  @Local isSearching: boolean = false;
  @Local hasSearched: boolean = false;
  @Local matchingContacts: User[] = [];
  @Local matchingChats: Chat[] = [];
  @Local matchingMessages: Message[] = [];

  private searchTimerId: number = -1;

  aboutToDisappear(): void {
    if (this.searchTimerId >= 0) {
      clearTimeout(this.searchTimerId);
      this.searchTimerId = -1;
    }
  }

  private totalResultCount(): number {
    return this.matchingContacts.length + this.matchingChats.length + this.matchingMessages.length;
  }

  build() {
    NavDestination() {
      Column() {
        // Search bar with back button
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .padding(12)
            .onClick(() => this.navPathStack.pop())
            .margin({ right: 8 })

          Search({ placeholder: $r('app.string.search_messages_placeholder'), value: this.searchText })
            .layoutWeight(1)
            .height(36)
            .onChange((value: string) => {
              this.searchText = value;
              if (this.searchTimerId >= 0) {
                clearTimeout(this.searchTimerId);
              }
              if (value.trim().length > 0) {
                this.searchTimerId = setTimeout(() => {
                  this.performGlobalSearch(value.trim());
                }, 500);
              } else {
                this.clearResults();
              }
            })
        }
        .width('100%')
        .height(48)
        .padding({ left: 4, right: 12 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 24, bottomRight: 24 })
        .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // Results
        if (this.isSearching) {
          Column() {
            LoadingProgress()
              .width(40).height(40).color($r('app.color.telegram_blue'))
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.hasSearched && this.totalResultCount() === 0) {
          Column() {
            Image($r('app.media.ic_search'))
              .width(48).height(48)
              .fillColor($r('app.color.text_secondary'))
              .opacity(0.5)
            Text($r('app.string.search_no_results'))
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 12 })
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.hasSearched) {
          List() {
            // --- Contacts Section ---
            if (this.matchingContacts.length > 0) {
              ListItem() {
                SearchSectionHeader({ title: $r('app.string.search_contacts_section') })
              }

              ForEach(this.matchingContacts, (user: User) => {
                ListItem() {
                  SearchContactRow({
                    user: user,
                    onOpen: (userId: number) => {
                      this.openPrivateChat(userId);
                    }
                  })
                }
              }, (user: User) => `contact_${user.id}`)
            }

            // --- Chats Section ---
            if (this.matchingChats.length > 0) {
              ListItem() {
                SearchSectionHeader({ title: $r('app.string.search_chats_section') })
              }

              ForEach(this.matchingChats, (chat: Chat) => {
                ListItem() {
                  SearchChatRow({
                    chat: chat,
                    onOpen: (chatId: number) => {
                      this.navPathStack.pop();
                      this.navPathStack.pushPath(new NavPathInfo('ChatDetail', chatId));
                    }
                  })
                }
              }, (chat: Chat) => `chat_${chat.id}`)
            }

            // --- Messages Section ---
            if (this.matchingMessages.length > 0) {
              ListItem() {
                SearchSectionHeader({ title: $r('app.string.search_messages_section') })
              }

              ForEach(this.matchingMessages, (msg: Message) => {
                ListItem() {
                  SearchMessageRow({
                    message: msg,
                    senderLabel: msg.senderName,
                    dateLabel: this.formatDate(msg.date),
                    chatTitle: this.getChatTitle(msg.chatId),
                    previewText: msg.text.length > 0 ? msg.text : this.contentTypeLabel(msg.contentType),
                    onOpenChat: (chatId: number) => {
                      this.navPathStack.pop();
                      this.navPathStack.pushPath(new NavPathInfo('ChatDetail', chatId));
                    }
                  })
                }
              }, (msg: Message) => `msg_${msg.id}_${msg.chatId}`)
            }
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
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
    }
    .hideTitleBar(true)
  }

  // ---- Search logic ----

  private clearResults(): void {
    this.matchingContacts = [];
    this.matchingChats = [];
    this.matchingMessages = [];
    this.hasSearched = false;
  }

  private async performGlobalSearch(query: string): Promise<void> {
    this.isSearching = true;
    this.hasSearched = true;

    try {
      const contactsPromise = this.searchContacts(query);
      const chatsPromise = this.searchChats(query);
      const messagesPromise = this.searchMessages(query);

      const results = await Promise.all([contactsPromise, chatsPromise, messagesPromise]);

      this.matchingContacts = results[0] as User[];
      this.matchingChats = results[1] as Chat[];
      this.matchingMessages = results[2] as Message[];
    } catch (e) {
      this.matchingContacts = [];
      this.matchingChats = [];
      this.matchingMessages = [];
    } finally {
      this.isSearching = false;
    }
  }

  private async searchContacts(query: string): Promise<User[]> {
    try {
      return await ContactsController.getInstance().searchContacts(query, 20);
    } catch (e) {
      return [];
    }
  }

  private async searchChats(query: string): Promise<Chat[]> {
    try {
      const result = await ChatService.getInstance().searchChats(query, 20);
      const chatIds = result.chat_ids;
      const chats: Chat[] = [];

      if (chatIds) {
        const mc = MessagesController.getInstance();
        for (const chatId of chatIds) {
          const chat = mc.getChat(chatId);
          if (chat) {
            chats.push(chat);
          }
        }
      }

      return chats;
    } catch (e) {
      return [];
    }
  }

  private async searchMessages(query: string): Promise<Message[]> {
    try {
      const result = await ChatService.getInstance().searchGlobalMessages(query, 50);
      const rawMessages = result['messages'] as Record<string, Object>[];
      if (!rawMessages) return [];
      return rawMessages.map((raw: Record<string, Object>): Message => {
        const msg = new Message();
        msg.id = (raw['id'] as number) || 0;
        msg.chatId = (raw['chat_id'] as number) || 0;
        msg.date = (raw['date'] as number) || 0;
        msg.isOutgoing = (raw['is_outgoing'] as boolean) || false;
        const content = raw['content'] as Record<string, Object>;
        if (content) {
          const text = content['text'] as Record<string, Object>;
          if (text) {
            msg.text = (text['text'] as string) || '';
          }
        }
        const sender = raw['sender_id'] as Record<string, Object>;
        if (sender) {
          msg.senderId = (sender['user_id'] as number) || 0;
        }
        return msg;
      });
    } catch (e) {
      return [];
    }
  }

  // ---- Navigation helpers ----

  private async openPrivateChat(userId: number): Promise<void> {
    try {
      const chatId = await ChatService.getInstance().createPrivateChat(userId);
      if (chatId) {
        this.navPathStack.pop();
        this.navPathStack.pushPath(new NavPathInfo('ChatDetail', chatId));
      }
    } catch (e) {
      // Failed to open private chat
    }
  }

  // ---- Formatting helpers ----

  private getChatTitle(chatId: number): string {
    const chat = MessagesController.getInstance().getChat(chatId);
    return chat ? chat.title : '';
  }

  private contentTypeLabel(contentType: MessageContentType): string {
    const rm = getContext(this).resourceManager;
    switch (contentType) {
      case MessageContentType.PHOTO: return rm.getStringByNameSync('photo');
      case MessageContentType.VIDEO: return rm.getStringByNameSync('video');
      case MessageContentType.DOCUMENT: return rm.getStringByNameSync('document_label');
      case MessageContentType.VOICE: return rm.getStringByNameSync('voice_message');
      case MessageContentType.STICKER: return rm.getStringByNameSync('sticker');
      case MessageContentType.ANIMATION: return rm.getStringByNameSync('gif');
      default: return '';
    }
  }

  private formatDate(timestamp: number): string {
    if (timestamp <= 0) return '';
    const date = new Date(timestamp * 1000);
    const now = new Date();
    if (date.toDateString() === now.toDateString()) {
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' } as Intl.DateTimeFormatOptions);
    }
    return `${date.getDate()}.${(date.getMonth() + 1).toString().padStart(2, '0')}`;
  }
}
