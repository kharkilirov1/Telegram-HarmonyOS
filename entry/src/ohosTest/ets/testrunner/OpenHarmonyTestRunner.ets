import { TestRunner, abilityDelegatorRegistry } from '@kit.TestKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Want } from '@kit.AbilityKit';

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
    const testModule = abilityDelegatorArguments.parameters['-m'];
    if (testModule !== 'entry_test') throw new Error('Test runner requires entry_test');
    const uiModule = abilityDelegatorArguments.parameters['-s nativeUiModule'];
    const moduleName = uiModule === undefined ? testModule : uiModule;
    hilog.info(DOMAIN, TAG, 'Test module argument type=%{public}s value=%{public}s',
      typeof moduleName, moduleName ?? '<missing>');
    if (moduleName !== 'entry_test' && moduleName !== 'entry') throw new Error('Invalid native UI module');
    if (moduleName === 'entry' && !/^com\.telegram\.harmonyos\.(slowmode|nativevalidation)[0-9]{8}$/.test(bundleName)) {
      throw new Error('Main-module validation requires an isolated verification bundle');
    }
    // Initialize the requested test module before its Ability/window can render,
    // using the supported synchronous API9 call in the official Runner template.
    // Native v10 did not reach the post-initialization log with the Promise API.
    hilog.info(DOMAIN, TAG, 'Before synchronous test module context %{public}s', moduleName);
    const moduleContext = abilityDelegator.getAppContext().getApplicationContext().createModuleContext(moduleName);
    const moduleResources = moduleContext.resourceManager;
    hilog.info(DOMAIN, TAG, 'Prepared test module %{public}s resourceDir=%{public}s managerType=%{public}s',
      moduleName, moduleContext.resourceDir, typeof moduleResources);

    const lMonitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: testAbilityName,
      onAbilityCreate: onAbilityCreateCallback,
      moduleName: moduleName,
    };
    abilityDelegator.addAbilityMonitor(lMonitor, addAbilityMonitorCallback);

    const want: Want = { bundleName: bundleName, abilityName: testAbilityName, moduleName: moduleName };
    abilityDelegator.startAbility(want, (err) => {
      hilog.info(DOMAIN, TAG, 'startAbility: err=%{public}s', JSON.stringify(err));
    });

    hilog.info(DOMAIN, TAG, 'TestAbility started, hypium runs in its onCreate');
  }
}
