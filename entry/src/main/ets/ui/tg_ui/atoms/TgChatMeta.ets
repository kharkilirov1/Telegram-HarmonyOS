import { TgIcon } from './TgIcon';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { formatTelegramCompactCount } from '../utils/TgCompactCount';

export enum TgChatSendStatus {
  None = 0,
  Sending = 1,
  Sent = 2,
  Read = 3,
  Failed = 4
}

@ComponentV2
export struct TgChatMetaTop {
  @Param timeText: string = '';
  @Param sendStatus: TgChatSendStatus = TgChatSendStatus.None;
  @Param rowHeight: number = TgUiTokens.CHAT_META_TOP_ROW_HEIGHT;

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

  build() {
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
    .height(this.rowHeight)
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
export struct TgChatMetaBottom {
  @Param unreadCount: number = 0;
  @Param isMuted: boolean = false;
  @Param isPinned: boolean = false;
  @Param hasMention: boolean = false;
  @Param reservePlaceholder: boolean = false;
  @Param rowHeight: number = TgUiTokens.CHAT_META_BOTTOM_ROW_HEIGHT;

  private unreadBadgeText(): string {
    return formatTelegramCompactCount(this.unreadCount);
  }

  private unreadBadgeWidth(): number {
    const text = this.unreadBadgeText();
    if (text.length <= 1) {
      return TgUiTokens.UNREAD_BADGE_MIN_WIDTH;
    }

    const measuredWidth = text.length * TgUiTokens.UNREAD_BADGE_TEXT_ESTIMATED_CHAR_WIDTH +
      TgUiTokens.UNREAD_BADGE_H_PADDING * 2;
    return Math.min(
      TgUiTokens.UNREAD_BADGE_MAX_WIDTH,
      Math.max(TgUiTokens.UNREAD_BADGE_MIN_WIDTH, Math.ceil(measuredWidth))
    );
  }

  private badgeBackgroundColor(): ResourceColor {
    return this.isMuted ? TgUiTokens.COLOR_UNREAD_BG_MUTED : TgUiTokens.COLOR_UNREAD_BG;
  }

  @Builder
  private buildMentionBadge() {
    Row() {
      Text('@')
        .fontSize(TgUiTokens.CHAT_META_MENTION_FONT_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(TgUiTokens.COLOR_UNREAD_TEXT)
        .lineHeight(TgUiTokens.UNREAD_BADGE_HEIGHT)
        .textAlign(TextAlign.Center)
    }
    .width(TgUiTokens.CHAT_META_MENTION_BADGE_SIZE)
    .height(TgUiTokens.CHAT_META_MENTION_BADGE_SIZE)
    .borderRadius(TgUiTokens.CHAT_META_MENTION_BADGE_SIZE / 2)
    .backgroundColor(this.badgeBackgroundColor())
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildUnreadBadge() {
    Row() {
      Text(this.unreadBadgeText())
        .fontSize(TgUiTokens.CHAT_META_BADGE_FONT_SIZE)
        .fontWeight(FontWeight.Regular)
        .fontColor(TgUiTokens.COLOR_UNREAD_TEXT)
        .lineHeight(TgUiTokens.UNREAD_BADGE_HEIGHT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Clip })
        .textAlign(TextAlign.Center)
    }
    .width(this.unreadBadgeWidth())
    .height(TgUiTokens.UNREAD_BADGE_HEIGHT)
    .borderRadius(TgUiTokens.UNREAD_BADGE_HEIGHT / 2)
    .backgroundColor(this.badgeBackgroundColor())
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildBottomContent() {
    if (this.unreadCount > 0) {
      Row({ space: TgUiTokens.CHAT_META_BADGE_GAP }) {
        if (this.hasMention) {
          this.buildMentionBadge()
        }
        this.buildUnreadBadge()
      }
    } else if (this.hasMention) {
      this.buildMentionBadge()
    } else if (this.isPinned) {
      TgIcon({
        src: TgUiTokens.ICON_RES_PIN,
        iconSize: TgUiTokens.CHAT_META_PIN_ICON_SIZE,
        tintColor: TgUiTokens.COLOR_ICON_SECONDARY
      })
    } else if (this.reservePlaceholder) {
      Row()
        .width(TgUiTokens.CHAT_META_BOTTOM_PLACEHOLDER_WIDTH)
        .height(TgUiTokens.CHAT_META_BOTTOM_PLACEHOLDER_HEIGHT)
        .opacity(0)
    } else {
      Row()
        .width(0)
        .height(this.rowHeight)
    }
  }

  build() {
    Row() {
      this.buildBottomContent()
    }
    .height(this.rowHeight)
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
export struct TgChatMeta {
  @Param timeText: string = '';
  @Param sendStatus: TgChatSendStatus = TgChatSendStatus.None;
  @Param unreadCount: number = 0;
  @Param isMuted: boolean = false;
  @Param isPinned: boolean = false;
  @Param hasMention: boolean = false;

  @Param minWidth: number = TgUiTokens.CHAT_META_MIN_WIDTH;
  @Param topRowHeight: number = TgUiTokens.CHAT_META_TOP_ROW_HEIGHT;
  @Param bottomRowHeight: number = TgUiTokens.CHAT_META_BOTTOM_ROW_HEIGHT;

  build() {
    Column({ space: TgUiTokens.CHAT_META_ROW_GAP }) {
      TgChatMetaTop({
        timeText: this.timeText,
        sendStatus: this.sendStatus,
        rowHeight: this.topRowHeight
      })
      TgChatMetaBottom({
        unreadCount: this.unreadCount,
        isMuted: this.isMuted,
        isPinned: this.isPinned,
        hasMention: this.hasMention,
        reservePlaceholder: true,
        rowHeight: this.bottomRowHeight
      })
    }
    .constraintSize({ minWidth: this.minWidth })
    .alignItems(HorizontalAlign.End)
  }
}
