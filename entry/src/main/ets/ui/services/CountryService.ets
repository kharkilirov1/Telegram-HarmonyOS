// CountryService — сервис для работы с кодами стран
// HarmonyOS Guidelines: загружает данные из rawfile

import { getAppContext } from '../../core/utils/AppResource';

export interface CountryInfo {
  code: string;        // ISO 3166-1 alpha-2 (RU, US, GB)
  name: string;        // English name
  nameRu: string;      // Russian name
  dialCode: string;    // Phone code (+7, +1, +44)
  pattern: string;     // Phone pattern (XXX XXX-XX-XX)
}

interface CountriesJson {
  countries: CountryInfo[];
}

class CountryServiceImpl {
  private countries: CountryInfo[] = [];
  private countriesByCode: Map<string, CountryInfo> = new Map();
  private countriesByDialCode: Map<string, CountryInfo[]> = new Map();
  private isLoaded: boolean = false;

  async loadCountries(): Promise<void> {
    if (this.isLoaded) return;

    try {
      const context = getAppContext();
      if (!context) {
        console.error('CountryService: App context not initialized');
        return;
      }
      const rm = context.resourceManager;
      const rawData = await rm.getRawFileContent('data/countries.json');
      const jsonString = this.uint8ArrayToString(rawData);
      const data: CountriesJson = JSON.parse(jsonString) as CountriesJson;

      this.countries = data.countries;

      // Build indexes
      for (const country of this.countries) {
        this.countriesByCode.set(country.code, country);

        const dialCode = country.dialCode.replace('+', '');
        const existing = this.countriesByDialCode.get(dialCode);
        if (existing) {
          existing.push(country);
        } else {
          this.countriesByDialCode.set(dialCode, [country]);
        }
      }

      this.isLoaded = true;
    } catch (e) {
      console.error('CountryService: Failed to load countries', e);
    }
  }

  private uint8ArrayToString(array: Uint8Array): string {
    let result = '';
    for (let i = 0; i < array.length; i++) {
      result += String.fromCharCode(array[i]);
    }
    return result;
  }

  getAllCountries(): CountryInfo[] {
    return this.countries;
  }

  getCountryByCode(code: string): CountryInfo | undefined {
    return this.countriesByCode.get(code.toUpperCase());
  }

  getCountriesByDialCode(dialCode: string): CountryInfo[] {
    const stripped = dialCode.replace('+', '');
    return this.countriesByDialCode.get(stripped) || [];
  }

  findCountryByDialCode(dialCode: string): CountryInfo | undefined {
    const stripped = dialCode.replace('+', '');
    
    // Try exact match first
    const exact = this.countriesByDialCode.get(stripped);
    if (exact && exact.length > 0) {
      return exact[0];
    }

    // Try prefix match (e.g., +77 -> +7)
    for (let len = stripped.length; len > 0; len--) {
      const prefix = stripped.substring(0, len);
      const matches = this.countriesByDialCode.get(prefix);
      if (matches && matches.length > 0) {
        return matches[0];
      }
    }

    return undefined;
  }

  getCountryFlagEmoji(countryCode: string): string {
    if (countryCode.length !== 2) return '';
    const codePoints = countryCode
      .toUpperCase()
      .split('')
      .map(char => 127397 + char.charCodeAt(0));
    return String.fromCodePoint(...codePoints);
  }

  getLocalizedName(country: CountryInfo, locale: string): string {
    if (locale.startsWith('ru')) {
      return country.nameRu;
    }
    return country.name;
  }
}

// Singleton
export const CountryService = new CountryServiceImpl();
