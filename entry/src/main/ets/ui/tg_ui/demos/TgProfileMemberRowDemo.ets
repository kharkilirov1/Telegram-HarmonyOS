import { TgProfileMemberRow } from '../atoms/TgProfileMemberRow';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgProfileMemberRow' })
@ComponentV2
export struct TgProfileMemberRowDemo {
  build() {
    Column() {
      TgProfileMemberRow({
        title: 'Kharki Lirov', subtitle: 'online', avatarInitials: 'KL', isOnline: true,
        avatarColor: TgUiTokens.AVATAR_COLOR_5, roleLabel: 'Owner', roleKind: 'creator'
      })
      TgProfileMemberRow({
        title: 'HarmonyOS Developer', subtitle: 'last seen recently', avatarInitials: 'HD',
        avatarColor: TgUiTokens.AVATAR_COLOR_3, roleLabel: 'admin', roleKind: 'administrator'
      })
      TgProfileMemberRow({
        title: 'Telegram Bot', subtitle: 'bot', avatarInitials: 'TB',
        avatarColor: TgUiTokens.AVATAR_COLOR_7
      })
      TgProfileMemberRow({
        title: 'A very long member name that must stay on one line', subtitle: 'last seen within a week',
        avatarInitials: 'AM', avatarColor: TgUiTokens.AVATAR_COLOR_2
      })
      TgProfileMemberRow({
        title: 'Anonymous Admin', subtitle: 'anonymous', avatarInitials: 'AA',
        avatarColor: TgUiTokens.AVATAR_COLOR_6, roleLabel: 'admin', roleKind: 'administrator',
        isEnabled: false, showSeparator: false
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
  }
}
