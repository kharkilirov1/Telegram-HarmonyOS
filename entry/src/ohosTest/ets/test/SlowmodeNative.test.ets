import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON, abilityDelegatorRegistry, Point, Rect } from '@kit.TestKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { localized } from '../../../main/ets/core/utils/AppResource';
import { navigationUIState } from '../../../main/ets/core/model/UIStateModels';
import { SlowmodeNativeFixture } from '../testability/components/SlowmodeFixture';

async function slowmodeNativeReady(driver: Driver): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator(); const deadline = Date.now() + 10000;
  let diagnostic = 'TestAbility is not current';
  while (Date.now() < deadline) {
    let current = false;
    try {
      const ability = await delegator.getCurrentTopAbility();
      current = ability !== undefined && ability !== null && ability.context !== undefined &&
        ability.context.abilityInfo.name === 'TestAbility' && ability.context.currentHapModuleInfo.name === $r('app.color.background_primary').moduleName;
    } catch (error) {
      const native = error as BusinessError;
      if (native.code !== 16000100) throw new Error('Cannot obtain native TestAbility: ' + native.message);
      diagnostic = native.message;
    }
    if (current) {
      if (!SlowmodeNativeFixture.configurationReady()) {
        diagnostic = 'TestAbility page and app-local color mode are not ready';
        await driver.delayMs(100); continue;
      }
      if (!SlowmodeNativeFixture.navigationBound()) {
        diagnostic = 'Actual fixture Index NavPathStack is not mounted';
        await driver.delayMs(100); continue;
      }
      const depth = SlowmodeNativeFixture.navigationDepth();
      if (depth === 1) {
        const existing = await driver.findComponents(ON.id('slowmode-fixture-ready'));
        if (existing !== undefined && existing !== null && existing.length > 0) return;
      } else if (depth === 0) {
        // A retiring destination can remain in the accessibility tree. Its old
        // ready ID cannot establish ownership after real Back has popped it.
        const scroll = await driver.waitForComponent(ON.id('chat-test-fixture-scroll'), 1000);
        if (scroll !== undefined && scroll !== null) {
          const button = await scroll.scrollSearch(ON.id('slowmode-fixture-open-route'));
          if (button !== undefined && button !== null) {
            await button.click();
            if (!await driver.waitForIdle(200, 3000)) throw new Error('Native slowmode route transition did not become idle');
            const mounted = await driver.waitForComponent(ON.id('slowmode-fixture-ready'), 3000);
            if (mounted !== undefined && mounted !== null && SlowmodeNativeFixture.navigationDepth() === 1) return;
          }
        }
      } else throw new Error('Unexpected native slowmode route stack depth=' + depth.toString());
      diagnostic = 'TestAbility is current but the slowmode fixture is not mounted';
    }
    await new Promise<void>((resolve) => { setTimeout(() => resolve(), 100); });
  }
  throw new Error('Slowmode native readiness timeout: ' + diagnostic);
}
async function slowmodeAction(driver: Driver): Promise<Point> {
  // Dedicated route is already mounted. Never scroll after arming an expiry.
  const countdown = await driver.waitForComponent(ON.id('tg_composer_slowmode_countdown'), 2000);
  if (countdown === undefined || countdown === null) throw new Error('Actual atom countdown is not mounted');
  const text = await countdown.getText();
  expect(/^[0-9]+:[0-9]{2}$/.test(text)).assertTrue();
  console.info('[SlowmodeNative] actualCountdownText=' + text);
  const point = await countdown.getBoundsCenter();
  try { slowmodeResendLog('capturedCountdown point=' + point.x.toString() + ',' + point.y.toString()); } catch (diagnosticError) {}
  return point;
}
// Exact native action acquisition; captured countdown coordinates are evidence only.
async function clickCurrentSlowmodeAction(driver: Driver, capturedAction: Point): Promise<void> {
  const started = Date.now(); let awaitedOperations: number = 0;
  const fixture = SlowmodeNativeFixture.fixture();
  const generation = SlowmodeNativeFixture.routeGeneration();
  const bundleName = abilityDelegatorRegistry.getArguments().bundleName;
  const moduleName = $r('app.color.background_primary').moduleName;
  if (!bundleName || !moduleName) throw new Error('Slowmode action has no expected bundle/module');
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  let ownerAbility: UIAbility | undefined;
  let ownerWindowId: number = 0;
  const checkOwner = (): void => {
    if (SlowmodeNativeFixture.fixture() !== fixture || SlowmodeNativeFixture.state.page !== fixture.page ||
      SlowmodeNativeFixture.routeGeneration() !== generation || SlowmodeNativeFixture.navigationDepth() !== 1)
      throw new Error('Slowmode action fixture owner changed');
    if (ownerAbility !== undefined && ownerWindowId !== 0 &&
      ownerAbility.context.windowStage.getMainWindowSync().getWindowProperties().id !== ownerWindowId)
      throw new Error('Slowmode action Stage owner changed');
  };
  const checkAbility = async (): Promise<UIAbility> => {
    awaitedOperations++;
    const ability = await delegator.getCurrentTopAbility(); checkOwner();
    if (ability === undefined || ability === null || ability.context.abilityInfo.name !== 'TestAbility' ||
      ability.context.abilityInfo.bundleName !== bundleName || ability.context.currentHapModuleInfo.name !== moduleName ||
      (ownerAbility !== undefined && ownerAbility !== ability)) throw new Error('Slowmode action ability owner changed');
    ownerAbility = ability; return ability;
  };
  const observeOwner = async (): Promise<Rect> => {
    const ability = await checkAbility(); checkOwner();
    awaitedOperations++;
    const main = await window.getLastWindow(ability.context); checkOwner();
    const properties = main.getWindowProperties();
    const stage = ability.context.windowStage.getMainWindowSync().getWindowProperties();
    if (!Number.isSafeInteger(properties.id) || properties.id <= 0 || properties.id !== stage.id ||
      (ownerWindowId !== 0 && properties.id !== ownerWindowId)) throw new Error('Slowmode action main-window identity mismatch');
    ownerWindowId = properties.id;
    awaitedOperations++;
    const focused = await driver.findWindow({ bundleName: bundleName, focused: true }); checkOwner();
    if (focused === undefined || focused === null) throw new Error('Slowmode action has no owned focused window');
    const bounds = properties.windowRect;
    return { left: bounds.left, top: bounds.top, right: bounds.left + bounds.width, bottom: bounds.top + bounds.height };
  };
  const positive = (rect: Rect): boolean => Number.isFinite(rect.left) && Number.isFinite(rect.top) &&
    Number.isFinite(rect.right) && Number.isFinite(rect.bottom) && rect.right > rect.left && rect.bottom > rect.top;
  const contains = (outer: Rect, inner: Rect): boolean => positive(outer) && positive(inner) &&
    inner.left >= outer.left && inner.right <= outer.right && inner.top >= outer.top && inner.bottom <= outer.bottom;
  checkOwner(); await observeOwner(); checkOwner();
  const dockSelector = ON.id('slowmode-fixture-dock').inWindow(bundleName);
  awaitedOperations++;
  const docks = await driver.findComponents(dockSelector); checkOwner();
  if (docks === undefined || docks === null || docks.length !== 1) throw new Error('Slowmode action Dock is not unique');
  awaitedOperations++;
  const targets = await driver.findComponents(ON.id('tg_composer_action').inWindow(bundleName).within(dockSelector)); checkOwner();
  if (targets === undefined || targets === null || targets.length !== 1) throw new Error('Slowmode action target is not unique');
  const target = targets[0];
  awaitedOperations++;
  const enabled = await target.isEnabled(); checkOwner();
  awaitedOperations++;
  const clickable = await target.isClickable(); checkOwner();
  if (!enabled || !clickable) throw new Error('Slowmode action native target is not enabled/clickable');
  awaitedOperations++;
  const dockBounds = await docks[0].getBounds(); checkOwner();
  awaitedOperations++;
  const bounds = await target.getBounds(); checkOwner();
  // Two fresh owner observations after the target/property lookups; no snapshot atomicity is assumed.
  await observeOwner(); checkOwner();
  const ownerBounds = await observeOwner(); checkOwner();
  if (!contains(dockBounds, bounds) || !contains(ownerBounds, bounds)) throw new Error('Slowmode action is clipped or has invalid bounds');
  const submitEligible = fixture.page.composerCanSubmit();
  if (fixture.page.isSending || fixture.page.composerSlowmodeSeconds !== 0 || !submitEligible)
    throw new Error('Slowmode action model is not ready for one manual send');
  try {
    slowmodeResendLog('currentAction captured=' + capturedAction.x.toString() + ',' + capturedAction.y.toString() +
      ' freshBounds=' + bounds.left.toString() + ',' + bounds.top.toString() + ',' + bounds.right.toString() + ',' + bounds.bottom.toString() +
      ' freshCenter=' + ((bounds.left + bounds.right) / 2).toString() + ',' + ((bounds.top + bounds.bottom) / 2).toString() +
      ' generation=' + generation.toString() + ' mainWindow=' + ownerWindowId.toString() +
      ' awaitedOperations=' + awaitedOperations.toString() + ' elapsedWallMs=' + (Date.now() - started).toString() +
      ' modelSlowmode=' + fixture.page.composerSlowmodeSeconds.toString() + ' submitEligible=' + submitEligible.toString());
  } catch (diagnosticError) {}
  slowmodeResendPhase('current-action-enter', capturedAction);
  checkOwner();
  awaitedOperations++;
  await target.click(); checkOwner();
  slowmodeResendPhase('current-action-native-return', capturedAction);
  // A successful send can open an owned native dialog; retain Ability/Stage/focus proof without treating that dialog as the main Window.
  await checkAbility(); checkOwner();
  awaitedOperations++;
  const focusedAfter = await driver.findWindow({ bundleName: bundleName, focused: true }); checkOwner();
  if (focusedAfter === undefined || focusedAfter === null) throw new Error('Slowmode action lost owned focus after click');
  slowmodeResendLog('currentAction completed awaitedOperations=' + awaitedOperations.toString() +
    ' elapsedWallMs=' + (Date.now() - started).toString());
  slowmodeResendPhase('current-action-return', capturedAction);
}
async function prepareNativeInput(driver: Driver, unknown: boolean = false): Promise<void> {
  await SlowmodeNativeFixture.assertNativeColorContext();
  await SlowmodeNativeFixture.reset('0', unknown);
  const text = await driver.waitForComponent(ON.id('tg_chat_composer_text_input'), 3000);
  if (text === undefined || text === null) throw new Error('Actual TextArea has not mounted');
  expect(await text.getText()).assertEqual('\uD83D\uDE00 preserved draft');
  const before = SlowmodeNativeFixture.requestNativeCaret(); const deadline = Date.now() + 3000;
  let committed = false;
  while (Date.now() < deadline) {
    const page = SlowmodeNativeFixture.fixture().page;
    if (SlowmodeNativeFixture.selectionEvents() > before && page.composerSelectionStart === 2 && page.composerSelectionEnd === 2) {
      committed = true; break;
    }
    await driver.delayMs(50);
  }
  expect(committed).assertTrue();
  if (!committed) throw new Error('Real TextArea selection callback did not commit requested nonterminal caret2:2');
  if (!await driver.waitForIdle(200, 3000)) throw new Error('Mounted native input did not become idle before cooldown');
  preserved();
}
async function attachmentPoint(driver: Driver): Promise<Point> {
  const text = await driver.waitForComponent(ON.id('tg_chat_composer_text_input'), 1000);
  const images = await driver.findComponents(ON.type('Image')); const dock = await driver.waitForComponent(ON.id('slowmode-fixture-dock'), 1000);
  if (images === undefined || images === null || dock === undefined || dock === null || text === undefined || text === null) {
    throw new Error('Actual Dock image controls missing');
  }
  const bounds = await dock.getBounds(); const input = await text.getBoundsCenter(); let attach: Point | undefined;
  for (const image of images) {
    const point = await image.getBoundsCenter();
    if (point.x >= bounds.left && point.x <= bounds.right && point.y >= bounds.top && point.y <= bounds.bottom &&
      Math.abs(point.y - input.y) <= 30 && (attach === undefined || point.x < attach.x)) attach = point;
  }
  if (attach === undefined) throw new Error('Actual attachment image in the TextArea row missing');
  return attach;
}
function requireInputSetupSealed(): void {
  let rejected = false;
  try { SlowmodeNativeFixture.requestNativeCaret(); }
  catch (error) { rejected = (error as Error).message === 'Native input setup is sealed after cooldown starts'; }
  expect(rejected).assertTrue(); preserved();
}
async function closeNativeRoute(driver: Driver, completed: boolean): Promise<void> {
  const beforeDepth = SlowmodeNativeFixture.navigationDepth(); const generation = SlowmodeNativeFixture.routeGeneration();
  SlowmodeNativeFixture.dispose();
  try {
    if (beforeDepth !== 1) throw new Error('Slowmode route owner changed before real Back cleanup');
    await driver.pressBack();
    if (!await driver.waitForIdle(200, 3000)) throw new Error('Native slowmode Back transition did not become idle');
    const afterDepth = SlowmodeNativeFixture.navigationDepth();
    console.info('[SlowmodeNative] afterBack depth=' + afterDepth.toString() + ' generation=' +
      SlowmodeNativeFixture.routeGeneration().toString());
    if (afterDepth !== beforeDepth - 1 || SlowmodeNativeFixture.routeGeneration() !== generation) {
      throw new Error('Real Back did not remove exactly the owned slowmode route');
    }
    const deadline = Date.now() + 3000;
    while (Date.now() < deadline) {
      const outgoingReady = await driver.findComponents(ON.id('slowmode-fixture-ready'));
      const outgoingDock = await driver.findComponents(ON.id('slowmode-fixture-dock'));
      const root = await driver.findComponents(ON.id('chat-test-fixture-scroll'));
      const readyGone = outgoingReady === undefined || outgoingReady === null || outgoingReady.length === 0;
      const dockGone = outgoingDock === undefined || outgoingDock === null || outgoingDock.length === 0;
      const rootVisible = root !== undefined && root !== null && root.length > 0;
      if (readyGone && dockGone && rootVisible && SlowmodeNativeFixture.navigationDepth() === 0 &&
        SlowmodeNativeFixture.routeGeneration() === generation) return;
      await driver.delayMs(50);
    }
    throw new Error('Actual slowmode route did not retire to visible Index with outgoing ready/Dock absent after real Back');
  } catch (error) {
    const detail = (error as Error).message;
    if (completed) throw new Error('Slowmode native Back cleanup failed: ' + detail);
    console.info('[SlowmodeNative] cleanup after original failure: ' + detail);
  }
}
async function waitSlowmode(driver: Driver, expired: boolean): Promise<void> {
  const deadline = Date.now() + 10000;
  while (Date.now() < deadline) {
    const found = await driver.findComponents(ON.id('tg_composer_slowmode_countdown'));
    const visible = found !== undefined && found !== null && found.length > 0;
    if (expired ? !visible : visible) return;
    await driver.delayMs(100);
  }
  throw new Error('Actual slowmode countdown did not reach expected visibility: ' + expired.toString());
}
async function clickNativeLabel(driver: Driver, label: string): Promise<void> {
  const button = await driver.waitForComponent(ON.text(label), 5000);
  if (button === undefined || button === null) throw new Error('Native modal action missing: ' + label);
  await button.click();
}
async function waitNativeLabel(driver: Driver, label: string): Promise<void> {
  const component = await driver.waitForComponent(ON.text(label), 5000);
  if (component === undefined || component === null) throw new Error('Native modal label missing: ' + label);
}
async function waitNativeDialogDismissed(driver: Driver, title: string, confirm: string): Promise<void> {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const titles = await driver.findComponents(ON.text(title)); const confirmations = await driver.findComponents(ON.text(confirm));
    if ((titles === undefined || titles === null || titles.length === 0) &&
      (confirmations === undefined || confirmations === null || confirmations.length === 0)) return;
    await driver.delayMs(50);
  }
  throw new Error('Actual native resend dialog did not disappear after its selected action');
}
// Diagnostic reads only: model state is not proof that the native atom is ready.
function slowmodeResendLog(message: string): void {
  try { console.info('[SlowmodeNative] ' + message); } catch (error) {}
}
function slowmodeResendPhase(phase: string, action?: Point): void {
  try {
    const fixture = SlowmodeNativeFixture.fixture();
    slowmodeResendLog('resendPhase=' + phase + ' wallMs=' + Date.now().toString() +
      ' generation=' + SlowmodeNativeFixture.routeGeneration().toString() +
      ' depth=' + SlowmodeNativeFixture.navigationDepth().toString() +
      ' modelBusy=' + fixture.page.isSending.toString() +
      ' modelSlowmode=' + fixture.page.composerSlowmodeSeconds.toString() +
      ' mutations=' + SlowmodeNativeFixture.state.mutations.toString() +
      ' gatewayRequests=' + fixture.gateway.requests.length.toString() +
      ' preparations=' + fixture.composer.preparations.length.toString() +
      ' pendingAttachments=' + fixture.page.pendingAttachmentUris.length.toString() +
      ' capturedAction=' + (action === undefined ? 'unavailable' : action.x.toString() + ',' + action.y.toString()));
  } catch (error) { slowmodeResendLog('resendPhase=' + phase + ' stateUnavailable'); }
}
async function nativeResendFailureGeometry(driver: Driver): Promise<void> {
  // Fixed IDs in the synthetic route; no target search, interaction or retry.
  for (const id of ['slowmode-fixture-dock', 'tg_chat_composer_text_input']) {
    slowmodeResendLog('failureGeometry query-enter id=' + id);
    try {
      const components = await driver.findComponents(ON.id(id));
      slowmodeResendLog('failureGeometry query-return id=' + id + ' count=' + (components?.length ?? 0).toString());
      if (components !== undefined && components !== null && components.length === 1) {
        slowmodeResendLog('failureGeometry bounds-enter id=' + id);
        const bounds = await components[0].getBounds();
        slowmodeResendLog('failureGeometry bounds-return id=' + id + ' rect=' +
          bounds.left.toString() + ',' + bounds.top.toString() + ',' + bounds.right.toString() + ',' + bounds.bottom.toString());
      }
    } catch (error) { slowmodeResendLog('failureGeometry unavailable id=' + id); }
  }
}
async function nativeDialogEvidence(driver: Driver, title: string, cancel: string, confirm: string, name: string): Promise<void> {
  console.info('[SlowmodeNative] dialogEvidence=' + name + ' title=' + title + ' cancel=' + cancel + ' confirm=' + confirm +
    ' busy=' + SlowmodeNativeFixture.fixture().page.isSending.toString());
  for (const label of [title, cancel, confirm]) {
    try {
      const nodes = await driver.findComponents(ON.text(label));
      console.info('[SlowmodeNative] dialogLabel=' + label + ' nodes=' + (nodes?.length ?? 0).toString());
    } catch (error) { console.info('[SlowmodeNative] dialogLabel=' + label + ' queryFailure=' + (error as Error).message); }
  }
  try {
    const path = SlowmodeNativeFixture.screenshotPath(name);
    console.info('[SlowmodeNative] screenshot=' + path + ' captured=' + (await driver.screenCap(path)).toString());
  } catch (error) { console.info('[SlowmodeNative] failure-time screenshot error=' + (error as Error).message); }
}
async function clickNativeConfirmation(driver: Driver, title: string, cancel: string, confirm: string): Promise<void> {
  try { await clickNativeLabel(driver, confirm); }
  catch (error) {
    await nativeDialogEvidence(driver, title, cancel, confirm, 'resend-confirm-missing');
    throw new Error((error as Error).message);
  }
}
async function waitNativeApplicationState(driver: Driver, ability: UIAbility, foreground: boolean): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const state = foreground ? abilityDelegatorRegistry.AbilityLifecycleState.FOREGROUND :
    abilityDelegatorRegistry.AbilityLifecycleState.BACKGROUND;
  const deadline = Date.now() + 3000;
  while (Date.now() < deadline) {
    if (navigationUIState.applicationForeground === foreground && delegator.getAbilityState(ability) === state) {
      console.info('[SlowmodeNative] actualAbilityState=' + state.toString() + ' callbackForeground=' + foreground.toString()); return;
    }
    await driver.delayMs(50);
  }
  expect(navigationUIState.applicationForeground).assertEqual(foreground);
  expect(delegator.getAbilityState(ability)).assertEqual(state);
  throw new Error('Actual TestAbility lifecycle state and typed callback did not converge');
}
async function waitMutation(driver: Driver, count: number): Promise<void> {
  try {
    const component = await driver.waitForComponent(ON.text('slowmode mutations:' + count.toString()), 5000);
    if (component === undefined || component === null) throw new Error('Slowmode mutation count did not reach ' + count.toString());
  } catch (error) {
    slowmodeResendPhase('mutation-label-failed-' + count.toString());
    try {
      const path = SlowmodeNativeFixture.screenshotPath('mutation-label-failed-' + count.toString());
      slowmodeResendLog('mutationFailure screenshot-enter=' + path);
      const captured = await driver.screenCap(path);
      slowmodeResendLog('mutationFailure screenshot-return captured=' + captured.toString());
    } catch (diagnosticError) { slowmodeResendLog('mutationFailure screenshot-unavailable'); }
    throw error as Error;
  }
}
async function waitIdle(driver: Driver): Promise<void> {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    if (!SlowmodeNativeFixture.fixture().page.isSending) return;
    await driver.delayMs(50);
  }
  throw new Error('Slowmode composer remained busy');
}
function preserved(): void {
  const f = SlowmodeNativeFixture.fixture();
  expect(f.page.composerDraftText).assertEqual('\uD83D\uDE00 preserved draft');
  expect(f.page.pendingAttachmentUris.join('|')).assertEqual('fixture:slowmode-document');
  expect(f.page.replyToMessageId).assertEqual('55'); expect(f.page.customEmojiDraftEntities.length).assertEqual(1);
  expect(f.page.customEmojiDraftEntities[0].customEmojiId).assertEqual('123');
  expect(f.page.composerSelectionStart).assertEqual(2); expect(f.page.composerSelectionEnd).assertEqual(2);
}
async function screenshot(driver: Driver, name: string): Promise<void> {
  const path = SlowmodeNativeFixture.screenshotPath(name); console.info('[SlowmodeNative] screenshot=' + path);
  expect(await driver.screenCap(path)).assertTrue();
}
export default function slowmodeNativeTest(): void {
  describe('SlowmodeNative', () => {
    it('mounted actual Dock countdown blocks action and attachment while expiry enables a manual send without autosend', 0, async () => {
      const driver = Driver.create(); await slowmodeNativeReady(driver);
      let completed = false;
      try {
        await prepareNativeInput(driver); const attach = await attachmentPoint(driver);
        await SlowmodeNativeFixture.cooldown('8'); requireInputSetupSealed();
        const action = await slowmodeAction(driver); const f = SlowmodeNativeFixture.fixture();
        expect(f.page.composerSlowmodeSeconds > 0).assertTrue(); preserved();
        if (f.page.composerSlowmodeSeconds <= 0) throw new Error('Blocked action witness is inconclusive: cooldown expired before click');
        slowmodeResendPhase('blocked-action-click-enter', action);
        await driver.click(action.x, action.y);
        slowmodeResendPhase('blocked-action-click-return', action);
        if (f.page.composerSlowmodeSeconds <= 0) throw new Error('Blocked action witness is inconclusive: cooldown expired during click');
        expect(f.gateway.requests.length).assertEqual(0);
        if (f.page.composerSlowmodeSeconds <= 0) throw new Error('Blocked attachment witness is inconclusive: cooldown expired before click');
        await driver.click(attach.x, attach.y);
        if (f.page.composerSlowmodeSeconds <= 0) throw new Error('Blocked attachment witness is inconclusive: cooldown expired during click');
        expect(f.composer.recentLoads).assertEqual(0);
        expect(f.composer.preparations.length).assertEqual(0); preserved(); await screenshot(driver, 'countdown');
        await waitSlowmode(driver, true); expect(f.page.composerSlowmodeSeconds).assertEqual(0);
        expect(f.gateway.requests.length).assertEqual(0); preserved(); await screenshot(driver, 'expired');
        await clickCurrentSlowmodeAction(driver, action); await waitMutation(driver, 1); await waitIdle(driver);
        expect(f.composer.preparations.length).assertEqual(1); expect(f.page.pendingAttachmentUris.length).assertEqual(0);
        expect(f.page.composerDraftText).assertEqual(''); expect(f.page.replyToMessageId).assertEqual('0');
        completed = true;
      } finally { await closeNativeRoute(driver, completed); }
    });
    it('native resend Cancel preserves unknown intent and Confirm rechecks a cooldown that arrived inside the actual dialog', 0, async () => {
      const driver = Driver.create(); await slowmodeNativeReady(driver);
      const title = localized($r('app.string.composer_media_resend_title').id, 'Send these files again?');
      const cancel = localized($r('app.string.cancel').id, 'Cancel');
      const confirm = localized($r('app.string.composer_album_resend_action').id, 'Send again');
      console.info('[SlowmodeNative] nativeResendLabels title=' + title + ' cancel=' + cancel + ' confirm=' + confirm);
      let completed = false;
      let resendPhase = 'prepare'; let diagnosticAction: Point | undefined;
      try {
        slowmodeResendPhase(resendPhase);
        await prepareNativeInput(driver, true); await SlowmodeNativeFixture.cooldown('30'); requireInputSetupSealed();
        const action = await slowmodeAction(driver); diagnosticAction = action;
        resendPhase = 'action-captured'; slowmodeResendPhase(resendPhase, action);
        await SlowmodeNativeFixture.expire(); await waitSlowmode(driver, true);
        resendPhase = 'initial-click-enter'; slowmodeResendPhase(resendPhase, action);
        await clickCurrentSlowmodeAction(driver, action);
        resendPhase = 'initial-click-return'; slowmodeResendPhase(resendPhase, action);
        await waitMutation(driver, 1); await waitIdle(driver); preserved();
        resendPhase = 'first-resend-click-enter'; slowmodeResendPhase(resendPhase, action);
        await clickCurrentSlowmodeAction(driver, action);
        resendPhase = 'first-title-wait-enter'; slowmodeResendPhase(resendPhase, action);
        await waitNativeLabel(driver, title);
        resendPhase = 'first-title-wait-return'; slowmodeResendPhase(resendPhase, action);
        await clickNativeLabel(driver, cancel); await waitIdle(driver);
        await waitNativeDialogDismissed(driver, title, confirm);
        preserved(); expect(SlowmodeNativeFixture.fixture().composer.preparations.length).assertEqual(1);
        resendPhase = 'second-resend-click-enter'; slowmodeResendPhase(resendPhase, action);
        await clickCurrentSlowmodeAction(driver, action);
        resendPhase = 'second-title-wait-enter'; slowmodeResendPhase(resendPhase, action);
        await waitNativeLabel(driver, title);
        resendPhase = 'second-title-wait-return'; slowmodeResendPhase(resendPhase, action);
        await waitNativeLabel(driver, confirm); expect(SlowmodeNativeFixture.fixture().page.isSending).assertTrue();
        resendPhase = 'cooldown-confirm'; slowmodeResendPhase(resendPhase, action);
        await SlowmodeNativeFixture.cooldown('30');
        await nativeDialogEvidence(driver, title, cancel, confirm, 'resend-before-cooldown-confirm');
        await clickNativeConfirmation(driver, title, cancel, confirm); await waitIdle(driver);
        await waitNativeDialogDismissed(driver, title, confirm);
        preserved(); expect(SlowmodeNativeFixture.state.mutations).assertEqual(1);
        expect(SlowmodeNativeFixture.fixture().composer.preparations.length).assertEqual(1); await screenshot(driver, 'resend-blocked');
        await SlowmodeNativeFixture.expire(); await waitSlowmode(driver, true); expect(SlowmodeNativeFixture.state.mutations).assertEqual(1);
        SlowmodeNativeFixture.acceptNextWrites();
        resendPhase = 'third-resend-click-enter'; slowmodeResendPhase(resendPhase, action);
        await clickCurrentSlowmodeAction(driver, action);
        resendPhase = 'third-title-wait-enter'; slowmodeResendPhase(resendPhase, action);
        await waitNativeLabel(driver, title);
        resendPhase = 'third-title-wait-return'; slowmodeResendPhase(resendPhase, action);
        await screenshot(driver, 'resend-confirmation'); await clickNativeConfirmation(driver, title, cancel, confirm);
        await waitMutation(driver, 2); await waitIdle(driver); await waitNativeDialogDismissed(driver, title, confirm);
        expect(SlowmodeNativeFixture.fixture().composer.preparations.length).assertEqual(2);
        expect(SlowmodeNativeFixture.fixture().page.pendingAttachmentUris.length).assertEqual(0);
        completed = true;
        resendPhase = 'completed'; slowmodeResendPhase(resendPhase, action);
      } catch (error) {
        // Preserve the original failing phase before any diagnostic native RPC.
        slowmodeResendLog('originalFailure phase=' + resendPhase);
        slowmodeResendPhase('failed-' + resendPhase, diagnosticAction);
        try {
          await nativeResendFailureGeometry(driver);
          await nativeDialogEvidence(driver, title, cancel, confirm, 'resend-' + resendPhase + '-failure');
        } catch (diagnosticError) {
          slowmodeResendLog('failureEvidenceUnavailable phase=' + resendPhase);
        }
        throw error as Error;
      } finally {
        try {
          const modal = await driver.findComponents(ON.text(title));
          if (modal !== undefined && modal !== null && modal.length > 0) await clickNativeLabel(driver, cancel);
        } catch (error) { console.info('[SlowmodeNative] modal cleanup: ' + (error as Error).message); }
        await closeNativeRoute(driver, completed);
      }
    });
    it('real TestAbility background and foreground callbacks resume the mounted timer while preserving populated input', 0, async () => {
      const driver = Driver.create(); await slowmodeNativeReady(driver);
      const delegator = abilityDelegatorRegistry.getAbilityDelegator(); const ability = await delegator.getCurrentTopAbility();
      if (ability === undefined || ability === null) throw new Error('TestAbility unavailable for lifecycle proof');
      let background = false;
      let completed = false;
      try {
        await prepareNativeInput(driver); await SlowmodeNativeFixture.cooldown('8'); requireInputSetupSealed();
        await slowmodeAction(driver); preserved(); await screenshot(driver, 'before-background');
        await delegator.doAbilityBackground(ability); background = true;
        await waitNativeApplicationState(driver, ability, false);
        expect(navigationUIState.applicationForeground).assertFalse();
        await new Promise<void>((resolve) => { setTimeout(() => resolve(), 8500); });
        await delegator.doAbilityForeground(ability); background = false; await waitNativeApplicationState(driver, ability, true);
        expect(navigationUIState.applicationForeground).assertTrue();
        await slowmodeNativeReady(driver); await waitSlowmode(driver, true); preserved();
        expect(SlowmodeNativeFixture.fixture().page.composerSlowmodeSeconds).assertEqual(0);
        expect(SlowmodeNativeFixture.state.mutations).assertEqual(0); await screenshot(driver, 'after-foreground');
        completed = true;
      } finally {
        if (background) await delegator.doAbilityForeground(ability);
        await closeNativeRoute(driver, completed);
      }
    });
  });
}
