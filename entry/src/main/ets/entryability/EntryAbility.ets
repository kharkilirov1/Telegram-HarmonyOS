import { UIAbility, ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { PreferencesService } from '../services/PreferencesService';

const TAG = 'EntryAbility';
const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  async onCreate(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onCreate');
    // Initialize preferences with ability context
    await PreferencesService.getInstance().initialize(this.context);
    await this.applyPersistedAppPreferences();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
  }

  private async applyPersistedAppPreferences(): Promise<void> {
    const prefs = PreferencesService.getInstance();

    // Apply persisted theme mode
    try {
      const appContext = this.context.getApplicationContext();
      const themeMode = await prefs.getThemeMode();
      switch (themeMode) {
        case 'light':
          appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          break;
        case 'dark':
          appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          break;
        default:
          appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
          break;
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'apply theme preference failed: %{public}s', String(error));
    }

    // Apply persisted language
    try {
      const langCode = await prefs.getAppLanguage();
      const preferredLanguage = this.mapLanguageCode(langCode);
      i18n.System.setAppPreferredLanguage(preferredLanguage);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'apply language preference failed: %{public}s', String(error));
    }
  }

  private mapLanguageCode(code: string): string {
    switch (code) {
      case 'zh':
        return 'zh-Hans';
      case 'pt':
        return 'pt-BR';
      default:
        return code;
    }
  }
}
