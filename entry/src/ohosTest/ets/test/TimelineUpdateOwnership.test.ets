import { describe, it, expect } from '@ohos/hypium';
import { TimelineTransactionFixture } from '../testability/TimelineTransactionFixture';

function rows(): number[] {
  const result: number[] = [];
  for (let index = 1; index <= 80; index++) result.push(index * 10);
  return result;
}

function positioned(): TimelineTransactionFixture {
  const fixture = new TimelineTransactionFixture();
  fixture.apply(rows());
  fixture.mounted = true;
  fixture.lastVisibleStartIndex = 26;
  fixture.lastVisibleEndIndex = 32;
  return fixture;
}

export default function timelineUpdateOwnershipTest() {
  describe('TimelineUpdateOwnership', () => {
    it('actual transaction blocks delayed index pagination after deletion above viewport', 0, () => {
      const fixture = positioned();
      try {
        fixture.apply(rows().filter((id: number) => id !== 10 && id !== 20));
        expect(fixture.isApplyingTimelineDiff).assertFalse();
        expect(fixture.indexOf(260)).assertEqual(24);
        fixture.onScrollIndex(24, 30);
        expect(fixture.olderCalls).assertEqual(0);
        expect(fixture.newerCalls).assertEqual(0);
      } finally { fixture.dispose(); }
    });
    it('actual transaction preserves existing positive prepend pagination guard', 0, () => {
      const fixture = positioned();
      try {
        fixture.apply([1, 5, ...rows()]);
        fixture.onScrollIndex(24, 30);
        expect(fixture.dataSource.getLastPrependCount()).assertEqual(2);
        expect(fixture.blockAutoPaginationUntilUserScroll).assertTrue();
        expect(fixture.olderCalls).assertEqual(0);
      } finally { fixture.dispose(); }
      const middle = positioned();
      try {
        middle.apply([...rows(), 245].sort((a: number, b: number) => a - b));
        expect(middle.dataSource.getLastPrependCount()).assertEqual(0);
        expect(middle.indexOf(260)).assertEqual(27);
        expect(middle.blockAutoPaginationUntilUserScroll).assertTrue();
        middle.onScrollIndex(27, 33);
        expect(middle.olderCalls).assertEqual(0);
      } finally { middle.dispose(); }
      const rekey = positioned();
      try {
        rekey.apply(rows().filter((id: number) => id !== 10 && id !== 20), 260, 1);
        expect(rekey.indexOf(260)).assertEqual(24);
        expect(rekey.dataSource.getData(24).key.endsWith('_e1')).assertTrue();
        expect(rekey.blockAutoPaginationUntilUserScroll).assertTrue();
        rekey.onScrollIndex(24, 30);
        expect(rekey.olderCalls).assertEqual(0);
      } finally { rekey.dispose(); }
      const zeroShift = positioned();
      try {
        zeroShift.apply([...rows().filter((id: number) => id !== 20), 15].sort((a: number, b: number) => a - b));
        expect(zeroShift.indexOf(260)).assertEqual(26);
        expect(zeroShift.dataSource.getLastPrependCount()).assertEqual(0);
        expect(zeroShift.blockAutoPaginationUntilUserScroll).assertTrue();
      } finally { zeroShift.dispose(); }
      const below = positioned();
      try {
        below.apply([...rows(), 555].sort((a: number, b: number) => a - b), 260, 1);
        expect(below.indexOf(260)).assertEqual(26);
        expect(below.blockAutoPaginationUntilUserScroll).assertFalse();
      } finally { below.dispose(); }
    });
    it('actual event handler keeps ordinary unguarded user-edge pagination enabled', 0, () => {
      const fixture = positioned();
      try {
        fixture.suppressLoadOlderUntil = 0;
        fixture.blockAutoPaginationUntilUserScroll = false;
        fixture.onScrollIndex(24, 30);
        expect(fixture.olderCalls).assertEqual(1);
        expect(fixture.lastVisibleStartIndex).assertEqual(24);
        expect(fixture.lastVisibleEndIndex).assertEqual(30);
        fixture.apply([1, 5, ...rows()]);
        expect(fixture.blockAutoPaginationUntilUserScroll).assertTrue();
        // Isolate the real user-unlock predicate from its independent clock
        // suppression. Native gesture/elapsed-time coverage lives in UI cases.
        fixture.suppressLoadOlderUntil = 0;
        fixture.onDidScroll(40, ScrollState.Scroll);
        expect(fixture.blockAutoPaginationUntilUserScroll).assertFalse();
        fixture.onScrollIndex(24, 30);
        expect(fixture.olderCalls).assertEqual(2);
      } finally { fixture.dispose(); }
    });
    it('isolated fixture disappearance ignores delayed native index events', 0, () => {
      const fixture = positioned();
      fixture.dispose();
      fixture.onScrollIndex(2, 8);
      expect(fixture.olderCalls).assertEqual(0);
      expect(fixture.lastVisibleStartIndex).assertEqual(26);
      // This is the fixture's mount fence, not a claim about real ChatPage route ownership.
      expect(fixture.mounted).assertFalse();
    });
  });
}
