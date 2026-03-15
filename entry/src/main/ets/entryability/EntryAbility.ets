// Minimal EntryAbility - no UI, only core initialization
// UI layers will be added separately in presentation/ui

import { UIAbility, AbilityConstant, Configuration, ConfigurationConstant, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, KeyboardAvoidMode } from '@kit.ArkUI';
import { getAppCoreRuntime } from '../app/bootstrap/AppCoreRuntime';
import { StorageKeys } from '../app/bridge/AppStoreBridge';
import { getMessageCacheManager } from '../core/utils/MessageLruCache';
import { setAppContext } from '../core/utils/AppResource';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'EntryAbility';
const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  async onCreate(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onCreate');

    // Инициализируем глобальный контекст для доступа к ресурсам
    setAppContext(this.context);

    // Сохраняем текущий colorMode для UI-слоя
    AppStorage.setOrCreate<number>('colorMode', this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);

    // Initialize AppCoreRuntime (TdGateway + EventNormalizer + AppStore)
    try {
      const runtime = getAppCoreRuntime();
      await runtime.initialize();
      AppStorage.setOrCreate<string>(StorageKeys.GLASS_MODE, 'auto');
      hilog.info(DOMAIN, TAG, 'AppCoreRuntime initialized');
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to initialize AppCoreRuntime: %{public}s', err.message);
    }
  }

  async onDestroy(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onDestroy');

    // Shutdown runtime
    try {
      const runtime = getAppCoreRuntime();
      await runtime.shutdown();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Error during shutdown: %{public}s', String(error));
    }
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');

    try {
      // Immersive fullscreen — контент на весь экран
      this.mainWindow = windowStage.getMainWindowSync();
      this.mainWindow.setWindowLayoutFullScreen(true);

      // System bars прозрачные, контент (часы/батарея/сеть) — цвет по теме
      this.applyStatusBarColors();
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to set window properties: %{public}s', err.message);
      return;
    }
    const mainWindow = this.mainWindow;

    // Load login router page
    windowStage.loadContent('ui/pages/login/LoginRouterPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'LoginRouterPage loaded');

      // UIContext доступен ТОЛЬКО после loadContent
      try {
        const uiContext = mainWindow.getUIContext();
        if (uiContext) {
          uiContext.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
          hilog.info(DOMAIN, TAG, 'KeyboardAvoidMode set to RESIZE');
        }
      } catch (error) {
        const err: BusinessError = error as BusinessError;
        hilog.warn(DOMAIN, TAG, 'Failed to set keyboard mode: %{public}s', err.message);
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

  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, TAG, 'onConfigurationUpdate colorMode=%{public}d', newConfig.colorMode ?? -1);
    if (newConfig.colorMode !== undefined) {
      AppStorage.setOrCreate<number>('colorMode', newConfig.colorMode);
      this.applyStatusBarColors();
    }
  }

  private applyStatusBarColors(): void {
    if (!this.mainWindow) {
      return;
    }
    const isDark = (AppStorage.get<number>('colorMode') ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
      === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const contentColor = isDark ? '#FFFFFF' : '#000000';
    const sysBarProps: window.SystemBarProperties = {
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: contentColor,
      navigationBarContentColor: contentColor
    };
    try {
      this.mainWindow.setWindowSystemBarProperties(sysBarProps);
      hilog.info(DOMAIN, TAG, 'Status bar content color set to %{public}s', contentColor);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Failed to update status bar colors: %{public}s', String(error));
    }
  }

  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    hilog.info(DOMAIN, TAG, 'onMemoryLevel: %{public}d', level);
    if (level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_CRITICAL || 
        level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_LOW) {
      hilog.warn(DOMAIN, TAG, 'Memory low/critical. Clearing message cache.');
      getMessageCacheManager().clear();
      AppStorage.set<string>(StorageKeys.GLASS_MODE, 'fallback');
      hilog.warn(DOMAIN, TAG, 'Glass policy switched to fallback due to memory pressure');
    } else if (level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_MODERATE) {
      // Keep app responsive on sustained moderate pressure.
      AppStorage.set<string>(StorageKeys.GLASS_MODE, 'fallback');
      hilog.warn(DOMAIN, TAG, 'Glass policy switched to fallback due to moderate memory pressure');
    }
  }
}
