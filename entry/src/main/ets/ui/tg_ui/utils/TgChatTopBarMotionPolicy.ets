import { TgUiTokens } from '../tokens/TgUiTokens';

export function chatTopBarContentTransition(): TransitionEffect {
  const enter = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.CHAT_TOP_BAR_MOTION_MS, curve: Curve.EaseOut })
    .combine(TransitionEffect.scale({
      x: TgUiTokens.CHAT_TOP_BAR_MOTION_SCALE,
      y: TgUiTokens.CHAT_TOP_BAR_MOTION_SCALE
    }).animation({ duration: TgUiTokens.CHAT_TOP_BAR_MOTION_MS, curve: Curve.Smooth }));

  const exit = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.CHAT_TOP_BAR_MOTION_EXIT_MS, curve: Curve.EaseIn })
    .combine(TransitionEffect.scale({
      x: TgUiTokens.CHAT_TOP_BAR_MOTION_SCALE,
      y: TgUiTokens.CHAT_TOP_BAR_MOTION_SCALE
    }).animation({ duration: TgUiTokens.CHAT_TOP_BAR_MOTION_EXIT_MS, curve: Curve.EaseIn }));

  return TransitionEffect.asymmetric(enter, exit);
}
