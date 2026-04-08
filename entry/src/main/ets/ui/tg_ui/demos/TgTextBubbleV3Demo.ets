import { TgTextBubbleV3 } from '../atoms/TgTextBubbleV3'
import { TgUiTokens } from '../tokens/TgUiTokens'
import { TgMessageSendStatus } from '../atoms/TgMessageMeta'
import { TgTextLayout } from '../../text_engine/TgTextLayout'
import { computeTextBubbleLayout } from '../layout/TgBubbleLayout'
import { BubbleLayoutInput } from '../layout/TgBubbleLayoutTypes'

@ComponentV2
export struct TgTextBubbleV3Demo {
  private longText: string = 'Engine-driven Telegram-like text bubble used to verify shrink-wrap width, inline meta, and resilient width calculation under realistic content.'
  private multilineText: string = 'First line stays visible.\nSecond line must remain a hard break.\n\nParagraph break must also survive.'
  private quotedText: string = 'Intro line.\nQuoted fragment that should expand the bubble height as a real quote block.\nOutro line.'
  private narrowUrl: string = 'https://example.com/super/long/path/that/should/still/wrap/without/exploding/the/bubble/width/in/narrow/layout'

  private buildLayout(input: BubbleLayoutInput) {
    return computeTextBubbleLayout(TgTextLayout.getInstance(this.getUIContext()), input)
  }

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
        Text('TgTextBubbleV3 Demo')
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

        Text('Engine-driven runtime path: pre-computed layout + hard-break-safe text measurement')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming basic', () => {
          TgTextBubbleV3({
            layout: this.buildLayout({
              text: 'Incoming text bubble',
              isOutgoing: false,
              containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
              maxWidthRatio: TgUiTokens.BUBBLE_MAX_WIDTH_RATIO,
              avatarInset: 0,
              senderName: '',
              replyAuthor: '',
              replyPreview: '',
              replyHasThumbnail: false,
              timeText: '09:41',
              hasStatus: false,
              isEmojiOnly: false,
              forceBreakAll: false,
              quoteOffsets: [],
              quoteLengths: [],
              quoteCollapsedFlags: []
            }),
            text: 'Incoming text bubble',
            timeText: '09:41',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('02 multiline hard breaks', () => {
          TgTextBubbleV3({
            layout: this.buildLayout({
              text: this.multilineText,
              isOutgoing: false,
              containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
              maxWidthRatio: TgUiTokens.BUBBLE_MAX_WIDTH_RATIO,
              avatarInset: 0,
              senderName: '',
              replyAuthor: '',
              replyPreview: '',
              replyHasThumbnail: false,
              timeText: '10:02',
              hasStatus: false,
              isEmojiOnly: false,
              forceBreakAll: false,
              quoteOffsets: [],
              quoteLengths: [],
              quoteCollapsedFlags: []
            }),
            text: this.multilineText,
            timeText: '10:02',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('03 outgoing failed status', () => {
          TgTextBubbleV3({
            layout: this.buildLayout({
              text: this.longText,
              isOutgoing: true,
              containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
              maxWidthRatio: TgUiTokens.BUBBLE_MAX_WIDTH_RATIO,
              avatarInset: 0,
              senderName: '',
              replyAuthor: '',
              replyPreview: '',
              replyHasThumbnail: false,
              timeText: '10:11',
              hasStatus: true,
              isEmojiOnly: false,
              forceBreakAll: false,
              quoteOffsets: [],
              quoteLengths: [],
              quoteCollapsedFlags: []
            }),
            text: this.longText,
            isOutgoing: true,
            timeText: '10:11',
            sendStatus: TgMessageSendStatus.Failed,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('04 sender + reply', () => {
          TgTextBubbleV3({
            layout: this.buildLayout({
              text: 'Reply snippet should coexist with text width without forcing a broken bubble contract.',
              isOutgoing: false,
              containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
              maxWidthRatio: TgUiTokens.BUBBLE_MAX_WIDTH_RATIO,
              avatarInset: 0,
              senderName: 'Rose',
              replyAuthor: 'Alex',
              replyPreview: 'Photo',
              replyHasThumbnail: true,
              timeText: '10:15',
              hasStatus: false,
              isEmojiOnly: false,
              forceBreakAll: false,
              quoteOffsets: [],
              quoteLengths: [],
              quoteCollapsedFlags: []
            }),
            text: 'Reply snippet should coexist with text width without forcing a broken bubble contract.',
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

        this.caseBlock('05 visible quote block', () => {
          TgTextBubbleV3({
            layout: this.buildLayout({
              text: this.quotedText,
              isOutgoing: false,
              containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
              maxWidthRatio: TgUiTokens.BUBBLE_MAX_WIDTH_RATIO,
              avatarInset: 0,
              senderName: 'Rose',
              replyAuthor: '',
              replyPreview: '',
              replyHasThumbnail: false,
              timeText: '10:22',
              hasStatus: false,
              isEmojiOnly: false,
              forceBreakAll: false,
              quoteOffsets: [12],
              quoteLengths: [74],
              quoteCollapsedFlags: [false]
            }),
            text: this.quotedText,
            quoteOffsets: [12],
            quoteLengths: [74],
            quoteCollapsedFlags: [false],
            quoteAccentHex: '#8544d6',
            timeText: '10:22',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('06 narrow url torture', () => {
          TgTextBubbleV3({
            layout: this.buildLayout({
              text: this.narrowUrl,
              isOutgoing: false,
              containerWidth: TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH,
              maxWidthRatio: TgUiTokens.BUBBLE_MAX_WIDTH_RATIO,
              avatarInset: 0,
              senderName: '',
              replyAuthor: '',
              replyPreview: '',
              replyHasThumbnail: false,
              timeText: '10:30',
              hasStatus: false,
              isEmojiOnly: false,
              forceBreakAll: true,
              quoteOffsets: [],
              quoteLengths: [],
              quoteCollapsedFlags: []
            }),
            text: this.narrowUrl,
            forceBreakAll: true,
            timeText: '10:30',
            containerWidth: TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH
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
