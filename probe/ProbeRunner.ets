// Shared drain probe. The same code runs on the main thread and inside a worker;
// the only difference between the two runs is which thread owns it.
//
// It mirrors the gateway's shape: batches arrive, each response costs
// ITEM_WORK_MS of synchronous consumer work, and the drain yields once it has
// spent SLICE_BUDGET_MS so a long batch cannot hold the thread.
//
// The queue is filled synchronously before the drain starts, so arrival timing
// is identical in both arms. That removes the confound where a slow drain stamps
// batches later and makes arrival-to-ack look shorter.
//
// Source: synthetic. TDLib does not answer an unauthenticated client, and this
// bundle carries dummy API credentials by design, so a live receive loop yields
// nothing. Arrival timing is modelled here, not observed.

const ITEM_WORK_MS: number = 8;
const WATCHDOG_MS: number = 60000;

class Batch {
  id: number;
  emittedAt: number;
  touchedAt: number = 0;
  remaining: number;

  constructor(id: number, emittedAt: number, remaining: number) {
    this.id = id;
    this.emittedAt = emittedAt;
    this.remaining = remaining;
  }
}

export interface ProbeSummary {
  mode: string;
  batches: number;
  items: number;
  elapsedMs: number;
  maxDrainMs: number;
  maxWaitMs: number;
  maxBacklog: number;
  completed: boolean;
}

function busy(ms: number): void {
  const until: number = Date.now() + ms;
  while (Date.now() < until) {
  }
}

export class ProbeRunner {
  private readonly mode: string;
  private readonly onDone: (summary: ProbeSummary) => void;
  private readonly budgetMs: number;
  private expected: number = 0;
  private queue: Batch[] = [];
  private items: number = 0;
  private batches: number = 0;
  private startedAt: number = 0;
  private lastAckAt: number = 0;
  private maxDrain: number = 0;
  private maxWait: number = 0;
  private maxBacklog: number = 0;
  private draining: boolean = false;
  private finished: boolean = false;

  constructor(mode: string, onDone: (summary: ProbeSummary) => void, budgetMs: number) {
    this.mode = mode;
    this.onDone = onDone;
    this.budgetMs = budgetMs;
  }

  start(total: number, batchSize: number): void {
    this.expected = total;
    this.startedAt = Date.now();
    let emitted: number = 0;
    let id: number = 0;
    while (emitted < total) {
      const size: number = Math.min(batchSize, total - emitted);
      this.queue.push(new Batch(id, this.startedAt, size));
      this.batches += 1;
      id += 1;
      emitted += size;
    }
    this.maxBacklog = this.queue.length;
    setTimeout((): void => {
      if (!this.finished) this.finish(false);
    }, WATCHDOG_MS);
    this.pump();
  }

  private pump(): void {
    if (this.draining || this.finished) return;
    this.draining = true;
    setTimeout((): void => {
      this.draining = false;
      this.slice();
    }, 0);
  }

  private slice(): void {
    if (this.finished) return;
    const sliceStart: number = Date.now();
    let transferred: number = 0;
    while (this.queue.length > 0 &&
      (transferred === 0 || Date.now() - sliceStart < this.budgetMs)) {
      const batch: Batch = this.queue[0];
      if (batch.touchedAt === 0) {
        batch.touchedAt = Date.now();
        const wait: number = batch.touchedAt - batch.emittedAt;
        if (wait > this.maxWait) this.maxWait = wait;
      }
      busy(ITEM_WORK_MS);
      batch.remaining -= 1;
      transferred += 1;
      this.items += 1;
      if (batch.remaining <= 0) {
        this.queue.shift();
        const ackAt: number = Date.now();
        const drain: number = ackAt - batch.touchedAt;
        if (drain > this.maxDrain) this.maxDrain = drain;
        this.lastAckAt = ackAt;
      }
    }
    if (this.queue.length > 0) {
      this.pump();
      return;
    }
    if (this.items >= this.expected) {
      this.finish(true);
    }
    // Idle: nothing to re-arm. The next start() fills the queue again.
  }

  private finish(completed: boolean): void {
    if (this.finished) return;
    this.finished = true;
    const summary: ProbeSummary = {
      mode: this.mode,
      batches: this.batches,
      items: this.items,
      elapsedMs: this.lastAckAt > 0 ? this.lastAckAt - this.startedAt : -1,
      maxDrainMs: this.maxDrain,
      maxWaitMs: this.maxWait,
      maxBacklog: this.maxBacklog,
      completed: completed
    };
    this.onDone(summary);
  }
}
