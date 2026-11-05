// D27: dice bubble. The emoji is rendered large, the rolled value sits in a badge and a roll animates the
// value change the way iOS shows it. Tokens only, no layout magic numbers.

import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgDiceBubble {
  @Param emoji: string = '🎲';
  @Param value: number = 0;

  // Starts at zero so the first value arriving animates the opening roll.
  @Local private shownValue: number = 0;
  @Local private rollScale: number = 1;
  @Local private rollRotation: number = 0;

  @Monitor('value')
  onValueChanged(): void {
    if (this.value === this.shownValue) {
      return;
    }
    // A new roll: the emoji turns while scaling, then settles; the badge counts up.
    this.getUIContext().animateTo({ duration: TgUiTokens.DICE_ROLL_DURATION_MS, curve: Curve.EaseOut }, () => {
      this.rollScale = TgUiTokens.DICE_ROLL_PEAK_SCALE;
      this.rollRotation = TgUiTokens.DICE_ROLL_PEAK_ROTATION;
    });
    this.getUIContext().animateTo({
      duration: TgUiTokens.DICE_ROLL_DURATION_MS,
      delay: TgUiTokens.DICE_ROLL_DURATION_MS,
      curve: Curve.EaseInOut
    }, () => {
      this.rollScale = 1;
      this.rollRotation = 0;
    });
    this.shownValue = this.value;
  }

  private displayEmoji(): string {
    return this.emoji.length > 0 ? this.emoji : '🎲';
  }

  build() {
    Column() {
      Text(this.displayEmoji())
        .fontSize(TgUiTokens.DICE_EMOJI_SIZE)
        .scale({ x: this.rollScale, y: this.rollScale })
        .rotate({ angle: this.rollRotation })
      if (this.value > 0) {
        Text('🎲 ' + this.value.toString())
          .fontSize(TgUiTokens.DICE_VALUE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .padding({
            left: TgUiTokens.DICE_VALUE_BADGE_PADDING_H,
            right: TgUiTokens.DICE_VALUE_BADGE_PADDING_H,
            top: TgUiTokens.DICE_VALUE_BADGE_PADDING_V,
            bottom: TgUiTokens.DICE_VALUE_BADGE_PADDING_V
          })
          .backgroundColor(TgUiTokens.COLOR_DICE_VALUE_BADGE_BG)
          .borderRadius(TgUiTokens.DICE_VALUE_BADGE_RADIUS)
          .margin({ top: TgUiTokens.SPACE_4 })
      }
    }
    .alignItems(HorizontalAlign.Center)
    .padding(TgUiTokens.DICE_BUBBLE_PADDING)
  }
}
