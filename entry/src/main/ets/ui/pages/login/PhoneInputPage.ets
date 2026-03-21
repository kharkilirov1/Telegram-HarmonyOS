// PhoneInputPage — экран ввода номера телефона
// HarmonyOS Guidelines: использует $r() для локализации и ресурсов

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { MonkeyAnimation } from '../../components/login/MonkeyAnimation';
import { SolidRoundedButton, ButtonState } from '../../components/login/SolidRoundedButton';
import { LoginController, SendCodeFailure } from '../../controllers/LoginController';
import { CountryService, CountryInfo } from '../../services/CountryService';
import { i18n } from '@kit.LocalizationKit';
import { LengthMetrics } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { getString } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TgCountrySelectionScreen, TgCountryGroup } from '../../tg_ui/molecules/TgCountrySelectionScreen';

const DOMAIN = 0x0042;
const TAG = 'PhoneInputPage';

@ComponentV2
export struct PhoneInputPage {
  @Event onPhoneSent: () => void = (): void => {};

  @Local private countryCode: string = '+7';
  @Local private countryFlag: string = 'RU';
  @Local private countryName: string = 'Russia';
  @Local private phoneNumber: string = '';
  @Local private buttonState: ButtonState = 'default';
  @Local private errorMessage: string = '';
  @Local private hasNumber: boolean = false;
  @Local private isCountriesLoaded: boolean = false;
  @Local private isShowCountrySheet: boolean = false;
  @Local private searchText: string = '';
  @Local private groupedCountries: TgCountryGroup[] = [];
  @Local private alphabet: string[] = [];

  async aboutToAppear(): Promise<void> {
    try {
      await CountryService.loadCountries();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to load countries: %{public}s', String(e));
    }
    this.isCountriesLoaded = true;
    this.updateCountryList('');
    // Set default country from loaded data
    const defaultCountry = CountryService.getCountryByCode('RU');
    if (defaultCountry) {
      this.setCountry(defaultCountry);
    }
  }

  @Builder
  countrySheetBuilder() {
    TgCountrySelectionScreen({
      isLoaded: this.isCountriesLoaded,
      searchText: this.searchText,
      groupedCountries: this.groupedCountries,
      alphabet: this.alphabet,
      onSearchChange: (value: string): void => {
        this.searchText = value;
        this.updateCountryList(value);
      },
      onCountryPress: (country: CountryInfo): void => {
        this.isShowCountrySheet = false;
        this.setCountry(country);
      }
    })
  }

