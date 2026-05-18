// CodeInputPage — экран ввода кода подтверждения
// HarmonyOS Guidelines: $r() для локализации, animateTo для анимаций

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { MonkeyAnimation } from '../../components/login/MonkeyAnimation';
import { CodeInputView, CodeInputType } from '../../components/login/CodeInputView';
import { SolidRoundedButton, ButtonState } from '../../components/login/SolidRoundedButton';
import { LoginController, CheckCodeFailure, SendCodeFailure, CodeType } from '../../controllers/LoginController';
import { curves } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { getString } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0040;
const TAG = 'CodeInputPage';

@ComponentV2
export struct CodeInputPage {
  @Param phoneNumber: string = '';
  @Param codeType: CodeType = 'sms';
  @Param codeLength: number = 5;
  @Param nextType: CodeType | null = null;
  @Param timeout: number = 60;
  @Event onCodeAccepted: () => void = (): void => {};
  @Event onWrongNumber: () => void = (): void => {};

  @Local private code: string = '';
  @Local private buttonState: ButtonState = 'default';
  @Local private errorMessage: string = '';
  @Local private remainingTime: number = 60;
  @Local private resendTimer: number = -1;
  @Local private shakeOffset: number = 0;

  private pageLifecycleToken: number = 0;
  private shakeAnimationSerial: number = 0;
  private codeSubmitRequestSerial: number = 0;
  private resendRequestSerial: number = 0;

  private isCurrentCodeContinuation(scheduledToken: number): boolean {
    return scheduledToken === this.pageLifecycleToken;
  }

  private isCurrentShakeAnimation(scheduledToken: number, scheduledSerial: number): boolean {
    return this.isCurrentCodeContinuation(scheduledToken) && scheduledSerial === this.shakeAnimationSerial;
  }

  private isCurrentCodeSubmitRequest(scheduledToken: number, scheduledSerial: number): boolean {
    return this.isCurrentCodeContinuation(scheduledToken) && scheduledSerial === this.codeSubmitRequestSerial;
  }

