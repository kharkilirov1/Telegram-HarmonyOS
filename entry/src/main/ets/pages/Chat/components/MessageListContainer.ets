import { Message } from '../../../models/Message';
import { MessageBubble } from '../../../components/Message/MessageBubble';
import { DateSeparator } from '../../../components/Common/DateSeparator';
import { BasicDataSource } from '../../../datasources/BasicDataSource';
import { ChatDetailListItem } from './ChatDetailListItem';

@ComponentV2
export struct MessageListContainer {
  @Param isLoading: boolean = true;
  @Param isGroupChat: boolean = false;
  @Param isSelectionMode: boolean = false;
  @Param selectedMessageIds: number[] = [];
  @Param showScrollToBottom: boolean = false;
  @Param newMessageCount: number = 0;
  @Param listScroller: Scroller = new Scroller();
  @Param messageDataSource: BasicDataSource<ChatDetailListItem> = new BasicDataSource<ChatDetailListItem>();

  @Event onListScroll: (firstIndex: number, lastIndex: number, totalItems: number) => void = () => {};
  @Event onScrollToBottomTap: () => void = () => {};
  @Event onSelectMessage: (msg: Message) => void = () => {};
  @Event onReplyMessage: (msg: Message) => void = () => {};
  @Event onForwardMessage: (msg: Message) => void = () => {};
  @Event onCopyMessage: (msg: Message) => void = () => {};
  @Event onDeleteMessage: (msg: Message) => void = () => {};
  @Event onEditMessage: (msg: Message) => void = () => {};
  @Event onMediaTap: (url: string, messageId: number, chatId: number) => void = () => {};
  @Event onVideoPlay: (url: string, duration: number) => void = () => {};
  @Event onReactionTap: (msg: Message, emoji: string) => void = () => {};
  @Event onPollVote: (msg: Message, optionIndex: number) => void = () => {};

  build() {
    if (this.isLoading) {
      Column() {
        LoadingProgress()
          .width(40)
          .height(40)
          .color($r('app.color.telegram_blue'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
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
                  onSelect: (msg: Message) => { this.onSelectMessage(msg); },
                  onReply: (msg: Message) => { this.onReplyMessage(msg); },
                  onForward: (msg: Message) => { this.onForwardMessage(msg); },
                  onCopy: (msg: Message) => { this.onCopyMessage(msg); },
                  onDelete: (msg: Message) => { this.onDeleteMessage(msg); },
                  onEdit: (msg: Message) => { this.onEditMessage(msg); },
                  onMediaTap: (url: string, messageId: number, chatId: number) => {
                    this.onMediaTap(url, messageId, chatId);
                  },
                  onVideoPlay: (url: string, duration: number) => { this.onVideoPlay(url, duration); },
                  onReactionTap: (msg: Message, emoji: string) => { this.onReactionTap(msg, emoji); },
                  onPollVote: (msg: Message, optionIndex: number) => { this.onPollVote(msg, optionIndex); }
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
          const totalItems = this.messageDataSource.totalCount();
          this.onListScroll(firstIndex, lastIndex, totalItems);
        })

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
              .width(36)
              .height(36)
              .fillColor($r('app.color.text_secondary'))
              .backgroundColor($r('app.color.background_primary'))
              .borderRadius(20)
              .shadow({ radius: 4, color: $r('app.color.shadow_color') })
              .accessibilityText($r('app.string.accessibility_scroll_bottom'))
          }
          .position({ right: 16, bottom: 16 })
          .onClick(() => { this.onScrollToBottomTap(); })
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
  }
}
