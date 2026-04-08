// TgContactBubble — contact message bubble (iOS ref: ChatMessageContactBubbleContentNode)
// Layout: [Avatar 40vp] Name + Phone | [Message] [Add] buttons

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgAvatar } from './TgAvatar';

@ComponentV2
export struct TgContactBubble {
  @Param firstName: string = '';
  @Param lastName: string = '';
  @Param phoneNumber: string = '';
  @Param contactUserId: number = 0;
  @Param isOutgoing: boolean = false;

  private displayName(): string {
    const full = (this.firstName + ' ' + this.lastName).trim();
    return full.length > 0 ? full : this.phoneNumber;
  }

  private initials(): string {
    const f = this.firstName.length > 0 ? this.firstName.charAt(0) : '';
    const l = this.lastName.length > 0 ? this.lastName.charAt(0) : '';
    return (f + l).toUpperCase();
  }

  build() {
    Column() {
      // Contact card
      Row() {
        TgAvatar({
          avatarSize: 40,
          initials: this.initials(),
          useImage: false,
          imageSrc: '',
          isOnline: false,
          avatarBackgroundColor: TgUiTokens.AVATAR_COLOR_3
        })

        Column() {
          Text(this.displayName())
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.phoneNumber.length > 0) {
            Text(this.phoneNumber)
              .fontSize(14)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              .maxLines(1)
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ top: 8, bottom: 8, left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H })

      // Separator
      Row()
        .width('100%')
        .height(0.5)
        .backgroundColor(TgUiTokens.COLOR_SEPARATOR)

      // Action buttons row (iOS: Message + Add Contact)
      Row() {
        Text('Message')
          .fontSize(14)
          .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(33)

        Row()
          .width(0.5)
          .height(20)
          .backgroundColor(TgUiTokens.COLOR_SEPARATOR)

        Text('Add Contact')
          .fontSize(14)
          .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(33)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .constraintSize({ minWidth: 220 })
  }
}
