// PhoneInputPage — экран ввода номера телефона
// HarmonyOS Guidelines: использует $r() для локализации и ресурсов

import { TgColor, TgSize, TgColorRes, TgIcon } from '../../theme/TelegramTheme';
import { MonkeyAnimation } from '../../components/login/MonkeyAnimation';
import { SolidRoundedButton, ButtonState } from '../../components/login/SolidRoundedButton';
import { LoginController, SendCodeFailure } from '../../controllers/LoginController';
import { CountryService, CountryInfo } from '../../services/CountryService';
import { i18n } from '@kit.LocalizationKit';
import { LengthMetrics } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { getString } from '../../../core/utils/AppResource';

// PopInfo interface для навигации (HarmonyOS API 12+)
interface PopInfo {
  info: NavPathInfo;
  result: Object;
}

interface NavPathInfo {
  name: string;
}

@Component
export struct PhoneInputPage {
  onPhoneSent: () => void = (): void => {};

  // Выбираем pageStack из AppStorage вместо упавшего @Consume
  private pageStack: NavPathStack = AppStorage.get<NavPathStack>('pageStack') as NavPathStack;

  @State private countryCode: string = '+7';
  @State private countryFlag: string = 'RU';
  @State private countryName: string = 'Russia';
  @State private phoneNumber: string = '';
  @State private buttonState: ButtonState = 'default';
  @State private errorMessage: string = '';
  @State private hasNumber: boolean = false;
  @State private isCountriesLoaded: boolean = false;

  async aboutToAppear(): Promise<void> {
    try {
      await CountryService.loadCountries();
    } catch (e) {
      console.error('Failed to load countries:', String(e));
    }
    this.isCountriesLoaded = true;
    // Set default country from loaded data
    const defaultCountry = CountryService.getCountryByCode('RU');
    if (defaultCountry) {
      this.setCountry(defaultCountry);
    }
  }

