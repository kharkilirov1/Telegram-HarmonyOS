import { TgTopChromeBackground } from '../atoms/TgTopChromeBackground';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

@ComponentV2
export struct TgTopChromeBackgroundDemo {
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: TgUiTokens.SPACE_8 }) {
        Text('Scrollable content under chrome')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .margin({ top: 140, left: 16, right: 16 })

        ForEach([1, 2, 3, 4, 5, 6, 7, 8], (item: number) => {
          Row() {
            Text(`Row ${item}`)
              .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          }
          .width('100%')
          .height(44)
          .padding({ left: 16, right: 16 })
          .backgroundColor(item % 2 === 0 ? TgUiTokens.TOP_BAR_GLASS_FALLBACK_BG : TgUiTokens.COLOR_BG_PRIMARY)
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

      Column({ space: TgUiTokens.SPACE_12 }) {
        TgTopChromeBackground({
          topInset: 24,
          contentHeight: TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT
        })

        TgTopChromeBackground({
          topInset: 24,
          contentHeight: TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE + TgUiTokens.TOP_BAR_BOTTOM_PADDING,
          glassMode: TgGlassPolicy.MODE_FALLBACK,
          showTopEdgeEmphasis: false
        })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}
