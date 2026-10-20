// Main-thread frame load. Occupies the thread the way rendering does: a fixed
// amount of synchronous work every FRAME_MS, never yielding early.
//
// It reports a heartbeat once a second so a stalled loop is visible in the log
// instead of being misread as "no gap". A zero maxGap with one tick means the
// loop never ran, not that nothing stalled.

const FRAME_MS: number = 16;
const FRAME_WORK_MS: number = 6;

export interface FrameStats {
  ticks: number;
  maxGapMs: number;
  elapsedMs: number;
  heartbeats: number;
}

function busy(ms: number): void {
  const until: number = Date.now() + ms;
  while (Date.now() < until) {
  }
}

export class FrameLoad {
  private readonly onBeat: (message: string) => void;
  private running: boolean = false;
  private last: number = 0;
  private startedAt: number = 0;
  private maxGap: number = 0;
  private ticks: number = 0;
  private heartbeats: number = 0;

  constructor(onBeat: (message: string) => void) {
    this.onBeat = onBeat;
  }

  start(): void {
    if (this.running) return;
    this.running = true;
    this.startedAt = Date.now();
    this.last = this.startedAt;
    this.maxGap = 0;
    this.ticks = 0;
    this.heartbeats = 0;
    this.tick();
  }

  stop(): FrameStats {
    this.running = false;
    return this.peek();
  }

  // Zero the counters without breaking the running tick chain, so one window of
  // a longer run can be attributed to a single variant.
  resetStats(): void {
    this.maxGap = 0;
    this.ticks = 0;
    this.heartbeats = 0;
    this.startedAt = Date.now();
    this.last = this.startedAt;
  }

  peek(): FrameStats {
    const stats: FrameStats = {
      ticks: this.ticks,
      maxGapMs: this.maxGap,
      elapsedMs: Date.now() - this.startedAt,
      heartbeats: this.heartbeats
    };
    return stats;
  }

  private tick(): void {
    if (!this.running) return;
    const now: number = Date.now();
    const gap: number = now - this.last;
    if (gap > this.maxGap) this.maxGap = gap;
    this.last = now;
    this.ticks += 1;
    const elapsed: number = now - this.startedAt;
    if (elapsed > (this.heartbeats + 1) * 1000) {
      this.heartbeats += 1;
      this.onBeat('BEAT t=' + elapsed + ' ticks=' + this.ticks + ' maxGap=' + this.maxGap);
    }
    busy(FRAME_WORK_MS);
    const spent: number = Date.now() - now;
    const delay: number = FRAME_MS - spent;
    setTimeout((): void => {
      this.tick();
    }, delay > 0 ? delay : 0);
  }
}
