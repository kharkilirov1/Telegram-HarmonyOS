import { TgTopBar } from '../atoms/TgTopBar';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgTopBar' })
@ComponentV2
export struct TgTopBarDemo {
  build() {
    Column({ space: TgUiTokens.SPACE_12 }) {
      TgTopBar({
        title: 'Chat'
      })

      TgTopBar({
        title: 'Chat',
        showBackAction: true
      })

      TgTopBar({
        title: 'Chat',
        showRightAction: true,
        rightIcon: TgUiTokens.ICON_RES_MORE
      })

      TgTopBar({
        title: 'Very long chat title that should ellipsize correctly in top bar',
        showBackAction: true,
        showRightAction: true
      })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

