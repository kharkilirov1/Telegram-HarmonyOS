import { TgComposeActionRow } from '../atoms/TgComposeActionRow';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Entry
@ComponentV2
export struct TgComposeActionRowDemo {
  build() {
    Column() {
      TgComposeActionRow({ title: 'New Group', icon: TgUiTokens.ICON_RES_GROUP })
      TgComposeActionRow({ title: 'New Contact', icon: TgUiTokens.ICON_RES_CONTACT_ADD })
      TgComposeActionRow({ title: 'New Channel', icon: TgUiTokens.ICON_RES_CHANNEL, showSeparator: false })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}
