import { TgAvatar } from './TgAvatar';
import { TgChatMeta, TgChatSendStatus } from './TgChatMeta';
import { TgIcon } from './TgIcon';
import { TgUiTokens } from '../tokens/TgUiTokens';

export class TgChatRowData {
  chatId: number = 0;

  title: string = '';
  preview: string = '';
  timeText: string = '';

  unreadCount: number = 0;
  isMuted: boolean = false;
  isPinned: boolean = false;
  sendStatus: TgChatSendStatus = TgChatSendStatus.None;

  avatarInitials: string = 'TG';
  avatarUseImage: boolean = false;
  avatarImageSrc: Resource | string = $r('app.media.app_icon_transparent');
  avatarIsOnline: boolean = false;
  avatarBackgroundColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG;
  avatarTextColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT;
}

@Reusable
@Component
export struct TgChatRow {
  @Prop data: TgChatRowData = new TgChatRowData();
  @Prop showSeparator: boolean = true;

  private previewText(): string {
    return this.data.preview.length > 0 ? this.data.preview : ' ';
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row() {
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_DEFAULT,
          initials: this.data.avatarInitials,
          useImage: this.data.avatarUseImage,
          imageSrc: this.data.avatarImageSrc,
          isOnline: this.data.avatarIsOnline,
          avatarBackgroundColor: this.data.avatarBackgroundColor,
          textColor: this.data.avatarTextColor
        })

        Row() {
          Column({ space: TgUiTokens.CHAT_ROW_TITLE_PREVIEW_GAP }) {
            Row() {
              Text(this.data.title)
                .fontSize(TgUiTokens.FONT_TITLE_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              if (this.data.isMuted) {
                TgIcon({
                  src: TgUiTokens.ICON_RES_MUTE,
                  iconSize: TgUiTokens.CHAT_ROW_MUTE_ICON_SIZE,
                  tintColor: TgUiTokens.COLOR_ICON_MUTED
                })
                  .margin({ left: TgUiTokens.CHAT_ROW_TITLE_MUTE_GAP })
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Text(this.previewText())
              .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .layoutWeight(1)
          .padding({ right: TgUiTokens.CHAT_ROW_TEXT_META_GAP })
          .justifyContent(FlexAlign.Center)

          TgChatMeta({
            timeText: this.data.timeText,
            sendStatus: this.data.sendStatus,
            unreadCount: this.data.unreadCount,
            isMuted: this.data.isMuted,
            isPinned: this.data.isPinned,
            minWidth: TgUiTokens.CHAT_ROW_META_FIXED_WIDTH
          })
        }
        .layoutWeight(1)
        .margin({ left: TgUiTokens.CHAT_ROW_AVATAR_TEXT_GAP })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(TgUiTokens.CHAT_ROW_HEIGHT)
      .padding({
        left: TgUiTokens.CHAT_ROW_SIDE_INSET,
        right: TgUiTokens.CHAT_ROW_SIDE_INSET
      })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.data.isPinned ? TgUiTokens.COLOR_CHAT_ROW_PINNED_BG : TgUiTokens.COLOR_BG_PRIMARY)

      if (this.showSeparator) {
        Divider()
          .strokeWidth(TgUiTokens.CHAT_ROW_SEPARATOR_STROKE)
          .color(TgUiTokens.COLOR_SEPARATOR)
          .width('100%')
          .margin({
            left: TgUiTokens.CHAT_ROW_SEPARATOR_INSET,
            right: TgUiTokens.CHAT_ROW_SIDE_INSET
          })
      }
    }
    .width('100%')
    .height(TgUiTokens.CHAT_ROW_HEIGHT)
  }
}
