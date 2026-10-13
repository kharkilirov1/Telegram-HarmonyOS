import { describe, it, expect } from '@ohos/hypium';
import { Component, Driver, ON, abilityDelegatorRegistry } from '@kit.TestKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { localized } from '../../../main/ets/core/utils/AppResource';
import { PhotoSelectionPreviewFixture } from '../testability/components/PhotoSelectionPreviewFixture';

async function testAbilityReady(driver: Driver): Promise<void> {
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
        // Driver failures propagate; only the expected early GetTop error is retried.
        const scrolls = await driver.findComponents(ON.id('chat-test-fixture-scroll'));
        if (!waiting) break;
        if (scrolls !== undefined && scrolls !== null && scrolls.length > 0) return;
        diagnostic = 'TestAbility is current but its Scroll is not mounted';
      }
      // Yield the ability's event loop so WindowStage/loadContent can finish.
      await new Promise<void>((resolve) => { setTimeout(() => resolve(), 100); });
    }
    throw new Error('Native TestAbility/Scroll readiness timeout: ' + diagnostic);
  };
  const timeout = new Promise<void>((_resolve, reject) => {
    timeoutId = setTimeout(() => {
      waiting = false;
      reject(new Error('Native TestAbility/Scroll readiness timeout after 10000 ms: ' + diagnostic));
    }, 10000);
  });
  try { await Promise.race([ready(), timeout]); }
  finally {
    waiting = false;
    clearTimeout(timeoutId);
  }
}

async function visible(driver: Driver, id: string): Promise<Component> {
  const scroll = await driver.waitForComponent(ON.id('chat-test-fixture-scroll'), 5000);
  if (scroll === undefined || scroll === null) throw new Error('Test fixture Scroll is not mounted');
  const component = await scroll.scrollSearch(ON.id(id));
  if (component === undefined || component === null) throw new Error('Missing native preview component: ' + id);
  await driver.assertComponentExist(ON.id(id));
  return component;
}

async function click(driver: Driver, id: string): Promise<void> {
  const component = await visible(driver, id);
  expect(await component.isEnabled()).assertTrue();
  await component.click();
}

async function requireText(driver: Driver, text: string, fixtureId?: string): Promise<void> {
  console.info('[PhotoSelectionPreview] requireText=' + text + ', sessionBusy=' +
    PhotoSelectionPreviewFixture.session.isSendingMessage().toString() + ', composerBusy=' +
    PhotoSelectionPreviewFixture.view.composer.isSending.toString());
  // Fixture status rows are below the tall preview. Expose the stable row
  // before the existing text wait; a matching label elsewhere is insufficient.
  const footer = fixtureId === undefined ? undefined : await visible(driver, fixtureId);
  const component = await driver.waitForComponent(ON.text(text), 5000);
  if (component === undefined || component === null) throw new Error('Missing native preview text: ' + text);
  await driver.assertComponentExist(ON.text(text));
  if (footer !== undefined) expect(await footer.getText()).assertEqual(text);
}

async function decoded(driver: Driver, uri: string): Promise<void> {
  const state = PhotoSelectionPreviewFixture.state;
  for (let attempt = 0; attempt < 50 && (state.loadedUri !== uri || !state.loadSuccess ||
    state.decodedWidth <= 0 || state.decodedHeight <= 0); attempt++) {
    await driver.delayMs(100);
  }
  if (state.loadedUri !== uri || !state.loadSuccess || state.decodedWidth <= 0 || state.decodedHeight <= 0) {
    throw new Error('Native preview decode missing: requested=' + uri + ', loaded=' + state.loadedUri +
      ', success=' + state.loadSuccess.toString() + ', dimensions=' + state.decodedWidth.toString() + 'x' +
      state.decodedHeight.toString() + ', preparationError=' + state.preparationError);
  }
  expect(state.decodedWidth).assertEqual(240);
  expect(state.decodedHeight).assertEqual(160);
  expect(state.contentWidth > 0 && state.contentHeight > 0).assertTrue();
  if (Math.abs(state.contentWidth / state.contentHeight - 240 / 160) >= 0.02) {
    throw new Error('Native preview aspect mismatch: source=' + state.decodedWidth.toString() + 'x' +
      state.decodedHeight.toString() + ', rendered=' + state.contentWidth.toString() + 'x' + state.contentHeight.toString());
  }
  expect(Math.abs(state.contentWidth / state.contentHeight - 240 / 160) < 0.02).assertTrue();
  const component = await visible(driver, 'photo-preview-fixture-image');
  const bounds = await component.getBounds();
  expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
}

