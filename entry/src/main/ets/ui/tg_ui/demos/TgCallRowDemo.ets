import { TgCallRow, TgCallType } from '../atoms/TgCallRow';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgCallRow' })
@ComponentV2
export struct TgCallRowDemo {
  build() {
    Column() {
      TgCallRow({
        name: 'Alice Johnson',
        initials: 'AJ',
        callType: TgCallType.Incoming,
        dateText: '10:24',
        isVideo: false
      })

      TgCallRow({
        name: 'Design Team Daily',
        initials: 'DT',
        callType: TgCallType.Outgoing,
        dateText: 'Yesterday',
        isVideo: true
      })

      TgCallRow({
        name: 'Missed call with very long contact name that should ellipsize',
        initials: 'MC',
        callType: TgCallType.Missed,
        dateText: 'Fri',
        isVideo: false
      })

      TgCallRow({
        name: 'Video support',
        initials: 'VS',
        callType: TgCallType.Missed,
        dateText: 'Mar 5',
        isVideo: true,
        showSeparator: false
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .padding({ top: TgUiTokens.SPACE_16 })
  }
}
