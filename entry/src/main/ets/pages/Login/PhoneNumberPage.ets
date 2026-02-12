import { AuthController } from '../../controllers/AuthController';
import { TelegramMascot, MascotState } from '../../components/Common/TelegramMascot';

@Builder
export function PhoneNumberBuilder(name: string, param: Object) {
  PhoneNumberPage()
}

interface CountryEntry {
  name: string;
  code: string;
  flag: string;
}

// Country list with codes and flag emoji (like Telegram iOS/Android country picker)
const COUNTRY_LIST: CountryEntry[] = [
  { name: 'Russia', code: '+7', flag: '\u{1F1F7}\u{1F1FA}' },
  { name: 'United States', code: '+1', flag: '\u{1F1FA}\u{1F1F8}' },
  { name: 'United Kingdom', code: '+44', flag: '\u{1F1EC}\u{1F1E7}' },
  { name: 'Germany', code: '+49', flag: '\u{1F1E9}\u{1F1EA}' },
  { name: 'France', code: '+33', flag: '\u{1F1EB}\u{1F1F7}' },
  { name: 'Italy', code: '+39', flag: '\u{1F1EE}\u{1F1F9}' },
  { name: 'Spain', code: '+34', flag: '\u{1F1EA}\u{1F1F8}' },
  { name: 'Ukraine', code: '+380', flag: '\u{1F1FA}\u{1F1E6}' },
  { name: 'Poland', code: '+48', flag: '\u{1F1F5}\u{1F1F1}' },
  { name: 'Netherlands', code: '+31', flag: '\u{1F1F3}\u{1F1F1}' },
  { name: 'Turkey', code: '+90', flag: '\u{1F1F9}\u{1F1F7}' },
  { name: 'Brazil', code: '+55', flag: '\u{1F1E7}\u{1F1F7}' },
  { name: 'India', code: '+91', flag: '\u{1F1EE}\u{1F1F3}' },
  { name: 'China', code: '+86', flag: '\u{1F1E8}\u{1F1F3}' },
  { name: 'Japan', code: '+81', flag: '\u{1F1EF}\u{1F1F5}' },
  { name: 'South Korea', code: '+82', flag: '\u{1F1F0}\u{1F1F7}' },
  { name: 'Canada', code: '+1', flag: '\u{1F1E8}\u{1F1E6}' },
  { name: 'Australia', code: '+61', flag: '\u{1F1E6}\u{1F1FA}' },
  { name: 'Mexico', code: '+52', flag: '\u{1F1F2}\u{1F1FD}' },
  { name: 'Argentina', code: '+54', flag: '\u{1F1E6}\u{1F1F7}' },
  { name: 'Saudi Arabia', code: '+966', flag: '\u{1F1F8}\u{1F1E6}' },
  { name: 'UAE', code: '+971', flag: '\u{1F1E6}\u{1F1EA}' },
  { name: 'Israel', code: '+972', flag: '\u{1F1EE}\u{1F1F1}' },
  { name: 'Egypt', code: '+20', flag: '\u{1F1EA}\u{1F1EC}' },
  { name: 'South Africa', code: '+27', flag: '\u{1F1FF}\u{1F1E6}' },
  { name: 'Nigeria', code: '+234', flag: '\u{1F1F3}\u{1F1EC}' },
  { name: 'Indonesia', code: '+62', flag: '\u{1F1EE}\u{1F1E9}' },
  { name: 'Thailand', code: '+66', flag: '\u{1F1F9}\u{1F1ED}' },
  { name: 'Vietnam', code: '+84', flag: '\u{1F1FB}\u{1F1F3}' },
  { name: 'Kazakhstan', code: '+7', flag: '\u{1F1F0}\u{1F1FF}' },
  { name: 'Belarus', code: '+375', flag: '\u{1F1E7}\u{1F1FE}' },
  { name: 'Georgia', code: '+995', flag: '\u{1F1EC}\u{1F1EA}' },
  { name: 'Armenia', code: '+374', flag: '\u{1F1E6}\u{1F1F2}' },
  { name: 'Azerbaijan', code: '+994', flag: '\u{1F1E6}\u{1F1FF}' },
  { name: 'Uzbekistan', code: '+998', flag: '\u{1F1FA}\u{1F1FF}' },
  { name: 'Switzerland', code: '+41', flag: '\u{1F1E8}\u{1F1ED}' },
  { name: 'Austria', code: '+43', flag: '\u{1F1E6}\u{1F1F9}' },
  { name: 'Sweden', code: '+46', flag: '\u{1F1F8}\u{1F1EA}' },
  { name: 'Norway', code: '+47', flag: '\u{1F1F3}\u{1F1F4}' },
  { name: 'Finland', code: '+358', flag: '\u{1F1EB}\u{1F1EE}' },
  { name: 'Denmark', code: '+45', flag: '\u{1F1E9}\u{1F1F0}' },
  { name: 'Czech Republic', code: '+420', flag: '\u{1F1E8}\u{1F1FF}' },
  { name: 'Romania', code: '+40', flag: '\u{1F1F7}\u{1F1F4}' },
  { name: 'Portugal', code: '+351', flag: '\u{1F1F5}\u{1F1F9}' },
  { name: 'Greece', code: '+30', flag: '\u{1F1EC}\u{1F1F7}' },
  { name: 'Ireland', code: '+353', flag: '\u{1F1EE}\u{1F1EA}' },
  { name: 'Singapore', code: '+65', flag: '\u{1F1F8}\u{1F1EC}' },
  { name: 'Malaysia', code: '+60', flag: '\u{1F1F2}\u{1F1FE}' },
  { name: 'Philippines', code: '+63', flag: '\u{1F1F5}\u{1F1ED}' },
  { name: 'New Zealand', code: '+64', flag: '\u{1F1F3}\u{1F1FF}' }
];

