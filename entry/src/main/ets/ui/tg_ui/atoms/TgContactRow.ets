// TgContactRow — Contact list row (Phase E-1).
// Avatar + Name + Last seen status. iOS Contacts style.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgAvatar } from './TgAvatar';

@ComponentV2
export struct TgContactRow {
  @Param name: string = '';
  @Param statusText: string = '';
  @Param initials: string = '';
  @Param avatarPath: string = '';
  @Param isOnline: boolean = false;
  @Param showSeparator: boolean = true;
  @Param avatarBgColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG;

  private statusColor(): ResourceColor {
    return this.isOnline ? TgUiTokens.COLOR_ONLINE_DOT : TgUiTokens.COLOR_TEXT_PREVIEW;
  }

  build() {
    Column() {
      Row() {
        TgAvatar({
          avatarSize: TgUiTokens.CONTACT_ROW_AVATAR_SIZE,
          initials: this.initials,
          useImage: this.avatarPath.length > 0,
          imageSrc: this.avatarPath,
          isOnline: this.isOnline,
          avatarBackgroundColor: this.avatarBgColor
        })

        Column() {
          Text(this.name)
            .fontSize(TgUiTokens.CONTACT_ROW_NAME_SIZE)
            .fontWeight(FontWeight.Regular)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.statusText.length > 0) {
            Text(this.statusText)
              .fontSize(TgUiTokens.CONTACT_ROW_STATUS_SIZE)
              .fontColor(this.statusColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: TgUiTokens.SPACE_2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: TgUiTokens.CONTACT_ROW_GAP })
      }
      .width('100%')
      .height(TgUiTokens.CONTACT_ROW_HEIGHT)
      .padding({
        left: TgUiTokens.CONTACT_ROW_PADDING_H,
        right: TgUiTokens.CONTACT_ROW_PADDING_H
      })
      .alignItems(VerticalAlign.Center)

      if (this.showSeparator) {
        Row()
          .width('100%')
          .height(TgUiTokens.CONTACT_ROW_SEPARATOR_STROKE)
          .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: TgUiTokens.CONTACT_ROW_SEPARATOR_INSET })
      }
    }
    .width('100%')
  }
}
