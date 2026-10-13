import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON, abilityDelegatorRegistry } from '@kit.TestKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { localized } from '../../../main/ets/core/utils/AppResource';
import { SequentialMediaDialogFixture } from '../testability/components/SequentialMediaDialogFixture';

async function sequentialNativeReady(driver: Driver): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator(); const deadline = Date.now() + 10000;
  let waiting = true; let timeoutId: number = -1; let diagnostic = 'TestAbility has not become current';
  const ready = async (): Promise<void> => {
    while (waiting && Date.now() < deadline) {
      let current = false;
      try {
        const ability = await delegator.getCurrentTopAbility(); if (!waiting) break;
        if (ability === undefined || ability === null || ability.context === undefined || ability.context === null) diagnostic = 'Current ability is unavailable';
        else if (ability.context.abilityInfo.name !== 'TestAbility' || ability.context.currentHapModuleInfo.name !== $r('app.color.background_primary').moduleName) {
          diagnostic = 'Current ability is ' + ability.context.abilityInfo.name + '/' + ability.context.currentHapModuleInfo.name;
        } else current = true;
      } catch (error) {
        const native = error as BusinessError;
        if (native.code !== 16000100) throw new Error('Cannot obtain native TestAbility: ' + native.message);
        diagnostic = native.message;
      }
      if (current) {
        const scrolls = await driver.findComponents(ON.id('chat-test-fixture-scroll')); if (!waiting) break;
        if (scrolls !== undefined && scrolls !== null && scrolls.length > 0) return;
        diagnostic = 'TestAbility is current but its Scroll is not mounted';
      }
      await new Promise<void>((resolve) => { setTimeout(() => resolve(), 100); });
    }
    throw new Error('Sequential native fixture readiness timeout: ' + diagnostic);
  };
  const timeout = new Promise<void>((_resolve, reject) => {
    timeoutId = setTimeout(() => { waiting = false; reject(new Error('Sequential native readiness timeout after 10000ms: ' + diagnostic)); }, 10000);
  });
  try { await Promise.race([ready(), timeout]); } finally { waiting = false; clearTimeout(timeoutId); }
}
async function clickSequentialFixture(driver: Driver): Promise<void> {
  const scroll = await driver.waitForComponent(ON.id('chat-test-fixture-scroll'), 5000);
  if (scroll === undefined || scroll === null) throw new Error('Sequential fixture Scroll is not mounted');
  const button = await scroll.scrollSearch(ON.id('sequential-media-fixture-send'));
  if (button === undefined || button === null) throw new Error('Sequential native send button is not mounted');
  await driver.assertComponentExist(ON.id('sequential-media-fixture-send')); await button.click();
}
async function requireSequentialText(driver: Driver, text: string): Promise<void> {
  const value = await driver.waitForComponent(ON.text(text), 5000);
  expect(value === undefined || value === null).assertFalse();
  if (value === undefined || value === null) throw new Error('Missing sequential native UI text: ' + text);
  await driver.assertComponentExist(ON.text(text));
}
async function clickSequentialText(driver: Driver, text: string): Promise<void> {
  const value = await driver.waitForComponent(ON.text(text), 5000);
  if (value === undefined || value === null) throw new Error('Missing sequential native action: ' + text);
  await value.click();
}
async function absentSequentialText(driver: Driver, text: string): Promise<void> {
  let found = await driver.findComponents(ON.text(text));
  for (let attempt = 0; attempt < 50 && found !== undefined && found !== null && found.length > 0; attempt++) {
    await driver.delayMs(100); found = await driver.findComponents(ON.text(text));
  }
  expect(found === undefined || found === null || found.length === 0).assertTrue();
}
export default function sequentialMediaDialogTest() {
  describe('SequentialMediaDialog', () => {
    for (const kind of ['document', 'video']) {
      it(kind + ' accepted prefix then unknown tail Cancel preserves tail and Send again never repeats prefix', 0, async () => {
        const driver = Driver.create(); await sequentialNativeReady(driver); SequentialMediaDialogFixture.reset(kind);
        const state = SequentialMediaDialogFixture.state;
        const title = localized($r('app.string.composer_media_resend_title').id, 'Send these files again?');
        const message = localized($r('app.string.composer_media_resend_message').id,
          'Some of these files may already have been sent. Sending again can create duplicates.');
        const cancel = localized($r('app.string.cancel').id, 'Cancel');
        const resend = localized($r('app.string.composer_album_resend_action').id, 'Send again');
        try {
          await clickSequentialFixture(driver); await requireSequentialText(driver, 'sequential mutations:2'); await requireSequentialText(driver, 'sequential busy:false');
          expect(state.uris).assertEqual('fixture:b'); expect(state.draft).assertEqual(''); expect(state.reply).assertEqual('0');
          expect(state.entities).assertEqual(0); expect(state.selection).assertEqual('0:0'); expect(state.preparations).assertEqual(2); expect(state.discarded).assertEqual(0);
          await clickSequentialFixture(driver); await requireSequentialText(driver, title); await requireSequentialText(driver, message);
          await requireSequentialText(driver, cancel); await requireSequentialText(driver, resend);
          expect(state.busy).assertTrue(); expect(state.mutations).assertEqual(2); expect(state.preparations).assertEqual(2);
          const screenshot = SequentialMediaDialogFixture.screenshotPath(); console.info('[SequentialMediaDialog] screenshot=' + screenshot);
          expect(await driver.screenCap(screenshot)).assertTrue();
          await clickSequentialText(driver, cancel); await absentSequentialText(driver, title); await requireSequentialText(driver, 'sequential busy:false');
          expect(state.uris).assertEqual('fixture:b'); expect(state.mutations).assertEqual(2); expect(state.preparations).assertEqual(2);
          expect(state.draft).assertEqual(''); expect(state.reply).assertEqual('0'); expect(state.entities).assertEqual(0); expect(state.selection).assertEqual('0:0');
          await clickSequentialFixture(driver); await requireSequentialText(driver, title); await clickSequentialText(driver, resend);
          await absentSequentialText(driver, title); await requireSequentialText(driver, 'sequential busy:false'); await requireSequentialText(driver, 'sequential mutations:3');
          expect(state.uris).assertEqual(''); expect(state.preparations).assertEqual(3); expect(state.discarded).assertEqual(0);
          expect(SequentialMediaDialogFixture.preparedUris().join('|')).assertEqual('fixture:a|fixture:b|fixture:b');
          const commands = SequentialMediaDialogFixture.commands(); expect(commands.length).assertEqual(3);
          expect(commands[0].payload.caption).assertEqual('\uD83D\uDE00 caption'); expect(commands[0].payload.replyToMessageId).assertEqual('55');
          for (let index = 0; index < commands.length; index++) {
            expect(commands[index].payload.chatId).assertEqual(42); expect(commands[index].payload.mediaKind).assertEqual(kind);
            if (index > 0) { expect(commands[index].payload.caption).assertEqual(''); expect(commands[index].payload.replyToMessageId).assertEqual('0'); }
          }
        } finally {
          try {
            const titles = await driver.findComponents(ON.text(title));
            if (titles !== undefined && titles !== null && titles.length > 0) {
              const buttons = await driver.findComponents(ON.text(cancel));
              if (buttons !== undefined && buttons !== null && buttons.length > 0) await buttons[0].click();
            }
          } catch (error) { console.info('[SequentialMediaDialog] cleanup failed: ' + (error as Error).message); }
        }
      });
    }
  });
}
