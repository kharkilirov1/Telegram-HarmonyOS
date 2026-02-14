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

      if (this.message.webPageTitle.length > 0 || this.message.webPageSiteName.length > 0) {
        this.buildWebPagePreview()
      } else if (containsUrl(this.message.text)) {
        this.buildLinkPreview()
      }

      MessageMetaRow({
        date: this.message.date,
        isOutgoing: this.message.isOutgoing,
        isRead: this.message.isRead,
        isEdited: this.message.isEdited,
        sendState: this.message.sendState,
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
  private buildWebPagePreview() {
    // iOS ChatMessageWebpageBubbleContentNode: blue left bar + content block
    Row() {
      // Blue vertical bar — iOS: 3pt line accent
      Column()
        .width(3)
        .height('100%')
        .borderRadius(1.5)
        .backgroundColor($r('app.color.telegram_blue'))

      Column() {
        // Site name — iOS: semibold 15pt, accentTextColor
        if (this.message.webPageSiteName.length > 0) {
          Text(this.message.webPageSiteName)
            .fontSize(12)
            .fontColor($r('app.color.telegram_blue'))
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        // Title — iOS: subtitle
        if (this.message.webPageTitle.length > 0) {
          Text(this.message.webPageTitle)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
            .margin({ top: this.message.webPageSiteName.length > 0 ? 2 : 0 })
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        // Description — iOS: text with entities, max lines
        if (this.message.webPageDescription.length > 0) {
          Text(this.message.webPageDescription)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(18)
            .margin({ top: 2 })
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        // URL hint
        if (this.message.webPageUrl.length > 0 &&
          this.message.webPageTitle.length === 0 && this.message.webPageSiteName.length === 0) {
          Text(this.message.webPageUrl)
            .fontSize(12)
            .fontColor($r('app.color.telegram_blue'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 8 })
    }
    .width('100%')
    .margin({ top: 6 })
    .padding({ top: 2, bottom: 2 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildLinkPreview() {
    // Fallback link preview when no TDLib web_page data
    Row() {
      Column()
        .width(3)
        .height('100%')
        .borderRadius(1.5)
        .backgroundColor($r('app.color.telegram_blue'))

      Column() {
        Text(extractDomain(this.message.text))
          .fontSize(12)
          .fontColor($r('app.color.telegram_blue'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 8 })
    }
    .width('100%')
    .margin({ top: 6 })
    .padding({ top: 4, bottom: 4 })
    .alignItems(VerticalAlign.Top)
  }
}
