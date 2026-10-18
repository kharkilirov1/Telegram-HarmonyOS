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

// The pressure test controls loader completion and observes the coordinator's
// URI publication. Wall-clock sleeps cannot prove that a later batch finished.
class ControlledThumbTarget implements SharedMediaThumbnailTarget {
  readonly thumbFileId: number;
  readonly result: Promise<string>;
  readonly published: Promise<void>;
  private uri: string = '';
  private finish: (uri: string) => void = (_uri: string): void => {};
  private notifyPublished: () => void = (): void => {};

  constructor(fileId: number) {
    this.thumbFileId = fileId;
    this.result = new Promise<string>((resolve: (uri: string) => void) => { this.finish = resolve; });
    this.published = new Promise<void>((resolve: () => void) => { this.notifyPublished = resolve; });
  }

  get thumbUri(): string { return this.uri; }
  set thumbUri(uri: string) {
    this.uri = uri;
    this.notifyPublished();
  }

  complete(): void { this.finish(`file://${this.thumbFileId}`); }
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
      const targets: ControlledThumbTarget[] = [
        new ControlledThumbTarget(1),
        new ControlledThumbTarget(2),
        new ControlledThumbTarget(3),
        new ControlledThumbTarget(4)
      ];
      const coordinator = new SharedMediaThumbnailCoordinator(async (fileId: number): Promise<string> => {
        started.push(fileId);
        return targets[fileId - 1].result;
      }, (_fileId: number, _reason: string): void => {}, 1);

      try {
        coordinator.enqueue(targets);
        expect(started.join(',')).assertEqual('1');
        coordinator.prioritizeRange(targets, 3, 3);
        expect(started.join(',')).assertEqual('1');
        targets[0].complete();
        await targets[0].published;
        expect(started.join(',')).assertEqual('1,4');
        targets[3].complete();
        await targets[3].published;
        expect(started.join(',')).assertEqual('1,4,2');
        targets[1].complete();
        await targets[1].published;
        expect(started.join(',')).assertEqual('1,4,2,3');
        targets[2].complete();
        await targets[2].published;
        expect(targets[3].thumbUri).assertEqual('file://4');
      } finally {
        coordinator.cancel();
        for (const target of targets) target.complete();
      }
    });

    it('keeps TDLib thumbnail pressure within the configured bound', 0, async () => {
      let active = 0;
      let peak = 0;
      const started: number[] = [];
      const targets: ControlledThumbTarget[] = [
        new ControlledThumbTarget(11),
        new ControlledThumbTarget(12),
        new ControlledThumbTarget(13),
        new ControlledThumbTarget(14)
      ];
      const coordinator = new SharedMediaThumbnailCoordinator(async (fileId: number): Promise<string> => {
        active++;
        peak = Math.max(peak, active);
        started.push(fileId);
        const uri = await targets[fileId - 11].result;
        active--;
        return uri;
      }, (_fileId: number, _reason: string): void => {}, 2);

      try {
        coordinator.enqueue(targets);
        expect(active).assertEqual(2);
        expect(started.join(',')).assertEqual('11,12');
        targets[0].complete();
        await targets[0].published;
        expect(active).assertEqual(2);
        expect(started.join(',')).assertEqual('11,12,13');
        targets[1].complete();
        await targets[1].published;
        expect(active).assertEqual(2);
        expect(started.join(',')).assertEqual('11,12,13,14');
        targets[2].complete();
        targets[3].complete();
        await Promise.all([targets[2].published, targets[3].published]);
        expect(active).assertEqual(0);
        expect(peak).assertEqual(2);
        expect(targets[3].thumbUri).assertEqual('file://14');
      } finally {
        coordinator.cancel();
        for (const target of targets) target.complete();
      }
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