  build() {
    Column() {
      // Scrollable content area
      Scroll() {
        Column({ space: 0 }) {
          // Monkey animation
          MonkeyAnimation({ screen: 'phone' })
            .margin({ top: TgUiTokens.LOGIN_SPACING_MONKEY_TOP })

          // Title — локализованная строка
          Text($r('app.string.login_your_phone'))
            .fontSize(TgUiTokens.LOGIN_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TgUiTokens.LOGIN_TITLE_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_SPACING_TITLE_TOP })

          // Subtitle — локализованная строка
          Text($r('app.string.login_confirm_text'))
            .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
            .fontColor(TgUiTokens.LOGIN_SUBTITLE_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_SPACING_TITLE_TOP })

          // ─── Country Button ───
          Column() {
            Row() {
              // Country name with flag prefix
              Text(`${this.getCountryFlagEmoji()} ${this.countryName}`)
                .fontSize(TgUiTokens.LOGIN_COUNTRY_NAME_SIZE)
                .fontColor(TgUiTokens.LOGIN_LINK_COLOR)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              // Disclosure arrow — используем иконку вместо символа
              Image(TgUiTokens.ICON_RES_ARROW_RIGHT)
                .width(TgUiTokens.ICON_SIZE_MD)
                .height(TgUiTokens.ICON_SIZE_MD)
                .fillColor(TgUiTokens.COLOR_ICON_SECONDARY)
            }
            .width('100%')
            .height(TgUiTokens.LOGIN_INPUT_ROW_HEIGHT)
            .padding({ start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET), end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET) })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.searchText = '';
              this.updateCountryList('');
              this.isShowCountrySheet = true;
            })

            // Separator
            Divider()
              .width('calc(100% - 16vp)')
              .strokeWidth(TgUiTokens.LOGIN_SEPARATOR_STROKE)
              .color(TgUiTokens.LOGIN_SEPARATOR_COLOR)
              .margin({ start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET) })
          }
          .margin({ top: TgUiTokens.LOGIN_SPACING_COUNTRY_TOP })

          // ─── Phone Input Row ───
          Row() {
            // Country code field
            TextInput({ text: this.countryCode })
              .width(TgUiTokens.LOGIN_COUNTRY_CODE_WIDTH)
              .height(TgUiTokens.LOGIN_INPUT_ROW_HEIGHT)
              .fontSize(TgUiTokens.LOGIN_INPUT_FONT_SIZE)
              .fontColor(TgUiTokens.LOGIN_INPUT_TEXT_COLOR)
              .backgroundColor(Color.Transparent)
              .padding({ start: LengthMetrics.vp(TgUiTokens.LOGIN_COUNTRY_CODE_PADDING_START) })
              .type(InputType.PhoneNumber)
              .onChange((value: string) => {
                this.countryCode = value;
                this.updateCountryFromCode(value);
              })

            // Vertical separator
            Column()
              .width(TgUiTokens.LOGIN_SEPARATOR_STROKE)
              .height(TgUiTokens.LOGIN_VERTICAL_SEP_HEIGHT)
              .backgroundColor(TgUiTokens.LOGIN_SEPARATOR_COLOR)
              .margin({ start: LengthMetrics.vp(0), end: LengthMetrics.vp(TgUiTokens.LOGIN_PHONE_SEP_GAP_END) })

            // Phone number field
            TextInput({ text: this.phoneNumber, placeholder: this.getPhonePlaceholder() })
              .layoutWeight(1)
              .height(TgUiTokens.LOGIN_INPUT_ROW_HEIGHT)
              .fontSize(TgUiTokens.LOGIN_INPUT_FONT_SIZE)
              .fontColor(TgUiTokens.LOGIN_INPUT_TEXT_COLOR)
              .placeholderColor(TgUiTokens.LOGIN_INPUT_PLACEHOLDER_COLOR)
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
          .padding({ end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET) })

          // Separator under phone input
          Divider()
            .width('calc(100% - 16vp)')
            .strokeWidth(TgUiTokens.LOGIN_SEPARATOR_STROKE)
            .color(TgUiTokens.LOGIN_SEPARATOR_COLOR)
            .margin({ start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET) })

          // Error message
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(TgUiTokens.LOGIN_ERROR_SIZE)
              .fontColor(TgUiTokens.LOGIN_ERROR_COLOR)
              .textAlign(TextAlign.Center)
              .margin({ top: TgUiTokens.LOGIN_SPACING_ERROR_TOP })
              .padding({ start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET), end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET) })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: TgUiTokens.LOGIN_MAX_WIDTH })
      }
      .layoutWeight(1)

      // ─── Continue Button + QR Login ───
      Column({ space: 12 }) {
        SolidRoundedButton({
          title: this.getContinueTitle(),
          isEnabled: this.hasNumber,
          buttonState: this.buttonState,
          onPress: (): void => { this.handleNext(); }
        })

        // QR login link (like Nicegram — under country selector area)
        Text('Log in by QR Code')
          .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
          .fontColor(TgUiTokens.LOGIN_LINK_COLOR)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.requestQrLogin();
          })
      }
      .width('100%')
      .padding({
        start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET),
        end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET),
        bottom: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET)
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.LOGIN_BG)
    .bindSheet($$this.isShowCountrySheet, this.countrySheetBuilder(), {
      height: SheetSize.LARGE,
      blurStyle: BlurStyle.Thick,
      showClose: true,
      title: { title: $r('app.string.select_country') },
      enableOutsideInteractive: false,
      backgroundColor: TgUiTokens.LOGIN_BG
    })
  }

  private handleNext(): void {
    if (!this.hasNumber) return;
    this.sendPhone();
  }

  private async sendPhone(): Promise<void> {
    this.buttonState = 'progress';
    this.errorMessage = '';

    const digits = this.countryCode.replace('+', '') + this.phoneNumber.replace(/\D/g, '');

    // Telegram test DC numbers (99966XXXXX) bypass client-side validation
    const isTestNumber = digits.startsWith('99966') && digits.length >= 10;

    // Клиентская валидация телефона через HarmonyOS i18n API
    let isValidNumber = isTestNumber;
    if (!isValidNumber) {
      try {
        const format = new i18n.PhoneNumberFormat(this.countryFlag);
        isValidNumber = format.isValidNumber(digits);
      } catch (e) {
        // Если i18n API недоступен, используем базовую валидацию
        const phoneRegex = /^[1-9]\d{7,14}$/; // Базовая проверка: 8-15 цифр, начинается не с 0
        isValidNumber = phoneRegex.test(digits.replace(/\D/g, ''));
      }
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

  private async requestQrLogin(): Promise<void> {
    this.errorMessage = '';
    const controller = LoginController.getInstance();
    const result = await controller.requestQrLogin();
    if (!result.success) {
      const failure = result as SendCodeFailure;
      this.errorMessage = failure.error.message;
    }
    // На успех: TDLib пришлёт waitOtherDeviceConfirmation → LoginRouter переключится на QrLoginPage
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

  private updateCountryList(query: string): void {
    const all = CountryService.getAllCountries();
    let filtered = all;

    if (query.trim().length > 0) {
      const q = query.toLowerCase();
      filtered = all.filter(c =>
        c.name.toLowerCase().includes(q) ||
        c.nameRu.toLowerCase().includes(q) ||
        c.dialCode.includes(q)
      );
    }

    const map = new Map<string, CountryInfo[]>();
    for (const c of filtered) {
      const letter = c.name.charAt(0).toUpperCase();
      if (!map.has(letter)) {
        map.set(letter, []);
      }
      map.get(letter)!.push(c);
    }

    const sortedLetters = Array.from(map.keys()).sort();

    this.groupedCountries = sortedLetters.map(letter => {
      const countries = map.get(letter)!;
      countries.sort((a, b) => a.name.localeCompare(b.name));
      return new TgCountryGroup(letter, countries);
    });

    this.alphabet = sortedLetters;
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
      hilog.warn(DOMAIN, TAG, 'Failed to get phone placeholder: %{public}s', String(e));
      return 'Phone number';
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

  private getSelectCountryTitle(): string {
    try {
      return getString($r('app.string.select_country').id);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to get select country title: %{public}s', String(e));
      return 'Select a country';
    }
  }
}
