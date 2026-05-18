import { TgIcon } from './TgIcon';
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
  @Param hasMention: boolean = false;

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

  private unreadBadgeText(): string {
    const count = Math.max(0, Math.floor(this.unreadCount));
    if (count >= TgUiTokens.UNREAD_BADGE_COMPACT_MILLION) {
      return this.compactBadgeTextForUnit(
        count,
        TgUiTokens.UNREAD_BADGE_COMPACT_MILLION,
        TgUiTokens.UNREAD_BADGE_COMPACT_MILLION_SUFFIX
      );
    }
    if (count >= TgUiTokens.UNREAD_BADGE_COMPACT_THOUSAND) {
      return this.compactBadgeTextForUnit(
        count,
        TgUiTokens.UNREAD_BADGE_COMPACT_THOUSAND,
        TgUiTokens.UNREAD_BADGE_COMPACT_THOUSAND_SUFFIX
      );
    }
    return `${count}`;
  }

  private compactBadgeTextForUnit(count: number, unit: number, suffix: string): string {
    const whole = Math.floor(count / unit);
    const decimal = Math.floor((count % unit) / (unit / TgUiTokens.UNREAD_BADGE_COMPACT_DECIMAL_DIVISOR));
    if (decimal > 0) {
      return `${whole}.${decimal}${suffix}`;
    }
    return `${whole}${suffix}`;
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
