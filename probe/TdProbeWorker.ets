import { worker } from '@kit.ArkTS';
import { ProbeRunner, ProbeSummary } from '../probe/ProbeRunner';

// Worker half of the drain probe. Identical runner, different thread.

const port = worker.workerPort;

// Signal that the module is loaded, so the main thread can open the measurement
// window only after cold start is out of the way.
port.postMessage('ready');

port.onmessage = (): void => {
  const runner: ProbeRunner = new ProbeRunner('worker', (summary: ProbeSummary): void => {
    port.postMessage(JSON.stringify(summary));
  });
  runner.start(161, 8);
};
