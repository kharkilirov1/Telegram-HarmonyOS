import { describe, it, expect } from '@ohos/hypium';
import { Component, Driver, ON, abilityDelegatorRegistry } from '@kit.TestKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TimelineTransactionFixture, TimelineScrollEvent, timelineTimingNow } from '../testability/TimelineTransactionFixture';
import { TimelineUpdateFixture } from '../testability/components/TimelineUpdateFixture';

class NativeTimelineMeasurement {
  phase: string = '';
  observationGeneration: number = 0;
  identity: string = '';
  index: number = -1;
  time: number = 0;
  screenLeft: number = 0;
  screenTop: number = 0;
  screenRight: number = 0;
  screenBottom: number = 0;
  itemX: number = 0;
  itemY: number = 0;
  itemWidth: number = 0;
  itemHeight: number = 0;
  listTop: number = 0;
  listBottom: number = 0;
  count: number = 0;
  olderCalls: number = 0;
  newerCalls: number = 0;
  events: TimelineScrollEvent[] = [];
}

class NativeTimelineObservation {
  deadline: number = 0;
  generation: number = 0;
  samples: number = 0;
  acquisitions: number = 0;
  row?: Component;
  list?: Component;
}

async function waitForDisappearance(fixture: TimelineTransactionFixture): Promise<void> {
  let timeoutId: number = -1;
  try {
    await Promise.race<void>([fixture.disappeared, new Promise<void>((_resolve, reject) => {
      timeoutId = setTimeout(() => reject(new Error('Native timeline disappearance timeout')), 5000) as number;
    })]);
  } finally { if (timeoutId >= 0) clearTimeout(timeoutId); }
}

async function fixtureRootReady(driver: Driver): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  let diagnostic = 'TestAbility not current';
  const deadline = Date.now() + 10000;
  while (Date.now() < deadline) {
    let current = false;
    try {
      const ability = await delegator.getCurrentTopAbility();
      if (ability !== undefined && ability !== null && ability.context !== undefined && ability.context !== null &&
        ability.context.abilityInfo.name === 'TestAbility' && ability.context.currentHapModuleInfo.name === $r('app.color.background_primary').moduleName) {
        TimelineUpdateFixture.filesDir = ability.context.filesDir;
        current = true;
      }
    } catch (error) {
      const native = error as BusinessError;
      if (native.code !== 16000100) throw new Error('Cannot obtain TestAbility: ' + native.message);
      diagnostic = native.message;
    }
    if (current) {
      const roots = await driver.findComponents(ON.id('chat-test-fixture-scroll'));
      if (roots !== undefined && roots !== null && roots.length > 0) return;
      diagnostic = 'TestAbility content is not mounted';
    }
    await driver.delayMs(100);
  }
  throw new Error('Native timeline mount timeout: ' + diagnostic);
}

async function required(driver: Driver, id: string, timeout: number = 5000, deadline: number = 0): Promise<Component> {
  const component = await driver.waitForComponent(ON.id(id), timeout);
  expect(component !== undefined && component !== null).assertTrue();
  if (component === undefined || component === null) throw new Error('Missing native timeline component: ' + id);
  if (deadline > 0 && Date.now() >= deadline) throw new Error('Native timeline observation deadline');
  await driver.assertComponentExist(ON.id(id));
  return component;
}

async function openTimeline(driver: Driver): Promise<TimelineTransactionFixture> {
  await fixtureRootReady(driver);
  const root = await required(driver, 'chat-test-fixture-scroll');
  const launch = await root.scrollSearch(ON.id('timeline-update-open'));
  expect(launch !== undefined && launch !== null).assertTrue();
  if (launch === undefined || launch === null) throw new Error('Missing timeline fixture launcher');
  await launch.click();
  const list = await required(driver, 'timeline-update-list');
  const bounds = await list.getBounds();
  expect(bounds.bottom > bounds.top && bounds.right > bounds.left).assertTrue();
  const fixture = TimelineUpdateFixture.current;
  expect(fixture.mounted).assertTrue();
  expect(fixture.dataSource.totalCount()).assertEqual(81);
  return fixture;
}

