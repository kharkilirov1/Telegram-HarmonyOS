import { AuthController } from '../../controllers/AuthController';
import { ChatService } from '../../services/ChatService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TelegramMascot, MascotState } from '../../components/Common/TelegramMascot';

@Builder
export function LoginPasswordBuilder() {
  PasswordPage()
}

@ComponentV2
export struct PasswordPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local password: string = '';
  @Local isLoading: boolean = false;
  @Local errorMessage: string = '';
  @Local passwordHint: string = '';
  @Local showPassword: boolean = false;
  @Local mascotState: MascotState = MascotState.CLOSE;
  @Local showRecoveryView: boolean = false;
  @Local recoveryCode: string = '';
  @Local recoveryEmailPattern: string = '';
  @Local recoveryMessage: string = '';

  aboutToAppear(): void {
    this.passwordHint = AuthController.getInstance().getPasswordHint();
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

        // Animated mascot — closes eyes for password, peeks when toggled
        TelegramMascot({ mascotState: this.mascotState, mascotSize: 120 })
          .margin({ bottom: 12 })

        // Title
        Text($r('app.string.two_step_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        // Subtitle
        Text($r('app.string.two_step_subtitle'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .padding({ left: 40, right: 40 })
          .margin({ bottom: 32 })

        // Password input with show/hide toggle (like both platforms)
        Row() {
          TextInput({ placeholder: $r('app.string.password_placeholder'), text: this.password })
            .type(this.showPassword ? InputType.Normal : InputType.Password)
            .fontSize(20)
            .layoutWeight(1)
            .height(48)
            .backgroundColor(Color.Transparent)
            .caretColor($r('app.color.telegram_blue'))
            .onChange((value: string) => {
              this.password = value;
              this.errorMessage = '';
            })
            .onFocus(() => {
              // Monkey closes eyes when password field is focused
              if (!this.showPassword) {
                this.mascotState = MascotState.CLOSE;
              }
            })
            .onSubmit(() => {
              if (this.password.length > 0) {
                this.submitPassword();
              }
            })

          // Show/hide password toggle — monkey peeks / closes eyes
          Image(this.showPassword ? $r('app.media.ic_close') : $r('app.media.ic_search'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.text_secondary'))
            .margin({ right: 12 })
            .onClick(() => {
              this.showPassword = !this.showPassword;
              if (this.showPassword) {
                // Monkey peeks through fingers
                this.mascotState = MascotState.PEEK;
              } else {
                // Monkey closes eyes again
                this.mascotState = MascotState.CLOSE_AND_PEEK;
              }
            })
        }
        .width('80%')
        .height(48)
        .backgroundColor($r('app.color.background_secondary'))
        .borderRadius(10)
        .padding({ left: 12 })

        // Hint (like real Telegram)
        if (this.passwordHint.length > 0) {
          Text(this.formatHint())
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 12 })
        }

        // Error message
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor($r('app.color.error_red'))
            .margin({ top: 8 })
        }

        if (this.isLoading) {
          LoadingProgress()
            .width(32)
            .height(32)
            .margin({ top: 20 })
            .color($r('app.color.telegram_blue'))
        }

        // "Forgot Password?" link (like real Telegram)
        Text($r('app.string.login_forgot_password'))
          .fontSize(14)
          .fontColor($r('app.color.telegram_blue'))
          .margin({ top: 24 })
          .onClick(() => { this.requestPasswordRecovery(); })

        Blank()

        // Continue button at bottom center (like iOS Telegram)
        if (this.password.length > 0 && !this.isLoading) {
          Button($r('app.string.next_button'))
            .type(ButtonType.Capsule)
            .width('90%')
            .height(50)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('app.color.telegram_blue'))
            .fontColor(Color.White)
            .margin({ bottom: 16 })
            .onClick(() => this.submitPassword())
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

      // --- Password recovery overlay ---
      if (this.showRecoveryView) {
        Column() {
          // Top bar: Back button only
          Row() {
            Image($r('app.media.ic_back'))
              .width(24).height(24)
              .fillColor($r('app.color.telegram_blue'))
              .padding(12)
              .onClick(() => {
                this.showRecoveryView = false;
                this.recoveryCode = '';
                this.errorMessage = '';
              })

            Blank()
          }
          .width('100%')
          .height(48)
          .padding({ left: 4, right: 16 })

          Blank().height(32)

          // Email icon
          Image($r('app.media.ic_email'))
            .width(80).height(80)
            .fillColor($r('app.color.telegram_blue'))
            .margin({ bottom: 24 })

          Text($r('app.string.recovery_title'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: 8 })

          Text(this.recoveryMessage.length > 0
            ? this.recoveryMessage
            : getContext(this).resourceManager.getStringByNameSync('recovery_subtitle'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .padding({ left: 40, right: 40 })
            .margin({ bottom: 8 })

          if (this.recoveryEmailPattern.length > 0) {
            Text(this.recoveryEmailPattern)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 32 })
          }

          // Recovery code input
          TextInput({ placeholder: $r('app.string.recovery_code_placeholder'), text: this.recoveryCode })
            .type(InputType.Number)
            .fontSize(20)
            .width('70%')
            .height(48)
            .backgroundColor($r('app.color.background_secondary'))
            .borderRadius(10)
            .textAlign(TextAlign.Center)
            .caretColor($r('app.color.telegram_blue'))
            .onChange((value: string) => {
              this.recoveryCode = value;
              this.errorMessage = '';
            })
            .onSubmit(() => {
              if (this.recoveryCode.length > 0) {
                this.submitRecoveryCode();
              }
            })

          // Error
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor($r('app.color.error_red'))
              .margin({ top: 12 })
          }

          if (this.isLoading) {
            LoadingProgress()
              .width(32).height(32)
              .margin({ top: 20 })
              .color($r('app.color.telegram_blue'))
          }

          Blank()

          // Continue button at bottom center
          if (this.recoveryCode.length > 0 && !this.isLoading) {
            Button($r('app.string.next_button'))
              .type(ButtonType.Capsule)
              .width('90%')
              .height(50)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .backgroundColor($r('app.color.telegram_blue'))
              .fontColor(Color.White)
              .margin({ bottom: 16 })
              .onClick(() => { this.submitRecoveryCode(); })
              .transition(TransitionEffect.OPACITY.combine(
                TransitionEffect.scale({ x: 0.95, y: 0.95 })
              ).animation({ duration: 200, curve: Curve.EaseOut }))
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.background_primary'))
        .alignItems(HorizontalAlign.Center)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }
    }
    .hideTitleBar(true)
  }

  private async submitPassword(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';

    try {
      await AuthController.getInstance().submitPassword(this.password);
    } catch (e) {
      this.errorMessage = getContext(this).resourceManager.getStringByNameSync('error_wrong_password');
    } finally {
      this.isLoading = false;
    }
  }

  private async requestPasswordRecovery(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';

    try {
      const result: Record<string, unknown> = await ChatService.getInstance().requestAuthPasswordRecovery();
      // TDLib responds with emailAddressAuthenticationCodeInfo
      this.recoveryEmailPattern = (result['email_address_pattern'] as string) || '';
      if (this.recoveryEmailPattern.length > 0) {
        const template = getContext(this).resourceManager.getStringByNameSync('code_sent_to');
        this.recoveryMessage = template.replace('%s', this.recoveryEmailPattern);
      } else {
        this.recoveryMessage = getContext(this).resourceManager.getStringByNameSync('recovery_subtitle');
      }
      this.showRecoveryView = true;
    } catch (e) {
      hilog.warn(0x0001, 'PasswordPage', 'Failed to request password recovery');
      // If no recovery email is set, TDLib will return error
      AlertDialog.show({
        title: getContext(this).resourceManager.getStringByNameSync('recovery_no_email_title'),
        message: getContext(this).resourceManager.getStringByNameSync('recovery_no_email_message'),
        buttons: [
          { value: getContext(this).resourceManager.getStringByNameSync('done'), action: () => {} }
        ]
      });
    } finally {
      this.isLoading = false;
    }
  }

  private async submitRecoveryCode(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';

    try {
      await ChatService.getInstance().recoverAuthPassword(this.recoveryCode);
      // On success, auth state transitions to Ready
      this.showRecoveryView = false;
    } catch (e) {
      hilog.warn(0x0001, 'PasswordPage', 'Failed to recover authentication password');
      this.errorMessage = getContext(this).resourceManager.getStringByNameSync('recovery_invalid_code');
    } finally {
      this.isLoading = false;
    }
  }

  private formatHint(): string {
    const template = getContext(this).resourceManager.getStringByNameSync('hint_prefix');
    return template.replace('%s', this.passwordHint);
  }
}
