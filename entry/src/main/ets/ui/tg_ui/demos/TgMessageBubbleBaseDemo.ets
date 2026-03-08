import { TgMessageBubbleBase } from '../atoms/TgMessageBubbleBase';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgMessageBubbleBaseDemo {
  build() {
    Scroll() {
      Column({ space: TgUiTokens.SPACE_12 }) {
        TgMessageBubbleBase({
          text: 'Incoming text bubble',
          isOutgoing: false,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })

        TgMessageBubbleBase({
          text: 'Outgoing bubble with a longer string to check width and wrapping behavior.',
          isOutgoing: true,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })

        TgMessageBubbleBase({
          text: '😀😀😀',
          isOutgoing: false,
          isEmojiOnly: true,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })

        TgMessageBubbleBase({
          text: 'https://example.com/super/long/path/that/needs/break/all/handling/in/narrow/layout',
          isOutgoing: true,
          forceBreakAll: true,
          containerWidth: TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_16,
        bottom: TgUiTokens.SPACE_16
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}
