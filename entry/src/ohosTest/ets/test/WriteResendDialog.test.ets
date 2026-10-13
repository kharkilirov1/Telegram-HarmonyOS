import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON, abilityDelegatorRegistry } from '@kit.TestKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { localized } from '../../../main/ets/core/utils/AppResource';
import { WriteResendFixture } from '../testability/components/WriteResendFixture';

async function nativeTextFixtureReady(driver: Driver): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const deadline = Date.now() + 10000;
  let waiting = true;
  let timeoutId: number = -1;
  let diagnostic = 'TestAbility has not become current';
  const ready = async (): Promise<void> => {
    while (waiting && Date.now() < deadline) {
      let currentTestAbility = false;
      try {
        const ability = await delegator.getCurrentTopAbility();
        if (!waiting) break;
        if (ability === undefined || ability === null || ability.context === undefined || ability.context === null) {
          diagnostic = 'Current ability is unavailable';
        } else if (ability.context.abilityInfo.name !== 'TestAbility' || ability.context.currentHapModuleInfo.name !== $r('app.color.background_primary').moduleName) {
          diagnostic = 'Current ability is ' + ability.context.abilityInfo.name + '/' + ability.context.currentHapModuleInfo.name;
        } else currentTestAbility = true;
      } catch (error) {
        const native = error as BusinessError;
        if (native.code !== 16000100) throw new Error('Cannot obtain native TestAbility: ' + native.message);
        diagnostic = native.message;
      }
      if (currentTestAbility) {
        const scrolls = await driver.findComponents(ON.id('chat-test-fixture-scroll'));
        if (!waiting) break;
        if (scrolls !== undefined && scrolls !== null && scrolls.length > 0) return;
        diagnostic = 'TestAbility is current but its Scroll is not mounted';
      }
      // Allow onWindowStageCreate/loadContent to finish before native UI queries.
      await new Promise<void>((resolve) => { setTimeout(() => resolve(), 100); });
    }
    throw new Error('Native text TestAbility/Scroll readiness timeout: ' + diagnostic);
  };
  const timeout = new Promise<void>((_resolve, reject) => {
    timeoutId = setTimeout(() => {
      waiting = false;
      reject(new Error('Native text TestAbility/Scroll readiness timeout after 10000 ms: ' + diagnostic));
    }, 10000);
  });
  try { await Promise.race([ready(), timeout]); }
  finally { waiting = false; clearTimeout(timeoutId); }
}

async function requireResendText(driver: Driver, text: string): Promise<void> {
  const value = await driver.waitForComponent(ON.text(text), 5000);
  expect(value === undefined || value === null).assertFalse();
  if (value === undefined || value === null) throw new Error('Missing native text confirmation: ' + text);
  await driver.assertComponentExist(ON.text(text));
}
async function clickResendText(driver: Driver, text: string): Promise<void> {
  const value = await driver.waitForComponent(ON.text(text), 5000);
  if (value === undefined || value === null) throw new Error('Missing native confirmation button: ' + text);
  await value.click();
}
async function clickTextFixture(driver: Driver): Promise<void> {
  const scroll = await driver.waitForComponent(ON.id('chat-test-fixture-scroll'), 5000);
  if (scroll === undefined || scroll === null) throw new Error('Native text fixture Scroll is not mounted');
  const value = await scroll.scrollSearch(ON.id('write-resend-fixture-send'));
  if (value === undefined || value === null) throw new Error('Native text fixture button is not mounted');
  await driver.assertComponentExist(ON.id('write-resend-fixture-send'));
  await value.click();
}
async function absentResendText(driver: Driver, text: string): Promise<void> {
  let found = await driver.findComponents(ON.text(text));
  for (let attempt = 0; attempt < 50 && found !== undefined && found !== null && found.length > 0; attempt++) {
    await driver.delayMs(100); found = await driver.findComponents(ON.text(text));
  }
  expect(found === undefined || found === null || found.length === 0).assertTrue();
}
export default function writeResendDialogTest() {
  describe('WriteResendDialog', () => {
    it('native Cancel preserves composer and Send again dispatches one accepted text', 0, async () => {
      const driver = Driver.create(); await nativeTextFixtureReady(driver);
      WriteResendFixture.reset(); const state = WriteResendFixture.state;
      const title = localized($r('app.string.composer_send_resend_title').id, 'Send this message again?');
      const cancel = localized($r('app.string.cancel').id, 'Cancel');
      const resend = localized($r('app.string.composer_album_resend_action').id, 'Send again');
      try {
        await clickTextFixture(driver); await requireResendText(driver, 'text busy:false'); await requireResendText(driver, 'text mutations:1');
        expect(state.draft).assertEqual('\uD83D\uDE00 fixture text'); expect(state.reply).assertEqual('55'); expect(state.entities).assertEqual(1);
        await clickTextFixture(driver); await requireResendText(driver, title); await requireResendText(driver, cancel); await requireResendText(driver, resend);
        expect(state.busy).assertTrue(); expect(state.mutations).assertEqual(1);
        const screenshot = WriteResendFixture.screenshotPath(); console.info('[WriteResendDialog] screenshot=' + screenshot);
        expect(await driver.screenCap(screenshot)).assertTrue();
        await clickResendText(driver, cancel); await absentResendText(driver, title); await requireResendText(driver, 'text busy:false');
        expect(state.mutations).assertEqual(1); expect(state.draft).assertEqual('\uD83D\uDE00 fixture text');
        expect(state.reply).assertEqual('55'); expect(state.entities).assertEqual(1);
        await clickTextFixture(driver); await requireResendText(driver, title); await clickResendText(driver, resend);
        await absentResendText(driver, title); await requireResendText(driver, 'text busy:false'); await requireResendText(driver, 'text mutations:2');
        expect(state.draft).assertEqual(''); expect(state.reply).assertEqual('0'); expect(state.entities).assertEqual(0);
        const commands = WriteResendFixture.capturedTexts(); expect(commands.length).assertEqual(2);
        for (const command of commands) {
          expect(command.payload.chatId).assertEqual(42); expect(command.payload.text).assertEqual('\uD83D\uDE00 fixture text');
          expect(command.payload.replyToMessageId).assertEqual('55'); expect(command.payload.customEmojiEntities.length).assertEqual(1);
          expect(command.payload.customEmojiEntities[0].customEmojiId).assertEqual('123');
        }
      } finally {
        // Cancel only our owned modal; cleanup cannot replace a failed assertion.
        try {
          const titles = await driver.findComponents(ON.text(title));
          if (titles !== undefined && titles !== null && titles.length > 0) {
            const buttons = await driver.findComponents(ON.text(cancel));
            if (buttons !== undefined && buttons !== null && buttons.length > 0) await buttons[0].click();
          }
        } catch (error) {
          console.info('[WriteResendDialog] cleanup failed: ' + (error as Error).message);
        }
      }
    });
  });
}
