import { CountryInfo } from '../../services/CountryService';
import { TgCountryGroup, TgCountrySelectionScreen } from '../molecules/TgCountrySelectionScreen';

@Preview({ title: 'TgCountrySelectionScreen' })
@ComponentV2
export struct TgCountrySelectionScreenDemo {
  @Local searchText: string = '';
  @Local groups: TgCountryGroup[] = [];
  @Local alphabet: string[] = [];

  private allCountries: CountryInfo[] = [
    { code: 'US', name: 'United States', nameRu: 'США', dialCode: '+1', pattern: '' },
    { code: 'GB', name: 'United Kingdom', nameRu: 'Великобритания', dialCode: '+44', pattern: '' },
    { code: 'DE', name: 'Germany', nameRu: 'Германия', dialCode: '+49', pattern: '' },
    { code: 'JP', name: 'Japan', nameRu: 'Япония', dialCode: '+81', pattern: '' },
    { code: 'KZ', name: 'Kazakhstan', nameRu: 'Казахстан', dialCode: '+7', pattern: '' }
  ];

  aboutToAppear(): void {
    this.rebuildGroups('');
  }

  private rebuildGroups(query: string): void {
    let filtered = this.allCountries;
    if (query.trim().length > 0) {
      const q = query.toLowerCase();
      filtered = filtered.filter((c: CountryInfo) =>
        c.name.toLowerCase().includes(q) ||
        c.nameRu.toLowerCase().includes(q) ||
        c.dialCode.includes(q)
      );
    }

    const map = new Map<string, CountryInfo[]>();
    for (const country of filtered) {
      const letter = country.name.charAt(0).toUpperCase();
      if (!map.has(letter)) {
        map.set(letter, []);
      }
      map.get(letter)!.push(country);
    }

    const letters = Array.from(map.keys()).sort();
    this.groups = letters.map((letter: string) => new TgCountryGroup(letter, map.get(letter)!));
    this.alphabet = letters;
  }

  build() {
    TgCountrySelectionScreen({
      isLoaded: true,
      searchText: this.searchText,
      groupedCountries: this.groups,
      alphabet: this.alphabet,
      onSearchChange: (value: string): void => {
        this.searchText = value;
        this.rebuildGroups(value);
      }
    })
  }
}

