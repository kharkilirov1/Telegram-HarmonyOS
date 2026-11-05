// D24: translation target language. iOS remembers the language per chat and offers a picker; this module
// owns the supported list, the per-chat override and the fallback to the system language.

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x004E;
const TAG = 'TranslationLanguage';

// Codes TDLib accepts and the app ships strings for; order is the picker order.
export const SUPPORTED_TRANSLATION_LANGUAGES: string[] = [
  'en', 'ru', 'uk', 'de', 'fr', 'es', 'it', 'pt', 'pl', 'tr', 'ar', 'zh', 'ja', 'ko'
];

export const FALLBACK_TRANSLATION_LANGUAGE = 'en';

export function normalizeTranslationLanguage(code: string): string {
  const trimmed = code.trim().toLowerCase();
  if (trimmed.length === 0) {
    return '';
  }
  const primary = trimmed.split('-')[0];
  return /^[a-z]{2,3}$/.test(primary) ? primary : '';
}

export function isSupportedTranslationLanguage(code: string): boolean {
  const normalized = normalizeTranslationLanguage(code);
  return normalized.length > 0 && SUPPORTED_TRANSLATION_LANGUAGES.includes(normalized);
}

// Per-chat choice wins, then the app-wide default, then the system language, then English.
export function resolveTranslationLanguage(stored: string, systemLanguage: string,
  globalDefault: string = ''): string {
  const storedNormalized = normalizeTranslationLanguage(stored);
  if (isSupportedTranslationLanguage(storedNormalized)) {
    return storedNormalized;
  }
  const globalNormalized = normalizeTranslationLanguage(globalDefault);
  if (isSupportedTranslationLanguage(globalNormalized)) {
    return globalNormalized;
  }
  const systemNormalized = normalizeTranslationLanguage(systemLanguage);
  if (isSupportedTranslationLanguage(systemNormalized)) {
    return systemNormalized;
  }
  return FALLBACK_TRANSLATION_LANGUAGE;
}

// The app-wide default is stored under a reserved key so the settings picker and a future per-chat
// override share one store.
export const GLOBAL_TRANSLATION_CHAT_ID = 1;

// Picker labels: the codes are shown upper-case, matching the iOS compact list.
export function translationLanguageLabel(code: string): string {
  const normalized = normalizeTranslationLanguage(code);
  return normalized.length > 0 ? normalized.toUpperCase() : '';
}

class TranslationLanguagePreferencesStore {
  private perChat: Map<number, string> = new Map<number, string>();

  set(chatId: number, code: string): boolean {
    if (chatId === 0) {
      return false;
    }
    const normalized = normalizeTranslationLanguage(code);
    if (!isSupportedTranslationLanguage(normalized)) {
      return false;
    }
    this.perChat.set(chatId, normalized);
    hilog.info(DOMAIN, TAG, 'Translation language for chat %{public}d: %{public}s', chatId, normalized);
    return true;
  }

  get(chatId: number): string {
    return this.perChat.get(chatId) ?? '';
  }

  clear(chatId: number): void {
    this.perChat.delete(chatId);
  }

  // Settings picker: the app-wide default, independent of any chat.
  globalDefault(): string {
    return this.perChat.get(GLOBAL_TRANSLATION_CHAT_ID) ?? '';
  }

  setGlobalDefault(code: string): boolean {
    return this.set(GLOBAL_TRANSLATION_CHAT_ID, code);
  }

  clearAll(): void {
    this.perChat.clear();
  }

  size(): number {
    return this.perChat.size;
  }
}

export const translationLanguagePreferences: TranslationLanguagePreferencesStore =
  new TranslationLanguagePreferencesStore();
