import { AuthController } from '../../controllers/AuthController';
import { TelegramMascot, MascotState } from '../../components/Common/TelegramMascot';

@Builder
export function LoginCodeBuilder(name: string, param: Object) {
  VerifyCodePage({ phoneNumber: (param as string) || '' })
}

@ComponentV2
export struct VerifyCodePage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param phoneNumber: string = '';
  @Local code: string = '';
  @Local isLoading: boolean = false;
  @Local errorMessage: string = '';
  @Local resendTimer: number = 60;
  @Local mascotState: MascotState = MascotState.IDLE;
  private timerInterval: number = -1;

  aboutToAppear(): void {
    this.startResendTimer();
  }

  aboutToDisappear(): void {
    if (this.timerInterval >= 0) {
      clearInterval(this.timerInterval);
    }
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar: Back button only
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .padding(12)
            .onClick(() => this.navPathStack.pop())

          Blank()
        }
        .width('100%')
        .height(48)
        .padding({ left: 4, right: 16 })

        Blank().height(12)

        // Animated mascot — tracks code input (like real Telegram)
        TelegramMascot({ mascotState: this.mascotState, mascotSize: 120 })
          .margin({ bottom: 12 })

        // Title
        Text($r('app.string.enter_code_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        // Subtitle with phone number
        Text($r('app.string.code_sent_to', this.phoneNumber))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: 8 })
          .padding({ left: 40, right: 40 })

        // "Wrong number?" link (like real Telegram)
        Text($r('app.string.login_wrong_number'))
          .fontSize(14)
          .fontColor($r('app.color.telegram_blue'))
          .margin({ bottom: 32 })
          .onClick(() => this.navPathStack.pop())

        // Code input — large centered digits (like both platforms)
        TextInput({ placeholder: '_ _ _ _ _', text: this.code })
          .type(InputType.Number)
          .fontSize(28)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .maxLength(6)
          .width('60%')
          .height(56)
          .backgroundColor($r('app.color.background_secondary'))
          .borderRadius(10)
          .caretColor($r('app.color.telegram_blue'))
          .onChange((value: string) => {
            this.code = value;
            this.errorMessage = '';
            // Mascot tracks code input — switches to tracking when typing
            this.mascotState = value.length > 0 ? MascotState.TRACKING : MascotState.IDLE;
            if (value.length >= 5) {
              this.submitCode();
            }
          })
          .onFocus(() => {
            this.mascotState = this.code.length > 0 ? MascotState.TRACKING : MascotState.IDLE;
          })

        // Error message
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor($r('app.color.error_red'))
            .margin({ top: 12 })
        }

        if (this.isLoading) {
          LoadingProgress()
            .width(32)
            .height(32)
            .margin({ top: 20 })
            .color($r('app.color.telegram_blue'))
        }

        // Resend timer (like real Telegram)
        if (this.resendTimer > 0) {
          Text($r('app.string.login_resend_code', `0:${this.resendTimer.toString().padStart(2, '0')}`))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 24 })
        } else {
          Text($r('app.string.login_resend_code'))
            .fontSize(14)
            .fontColor($r('app.color.telegram_blue'))
            .margin({ top: 24 })
            .onClick(() => {
              this.resendAuthCode();
            })
        }

        Blank()

        // Continue button at bottom center (like iOS Telegram)
        if (this.code.length >= 5 && !this.isLoading) {
          Button($r('app.string.next_button'))
            .type(ButtonType.Capsule)
            .width('90%')
            .height(50)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('app.color.telegram_blue'))
            .fontColor(Color.White)
            .margin({ bottom: 16 })
            .onClick(() => this.submitCode())
            .transition(TransitionEffect.OPACITY.combine(
              TransitionEffect.scale({ x: 0.95, y: 0.95 })
            ).animation({ duration: 200, curve: Curve.EaseOut }))
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .alignItems(HorizontalAlign.Center)
    }
    .hideTitleBar(true)
  }

  private async submitCode(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    this.errorMessage = '';

    try {
      await AuthController.getInstance().submitCode(this.code);
    } catch (e) {
      this.errorMessage = getContext(this).resourceManager.getStringByNameSync('error_invalid_code');
    } finally {
      this.isLoading = false;
    }
  }

  private async resendAuthCode(): Promise<void> {
    try {
      await AuthController.getInstance().resendCode();
      this.resendTimer = 60;
      this.startResendTimer();
    } catch (e) {
      this.errorMessage = getContext(this).resourceManager.getStringByNameSync('error_send_code');
    }
  }

  private startResendTimer(): void {
    if (this.timerInterval >= 0) {
      clearInterval(this.timerInterval);
    }
    this.timerInterval = setInterval(() => {
      this.resendTimer--;
      if (this.resendTimer <= 0) {
        clearInterval(this.timerInterval);
        this.timerInterval = -1;
      }
    }, 1000);
  }
}
