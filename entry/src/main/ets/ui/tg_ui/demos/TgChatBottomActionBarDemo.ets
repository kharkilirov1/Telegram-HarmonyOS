import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgChatBottomActionBar } from '../atoms/TgChatBottomActionBar';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgChatBottomActionBar' })
@ComponentV2
export struct TgChatBottomActionBarDemo {
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      TgChatBackground({ showPattern: true })

      Column({ space: TgUiTokens.SPACE_12 }) {
        TgChatBottomActionBar({
          mode: 'action',
          actionText: 'Unmute',
          onActionPress: (): void => {}
        })

        TgChatBottomActionBar({
          mode: 'action',
          actionText: 'Mute',
          onActionPress: (): void => {}
        })

        TgChatBottomActionBar({
          mode: 'action',
          actionText: 'Join',
          isActionAccent: true,
          onActionPress: (): void => {}
        })

        TgChatBottomActionBar({
          mode: 'restricted',
          messageText: "Writing messages isn't allowed in this group."
        })

        TgChatBottomActionBar({
          mode: 'action',
          actionText: 'Join',
          isActionAccent: true,
          glassMode: TgGlassPolicy.MODE_FALLBACK,
          onActionPress: (): void => {}
        })

        TgChatBottomActionBar({
          mode: 'restricted',
          messageText: 'A long restriction reason must stay on one line without wrapping the capsule',
          glassMode: TgGlassPolicy.MODE_FALLBACK
        })
      }
      .width('100%')
      .padding({ bottom: TgUiTokens.SPACE_12 })
    }
    .width('100%')
    .height('100%')
  }
}
