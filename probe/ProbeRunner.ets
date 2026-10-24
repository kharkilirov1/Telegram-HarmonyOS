// Shared drain probe. The same code runs on the main thread and inside a worker;
// the only difference between the two runs is which thread owns it.
//
// It mirrors the gateway's shape: batches arrive, each response costs
// ITEM_WORK_MS of synchronous consumer work, and the drain yields once it has
// spent SLICE_BUDGET_MS so a long batch cannot hold the thread.
//
// The yield policy is NOT part of the shape, it is part of the system, and the two
// models below differ enough to change the conclusion of a budget sweep:
//   YIELD_IMMEDIATE - setTimeout(..., 0). This is the model the 2026-10-20 and
//                     2026-10-21 runs used, so their numbers are not transferable
//                     to the shipped gateway.
//   YIELD_SHIPPED   - the delay TdGatewayImpl.drainSlice actually schedules:
//                     max(DRAIN_YIELD_MS, min(DRAIN_BACKOFF_CAP_MS, elapsed * 2)).
//                     Here the pause grows with the slice, so a bigger budget buys
//                     fewer yields and pays more for each one.
//
// The queue is filled synchronously before the drain starts, so arrival timing
// is identical in both arms. That removes the confound where a slow drain stamps
// batches later and makes arrival-to-ack look shorter.
//
// Source: synthetic. TDLib does not answer an unauthenticated client, and this
// bundle carries dummy API credentials by design, so a live receive loop yields
// nothing. Arrival timing is modelled here, not observed.

export const YIELD_IMMEDIATE: string = 'immediate';
export const YIELD_SHIPPED: string = 'shipped';

const ITEM_WORK_MS: number = 8;
const WATCHDOG_MS: number = 60000;
// Mirrors TdGatewayImpl.DRAIN_YIELD_MS and TdGatewayImpl.DRAIN_BACKOFF_CAP_MS.
const DRAIN_YIELD_MS: number = 2;
const DRAIN_BACKOFF_CAP_MS: number = 250;

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
  // Drain turns actually taken. This is the number the earlier notes reported as
  // "measured hop counts" while no counter existed; it is measured now.
  slices: number;
  elapsedMs: number;
  maxDrainMs: number;
  // Fill -> first touch of a batch. It is not arrival-to-ack.
  maxWaitMs: number;
  // Deepest queue observed during the run, not the initial fill.
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
  private readonly yieldModel: string;
  private expected: number = 0;
  private queue: Batch[] = [];
  private items: number = 0;
  private batches: number = 0;
  private slices: number = 0;
  private startedAt: number = 0;
  private lastAckAt: number = 0;
  private maxDrain: number = 0;
  private maxWait: number = 0;
  private maxBacklog: number = 0;
  private lastSliceMs: number = 0;
  private watchdogId: number = -1;
  private running: boolean = false;
  private draining: boolean = false;
  private finished: boolean = false;

  constructor(mode: string, onDone: (summary: ProbeSummary) => void, budgetMs: number,
    yieldModel: string = YIELD_IMMEDIATE) {
    this.mode = mode;
    this.onDone = onDone;
    this.budgetMs = budgetMs;
    this.yieldModel = yieldModel;
  }

  start(total: number, batchSize: number): void {
    if (this.running) return;
    this.reset();
    this.running = true;
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
    this.watchdogId = setTimeout((): void => {
      if (!this.finished) this.finish(false);
    }, WATCHDOG_MS) as number;
    this.pump();
  }

  // One run per instance, but a finished instance is reusable: the counters are
  // reset here, so start() after finish() is a fresh measurement, not a hang.
  private reset(): void {
    this.queue = [];
    this.expected = 0;
    this.items = 0;
    this.batches = 0;
    this.slices = 0;
    this.startedAt = 0;
    this.lastAckAt = 0;
    this.maxDrain = 0;
    this.maxWait = 0;
    this.maxBacklog = 0;
    this.lastSliceMs = 0;
    this.draining = false;
    this.finished = false;
  }

  private yieldDelay(): number {
    if (this.yieldModel !== YIELD_SHIPPED) return 0;
    const backoff: number = Math.min(DRAIN_BACKOFF_CAP_MS, this.lastSliceMs * 2);
    return Math.max(DRAIN_YIELD_MS, backoff);
  }

  private pump(): void {
    if (this.draining || this.finished) return;
    this.draining = true;
    setTimeout((): void => {
      this.draining = false;
      this.slice();
    }, this.yieldDelay());
  }

  private slice(): void {
    if (this.finished) return;
    if (this.queue.length > this.maxBacklog) this.maxBacklog = this.queue.length;
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
    if (transferred > 0) {
      this.slices += 1;
      this.lastSliceMs = Date.now() - sliceStart;
    }
    if (this.queue.length > 0) {
      this.pump();
      return;
    }
    if (this.items >= this.expected) {
      this.finish(true);
      return;
    }
    // Idle with work outstanding cannot happen for a prefilled queue; if it does,
    // the watchdog reports it as an incomplete run instead of spinning a timer.
  }

  private finish(completed: boolean): void {
    if (this.finished) return;
    this.finished = true;
    this.running = false;
    if (this.watchdogId !== -1) {
      clearTimeout(this.watchdogId);
      this.watchdogId = -1;
    }
    const summary: ProbeSummary = {
      mode: this.mode,
      batches: this.batches,
      items: this.items,
      slices: this.slices,
      elapsedMs: this.lastAckAt > 0 ? this.lastAckAt - this.startedAt : -1,
      maxDrainMs: this.maxDrain,
      maxWaitMs: this.maxWait,
      maxBacklog: this.maxBacklog,
      completed: completed
    };
    this.onDone(summary);
  }
}
