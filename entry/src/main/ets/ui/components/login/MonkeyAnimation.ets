// MonkeyAnimation — Lottie обезьянка для экранов логина
// HarmonyOS Guidelines: использует @ohos/lottie для анимаций
//
// Анимации из rawfile/animations/:
// - monkey_idle.json — обезьянка сидит, смотрит прямо (phone screen)
// - monkey_tracking.json — следит за вводом (code screen)
// - monkey_close.json — закрывает глаза (password hidden)
// - monkey_peek.json — подглядывает (password visible)
// - monkey_close_and_peek.json — переход закрыто → подглядывание
// - monkey_close_peek_to_idle.json — переход подглядывание → закрыто

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import lottie, { AnimationItem } from '@ohos/lottie';

export type MonkeyScreen = 'phone' | 'code' | 'password';

// Пути к анимациям в rawfile
class AnimPath {
  static readonly idle: string = 'animations/monkey_idle.json';
  static readonly tracking: string = 'animations/monkey_tracking.json';
  static readonly close: string = 'animations/monkey_close.json';
  static readonly peek: string = 'animations/monkey_peek.json';
  static readonly closeAndPeek: string = 'animations/monkey_close_and_peek.json';
  static readonly closePeekToIdle: string = 'animations/monkey_close_peek_to_idle.json';
}

@ComponentV2
export struct MonkeyAnimation {
  @Param screen: MonkeyScreen = 'phone';
  @Param isPasswordVisible: boolean = false;
  @Param lastDigit: number = -1;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasController: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private animationItem: AnimationItem | null = null;
  private currentAnimation: string = '';
  @Local private periodicTimer: number = -1;

  aboutToAppear(): void {
    if (this.screen === 'password') {
      this.startPeriodicPeek();
    }
  }

  aboutToDisappear(): void {
    this.stopPeriodicPeek();
    this.destroyAnimation();
  }

  // ─── Lifecycle ───

  private onCanvasReady(): void {
    this.loadInitialAnimation();
  }

  private loadInitialAnimation(): void {
    let path: string;

    if (this.screen === 'phone') {
      path = AnimPath.idle;
    } else if (this.screen === 'code') {
      path = AnimPath.tracking;
    } else {
      // password
      path = this.isPasswordVisible ? AnimPath.peek : AnimPath.close;
    }

    this.playAnimation(path, this.screen !== 'password');
  }

  // ─── Animation Control ───

  private playAnimation(path: string, loop: boolean = false): void {
    if (this.currentAnimation === path && this.animationItem) {
      return;
    }

    this.destroyAnimation();
    this.currentAnimation = path;

    // В @ohos/lottie важно передавать имя анимации для безопасного управления
    const animName = this.currentAnimation;

    this.animationItem = lottie.loadAnimation({
      container: this.canvasController,
      renderer: 'canvas',
      name: animName,
      loop: loop,
      autoplay: true,
      path: path,
    });
  }

  private destroyAnimation(): void {
    if (this.currentAnimation) {
      // Уничтожаем конкретную анимацию по имени для безопасности
      lottie.destroy(this.currentAnimation);
    }
    this.animationItem = null;
    this.currentAnimation = '';
  }

  // ─── Password Visibility Changes ───

  @Monitor('isPasswordVisible')
  private onPasswordVisibilityChanged(monitor: IMonitor): void {
    if (this.screen !== 'password') return;

    if (this.isPasswordVisible) {
      // Переход к подглядыванию
      this.playAnimation(AnimPath.closeAndPeek, false);
    } else {
      // Переход к закрытым глазам
      this.playAnimation(AnimPath.closePeekToIdle, false);
    }
  }

  // ─── Code Input Tracking ───

  @Monitor('lastDigit')
  private onDigitChanged(monitor: IMonitor): void {
    if (this.screen !== 'code' || this.lastDigit < 0) return;

    // Tracking анимация — перематываем на позицию, соответствующую цифре
    if (this.animationItem && this.currentAnimation === AnimPath.tracking) {
      const totalFrames = this.animationItem.totalFrames || 60;
      const targetFrame = Math.floor((this.lastDigit / 5) * totalFrames);
      this.animationItem.goToAndStop(targetFrame, true);
    }
  }

  // ─── Periodic Peek (Password Screen) ───

  private startPeriodicPeek(): void {
    this.stopPeriodicPeek();
    // iOS: каждые 7.5 секунд обезьянка подглядывает
    this.periodicTimer = setInterval(() => {
      this.triggerPeekAnimation();
    }, 7500);
  }

  private stopPeriodicPeek(): void {
    if (this.periodicTimer !== -1) {
      clearInterval(this.periodicTimer);
      this.periodicTimer = -1;
    }
  }

  private triggerPeekAnimation(): void {
    if (this.screen !== 'password' || this.isPasswordVisible) return;

    // Кратковременно подглядываем
    this.playAnimation(AnimPath.closeAndPeek, false);

    // После завершения — возврат к закрытым глазам
    setTimeout(() => {
      if (!this.isPasswordVisible) {
        this.playAnimation(AnimPath.closePeekToIdle, false);
      }
    }, 1200);
  }

  build() {
    Canvas(this.canvasController)
      .width(TgUiTokens.LOGIN_MONKEY_SIZE)
      .height(TgUiTokens.LOGIN_MONKEY_SIZE)
      .backgroundColor(Color.Transparent)
      .onReady(() => {
        this.onCanvasReady();
      })
  }
}
