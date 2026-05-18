import { TgCountrySectionHeader } from '../atoms/TgCountrySectionHeader';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgCountrySectionHeader' })
@ComponentV2
export struct TgCountrySectionHeaderDemo {
  build() {
    Column() {
      TgCountrySectionHeader({ title: 'A' })
      TgCountrySectionHeader({ title: 'B' })
      TgCountrySectionHeader({ title: 'LONG' })
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

