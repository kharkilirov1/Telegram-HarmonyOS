/// <reference path="../types/libtdlib_napi.d.ts" />
import tdlib from 'libtdlib_napi.so';

// Shared drain probe. The same code runs on the main thread and inside a worker;
// the only difference between the two runs is which thread owns it.
//
// It mirrors the gateway's shape: batches arrive, each response costs
// ITEM_WORK_MS of synchronous consumer work, and the drain yields once it has
// spent SLICE_BUDGET_MS so a long batch cannot hold the thread.
//
// Two sources are available. 'native' drives real TDLib through the receive
// loop; it needs an authorized client and produces nothing without one.
// 'synthetic' feeds the same batches from a timer, which isolates drain
// topology from TDLib's own timing.

const ITEM_WORK_MS: number = 8;
const SLICE_BUDGET_MS: number = 8;
const WATCHDOG_MS: number = 60000;

class Batch {
  epoch: number;
  id: number;
  at: number;
  remaining: number;

  constructor(epoch: number, id: number, at: number, remaining: number) {
    this.epoch = epoch;
    this.id = id;
    this.at = at;
    this.remaining = remaining;
  }
}

export interface ProbeSummary {
  mode: string;
  source: string;
  batches: number;
  items: number;
  elapsedMs: number;
  maxBatchLatencyMs: number;
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
  private source: string = 'none';
  private expected: number = 0;
  private queue: Batch[] = [];
  private items: number = 0;
  private batches: number = 0;
  private startedAt: number = 0;
  private lastAckAt: number = 0;
  private maxLatency: number = 0;
  private maxBacklog: number = 0;
  private draining: boolean = false;
  private finished: boolean = false;

  constructor(mode: string, onDone: (summary: ProbeSummary) => void) {
    this.mode = mode;
    this.onDone = onDone;
  }

  // Emits batches back to back so the queue can actually build up: the point is
  // to find out whether the drain falls behind, not to measure a steady trickle.
  startSynthetic(total: number, batchSize: number): void {
    this.source = 'synthetic';
    this.expected = total;
    this.startedAt = Date.now();
    let emitted: number = 0;
    let id: number = 0;
    const emit = (): void => {
      if (this.finished) return;
      if (emitted >= total) return;
      const size: number = Math.min(batchSize, total - emitted);
      this.accept(0, id, size);
      id += 1;
      emitted += size;
      setTimeout(emit, 0);
    };
    setTimeout(emit, 0);
    setTimeout((): void => {
      if (!this.finished) this.finish(false);
    }, WATCHDOG_MS);
  }

  startNative(total: number): void {
    this.source = 'native';
    this.expected = total;
    this.startedAt = Date.now();
    const epoch: number = tdlib.startReceiveLoop((json: string, ep: number, id: number,
      bytes: number): boolean => {
      let count: number = 1;
      try {
        const parsed: Object = JSON.parse(json);
        if (Array.isArray(parsed)) {
          const list: Object[] = parsed as Object[];
          if (list.length > 0) count = list.length;
        }
      } catch (error) {
        count = 1;
      }
      this.accept(ep, id, count);
      return true;
    });
    const clientId: number = tdlib.createClient();
    for (let i: number = 0; i < total; i++) {
      tdlib.send(clientId, '{"@type":"getOption","name":"version"}');
    }
    setTimeout((): void => {
      if (!this.finished) this.finish(false);
    }, WATCHDOG_MS);
    if (epoch <= 0) this.finish(false);
  }

  private accept(epoch: number, id: number, count: number): void {
    const at: number = Date.now();
    this.queue.push(new Batch(epoch, id, at, count));
    this.batches += 1;
    if (this.queue.length > this.maxBacklog) this.maxBacklog = this.queue.length;
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
      (transferred === 0 || Date.now() - sliceStart < SLICE_BUDGET_MS)) {
      const batch: Batch = this.queue[0];
      busy(ITEM_WORK_MS);
      batch.remaining -= 1;
      transferred += 1;
      this.items += 1;
      if (batch.remaining <= 0) {
        this.queue.shift();
        const ackAt: number = Date.now();
        const latency: number = ackAt - batch.at;
        if (latency > this.maxLatency) this.maxLatency = latency;
        this.lastAckAt = ackAt;
        if (batch.epoch > 0) tdlib.ackReceiveBatch(batch.epoch, batch.id);
      }
    }
    if (this.queue.length > 0) {
      this.pump();
      return;
    }
    if (this.items >= this.expected) {
      this.finish(true);
    }
    // Idle: the next accept() re-arms the pump. Re-pumping here would spin a
    // zero-delay timer loop and starve the thread it is supposed to measure.
  }

  private finish(completed: boolean): void {
    if (this.finished) return;
    this.finished = true;
    const summary: ProbeSummary = {
      mode: this.mode,
      source: this.source,
      batches: this.batches,
      items: this.items,
      elapsedMs: this.lastAckAt > 0 ? this.lastAckAt - this.startedAt : -1,
      maxBatchLatencyMs: this.maxLatency,
      maxBacklog: this.maxBacklog,
      completed: completed
    };
    this.onDone(summary);
  }
}
