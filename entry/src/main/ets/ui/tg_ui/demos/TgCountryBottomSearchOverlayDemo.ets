import { TgCountryBottomSearchOverlay } from '../atoms/TgCountryBottomSearchOverlay';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgCountryBottomSearchOverlayDemo {
  @Local query: string = '';

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

      TgCountryBottomSearchOverlay({
        query: this.query,
        bottomInset: 34,
        onQueryChange: (value: string): void => {
          this.query = value;
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

