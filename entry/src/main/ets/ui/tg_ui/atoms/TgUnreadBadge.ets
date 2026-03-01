import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgUnreadBadge {
  @Param count: number = 0;
  @Param isMuted: boolean = false;
  @Param isDisabled: boolean = false;

  @Param badgeHeight: number = TgUiTokens.UNREAD_BADGE_HEIGHT;
  @Param minWidth: number = TgUiTokens.UNREAD_BADGE_MIN_WIDTH;
  @Param horizontalPadding: number = TgUiTokens.UNREAD_BADGE_H_PADDING;

  @Param activeBackgroundColor: ResourceColor = TgUiTokens.COLOR_UNREAD_BG;
  @Param mutedBackgroundColor: ResourceColor = TgUiTokens.COLOR_UNREAD_BG_MUTED;
  @Param textColor: ResourceColor = TgUiTokens.COLOR_UNREAD_TEXT;

  private normalizedCount(): number {
    return Math.max(0, Math.floor(this.count));
  }

  private shouldRender(): boolean {
    return this.normalizedCount() > 0;
  }

  private displayText(): string {
    const value = this.normalizedCount();
    if (value <= 0) {
      return '';
    }
    if (value > TgUiTokens.UNREAD_BADGE_MAX_VISIBLE_COUNT) {
      return `${TgUiTokens.UNREAD_BADGE_MAX_VISIBLE_COUNT}+`;
    }
    return `${value}`;
  }

  private resolvedBackgroundColor(): ResourceColor {
    return this.isMuted ? this.mutedBackgroundColor : this.activeBackgroundColor;
  }

  build() {
    if (this.shouldRender()) {
      Row() {
        Text(this.displayText())
          .fontSize(TgUiTokens.FONT_BADGE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Clip })
          .textAlign(TextAlign.Center)
      }
      .height(this.badgeHeight)
      .constraintSize({ minWidth: this.minWidth })
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.resolvedBackgroundColor())
      .borderRadius(this.badgeHeight / 2)
      .opacity(this.isDisabled ? TgUiTokens.UNREAD_BADGE_DISABLED_OPACITY : 1)
    } else {
      Blank()
        .width(0)
        .height(0)
    }
  }
}
