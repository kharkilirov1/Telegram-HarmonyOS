import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'PreferencesService';
const DOMAIN = 0x0001;
const PREFERENCES_NAME = 'telegram_settings';

/**
 * Lightweight key-value persistence for user settings.
 * Uses @ohos.data.preferences (Huawei recommended for small-data settings).
 */
export class PreferencesService {
  private static instance: PreferencesService | null = null;
  private store: preferences.Preferences | null = null;

  private constructor() {}

  static getInstance(): PreferencesService {
    if (!PreferencesService.instance) {
      PreferencesService.instance = new PreferencesService();
    }
    return PreferencesService.instance;
  }

  /**
   * Initialize preferences store. Must be called with a valid context.
   */
  async initialize(context: Context): Promise<void> {
    try {
      this.store = preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
      hilog.info(DOMAIN, TAG, 'Preferences initialized');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize preferences: %{public}s', String(e));
    }
  }

  // --- Theme ---

  async getThemeMode(): Promise<string> {
    return this.getString('theme_mode', 'system');
  }

  async setThemeMode(mode: string): Promise<void> {
    await this.putString('theme_mode', mode);
  }

  // --- Notifications ---

  async getNotificationsEnabled(): Promise<boolean> {
    return this.getBoolean('notifications_enabled', true);
  }

  async setNotificationsEnabled(enabled: boolean): Promise<void> {
    await this.putBoolean('notifications_enabled', enabled);
  }

  async getNotificationSound(): Promise<string> {
    return this.getString('notification_sound', 'default');
  }

  async setNotificationSound(sound: string): Promise<void> {
    await this.putString('notification_sound', sound);
  }

  // --- Chat settings ---

  async getSendByEnter(): Promise<boolean> {
    return this.getBoolean('send_by_enter', true);
  }

  async setSendByEnter(enabled: boolean): Promise<void> {
    await this.putBoolean('send_by_enter', enabled);
  }

  async getFontSize(): Promise<number> {
    return this.getNumber('font_size', 16);
  }

  async setFontSize(size: number): Promise<void> {
    await this.putNumber('font_size', size);
  }

  // --- Privacy ---

  async getLastSeenVisibility(): Promise<string> {
    return this.getString('last_seen_visibility', 'everybody');
  }

  async setLastSeenVisibility(visibility: string): Promise<void> {
    await this.putString('last_seen_visibility', visibility);
  }

  // --- Generic accessors ---

  private async getString(key: string, defaultValue: string): Promise<string> {
    if (!this.store) return defaultValue;
    try {
      return this.store.getSync(key, defaultValue) as string;
    } catch {
      return defaultValue;
    }
  }

  private async putString(key: string, value: string): Promise<void> {
    if (!this.store) return;
    this.store.putSync(key, value);
    await this.store.flush();
  }

  private async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    if (!this.store) return defaultValue;
    try {
      return this.store.getSync(key, defaultValue) as boolean;
    } catch {
      return defaultValue;
    }
  }

  private async putBoolean(key: string, value: boolean): Promise<void> {
    if (!this.store) return;
    this.store.putSync(key, value);
    await this.store.flush();
  }

  private async getNumber(key: string, defaultValue: number): Promise<number> {
    if (!this.store) return defaultValue;
    try {
      return this.store.getSync(key, defaultValue) as number;
    } catch {
      return defaultValue;
    }
  }

  private async putNumber(key: string, value: number): Promise<void> {
    if (!this.store) return;
    this.store.putSync(key, value);
    await this.store.flush();
  }
}
