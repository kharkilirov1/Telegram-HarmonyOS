// TgBubbleTail — iOS-style tail attached to the last bubble of a sender group.
// Placed as a Row sibling of the bubble (flat edge flush against it); the
// negative margin at the call site keeps the bubble column aligned with
// tailless rows. Path commands are in px, hence vp2px at build time.

import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgBubbleTail {
  @Param isOutgoing: boolean = false;

  private tailColor(): ResourceColor {
    return this.isOutgoing
      ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG
      : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private tailCommands(): string {
    const w = vp2px(TgUiTokens.BUBBLE_TAIL_WIDTH);
    const h = vp2px(TgUiTokens.BUBBLE_TAIL_HEIGHT);
    if (this.isOutgoing) {
      // Flat LEFT edge flush against the bubble, tip pointing bottom-right
      return `M0 0 L0 ${h} L${w} ${h} Q${w * 0.25} ${h * 0.9} 0 ${h * 0.35} Z`;
    }
    // Flat RIGHT edge flush against the bubble, tip pointing bottom-left
    return `M${w} 0 L${w} ${h} L0 ${h} Q${w * 0.75} ${h * 0.9} ${w} ${h * 0.35} Z`;
  }

  build() {
    Path()
      .width(TgUiTokens.BUBBLE_TAIL_WIDTH)
      .height(TgUiTokens.BUBBLE_TAIL_HEIGHT)
      .commands(this.tailCommands())
      .fill(this.tailColor())
      .strokeWidth(0)
      .antiAlias(true)
  }
}
