// PasswordInputPage — экран ввода пароля 2FA
// HarmonyOS Guidelines: $r() для локализации, Image для иконок, animateTo для анимаций

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { MonkeyAnimation } from '../../components/login/MonkeyAnimation';
import { SolidRoundedButton, ButtonState } from '../../components/login/SolidRoundedButton';
import { LoginController, CheckPasswordFailure } from '../../controllers/LoginController';
import { curves } from '@kit.ArkUI';
import { getString } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0041;
const TAG = 'PasswordInputPage';

@ComponentV2
export struct PasswordInputPage {
  // Стабильный id поля ввода пароля — цель автофокуса при появлении шага.
  private static readonly PASSWORD_INPUT_ID: string = 'login_password_input';

  @Param hint: string = '';
  @Param suggestReset: boolean = false;
  @Event onPasswordAccepted: () => void = (): void => {};
  @Event onBackToPhone: () => void = (): void => {};

  @Local private password: string = '';
  @Local private isPasswordVisible: boolean = false;
  @Local private buttonState: ButtonState = 'default';
  @Local private errorMessage: string = '';
  @Local private shakeOffset: number = 0;

  @Local private didForgotWithNoRecovery: boolean = false;
  @Local private showResetOption: boolean = false;

  private pageLifecycleToken: number = 0;
  private shakeAnimationSerial: number = 0;
  private passwordSubmitRequestSerial: number = 0;
  private forgotPasswordRequestSerial: number = 0;

  private isCurrentPasswordContinuation(scheduledToken: number): boolean {
    return scheduledToken === this.pageLifecycleToken;
  }

  private isCurrentShakeAnimation(scheduledToken: number, scheduledSerial: number): boolean {
    return this.isCurrentPasswordContinuation(scheduledToken) && scheduledSerial === this.shakeAnimationSerial;
  }

  private isCurrentPasswordSubmitRequest(scheduledToken: number, scheduledSerial: number): boolean {
    return this.isCurrentPasswordContinuation(scheduledToken) && scheduledSerial === this.passwordSubmitRequestSerial;
  }

