// SolidRoundedButton — широкая кнопка Continue
// HarmonyOS Guidelines: animateTo для анимаций, Image для иконок, $r() для ресурсов

import { TgColor, TgSize, TgIcon } from '../../theme/TelegramTheme';
import { curves } from '@kit.ArkUI';

export type ButtonState = 'default' | 'progress' | 'success';

@Component
export struct SolidRoundedButton {
  @Prop title: string = 'Continue';
  @Prop isEnabled: boolean = true;
  @Prop buttonState: ButtonState = 'default';
  onPress: () => void = (): void => {};

  @State private btnScale: number = 1.0;

  build() {
    Button() {
      if (this.buttonState === 'progress') {
        // Spinner внутри кнопки
        LoadingProgress()
          .width(24)
          .height(24)
          .color(Color.White)
      } else if (this.buttonState === 'success') {
        // Галочка — Image вместо эмодзи
        Image(TgIcon.CHECK)
          .width(24)
          .height(24)
          .fillColor(Color.White)
      } else {
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isEnabled ? Color.White : $r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .height(TgSize.BUTTON_HEIGHT)
    .borderRadius(TgSize.BUTTON_RADIUS)
    .backgroundColor(this.isEnabled ? $r('app.color.telegram_blue') : $r('app.color.separator'))
    .enabled(this.isEnabled && this.buttonState === 'default')
    .scale({ x: this.btnScale, y: this.btnScale })
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
