// CodeInputPage — экран ввода кода подтверждения
// HarmonyOS Guidelines: $r() для локализации, animateTo для анимаций

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { MonkeyAnimation } from '../../components/login/MonkeyAnimation';
import { CodeInputView, CodeInputType } from '../../components/login/CodeInputView';
import { SolidRoundedButton, ButtonState } from '../../components/login/SolidRoundedButton';
import { LoginController, CheckCodeFailure, CodeType } from '../../controllers/LoginController';
import { curves } from '@kit.ArkUI';
import { getString } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0040;
const TAG = 'CodeInputPage';

@Component
export struct CodeInputPage {
  @Prop phoneNumber: string = '';
  @Prop codeType: CodeType = 'sms';
  @Prop codeLength: number = 5;
  @Prop nextType: CodeType | null = null;
  @Prop timeout: number = 60;
  onCodeAccepted: () => void = (): void => {};
  onWrongNumber: () => void = (): void => {};

  @State private code: string = '';
  @State private buttonState: ButtonState = 'default';
  @State private errorMessage: string = '';
  @State private remainingTime: number = 60;
  @State private resendTimer: number = -1;
  @State private shakeOffset: number = 0;

  aboutToAppear(): void {
    this.remainingTime = this.timeout;
    this.startCountdown();
  }

  aboutToDisappear(): void {
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
              code: $code,
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
                // TODO: open fragment.com URL
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
    this.buttonState = 'progress';
    this.errorMessage = '';

    const controller = LoginController.getInstance();
    const result = await controller.checkCode(code);

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
    const controller = LoginController.getInstance();
    const result = await controller.resendCode();
    if (result.success) {
      this.remainingTime = this.timeout;
      this.startCountdown();
    }
  }

  // ─── Timer ───
  // Note: setInterval приемлем для UI countdown — корректно очищается в aboutToDisappear().
  // При уходе в background таймер замораживается, что ОК для UX.
  private startCountdown(): void {
    this.stopCountdown();
    this.resendTimer = setInterval(() => {
      this.remainingTime--;
      if (this.remainingTime <= 0) {
        this.remainingTime = 0;
        this.stopCountdown();
      }
    }, 1000);
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
