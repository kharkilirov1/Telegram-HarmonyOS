import { Message } from '../../models/Message';
import { MessageMetaRow } from './MessageMetaRow';
import { TextPart, containsUrl, extractDomain, splitByUrls } from './MessageUtils';

@ComponentV2
export struct TextBubble {
  @Param message: Message = new Message();
  @Local spoilerRevealed: boolean = false;

  build() {
    Column() {
      if (containsUrl(this.message.text)) {
        this.buildRichText()
      } else if (this.message.hasSpoiler && !this.spoilerRevealed) {
        Text(this.message.text)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(21)
          .blur(15)
          .onClick(() => { this.spoilerRevealed = true; })
      } else {
        Text(this.message.text)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(21)
      }

      if (containsUrl(this.message.text)) {
        this.buildLinkPreview()
      }

      MessageMetaRow({
        date: this.message.date,
        isOutgoing: this.message.isOutgoing,
        isRead: this.message.isRead,
        tint: $r('app.color.text_secondary'),
        checkTint: $r('app.color.telegram_blue')
      })
    }
  }

  @Builder
  private buildRichText() {
    Text() {
      ForEach(splitByUrls(this.message.text), (part: TextPart, index: number) => {
        if (part.isUrl) {
          Span(part.text)
            .fontColor($r('app.color.telegram_blue'))
            .decoration({
              type: TextDecorationType.Underline,
              color: $r('app.color.telegram_blue')
            })
        } else {
          Span(part.text)
            .fontColor($r('app.color.text_primary'))
        }
      }, (_part: TextPart, index: number) => index.toString())
    }
    .fontSize(16)
    .lineHeight(21)
  }

  @Builder
  private buildLinkPreview() {
    Column() {
      Divider()
        .strokeWidth(2)
        .color($r('app.color.telegram_blue'))
        .width('100%')

      Text(extractDomain(this.message.text))
        .fontSize(12)
        .fontColor($r('app.color.telegram_blue'))
        .fontWeight(FontWeight.Medium)
        .margin({ top: 4 })
        .maxLines(1)

      Text(extractDomain(this.message.text))
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ top: 2 })
        .maxLines(1)
    }
    .width('100%')
    .padding({ left: 8, top: 4, bottom: 4 })
    .margin({ top: 4 })
    .alignItems(HorizontalAlign.Start)
  }
}
