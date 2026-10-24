import { FrameLoad, FrameStats } from './FrameLoad';
import { BudgetSweep, SweepRow } from './BudgetSweep';
import { ProbeRunner, ProbeSummary, YIELD_IMMEDIATE } from './ProbeRunner';

// Entry point for the drain probe. Without this file `probe/` was a set of classes
// with no way to start them, which is why the notes called the harness
// "reproducible" while the only wiring lived in reverted code.
//
// Wire it from EntryAbility.onCreate in an isolated bundle, then revert the wiring;
// nothing under entry/ imports this file. The settle delay is part of the
// measurement — window load is not the drain.

export const SETTLE_MS: number = 5000;
export const TOTAL_RESPONSES: number = 161;
export const BATCH_SIZE: number = 8;
export const DEFAULT_BUDGETS: number[] = [8, 16, 32, 64];

export class ProbeEntry {
  private readonly frames: FrameLoad;

  constructor(onBeat: (message: string) => void) {
    this.frames = new FrameLoad(onBeat);
  }

  // Budget sweep on the main thread. Rows arrive in budget order; a row with
  // completed = false hit the watchdog and must be excluded from any mean.
  runBudgetSweep(budgets: number[], onRow: (row: SweepRow) => void, onDone: () => void,
    yieldModel: string = YIELD_IMMEDIATE): void {
    this.frames.start();
    setTimeout((): void => {
      const sweep: BudgetSweep = new BudgetSweep(this.frames, budgets, onRow, onDone, yieldModel);
      sweep.start();
    }, SETTLE_MS);
  }

  // One arm of the topology comparison. The main arm is this runner; the worker arm
  // is TdProbeWorker.ets. Only the main arm can carry the frame load, so a worker
  // frame gap is not comparable evidence.
  runMainArm(budgetMs: number, onSummary: (summary: ProbeSummary, stats: FrameStats) => void,
    yieldModel: string = YIELD_IMMEDIATE): void {
    this.frames.start();
    setTimeout((): void => {
      const runner: ProbeRunner = new ProbeRunner('main', (summary: ProbeSummary): void => {
        onSummary(summary, this.frames.peek());
      }, budgetMs, yieldModel);
      runner.start(TOTAL_RESPONSES, BATCH_SIZE);
    }, SETTLE_MS);
  }

  stopFrames(): FrameStats {
    return this.frames.stop();
  }
}
