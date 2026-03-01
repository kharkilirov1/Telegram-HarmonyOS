import { TgCountryTopOverlay } from '../atoms/TgCountryTopOverlay';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgCountryTopOverlayDemo {
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

      TgCountryTopOverlay({
        topInset: 44
      })
    }
    .width('100%')
    .height('100%')
  }
}

