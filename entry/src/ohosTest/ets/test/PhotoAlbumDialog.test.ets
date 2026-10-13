import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON } from '@kit.TestKit';
import { localized } from '../../../main/ets/core/utils/AppResource';
import { PhotoAlbumDialogFixture } from '../testability/components/PhotoAlbumDialogFixture';

async function nativePromptDiagnostic(driver: Driver, validColor: boolean): Promise<string> {
  PhotoAlbumDialogFixture.startUnknownPromptDiagnostic(validColor);
  const done = localized($r('app.string.done').id, 'Done');
  const title = localized($r('app.string.composer_album_unknown_title').id, 'Sending result unknown');
  const button = await driver.waitForComponent(ON.text(done), 1500);
  const titles = await driver.findComponents(ON.text(title));
  const titlePresent = titles !== undefined && titles !== null && titles.length > 0;
  const buttonPresent = button !== undefined && button !== null;
  if (titlePresent && button !== undefined && button !== null) {
    await driver.assertComponentExist(ON.text(done));
    await button.click();
    await driver.findComponents(ON.text(title));
  }
  return PhotoAlbumDialogFixture.state.nativePromptDiagnostic + ', titlePresent=' + titlePresent.toString() +
    ', DonePresent=' + buttonPresent.toString();
}

async function requireText(driver: Driver, text: string): Promise<void> {
  const component = await driver.waitForComponent(ON.text(text), 5000);
  if (component === undefined || component === null) {
    const state = PhotoAlbumDialogFixture.state;
    let screenshot = 'not attempted';
    try {
      const path = PhotoAlbumDialogFixture.screenshotPath('tg-photo-album-missing.png');
      console.info('[PhotoAlbumDialog] diagnostic screenshot=' + path);
      screenshot = path + ', result=' + (await driver.screenCap(path)).toString();
    } catch (error) {
      screenshot = 'failed: ' + (error as Error).message;
    }
    let nativePrompt = 'not attempted';
    let nativeColorContexts = 'not attempted';
    if (state.mutations === 1 && !state.sending &&
      text === localized($r('app.string.composer_album_unknown_title').id, 'Sending result unknown')) {
      try {
        nativeColorContexts = await PhotoAlbumDialogFixture.colorContextDiagnostic();
        nativePrompt = 'production: ' + await nativePromptDiagnostic(driver, false);
        if (PhotoAlbumDialogFixture.state.nativePromptDiagnostic.startsWith('rejected')) {
          nativePrompt += '; valid-color control: ' + await nativePromptDiagnostic(driver, true);
        }
      } catch (error) {
        nativePrompt += '; diagnostic failure: ' + (error as Error).message;
      }
    }
    throw new Error('Missing native UI text: ' + text + '; fixture mutations=' + state.mutations.toString() +
      ', preparedFiles=' + state.preparedFiles.toString() + ', busy=' + state.sending.toString() +
      ', selectedPhotos=' + state.selectedPhotos.toString() + ', gatewayCalls=' + state.gatewayCalls.toString() +
      ', singleSends=' + state.singleSends.toString() + '; diagnosticScreenshot=' + screenshot + '; nativePrompt=' + nativePrompt +
      '; nativeColorContexts=' + nativeColorContexts);
  }
  expect(component === undefined || component === null).assertFalse();
  await driver.assertComponentExist(ON.text(text));
}

async function absentText(driver: Driver, text: string): Promise<void> {
  let found = await driver.findComponents(ON.text(text));
  for (let attempt = 0; attempt < 50 && found !== undefined && found !== null && found.length > 0; attempt++) {
    await driver.delayMs(100);
    found = await driver.findComponents(ON.text(text));
  }
  expect(found === undefined || found === null || found.length === 0).assertTrue();
}

async function clickText(driver: Driver, text: string): Promise<void> {
  const component = await driver.waitForComponent(ON.text(text), 5000);
  if (component === undefined || component === null) throw new Error('Missing native dialog button: ' + text);
  expect(component === undefined || component === null).assertFalse();
  await driver.assertComponentExist(ON.text(text));
  await component.click();
}

async function sendFixture(driver: Driver): Promise<void> {
  const component = await driver.waitForComponent(ON.id('photo-album-fixture-send'), 5000);
  expect(component === undefined || component === null).assertFalse();
  if (component === undefined || component === null) throw new Error('Photo album fixture is not mounted');
  await driver.assertComponentExist(ON.id('photo-album-fixture-send'));
  await component.click();
}

