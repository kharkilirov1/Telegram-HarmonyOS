import { UIAbility, AbilityConstant, Want, ConfigurationConstant } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';
import { navigationUIState } from '../../../main/ets/core/model/UIStateModels';
import { SlowmodeNativeFixture } from './components/SlowmodeFixture';

const TAG = 'TestAbility';
const DOMAIN = 0x0001;

export default class TestAbility extends UIAbility {
  private nativeColorMode?: string;
  onForeground(): void { navigationUIState.applicationForeground = true; }
  onBackground(): void { navigationUIState.applicationForeground = false; }
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onCreate');
    // Canonical hypium bootstrap (JsUnit User Guide): without this call the
    // suites are only registered, never executed — aa test hangs silently
    const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
    const abilityDelegatorArguments = abilityDelegatorRegistry.getArguments();
    const color = abilityDelegatorArguments.parameters['-s nativeColorMode'];
    SlowmodeNativeFixture.setConfigurationReady(false);
    if (color !== undefined) {
      if (color !== 'light' && color !== 'dark') throw new Error('Invalid native test color mode');
      this.nativeColorMode = color;
    }
    hilog.info(DOMAIN, TAG, 'start run testcase');
    Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite);
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
      // Official SDK requires a created window and successfully loaded page.
      if (this.nativeColorMode !== undefined) {
        this.context.getApplicationContext().setColorMode(this.nativeColorMode === 'dark' ?
          ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      }
      SlowmodeNativeFixture.setConfigurationReady(true);
      console.info('[NativeTestLaunch] ability=' + this.context.abilityInfo.name +
        ' module=' + this.context.currentHapModuleInfo.name + ' color=' + (this.nativeColorMode ?? 'system'));
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
    });

  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onWindowStageDestroy');
  }
}
