import { describe, it, expect } from '@ohos/hypium';
import {
  SharedMediaThumbnailCoordinator,
  SharedMediaThumbnailTarget
} from '../../../main/ets/ui/pages/profile/SharedMediaThumbnailCoordinator';

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, ms);
  });
}

class TestThumbTarget implements SharedMediaThumbnailTarget {
  thumbFileId: number;
  thumbUri: string = '';

  constructor(fileId: number) {
    this.thumbFileId = fileId;
  }
}

export default function sharedMediaThumbnailCoordinatorTest() {
  describe('SharedMediaThumbnailCoordinator', () => {
    it('requests only the visible range when no background queue was registered', 0, async () => {
      const started: number[] = [];
      const targets: TestThumbTarget[] = [
        new TestThumbTarget(1),
        new TestThumbTarget(2),
        new TestThumbTarget(3),
        new TestThumbTarget(4)
      ];
      const coordinator = new SharedMediaThumbnailCoordinator(async (fileId: number): Promise<string> => {
        started.push(fileId);
        return '';
      }, (_fileId: number, _reason: string): void => {}, 2);

      coordinator.prioritizeRange(targets, 2, 3);
      await sleep(20);

      expect(started.join(',')).assertEqual('3,4');
    });

    it('prioritizes the newly visible range ahead of background work', 0, async () => {
      const started: number[] = [];
      const targets: TestThumbTarget[] = [
        new TestThumbTarget(1),
        new TestThumbTarget(2),
        new TestThumbTarget(3),
        new TestThumbTarget(4)
      ];
      const coordinator = new SharedMediaThumbnailCoordinator(async (fileId: number): Promise<string> => {
        started.push(fileId);
        await sleep(15);
        return `file://${fileId}`;
      }, (_fileId: number, _reason: string): void => {}, 1);

      coordinator.enqueue(targets);
      coordinator.prioritizeRange(targets, 3, 3);
      await sleep(90);

      expect(started.join(',')).assertEqual('1,4,2,3');
      expect(targets[3].thumbUri).assertEqual('file://4');
    });

    it('keeps TDLib thumbnail pressure within the configured bound', 0, async () => {
      let active = 0;
      let peak = 0;
      const targets: TestThumbTarget[] = [
        new TestThumbTarget(11),
        new TestThumbTarget(12),
        new TestThumbTarget(13),
        new TestThumbTarget(14)
      ];
      const coordinator = new SharedMediaThumbnailCoordinator(async (fileId: number): Promise<string> => {
        active++;
        peak = Math.max(peak, active);
        await sleep(20);
        active--;
        return `file://${fileId}`;
      }, (_fileId: number, _reason: string): void => {}, 2);

      coordinator.enqueue(targets);
      await sleep(90);

      expect(peak).assertEqual(2);
      expect(targets[3].thumbUri).assertEqual('file://14');
    });

    it('does not mutate page targets after cancellation', 0, async () => {
      const target = new TestThumbTarget(21);
      const coordinator = new SharedMediaThumbnailCoordinator(async (fileId: number): Promise<string> => {
        await sleep(30);
        return `file://${fileId}`;
      }, (_fileId: number, _reason: string): void => {}, 1);

      coordinator.enqueue([target]);
      coordinator.cancel();
      await sleep(60);

      expect(target.thumbUri).assertEqual('');
    });

    it('reports the exact file id when a thumbnail load fails', 0, async () => {
      const failures: string[] = [];
      const coordinator = new SharedMediaThumbnailCoordinator(async (_fileId: number): Promise<string> => {
        throw new Error('TDLib unavailable');
      }, (fileId: number, reason: string): void => {
        failures.push(`${fileId}:${reason}`);
      }, 1);

      coordinator.enqueue([new TestThumbTarget(31)]);
      await sleep(30);

      expect(failures.length).assertEqual(1);
      expect(failures[0].indexOf('31:') === 0).assertTrue();
      expect(failures[0].indexOf('TDLib unavailable') > 0).assertTrue();
    });
  });
}
