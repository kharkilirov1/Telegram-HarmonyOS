// CountrySelectPage — Экран выбора страны
// Layout: список на весь экран, круглая кнопка назад сверху, поиск снизу
// Референс: Telegram iOS glass style

import { CountryInfo, CountryService } from '../../services/CountryService';
import { TgCountrySelectionScreen, TgCountryGroup } from '../../tg_ui/molecules/TgCountrySelectionScreen';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

declare function px2vp(value: number): number;

@Component
export struct CountrySelectPage {
  private pageStack: NavPathStack = AppStorage.get<NavPathStack>('pageStack') as NavPathStack;

  @State private searchText: string = '';
  @State private groupedCountries: TgCountryGroup[] = [];
  @State private alphabet: string[] = [];
  @State private isLoaded: boolean = false;
  @State private topInset: number = 44;
  @State private bottomInset: number = 34;

  onCountrySelected?: (country: CountryInfo) => void;

  aboutToAppear(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage = context.windowStage;
      if (windowStage) {
        const mainWindow = windowStage.getMainWindowSync();
        const topArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.topInset = px2vp(topArea.topRect.height);
        const navArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        this.bottomInset = px2vp(navArea.bottomRect.height);
      }
    } catch (error) {
      this.topInset = 44;
      this.bottomInset = 34;
    }

    CountryService.loadCountries()
      .then((): void => {
        this.updateList('');
        this.isLoaded = true;
      })
      .catch((e: Error) => {
        console.error('Failed to load countries:', e.message);
        this.isLoaded = true;
      });
  }

  private updateList(query: string): void {
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

  build() {
    NavDestination() {
      TgCountrySelectionScreen({
        isLoaded: this.isLoaded,
        topInset: this.topInset,
        bottomInset: this.bottomInset,
        searchText: this.searchText,
        groupedCountries: this.groupedCountries,
        alphabet: this.alphabet,
        onBackPress: (): void => {
          this.pageStack.pop();
        },
        onSearchChange: (value: string): void => {
          this.searchText = value;
          this.updateList(value);
        },
        onCountryPress: (country: CountryInfo): void => {
          this.pageStack.pop(country);
        }
      })
    }
    .hideTitleBar(true)
  }
}