async function absent(driver: Driver, id: string): Promise<void> {
  let found = await driver.findComponents(ON.id(id));
  for (let attempt = 0; attempt < 50 && found !== undefined && found !== null && found.length > 0; attempt++) {
    await driver.delayMs(100);
    found = await driver.findComponents(ON.id(id));
  }
  if (found !== undefined && found !== null && found.length > 0) throw new Error('Native preview component remains: ' + id);
  expect(found === undefined || found === null || found.length === 0).assertTrue();
}

function position(index: number, count: number): string {
  return localized($r('app.string.composer_photo_preview_photo').id, 'Photo') + ' ' + index.toString() + ' / ' + count.toString();
}

async function renderedPosition(driver: Driver, index: number, count: number): Promise<void> {
  const component = await visible(driver, 'photo-preview-fixture-position');
  const expected = position(index, count);
  let actual = await component.getText();
  for (let attempt = 0; attempt < 50 && actual !== expected; attempt++) {
    await driver.delayMs(100);
    actual = await component.getText();
  }
  if (actual !== expected) throw new Error('Native selected position mismatch: expected=' + expected + ', actual=' + actual);
  expect(actual).assertEqual(expected);
  const bounds = await component.getBounds();
  expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
}

function luminance(argb: number): number {
  const red = ((argb >>> 16) & 255) / 255;
  const green = ((argb >>> 8) & 255) / 255;
  const blue = (argb & 255) / 255;
  return 0.2126 * linearColor(red) + 0.7152 * linearColor(green) + 0.0722 * linearColor(blue);
}

function linearColor(channel: number): number {
  return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
}

