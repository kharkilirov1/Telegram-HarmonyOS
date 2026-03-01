// Minimal EntryAbility - no UI, only core initialization
// UI layers will be added separately in presentation/ui

import { UIAbility, AbilityConstant, common } from '@kit.AbilityKit';
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
  async onCreate(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onCreate');

    // Инициализируем глобальный контекст для доступа к ресурсам
    setAppContext(this.context);

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

    let mainWindow: window.Window;
    try {
      // Immersive fullscreen — контент на весь экран
      mainWindow = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true);

      // System bars прозрачные, цвет контента адаптивный
      const sysBarProps: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: false,
        isNavigationBarLightIcon: false
      };
      mainWindow.setWindowSystemBarProperties(sysBarProps);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to set window properties: %{public}s', err.message);
      return;
    }

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
