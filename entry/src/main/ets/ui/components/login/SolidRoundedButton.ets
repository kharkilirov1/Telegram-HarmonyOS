// SolidRoundedButton — широкая кнопка Continue
// HarmonyOS Guidelines: animateTo для анимаций, Image для иконок, $r() для ресурсов

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { curves } from '@kit.ArkUI';

export type ButtonState = 'default' | 'progress' | 'success';

@ComponentV2
export struct SolidRoundedButton {
  @Param title: string = 'Continue';
  @Param isEnabled: boolean = true;
  @Param buttonState: ButtonState = 'default';
  @Event onPress: () => void = (): void => {};

  @Local private btnScale: number = 1.0;

  build() {
    Button() {
      if (this.buttonState === 'progress') {
        // Spinner внутри кнопки
        LoadingProgress()
          .width(TgUiTokens.ICON_SIZE_LG)
          .height(TgUiTokens.ICON_SIZE_LG)
          .color(TgUiTokens.LOGIN_BUTTON_SPINNER_COLOR)
      } else if (this.buttonState === 'success') {
        // Галочка — Image вместо эмодзи
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
    .scale({ x: this.btnScale, y: this.btnScale })
    .accessibilityGroup(true)
    .accessibilityDescription(this.buttonState === 'progress' ? 'Loading' : (this.buttonState === 'success' ? 'Success' : this.title))
    .onClick(() => {
      this.animatePress();
      this.onPress();
    })
  }

  // Пружинная анимация согласно гайдлайнам HarmonyOS API 22
  private animatePress(): void {
    // Анимация сжатия
    this.getUIContext()?.animateTo({
      curve: curves.springMotion(0.5, 0.8)
    }, () => {
      this.btnScale = 0.95;
    });

    // Анимация возврата
    setTimeout(() => {
      this.getUIContext()?.animateTo({
        curve: curves.springMotion(0.4, 0.6)
      }, () => {
        this.btnScale = 1.0;
      });
    }, 100);
  }
}
