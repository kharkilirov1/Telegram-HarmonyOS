// Global message search page
// Reference: Telegram Android SearchActivity, iOS ChatSearchController

import { TDLibClient } from '../../services/TDLibClient';
import { MessagesController } from '../../controllers/MessagesController';
import { Message, MessageContentType } from '../../models/Message';
import { BasicDataSource } from '../../datasources/BasicDataSource';

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

  private resultDataSource: BasicDataSource<Message> = new BasicDataSource<Message>();
  private searchTimerId: number = -1;

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
                  this.performSearch(value.trim());
                }, 500);
              } else {
                this.resultDataSource.setData([]);
                this.hasSearched = false;
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
        } else if (this.hasSearched && this.resultDataSource.totalCount() === 0) {
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
        } else {
          List() {
            LazyForEach(this.resultDataSource, (msg: Message) => {
              ListItem() {
                this.searchResultRow(msg)
              }
            }, (msg: Message) => msg.id.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .cachedCount(5)
          .edgeEffect(EdgeEffect.Spring)
          .divider({
            strokeWidth: 0.5,
            color: $r('app.color.separator'),
            startMargin: 16,
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

  @Builder
  searchResultRow(msg: Message) {
    Row() {
      // Chat initial avatar
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

        Text(msg.text)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.navPathStack.pop();
      this.navPathStack.pushPath({ name: 'ChatDetail', param: msg.chatId });
    })
  }

  private async performSearch(query: string): Promise<void> {
    this.isSearching = true;
    this.hasSearched = true;

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
        for (const raw of rawMessages) {
          const msg = MessagesController.getInstance().parseMessage(raw);
          parsed.push(msg);
        }
      }

      this.resultDataSource.setData(parsed);
    } catch (e) {
      this.resultDataSource.setData([]);
    } finally {
      this.isSearching = false;
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
