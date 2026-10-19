/// <reference path="../types/libtdlib_napi.d.ts" />
import { worker } from '@kit.ArkTS';
import { ProbeRunner, ProbeSummary } from '../probe/ProbeRunner';

// Worker half of the drain probe. Identical runner, different thread.

const port = worker.workerPort;

port.onmessage = (): void => {
  const runner: ProbeRunner = new ProbeRunner('worker', (summary: ProbeSummary): void => {
    port.postMessage(JSON.stringify(summary));
  });
  runner.startSynthetic(161, 8);
};
