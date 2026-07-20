import { TgChatMeta, TgChatSendStatus } from './TgChatMeta';
import { TgIcon } from './TgIcon';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgArchivedChatsRow {
  @Param title: string = 'Archived Chats';
  @Param preview: string = '';
  @Param chatCount: number = 0;
  @Param unreadCount: number = 0;
  @Param showSeparator: boolean = true;
  @Param surfaceColor: ResourceColor = TgUiTokens.COLOR_BG_PRIMARY;
  @Param separatorColor: ResourceColor = TgUiTokens.COLOR_SEPARATOR;

  private previewText(): string {
    const preview = this.preview.trim();
    if (preview.length > 0) {
      return preview;
    }
    return `${Math.max(0, this.chatCount)} chats`;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row() {
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_ARCHIVE,
            iconSize: TgUiTokens.ICON_SIZE_LG,
            tintColor: TgUiTokens.COLOR_UNREAD_TEXT
          })
        }
        .width(TgUiTokens.AVATAR_SIZE_DEFAULT)
        .height(TgUiTokens.AVATAR_SIZE_DEFAULT)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(TgUiTokens.COLOR_ICON_PRIMARY)
        .borderRadius(TgUiTokens.AVATAR_SIZE_DEFAULT / 2)

        Row() {
          Column({ space: TgUiTokens.CHAT_ROW_TITLE_PREVIEW_GAP }) {
            Text(this.title)
              .fontSize(TgUiTokens.CHAT_ROW_TITLE_FONT_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.previewText())
              .fontSize(TgUiTokens.CHAT_ROW_PREVIEW_FONT_SIZE)
              .fontWeight(FontWeight.Regular)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
          .padding({ right: TgUiTokens.CHAT_ROW_TEXT_META_GAP })

          TgChatMeta({
            timeText: '',
            sendStatus: TgChatSendStatus.None,
            unreadCount: this.unreadCount,
            isMuted: true,
            minWidth: TgUiTokens.CHAT_ROW_META_FIXED_WIDTH
          })
            .width(TgUiTokens.CHAT_ROW_META_FIXED_WIDTH)
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
      .backgroundColor(this.surfaceColor)

      if (this.showSeparator) {
        Divider()
          .color(this.separatorColor)
          .strokeWidth(TgUiTokens.CHAT_ROW_SEPARATOR_STROKE)
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
