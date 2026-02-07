import { AuthController } from '../../controllers/AuthController';

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

  aboutToAppear(): void {
    this.passwordHint = AuthController.getInstance().getPasswordHint();
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar: Back + "Next"
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Blank()

          if (this.password.length > 0 && !this.isLoading) {
            Text($r('app.string.next_button'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.telegram_blue'))
              .onClick(() => this.submitPassword())
          }
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })

        Blank().height(40)

        // Lock icon (like real Telegram — would be monkey animation in real app)
        Image($r('app.media.ic_lock'))
          .width(80)
          .height(80)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ bottom: 20 })

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
            .fontSize(17)
            .layoutWeight(1)
            .height(48)
            .backgroundColor(Color.Transparent)
            .caretColor($r('app.color.telegram_blue'))
            .onChange((value: string) => {
              this.password = value;
              this.errorMessage = '';
            })
            .onSubmit(() => {
              if (this.password.length > 0) {
                this.submitPassword();
              }
            })

          // Show/hide password toggle
          Image(this.showPassword ? $r('app.media.ic_close') : $r('app.media.ic_search'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.text_secondary'))
            .margin({ right: 12 })
            .onClick(() => {
              this.showPassword = !this.showPassword;
            })
        }
        .width('80%')
        .height(48)
        .backgroundColor($r('app.color.background_secondary'))
        .borderRadius(10)
        .padding({ left: 12 })

        // Hint (like real Telegram)
        if (this.passwordHint.length > 0) {
          Text(`Hint: ${this.passwordHint}`)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 12 })
        }

        // Error message
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
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
          .onClick(() => {
            // TODO: password recovery flow
          })

        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
      .alignItems(HorizontalAlign.Center)
    }
    .hideTitleBar(true)
  }

  private async submitPassword(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';

    try {
      await AuthController.getInstance().submitPassword(this.password);
    } catch (e) {
      this.errorMessage = 'Wrong password. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }
}
