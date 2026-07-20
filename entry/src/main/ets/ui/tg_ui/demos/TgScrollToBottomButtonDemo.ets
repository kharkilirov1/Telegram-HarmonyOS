import { TgScrollToBottomButton } from '../atoms/TgScrollToBottomButton';
import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgScrollToBottomButton' })
@ComponentV2
export struct TgScrollToBottomButtonDemo {
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      TgChatBackground({ showPattern: true })

      Row({ space: TgUiTokens.SPACE_24 }) {
        TgScrollToBottomButton({ unreadCount: 0 })
        TgScrollToBottomButton({ unreadCount: 1 })
        TgScrollToBottomButton({ unreadCount: 24 })
        TgScrollToBottomButton({ unreadCount: 1200 })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_24,
        right: TgUiTokens.SPACE_24,
        top: TgUiTokens.SPACE_24
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
