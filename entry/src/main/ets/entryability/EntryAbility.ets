// Minimal EntryAbility - no UI, only core initialization
// UI layers will be added separately in presentation/ui

import { UIAbility } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { getAppCoreRuntime } from '../app/bootstrap/AppCoreRuntime';

const TAG = 'EntryAbility';
const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  async onCreate(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onCreate');

    // Initialize AppCoreRuntime (TdGateway + EventNormalizer + AppStore)
    try {
      const runtime = getAppCoreRuntime();
      await runtime.initialize();
      hilog.info(DOMAIN, TAG, 'AppCoreRuntime initialized');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize AppCoreRuntime: %{public}s', String(error));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');

    // Shutdown runtime
    try {
      const runtime = getAppCoreRuntime();
      runtime.shutdown();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Error during shutdown: %{public}s', String(error));
    }
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');

    // Load minimal placeholder page (to be replaced by presentation layer)
    windowStage.loadContent('ui/pages/PlaceholderPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Placeholder content loaded');
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
}