// No scrollSearch, scrollToIndex or gesture is allowed in this measurement: a
// failed retention must not be repaired by the test while finding the anchor.
async function measure(driver: Driver, fixture: TimelineTransactionFixture,
  id: number, phase: string, observation: NativeTimelineObservation): Promise<NativeTimelineMeasurement> {
  while (true) {
    if (Date.now() >= observation.deadline) throw new Error('Native timeline observation deadline');
    if (!fixture.mounted || TimelineUpdateFixture.current !== fixture) throw new Error('Native timeline owner changed');
    try {
      if (observation.row === undefined) {
        observation.acquisitions++;
        observation.row = await required(driver, 'timeline-update-msg_' + id.toString(), Math.max(1, observation.deadline - Date.now()), observation.deadline);
      }
      if (Date.now() >= observation.deadline) throw new Error('Native timeline observation deadline');
      const bounds = await observation.row.getBounds();
      if (Date.now() >= observation.deadline) throw new Error('Native timeline observation deadline');
      if (observation.list === undefined) {
        observation.acquisitions++;
        observation.list = await required(driver, 'timeline-update-list', Math.max(1, observation.deadline - Date.now()), observation.deadline);
      }
      if (Date.now() >= observation.deadline) throw new Error('Native timeline observation deadline');
      const listBounds = await observation.list.getBounds();
      if (!fixture.mounted || TimelineUpdateFixture.current !== fixture) throw new Error('Native timeline owner changed');
      if (Date.now() >= observation.deadline) throw new Error('Native timeline observation deadline');
      const index = fixture.indexOf(id);
      expect(index >= 0).assertTrue();
      const rect = fixture.listScroller.getItemRect(index);
      expect(bounds.bottom > bounds.top && bounds.right > bounds.left).assertTrue();
      expect(rect.width > 0 && rect.height > 0).assertTrue();
      expect(bounds.bottom > listBounds.top && bounds.top < listBounds.bottom).assertTrue();
      const result = new NativeTimelineMeasurement();
      result.observationGeneration = observation.generation;
      result.phase = phase; result.identity = 'msg_' + id.toString(); result.index = index; result.time = Date.now();
      result.screenLeft = bounds.left; result.screenTop = bounds.top; result.screenRight = bounds.right; result.screenBottom = bounds.bottom;
      result.itemX = rect.x; result.itemY = rect.y; result.itemWidth = rect.width; result.itemHeight = rect.height;
      result.listTop = listBounds.top; result.listBottom = listBounds.bottom; result.count = fixture.dataSource.totalCount();
      result.olderCalls = fixture.olderCalls; result.newerCalls = fixture.newerCalls; result.events = fixture.events.slice();
      observation.samples++;
      return result;
    } catch (error) {
      if ((error as BusinessError).code !== 17000004) throw error as Error;
      // Only this SDK stale/invisible-handle error permits reacquisition. Never
      // move the viewport or reset the existing invocation deadline.
      observation.row = undefined; observation.list = undefined; observation.generation++;
    }
  }
}

async function settled(driver: Driver, fixture: TimelineTransactionFixture,
  id: number, phase: string): Promise<NativeTimelineMeasurement> {
  const deadline = Date.now() + 5000;
  const observation = new NativeTimelineObservation(); observation.deadline = deadline;
  const startMono = timelineTimingNow();
  let stable: number = 0;
  let completed: boolean = false;
  try {
    let prior = await measure(driver, fixture, id, phase, observation);
    while (Date.now() < deadline) {
      await driver.delayMs(100);
      const current = await measure(driver, fixture, id, phase, observation);
      if (Math.abs(prior.screenTop - current.screenTop) <= 1 && Math.abs(prior.itemY - current.itemY) <= 0.5 &&
        prior.index === current.index && prior.count === current.count &&
        prior.observationGeneration === current.observationGeneration) stable++;
      else stable = 0;
      prior = current;
      if (stable >= 3) { completed = true; return current; }
    }
    throw new Error('Native timeline layout did not settle for ' + phase);
  } finally {
    try {
      console.info('[TimelineTiming] ' + JSON.stringify({ format: 'observation-v1', event: 'settled-end',
        phase: phase, fixtureId: fixture.timingId, startMono: startMono, endMono: timelineTimingNow(),
        deadlineWall: deadline, wall: Date.now(), samples: observation.samples, stable: stable,
        acquisitions: observation.acquisitions, staleReacquisitions: observation.generation, completed: completed }));
    } catch (_) {}
  }
}

function retained(before: NativeTimelineMeasurement, after: NativeTimelineMeasurement): void {
  expect(after.identity).assertEqual(before.identity);
  // UiTest rectangles are screen pixels; Scroller item rectangles use vp.
  expect(Math.abs(after.screenTop - before.screenTop) <= 3).assertTrue();
  expect(Math.abs(after.itemY - before.itemY) <= 1).assertTrue();
  expect(Math.abs(after.screenBottom - before.screenBottom) <= 3).assertTrue();
}

