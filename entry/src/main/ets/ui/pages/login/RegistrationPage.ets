// RegistrationPage — экран регистрации (authorizationStateWaitRegistration)
// Новые пользователи Telegram: firstName обязательно, lastName опционально.
// registerUser → TDLib → auth переходит в ready.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { MonkeyAnimation } from '../../components/login/MonkeyAnimation';
import { SolidRoundedButton, ButtonState } from '../../components/login/SolidRoundedButton';
import { LoginController, RegisterUserFailure } from '../../controllers/LoginController';
import { LengthMetrics } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0043;
const TAG = 'RegistrationPage';

@ComponentV2
export struct RegistrationPage {
  @Event onRegistered: () => void = (): void => {};

  @Local private firstName: string = '';
  @Local private lastName: string = '';
  @Local private buttonState: ButtonState = 'default';
  @Local private errorMessage: string = '';
  @Local private isLoading: boolean = false;

  build() {
    Column() {
      Scroll() {
        Column({ space: 0 }) {
          MonkeyAnimation({ screen: 'phone' })
            .margin({ top: TgUiTokens.LOGIN_SPACING_MONKEY_TOP })

          Text('Your Name')
            .fontSize(TgUiTokens.LOGIN_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TgUiTokens.LOGIN_TITLE_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_SPACING_TITLE_TOP })

          Text('Enter your name and add\na profile photo')
            .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
            .fontColor(TgUiTokens.LOGIN_SUBTITLE_COLOR)
            .textAlign(TextAlign.Center)
            .lineHeight(22)
            .margin({ top: TgUiTokens.LOGIN_SPACING_TITLE_TOP })

          // ─── First Name ───
          Column({ space: 0 }) {
            TextInput({
              text: this.firstName,
              placeholder: 'First Name'
            })
              .width('100%')
              .height(TgUiTokens.LOGIN_INPUT_ROW_HEIGHT)
              .fontSize(TgUiTokens.LOGIN_INPUT_FONT_SIZE)
              .fontColor(TgUiTokens.LOGIN_INPUT_TEXT_COLOR)
              .placeholderColor(TgUiTokens.LOGIN_INPUT_PLACEHOLDER_COLOR)
              .backgroundColor(Color.Transparent)
              .padding({ left: 0, right: 0 })
              .onChange((value: string) => {
                this.firstName = value;
                this.errorMessage = '';
              })
              .onSubmit(() => { this.handleRegister(); })

            Divider()
              .width('100%')
              .strokeWidth(TgUiTokens.LOGIN_SEPARATOR_STROKE)
              .color(TgUiTokens.LOGIN_SEPARATOR_COLOR)
          }
          .padding({
            start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET),
            end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET)
          })
          .margin({ top: TgUiTokens.LOGIN_SPACING_COUNTRY_TOP })

          // ─── Last Name (optional) ───
          Column({ space: 0 }) {
            TextInput({
              text: this.lastName,
              placeholder: 'Last Name (optional)'
            })
              .width('100%')
              .height(TgUiTokens.LOGIN_INPUT_ROW_HEIGHT)
              .fontSize(TgUiTokens.LOGIN_INPUT_FONT_SIZE)
              .fontColor(TgUiTokens.LOGIN_INPUT_TEXT_COLOR)
              .placeholderColor(TgUiTokens.LOGIN_INPUT_PLACEHOLDER_COLOR)
              .backgroundColor(Color.Transparent)
              .padding({ left: 0, right: 0 })
              .onChange((value: string) => {
                this.lastName = value;
              })
              .onSubmit(() => { this.handleRegister(); })

            Divider()
              .width('100%')
              .strokeWidth(TgUiTokens.LOGIN_SEPARATOR_STROKE)
              .color(TgUiTokens.LOGIN_SEPARATOR_COLOR)
          }
          .padding({
            start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET),
            end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET)
          })
          .margin({ top: 0 })

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(TgUiTokens.LOGIN_ERROR_SIZE)
              .fontColor(TgUiTokens.LOGIN_ERROR_COLOR)
              .textAlign(TextAlign.Center)
              .margin({ top: TgUiTokens.LOGIN_SPACING_ERROR_TOP })
              .padding({
                start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET),
                end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET)
              })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: TgUiTokens.LOGIN_MAX_WIDTH })
      }
      .layoutWeight(1)

      // ─── Start Messaging Button ───
      Column() {
        SolidRoundedButton({
          title: 'Start Messaging',
          isEnabled: this.firstName.trim().length > 0 && !this.isLoading,
          buttonState: this.buttonState,
          onPress: (): void => { this.handleRegister(); }
        })
      }
      .width('100%')
      .padding({
        start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET),
        end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET),
        bottom: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET)
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.LOGIN_BG)
  }

  private handleRegister(): void {
    if (this.firstName.trim().length === 0 || this.isLoading) return;
    this.registerUser();
  }

  private async registerUser(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    this.buttonState = 'progress';
    this.errorMessage = '';

    const controller = LoginController.getInstance();
    const result = await controller.registerUser(this.firstName.trim(), this.lastName.trim());

    this.isLoading = false;

    if (result.success) {
      this.buttonState = 'default';
      hilog.info(DOMAIN, TAG, 'Registration successful');
      this.onRegistered();
    } else {
      this.buttonState = 'default';
      const failure = result as RegisterUserFailure;
      this.errorMessage = failure.error.message;
      hilog.warn(DOMAIN, TAG, 'Registration failed: %{public}s', failure.error.message);
    }
  }
}