  build() {
    Column() {
      // Scrollable content area
      Scroll() {
        Column({ space: 0 }) {
          // Monkey animation
          MonkeyAnimation({ screen: 'phone' })
            .margin({ top: 10 })

          // Title — локализованная строка
          Text($r('app.string.login_your_phone'))
            .fontSize($r('app.float.font_size_title_large'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
            .margin({ top: 18 })

          // Subtitle — локализованная строка
          Text($r('app.string.login_confirm_text'))
            .fontSize($r('app.float.font_size_headline'))
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
            .margin({ top: 18 })

          // ─── Country Button ───
          Column() {
            Row() {
              // Country name with flag prefix
              Text(`${this.getCountryFlagEmoji()} ${this.countryName}`)
                .fontSize(20)
                .fontColor($r('app.color.telegram_blue'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              // Disclosure arrow — используем иконку вместо символа
              Image(TgIcon.ARROW_RIGHT)
                .width(20)
                .height(20)
                .fillColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .height(57)
            .padding({ start: LengthMetrics.vp(TgSize.SIDE_INSET), end: LengthMetrics.vp(TgSize.SIDE_INSET) })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              try {
                this.pageStack.pushPathByName('CountrySelectPage', null, (popInfo: PopInfo) => {
                  if (popInfo.result) {
                    const country = popInfo.result as CountryInfo;
                    this.setCountry(country);
                  }
                });
              } catch (error) {
                console.error('Failed to navigate to CountrySelectPage:', error);
              }
            })

            // Separator
            Divider()
              .width('calc(100% - 16vp)')
              .strokeWidth(0.5)
              .color($r('app.color.separator'))
              .margin({ start: LengthMetrics.vp(TgSize.SIDE_INSET) })
          }
          .margin({ top: 30 })

          // ─── Phone Input Row ───
          Row() {
            // Country code field
            TextInput({ text: this.countryCode })
              .width(71)
              .height(57)
              .fontSize(TgSize.INPUT_FONT)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .padding({ start: LengthMetrics.vp(18) })
              .type(InputType.PhoneNumber)
              .onChange((value: string) => {
                this.countryCode = value;
                this.updateCountryFromCode(value);
              })

            // Vertical separator
            Column()
              .width(0.5)
              .height(32)
              .backgroundColor($r('app.color.separator'))
              .margin({ start: LengthMetrics.vp(0), end: LengthMetrics.vp(16) })

            // Phone number field
            TextInput({ text: this.phoneNumber, placeholder: this.getPhonePlaceholder() })
              .layoutWeight(1)
              .height(57)
              .fontSize(TgSize.INPUT_FONT)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_secondary'))
              .backgroundColor(Color.Transparent)
              .type(InputType.PhoneNumber)
              .onChange((value: string) => {
                this.phoneNumber = value;
                this.hasNumber = value.length > 0;
                this.errorMessage = '';
              })
              .onSubmit(() => { this.handleNext(); })
          }
          .width('100%')
          .padding({ end: LengthMetrics.vp(TgSize.SIDE_INSET) })

          // Separator under phone input
          Divider()
            .width('calc(100% - 16vp)')
            .strokeWidth(0.5)
            .color($r('app.color.separator'))
            .margin({ start: LengthMetrics.vp(TgSize.SIDE_INSET) })

          // Error message
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor($r('app.color.error_red'))
              .textAlign(TextAlign.Center)
              .margin({ top: 12 })
              .padding({ start: LengthMetrics.vp(TgSize.SIDE_INSET), end: LengthMetrics.vp(TgSize.SIDE_INSET) })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: TgSize.MAX_WIDTH })
      }
      .layoutWeight(1)

      // ─── Continue Button ───
      Column() {
        SolidRoundedButton({
          title: this.getContinueTitle(),
          isEnabled: this.hasNumber,
          buttonState: this.buttonState,
          onPress: (): void => { this.handleNext(); }
        })
      }
      .width('100%')
      .padding({
        start: LengthMetrics.vp(TgSize.SIDE_INSET),
        end: LengthMetrics.vp(TgSize.SIDE_INSET),
        bottom: LengthMetrics.vp(TgSize.SIDE_INSET)
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_primary'))
  }

  private handleNext(): void {
    if (!this.hasNumber) return;
    this.sendPhone();
  }

  private async sendPhone(): Promise<void> {
    this.buttonState = 'progress';
    this.errorMessage = '';

    const digits = this.countryCode.replace('+', '') + this.phoneNumber.replace(/\D/g, '');

    // Клиентская валидация телефона через HarmonyOS i18n API
    let isValidNumber = false;
    try {
      const format = new i18n.PhoneNumberFormat(this.countryFlag);
      isValidNumber = format.isValidNumber(digits);
    } catch (e) {
      // Если i18n API недоступен, используем базовую валидацию
      const phoneRegex = /^[1-9]\d{7,14}$/; // Базовая проверка: 8-15 цифр, начинается не с 0
      isValidNumber = phoneRegex.test(digits.replace(/\D/g, ''));
    }

    if (!isValidNumber) {
      this.buttonState = 'default';
      this.errorMessage = getString($r('app.string.invalid_phone_format').id);
      return;
    }

    const controller = LoginController.getInstance();
    const result = await controller.sendPhoneNumber('+' + digits);

    if (result.success) {
      this.buttonState = 'default';
      this.onPhoneSent();
    } else {
      this.buttonState = 'default';
      const failure = result as SendCodeFailure;
      this.errorMessage = failure.error.message;
    }
  }

  private updateCountryFromCode(code: string): void {
    if (!this.isCountriesLoaded) return;

    const country = CountryService.findCountryByDialCode(code);
    if (country) {
      this.countryFlag = country.code;
      this.countryName = this.getLocalizedCountryName(country);
    } else {
      this.countryFlag = '';
      this.countryName = this.getSelectCountryTitle();
    }
  }

  private setCountry(country: CountryInfo): void {
    this.countryCode = country.dialCode;
    this.countryFlag = country.code;
    this.countryName = this.getLocalizedCountryName(country);
  }

  private getLocalizedCountryName(country: CountryInfo): string {
    // Check system locale, simplified due to getContext().config deprecation.
    // In HarmonyOS use i18n APIs if needed. Default to 'en' or match.
    // A simple implementation without getContext()
    const locale = 'en'; // Can be retrieved correctly using I18n kit later.
    return CountryService.getLocalizedName(country, locale);
  }

  // Получить эмодзи флага из кода страны (ISO 3166-1 alpha-2)
  private getCountryFlagEmoji(): string {
    return CountryService.getCountryFlagEmoji(this.countryFlag);
  }

  // ─── Helper Methods ───
  private getPhonePlaceholder(): string {
    try {
      return getString($r('app.string.phone_placeholder').id);
    } catch (e) {
      console.error('Failed to get phone placeholder:', String(e));
      return 'Phone number';
    }
  }

  private getContinueTitle(): string {
    try {
      return getString($r('app.string.login_continue').id);
    } catch (e) {
      console.error('Failed to get continue title:', String(e));
      return 'Continue';
    }
  }

  private getSelectCountryTitle(): string {
    try {
      return getString($r('app.string.select_country').id);
    } catch (e) {
      console.error('Failed to get select country title:', String(e));
      return 'Select a country';
    }
  }
}
