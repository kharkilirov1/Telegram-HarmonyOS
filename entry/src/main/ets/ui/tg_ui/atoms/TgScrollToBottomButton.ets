import { TgUiTokens } from '../tokens/TgUiTokens';
import { formatTelegramCompactCount } from '../utils/TgCompactCount';

function scrollButtonTransition(): TransitionEffect {
  const enter = TransitionEffect.OPACITY
    .animation({ duration: 300, curve: Curve.EaseOut })
    .combine(TransitionEffect.scale({ x: 0.2, y: 0.2 })
      .animation({ duration: 300, curve: Curve.Smooth }));
  const exit = TransitionEffect.OPACITY
    .animation({ duration: 200, curve: Curve.EaseIn })
    .combine(TransitionEffect.scale({ x: 0.2, y: 0.2 })
      .animation({ duration: 200, curve: Curve.EaseIn }));
  return TransitionEffect.asymmetric(enter, exit);
}

function scrollBadgeTransition(): TransitionEffect {
  const enter = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.SCROLL_FAB_BADGE_MOTION_MS, curve: Curve.EaseOut })
    .combine(TransitionEffect.scale({
      x: TgUiTokens.SCROLL_FAB_BADGE_MOTION_SCALE,
      y: TgUiTokens.SCROLL_FAB_BADGE_MOTION_SCALE
    }).animation({ duration: TgUiTokens.SCROLL_FAB_BADGE_MOTION_MS, curve: Curve.Smooth }));
  const exit = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.SCROLL_FAB_BADGE_MOTION_MS, curve: Curve.EaseIn })
    .combine(TransitionEffect.scale({
      x: TgUiTokens.SCROLL_FAB_BADGE_MOTION_SCALE,
      y: TgUiTokens.SCROLL_FAB_BADGE_MOTION_SCALE
    }).animation({ duration: TgUiTokens.SCROLL_FAB_BADGE_MOTION_MS, curve: Curve.EaseIn }));
  return TransitionEffect.asymmetric(enter, exit);
}

@ComponentV2
export struct TgScrollToBottomButton {
  @Param unreadCount: number = 0;
  @Event onPress: () => void = (): void => {};

  private safeUnreadCount(): number {
    return Math.max(0, Math.floor(this.unreadCount));
  }

  private badgeText(): string {
    return formatTelegramCompactCount(this.safeUnreadCount());
  }

  private badgeWidth(): number {
    const estimatedWidth = this.badgeText().length * TgUiTokens.UNREAD_BADGE_TEXT_ESTIMATED_CHAR_WIDTH +
      TgUiTokens.UNREAD_BADGE_H_PADDING * 2;
    return Math.min(
      TgUiTokens.UNREAD_BADGE_MAX_WIDTH,
      Math.max(TgUiTokens.SCROLL_FAB_BADGE_MIN_WIDTH, Math.ceil(estimatedWidth))
    );
  }

  private badgeX(): number {
    return (TgUiTokens.SCROLL_FAB_SIZE - this.badgeWidth()) / 2;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(20)
          .fontColor([TgUiTokens.COLOR_TEXT_TITLE])
      }
      .width(TgUiTokens.SCROLL_FAB_SIZE)
      .height(TgUiTokens.SCROLL_FAB_SIZE)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(TgUiTokens.SCROLL_FAB_BG)
      .borderRadius(TgUiTokens.SCROLL_FAB_SIZE / 2)
      .border({ width: 0.5, color: TgUiTokens.COLOR_SEPARATOR })
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
      .onClick(() => {
        this.onPress();
      })

      if (this.safeUnreadCount() > 0) {
        Row() {
          Text(this.badgeText())
            .fontSize(TgUiTokens.SCROLL_FAB_BADGE_FONT_SIZE)
            .fontWeight(FontWeight.Regular)
            .fontColor(TgUiTokens.COLOR_UNREAD_TEXT)
            .lineHeight(TgUiTokens.SCROLL_FAB_BADGE_HEIGHT)
            .maxLines(1)
            .textAlign(TextAlign.Center)
        }
        .width(this.badgeWidth())
        .height(TgUiTokens.SCROLL_FAB_BADGE_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(TgUiTokens.COLOR_UNREAD_BG)
        .borderRadius(TgUiTokens.SCROLL_FAB_BADGE_HEIGHT / 2)
        .position({ x: this.badgeX(), y: TgUiTokens.SCROLL_FAB_BADGE_TOP_OFFSET })
        .hitTestBehavior(HitTestMode.None)
        .transition(scrollBadgeTransition())
      }
    }
    .width(TgUiTokens.SCROLL_FAB_SIZE)
    .height(TgUiTokens.SCROLL_FAB_SIZE)
    .clip(false)
    .transition(scrollButtonTransition())
  }
}
