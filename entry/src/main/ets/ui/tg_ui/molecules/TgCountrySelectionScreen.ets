import { CountryInfo, CountryService } from '../../services/CountryService';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgCountrySectionHeader } from '../atoms/TgCountrySectionHeader';
import { TgCountryRow } from '../atoms/TgCountryRow';

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
  @Param searchText: string = '';
  @Param searchPlaceholder: string = 'Search';
  @Param groupedCountries: TgCountryGroup[] = [];
  @Param alphabet: string[] = [];

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
    Column() {
      Search({ placeholder: this.searchPlaceholder, value: this.searchText })
        .height(TgUiTokens.COUNTRY_SHEET_SEARCH_HEIGHT)
        .backgroundColor(TgUiTokens.SEARCH_BAR_BG)
        .margin({
          left: TgUiTokens.COUNTRY_SHEET_SEARCH_SIDE_INSET,
          right: TgUiTokens.COUNTRY_SHEET_SEARCH_SIDE_INSET,
          top: TgUiTokens.SPACE_8,
          bottom: TgUiTokens.SPACE_8
        })
        .onChange((value: string) => {
          this.onSearchChange(value);
        })

      if (this.isLoaded) {
        Stack({ alignContent: Alignment.End }) {
          List() {
            ForEach(this.groupedCountries, (group: TgCountryGroup) => {
              ListItemGroup({ header: this.buildSectionHeader(group.letter) }) {
                ForEach(group.countries, (country: CountryInfo, index: number) => {
                  ListItem() {
                    this.buildCountryRow(country, index === group.countries.length - 1)
                  }
                }, (country: CountryInfo) => country.code)
              }
            }, (group: TgCountryGroup) => group.letter)
          }
          .width('100%')
          .height('100%')
          .sticky(StickyStyle.Header)
          .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

          if (this.alphabet.length > 0) {
            AlphabetIndexer({ arrayValue: this.alphabet, selected: 0 })
              .font({ size: TgUiTokens.COUNTRY_INDEXER_FONT_SIZE })
              .selectedFont({ size: TgUiTokens.COUNTRY_INDEXER_FONT_SIZE, weight: FontWeight.Bold })
              .color(TgUiTokens.COLOR_ICON_PRIMARY)
              .selectedColor(TgUiTokens.COLOR_TEXT_TITLE)
              .selectedBackgroundColor(Color.Transparent)
              .usingPopup(true)
              .popupFont({ size: TgUiTokens.COUNTRY_INDEXER_POPUP_FONT_SIZE, weight: FontWeight.Bold })
              .popupBackground(TgUiTokens.COLOR_OVERLAY_DIM)
              .alignStyle(IndexerAlign.Right)
              .itemSize(TgUiTokens.COUNTRY_INDEXER_ITEM_SIZE)
              .margin({ right: TgUiTokens.COUNTRY_INDEXER_MARGIN_RIGHT })
          }
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Column() {
          LoadingProgress()
            .width(TgUiTokens.COUNTRY_SHEET_LOADING_SIZE)
            .height(TgUiTokens.COUNTRY_SHEET_LOADING_SIZE)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      }
    }
    .width('100%')
    .height('100%')
  }
}
