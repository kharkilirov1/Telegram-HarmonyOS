// PasswordInputPage — экран ввода пароля 2FA
// HarmonyOS Guidelines: $r() для локализации, Image для иконок, animateTo для анимаций

import { TgColor, TgSize, TgIcon } from '../../theme/TelegramTheme';
import { MonkeyAnimation } from '../../components/login/MonkeyAnimation';
import { SolidRoundedButton, ButtonState } from '../../components/login/SolidRoundedButton';
import { LoginController, CheckPasswordFailure } from '../../controllers/LoginController';
import { curves } from '@kit.ArkUI';
import { getString } from '../../../core/utils/AppResource';

@Component
export struct PasswordInputPage {
  @Prop hint: string = '';
  @Prop suggestReset: boolean = false;
  onPasswordAccepted: () => void = (): void => {};
  onBackToPhone: () => void = (): void => {};

  @State private password: string = '';
  @State private isPasswordVisible: boolean = false;
  @State private buttonState: ButtonState = 'default';
  @State private errorMessage: string = '';
  @State private shakeOffset: number = 0;

  @State private didForgotWithNoRecovery: boolean = false;
  @State private showResetOption: boolean = false;

  build() {
    Column() {
      Scroll() {
        Column({ space: 0 }) {
          // Monkey animation
          MonkeyAnimation({
            screen: 'password',
            isPasswordVisible: this.isPasswordVisible
          })
            .margin({ top: 10 })

          // Title
          Text($r('app.string.two_step_title'))
            .fontSize($r('app.float.font_size_title_large'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
            .margin({ top: 18 })

          // Subtitle
          Text($r('app.string.login_two_step_protected'))
            .fontSize($r('app.float.font_size_headline'))
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
            .margin({ top: 18 })

          // ─── Password Field ───
          Column({ space: 0 }) {
            Row() {
              TextInput({
                text: this.password,
                placeholder: this.getPasswordPlaceholder()
              })
                .layoutWeight(1)
                .height(44)
                .fontSize(TgSize.INPUT_FONT)
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_secondary'))
                .backgroundColor(Color.Transparent)
                .type(this.isPasswordVisible ? InputType.Normal : InputType.Password)
                .padding({ left: 0, right: 0 })
                .onChange((value: string) => {
                  this.password = value;
                  this.errorMessage = '';
                })
                .onSubmit(() => { this.submitPassword(); })

              // Toggle password visibility — Image вместо эмодзи
              Image(this.isPasswordVisible ? TgIcon.EYE : TgIcon.EYE_OFF)
                .width(24)
                .height(24)
                .fillColor($r('app.color.text_secondary'))
                .margin({ left: 10, right: 10 })
                .onClick(() => {
                  this.isPasswordVisible = !this.isPasswordVisible;
                })
            }
            .width('100%')

            // Separator
            Divider()
              .width('100%')
              .strokeWidth(0.5)
              .color($r('app.color.separator'))
          }
          .padding({ left: TgSize.SIDE_INSET, right: TgSize.SIDE_INSET })
          .margin({ top: 32 })
          .offset({ x: this.shakeOffset })

          // Error message
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor($r('app.color.error_red'))
              .textAlign(TextAlign.Center)
              .margin({ top: 12 })
              .padding({ left: TgSize.SIDE_INSET, right: TgSize.SIDE_INSET })
          }

          // ─── Forgot Password ───
          Text($r('app.string.login_forgot_password'))
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
            .textAlign(TextAlign.Center)
            .margin({ top: 48 })
            .onClick(() => { this.handleForgot(); })

          // ─── Reset Account ───
          if (this.showResetOption || this.suggestReset) {
            Text($r('app.string.login_reset_account'))
              .fontSize(16)
              .fontColor($r('app.color.error_red'))
              .textAlign(TextAlign.Center)
              .margin({ top: 10 })
              .onClick(() => { this.handleReset(); })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: TgSize.MAX_WIDTH })
      }
      .layoutWeight(1)

      // ─── Continue Button ───
      Column() {
        SolidRoundedButton({
          title: this.getContinueTitle(),
          isEnabled: this.password.length > 0,
          buttonState: this.buttonState,
          onPress: (): void => { this.submitPassword(); }
        })
      }
      .width('100%')
      .padding({
        left: TgSize.SIDE_INSET,
        right: TgSize.SIDE_INSET,
        bottom: TgSize.SIDE_INSET
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_primary'))
  }

  // ─── Submit Password ───
  private async submitPassword(): Promise<void> {
    if (this.password.length === 0) return;
    this.buttonState = 'progress';
    this.errorMessage = '';

    const controller = LoginController.getInstance();
    const result = await controller.checkPassword(this.password);

    if (result.success) {
      this.buttonState = 'default';
      this.onPasswordAccepted();
    } else {
      this.buttonState = 'default';
      const failure = result as CheckPasswordFailure;
      this.errorMessage = failure.error.message;
      this.animateShake();
      this.password = '';
    }
  }

  // ─── Forgot Password ───
  private async handleForgot(): Promise<void> {
    const controller = LoginController.getInstance();
    const result = await controller.requestPasswordRecovery();

    if (result.success) {
      // TODO: navigate to password recovery screen
    } else {
      this.didForgotWithNoRecovery = true;
      this.showResetOption = true;
      this.errorMessage = this.getRecoveryUnavailableMessage();
    }
  }

  // ─── Reset Account ───
  private handleReset(): void {
    // TODO: показать AlertDialog с подтверждением
  }

  // ─── Shake Animation (HarmonyOS: animateTo with spring curve) ───
  private animateShake(): void {
    const uiContext = this.getUIContext();
    if (!uiContext) return;
    uiContext.keyframeAnimateTo({ iterations: 1 }, [
      {
        duration: 100,
        curve: Curve.Linear,
        event: () => { this.shakeOffset = 12; }
      },
      {
        duration: 100,
        curve: Curve.Linear,
        event: () => { this.shakeOffset = -12; }
      },
      {
        duration: 100,
        curve: Curve.Linear,
        event: () => { this.shakeOffset = 12; }
      },
      {
        duration: 100,
        curve: Curve.Linear,
        event: () => { this.shakeOffset = 0; }
      }
    ]);
  }

  // ─── Helper Methods ───
  private getPasswordPlaceholder(): string {
    try {
      return this.hint.length > 0 ? this.hint : getString($r('app.string.password_placeholder').id);
    } catch (e) {
      console.error('Failed to get password placeholder:', String(e));
      return 'Password';
    }
  }

  private getContinueTitle(): string {
    try {
      return getString($r('app.string.login_continue').id);
    } catch (e) {
      console.error('Failed to get continue title:', String(e));
      return 'Continue';
    }
  }

  private getRecoveryUnavailableMessage(): string {
    try {
      return getString($r('app.string.login_recovery_unavailable').id);
    } catch (e) {
      console.error('Failed to get recovery message:', String(e));
      return 'Password recovery unavailable';
    }
  }
}
