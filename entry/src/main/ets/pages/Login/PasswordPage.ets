import { AuthController } from '../../controllers/AuthController';

@Component
export struct PasswordPage {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @State password: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State passwordHint: string = '';

  build() {
    NavDestination() {
      Column() {
        // Back button
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => {
              this.navPathStack.pop();
            })
          Blank()
        }
        .width('100%')
        .padding({ left: 16, top: 12 })

        // Lock icon
        Image($r('app.media.ic_lock'))
          .width(80)
          .height(80)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ top: 40, bottom: 24 })

        // Title
        Text($r('app.string.two_step_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        // Subtitle
        Text($r('app.string.two_step_subtitle'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: 32 })

        // Password input
        TextInput({ placeholder: $r('app.string.password_placeholder'), text: this.password })
          .type(InputType.Password)
          .fontSize(17)
          .width('80%')
          .height(48)
          .backgroundColor($r('app.color.background_secondary'))
          .borderRadius(10)
          .onChange((value: string) => {
            this.password = value;
            this.errorMessage = '';
          })

        // Hint
        if (this.passwordHint.length > 0) {
          Text(`Hint: ${this.passwordHint}`)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
        }

        // Error message
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor($r('app.color.error_red'))
            .margin({ top: 8 })
        }

        // Next button
        Button($r('app.string.next_button'))
          .type(ButtonType.Capsule)
          .width('60%')
          .height(48)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('app.color.telegram_blue'))
          .margin({ top: 24 })
          .enabled(!this.isLoading && this.password.length > 0)
          .onClick(() => {
            this.submitPassword();
          })

        if (this.isLoading) {
          LoadingProgress()
            .width(32)
            .height(32)
            .margin({ top: 16 })
            .color($r('app.color.telegram_blue'))
        }

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
