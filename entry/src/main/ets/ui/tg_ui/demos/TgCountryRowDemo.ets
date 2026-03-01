import { TgCountryRow } from '../atoms/TgCountryRow';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgCountryRowDemo {
  build() {
    Column() {
      TgCountryRow({
        flagEmoji: '🇺🇸',
        countryName: 'United States',
        dialCode: '+1',
        showSeparator: true
      })

      TgCountryRow({
        flagEmoji: '🇬🇧',
        countryName: 'United Kingdom of Great Britain and Northern Ireland',
        dialCode: '+44',
        showSeparator: true
      })

      TgCountryRow({
        flagEmoji: '🇯🇵',
        countryName: 'Japan',
        dialCode: '+81',
        showSeparator: false
      })
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

