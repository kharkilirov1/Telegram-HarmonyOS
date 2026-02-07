import { AuthController } from '../../controllers/AuthController';

@Component
export struct VerifyCodePage {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @Prop phoneNumber: string = '';
  @State code: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';

  build() {
    NavDestination() {
      Column() {
        // Back button area
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
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

        // Icon
        Image($r('app.media.app_icon'))
          .width(80)
          .height(80)
          .margin({ top: 40, bottom: 24 })

        // Title
        Text('Enter Code')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        // Subtitle with phone number
        Text(`We've sent a code to ${this.phoneNumber}`)
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: 32 })
          .padding({ left: 32, right: 32 })

        // Code input
        TextInput({ placeholder: $r('app.string.code_placeholder'), text: this.code })
          .type(InputType.Number)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .maxLength(6)
          .width('60%')
          .height(56)
          .backgroundColor($r('app.color.background_secondary'))
          .borderRadius(10)
          .onChange((value: string) => {
            this.code = value;
            this.errorMessage = '';
            // Auto-submit when 5 digits entered
            if (value.length >= 5) {
              this.submitCode();
            }
          })

        // Error message
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(Color.Red)
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
          .enabled(!this.isLoading && this.code.length >= 5)
          .onClick(() => {
            this.submitCode();
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

  private async submitCode(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    this.errorMessage = '';

    try {
      await AuthController.getInstance().submitCode(this.code);
    } catch (e) {
      this.errorMessage = 'Invalid code. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }
}
