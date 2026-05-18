// SolidRoundedButton — широкая кнопка Continue
// API 23: использует встроенный stateEffect Button вместо кастомной spring-анимации

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';

export type ButtonState = 'default' | 'progress' | 'success';

@ComponentV2
export struct SolidRoundedButton {
  @Param title: string = 'Continue';
  @Param isEnabled: boolean = true;
  @Param buttonState: ButtonState = 'default';
  @Event onPress: () => void = (): void => {};

  build() {
    Button() {
      if (this.buttonState === 'progress') {
        LoadingProgress()
          .width(TgUiTokens.ICON_SIZE_LG)
          .height(TgUiTokens.ICON_SIZE_LG)
          .color(TgUiTokens.LOGIN_BUTTON_SPINNER_COLOR)
      } else if (this.buttonState === 'success') {
        Image(TgUiTokens.ICON_RES_CHECK)
          .width(TgUiTokens.ICON_SIZE_LG)
          .height(TgUiTokens.ICON_SIZE_LG)
          .fillColor(TgUiTokens.LOGIN_BUTTON_TEXT_COLOR)
      } else {
        Text(this.title)
          .fontSize(TgUiTokens.LOGIN_BUTTON_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isEnabled ? TgUiTokens.LOGIN_BUTTON_TEXT_COLOR : TgUiTokens.LOGIN_BUTTON_DISABLED_TEXT_COLOR)
      }
    }
    .width('100%')
    .height(TgUiTokens.LOGIN_BUTTON_HEIGHT)
    .borderRadius(TgUiTokens.LOGIN_BUTTON_RADIUS)
    .backgroundColor(this.isEnabled ? TgUiTokens.LOGIN_BUTTON_BG : TgUiTokens.LOGIN_BUTTON_DISABLED_BG)
    .enabled(this.isEnabled && this.buttonState === 'default')
    .stateEffect(true) // Встроенный press-эффект Button (замена кастомной spring-анимации)
    .onClick(() => {
      this.onPress();
    })
  }
}
