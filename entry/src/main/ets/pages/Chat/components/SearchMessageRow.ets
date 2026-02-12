import { Message } from '../../../models/Message';

@ComponentV2
export struct SearchMessageRow {
  @Param message: Message = new Message();
  @Param senderLabel: string = '';
  @Param dateLabel: string = '';
  @Param chatTitle: string = '';
  @Param previewText: string = '';
  @Event onOpenChat: (chatId: number) => void = (_chatId: number) => {};

  build() {
    Row() {
      Text(this.senderLabel.length > 0 ? this.senderLabel.charAt(0) : '?')
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
          Text(this.senderLabel.length > 0 ? this.senderLabel : $r('app.string.user_fallback'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)

          Text(this.dateLabel)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')

        if (this.chatTitle.length > 0) {
          Text(this.formatChatContext())
            .fontSize(12)
            .fontColor($r('app.color.telegram_blue'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 1 })
        }

        Text(this.previewText)
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
      this.onOpenChat(this.message.chatId);
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

  private formatChatContext(): string {
    const template = getContext(this).resourceManager.getStringByNameSync('search_in_chat_context');
    return template.replace('%s', this.chatTitle);
  }
}
