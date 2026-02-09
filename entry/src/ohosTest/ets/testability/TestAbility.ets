import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const TAG = 'TestAbility';
const DOMAIN = 0x0001;

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onWindowStageCreate');
    windowStage.loadContent('testability/pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
    });

    const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
    const testAbilityArgs = abilityDelegatorRegistry.getArguments();
    hilog.info(DOMAIN, TAG, 'Starting test runner with args: %{public}s', JSON.stringify(testAbilityArgs));
    abilityDelegator.addAbilityStageMonitor({
      moduleName: 'entry_test',
      srcEntrance: ''
    }, () => {
      hilog.info(DOMAIN, TAG, 'Stage monitor triggered');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onWindowStageDestroy');
  }
}
