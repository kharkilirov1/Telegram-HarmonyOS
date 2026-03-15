import { TgIcon } from './TgIcon';
import { TgUnreadBadge } from './TgUnreadBadge';
import { TgUiTokens } from '../tokens/TgUiTokens';

export enum TgChatSendStatus {
  None = 0,
  Sending = 1,
  Sent = 2,
  Read = 3,
  Failed = 4
}

@ComponentV2
export struct TgChatMeta {
  @Param timeText: string = '';
  @Param sendStatus: TgChatSendStatus = TgChatSendStatus.None;
  @Param unreadCount: number = 0;
  @Param isMuted: boolean = false;
  @Param isPinned: boolean = false;

  @Param minWidth: number = TgUiTokens.CHAT_META_MIN_WIDTH;
  @Param topRowHeight: number = TgUiTokens.CHAT_META_TOP_ROW_HEIGHT;
  @Param bottomRowHeight: number = TgUiTokens.CHAT_META_BOTTOM_ROW_HEIGHT;

  private hasTimeText(): boolean {
    return this.timeText.trim().length > 0;
  }

  private hasStatusIcon(): boolean {
    return this.sendStatus !== TgChatSendStatus.None;
  }

  private statusIconResource(): Resource {
    switch (this.sendStatus) {
      case TgChatSendStatus.Sending:
        return TgUiTokens.ICON_RES_CLOCK;
      case TgChatSendStatus.Sent:
        return TgUiTokens.ICON_RES_CHECK_SINGLE;
      case TgChatSendStatus.Read:
        return TgUiTokens.ICON_RES_CHECK_DOUBLE;
      case TgChatSendStatus.Failed:
        return TgUiTokens.ICON_RES_FAILED;
      default:
        return TgUiTokens.ICON_RES_CLOCK;
    }
  }

  private statusIconColor(): ResourceColor {
    switch (this.sendStatus) {
      case TgChatSendStatus.Sending:
        return TgUiTokens.COLOR_STATUS_PENDING;
      case TgChatSendStatus.Sent:
        return TgUiTokens.COLOR_STATUS_SENT;
      case TgChatSendStatus.Read:
        return TgUiTokens.COLOR_STATUS_READ;
      case TgChatSendStatus.Failed:
        return TgUiTokens.COLOR_STATUS_FAILED;
      default:
        return TgUiTokens.COLOR_ICON_SECONDARY;
    }
  }

  private statusGap(): number {
    return this.hasTimeText() ? TgUiTokens.CHAT_META_STATUS_GAP : 0;
  }

  @Builder
  private buildBottomContent() {
    if (this.unreadCount > 0) {
      TgUnreadBadge({
        count: this.unreadCount,
        isMuted: this.isMuted
      })
    } else if (this.isPinned) {
      TgIcon({
        src: TgUiTokens.ICON_RES_PIN,
        iconSize: TgUiTokens.CHAT_META_PIN_ICON_SIZE,
        tintColor: TgUiTokens.COLOR_ICON_SECONDARY
      })
    } else {
      Row()
        .width(TgUiTokens.CHAT_META_BOTTOM_PLACEHOLDER_WIDTH)
        .height(TgUiTokens.CHAT_META_BOTTOM_PLACEHOLDER_HEIGHT)
        .opacity(0)
    }
  }

  @Builder
  private buildTopRow() {
    Row() {
      if (this.hasStatusIcon()) {
        TgIcon({
          src: this.statusIconResource(),
          iconSize: TgUiTokens.CHAT_META_STATUS_ICON_SIZE,
          tintColor: this.statusIconColor()
        })
          .margin({ right: this.statusGap() })
      }

      if (this.hasTimeText()) {
        Text(this.timeText)
          .fontSize(TgUiTokens.CHAT_META_TIME_FONT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Clip })
      }
    }
    .width('100%')
    .height(this.topRowHeight)
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildBottomRow() {
    Row() {
      this.buildBottomContent()
    }
    .width('100%')
    .height(this.bottomRowHeight)
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column({ space: TgUiTokens.CHAT_META_ROW_GAP }) {
      this.buildTopRow()
      this.buildBottomRow()
    }
    .constraintSize({ minWidth: this.minWidth })
    .alignItems(HorizontalAlign.End)
  }
}