@ComponentV2
export struct PhoneNumberPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local phoneNumber: string = '';
  @Local countryCode: string = '+7';
  @Local countryName: string = 'Russia';
  @Local countryFlag: string = '\u{1F1F7}\u{1F1FA}';
  @Local isLoading: boolean = false;
  @Local errorMessage: string = '';
  @Local showCountryPicker: boolean = false;
  @Local countrySearchText: string = '';

  build() {
    NavDestination() {
      Stack() {
        Column() {
          // Top bar with "Next" in top-right (like real Telegram iOS)
          Row() {
            Blank()
            if (this.phoneNumber.length > 0) {
              Text($r('app.string.next_button'))
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.telegram_blue'))
                .onClick(() => this.submitPhoneNumber())
            }
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })

          Blank().height(20)

          // Animated mascot — the Telegram monkey (like real Telegram login)
          TelegramMascot({ mascotState: MascotState.IDLE, mascotSize: 120 })
            .margin({ bottom: 16 })

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
              Text(`${this.countryFlag}  ${this.countryName}`)
                .fontSize(20)
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
              this.showCountryPicker = true;
              this.countrySearchText = '';
            })

            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 20 })

            // Country code + phone number input row (like real Telegram)
            Row() {
              // Country code (tappable to open picker)
              Text(this.countryCode)
                .fontSize(20)
                .fontColor($r('app.color.telegram_blue'))
                .width(60)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.showCountryPicker = true;
                  this.countrySearchText = '';
                })

              Divider()
                .vertical(true)
                .strokeWidth(0.5)
                .color($r('app.color.separator'))
                .height(24)

              // Phone number input
              TextInput({ placeholder: $r('app.string.phone_placeholder'), text: this.phoneNumber })
                .type(InputType.PhoneNumber)
                .fontSize(20)
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
              .fontSize(14)
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
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        // --- Country picker overlay (like Telegram iOS/Android) ---
        if (this.showCountryPicker) {
          Column() {
            // Header
            Row() {
              Text($r('app.string.cancel'))
                .fontSize(16)
                .fontColor($r('app.color.telegram_blue'))
                .onClick(() => { this.showCountryPicker = false; })

              Blank()

              Text($r('app.string.login_choose_country'))
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Blank()

              // Spacer to balance Cancel button
              Text('').width(50)
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })

            // Search field
            Search({ placeholder: $r('app.string.search_placeholder'), value: this.countrySearchText })
              .width('100%')
              .height(36)
              .margin({ left: 16, right: 16, bottom: 8 })
              .onChange((value: string) => { this.countrySearchText = value; })

            Divider().strokeWidth(0.5).color($r('app.color.separator'))

            // Country list
            List() {
              ForEach(this.getFilteredCountries(), (country: CountryEntry) => {
                ListItem() {
                  Row() {
                    Text(country.flag)
                      .fontSize(24)
                      .width(40)

                    Text(country.name)
                      .fontSize(16)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)

                    Text(country.code)
                      .fontSize(16)
                      .fontColor($r('app.color.telegram_blue'))
                  }
                  .width('100%')
                  .height(48)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => {
                    this.countryName = country.name;
                    this.countryCode = country.code;
                    this.countryFlag = country.flag;
                    this.showCountryPicker = false;
                  })
                }
              }, (country: CountryEntry) => `${country.name}_${country.code}`)
            }
            .width('100%')
            .layoutWeight(1)
            .divider({
              strokeWidth: 0.5,
              color: $r('app.color.separator'),
              startMargin: 56,
              endMargin: 0
            })
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.background_primary'))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  private getFilteredCountries(): CountryEntry[] {
    if (this.countrySearchText.length === 0) {
      return COUNTRY_LIST;
    }
    const query = this.countrySearchText.toLowerCase();
    return COUNTRY_LIST.filter(c =>
      c.name.toLowerCase().includes(query) || c.code.includes(query)
    );
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
