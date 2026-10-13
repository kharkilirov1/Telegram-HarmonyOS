import { describe, it, expect } from '@ohos/hypium';
import { ChatTimelineEntryVO } from '../../../main/ets/ui/pages/chat/ChatTimelineVO';
import {
  TimelineUpdateHarness, TimelineUpdateRecorder, timelineEntries, timelineMarker, timelineMessage
} from '../testability/TimelineUpdateInputs';

export default function timelineUpdateDataSourceTest() {
  describe('TimelineUpdateDataSource', () => {
    it('same-day insertion retains date A B without duplicated B', 0, () => {
      const f = new TimelineUpdateHarness([timelineMarker('date', 'D'), ...timelineEntries(['10', '20'])]);
      f.apply([timelineMarker('date', 'D'), ...timelineEntries(['5', '10', '20'])]);
      expect(f.source.getLastPrependCount()).assertEqual(1);
      expect(f.recorder.added.join('|')).assertEqual('msg_5');
      expect(f.recorder.removed.length).assertEqual(0);
    });
    it('same-day insertion before unread retains all logical identities', 0, () => {
      const f = new TimelineUpdateHarness([timelineMarker('date', 'D'), timelineMarker('unread', '10'), ...timelineEntries(['10', '20'])]);
      f.apply([timelineMarker('date', 'D'), timelineMessage('5'), timelineMarker('unread', '10'), ...timelineEntries(['10', '20'])]);
      expect(f.source.getLastPrependCount()).assertEqual(1);
      expect(f.recorder.events.length).assertEqual(1);
    });
    it('repeated same-day prepends preserve each intermediate snapshot', 0, () => {
      const f = new TimelineUpdateHarness([timelineMarker('date', 'D'), ...timelineEntries(['10', '20'])]);
      f.apply([timelineMarker('date', 'D'), ...timelineEntries(['5', '10', '20'])]);
      f.apply([timelineMarker('date', 'D'), ...timelineEntries(['1', '5', '10', '20'])]);
      expect(f.recorder.added.join('|')).assertEqual('msg_5|msg_1');
      expect(f.source.getLastPrependCount()).assertEqual(1);
    });
    it('interior insert emits one coherent add and retains anchor', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20', '30']));
      f.apply(timelineEntries(['10', '15', '20', '30']));
      expect(f.recorder.events.length).assertEqual(1);
      expect(f.recorder.events[0].index).assertEqual(1);
      expect(f.source.getLastPrependCount()).assertEqual(0);
      expect(f.recorder.removed.length).assertEqual(0);
    });
    it('interior deletion emits one coherent delete', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20', '30', '40']));
      f.apply(timelineEntries(['10', '30', '40']));
      expect(f.recorder.events.length).assertEqual(1);
      expect(f.recorder.events[0].index).assertEqual(1);
      expect(f.recorder.removed.join('|')).assertEqual('msg_20');
      expect(f.recorder.added.length).assertEqual(0);
      expect(f.source.getLastPrependCount()).assertEqual(0);
    });
    it('head deletion retains first surviving message and clamps negative shift', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20', '30']));
      f.apply(timelineEntries(['20', '30']));
      expect(f.recorder.removed.join('|')).assertEqual('msg_10');
      expect(f.source.getLastPrependCount()).assertEqual(0);
    });
    it('unread removal combined with older insert keeps A without reinsertion', 0, () => {
      const f = new TimelineUpdateHarness([timelineMarker('date', 'D'), timelineMarker('unread', '10'), ...timelineEntries(['10', '20'])]);
      f.apply([timelineMarker('date', 'D'), ...timelineEntries(['5', '10', '20'])]);
      expect(f.recorder.removed.join('|')).assertEqual('unread_10');
      expect(f.recorder.added.join('|')).assertEqual('msg_5');
      expect(f.source.getLastPrependCount()).assertEqual(0);
    });
    it('mixed positive shift measures net movement after marker removal', 0, () => {
      const f = new TimelineUpdateHarness([timelineMarker('date', 'D'), timelineMarker('unread', '10'), ...timelineEntries(['10', '20'])]);
      f.apply([timelineMarker('date', 'D'), ...timelineEntries(['1', '5', '10', '20', '30'])]);
      expect(f.source.getLastPrependCount()).assertEqual(1);
      expect(f.recorder.removed.join('|')).assertEqual('unread_10');
      expect(f.recorder.added.join('|')).assertEqual('msg_1|msg_5|msg_30');
    });
    it('tail beyond five-anchor sample is removed exactly', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20', '30', '40', '50', '60', '70']));
      f.apply(timelineEntries(['1', '5', '10', '20', '30', '40', '50', '70']));
      expect(f.recorder.removed.join('|')).assertEqual('msg_60');
      expect(f.source.getLastPrependCount()).assertEqual(2);
    });
    it('disjoint deletions and additions maintain every notified index', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20', '30', '40', '50', '60']));
      f.apply(timelineEntries(['5', '10', '25', '30', '50', '70']));
      expect(f.recorder.removed.join('|')).assertEqual('msg_60|msg_40|msg_20');
      expect(f.recorder.added.join('|')).assertEqual('msg_5|msg_25|msg_70');
      expect(f.recorder.events.length).assertEqual(6);
    });
    it('insert with stamped retained content refresh emits one change', 0, () => {
      const f = new TimelineUpdateHarness([timelineMarker('date', 'D'), ...timelineEntries(['10', '20'])]);
      f.apply([timelineMarker('date', 'D'), timelineMessage('5'), timelineMessage('10', 1, 'edited'), timelineMessage('20')]);
      expect(f.recorder.events.filter((event) => event.kind === 'change').length).assertEqual(1);
      expect(f.source.getData(2).key).assertEqual('msg_10_s1_r0_e0');
      expect(f.source.getData(2).message.text).assertEqual('edited');
      expect(f.recorder.removed.length).assertEqual(0);
    });
    it('delete with retained content refresh uses shifted change index', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20', '30', '40']));
      f.apply([timelineMessage('10'), timelineMessage('30', 2, 'reply hydrated'), timelineMessage('40')]);
      expect(f.recorder.events.length).assertEqual(2);
      expect(f.recorder.events[1].kind).assertEqual('change');
      expect(f.recorder.events[1].index).assertEqual(1);
      expect(f.recorder.removed.join('|')).assertEqual('msg_20');
    });
    it('same stable order preserves render-key refresh fast path', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20']));
      f.apply([timelineMessage('10', 1), timelineMessage('20')]);
      expect(f.recorder.events.length).assertEqual(1);
      expect(f.recorder.events[0].kind).assertEqual('change');
      expect(f.recorder.events[0].index).assertEqual(0);
    });
    it('same render key textual update still publishes changed content', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20']));
      f.apply([timelineMessage('10', 0, 'new text'), timelineMessage('20')]);
      expect(f.recorder.events.length).assertEqual(1);
      expect(f.recorder.events[0].kind).assertEqual('change');
    });
    it('identical repeated snapshots emit no events and clear shift', 0, () => {
      const next = timelineEntries(['10', '20']);
      const f = new TimelineUpdateHarness(next);
      f.apply(next); f.apply(timelineEntries(['10', '20']));
      expect(f.recorder.events.length).assertEqual(0);
      expect(f.source.getLastPrependCount()).assertEqual(0);
    });
    it('pure prepend fast path remains splice-coherent', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20']));
      f.apply(timelineEntries(['1', '5', '10', '20']));
      expect(f.recorder.events.length).assertEqual(2);
      expect(f.source.getLastPrependCount()).assertEqual(2);
    });
    it('append fast path preserves bulk-assignment contract and content refresh', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20']), false);
      f.apply([timelineMessage('10', 1), ...timelineEntries(['20', '30', '40'])]);
      expect(f.recorder.events.map((event) => event.kind).join('|')).assertEqual('change|add|add');
      expect(f.recorder.events.map((event) => event.index).join('|')).assertEqual('0|2|3');
    });
    it('tail trim fast path remains targeted', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20', '30', '40']), false);
      f.apply(timelineEntries(['10', '20']));
      expect(f.recorder.events.map((event) => event.index).join('|')).assertEqual('3|2');
    });
    it('empty to populated and populated to empty remain exact', 0, () => {
      const f = new TimelineUpdateHarness([], false);
      f.apply(timelineEntries(['10', '20'])); f.apply([]);
      expect(f.source.totalCount()).assertEqual(0);
      expect(f.recorder.events.map((event) => event.kind).join('|')).assertEqual('add|add|delete|delete');
    });
    it('retained order reversal deliberately reloads', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20', '30']));
      f.apply(timelineEntries(['30', '20', '10']), true);
    });
    it('disjoint replacement deliberately reloads', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20']));
      f.apply(timelineEntries(['30', '40']), true);
      expect(f.source.getLastPrependCount()).assertEqual(0);
    });
    it('duplicate stable identities reload before any incremental signal', 0, () => {
      const duplicate = timelineMessage('10', 1);
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20']));
      f.apply([timelineMessage('10'), duplicate, timelineMessage('20')], true);
    });
    it('duplicate render identities reload before any incremental signal', 0, () => {
      const duplicate = timelineMessage('15'); duplicate.key = timelineMessage('10').key;
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20']));
      f.apply([timelineMessage('10'), duplicate, timelineMessage('20')], true);
      // Unique within both snapshots is insufficient when a native rendered key
      // migrates to a different stable owner across snapshots.
      const migrated = timelineMessage('15'); migrated.key = timelineMessage('20').key;
      const other = new TimelineUpdateHarness(timelineEntries(['10', '20']));
      other.apply([timelineMessage('10', 1), migrated, timelineMessage('20', 1)], true);
    });
    it('empty stable or render identities use explicit fallback', 0, () => {
      const missing = timelineMessage('15'); missing.stableKey = '';
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20']));
      f.apply([timelineMessage('10'), missing, timelineMessage('20')], true);
      const other = timelineMessage('15'); other.key = '';
      f.apply([timelineMessage('10'), other, timelineMessage('20')], true);
    });
    it('ambiguous old snapshot cannot become a partial targeted plan', 0, () => {
      const f = new TimelineUpdateHarness([timelineMessage('10'), timelineMessage('10', 1), timelineMessage('20')]);
      f.apply(timelineEntries(['10', '15', '20']), true);
    });
    it('listener identity registers once and unregister removes only that listener', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20']));
      f.source.registerDataChangeListener(f.recorder);
      const other = new TimelineUpdateRecorder(f.source);
      f.source.registerDataChangeListener(other);
      f.apply(timelineEntries(['10', '15', '20']));
      expect(f.recorder.events.length).assertEqual(1);
      expect(other.events.length).assertEqual(1);
      f.source.unregisterDataChangeListener(other);
      f.apply(timelineEntries(['10', '20']));
      expect(f.recorder.events.length).assertEqual(2);
      expect(other.events.length).assertEqual(1);
    });
    it('100 and 1000 row windows emit work only for three actual edits', 0, () => {
      for (const count of [100, 1000]) {
        const before: ChatTimelineEntryVO[] = [];
        for (let index = 0; index < count; index++) before.push(timelineMessage((index * 10 + 10).toString()));
        const f = new TimelineUpdateHarness(before);
        const next = before.slice();
        next.splice(20, 1); next.splice(40, 0, timelineMessage('405'));
        next[60] = timelineMessage(next[60].message.messageId, 1, 'updated');
        f.apply(next);
        expect(f.recorder.events.length).assertEqual(3);
        expect(f.recorder.added.length).assertEqual(1);
        expect(f.recorder.removed.length).assertEqual(1);
      }
    });
    it('twenty insert-delete-refresh cycles retain exact intermediate state', 0, () => {
      const f = new TimelineUpdateHarness(timelineEntries(['10', '20', '30']));
      for (let cycle = 1; cycle <= 20; cycle++) {
        f.apply([timelineMessage('10', cycle), timelineMessage('15'), timelineMessage('20'), timelineMessage('30')]);
        f.apply([timelineMessage('10', cycle), timelineMessage('20'), timelineMessage('30')]);
      }
      expect(f.source.totalCount()).assertEqual(3);
      expect(f.recorder.events.length).assertEqual(60);
    });
  });
}
