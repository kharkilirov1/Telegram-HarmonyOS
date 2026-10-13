// Real ArkUI pages and actions with controlled local gateway/bootstrap only.
// No login/account creation or real Telegram delivery is performed.
import { describe, expect, it } from '@ohos/hypium';
import { Driver, ON, On, Component, UiWindow, abilityDelegatorRegistry } from '@kit.TestKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { GetSupergroupMembersCommand, SearchChatMembersCommand } from '../../../main/ets/core/model/AppCommand';
import { TG_CHAT_SEARCH_INPUT_ID } from '../../../main/ets/ui/tg_ui/atoms/TgChatTopBar';
import { SlowmodeNativeFixture } from '../testability/components/SlowmodeFixture';
import { StabilizationNativeFixture, StabilizationUiOwnership } from '../testability/components/StabilizationFixture';
import { AppCoreRuntime } from '../../../main/ets/app/bootstrap/AppCoreRuntime';

const CONTROLLED_IME_BUNDLE = 'com.huawei.hmos.inputmethod';
enum NativeUiPhase { Observing, OwnedCandidate, OwnedStable, ImeFirstUse, AfterCancel, AfterExit, OwnedClear, OwnedFixedKeyboard, TransientOrAmbiguous, Blocked }
let nativeUiTransactionSerial: number = 0;
let nativeUiActionSerial: number = 0;

