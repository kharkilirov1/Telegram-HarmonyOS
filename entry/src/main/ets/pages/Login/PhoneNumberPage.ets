import { AuthController } from '../../controllers/AuthController';

@ComponentV2
export struct PhoneNumberPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local phoneNumber: string = '';
  @Local countryCode: string = '+7';
  @Local countryName: string = 'Russia';
  @Local isLoading: boolean = false;
  @Local errorMessage: string = '';

  build() {
    NavDestination() {
      Column() {
        // Top bar with "Next" in top-right (like real Telegram iOS)
        Row() {
          Blank()
          if (this.phoneNumber.length > 0) {
            Text($r('app.string.next_button'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.telegram_blue'))
              .onClick(() => this.submitPhoneNumber())
          }
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })

        Blank().height(20)

        // Telegram logo — centered, like real Telegram login
        Image($r('app.media.app_icon'))
          .width(96)
          .height(96)
          .margin({ bottom: 20 })

        // Title — "Your Phone Number"
        Text($r('app.string.login_your_phone'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        // Subtitle
        Text($r('app.string.login_confirm_text'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 32 })
          .textAlign(TextAlign.Center)
          .padding({ left: 40, right: 40 })

        // Country selector row (like real Telegram)
        Column() {
          Row() {
            Text(this.countryName)
              .fontSize(17)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)

            Image($r('app.media.ic_forward'))
              .width(14)
              .height(14)
              .fillColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .height(48)
          .padding({ left: 20, right: 16 })
          .onClick(() => {
            // TODO: country picker
          })

          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 20 })

          // Country code + phone number input row (like real Telegram)
          Row() {
            // Country code
            Text(this.countryCode)
              .fontSize(17)
              .fontColor($r('app.color.text_primary'))
              .width(60)
              .textAlign(TextAlign.Center)

            Divider()
              .vertical(true)
              .strokeWidth(0.5)
              .color($r('app.color.separator'))
              .height(24)

            // Phone number input
            TextInput({ placeholder: $r('app.string.phone_placeholder'), text: this.phoneNumber })
              .type(InputType.PhoneNumber)
              .fontSize(17)
              .layoutWeight(1)
              .height(48)
              .backgroundColor(Color.Transparent)
              .padding({ left: 12 })
              .onChange((value: string) => {
                this.phoneNumber = value;
                this.errorMessage = '';
              })
              .onSubmit(() => {
                if (this.phoneNumber.length > 0) {
                  this.submitPhoneNumber();
                }
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: 8 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.background_secondary'))
        .borderRadius(10)
        .margin({ left: 16, right: 16 })

        // Error message
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor($r('app.color.error_red'))
            .margin({ top: 12 })
        }

        if (this.isLoading) {
          LoadingProgress()
            .width(32)
            .height(32)
            .margin({ top: 24 })
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

  private async submitPhoneNumber(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';

    const fullNumber = this.countryCode + this.phoneNumber;

    try {
      await AuthController.getInstance().submitPhoneNumber(fullNumber);
    } catch (e) {
      this.errorMessage = 'Failed to send code. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }
}