function evidence(name: string, records: NativeTimelineMeasurement[]): void {
  const json = JSON.stringify(records);
  hilog.info(0x0021, 'TimelineUpdateNative', '%{public}s %{public}s', name, json);
  const file = fileIo.openSync(TimelineUpdateFixture.filesDir + '/' + name + '.json',
    fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
  try { fileIo.writeSync(file.fd, json); } finally { fileIo.closeSync(file); }
}

async function absentText(driver: Driver, text: string): Promise<void> {
  const found = await driver.findComponents(ON.text(text));
  expect(found === undefined || found === null || found.length === 0).assertTrue();
}

export default function timelineUpdateNativeTest() {
  describe('TimelineUpdateNative', () => {
    it('real native List retains stable anchor through ordered edits and stamped row refresh', 0, async () => {
      const driver = Driver.create();
      const records: NativeTimelineMeasurement[] = [];
      let opened = false;
      try {
        const fixture = await openTimeline(driver); opened = true;
        fixture.guardProgrammaticScroll();
        fixture.listScroller.scrollToIndex(fixture.indexOf(400), false, ScrollAlign.START);
        const before = await settled(driver, fixture, 400, 'before'); records.push(before);
        expect(before.index).assertEqual(40);
        expect(await driver.screenCap(TimelineUpdateFixture.filesDir + '/timeline-update-before.png')).assertTrue();
        let ids = TimelineUpdateFixture.rows();
        ids = [...ids, 145].sort((a: number, b: number) => a - b);
        fixture.apply(ids);
        let after = await settled(driver, fixture, 400, 'insert-above-variable-height-row'); records.push(after); retained(before, after);
        expect(after.index).assertEqual(41);
        ids = ids.filter((id: number) => id !== 150);
        fixture.apply(ids);
        after = await settled(driver, fixture, 400, 'delete-above-variable-height-row'); records.push(after); retained(before, after);
        expect(after.index).assertEqual(40);
        ids = [...ids, 405].sort((a: number, b: number) => a - b);
        fixture.apply(ids);
        after = await settled(driver, fixture, 400, 'insert-visible-after-anchor'); records.push(after); retained(before, after);
        await required(driver, 'timeline-update-msg_405');
        ids = ids.filter((id: number) => id !== 410);
        fixture.apply(ids);
        after = await settled(driver, fixture, 400, 'delete-visible-after-anchor'); records.push(after); retained(before, after);
        ids = [...ids, 900]; fixture.apply(ids);
        after = await settled(driver, fixture, 400, 'append-below'); records.push(after); retained(before, after);
        expect(fixture.bottomCalls).assertEqual(0);
        fixture.apply(ids, 400, 1);
        after = await settled(driver, fixture, 400, 'visible-render-key-refresh'); records.push(after); retained(before, after);
        expect(await (await required(driver, 'timeline-update-msg_400')).getText()).assertEqual('timeline:400:v1');
        await absentText(driver, 'timeline:400:v0');
        const count = fixture.recorder.events.length;
        fixture.apply(ids, 400, 1);
        after = await settled(driver, fixture, 400, 'identical-repeat'); records.push(after); retained(before, after);
        expect(fixture.recorder.events.length).assertEqual(count);
        for (let cycle = 0; cycle < 3; cycle++) {
          fixture.apply([...ids, 135].sort((a: number, b: number) => a - b), 400, 1);
          after = await settled(driver, fixture, 400, 'cycle-insert-' + cycle.toString()); records.push(after); retained(before, after);
          fixture.apply(ids, 400, 1);
          after = await settled(driver, fixture, 400, 'cycle-delete-' + cycle.toString()); records.push(after); retained(before, after);
        }
        expect(fixture.olderCalls).assertEqual(0); expect(fixture.newerCalls).assertEqual(0);
        // Trigger an update from a real active native drag callback, rather than
        // guessing a delay or making concurrent UiTest calls during swipe.
        fixture.onActiveDrag = () => {
          ids = [...ids, 125].sort((a: number, b: number) => a - b);
          fixture.apply(ids, 400, 2);
        };
        const listBounds = await (await required(driver, 'timeline-update-list')).getBounds();
        const swipeX = Math.floor((listBounds.left + listBounds.right) / 2);
        await driver.swipe(swipeX, Math.floor(listBounds.top + 60), swipeX, Math.floor(listBounds.top + 220), 400);
        expect(fixture.activeDragUpdateCount).assertEqual(1);
        after = await settled(driver, fixture, 400, 'update-during-real-native-drag'); records.push(after);
        expect(Math.abs(after.screenTop - before.screenTop) > 3).assertTrue();
        expect(await (await required(driver, 'timeline-update-msg_400')).getText()).assertEqual('timeline:400:v2');
        await absentText(driver, 'timeline:400:v1');
        expect(fixture.dataSource.totalCount()).assertEqual(ids.length + 1);
        expect(fixture.bottomCalls).assertEqual(0);
        // A large tail update must remember the pre-diff bottom position, even
        // though the old visible index is far from the new final count.
        fixture.guardProgrammaticScroll();
        fixture.listScroller.scrollToIndex(fixture.dataSource.totalCount() - 1, false, ScrollAlign.END);
        await settled(driver, fixture, 900, 'at-bottom-before-large-append');
        expect(fixture.listScroller.isAtEnd()).assertTrue();
        const extra: number[] = [];
        for (let index = 1; index <= 20; index++) extra.push(900 + index * 10);
        ids = [...ids, ...extra];
        fixture.apply(ids, 400, 2);
        after = await settled(driver, fixture, 1100, 'at-bottom-after-large-append'); records.push(after);
        expect(fixture.listScroller.isAtEnd()).assertTrue();
        expect(fixture.lastVisibleEndIndex).assertEqual(fixture.dataSource.totalCount() - 1);
        expect(after.screenBottom <= after.listBottom + 3).assertTrue();
        expect(fixture.bottomCalls).assertEqual(1);
        expect(await driver.screenCap(TimelineUpdateFixture.filesDir + '/timeline-update-after.png')).assertTrue();
      } finally {
        if (records.length > 0) evidence('timeline-update-anchor-evidence', records);
        if (opened) await driver.pressBack();
      }
    });
    it('native maintained deletion callback cannot paginate at the shifted top threshold', 0, async () => {
      const driver = Driver.create(); const records: NativeTimelineMeasurement[] = []; let opened = false;
      try {
        const fixture = await openTimeline(driver); opened = true;
        fixture.guardProgrammaticScroll();
        fixture.listScroller.scrollToIndex(fixture.indexOf(260), false, ScrollAlign.START);
        const before = await settled(driver, fixture, 260, 'threshold-before'); records.push(before);
        // Allow the setup's guard to expire. Deletion must arm its own protection.
        await driver.delayMs(400);
        fixture.blockAutoPaginationUntilUserScroll = false;
        fixture.suppressLoadOlderUntil = 0;
        fixture.olderCalls = 0; fixture.newerCalls = 0; const eventStart = fixture.events.length;
        fixture.apply(TimelineUpdateFixture.rows().filter((id: number) => id !== 10 && id !== 20));
        const after = await settled(driver, fixture, 260, 'threshold-after-delete'); records.push(after); retained(before, after);
        expect(after.index).assertEqual(24);
        const nativeIndices = fixture.events.slice(eventStart).filter((event: TimelineScrollEvent) => event.kind === 'index');
        expect(nativeIndices.length > 0).assertTrue();
        expect(nativeIndices.some((event: TimelineScrollEvent) => event.start === 24 && !event.applying)).assertTrue();
        expect(fixture.olderCalls).assertEqual(0); expect(fixture.newerCalls).assertEqual(0);
        // Guard expiration plus an actual native user drag must restore ordinary
        // top-edge pagination; protection cannot become a permanent disable.
        await driver.delayMs(400);
        const listBounds = await (await required(driver, 'timeline-update-list')).getBounds();
        const swipeX = Math.floor((listBounds.left + listBounds.right) / 2);
        await driver.swipe(swipeX, Math.floor(listBounds.top + 60), swipeX, Math.floor(listBounds.top + 220), 400);
        expect(fixture.blockAutoPaginationUntilUserScroll).assertFalse();
        expect(fixture.olderCalls > 0).assertTrue();
      } finally {
        if (records.length > 0) evidence('timeline-update-pagination-evidence', records);
        if (opened) await driver.pressBack();
      }
    });
    it('isolated native fixture remount rejects its old queued update and index callback', 0, async () => {
      const driver = Driver.create(); let opened = false;
      try {
        const old = await openTimeline(driver); opened = true;
        old.timingEnabled = true;
        const releaseOldApply = old.captureQueuedApply([10, 20]);
        expect(old.queuedApplyDeliveries).assertEqual(0);
        old.traceTiming('back-enter');
        await driver.pressBack(); opened = false;
        old.traceTiming('back-return');
        await waitForDisappearance(old);
        old.traceTiming('disappearance-observed');
        const current = await openTimeline(driver); opened = true;
        current.timingEnabled = true;
        current.traceTiming('new-mount', old.timingId);
        expect(current !== old).assertTrue();
        releaseOldApply();
        expect(old.queuedApplyDeliveries).assertEqual(1);
        old.onScrollIndex(2, 8);
        old.traceTiming('old-before-assert', current.timingId);
        current.traceTiming('current-before-assert', old.timingId);
        expect(old.dataSource.totalCount()).assertEqual(81);
        expect(current.dataSource.totalCount()).assertEqual(81);
        expect(old.olderCalls).assertEqual(0);
        expect(current.olderCalls).assertEqual(0);
        expect(old.mounted).assertFalse(); expect(current.mounted).assertTrue();
        // Isolated fixture lifecycle evidence; real Session/account is unmounted.
      } finally { if (opened) await driver.pressBack(); }
    });
  });
}
