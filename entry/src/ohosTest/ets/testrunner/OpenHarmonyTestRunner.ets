import { TestRunner, abilityDelegatorRegistry } from '@kit.TestKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'OpenHarmonyTestRunner';
const DOMAIN = 0x0001;

let abilityDelegator: abilityDelegatorRegistry.AbilityDelegator | undefined = undefined;
let abilityDelegatorArguments: abilityDelegatorRegistry.AbilityDelegatorArgs | undefined = undefined;

async function onAbilityCreateCallback(): Promise<void> {
  hilog.info(DOMAIN, TAG, 'onAbilityCreateCallback');
}

async function addAbilityMonitorCallback(): Promise<void> {
  hilog.info(DOMAIN, TAG, 'addAbilityMonitorCallback');
}

export default class OpenHarmonyTestRunner implements TestRunner {
  constructor() {}

  onPrepare(): void {
    hilog.info(DOMAIN, TAG, 'OpenHarmonyTestRunner onPrepare');
  }

  async onRun(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'OpenHarmonyTestRunner onRun');
    abilityDelegatorArguments = abilityDelegatorRegistry.getArguments();
    abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();

    const bundleName = abilityDelegatorArguments.bundleName;
    const testAbilityName = 'TestAbility';

    const lMonitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: testAbilityName,
      onAbilityCreate: onAbilityCreateCallback,
    };
    abilityDelegator.addAbilityMonitor(lMonitor, addAbilityMonitorCallback);

    const want: Record<string, Object> = {};
    want['bundleName'] = bundleName;
    want['abilityName'] = testAbilityName;
    abilityDelegator.startAbility(want, (err) => {
      hilog.info(DOMAIN, TAG, 'startAbility: err=%{public}s', JSON.stringify(err));
    });

    hilog.info(DOMAIN, TAG, 'TestAbility started, hypium runs in its onCreate');
  }
}
