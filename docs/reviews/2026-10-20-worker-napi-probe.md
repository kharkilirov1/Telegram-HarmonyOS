# Worker NAPI probe — 2026-10-20

**Question:** can the TDLib native module load and answer inside an ArkTS Worker on this target?

This is the load-bearing assumption of the planned receive-drain relocation. If it fails, the whole
direction is dead and no further measurement is worth designing.

---

## Result: PASS

Probe bundle `com.telegram.harmonyos.nativevalidation20261020`, installed beside the accepted
`com.telegram.harmonyos` and never over it. Launched on the API24 x86_64 emulator:

```
10-20 03:12:03.350  I A00000/EntryAbility: WORKER_PROBE_STARTED
10-20 03:12:04.768  I A00000/EntryAbility: WORKER_PROBE PROBE_OK {"@type":"optionValueString","value":"1.8.61"}
```

The worker thread imported `libtdlib_napi.so`, called `execute()` — a synchronous, credential-free
TDLib call — and got a well-formed answer back. Latency from worker start to answer: 1.4 s,
which is cold module load, not a measurement of anything.

**Secondary result:** the running process reports TDLib **1.8.61**. The earlier report
(`docs/reviews/2026-10-19-tdlib-version-provenance.md`) could only witness the version in the
repository and the packaged HAP, because the installed `.so` is unreadable to the `shell` user.
This probe closes that gap from inside the app: the binary that actually runs is 1.8.61.

---

## Probe source (reverted after the run, reproduced here)

`entry/src/main/ets/workers/TdWorkerProbe.ets`

```ts
/// <reference path="../types/libtdlib_napi.d.ts" />
import { worker } from '@kit.ArkTS';
import tdlib from 'libtdlib_napi.so';

const port = worker.workerPort;

port.onmessage = (): void => {
  try {
    const version: string | null = tdlib.execute('{"@type":"getOption","name":"version"}');
    port.postMessage('PROBE_OK ' + String(version));
  } catch (error) {
    const failure = error as Error;
    port.postMessage('PROBE_FAIL ' + failure.name + ': ' + failure.message);
  }
};
```

Started from `EntryAbility.onCreate`:

```ts
const probe = new worker.ThreadWorker('entry/ets/workers/TdWorkerProbe.ets');
probe.onmessage = (event: MessageEvents): void => {
  hilog.info(DOMAIN, TAG, 'WORKER_PROBE %{public}s', String(event.data));
};
probe.onerror = (event: ErrorEvent): void => {
  hilog.error(DOMAIN, TAG, 'WORKER_PROBE_ERROR %{public}s', event.message);
};
probe.postMessage('go');
```

---

## Two build-time facts, each costing a cycle

1. **A worker outside `ets/workers/` is not collected.** Placing the file at
   `ets/infra/td/worker/TdWorkerProbe.ets` compiled fine but produced a runtime
   `WORKER_PROBE_THROW The worker file path is invalid ... can't find the file`. The file never
   appeared under `entry/build/.../loader_out/default/ets/`. It must live in `ets/workers/` **and**
   be declared:

   ```json5
   "buildOption": {
     "sourceOption": { "workers": ["./src/main/ets/workers/TdWorkerProbe.ets"] },
     "externalNativeOptions": { ... }
   }
   ```

2. **The worker compilation unit does not inherit ambient module declarations.** Without
   `/// <reference path="../types/libtdlib_napi.d.ts" />` the `.so` import is typed `any` and the
   build fails with `arkts-no-any-unknown` (10605008) at the first `tdlib.<call>`, while the same
   import in `ets/` code compiles untouched. The compiler warns
   *"Currently module for 'libtdlib_napi.so' is not verified"* and then refuses the `any` anyway.

---

## What this does and does not establish

**Established:** module load, NAPI call path, and a real TDLib response, all inside a worker thread
on the target emulator.

**Not established:** anything about timing, contention, or the receive loop. The probe never calls
`startReceiveLoop`, never creates a client, and never runs the drain. It proves the door opens; it
says nothing about what happens in the room.

**Also not established:** whether the module tolerates being loaded from a worker *while the main
thread already holds an owner*. `tdlib_napi.cpp:150` keeps `static DeliveryOwner active_owner` —
process-global — so a second load does not yield a second client. The A/B must therefore be
sequential across two builds, exactly as the earlier paired diagnostic builds were.

---

## State after the probe

All probe changes were reverted: `AppScope/app.json5`, `entry/src/main/ets/entryability/EntryAbility.ets`,
`entry/build-profile.json5`, and the worker file itself. `git status` shows only the untracked
version-provenance report. The accepted `com.telegram.harmonyos` package was never installed over.
