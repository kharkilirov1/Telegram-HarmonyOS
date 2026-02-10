import { Message } from '../../models/Message';
import { MessageMetaRow } from './MessageMetaRow';

@ComponentV2
export struct DiceBubble {
  @Param message: Message = new Message();

  build() {
    Column() {
      // iOS: Large animated sticker, we show large emoji
      Text(this.message.diceEmoji || '🎲')
        .fontSize(80)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 8, bottom: 4 })

      MessageMetaRow({
        date: this.message.date,
        isOutgoing: this.message.isOutgoing,
        isRead: this.message.isRead,
        isEdited: this.message.isEdited,
        tint: $r('app.color.text_secondary'),
        checkTint: $r('app.color.telegram_blue')
      })
    }
    .width(120)
    .alignItems(HorizontalAlign.Center)
  }
}
