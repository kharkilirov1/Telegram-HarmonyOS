import { TgProfileNavigationBar } from '../atoms/TgProfileNavigationBar';
import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgProfileNavigationBar' })
@ComponentV2
export struct TgProfileNavigationBarDemo {
  build() {
    Column({ space: TgUiTokens.SPACE_12 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        TgChatBackground({ showPattern: true })
        TgProfileNavigationBar({ topInset: 0 })
      }
      .width('100%')
      .height(120)

      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
        TgProfileNavigationBar({
          topInset: 0,
          glassMode: TgGlassPolicy.MODE_FALLBACK
        })
      }
      .width('100%')
      .height(120)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
  }
}
