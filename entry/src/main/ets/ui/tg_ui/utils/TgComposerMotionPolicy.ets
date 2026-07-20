import { TgUiTokens } from '../tokens/TgUiTokens';

export function composerPopupTransition(): TransitionEffect {
  const enter = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.COMPOSER_POPUP_ENTER_MS, curve: Curve.EaseOut })
    .combine(TransitionEffect.translate({ y: TgUiTokens.COMPOSER_POPUP_OFFSET_Y })
      .animation({ duration: TgUiTokens.COMPOSER_POPUP_ENTER_MS, curve: Curve.Smooth }))
    .combine(TransitionEffect.scale({
      x: TgUiTokens.COMPOSER_POPUP_ENTER_SCALE,
      y: TgUiTokens.COMPOSER_POPUP_ENTER_SCALE
    }).animation({ duration: TgUiTokens.COMPOSER_POPUP_ENTER_MS, curve: Curve.Smooth }));

  const exit = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.COMPOSER_POPUP_EXIT_MS, curve: Curve.EaseIn })
    .combine(TransitionEffect.translate({ y: TgUiTokens.COMPOSER_POPUP_OFFSET_Y })
      .animation({ duration: TgUiTokens.COMPOSER_POPUP_EXIT_MS, curve: Curve.EaseIn }))
    .combine(TransitionEffect.scale({
      x: TgUiTokens.COMPOSER_POPUP_EXIT_SCALE,
      y: TgUiTokens.COMPOSER_POPUP_EXIT_SCALE
    }).animation({ duration: TgUiTokens.COMPOSER_POPUP_EXIT_MS, curve: Curve.EaseIn }));

  return TransitionEffect.asymmetric(enter, exit);
}

export function composerMenuLabelTransition(): TransitionEffect {
  const enter = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.COMPOSER_LAYOUT_TRANSITION_MS, curve: Curve.EaseOut })
    .combine(TransitionEffect.translate({ x: -TgUiTokens.COMPOSER_MENU_LABEL_SHIFT })
      .animation({ duration: TgUiTokens.COMPOSER_LAYOUT_TRANSITION_MS, curve: Curve.Smooth }));
  const exit = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.COMPOSER_LAYOUT_TRANSITION_MS - 40, curve: Curve.EaseIn })
    .combine(TransitionEffect.translate({ x: -TgUiTokens.COMPOSER_MENU_LABEL_SHIFT })
      .animation({ duration: TgUiTokens.COMPOSER_LAYOUT_TRANSITION_MS - 40, curve: Curve.EaseIn }));
  return TransitionEffect.asymmetric(enter, exit);
}
