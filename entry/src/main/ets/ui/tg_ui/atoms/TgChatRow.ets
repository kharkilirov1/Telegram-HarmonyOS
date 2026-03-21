import { TgAvatar } from './TgAvatar';
import { TgChatMeta, TgChatSendStatus } from './TgChatMeta';
import { TgIcon } from './TgIcon';
import { TgUiTokens } from '../tokens/TgUiTokens';

export class TgChatRowData {
  chatId: number = 0;

  title: string = '';
  preview: string = '';
  previewPrefix: string = '';
  previewPrefixStyle: 'none' | 'draft' | 'author' = 'none';
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
  isTyping: boolean = false;
  isDraft: boolean = false;
}

@ComponentV2
export struct TgChatRow {
  @Param chatId: number = 0;
  @Param title: string = '';
  @Param preview: string = '';
  @Param previewPrefix: string = '';
  @Param previewPrefixStyle: 'none' | 'draft' | 'author' = 'none';
  @Param timeText: string = '';
  @Param unreadCount: number = 0;
  @Param isMuted: boolean = false;
  @Param isPinned: boolean = false;
  @Param sendStatus: TgChatSendStatus = TgChatSendStatus.None;
  @Param avatarInitials: string = 'TG';
  @Param avatarUseImage: boolean = false;
  @Param avatarImageSrc: ResourceStr = $r('app.media.app_icon_transparent');
  @Param avatarIsOnline: boolean = false;
  @Param avatarBackgroundColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG;
  @Param avatarTextColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT;
  @Param showSeparator: boolean = true;
  @Param isTyping: boolean = false;
  @Param isDraft: boolean = false;

  private previewText(): string {
    return this.preview.length > 0 ? this.preview : ' ';
  }

  private previewPrefixText(): string {
    if (this.previewPrefixStyle === 'none') {
      return '';
    }
    const trimmed = this.previewPrefix.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
    return this.previewPrefixStyle === 'draft' ? 'Draft:' : '';
  }

  private titleText(): string {
    const trimmed = this.title.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
    return 'Unknown';
  }

  private previewBodyColor(): ResourceColor {
    return TgUiTokens.COLOR_TEXT_PREVIEW;
  }

  private previewPrefixColor(): ResourceColor {
    if (this.previewPrefixStyle === 'author') {
      return TgUiTokens.COLOR_AUTHOR_NAME;
    }
    return TgUiTokens.COLOR_TEXT_ERROR;
  }

  @Builder
  private buildPreviewLine() {
    Row() {
      if (this.previewPrefixText().length > 0) {
        Text(this.previewPrefixText())
          .fontSize(TgUiTokens.CHAT_ROW_PREVIEW_FONT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.previewPrefixColor())
          .margin({ right: TgUiTokens.CHAT_ROW_PREVIEW_PREFIX_GAP })
      }

      Text(this.previewText())
        .fontSize(TgUiTokens.CHAT_ROW_PREVIEW_FONT_SIZE)
        .fontColor(this.previewBodyColor())
        .fontWeight(FontWeight.Regular)
        .maxLines(TgUiTokens.CHAT_ROW_PREVIEW_MAX_LINES)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row() {
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_DEFAULT,
          initials: this.avatarInitials,
          useImage: this.avatarUseImage,
          imageSrc: this.avatarImageSrc,
          isOnline: this.avatarIsOnline,
          avatarBackgroundColor: this.avatarBackgroundColor,
          textColor: this.avatarTextColor
        })

        Row() {
          Column({ space: TgUiTokens.CHAT_ROW_TITLE_PREVIEW_GAP }) {
            Row() {
              Text(this.titleText())
                .fontSize(TgUiTokens.CHAT_ROW_TITLE_FONT_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              if (this.isMuted) {
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

            this.buildPreviewLine()
          }
          .layoutWeight(1)
          .padding({ right: TgUiTokens.CHAT_ROW_TEXT_META_GAP })
          .justifyContent(FlexAlign.Center)

          TgChatMeta({
            timeText: this.timeText,
            sendStatus: this.sendStatus,
            unreadCount: this.unreadCount,
            isMuted: this.isMuted,
            isPinned: this.isPinned,
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
      .backgroundColor(this.isPinned ? TgUiTokens.COLOR_CHAT_ROW_PINNED_BG : TgUiTokens.COLOR_BG_PRIMARY)

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
