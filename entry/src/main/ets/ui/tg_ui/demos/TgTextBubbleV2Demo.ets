import { TgTextBubbleV2 } from '../atoms/TgTextBubbleV2';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgMessageSendStatus } from '../atoms/TgMessageMeta';

@ComponentV2
export struct TgTextBubbleV2Demo {
  private longText: string = 'Long Telegram-like text bubble used to validate shrink-wrap, inline meta reserve, and the balance between reply snippet, sender line, and body text.';
  private longUrl: string = 'https://example.com/super/long/path/that/should/still/wrap/without/exploding/the/bubble/width/in/narrow/layout';
  private quotePreview: string = 'Quoted preview should stay compact enough for everyday replies while still allowing richer multiline behavior when quote mode is explicitly enabled.';

  @Builder
  private caseBlock(label: string, builder: () => void) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      builder()
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
        Text('TgTextBubbleV2 Demo')
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

        Text('Parallel text-bubble rebuild path: sender + reply + text + inline meta')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming basic', () => {
          TgTextBubbleV2({
            text: 'Incoming text bubble',
            timeText: '09:41',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('02 outgoing basic', () => {
          TgTextBubbleV2({
            text: 'Ок, договорились 👍',
            isOutgoing: true,
            timeText: '09:42',
            sendStatus: TgMessageSendStatus.Read,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('03 incoming sender + reply', () => {
          TgTextBubbleV2({
            text: this.longText,
            showSenderName: true,
            senderName: 'Rose',
            senderColorHex: '#8544d6',
            showReplySnippet: true,
            replyAuthor: 'Alex',
            replyPreview: 'Photo',
            replyHasThumbnail: true,
            timeText: '10:15',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('04 outgoing quote reply', () => {
          TgTextBubbleV2({
            text: 'Replying to a longer quoted fragment.',
            isOutgoing: true,
            showReplySnippet: true,
            replyAuthor: 'You',
            replyPreview: this.quotePreview,
            replyIsOutgoing: true,
            replyIsQuote: true,
            timeText: '10:18',
            sendStatus: TgMessageSendStatus.Sent,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('05 narrow url torture', () => {
          TgTextBubbleV2({
            text: this.longUrl,
            forceBreakAll: true,
            timeText: '10:22',
            containerWidth: TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH
          })
        })

        this.caseBlock('06 emoji only', () => {
          TgTextBubbleV2({
            text: '😀😀😀',
            isOutgoing: true,
            isEmojiOnly: true,
            timeText: '10:30',
            sendStatus: TgMessageSendStatus.Read,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('07 grouped top incoming', () => {
          TgTextBubbleV2({
            text: 'Grouped top bubble',
            groupingFlags: 'top',
            timeText: '10:33',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('08 grouped bottom outgoing', () => {
          TgTextBubbleV2({
            text: 'Grouped bottom bubble',
            isOutgoing: true,
            groupingFlags: 'bottom',
            timeText: '10:34',
            sendStatus: TgMessageSendStatus.Read,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('09 visible quote block', () => {
          TgTextBubbleV2({
            text: 'Intro line.\nQuoted fragment that should now render as a real quote block inside the bubble.\nOutro line.',
            quoteOffsets: [12],
            quoteLengths: [77],
            timeText: '10:40',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}
