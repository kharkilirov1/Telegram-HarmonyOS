import { TgUiTokens } from '../tokens/TgUiTokens';
import { formatTelegramCompactCount } from '../utils/TgCompactCount';

@ComponentV2
export struct TgRootTabUnreadBadge {
  @Param count: number = 0;

  private safeCount(): number {
    return Math.max(0, Math.floor(this.count));
  }

  build() {
    if (this.safeCount() > 0) {
      Text(formatTelegramCompactCount(this.safeCount()))
        .fontSize(TgUiTokens.TAB_BADGE_FONT_SIZE)
        .fontWeight(FontWeight.Regular)
        .fontColor(TgUiTokens.TAB_BADGE_TEXT)
        .backgroundColor(TgUiTokens.TAB_BADGE_BG)
        .height(TgUiTokens.TAB_BADGE_HEIGHT)
        .constraintSize({ minWidth: TgUiTokens.TAB_BADGE_MIN_WIDTH })
        .padding({
          left: TgUiTokens.TAB_BADGE_PADDING_H,
          right: TgUiTokens.TAB_BADGE_PADDING_H
        })
        .borderRadius(TgUiTokens.TAB_BADGE_HEIGHT / 2)
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
  }
}