class NativeUiObservation {
  readonly transaction: number = ++nativeUiTransactionSerial;
  readonly deadline: number;
  readonly expectedDepth: number;
  readonly moduleName: string = $r('app.color.background_primary').moduleName;
  readonly bundleName: string = abilityDelegatorRegistry.getArguments().bundleName;
  readonly owner: StabilizationUiOwnership;
  phase: NativeUiPhase = NativeUiPhase.Observing;
  samples: number = 0;
  staleHandles: number = 0;
  cancelActions: number = 0;
  exitActions: number = 0;
  appActions: number = 0;
  keyboardDismissActions: number = 0;
  navigationBackActions: number = 0;
  keyboardStaleHandles: number = 0;
  backAbility?: UIAbility;
  backWindowId?: number;
  keyboardAreaVisible: boolean = false;
  keyboardAreaPositive: boolean = false;
  keyboardPanel: string = 'unobserved';
  registryCode: number = 0;
  focusedBundle: string = '';
  constructor(expectedDepth: number, deadline: number = Date.now() + 10000) {
    this.expectedDepth = expectedDepth; this.deadline = Math.min(deadline, Date.now() + 10000);
    this.owner = StabilizationNativeFixture.captureUiOwnership(expectedDepth);
    if (!this.bundleName || !this.moduleName) throw new Error('Native observation has no captured bundle/module');
  }
}
function nativeUiPhaseName(phase: NativeUiPhase): string {
  switch (phase) {
    case NativeUiPhase.Observing: return 'Observing';
    case NativeUiPhase.OwnedCandidate: return 'OwnedCandidate';
    case NativeUiPhase.OwnedStable: return 'OwnedStable';
    case NativeUiPhase.ImeFirstUse: return 'ImeFirstUse';
    case NativeUiPhase.AfterCancel: return 'AfterCancel';
    case NativeUiPhase.AfterExit: return 'AfterExit';
    case NativeUiPhase.OwnedClear: return 'OWNED_CLEAR';
    case NativeUiPhase.OwnedFixedKeyboard: return 'OWNED_FIXED_KEYBOARD';
    case NativeUiPhase.TransientOrAmbiguous: return 'TRANSIENT_OR_AMBIGUOUS';
    default: return 'Blocked';
  }
}
function nativeUiTrace(observation: NativeUiObservation, event: string): void {
  console.info('[StabilizationNative] ownerTxn=' + observation.transaction.toString() +
    ' readSeq=' + observation.samples.toString() + ' phase=' + nativeUiPhaseName(observation.phase) +
    ' event=' + event + ' registryCode=' + observation.registryCode.toString() +
    ' focus=' + observation.focusedBundle + ' depth=' + StabilizationNativeFixture.navigationDepth().toString() +
    ' expectedDepth=' + observation.expectedDepth.toString() + ' module=' + observation.moduleName +
    ' cancel=' + observation.cancelActions.toString() + ' exit=' + observation.exitActions.toString() +
    ' appActions=' + observation.appActions.toString() + ' keyboardDismiss=' + observation.keyboardDismissActions.toString() +
    ' navigationBack=' + observation.navigationBackActions.toString() + ' keyboardStale=' + observation.keyboardStaleHandles.toString() +
    ' keyboardAreaVisible=' + observation.keyboardAreaVisible.toString() + ' keyboardAreaPositive=' + observation.keyboardAreaPositive.toString() +
    ' keyboardPanel=' + observation.keyboardPanel + ' mainWindowId=' + (observation.backWindowId ?? -1).toString());
}
function blockNativeUi(observation: NativeUiObservation, reason: string): void {
  observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, reason); throw new Error(reason);
}
function checkNativeUiIdentity(observation: NativeUiObservation): void {
  if (!StabilizationNativeFixture.isUiOwnershipCurrent(observation.owner)) blockNativeUi(observation, 'Native UI route/session identity changed');
  if (StabilizationNativeFixture.navigationDepth() !== observation.expectedDepth) blockNativeUi(observation, 'Native UI navigation depth changed');
}
function checkNativeUiObservation(observation: NativeUiObservation): void {
  checkNativeUiIdentity(observation);
  if (Date.now() >= observation.deadline) blockNativeUi(observation, 'Native UI observation deadline exhausted');
}
async function delayNativeObservation(driver: Driver, observation: NativeUiObservation): Promise<void> {
  checkNativeUiObservation(observation);
  await driver.delayMs(Math.min(250, observation.deadline - Date.now()));
  checkNativeUiObservation(observation);
}
function checkNativeUiSampleAdmission(observation: NativeUiObservation): void {
  checkNativeUiObservation(observation);
  if (observation.samples >= 40) blockNativeUi(observation, 'Native UI observation sample limit exhausted');
}
async function readFocusedBundle(driver: Driver, observation: NativeUiObservation): Promise<string | undefined> {
  checkNativeUiSampleAdmission(observation);
  observation.samples++;
  let focused: UiWindow | undefined;
  try { focused = await driver.findWindow({ focused: true }); }
  catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'findWindow-failed'); throw error as Error; }
  checkNativeUiObservation(observation);
  if (focused === undefined || focused === null) {
    observation.focusedBundle = ''; nativeUiTrace(observation, 'focus-absent'); return undefined;
  }
  let bundle: string;
  let isFocused: boolean;
  try {
    bundle = await focused.getBundleName();
    checkNativeUiObservation(observation);
    isFocused = await focused.isFocused();
  } catch (error) {
    checkNativeUiObservation(observation);
    const cause = error as BusinessError;
    if (cause.code !== 17000004) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'focus-property-failed'); throw error as Error; }
    observation.staleHandles++; observation.focusedBundle = '';
    nativeUiTrace(observation, 'focus-handle-destroyed');
    if (observation.staleHandles >= 3) blockNativeUi(observation, 'Native UI destroyed-handle limit exhausted');
    return undefined;
  }
  checkNativeUiObservation(observation);
  observation.staleHandles = 0; observation.focusedBundle = bundle;
  if (!isFocused) { observation.focusedBundle = ''; nativeUiTrace(observation, 'focus-handle-background'); return undefined; }
  nativeUiTrace(observation, 'focus-observed');
  if (bundle !== observation.bundleName && bundle !== CONTROLLED_IME_BUNDLE) blockNativeUi(observation, 'Native UI has foreign focused owner');
  return bundle;
}
function validateNativeAbility(ability: UIAbility, observation: NativeUiObservation): void {
  if (ability.context.abilityInfo.name !== 'TestAbility' ||
    ability.context.abilityInfo.bundleName !== observation.bundleName ||
    ability.context.currentHapModuleInfo.name !== observation.moduleName) blockNativeUi(observation, 'Native registry ability/module/bundle mismatch');
}
class NativeImePage {
  kind: 'firstUse' | 'confirmation' | 'unknown' = 'unknown';
  cancel?: Component;
  exit?: Component;
}
async function findImeComponent(driver: Driver, selector: On, observation: NativeUiObservation): Promise<Component | undefined> {
  checkNativeUiObservation(observation);
  const found = await driver.findComponent(selector);
  checkNativeUiObservation(observation);
  return found === null ? undefined : found;
}
async function readKnownImePage(driver: Driver, observation: NativeUiObservation): Promise<NativeImePage> {
  const page = new NativeImePage();
  const cancel = await findImeComponent(driver, ON.id('Paf.Permission.button_cancel').text('Cancel').inWindow(CONTROLLED_IME_BUNDLE), observation);
  const agree = await findImeComponent(driver, ON.text('Agree').inWindow(CONTROLLED_IME_BUNDLE), observation);
  let title = await findImeComponent(driver, ON.text('Клавиатура Celia').inWindow(CONTROLLED_IME_BUNDLE), observation);
  if (title === undefined) title = await findImeComponent(driver, ON.text('Celia Keyboard').inWindow(CONTROLLED_IME_BUNDLE), observation);
  const exit = await findImeComponent(driver, ON.id('advanced_dialog_button_2').text('Exit app').inWindow(CONTROLLED_IME_BUNDLE), observation);
  const full = await findImeComponent(driver, ON.text('Use Full mode').inWindow(CONTROLLED_IME_BUNDLE), observation);
  const basic = await findImeComponent(driver, ON.text('Use Basic mode').inWindow(CONTROLLED_IME_BUNDLE), observation);
  if (cancel !== undefined && agree !== undefined && title !== undefined && exit === undefined) { page.kind = 'firstUse'; page.cancel = cancel; }
  if (exit !== undefined && full !== undefined && basic !== undefined) { page.kind = 'confirmation'; page.exit = exit; }
  return page;
}
async function performKnownImeStep(driver: Driver, observation: NativeUiObservation): Promise<void> {
  const page = await readKnownImePage(driver, observation);
  checkNativeUiObservation(observation);
  const freshBundle = await readFocusedBundle(driver, observation);
  if (freshBundle !== CONTROLLED_IME_BUNDLE) {
    if (freshBundle === observation.bundleName && observation.cancelActions !== 0 && observation.exitActions === 0)
      blockNativeUi(observation, 'Known IME returned without expected Exit confirmation');
    observation.phase = observation.exitActions !== 0 ? NativeUiPhase.AfterExit : observation.cancelActions !== 0 ? NativeUiPhase.AfterCancel : NativeUiPhase.Observing;
    nativeUiTrace(observation, 'ime-selector-sample-discarded'); return;
  }
  if (page.kind === 'unknown') blockNativeUi(observation, 'Known IME page is not the observed first-use/Exit confirmation');
  if (observation.exitActions !== 0) {
    if (page.kind === 'firstUse') blockNativeUi(observation, 'Known IME renewed after the single Exit');
    observation.phase = NativeUiPhase.AfterExit; return;
  }
  if (observation.cancelActions === 0) {
    if (page.kind !== 'firstUse' || page.cancel === undefined) blockNativeUi(observation, 'Known IME confirmation has no owned Cancel history');
    observation.phase = NativeUiPhase.ImeFirstUse; observation.cancelActions++;
    nativeUiTrace(observation, 'action-' + (++nativeUiActionSerial).toString() + '-Cancel');
    try { await page.cancel!.click(); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'Cancel-failed-no-replay'); throw error as Error; }
    checkNativeUiObservation(observation); observation.phase = NativeUiPhase.AfterCancel; return;
  }
  if (page.kind === 'firstUse') { observation.phase = NativeUiPhase.AfterCancel; return; }
  if (page.exit === undefined) blockNativeUi(observation, 'Known IME Exit target absent');
  observation.exitActions++; nativeUiTrace(observation, 'action-' + (++nativeUiActionSerial).toString() + '-Exit');
  try { await page.exit!.click(); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'Exit-failed-no-replay'); throw error as Error; }
  checkNativeUiObservation(observation); observation.phase = NativeUiPhase.AfterExit;
}
async function acquireOwnedUiContext(driver: Driver, expectedDepth: number, shared?: NativeUiObservation): Promise<UIAbility> {
  const observation = shared ?? new NativeUiObservation(expectedDepth);
  if (observation.expectedDepth !== expectedDepth) blockNativeUi(observation, 'Native UI transaction depth mismatch');
  let candidate: UIAbility | undefined = undefined;
  while (true) {
    checkNativeUiSampleAdmission(observation);
    let ability: UIAbility | undefined = undefined;
    observation.registryCode = 0;
    try {
      ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
      checkNativeUiObservation(observation);
    } catch (error) {
      checkNativeUiObservation(observation);
      const cause = error as BusinessError;
      if (cause.code !== 16000100) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'registry-failed'); throw error as Error; }
      observation.registryCode = 16000100; nativeUiTrace(observation, 'registry-transient');
    }
    if (ability !== undefined && ability !== null) validateNativeAbility(ability, observation);
    const focused = await readFocusedBundle(driver, observation);
    checkNativeUiObservation(observation);
    if (focused === CONTROLLED_IME_BUNDLE) {
      candidate = undefined; await performKnownImeStep(driver, observation); checkNativeUiObservation(observation);
    } else if (focused === observation.bundleName && ability !== undefined && ability !== null && observation.registryCode === 0) {
      if (observation.cancelActions !== 0 && observation.exitActions === 0) blockNativeUi(observation, 'Known IME returned without expected Exit confirmation');
      if (candidate === ability) {
        observation.phase = NativeUiPhase.OwnedStable; nativeUiTrace(observation, 'owned-coherent-two-samples'); return ability;
      }
      candidate = ability; observation.phase = NativeUiPhase.OwnedCandidate; nativeUiTrace(observation, 'owned-candidate');
    } else {
      candidate = undefined;
      observation.phase = observation.exitActions !== 0 ? NativeUiPhase.AfterExit : observation.cancelActions !== 0 ? NativeUiPhase.AfterCancel : NativeUiPhase.Observing;
      nativeUiTrace(observation, 'partial-sample-invalidated');
    }
    await delayNativeObservation(driver, observation);
  }
}
async function requireControlledUiOwner(driver: Driver, expectedDepth: number): Promise<UIAbility> {
  return acquireOwnedUiContext(driver, expectedDepth);
}
async function dismissKnownImeFirstUse(driver: Driver, expectedDepth: number): Promise<boolean> {
  const observation = new NativeUiObservation(expectedDepth);
  await acquireOwnedUiContext(driver, expectedDepth, observation);
  return observation.cancelActions === 1 && observation.exitActions === 1;
}
function recordOwnedAction(observation: NativeUiObservation, action: string): void {
  checkNativeUiObservation(observation);
  if (observation.phase !== NativeUiPhase.OwnedStable) blockNativeUi(observation, 'Native app action has no complete owner proof');
  observation.appActions++; nativeUiTrace(observation, 'action-' + (++nativeUiActionSerial).toString() + '-' + action);
}
async function refreshTargetAfterIme(driver: Driver, target: Component, targetId: string | undefined,
  observation: NativeUiObservation, declinedBefore: number): Promise<Component> {
  if (observation.cancelActions === declinedBefore) return target;
  if (targetId === undefined) blockNativeUi(observation, 'Interrupted target has no explicit reacquisition selector');
  const fresh = await driver.waitForComponent(ON.id(targetId!), Math.min(5000, observation.deadline - Date.now()));
  checkNativeUiObservation(observation);
  await acquireOwnedUiContext(driver, observation.expectedDepth, observation);
  if (fresh === undefined || fresh === null) blockNativeUi(observation, 'Actual target absent after known IME decline');
  return fresh!;
}
async function clickOwnedComponent(driver: Driver, target: Component, expectedDepth: number, action: string, targetId?: string): Promise<void> {
  const observation = new NativeUiObservation(expectedDepth);
  const declinedBefore = observation.cancelActions;
  await acquireOwnedUiContext(driver, expectedDepth, observation);
  const ownedTarget = observation.cancelActions === declinedBefore ? target :
    await refreshTargetAfterIme(driver, target, targetId, observation, declinedBefore);
  checkNativeUiObservation(observation); recordOwnedAction(observation, action);
  try { await ownedTarget.click(); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, action + '-failed-no-replay'); throw error as Error; }
}
async function inputOwnedText(driver: Driver, target: Component, text: string, expectedDepth: number, targetId?: string): Promise<void> {
  const observation = new NativeUiObservation(expectedDepth);
  const declinedBefore = observation.cancelActions;
  await acquireOwnedUiContext(driver, expectedDepth, observation);
  const ownedTarget = observation.cancelActions === declinedBefore ? target :
    await refreshTargetAfterIme(driver, target, targetId, observation, declinedBefore);
  checkNativeUiObservation(observation); recordOwnedAction(observation, 'inputText');
  try { await ownedTarget.inputText(text); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'inputText-failed-no-replay'); throw error as Error; }
  checkNativeUiIdentity(observation);
}
async function guardOwnedAction(driver: Driver, expectedDepth: number, action: string): Promise<NativeUiObservation> {
  const observation = new NativeUiObservation(expectedDepth);
  await acquireOwnedUiContext(driver, expectedDepth, observation); recordOwnedAction(observation, action);
  return observation;
}
async function ownedWaitForComponent(driver: Driver, selector: On, timeout: number, expectedDepth: number): Promise<Component | undefined> {
  const observation = new NativeUiObservation(expectedDepth);
  await acquireOwnedUiContext(driver, expectedDepth, observation);
  const result = await driver.waitForComponent(selector, Math.min(timeout, observation.deadline - Date.now()));
  checkNativeUiObservation(observation); await acquireOwnedUiContext(driver, expectedDepth, observation);
  return result === null ? undefined : result;
}
async function ownedText(driver: Driver, target: Component, expectedDepth: number): Promise<string> {
  const observation = new NativeUiObservation(expectedDepth);
  await acquireOwnedUiContext(driver, expectedDepth, observation);
  const text = await target.getText(); checkNativeUiObservation(observation);
  await acquireOwnedUiContext(driver, expectedDepth, observation); return text;
}
async function prepareOwnedGestureTarget(driver: Driver, target: Component, targetId: string, observation: NativeUiObservation): Promise<Component> {
  const declinedBefore = observation.cancelActions;
  await acquireOwnedUiContext(driver, observation.expectedDepth, observation);
  const ownedTarget = observation.cancelActions === declinedBefore ? target :
    await refreshTargetAfterIme(driver, target, targetId, observation, declinedBefore);
  checkNativeUiObservation(observation); return ownedTarget;
}
async function scrollOwnedToBottom(driver: Driver, target: Component, speed: number, expectedDepth: number, targetId: string): Promise<void> {
  const observation = new NativeUiObservation(expectedDepth);
  const ownedTarget = await prepareOwnedGestureTarget(driver, target, targetId, observation);
  recordOwnedAction(observation, 'scrollToBottom');
  try { await ownedTarget.scrollToBottom(speed); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'scrollToBottom-failed-no-replay'); throw error as Error; }
  checkNativeUiIdentity(observation);
}
async function scrollOwnedToTop(driver: Driver, target: Component, speed: number, expectedDepth: number, targetId: string): Promise<void> {
  const observation = new NativeUiObservation(expectedDepth);
  const ownedTarget = await prepareOwnedGestureTarget(driver, target, targetId, observation);
  recordOwnedAction(observation, 'scrollToTop');
  try { await ownedTarget.scrollToTop(speed); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'scrollToTop-failed-no-replay'); throw error as Error; }
  checkNativeUiIdentity(observation);
}
async function scrollOwnedSearch(driver: Driver, target: Component, selector: On, expectedDepth: number, targetId: string): Promise<Component | undefined> {
  const observation = new NativeUiObservation(expectedDepth);
  const ownedTarget = await prepareOwnedGestureTarget(driver, target, targetId, observation);
  recordOwnedAction(observation, 'scrollSearch');
  let found: Component | undefined;
  try { found = await ownedTarget.scrollSearch(selector); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'scrollSearch-failed-no-replay'); throw error as Error; }
  checkNativeUiIdentity(observation); return found === null ? undefined : found;
}
async function controlledInputAfterFocus(driver: Driver, id: string): Promise<Component> {
  const depth = StabilizationNativeFixture.navigationDepth(); const observation = new NativeUiObservation(depth);
  await acquireOwnedUiContext(driver, depth, observation);
  const declinedBeforeLookup = observation.cancelActions;
  let input = await driver.waitForComponent(ON.id(id), Math.min(5000, observation.deadline - Date.now()));
  checkNativeUiObservation(observation);
  await acquireOwnedUiContext(driver, depth, observation);
  if (observation.cancelActions > declinedBeforeLookup) {
    input = await driver.waitForComponent(ON.id(id), Math.min(5000, observation.deadline - Date.now()));
    checkNativeUiObservation(observation); await acquireOwnedUiContext(driver, depth, observation);
  }
  if (input === undefined || input === null) blockNativeUi(observation, 'Actual controlled input absent id=' + id);
  return input!;
}
async function waitCondition(driver: Driver, callback: () => boolean, label: string): Promise<void> {
  const deadline = Date.now() + 10000;
  while (Date.now() < deadline) { if (callback()) return; await driver.delayMs(50); }
  throw new Error('Stabilization native condition timed out: ' + label);
}
async function rootReady(driver: Driver, shared?: NativeUiObservation): Promise<void> {
  const deadline = shared?.deadline ?? Date.now() + 12000;
  while (Date.now() < deadline) {
    if (StabilizationNativeFixture.navigationBound() && SlowmodeNativeFixture.configurationReady()) {
      if (StabilizationNativeFixture.navigationDepth() !== 0) throw new Error('Native stabilization starts only on the actual empty Index stack');
      const observation = shared ?? new NativeUiObservation(0, deadline);
      await acquireOwnedUiContext(driver, 0, observation); checkNativeUiObservation(observation);
      const root = await driver.waitForComponent(ON.id('chat-test-fixture-scroll'), Math.min(1000, observation.deadline - Date.now()));
      checkNativeUiObservation(observation);
      if (root !== undefined && root !== null) { await acquireOwnedUiContext(driver, 0, observation); return; }
      blockNativeUi(observation, 'Actual owned Index root is absent');
    }
    if (shared !== undefined) checkNativeUiObservation(shared);
    await driver.delayMs(Math.min(100, deadline - Date.now()));
    if (shared !== undefined) checkNativeUiIdentity(shared);
  }
  throw new Error('Actual compiled-module TestAbility/Index did not mount');
}
async function component(driver: Driver, id: string): Promise<Component> {
  const depth = StabilizationNativeFixture.navigationDepth(); const owner = StabilizationNativeFixture.captureUiOwnership(depth);
  const result = await driver.waitForComponent(ON.id(id), 5000);
  if (!StabilizationNativeFixture.isUiOwnershipCurrent(owner)) throw new Error('Component lookup changed owned UI route/session');
  if (result === undefined || result === null) throw new Error('Actual component absent id=' + id); return result;
}
async function open(driver: Driver, id: string): Promise<void> {
  const depth = StabilizationNativeFixture.navigationDepth(); const observation = new NativeUiObservation(depth);
  const root = await component(driver, 'chat-test-fixture-scroll'); checkNativeUiObservation(observation);
  const declinedBeforeRoot = observation.cancelActions;
  await acquireOwnedUiContext(driver, depth, observation);
  const ownedRoot = observation.cancelActions === declinedBeforeRoot ? root :
    await refreshTargetAfterIme(driver, root, 'chat-test-fixture-scroll', observation, declinedBeforeRoot);
  checkNativeUiObservation(observation); recordOwnedAction(observation, 'route-scrollSearch');
  const button = await ownedRoot.scrollSearch(ON.id(id)); checkNativeUiIdentity(observation);
  if (button === undefined || button === null) throw new Error('Native fixture route button absent');
  const declinedBeforeButton = observation.cancelActions;
  await acquireOwnedUiContext(driver, depth, observation);
  const ownedButton = observation.cancelActions === declinedBeforeButton ? button :
    await refreshTargetAfterIme(driver, button, id, observation, declinedBeforeButton);
  checkNativeUiObservation(observation); recordOwnedAction(observation, 'route-click');
  try { await ownedButton.click(); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'route-click-failed-no-replay'); throw error as Error; }
  await waitCondition(driver, (): boolean => StabilizationNativeFixture.navigationDepth() === 1, 'owned route push');
  if (!await driver.waitForIdle(200, 3000)) throw new Error('Actual route transition did not become idle');
}
async function screenshot(driver: Driver, name: string): Promise<void> {
  const depth = StabilizationNativeFixture.navigationDepth(); const observation = new NativeUiObservation(depth);
  const ability = await acquireOwnedUiContext(driver, depth, observation);
  const label = abilityDelegatorRegistry.getArguments().parameters['-s nativeRunLabel'];
  if (label === undefined || !/^[a-z0-9-]+$/.test(label)) throw new Error('Native run label missing/invalid');
  const mode = ability.context.resourceManager.getConfigurationSync().colorMode;
  const path = ability.context.filesDir + '/' + label + '-stabilization-' + name + '.png';
  console.info('[StabilizationNative] screenshot=' + path + ' module=' + ability.context.currentHapModuleInfo.name + ' colorMode=' + mode.toString());
  recordOwnedAction(observation, 'screenCap');
  try { expect(await driver.screenCap(path)).assertTrue(); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'screenCap-failed-no-replay'); throw error as Error; }
  checkNativeUiIdentity(observation);
}
enum NativeBackKeyboardState { Clear, FixedKeyboard, Transient }
class NativeBackKeyboardSample {
  state: NativeBackKeyboardState = NativeBackKeyboardState.Transient;
  ability?: UIAbility;
  windowId?: number;
}
async function readBackAbility(observation: NativeUiObservation): Promise<UIAbility | undefined> {
  checkNativeUiSampleAdmission(observation); observation.registryCode = 0;
  let ability: UIAbility | undefined;
  try { ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility(); }
  catch (error) {
    checkNativeUiObservation(observation);
    const cause = error as BusinessError;
    if (cause.code !== 16000100) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'back-registry-failed'); throw error as Error; }
    observation.registryCode = 16000100; nativeUiTrace(observation, 'back-registry-transient'); return undefined;
  }
  checkNativeUiObservation(observation);
  if (ability === undefined || ability === null) return undefined;
  validateNativeAbility(ability, observation);
  if (observation.backAbility !== undefined && observation.backAbility !== ability) blockNativeUi(observation, 'Back ability identity changed');
  return ability;
}
function positiveKeyboardArea(area: window.AvoidArea, observation: NativeUiObservation): boolean {
  const rects: window.Rect[] = [area.leftRect, area.topRect, area.rightRect, area.bottomRect];
  let positive: boolean = false;
  for (const rect of rects) {
    if (!Number.isFinite(rect.width) || !Number.isFinite(rect.height) || rect.width < 0 || rect.height < 0)
      blockNativeUi(observation, 'Keyboard avoid-area geometry is invalid');
    if (rect.width > 0 && rect.height > 0) positive = true;
  }
  // Legacy TYPE_KEYBOARD visible describes the area category, even for empty rects.
  if (typeof area.visible !== 'boolean' || (positive && !area.visible))
    blockNativeUi(observation, 'Keyboard avoid-area visibility/geometry is ambiguous');
  observation.keyboardAreaVisible = area.visible; observation.keyboardAreaPositive = positive;
  return positive;
}
function readBackKeyboardArea(mainWindow: window.Window, observation: NativeUiObservation): boolean {
  checkNativeUiObservation(observation);
  const area = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
  checkNativeUiObservation(observation);
  return positiveKeyboardArea(area, observation);
}
function verifyBackMainWindow(mainWindow: window.Window, ability: UIAbility, observation: NativeUiObservation): number {
  checkNativeUiObservation(observation);
  const properties = mainWindow.getWindowProperties(); checkNativeUiObservation(observation);
  // Legacy type=1 is shared with alerts; exact Stage identity proves the main window.
  const stage = ability.context.windowStage; checkNativeUiObservation(observation);
  const stageMain = stage.getMainWindowSync(); checkNativeUiObservation(observation);
  const mainProperties = stageMain.getWindowProperties(); checkNativeUiObservation(observation);
  if (!Number.isSafeInteger(properties.id) || properties.id <= 0 ||
    !Number.isSafeInteger(mainProperties.id) || mainProperties.id <= 0)
    blockNativeUi(observation, 'Back main-window identity is invalid');
  if (properties.id !== mainProperties.id) blockNativeUi(observation, 'Back window is not the authoritative Stage main window');
  if (properties.windowType !== undefined && properties.windowType !== window.WindowType.TYPE_MAIN)
    blockNativeUi(observation, 'Back keyboard observation is not the main app window');
  if (properties.windowType === undefined && properties.type !== window.WindowType.TYPE_SYSTEM_ALERT)
    blockNativeUi(observation, 'Back keyboard legacy main-window type is invalid');
  if (observation.backWindowId !== undefined && observation.backWindowId !== properties.id) blockNativeUi(observation, 'Back main-window identity changed');
  return properties.id;
}
async function readVisibleKeyboardPanel(driver: Driver, observation: NativeUiObservation): Promise<boolean | undefined> {
  checkNativeUiObservation(observation);
  let panel: UiWindow | undefined;
  try { panel = await driver.findWindow({ bundleName: CONTROLLED_IME_BUNDLE }); }
  catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'keyboard-window-query-failed'); throw error as Error; }
  checkNativeUiObservation(observation);
  if (panel === undefined || panel === null) { observation.keyboardPanel = 'absent'; return false; }
  try {
    const bundle = await panel.getBundleName(); checkNativeUiObservation(observation);
    if (bundle !== CONTROLLED_IME_BUNDLE) blockNativeUi(observation, 'Keyboard window has foreign bundle');
    const bounds = await panel.getBounds(); checkNativeUiObservation(observation);
    if (!Number.isFinite(bounds.left) || !Number.isFinite(bounds.top) || !Number.isFinite(bounds.right) || !Number.isFinite(bounds.bottom) ||
      bounds.right <= bounds.left || bounds.bottom <= bounds.top) blockNativeUi(observation, 'Keyboard window bounds are ambiguous');
    const focused = await panel.isFocused(); checkNativeUiObservation(observation);
    if (focused) { observation.keyboardPanel = 'focused'; return undefined; }
    observation.keyboardPanel = 'visible-nonfocused'; return true;
  } catch (error) {
    checkNativeUiObservation(observation);
    const cause = error as BusinessError;
    if (cause.code !== 17000004) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'keyboard-window-property-failed'); throw error as Error; }
    observation.keyboardStaleHandles++; observation.keyboardPanel = 'invisible-or-destroyed';
    nativeUiTrace(observation, 'keyboard-window-sample-invalidated');
    if (observation.keyboardStaleHandles >= 3) blockNativeUi(observation, 'Back keyboard destroyed-handle limit exhausted');
    return undefined;
  }
}
async function readBackKeyboardSample(driver: Driver, observation: NativeUiObservation): Promise<NativeBackKeyboardSample> {
  const sample = new NativeBackKeyboardSample();
  const ability = await readBackAbility(observation);
  const focused = await readFocusedBundle(driver, observation); checkNativeUiObservation(observation);
  if (focused === CONTROLLED_IME_BUNDLE) {
    if (observation.keyboardDismissActions !== 0) blockNativeUi(observation, 'Keyboard became focused after the single dismissal');
    await performKnownImeStep(driver, observation); checkNativeUiObservation(observation); return sample;
  }
  if (focused !== observation.bundleName || ability === undefined || observation.registryCode !== 0) return sample;
  if (observation.cancelActions !== 0 && observation.exitActions === 0) blockNativeUi(observation, 'Known IME returned without expected Exit confirmation');
  if (observation.backAbility === undefined) observation.backAbility = ability;
  checkNativeUiObservation(observation);
  const mainWindow = await window.getLastWindow(ability.context); checkNativeUiObservation(observation);
  const windowId = verifyBackMainWindow(mainWindow, ability, observation);
  if (observation.backWindowId === undefined) observation.backWindowId = windowId;
  const before = readBackKeyboardArea(mainWindow, observation);
  const panel = await readVisibleKeyboardPanel(driver, observation); checkNativeUiObservation(observation);
  if (panel === undefined) return sample;
  const finalAbility = await readBackAbility(observation);
  if (finalAbility === undefined || observation.registryCode !== 0) return sample;
  if (finalAbility !== ability) blockNativeUi(observation, 'Back ability changed during keyboard sample');
  checkNativeUiObservation(observation);
  const finalMainWindow = await window.getLastWindow(finalAbility.context); checkNativeUiObservation(observation);
  if (verifyBackMainWindow(finalMainWindow, finalAbility, observation) !== windowId) blockNativeUi(observation, 'Back main-window changed during keyboard sample');
  const finalFocus = await readFocusedBundle(driver, observation); checkNativeUiObservation(observation);
  if (finalFocus !== observation.bundleName) return sample;
  const after = readBackKeyboardArea(finalMainWindow, observation);
  if (before !== after) { nativeUiTrace(observation, 'keyboard-area-change-sample-discarded'); return sample; }
  if (after !== panel) blockNativeUi(observation, 'Keyboard area/panel disagreement is ambiguous');
  sample.state = after ? NativeBackKeyboardState.FixedKeyboard : NativeBackKeyboardState.Clear;
  sample.ability = ability; sample.windowId = windowId;
  nativeUiTrace(observation, after ? 'keyboard-combined-fixed-sample' : 'keyboard-combined-clear-sample');
  return sample;
}
async function acquireBackKeyboardState(driver: Driver, observation: NativeUiObservation, requireClear: boolean): Promise<NativeBackKeyboardSample> {
  let candidate: NativeBackKeyboardSample | undefined;
  let observedClear: boolean = false;
  while (true) {
    const sample = await readBackKeyboardSample(driver, observation); checkNativeUiObservation(observation);
    if (requireClear && sample.state === NativeBackKeyboardState.FixedKeyboard) {
      if (observedClear) blockNativeUi(observation, 'Keyboard reappeared after dismissal');
      candidate = undefined; observation.phase = NativeUiPhase.TransientOrAmbiguous;
      nativeUiTrace(observation, 'keyboard-dismissal-pending');
    } else if (sample.state === NativeBackKeyboardState.Transient) {
      candidate = undefined; observation.phase = NativeUiPhase.TransientOrAmbiguous;
      nativeUiTrace(observation, 'back-combined-sample-invalidated');
    } else {
      if (requireClear) observedClear = true;
      if (candidate !== undefined && candidate.state === sample.state && candidate.ability === sample.ability && candidate.windowId === sample.windowId) {
        observation.phase = sample.state === NativeBackKeyboardState.Clear ? NativeUiPhase.OwnedClear : NativeUiPhase.OwnedFixedKeyboard;
        nativeUiTrace(observation, 'back-combined-two-coherent-samples'); return sample;
      }
      candidate = sample; observation.phase = NativeUiPhase.OwnedCandidate;
      nativeUiTrace(observation, 'back-combined-candidate');
    }
    await delayNativeObservation(driver, observation);
  }
}
function recordBackAction(observation: NativeUiObservation, keyboardDismiss: boolean): void {
  checkNativeUiObservation(observation);
  if (keyboardDismiss) {
    if (observation.phase !== NativeUiPhase.OwnedFixedKeyboard || observation.keyboardDismissActions !== 0 || observation.navigationBackActions !== 0)
      blockNativeUi(observation, 'KeyboardDismiss has no single owned fixed-keyboard proof');
    observation.keyboardDismissActions++;
  } else {
    if (observation.phase !== NativeUiPhase.OwnedClear || observation.navigationBackActions !== 0)
      blockNativeUi(observation, 'NavigationBack has no single owned-clear proof');
    observation.navigationBackActions++;
  }
  observation.appActions++;
  nativeUiTrace(observation, 'action-' + (++nativeUiActionSerial).toString() + (keyboardDismiss ? '-KeyboardDismiss' : '-NavigationBack'));
}
async function awaitExactBackPop(driver: Driver, observation: NativeUiObservation): Promise<void> {
  while (true) {
    if (StabilizationNativeFixture.isUiOwnershipPopped(observation.owner)) { nativeUiTrace(observation, 'exact-owned-route-pop'); return; }
    checkNativeUiObservation(observation);
    await driver.delayMs(Math.min(50, observation.deadline - Date.now()));
  }
}
async function back(driver: Driver, runningOwner?: AppCoreRuntime): Promise<void> {
  const depth = StabilizationNativeFixture.navigationDepth(); if (depth <= 0) throw new Error('No owned route to pop');
  const observation = new NativeUiObservation(depth);
  const state = await acquireBackKeyboardState(driver, observation, false);
  if (state.state === NativeBackKeyboardState.FixedKeyboard) {
    recordBackAction(observation, true);
    try { await driver.pressBack(); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'KeyboardDismiss-failed-no-replay'); throw error as Error; }
    checkNativeUiIdentity(observation);
    await acquireBackKeyboardState(driver, observation, true);
  }
  if (runningOwner !== undefined) expect(runningOwner.isPipelineRunning()).assertTrue();
  recordBackAction(observation, false);
  try { await driver.pressBack(); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'NavigationBack-failed-no-replay'); throw error as Error; }
  await awaitExactBackPop(driver, observation);
  if (!StabilizationNativeFixture.isUiOwnershipPopped(observation.owner)) blockNativeUi(observation, 'Exact Back successor changed before capture');
  expect(StabilizationNativeFixture.navigationDepth()).assertEqual(depth - 1);
  const successor = new NativeUiObservation(depth - 1);
  await acquireOwnedUiContext(driver, depth - 1, successor); checkNativeUiObservation(successor);
  if (!await driver.waitForIdle(200, 3000)) throw new Error('Back transition did not become idle');
  checkNativeUiIdentity(successor);
  if (depth === 1) await rootReady(driver, successor);
}
async function absentText(driver: Driver, text: string): Promise<void> {
  const depth = StabilizationNativeFixture.navigationDepth(); const observation = new NativeUiObservation(depth);
  await acquireOwnedUiContext(driver, depth, observation);
  const found = await driver.findComponents(ON.text(text)); checkNativeUiObservation(observation);
  await acquireOwnedUiContext(driver, depth, observation);
  expect(found === undefined || found === null || found.length === 0).assertTrue();
}
async function repeatTap(driver: Driver, target: Component, targetId?: string): Promise<void> {
  const depth = StabilizationNativeFixture.navigationDepth(); const observation = new NativeUiObservation(depth);
  const declinedBefore = observation.cancelActions;
  let point = await target.getBoundsCenter(); checkNativeUiObservation(observation);
  await acquireOwnedUiContext(driver, depth, observation);
  const ownedTarget = observation.cancelActions === declinedBefore ? target :
    await refreshTargetAfterIme(driver, target, targetId, observation, declinedBefore);
  checkNativeUiObservation(observation);
  if (observation.cancelActions > declinedBefore) {
    point = await ownedTarget.getBoundsCenter(); checkNativeUiObservation(observation);
    await acquireOwnedUiContext(driver, depth, observation);
  }
  recordOwnedAction(observation, 'repeatTap-component');
  try { await ownedTarget.click(); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'repeatTap-component-failed-no-replay'); throw error as Error; }
  checkNativeUiIdentity(observation);
  const declinedAfterFirstClick = observation.cancelActions;
  await acquireOwnedUiContext(driver, depth, observation);
  if (observation.cancelActions !== declinedAfterFirstClick) blockNativeUi(observation, 'Double tap interrupted by a new external IME decline');
  recordOwnedAction(observation, 'repeatTap-coordinate');
  try { await driver.click(point.x, point.y); } catch (error) { observation.phase = NativeUiPhase.Blocked; nativeUiTrace(observation, 'repeatTap-coordinate-failed-no-replay'); throw error as Error; }
  checkNativeUiIdentity(observation);
}
export default function stabilizationNativeTest() {
  const selection = abilityDelegatorRegistry.getArguments().parameters['-s nativeStabilizationSelection'];
  if (selection !== undefined && selection !== 'startup' && selection !== 'pagination') throw new Error('Invalid nativeStabilizationSelection');
  const registerNativeCase = (name: string, flag: number, callback: () => Promise<void>): void => {
    if (selection === 'startup' && name !== 'mounted startup rejection before appearance supports explicit repeated Retry and Back' && name !== 'mounted startup rejection after appearance supports explicit repeated Retry and Back') return;
    if (selection === 'pagination' && name !== 'actual members pagination error retains rows and explicit Retry repeats only failed cursor') return;
    it(name, flag, callback);
  };
  describe('StabilizationNative', () => {
    for (const beforeMount of [true, false]) {
      registerNativeCase('mounted startup rejection ' + (beforeMount ? 'before' : 'after') + ' appearance supports explicit repeated Retry and Back', 0, async () => {
        const driver = Driver.create(); await rootReady(driver); await StabilizationNativeFixture.prepareStartup();
        const runtime = StabilizationNativeFixture.runtime(); const store = runtime.getLifecycleStore();
        if (beforeMount) { StabilizationNativeFixture.failStartup(); await StabilizationNativeFixture.initialStartupSettled(); }
        await open(driver, 'stabilization-open-startup');
        if (!beforeMount) { StabilizationNativeFixture.failStartup(); await StabilizationNativeFixture.initialStartupSettled(); }
        await component(driver, 'loginRecoveryError'); await screenshot(driver, beforeMount ? 'startup-before-error' : 'startup-after-error');
        await repeatTap(driver, await component(driver, 'loginRecoveryRetry'), 'loginRecoveryRetry');
        await waitCondition(driver, (): boolean => StabilizationNativeFixture.initializeCalls() === 2, 'native Retry actual initialize');
        expect(StabilizationNativeFixture.runtime().getLifecycleStore() === store).assertTrue();
        expect(StabilizationNativeFixture.initializeCalls()).assertEqual(2);
        StabilizationNativeFixture.completeStartup();
        await waitCondition(driver, (): boolean => store.getState().auth.status === 'waitPhoneNumber', 'actual auth update after controlled recovery');
        await driver.delayMs(400); await screenshot(driver, beforeMount ? 'startup-before-recovered' : 'startup-after-recovered');
        StabilizationNativeFixture.forbidTransportProof();
        await back(driver, runtime); await StabilizationNativeFixture.waitRetired(runtime);
        expect(runtime.isPipelineRunning()).assertFalse();
      });
    }
    registerNativeCase('native Back during explicit retirement Retry prevents late reinitialization', 0, async () => {
      const driver = Driver.create(); await rootReady(driver); await StabilizationNativeFixture.prepareStartup(true);
      const runtime = StabilizationNativeFixture.runtime();
      await open(driver, 'stabilization-open-startup'); StabilizationNativeFixture.failStartup();
      await waitCondition(driver, (): boolean => StabilizationNativeFixture.destroyCalls() === 1, 'initial cleanup entered');
      StabilizationNativeFixture.settleRetirement(false); await StabilizationNativeFixture.initialStartupSettled();
      await repeatTap(driver, await component(driver, 'loginRecoveryRetry'), 'loginRecoveryRetry');
      await waitCondition(driver, (): boolean => StabilizationNativeFixture.destroyCalls() === 2, 'explicit retirement Retry');
      expect(StabilizationNativeFixture.initializeCalls()).assertEqual(1);
      await screenshot(driver, 'startup-retiring'); await back(driver);
      await StabilizationNativeFixture.waitRetirementStarted(runtime);
      StabilizationNativeFixture.settleRetirement(true); await StabilizationNativeFixture.waitRetired(runtime);
      await driver.delayMs(100); expect(StabilizationNativeFixture.initializeCalls()).assertEqual(1);
      StabilizationNativeFixture.forbidTransportProof();
    });
    registerNativeCase('actual members pagination error retains rows and explicit Retry repeats only failed cursor', 0, async () => {
      const driver = Driver.create(); await rootReady(driver); StabilizationNativeFixture.prepareProfiles();
      await open(driver, 'stabilization-open-members'); await waitCondition(driver, (): boolean => StabilizationNativeFixture.requestCount() === 1, 'initial members request');
      StabilizationNativeFixture.replyMembers(0, 1000, 100); const list = await component(driver, 'profile_members_list');
      await scrollOwnedToBottom(driver, list, 40000, 1, 'profile_members_list'); await waitCondition(driver, (): boolean => StabilizationNativeFixture.requestCount() === 2, 'actual native list pagination');
      const page = StabilizationNativeFixture.port().requests[1].command as GetSupergroupMembersCommand; expect(page.payload.offset).assertEqual(100);
      StabilizationNativeFixture.failProfileRequest(1);
      if (!await driver.waitForIdle(200, 3000)) throw new Error('Actual members error footer layout did not become idle');
      await scrollOwnedToBottom(driver, list, 40000, 1, 'profile_members_list');
      expect(StabilizationNativeFixture.requestCount()).assertEqual(2);
      const retry = await scrollOwnedSearch(driver, list, ON.id('profile_members_more_retry'), 1, 'profile_members_list');
      if (retry === undefined || retry === null) throw new Error('Retained rows have no actual footer Retry');
      await screenshot(driver, 'members-page-error'); await repeatTap(driver, retry, 'profile_members_more_retry');
      await waitCondition(driver, (): boolean => StabilizationNativeFixture.requestCount() === 3, 'explicit footer Retry');
      expect(StabilizationNativeFixture.requestCount()).assertEqual(3);
      const retried = StabilizationNativeFixture.port().requests[2].command as GetSupergroupMembersCommand;
      expect(retried.payload.offset).assertEqual(page.payload.offset);
      StabilizationNativeFixture.replyMembers(2, 1100, 20); await driver.delayMs(300); await scrollOwnedToTop(driver, list, 40000, 1, 'profile_members_list');
      const retained = await scrollOwnedSearch(driver, list, ON.text('Member 1000'), 1, 'profile_members_list'); expect(retained !== undefined && retained !== null).assertTrue();
      await screenshot(driver, 'members-retried'); await back(driver);
    });
    registerNativeCase('actual member search revokes old result and Back fences late replacement', 0, async () => {
      const driver = Driver.create(); await rootReady(driver); StabilizationNativeFixture.prepareProfiles();
      await open(driver, 'stabilization-open-members'); await waitCondition(driver, (): boolean => StabilizationNativeFixture.requestCount() === 1, 'initial members request');
      StabilizationNativeFixture.replyMembers(0, 1000, 100); await component(driver, 'profile_members_list');
      await clickOwnedComponent(driver, await component(driver, 'tg_chat_top_bar_search'), 1, 'members-search-open', 'tg_chat_top_bar_search'); const input = await controlledInputAfterFocus(driver, TG_CHAT_SEARCH_INPUT_ID);
      await inputOwnedText(driver, input, 'old', 1, TG_CHAT_SEARCH_INPUT_ID); await waitCondition(driver, (): boolean => StabilizationNativeFixture.requestCount() === 2, 'old query request');
      const replacementInput = await controlledInputAfterFocus(driver, TG_CHAT_SEARCH_INPUT_ID);
      await inputOwnedText(driver, replacementInput, 'new', 1, TG_CHAT_SEARCH_INPUT_ID); StabilizationNativeFixture.replyMembers(1, 1000, 1);
      await waitCondition(driver, (): boolean => StabilizationNativeFixture.requestCount() === 3, 'new query request');
      const newQuery = StabilizationNativeFixture.port().requests[2].command as SearchChatMembersCommand; expect(newQuery.payload.query).assertEqual('new');
      StabilizationNativeFixture.replyMembers(2, 1100, 1);
      const currentMember = await ownedWaitForComponent(driver, ON.text('Member 1100'), 5000, 1);
      expect(currentMember !== undefined && currentMember !== null).assertTrue();
      await dismissKnownImeFirstUse(driver, StabilizationNativeFixture.navigationDepth());
      await absentText(driver, 'Member 1000'); expect(await ownedText(driver, replacementInput, 1)).assertEqual('new'); await screenshot(driver, 'members-search-current');
      await clickOwnedComponent(driver, await component(driver, 'tg_chat_top_bar_search_close'), 1, 'members-search-close', 'tg_chat_top_bar_search_close');
      await waitCondition(driver, (): boolean => StabilizationNativeFixture.requestCount() === 4, 'close search reload');
      await back(driver); StabilizationNativeFixture.replyMembers(3, 1110, 1); await driver.delayMs(300);
      await absentText(driver, 'Member 1110'); expect(StabilizationNativeFixture.navigationDepth()).assertEqual(0);
    });
    registerNativeCase('actual profile error Retry renders formatted bio then clears revoked account details', 0, async () => {
      const driver = Driver.create(); await rootReady(driver); StabilizationNativeFixture.prepareProfiles();
      await open(driver, 'stabilization-open-profile'); await waitCondition(driver, (): boolean => StabilizationNativeFixture.requestCount() === 1, 'initial profile request');
      StabilizationNativeFixture.failProfileRequest(0); await component(driver, 'profile_retry'); await screenshot(driver, 'profile-error');
      await repeatTap(driver, await component(driver, 'profile_retry'), 'profile_retry');
      await waitCondition(driver, (): boolean => StabilizationNativeFixture.requestCount() === 2, 'explicit profile Retry');
      StabilizationNativeFixture.replyBio(1, 'Expected bio from formattedText');
      const bio = await ownedWaitForComponent(driver, ON.text('Expected bio from formattedText'), 5000, 1);
      expect(bio !== undefined && bio !== null).assertTrue(); await screenshot(driver, 'profile-bio');
      StabilizationNativeFixture.revokeAccount(); await component(driver, 'profile_state'); await driver.delayMs(100);
      await absentText(driver, 'Current Alice'); await absentText(driver, 'Expected bio from formattedText');
      await screenshot(driver, 'profile-account-unavailable'); await back(driver);
    });
    registerNativeCase('actual profile Search chooses nearest owned chat in native STACK and blocks missing or wrong-account target', 0, async () => {
      const driver = Driver.create();
      const modes: ('normal' | 'wrongAccount' | 'missing')[] = ['normal', 'wrongAccount', 'missing'];
      for (const mode of modes) {
        await rootReady(driver); StabilizationNativeFixture.prepareSearchStack(mode);
        const root = await component(driver, 'chat-test-fixture-scroll');
        const button = await scrollOwnedSearch(driver, root, ON.id('stabilization-open-search-stack'), 0, 'chat-test-fixture-scroll');
        if (button === undefined || button === null) throw new Error('Actual search STACK action absent');
        await clickOwnedComponent(driver, button, 0, 'search-stack-open', 'stabilization-open-search-stack'); await waitCondition(driver, (): boolean => StabilizationNativeFixture.navigationDepth() === 3, 'Chat A -> Chat B -> actual Profile B stack');
        await clickOwnedComponent(driver, await component(driver, 'profile_search'), 3, 'profile-search', 'profile_search');
        if (mode === 'normal') {
          await waitCondition(driver, (): boolean => StabilizationNativeFixture.navigationDepth() === 2, 'actual profile popToIndex returns Chat B');
          await component(driver, 'stabilization-stack-chat');
          await waitCondition(driver, (): boolean => StabilizationNativeFixture.searchOpenCalls() === 1, 'production handleNavShown consumes owned search once');
          expect(StabilizationNativeFixture.returnedSearchTargetIsCurrent()).assertTrue();
          expect(await ownedText(driver, await component(driver, 'stabilization-stack-search-state'), 2)).assertEqual('Controlled destination search consumed once');
          await screenshot(driver, 'search-stack-nearest'); await back(driver);
          expect(StabilizationNativeFixture.searchOpenCalls()).assertEqual(1); await back(driver);
        } else {
          await driver.delayMs(300); expect(StabilizationNativeFixture.navigationDepth()).assertEqual(3);
          expect(StabilizationNativeFixture.searchOpenCalls()).assertEqual(0);
          await screenshot(driver, 'search-stack-blocked-' + mode.toLowerCase());
          await back(driver); await back(driver); await back(driver);
          expect(StabilizationNativeFixture.searchOpenCalls()).assertEqual(0);
        }
      }
    });
  });
}
