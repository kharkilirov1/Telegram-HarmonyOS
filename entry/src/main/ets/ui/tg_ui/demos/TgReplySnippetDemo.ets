import { TgReplySnippet } from '../atoms/TgReplySnippet';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgReplySnippetDemo {
  private longAuthor: string = 'Very Long Author Name With Channel Context And Extra Prefix';
  private longPreview: string = 'Long reply preview text should truncate correctly and never break right-side media thumbnail alignment or bubble geometry.';
  private quotePreview: string = 'Quote preview can span multiple lines when expanded. This block validates higher max lines and keeps the left accent bar pinned to full snippet height.';

  @Builder
  private caseBlock(label: string, author: string, preview: string, isOutgoing: boolean = false, isQuote: boolean = false,
    hasThumbnail: boolean = false, containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Row() {
        TgReplySnippet({
          author: author,
          preview: preview,
          isOutgoing: isOutgoing,
          isQuote: isQuote,
          hasThumbnail: hasThumbnail,
          containerWidth: containerWidth
        })
      }
      .width('100%')
      .justifyContent(isOutgoing ? FlexAlign.End : FlexAlign.Start)
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_6,
      bottom: TgUiTokens.SPACE_6
    })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgReplySnippet Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        Text('Phase C / Step 3: reply header block (line + author + preview + optional thumbnail)')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming basic', 'Alex', 'Thanks! I will send details soon.', false)
        this.caseBlock('02 outgoing basic', 'You', 'Ок, договорились 👍', true)
        this.caseBlock('03 incoming with thumbnail', 'Anna', 'Photo', false, false, true)
        this.caseBlock('04 outgoing with thumbnail', 'You', 'Video', true, false, true)
        this.caseBlock('05 incoming long author', this.longAuthor, 'Short preview', false)
        this.caseBlock('06 incoming long preview', 'Telegram', this.longPreview, false)
        this.caseBlock('07 outgoing long preview', 'You', this.longPreview, true)
        this.caseBlock('08 quote mode incoming', 'Channel Name', this.quotePreview, false, true)
        this.caseBlock('09 quote mode outgoing', 'You', this.quotePreview, true, true)
        this.caseBlock('10 quote + thumbnail', 'Media Bot', this.quotePreview, false, true, true)
        this.caseBlock('11 narrow container', 'Narrow', this.longPreview, false, false, false, TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH)
        this.caseBlock('12 wide container', 'Wide', this.longPreview, false, false, false, TgUiTokens.MSG_DEMO_WIDE_CONTAINER_WIDTH)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}