function contrast(foreground: number, background: number): number {
  const a = luminance(foreground);
  const b = luminance(background);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

function resolvedTextContrast(): void {
  const state = PhotoSelectionPreviewFixture.state;
  expect(state.textColor >>> 24).assertEqual(255);
  expect(state.primaryBackgroundColor >>> 24).assertEqual(255);
  expect(state.secondaryBackgroundColor >>> 24).assertEqual(255);
  expect(contrast(state.textColor, state.primaryBackgroundColor) >= 4.5).assertTrue();
  expect(contrast(state.textColor, state.secondaryBackgroundColor) >= 4.5).assertTrue();
}

async function renderedOrdinal(driver: Driver, index: number): Promise<void> {
  const component = await visible(driver, 'photo-preview-fixture-ordinal-' + index.toString());
  expect(await component.getText()).assertEqual((index + 1).toString());
  const bounds = await component.getBounds();
  expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
}

export default function photoSelectionPreviewTest() {
  describe('PhotoSelectionPreview', () => {
    it('renders original native photos and applies URI edits through the actual composer owner', 0, async () => {
      const driver = Driver.create();
      try {
        await testAbilityReady(driver);
        await click(driver, 'photo-preview-fixture-prepare');
        const state = PhotoSelectionPreviewFixture.state;
        for (let attempt = 0; attempt < 100 && !state.ready && state.preparationError.length === 0; attempt++) {
          await driver.delayMs(100);
        }
        if (!state.ready) throw new Error('Original preview PNG preparation failed: ' + state.preparationError);
        expect(state.sampleUris.length).assertEqual(10);
        expect(new Set(state.sampleUris).size).assertEqual(10);
        resolvedTextContrast();
        const first = state.sampleUris[0];
        const second = state.sampleUris[1];
        const third = state.sampleUris[2];
        const session = PhotoSelectionPreviewFixture.session;
        expect(session.hasActiveChatState()).assertTrue();
        expect(session.getSendMediaUseCase('photo') !== undefined).assertTrue();
        await decoded(driver, first);
        await renderedPosition(driver, 1, 3);
        await renderedOrdinal(driver, 0);
        expect(await (await visible(driver, 'photo-preview-fixture-move-earlier')).isEnabled()).assertFalse();
        await visible(driver, 'photo-preview-fixture-remove');
        expect(await driver.screenCap(PhotoSelectionPreviewFixture.screenshotPath('tg-photo-selection-preview.png'))).assertTrue();

        // Native thumbnail selection and earlier/later buttons preserve URI identity.
        await click(driver, 'photo-preview-fixture-thumb-1');
        await decoded(driver, second);
        await renderedPosition(driver, 2, 3);
        const revision = session.getComposerInputRevision();
        await click(driver, 'photo-preview-fixture-move-earlier');
        await renderedPosition(driver, 1, 3);
        await renderedOrdinal(driver, 0);
        expect(session.getPendingAttachmentUris().join('|')).assertEqual([second, first, third].join('|'));
        expect(session.getComposerInputRevision() > revision).assertTrue();
        expect(state.lastMoveUri).assertEqual(second);
        expect(state.lastMoveDirection).assertEqual(-1);
        await decoded(driver, second);
        expect(await (await visible(driver, 'photo-preview-fixture-move-earlier')).isEnabled()).assertFalse();
        await visible(driver, 'photo-preview-fixture-remove');
        expect(await driver.screenCap(PhotoSelectionPreviewFixture.screenshotPath('tg-photo-selection-preview-reordered.png'))).assertTrue();
        // URI keys retain their event payloads, while IDs/ordinals bind to the new order.
        await click(driver, 'photo-preview-fixture-thumb-1');
        await decoded(driver, first);
        await renderedPosition(driver, 2, 3);
        await click(driver, 'photo-preview-fixture-thumb-0');
        await decoded(driver, second);
        await renderedPosition(driver, 1, 3);
        await click(driver, 'photo-preview-fixture-move-later');
        await renderedPosition(driver, 2, 3);
        expect(session.getPendingAttachmentUris().join('|')).assertEqual([first, second, third].join('|'));
        expect(state.lastMoveUri).assertEqual(second);
        expect(state.lastMoveDirection).assertEqual(1);
        await click(driver, 'photo-preview-fixture-remove');
        await renderedPosition(driver, 1, 2);
        expect(state.lastRemovedUri).assertEqual(second);
        expect(session.getPendingAttachmentUris().join('|')).assertEqual([first, third].join('|'));
        await decoded(driver, first);
        expect(session.getDraftText()).assertEqual('preview fixture caption');
        expect(session.getReplyToMessageId()).assertEqual('42');

        // Busy is the real adapter -> canonical @Trace field, not fixture state.
        await click(driver, 'photo-preview-fixture-busy');
        await requireText(driver, 'preview busy:true', 'photo-preview-fixture-busy-state');
        expect(PhotoSelectionPreviewFixture.view.composer.isSending).assertTrue();
        expect(session.isSendingMessage()).assertTrue();
        expect(await (await visible(driver, 'photo-preview-fixture-remove')).isEnabled()).assertFalse();
        expect(await (await visible(driver, 'photo-preview-fixture-move-later')).isEnabled()).assertFalse();
        expect(await (await visible(driver, 'photo-preview-fixture-thumb-1')).isEnabled()).assertFalse();
        expect(state.moveCalls).assertEqual(2);
        expect(state.removeCalls).assertEqual(1);
        await click(driver, 'photo-preview-fixture-busy');
        await requireText(driver, 'preview busy:false', 'photo-preview-fixture-busy-state');
        expect(await (await visible(driver, 'photo-preview-fixture-remove')).isEnabled()).assertTrue();

        // Select the final item to verify its boundary and then remove it.
        await click(driver, 'photo-preview-fixture-thumb-1');
        await decoded(driver, third);
        await renderedPosition(driver, 2, 2);
        expect(await (await visible(driver, 'photo-preview-fixture-move-later')).isEnabled()).assertFalse();
        await click(driver, 'photo-preview-fixture-remove');
        await renderedPosition(driver, 1, 1);
        expect(state.lastRemovedUri).assertEqual(third);
        expect(session.getPendingAttachmentUris().join('|')).assertEqual(first);
        await decoded(driver, first);
        expect(await (await visible(driver, 'photo-preview-fixture-move-earlier')).isEnabled()).assertFalse();
        expect(await (await visible(driver, 'photo-preview-fixture-move-later')).isEnabled()).assertFalse();

        // A new unavailable URI must show an error rather than the prior valid photo.
        await click(driver, 'photo-preview-fixture-missing');
        const unavailable = localized($r('app.string.composer_photo_preview_unavailable').id, 'Photo unavailable');
        await visible(driver, 'photo-preview-fixture-error');
        await requireText(driver, unavailable);
        const errorBounds = await (await visible(driver, 'photo-preview-fixture-error')).getBounds();
        expect(errorBounds.right > errorBounds.left && errorBounds.bottom > errorBounds.top).assertTrue();
        resolvedTextContrast();
        expect(state.loadedUri).assertEqual(state.missingUri);
        expect(state.loadSuccess).assertFalse();
        expect(state.decodedWidth).assertEqual(0);
        expect(state.decodedHeight).assertEqual(0);
        expect(state.contentWidth).assertEqual(0);
        expect(state.contentHeight).assertEqual(0);
        await visible(driver, 'photo-preview-fixture-remove');
        expect(await driver.screenCap(PhotoSelectionPreviewFixture.screenshotPath('tg-photo-selection-preview-error.png'))).assertTrue();
        await click(driver, 'photo-preview-fixture-remove');
        await requireText(driver, 'preview photos:0', 'photo-preview-fixture-count');
        expect(state.lastRemovedUri).assertEqual(state.missingUri);
        expect(session.getPendingAttachmentUris().length).assertEqual(0);
        expect(session.getPendingAttachmentKind()).assertEqual('');
        await absent(driver, 'photo-preview-fixture-image');
        await absent(driver, 'photo-preview-fixture-remove');
        await absent(driver, 'photo-preview-fixture-error');
        expect(session.getDraftText()).assertEqual('preview fixture caption');
        expect(session.getReplyToMessageId()).assertEqual('42');
        expect(state.gatewayCalls).assertEqual(0);

        // Exercise the actual maximum selection, including horizontal native scrolling.
        await click(driver, 'photo-preview-fixture-ten');
        await decoded(driver, first);
        await renderedPosition(driver, 1, 10);
        expect(session.getPendingAttachmentUris().length).assertEqual(10);
        expect(session.getPendingAttachmentUris().join('|')).assertEqual(state.sampleUris.join('|'));
        const strip = await visible(driver, 'photo-preview-fixture-strip');
        const tenth = await strip.scrollSearch(ON.id('photo-preview-fixture-thumb-9'), false);
        if (tenth === undefined || tenth === null) throw new Error('Native ten-photo strip does not expose thumbnail 10');
        await driver.assertComponentExist(ON.id('photo-preview-fixture-thumb-9'));
        expect(await tenth.isEnabled()).assertTrue();
        await tenth.click();
        await decoded(driver, state.sampleUris[9]);
        await renderedPosition(driver, 10, 10);
        expect(await (await visible(driver, 'photo-preview-fixture-move-later')).isEnabled()).assertFalse();
        expect(await (await visible(driver, 'photo-preview-fixture-move-earlier')).isEnabled()).assertTrue();
        expect(await driver.screenCap(PhotoSelectionPreviewFixture.screenshotPath('tg-photo-selection-preview-ten.png'))).assertTrue();
        expect(session.getDraftText()).assertEqual('preview fixture caption');
        expect(session.getReplyToMessageId()).assertEqual('42');
        expect(state.gatewayCalls).assertEqual(0);
      } finally {
        // Cleanup cannot mask the primary assertion or leave a tall UI over old fixtures.
        try { PhotoSelectionPreviewFixture.collapse(); }
        catch (error) { console.info('[PhotoSelectionPreview] cleanup failed: ' + (error as Error).message); }
      }
    });
  });
}
