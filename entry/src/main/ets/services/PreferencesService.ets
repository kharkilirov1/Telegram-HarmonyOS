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

  // --- Language ---

  async getAppLanguage(): Promise<string> {
    return this.getString('app_language', 'en');
  }

  async setAppLanguage(languageCode: string): Promise<void> {
    await this.putString('app_language', languageCode);
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

  // --- Passcode / Biometric Lock ---

  async getPasscodeEnabled(): Promise<boolean> {
    return this.getBoolean('passcode_enabled', false);
  }

  async setPasscodeEnabled(enabled: boolean): Promise<void> {
    await this.putBoolean('passcode_enabled', enabled);
  }

  async getBiometricEnabled(): Promise<boolean> {
    return this.getBoolean('biometric_enabled', false);
  }

  async setBiometricEnabled(enabled: boolean): Promise<void> {
    await this.putBoolean('biometric_enabled', enabled);
  }

  async getAutoLockTimeout(): Promise<number> {
    return this.getNumber('auto_lock_timeout', 0);
  }

  async setAutoLockTimeout(seconds: number): Promise<void> {
    await this.putNumber('auto_lock_timeout', seconds);
  }

  async getPasscodeHash(): Promise<string> {
    return this.getString('passcode_hash', '');
  }

  async setPasscodeHash(hash: string): Promise<void> {
    await this.putString('passcode_hash', hash);
  }

  // --- Auto-download settings ---

  async getAutoDownloadEnabled(mediaType: string, networkType: string): Promise<boolean> {
    const key = `auto_download_${mediaType}_${networkType}`;
    const defaultValue = networkType === 'wifi';
    return this.getBoolean(key, defaultValue);
  }

  async setAutoDownloadEnabled(mediaType: string, networkType: string, enabled: boolean): Promise<void> {
    const key = `auto_download_${mediaType}_${networkType}`;
    await this.putBoolean(key, enabled);
  }

  async getAutoDownloadMaxSize(mediaType: string): Promise<number> {
    const key = `auto_download_${mediaType}_max_size`;
    const defaultValue = mediaType === 'videos' ? 15728640 : 1048576;
    return this.getNumber(key, defaultValue);
  }

  async setAutoDownloadMaxSize(mediaType: string, size: number): Promise<void> {
    const key = `auto_download_${mediaType}_max_size`;
    await this.putNumber(key, size);
  }

  async getAutoPlayGifs(): Promise<boolean> {
    return this.getBoolean('auto_play_gifs', true);
  }

  async setAutoPlayGifs(enabled: boolean): Promise<void> {
    await this.putBoolean('auto_play_gifs', enabled);
  }

  async getAutoPlayVideos(): Promise<boolean> {
    return this.getBoolean('auto_play_videos', true);
  }

  async setAutoPlayVideos(enabled: boolean): Promise<void> {
    await this.putBoolean('auto_play_videos', enabled);
  }

  async getSaveIncomingPhotos(): Promise<boolean> {
    return this.getBoolean('save_incoming_photos', false);
  }

  async setSaveIncomingPhotos(enabled: boolean): Promise<void> {
    await this.putBoolean('save_incoming_photos', enabled);
  }

  async getSaveEditedPhotos(): Promise<boolean> {
    return this.getBoolean('save_edited_photos', false);
  }

  async setSaveEditedPhotos(enabled: boolean): Promise<void> {
    await this.putBoolean('save_edited_photos', enabled);
  }

  // --- Generic public keys (for advanced/settings screens) ---

  async getBooleanSetting(key: string, defaultValue: boolean): Promise<boolean> {
    return this.getBoolean(key, defaultValue);
  }

  async setBooleanSetting(key: string, value: boolean): Promise<void> {
    await this.putBoolean(key, value);
  }

  async getStringSetting(key: string, defaultValue: string): Promise<string> {
    return this.getString(key, defaultValue);
  }

  async setStringSetting(key: string, value: string): Promise<void> {
    await this.putString(key, value);
  }

  async getNumberSetting(key: string, defaultValue: number): Promise<number> {
    return this.getNumber(key, defaultValue);
  }

  async setNumberSetting(key: string, value: number): Promise<void> {
    await this.putNumber(key, value);
  }

  // --- Generic accessors ---

  private async getString(key: string, defaultValue: string): Promise<string> {
    if (!this.store) return defaultValue;
    try {
      return this.store.getSync(key, defaultValue) as string;
    } catch (e) {
      hilog.debug(DOMAIN, TAG, 'getString(%{public}s) failed: %{public}s', key, String(e));
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
    } catch (e) {
      hilog.debug(DOMAIN, TAG, 'getBoolean(%{public}s) failed: %{public}s', key, String(e));
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
    } catch (e) {
      hilog.debug(DOMAIN, TAG, 'getNumber(%{public}s) failed: %{public}s', key, String(e));
      return defaultValue;
    }
  }

  private async putNumber(key: string, value: number): Promise<void> {
    if (!this.store) return;
    this.store.putSync(key, value);
    await this.store.flush();
  }
}
