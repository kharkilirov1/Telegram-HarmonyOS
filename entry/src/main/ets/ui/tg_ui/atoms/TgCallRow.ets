// TgCallRow — Call history row (Phase E-4).
// Avatar + Name + Call type icon (incoming/outgoing/missed) + Date.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgAvatar } from './TgAvatar';
import { TgIcon } from './TgIcon';

export enum TgCallType {
  Incoming = 0,
  Outgoing = 1,
  Missed = 2
}

@ComponentV2
export struct TgCallRow {
  @Param name: string = '';
  @Param initials: string = '';
  @Param avatarPath: string = '';
  @Param callType: TgCallType = TgCallType.Outgoing;
  @Param dateText: string = '';
  @Param isVideo: boolean = false;
  @Param showSeparator: boolean = true;
  @Param avatarBgColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG;

  private nameColor(): ResourceColor {
    return this.callType === TgCallType.Missed ? TgUiTokens.CALL_ROW_MISSED_COLOR : TgUiTokens.COLOR_TEXT_TITLE;
  }

  private callTypeIcon(): Resource {
    if (this.callType === TgCallType.Incoming || this.callType === TgCallType.Missed) {
      return TgUiTokens.ICON_RES_CALL_INCOMING;
    }
    return TgUiTokens.ICON_RES_CALL_OUTGOING;
  }

  private callTypeColor(): ResourceColor {
    if (this.callType === TgCallType.Missed) {
      return TgUiTokens.CALL_ROW_MISSED_COLOR;
    }
    return this.callType === TgCallType.Incoming
      ? TgUiTokens.COLOR_ONLINE_DOT
      : TgUiTokens.COLOR_TEXT_PREVIEW;
  }

  private callLabel(): string {
    if (this.isVideo) {
      return this.callType === TgCallType.Incoming ? 'Incoming Video'
        : this.callType === TgCallType.Missed ? 'Missed Video'
        : 'Outgoing Video';
    }
    return this.callType === TgCallType.Incoming ? 'Incoming'
      : this.callType === TgCallType.Missed ? 'Missed'
      : 'Outgoing';
  }

  build() {
    Column() {
      Row() {
        TgAvatar({
          avatarSize: TgUiTokens.CALL_ROW_AVATAR_SIZE,
          initials: this.initials,
          useImage: this.avatarPath.length > 0,
          imageSrc: this.avatarPath,
          avatarBackgroundColor: this.avatarBgColor
        })

        Column() {
          Text(this.name)
            .fontSize(TgUiTokens.CALL_ROW_NAME_SIZE)
            .fontWeight(FontWeight.Regular)
            .fontColor(this.nameColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            TgIcon({
              src: this.callTypeIcon(),
              iconSize: TgUiTokens.CALL_ROW_TYPE_ICON_SIZE,
              tintColor: this.callTypeColor()
            })

            Text(this.callLabel())
              .fontSize(TgUiTokens.CALL_ROW_DATE_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              .margin({ left: TgUiTokens.SPACE_4 })
          }
          .margin({ top: TgUiTokens.SPACE_2 })
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: TgUiTokens.CALL_ROW_GAP })

        Text(this.dateText)
          .fontSize(TgUiTokens.CALL_ROW_DATE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)

        TgIcon({
          src: TgUiTokens.ICON_RES_PHONE_CALL,
          iconSize: TgUiTokens.ICON_SIZE_MD,
          tintColor: TgUiTokens.COLOR_ICON_PRIMARY
        })
          .margin({ left: TgUiTokens.SPACE_12 })
      }
      .width('100%')
      .height(TgUiTokens.CALL_ROW_HEIGHT)
      .padding({
        left: TgUiTokens.CALL_ROW_PADDING_H,
        right: TgUiTokens.CALL_ROW_PADDING_H
      })
      .alignItems(VerticalAlign.Center)

      if (this.showSeparator) {
        Row()
          .width('100%')
          .height(TgUiTokens.CALL_ROW_SEPARATOR_STROKE)
          .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: TgUiTokens.CALL_ROW_SEPARATOR_INSET })
      }
    }
    .width('100%')
  }
}