export default function photoAlbumDialogTest() {
  describe('PhotoAlbumDialog', () => {
    it('uses actual native unknown/resend dialogs and requires explicit repeat-send approval', 0, async () => {
      const driver = Driver.create();
      const mounted = await driver.waitForComponent(ON.id('photo-album-fixture-send'), 5000);
      expect(mounted === undefined || mounted === null).assertFalse();
      if (mounted === undefined || mounted === null) throw new Error('Photo album fixture is not mounted');
      PhotoAlbumDialogFixture.reset();
      const state = PhotoAlbumDialogFixture.state;
      const unknownTitle = localized($r('app.string.composer_album_unknown_title').id, 'Sending result unknown');
      const unknownMessage = localized($r('app.string.composer_album_unknown_message').id,
        'Check the chat before sending these photos again. They may already have been sent.');
      const resendTitle = localized($r('app.string.composer_album_resend_title').id, 'Send these photos again?');
      const resendMessage = localized($r('app.string.composer_album_resend_message').id,
        'These photos may already have been sent. Sending again can create duplicates.');
      const done = localized($r('app.string.done').id, 'Done');
      const cancel = localized($r('app.string.cancel').id, 'Cancel');
      const resend = localized($r('app.string.composer_album_resend_action').id, 'Send again');
      try {
        // The real controller receives the mounted component's actual UIContext.
        // Its first fake album mutation rejects with the real unknown error type.
        await sendFixture(driver);
        await requireText(driver, unknownTitle);
        await requireText(driver, unknownMessage);
        await requireText(driver, done);
        const unknownScreenshot = PhotoAlbumDialogFixture.screenshotPath('tg-photo-album-unknown.png');
        console.info('[PhotoAlbumDialog] unknown screenshot=' + unknownScreenshot);
        expect(await driver.screenCap(unknownScreenshot)).assertTrue();
        expect(state.mutations).assertEqual(1);
        expect(state.preparedFiles).assertEqual(2);
        expect(state.selectedPhotos).assertEqual(2);
        expect(state.draftText).assertEqual('album fixture caption');
        expect(state.sending).assertTrue();
        await clickText(driver, done);
        await requireText(driver, 'album busy:false');
        await absentText(driver, unknownTitle);
        await absentText(driver, unknownMessage);

        // The next ordinary tap cannot silently repeat the uncertain mutation.
        await sendFixture(driver);
        await requireText(driver, resendTitle);
        await requireText(driver, resendMessage);
        await requireText(driver, cancel);
        await requireText(driver, resend);
        const resendScreenshot = PhotoAlbumDialogFixture.screenshotPath('tg-photo-album-resend.png');
        console.info('[PhotoAlbumDialog] resend screenshot=' + resendScreenshot);
        expect(await driver.screenCap(resendScreenshot)).assertTrue();
        expect(state.mutations).assertEqual(1);
        expect(state.preparedFiles).assertEqual(2);
        await clickText(driver, cancel);
        await requireText(driver, 'album busy:false');
        await absentText(driver, resendTitle);
        await absentText(driver, resendMessage);
        expect(state.mutations).assertEqual(1);
        expect(state.preparedFiles).assertEqual(2);
        expect(state.selectionClears).assertEqual(0);
        expect(state.selectedPhotos).assertEqual(2);
        expect(state.draftText).assertEqual('album fixture caption');

        // Explicit approval permits one new fake mutation and owned input cleanup.
        await sendFixture(driver);
        await requireText(driver, resendTitle);
        await requireText(driver, resendMessage);
        await clickText(driver, resend);
        await requireText(driver, 'album busy:false');
        await requireText(driver, 'album mutations:2');
        await requireText(driver, 'album photos:0');
        await absentText(driver, resendTitle);
        await absentText(driver, resendMessage);
        await absentText(driver, unknownTitle);
        expect(state.mutations).assertEqual(2);
        expect(state.preparedFiles).assertEqual(4);
        expect(state.discardedFiles).assertEqual(0);
        expect(state.selectionClears).assertEqual(1);
        expect(state.draftText).assertEqual('');
        expect(state.gatewayCalls).assertEqual(0);
        expect(state.singleSends).assertEqual(0);
        const attempts = PhotoAlbumDialogFixture.capturedAttempts();
        expect(attempts.length).assertEqual(2);
        for (const attempt of attempts) {
          expect(attempt.chatId).assertEqual(900001);
          expect(attempt.localPaths.join('|')).assertEqual('/data/fixture/first-photo.jpg|/data/fixture/second-photo.jpg');
          expect(attempt.caption).assertEqual('album fixture caption');
          expect(attempt.replyToMessageId).assertEqual('0');
        }
      } finally {
        // A failed assertion must not leave our known modal over later UI cases.
        // Cleanup uses a currently found button and cannot replace a primary error.
        try {
          const unknown = await driver.findComponents(ON.text(unknownTitle));
          const confirmation = await driver.findComponents(ON.text(resendTitle));
          let closeText = '';
          if (unknown !== undefined && unknown !== null && unknown.length > 0) closeText = done;
          else if (confirmation !== undefined && confirmation !== null && confirmation.length > 0) closeText = cancel;
          if (closeText.length > 0) {
            const buttons = await driver.findComponents(ON.text(closeText));
            if (buttons !== undefined && buttons !== null && buttons.length > 0) await buttons[0].click();
            else console.info('[PhotoAlbumDialog] cleanup button already absent: ' + closeText);
          }
        } catch (error) {
          console.info('[PhotoAlbumDialog] cleanup failed: ' + (error as Error).message);
        }
      }
    });
  });
}
