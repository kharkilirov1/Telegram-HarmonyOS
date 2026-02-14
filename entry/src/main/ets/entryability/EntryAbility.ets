import { Configuration, UIAbility, ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, KeyboardAvoidMode } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { PreferencesService } from '../services/PreferencesService';

const TAG = 'EntryAbility';
const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | null = null;

  async onCreate(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onCreate');
    // Initialize preferences with ability context
    await PreferencesService.getInstance().initialize(this.context);
    await this.applyPersistedAppPreferences();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');

    this.windowStage = windowStage;

    // Edge-to-edge: transparent system bars like iOS
    try {
      const mainWindow = await windowStage.getMainWindow();
      await mainWindow.setWindowLayoutFullScreen(true);
      await this.updateSystemBarContentColor();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'window edge-to-edge setup failed: %{public}s', String(error));
    }

    // Use RESIZE mode so keyboard compresses layout instead of shifting it
    // (critical for chat input bars — prevents content from being obscured)
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
      try {
        const uiContext = windowStage.getMainWindowSync().getUIContext();
        uiContext.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'setKeyboardAvoidMode failed: %{public}s', String(error));
      }
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

  // Update status bar icon color when theme changes (dark ↔ light)
  onConfigurationUpdate(newConfig: Configuration): void {
    const isDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    void this.updateSystemBarContentColor(isDark);
  }

  private async updateSystemBarContentColor(isDark?: boolean): Promise<void> {
    if (!this.windowStage) return;
    try {
      const mainWindow = await this.windowStage.getMainWindow();
      if (isDark === undefined) {
        isDark = this.context.config?.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      }
      const contentColor = isDark ? '#FFFFFF' : '#000000';
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor
      });
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'update system bar color failed: %{public}s', String(error));
    }
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
