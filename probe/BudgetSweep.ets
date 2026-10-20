import { ProbeRunner, ProbeSummary } from './ProbeRunner';
import { FrameLoad, FrameStats } from './FrameLoad';

// Sweeps the drain slice budget over the same workload and records, for each
// budget, both the total drain time and the worst main-thread frame gap in that
// window. The point is the trade-off curve: fewer yields means less scheduling
// overhead and a longer uninterrupted slice.

export interface SweepRow {
  budgetMs: number;
  elapsedMs: number;
  maxDrainMs: number;
  frameMaxGapMs: number;
}

export class BudgetSweep {
  private readonly frames: FrameLoad;
  private readonly budgets: number[];
  private readonly onRow: (row: SweepRow) => void;
  private readonly onDone: () => void;
  private index: number = 0;

  constructor(frames: FrameLoad, budgets: number[],
    onRow: (row: SweepRow) => void, onDone: () => void) {
    this.frames = frames;
    this.budgets = budgets;
    this.onRow = onRow;
    this.onDone = onDone;
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
        elapsedMs: summary.elapsedMs,
        maxDrainMs: summary.maxDrainMs,
        frameMaxGapMs: stats.maxGapMs
      };
      this.onRow(row);
      this.index += 1;
      setTimeout((): void => {
        this.next();
      }, 800);
    }, budget);
    runner.start(161, 8);
  }
}