  private isCurrentForgotPasswordRequest(scheduledToken: number, scheduledSerial: number): boolean {
    return this.isCurrentPasswordContinuation(scheduledToken) && scheduledSerial === this.forgotPasswordRequestSerial;
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.shakeAnimationSerial += 1;
    this.passwordSubmitRequestSerial += 1;
    this.forgotPasswordRequestSerial += 1;
    this.shakeOffset = 0;
    this.buttonState = 'default';
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 0 }) {
          // Monkey animation
          MonkeyAnimation({
            screen: 'password',
            isPasswordVisible: this.isPasswordVisible
          })
            .margin({ top: TgUiTokens.LOGIN_SPACING_MONKEY_TOP })

          // Title
          Text($r('app.string.two_step_title'))
            .fontSize(TgUiTokens.LOGIN_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TgUiTokens.LOGIN_TITLE_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_SPACING_TITLE_TOP })

          // Subtitle
          Text($r('app.string.login_two_step_protected'))
            .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
            .fontColor(TgUiTokens.LOGIN_SUBTITLE_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_SPACING_TITLE_TOP })

          // ─── Password Field ───
          Column({ space: 0 }) {
            Row() {
              TextInput({
                text: this.password,
                placeholder: this.getPasswordPlaceholder()
              })
                .id(PasswordInputPage.PASSWORD_INPUT_ID)
                .layoutWeight(1)
                .height(TgUiTokens.LOGIN_TEXT_INPUT_HEIGHT)
                .fontSize(TgUiTokens.LOGIN_INPUT_FONT_SIZE)
                .fontColor(TgUiTokens.LOGIN_INPUT_TEXT_COLOR)
                .placeholderColor(TgUiTokens.LOGIN_INPUT_PLACEHOLDER_COLOR)
                .backgroundColor(Color.Transparent)
                .type(this.isPasswordVisible ? InputType.Normal : InputType.Password)
                .padding({ left: 0, right: 0 })
                .onChange((value: string) => {
                  this.password = value;
                  this.errorMessage = '';
                })
                .onSubmit(() => { this.submitPassword(); })

              // Toggle password visibility — Image вместо эмодзи
              Image(this.isPasswordVisible ? TgUiTokens.ICON_RES_EYE : TgUiTokens.ICON_RES_EYE_OFF)
                .width(TgUiTokens.ICON_SIZE_LG)
                .height(TgUiTokens.ICON_SIZE_LG)
                .fillColor(TgUiTokens.COLOR_ICON_SECONDARY)
                .margin({ left: TgUiTokens.LOGIN_EYE_ICON_MARGIN_H, right: TgUiTokens.LOGIN_EYE_ICON_MARGIN_H })
                .onClick(() => {
                  this.isPasswordVisible = !this.isPasswordVisible;
                })
            }
            .width('100%')

            // Separator
            Divider()
              .width('100%')
              .strokeWidth(TgUiTokens.LOGIN_SEPARATOR_STROKE)
              .color(TgUiTokens.LOGIN_SEPARATOR_COLOR)
          }
          .padding({ left: TgUiTokens.LOGIN_SIDE_INSET, right: TgUiTokens.LOGIN_SIDE_INSET })
          .margin({ top: TgUiTokens.LOGIN_PASSWORD_FIELD_TOP })
          .offset({ x: this.shakeOffset })

          // Error message
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(TgUiTokens.LOGIN_ERROR_SIZE)
              .fontColor(TgUiTokens.LOGIN_ERROR_COLOR)
              .textAlign(TextAlign.Center)
              .margin({ top: TgUiTokens.LOGIN_SPACING_ERROR_TOP })
              .padding({ left: TgUiTokens.LOGIN_SIDE_INSET, right: TgUiTokens.LOGIN_SIDE_INSET })
          }

          // ─── Forgot Password ───
          Text($r('app.string.login_forgot_password'))
            .fontSize(TgUiTokens.LOGIN_FORGOT_LINK_SIZE)
            .fontColor(TgUiTokens.LOGIN_LINK_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_FORGOT_LINK_TOP })
            .onClick(() => { this.handleForgot(); })

          // ─── Reset Account ───
          if (this.showResetOption || this.suggestReset) {
            Text($r('app.string.login_reset_account'))
              .fontSize(TgUiTokens.LOGIN_FORGOT_LINK_SIZE)
              .fontColor(TgUiTokens.LOGIN_ERROR_COLOR)
              .textAlign(TextAlign.Center)
              .margin({ top: TgUiTokens.LOGIN_SPACING_MONKEY_TOP })
              .onClick(() => { this.handleReset(); })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: TgUiTokens.LOGIN_MAX_WIDTH })
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
        left: TgUiTokens.LOGIN_SIDE_INSET,
        right: TgUiTokens.LOGIN_SIDE_INSET,
        bottom: TgUiTokens.LOGIN_SIDE_INSET
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.LOGIN_BG)
    .onAppear(() => { this.focusPasswordInput(); })
  }

  // Фокусирует поле пароля и поднимает софт-клавиатуру при появлении шага.
  private focusPasswordInput(): void {
    try {
      this.getUIContext().getFocusController().requestFocus(PasswordInputPage.PASSWORD_INPUT_ID);
    } catch (e) {
      // requestFocus бросает, если узел ещё не готов — не критично для UX.
    }
  }

  // ─── Submit Password ───
  private async submitPassword(): Promise<void> {
    if (this.password.length === 0) return;
    const requestToken: number = this.pageLifecycleToken;
    this.passwordSubmitRequestSerial += 1;
    const requestSerial: number = this.passwordSubmitRequestSerial;
    this.buttonState = 'progress';
    this.errorMessage = '';

    const controller = LoginController.getInstance();
    const result = await controller.checkPassword(this.password);

    if (!this.isCurrentPasswordSubmitRequest(requestToken, requestSerial)) {
      return;
    }
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
    const requestToken: number = this.pageLifecycleToken;
    this.forgotPasswordRequestSerial += 1;
    const requestSerial: number = this.forgotPasswordRequestSerial;
    const controller = LoginController.getInstance();
    const result = await controller.requestPasswordRecovery();
    if (!this.isCurrentForgotPasswordRequest(requestToken, requestSerial)) {
      return;
    }

    if (result.success) {
      // Recovery flow page is not ported yet — avoid dead tap with explicit fallback state.
      this.didForgotWithNoRecovery = true;
      this.showResetOption = true;
      this.errorMessage = this.getRecoveryUnavailableMessage();
    } else {
      this.didForgotWithNoRecovery = true;
      this.showResetOption = true;
      this.errorMessage = this.getRecoveryUnavailableMessage();
    }
  }

  // ─── Reset Account ───
  private handleReset(): void {
    // Temporary fallback until full reset flow is ported.
    this.onBackToPhone();
  }

  // ─── Shake Animation (HarmonyOS: animateTo with spring curve) ───
  private animateShake(): void {
    const uiContext = this.getUIContext();
    if (!uiContext) return;
    const animationToken: number = this.pageLifecycleToken;
    this.shakeAnimationSerial += 1;
    const animationSerial: number = this.shakeAnimationSerial;
    uiContext.keyframeAnimateTo({ iterations: 1 }, [
      {
        duration: 100,
        curve: Curve.Linear,
        event: () => {
          if (!this.isCurrentShakeAnimation(animationToken, animationSerial)) {
            return;
          }
          this.shakeOffset = 12;
        }
      },
      {
        duration: 100,
        curve: Curve.Linear,
        event: () => {
          if (!this.isCurrentShakeAnimation(animationToken, animationSerial)) {
            return;
          }
          this.shakeOffset = -12;
        }
      },
      {
        duration: 100,
        curve: Curve.Linear,
        event: () => {
          if (!this.isCurrentShakeAnimation(animationToken, animationSerial)) {
            return;
          }
          this.shakeOffset = 12;
        }
      },
      {
        duration: 100,
        curve: Curve.Linear,
        event: () => {
          if (!this.isCurrentShakeAnimation(animationToken, animationSerial)) {
            return;
          }
          this.shakeOffset = 0;
        }
      }
    ]);
  }

  // ─── Helper Methods ───
  private getPasswordPlaceholder(): string {
    try {
      return this.hint.length > 0 ? this.hint : getString($r('app.string.password_placeholder').id);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to get password placeholder: %{public}s', String(e));
      return 'Password';
    }
  }

  private getContinueTitle(): string {
    try {
      return getString($r('app.string.login_continue').id);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to get continue title: %{public}s', String(e));
      return 'Continue';
    }
  }

  private getRecoveryUnavailableMessage(): string {
    try {
      return getString($r('app.string.login_recovery_unavailable').id);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to get recovery message: %{public}s', String(e));
      return 'Password recovery unavailable';
    }
  }
}
