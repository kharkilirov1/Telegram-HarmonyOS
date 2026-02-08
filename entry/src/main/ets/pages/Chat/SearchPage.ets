// Global search page — contacts, chats, messages
// Reference: Telegram Android SearchActivity, iOS ChatSearchController

import { TDLibClient } from '../../services/TDLibClient';
import { MessagesController } from '../../controllers/MessagesController';
import { ContactsController } from '../../controllers/ContactsController';
import { Message, MessageContentType } from '../../models/Message';
import { User } from '../../models/User';
import { Chat } from '../../models/Chat';

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
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

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
                this.sectionHeader('Contacts')
              }

              ForEach(this.matchingContacts, (user: User) => {
                ListItem() {
                  this.contactRow(user)
                }
              }, (user: User) => `contact_${user.id}`)
            }

            // --- Chats Section ---
            if (this.matchingChats.length > 0) {
              ListItem() {
                this.sectionHeader('Chats')
              }

              ForEach(this.matchingChats, (chat: Chat) => {
                ListItem() {
                  this.chatRow(chat)
                }
              }, (chat: Chat) => `chat_${chat.id}`)
            }

            // --- Messages Section ---
            if (this.matchingMessages.length > 0) {
              ListItem() {
                this.sectionHeader('Messages')
              }

              ForEach(this.matchingMessages, (msg: Message) => {
                ListItem() {
                  this.messageRow(msg)
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

  // ---- Section header ----

  @Builder
  sectionHeader(title: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.telegram_blue'))
    }
    .width('100%')
    .height(36)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.background_secondary'))
  }

  // ---- Contact row ----

  @Builder
  contactRow(user: User) {
    Row() {
      Text(user.firstName.length > 0 ? user.firstName.charAt(0) : '?')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor($r('app.color.sender_color_5'))
        .textAlign(TextAlign.Center)
        .margin({ right: 12 })

      Column() {
        Row() {
          Text(`${user.firstName} ${user.lastName}`.trim())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (user.isOnline) {
            Circle()
              .width(8)
              .height(8)
              .fill($r('app.color.online_indicator'))
              .margin({ left: 6 })
          }
        }
        .width('100%')

        if (user.username.length > 0) {
          Text(`@${user.username}`)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        } else if (user.phoneNumber.length > 0) {
          Text(`+${user.phoneNumber}`)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.openPrivateChat(user.id);
    })
  }

  // ---- Chat row ----

  @Builder
  chatRow(chat: Chat) {
    Row() {
      Text(chat.title.length > 0 ? chat.title.charAt(0) : '?')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(chat.isGroup || chat.isChannel
          ? $r('app.color.sender_color_7')
          : $r('app.color.telegram_blue'))
        .textAlign(TextAlign.Center)
        .margin({ right: 12 })

      Column() {
        Row() {
          if (chat.isChannel) {
            Text('Channel')
              .fontSize(11)
              .fontColor($r('app.color.telegram_blue'))
              .margin({ right: 4 })
          } else if (chat.isGroup) {
            Text('Group')
              .fontSize(11)
              .fontColor($r('app.color.sender_color_7'))
              .margin({ right: 4 })
          }

          Text(chat.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (chat.unreadCount > 0) {
            Text(chat.unreadCount.toString())
              .fontSize(11)
              .fontColor(Color.White)
              .backgroundColor(chat.isMuted
                ? $r('app.color.text_secondary')
                : $r('app.color.telegram_blue'))
              .borderRadius(10)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .textAlign(TextAlign.Center)
              .margin({ left: 6 })
          }
        }
        .width('100%')

        if (chat.lastMessage.length > 0) {
          Text(chat.lastMessage)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.navPathStack.pop();
      this.navPathStack.pushPath({ name: 'ChatDetail', param: chat.id });
    })
  }

  // ---- Message row ----

  @Builder
  messageRow(msg: Message) {
    Row() {
      Text(msg.senderName.length > 0 ? msg.senderName.charAt(0) : '?')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor($r('app.color.telegram_blue'))
        .textAlign(TextAlign.Center)
        .margin({ right: 12 })

      Column() {
        Row() {
          Text(msg.senderName.length > 0 ? msg.senderName : 'Unknown')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)

          Text(this.formatDate(msg.date))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')

        // Show chat title for context when browsing messages
        if (this.getChatTitle(msg.chatId).length > 0) {
          Text(`in ${this.getChatTitle(msg.chatId)}`)
            .fontSize(12)
            .fontColor($r('app.color.telegram_blue'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 1 })
        }

        Text(msg.text.length > 0 ? msg.text : this.contentTypeLabel(msg.contentType))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height(76)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.navPathStack.pop();
      this.navPathStack.pushPath({ name: 'ChatDetail', param: msg.chatId });
    })
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
      const result = await TDLibClient.getInstance().send('searchChats', {
        query: query,
        limit: 20
      }) as Record<string, object>;

      const chatIds = result['chat_ids'] as number[];
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
      const result = await TDLibClient.getInstance().send('searchMessages', {
        chat_list: { '@type': 'chatListMain' },
        query: query,
        offset: '',
        offset_chat_id: 0,
        offset_message_id: 0,
        limit: 50
      }) as Record<string, object>;

      const rawMessages = result['messages'] as Record<string, object>[];
      const parsed: Message[] = [];

      if (rawMessages) {
        const mc = MessagesController.getInstance();
        for (const raw of rawMessages) {
          const msg = mc.parseMessage(raw);
          parsed.push(msg);
        }
      }

      return parsed;
    } catch (e) {
      return [];
    }
  }

  // ---- Navigation helpers ----

  private async openPrivateChat(userId: number): Promise<void> {
    try {
      const result = await TDLibClient.getInstance().send('createPrivateChat', {
        user_id: userId,
        force: false
      }) as Record<string, object>;

      const chatId = result['id'] as number;
      if (chatId) {
        this.navPathStack.pop();
        this.navPathStack.pushPath({ name: 'ChatDetail', param: chatId });
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
    switch (contentType) {
      case MessageContentType.PHOTO: return 'Photo';
      case MessageContentType.VIDEO: return 'Video';
      case MessageContentType.DOCUMENT: return 'Document';
      case MessageContentType.VOICE: return 'Voice message';
      case MessageContentType.STICKER: return 'Sticker';
      case MessageContentType.ANIMATION: return 'GIF';
      default: return '';
    }
  }

  private formatDate(timestamp: number): string {
    if (timestamp === 0) return '';
    const date = new Date(timestamp * 1000);
    const now = new Date();
    if (date.toDateString() === now.toDateString()) {
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' } as Intl.DateTimeFormatOptions);
    }
    return `${date.getDate()}.${(date.getMonth() + 1).toString().padStart(2, '0')}`;
  }
}
