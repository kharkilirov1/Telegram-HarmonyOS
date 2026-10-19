// Main-thread frame load. Occupies the thread the way rendering does: a fixed
// amount of synchronous work every FRAME_MS, never yielding early. Its only
// output is the worst gap between consecutive ticks, which is what a user
// perceives as a stutter.

const FRAME_MS: number = 16;
const FRAME_WORK_MS: number = 6;

export interface FrameStats {
  ticks: number;
  maxGapMs: number;
}

function busy(ms: number): void {
  const until: number = Date.now() + ms;
  while (Date.now() < until) {
  }
}

export class FrameLoad {
  private running: boolean = false;
  private last: number = 0;
  private maxGap: number = 0;
  private ticks: number = 0;

  start(): void {
    if (this.running) return;
    this.running = true;
    this.last = Date.now();
    this.maxGap = 0;
    this.ticks = 0;
    this.tick();
  }

  stop(): FrameStats {
    this.running = false;
    const stats: FrameStats = { ticks: this.ticks, maxGapMs: this.maxGap };
    return stats;
  }

  private tick(): void {
    if (!this.running) return;
    const now: number = Date.now();
    const gap: number = now - this.last;
    if (gap > this.maxGap) this.maxGap = gap;
    this.last = now;
    this.ticks += 1;
    busy(FRAME_WORK_MS);
    const spent: number = Date.now() - now;
    const delay: number = FRAME_MS - spent;
    setTimeout((): void => {
      this.tick();
    }, delay > 0 ? delay : 0);
  }
}
