import { TgChatTopBar } from '../atoms/TgChatTopBar';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgChatTopBarDemo {
  build() {
    Column({ space: TgUiTokens.SPACE_12 }) {
      TgChatTopBar({
        title: 'Alice',
        subtitle: 'online',
        avatarInitials: 'AL',
        avatarColorIndex: 0,
        isOnline: true
      })

      TgChatTopBar({
        title: 'Engineering',
        subtitle: '124 members, 8 online',
        avatarInitials: 'EN',
        avatarColorIndex: 3,
        isOnline: false
      })

      TgChatTopBar({
        title: 'Very long chat title that should ellipsize inside center capsule',
        subtitle: 'Last seen recently with equally long subtitle text',
        avatarInitials: 'VL',
        avatarColorIndex: 7,
        isOnline: false
      })

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}
