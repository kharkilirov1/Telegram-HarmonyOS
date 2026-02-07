import { TDLibClient } from '../../services/TDLibClient';

@Component
export struct PhoneNumberPage {
  @Consume('navPathStack') navPathStack: NavPathStack;
  @State phoneNumber: string = '';
  @State countryCode: string = '+7';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';

  build() {
    NavDestination() {
      Column() {
        // Logo area
        Image($r('app.media.app_icon'))
          .width(96)
          .height(96)
          .margin({ top: 80, bottom: 24 })

        // Title
        Text($r('app.string.login_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        // Subtitle
        Text($r('app.string.login_subtitle'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: 40 })
          .textAlign(TextAlign.Center)

        // Country code + phone input
        Row() {
          // Country code selector
          Text(this.countryCode)
            .fontSize(17)
            .fontColor($r('app.color.text_primary'))
            .padding({ left: 16, right: 12 })
            .height(48)
            .backgroundColor($r('app.color.background_secondary'))
            .borderRadius({ topLeft: 10, bottomLeft: 10 })

          // Phone number input
          TextInput({ placeholder: $r('app.string.phone_placeholder'), text: this.phoneNumber })
            .type(InputType.PhoneNumber)
            .fontSize(17)
            .layoutWeight(1)
            .height(48)
            .backgroundColor($r('app.color.background_secondary'))
            .borderRadius({ topRight: 10, bottomRight: 10 })
            .onChange((value: string) => {
              this.phoneNumber = value;
              this.errorMessage = '';
            })
        }
        .width('100%')
        .padding({ left: 32, right: 32 })

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
          .margin({ top: 32 })
          .enabled(!this.isLoading && this.phoneNumber.length > 0)
          .onClick(() => {
            this.submitPhoneNumber();
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

  private async submitPhoneNumber(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';

    const fullNumber = this.countryCode + this.phoneNumber;

    try {
      await TDLibClient.getInstance().setPhoneNumber(fullNumber);
      // Navigation to code page happens via updateAuthorizationState handler
      // in Index.ets, but we can also push directly:
      this.navPathStack.pushPath({ name: 'LoginCode', param: fullNumber });
    } catch (e) {
      this.errorMessage = 'Failed to send code. Please try again.';
    } finally {
      this.isLoading = false;
    }
  }
}
