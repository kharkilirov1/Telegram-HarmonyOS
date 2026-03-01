import { CountryInfo, CountryService } from '../../services/CountryService';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgCountrySectionHeader } from '../atoms/TgCountrySectionHeader';
import { TgCountryRow } from '../atoms/TgCountryRow';
import { TgCountryTopOverlay } from '../atoms/TgCountryTopOverlay';
import { TgCountryBottomSearchOverlay } from '../atoms/TgCountryBottomSearchOverlay';
import { LengthMetrics } from '@kit.ArkUI';

export class TgCountryGroup {
  letter: string = '';
  countries: CountryInfo[] = [];

  constructor(letter: string, countries: CountryInfo[]) {
    this.letter = letter;
    this.countries = countries;
  }
}

@ComponentV2
export struct TgCountrySelectionScreen {
  @Param isLoaded: boolean = false;
  @Param topInset: number = 44;
  @Param bottomInset: number = 34;
  @Param searchText: string = '';
  @Param searchPlaceholder: string = 'Search';
  @Param groupedCountries: TgCountryGroup[] = [];
  @Param alphabet: string[] = [];

  @Event onBackPress: () => void = (): void => {};
  @Event onSearchChange: (value: string) => void = (_value: string): void => {};
  @Event onCountryPress: (country: CountryInfo) => void = (_country: CountryInfo): void => {};

  @Builder
  private buildSectionHeader(text: string) {
    TgCountrySectionHeader({ title: text })
  }

  @Builder
  private buildCountryRow(country: CountryInfo, isLast: boolean) {
    TgCountryRow({
      flagEmoji: CountryService.getCountryFlagEmoji(country.code),
      countryName: country.name,
      dialCode: country.dialCode,
      showSeparator: !isLast,
      onPress: (): void => {
        this.onCountryPress(country);
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.isLoaded) {
        Stack({ alignContent: Alignment.End }) {
          List() {
            ListItem() {
              Row().height(this.topInset + TgUiTokens.COUNTRY_TOP_OVERLAY_BAR_HEIGHT)
            }

            ForEach(this.groupedCountries, (group: TgCountryGroup) => {
              ListItemGroup({ header: this.buildSectionHeader(group.letter) }) {
                ForEach(group.countries, (country: CountryInfo, index: number) => {
                  ListItem() {
                    this.buildCountryRow(country, index === group.countries.length - 1)
                  }
                }, (country: CountryInfo) => country.code)
              }
            }, (group: TgCountryGroup) => group.letter)

            ListItem() {
              Row().height(TgUiTokens.COUNTRY_SEARCH_OVERLAY_HEIGHT + this.bottomInset + TgUiTokens.SPACE_16)
            }
          }
          .width('100%')
          .height('100%')
          .sticky(StickyStyle.Header)
          .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

          if (this.alphabet.length > 0) {
            AlphabetIndexer({ arrayValue: this.alphabet, selected: 0 })
              .font({ size: 11 })
              .selectedFont({ size: 11, weight: FontWeight.Bold })
              .color(TgUiTokens.COLOR_ICON_PRIMARY)
              .selectedColor(TgUiTokens.COLOR_TEXT_TITLE)
              .selectedBackgroundColor(Color.Transparent)
              .usingPopup(true)
              .popupFont({ size: 30, weight: FontWeight.Bold })
              .popupBackground(TgUiTokens.COLOR_OVERLAY_DIM)
              .alignStyle(IndexerAlign.Right)
              .itemSize(16)
              .margin({
                end: LengthMetrics.vp(4),
                bottom: LengthMetrics.vp(TgUiTokens.COUNTRY_SEARCH_OVERLAY_HEIGHT + this.bottomInset)
              })
          }
        }
        .width('100%')
        .height('100%')
      } else {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      }

      TgCountryTopOverlay({
        topInset: this.topInset,
        onBackPress: (): void => {
          this.onBackPress();
        }
      })

      Column() {
        Blank()
        TgCountryBottomSearchOverlay({
          query: this.searchText,
          bottomInset: this.bottomInset,
          placeholder: this.searchPlaceholder,
          onQueryChange: (value: string): void => {
            this.onSearchChange(value);
          }
        })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
  }
}