  private isCurrentResendRequest(scheduledToken: number, scheduledSerial: number): boolean {
    return this.isCurrentCodeContinuation(scheduledToken) && scheduledSerial === this.resendRequestSerial;
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.remainingTime = this.timeout;
    this.startCountdown();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.shakeAnimationSerial += 1;
    this.codeSubmitRequestSerial += 1;
    this.resendRequestSerial += 1;
    this.shakeOffset = 0;
    this.buttonState = 'default';
    this.stopCountdown();
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 0 }) {
          // Monkey animation
          MonkeyAnimation({ screen: 'code' })
            .margin({ top: TgUiTokens.LOGIN_SPACING_MONKEY_TOP })

          // Title
          Text(this.getTitleForType())
            .fontSize(TgUiTokens.LOGIN_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TgUiTokens.LOGIN_TITLE_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_SPACING_TITLE_TOP })

          // Description
          Text(this.getDescriptionForType())
            .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
            .fontColor(TgUiTokens.LOGIN_SUBTITLE_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_SPACING_TITLE_TOP })
            .padding({ left: TgUiTokens.LOGIN_SIDE_INSET, right: TgUiTokens.LOGIN_SIDE_INSET })

          // ─── Code Input ───
          Column() {
            CodeInputView({
              codeLength: this.codeLength,
              inputType: this.getInputType(),
              code: this.code,
              onCodeChange: (val: string): void => { this.code = val; },
              onComplete: (code: string): void => { this.submitCode(code); },
              onTextChanged: (_text: string): void => {
                this.errorMessage = '';
              }
            })
          }
          .margin({ top: TgUiTokens.LOGIN_SPACING_COUNTRY_TOP })
          .offset({ x: this.shakeOffset })

          // Error text
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(TgUiTokens.LOGIN_ERROR_SIZE)
              .fontColor(TgUiTokens.LOGIN_ERROR_COLOR)
              .textAlign(TextAlign.Center)
              .margin({ top: TgUiTokens.LOGIN_SPACING_ERROR_TOP })
              .padding({ left: TgUiTokens.LOGIN_SIDE_INSET, right: TgUiTokens.LOGIN_SIDE_INSET })
          }

          // ─── Fragment Link ───
          if (this.codeType === 'fragment') {
            Text($r('app.string.login_open_fragment'))
              .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
              .fontColor(TgUiTokens.LOGIN_LINK_COLOR)
              .margin({ top: TgUiTokens.SPACE_16 })
              .onClick(() => {
                this.openFragmentWebsite();
              })
          }

          // ─── Next Option / Resend ───
          Text(this.getNextOptionText())
            .fontSize(TgUiTokens.LOGIN_LINK_SIZE)
            .fontColor(this.remainingTime > 0 ? TgUiTokens.LOGIN_INPUT_PLACEHOLDER_COLOR : TgUiTokens.LOGIN_LINK_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_RESEND_LINK_TOP })
            .onClick(() => {
              if (this.remainingTime <= 0) {
                this.requestResend();
              }
            })
            .enabled(this.remainingTime <= 0)

          // ─── Wrong Number? ───
          Text($r('app.string.login_wrong_number'))
            .fontSize(TgUiTokens.LOGIN_LINK_SIZE)
            .fontColor(TgUiTokens.LOGIN_LINK_COLOR)
            .margin({ top: TgUiTokens.SPACE_16 })
            .onClick(() => { this.onWrongNumber(); })
        }
        .width('100%')
        .constraintSize({ maxWidth: TgUiTokens.LOGIN_MAX_WIDTH })
      }
      .layoutWeight(1)

      // ─── Proceed Button (for word/phrase only) ───
      if (this.codeType === 'word' || this.codeType === 'phrase') {
        Column() {
          SolidRoundedButton({
            title: this.getContinueTitle(),
            isEnabled: this.code.length > 0,
            buttonState: this.buttonState,
            onPress: (): void => { this.submitCode(this.code); }
          })
        }
        .width('100%')
        .padding({
          left: TgUiTokens.LOGIN_SIDE_INSET,
          right: TgUiTokens.LOGIN_SIDE_INSET,
          bottom: TgUiTokens.LOGIN_SIDE_INSET
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.LOGIN_BG)
  }

  // ─── Submit ───
  private async submitCode(code: string): Promise<void> {
    if (code.length === 0) return;
    const requestToken: number = this.pageLifecycleToken;
    this.codeSubmitRequestSerial += 1;
    const requestSerial: number = this.codeSubmitRequestSerial;
    this.buttonState = 'progress';
    this.errorMessage = '';

    const controller = LoginController.getInstance();
    const result = await controller.checkCode(code);

    if (!this.isCurrentCodeSubmitRequest(requestToken, requestSerial)) {
      return;
    }
    if (result.success) {
      this.buttonState = 'default';
      this.onCodeAccepted();
    } else {
      this.buttonState = 'default';
      const failure = result as CheckCodeFailure;
      this.errorMessage = failure.error.message;
      this.animateShake();
      if (failure.error.code === 'CODE_INVALID' || failure.error.code === 'FLOOD_WAIT') {
        this.code = '';
      }
    }
  }

  // ─── Resend ───
  private async requestResend(): Promise<void> {
    const requestToken: number = this.pageLifecycleToken;
    this.resendRequestSerial += 1;
    const requestSerial: number = this.resendRequestSerial;
    const controller = LoginController.getInstance();
    const result = await controller.resendCode();
    if (!this.isCurrentResendRequest(requestToken, requestSerial)) {
      return;
    }
    if (result.success) {
      this.remainingTime = this.timeout;
      this.startCountdown();
    } else {
      const failure = result as SendCodeFailure;
      this.errorMessage = failure.error.message;
      hilog.warn(DOMAIN, TAG, 'resendCode failed: code=%{public}s msg=%{public}s',
        failure.error.code, failure.error.message);
      if (failure.error.retryAfter > 0) {
        this.remainingTime = failure.error.retryAfter;
        this.startCountdown();
      }
    }
  }

  // ─── Timer ───
  // Note: setInterval приемлем для UI countdown — корректно очищается в aboutToDisappear().
  // При уходе в background таймер замораживается, что ОК для UX.
  private startCountdown(): void {
    this.stopCountdown();
    const timerToken: number = this.pageLifecycleToken;
    const timerId: number = setInterval(() => {
      if (!this.isCurrentCodeContinuation(timerToken) || this.resendTimer !== timerId) {
        clearInterval(timerId);
        return;
      }
      this.remainingTime--;
      if (this.remainingTime <= 0) {
        this.remainingTime = 0;
        this.stopCountdown();
      }
    }, 1000);
    this.resendTimer = timerId;
  }

  private stopCountdown(): void {
    if (this.resendTimer !== -1) {
      clearInterval(this.resendTimer);
      this.resendTimer = -1;
    }
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

  private openFragmentWebsite(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: 'https://fragment.com'
      };
      const abilityToken: number = this.pageLifecycleToken;
      context.startAbility(want)
        .catch((error: Object) => {
          if (!this.isCurrentCodeContinuation(abilityToken)) {
            return;
          }
          hilog.error(DOMAIN, TAG, 'Failed to open fragment.com: %{public}s', String(error));
        });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to build browser want: %{public}s', String(error));
    }
  }

  // ─── Helpers ───
  private getInputType(): CodeInputType {
    if (this.codeType === 'word') return 'word';
    if (this.codeType === 'phrase') return 'phrase';
    return 'numeric';
  }

  private getTitleForType(): string {
    try {
      if (this.codeType === 'email') return getString($r('app.string.login_check_email').id);
      if (this.codeType === 'word') return getString($r('app.string.login_enter_code_word').id);
      if (this.codeType === 'phrase') return getString($r('app.string.login_enter_code_phrase').id);
      return this.phoneNumber;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to get title for type: %{public}s', String(e));
      return this.phoneNumber;
    }
  }

  private getDescriptionForType(): string {
    try {
      // Для строк с параметрами используем шаблон
      if (this.codeType === 'sms') {
        const template: string = getString($r('app.string.login_sms_sent').id);
        return template.replace('%s', this.phoneNumber);
      }
      if (this.codeType === 'call') {
        const template: string = getString($r('app.string.login_call_sent').id);
        return template.replace('%s', this.phoneNumber);
      }
      if (this.codeType === 'otherSession') {
        return getString($r('app.string.login_check_telegram').id);
      }
      if (this.codeType === 'missedCall') {
        const template: string = getString($r('app.string.login_missed_call').id);
        return template.replace('%s', this.phoneNumber);
      }
      if (this.codeType === 'fragment') {
        const template: string = getString($r('app.string.login_fragment_sent').id);
        return template.replace('%s', this.phoneNumber);
      }
      if (this.codeType === 'email') {
        return getString($r('app.string.login_email_sent').id);
      }
      if (this.codeType === 'word') {
        return getString($r('app.string.login_code_word_sent').id);
      }
      if (this.codeType === 'phrase') {
        return getString($r('app.string.login_code_phrase_sent').id);
      }
      const template: string = getString($r('app.string.login_code_sent_generic').id);
      return template.replace('%s', this.phoneNumber);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to get description for type: %{public}s', String(e));
      return '';
    }
  }

  private getNextOptionText(): string {
    try {
      if (this.remainingTime > 0) {
        const min: number = Math.floor(this.remainingTime / 60);
        const sec: number = this.remainingTime % 60;
        const timeStr: string = `${min}:${sec.toString().padStart(2, '0')}`;

        if (this.nextType === 'call') {
          const template: string = getString($r('app.string.login_request_call_in').id);
          return template.replace('%s', timeStr);
        }
        if (this.nextType === 'sms') {
          const template: string = getString($r('app.string.login_resend_sms_in').id);
          return template.replace('%s', timeStr);
        }
        const template: string = getString($r('app.string.login_resend_code_in').id);
        return template.replace('%s', timeStr);
      }

      if (this.nextType === 'call') return getString($r('app.string.login_request_call').id);
      if (this.nextType === 'sms') return getString($r('app.string.login_resend_sms').id);
      return getString($r('app.string.login_didnt_get_code').id);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to get next option text: %{public}s', String(e));
      return '';
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
}
