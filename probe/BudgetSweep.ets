import { ProbeRunner, ProbeSummary, YIELD_IMMEDIATE } from './ProbeRunner';
import { FrameLoad, FrameStats } from './FrameLoad';

// Sweeps the drain slice budget over the same workload and records, for each
// budget, both the total drain time and the worst main-thread frame gap in that
// window. The point is the trade-off curve: fewer yields means less scheduling
// overhead and a longer uninterrupted slice — but only the YIELD_SHIPPED model
// reproduces the gateway's scaling pause, so a sweep under YIELD_IMMEDIATE (the
// recorded 2026-10-21 runs) does not transfer to production.

export interface SweepRow {
  budgetMs: number;
  yieldModel: string;
  // Drain turns actually taken; the earlier notes derived this instead of measuring it.
  slices: number;
  elapsedMs: number;
  maxDrainMs: number;
  frameMaxGapMs: number;
  // False for a variant that hit the watchdog. Such a row carries elapsedMs = -1
  // and must be excluded from any mean.
  completed: boolean;
}

export class BudgetSweep {
  private readonly frames: FrameLoad;
  private readonly budgets: number[];
  private readonly yieldModel: string;
  private readonly onRow: (row: SweepRow) => void;
  private readonly onDone: () => void;
  private index: number = 0;

  constructor(frames: FrameLoad, budgets: number[], onRow: (row: SweepRow) => void,
    onDone: () => void, yieldModel: string = YIELD_IMMEDIATE) {
    this.frames = frames;
    this.budgets = budgets;
    this.onRow = onRow;
    this.onDone = onDone;
    this.yieldModel = yieldModel;
  }

  start(): void {
    this.next();
  }

  private next(): void {
    if (this.index >= this.budgets.length) {
      this.onDone();
      return;
    }
    const budget: number = this.budgets[this.index];
    this.frames.resetStats();
    const runner: ProbeRunner = new ProbeRunner('b' + budget, (summary: ProbeSummary): void => {
      const stats: FrameStats = this.frames.peek();
      const row: SweepRow = {
        budgetMs: budget,
        yieldModel: this.yieldModel,
        slices: summary.slices,
        elapsedMs: summary.elapsedMs,
        maxDrainMs: summary.maxDrainMs,
        frameMaxGapMs: stats.maxGapMs,
        completed: summary.completed
      };
      this.onRow(row);
      this.index += 1;
      setTimeout((): void => {
        this.next();
      }, 800);
    }, budget, this.yieldModel);
    runner.start(161, 8);
  }
}
