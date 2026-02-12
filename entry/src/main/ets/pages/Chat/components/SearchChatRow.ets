import { Chat } from '../../../models/Chat';

@ComponentV2
export struct SearchChatRow {
  @Param chat: Chat = new Chat();
  @Event onOpen: (chatId: number) => void = (_chatId: number) => {};

  build() {
    Row() {
      Text(this.chat.title.length > 0 ? this.chat.title.charAt(0) : '?')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(this.chat.isGroup || this.chat.isChannel
          ? $r('app.color.sender_color_7')
          : $r('app.color.telegram_blue'))
        .textAlign(TextAlign.Center)
        .margin({ right: 12 })

      Column() {
        Row() {
          if (this.chat.isChannel) {
            Text($r('app.string.search_chat_type_channel'))
              .fontSize(12)
              .fontColor($r('app.color.telegram_blue'))
              .margin({ right: 4 })
          } else if (this.chat.isGroup) {
            Text($r('app.string.search_chat_type_group'))
              .fontSize(12)
              .fontColor($r('app.color.sender_color_7'))
              .margin({ right: 4 })
          }

          Text(this.chat.title)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.chat.unreadCount > 0) {
            Text(this.chat.unreadCount.toString())
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor(this.chat.isMuted
                ? $r('app.color.text_secondary')
                : $r('app.color.telegram_blue'))
              .borderRadius(10)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .textAlign(TextAlign.Center)
              .margin({ left: 6 })
          }
        }
        .width('100%')

        if (this.chat.lastMessage.length > 0) {
          Text(this.chat.lastMessage)
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
      this.onOpen(this.chat.id);
    })
    .hoverEffect(HoverEffect.Highlight)
    .opacity(1.0)
    .stateStyles({
      pressed: {
        .opacity(0.6)
      },
      normal: {
        .opacity(1.0)
      }
    })
  }
}
