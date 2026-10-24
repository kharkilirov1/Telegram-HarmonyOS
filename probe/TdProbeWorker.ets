import { worker } from '@kit.ArkTS';
import { ProbeRunner, ProbeSummary, YIELD_IMMEDIATE } from './ProbeRunner';

// Worker half of the drain probe. Identical runner, different thread.
//
// To run it: copy this file and ProbeRunner.ets into entry/src/main/ets/workers/,
// declare the worker under buildOption.sourceOption.workers, and post any message
// to start the drain. Both files must stay in the same directory so the relative
// import above keeps resolving — that is why it is './ProbeRunner', not a path
// back into probe/.

const port = worker.workerPort;

// Budget is a constant here on purpose: a worker cannot be reconfigured between
// runs without a fresh process, and the sweep runs on the main thread anyway.
const WORKER_BUDGET_MS: number = 8;
const TOTAL_RESPONSES: number = 161;
const BATCH_SIZE: number = 8;

// Signal that the module is loaded, so the main thread can open the measurement
// window only after cold start is out of the way.
port.postMessage('ready');

port.onmessage = (): void => {
  const runner: ProbeRunner = new ProbeRunner('worker', (summary: ProbeSummary): void => {
    port.postMessage(JSON.stringify(summary));
  }, WORKER_BUDGET_MS, YIELD_IMMEDIATE);
  runner.start(TOTAL_RESPONSES, BATCH_SIZE);
};
