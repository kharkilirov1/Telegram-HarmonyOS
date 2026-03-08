import { TgContactRow } from '../atoms/TgContactRow';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgContactRowDemo {
  build() {
    Column() {
      TgContactRow({
        name: 'Alice Johnson',
        statusText: 'online',
        initials: 'AJ',
        isOnline: true
      })

      TgContactRow({
        name: 'Bob Smith',
        statusText: 'last seen 5 minutes ago',
        initials: 'BS',
        isOnline: false
      })

      TgContactRow({
        name: 'Very long contact name that should ellipsize on a single line',
        statusText: 'online',
        initials: 'VC',
        isOnline: true
      })

      TgContactRow({
        name: 'No status contact',
        statusText: '',
        initials: 'NS',
        isOnline: false,
        showSeparator: false
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .padding({ top: TgUiTokens.SPACE_16 })
  }
}
