import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgForwardPickerNavigationBar } from '../atoms/TgForwardPickerNavigationBar';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgForwardPickerNavigationBar' })
@ComponentV2
export struct TgForwardPickerNavigationBarDemo {
  build() {
    Column({ space: TgUiTokens.SPACE_12 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        TgChatBackground({ showPattern: true })
        TgForwardPickerNavigationBar({
          title: 'Переслать',
          topInset: 0
        })
      }
      .width('100%')
      .height(96)

      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
        TgForwardPickerNavigationBar({
          title: 'Forward to a conversation',
          topInset: 0,
          glassMode: TgGlassPolicy.MODE_FALLBACK
        })
      }
      .width('100%')
      .height(96)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
  }
}
