# Drain topology spike — 2026-10-20

> **Corrections — 2026-10-23.** The retraction in §3 stands; four supporting details did not.
>
> 1. **`maxBacklog` was not evidence.** The harness records the deepest queue observed, and the queue
>    was prefilled, so both arms reporting `maxBacklog = 21` only repeats the fill size. That the
>    workload was identical rests on `items = 161` and on the code, not on this counter.
> 2. **The "7 ms per yield" is platform timer cost under a zero-delay hand-off.** The harness yields
>    with `setTimeout(..., 0)`, while the shipped drain schedules the next slice at
>    `max(2, min(250, elapsed × 2))`. Production addends that mandated pause to every yield, so the
>    figure describes the emulator's timer overhead, not the drain's cost per turn.
> 3. **The frame numbers do not agree with the next note.** This note reports 37–237 ms worst main-arm
>    gap; the [budget sweep](2026-10-21-drain-budget-sweep.md) reports 102–630 ms for the same nominal
>    8 ms configuration. The difference is unexplained and the sweep's cross-budget frame comparison
>    inherits it. Neither number should be quoted without the other.
> 4. **The rebuild recipe in §7 was incomplete** and the retained worker file did not compile (a
>    constructor argument was missing after the budget became a parameter). Both are fixed; see §7.

**Question:** does moving the receive drain off the main thread change anything measurable on this
target?

**Answer: no, not on this workload.** With the confounds removed, the main-thread arm and the worker
arm are indistinguishable. The earlier 20 % delta reported in the first version of this note was an
arrival-timing artefact, and it is retracted below.

---

## 1. Design

Isolated bundle `com.telegram.harmonyos.nativevalidation20261020` on the API24 x86_64 emulator,
installed beside the accepted `com.telegram.harmonyos` and removed afterwards.

Identical drain code in both arms — the only difference is the thread that owns it:

- **21 batches × 8 items, 161 responses, filled synchronously before the drain starts.** Arrival
  timing is therefore identical in both arms, which removes the confound that made a slow drain
  stamp batches later and look faster per batch.
- **8 ms of synchronous consumer work per response** — an injected quantum, not the observed
  parse/dispatch cost (see Corrections and
  [receive-latency](2026-10-18-receive-latency.md)).
- **8 ms slice budget with a guaranteed first transfer**, i.e. the drain that is already committed.
- **Measurement opens 5 s after launch**, so window load is not attributed to the drain.
- **Worker cold start is outside the window**: the worker posts `ready` on module load and the main
  thread starts the clock only after that.
- Four runs per arm, each a fresh process (`aa force-stop` + `aa start`).

Work floor: 161 × 8 ms = **1288 ms**. Anything above that is scheduling.

---

## 2. Result

| Run | main | worker |
|---|---|---|
| 1 | 1984 ms | 1821 ms |
| 2 | 2163 ms | 2514 ms |
| 3 | 2462 ms | 2925 ms |
| 4 | 2948 ms | 2960 ms |
| **mean** | **2389 ms** | **2555 ms** |
| range | 1984–2948 | 1821–2960 |

The ranges overlap almost completely. **No difference is demonstrated.** The worker arm's mean is
7 % higher, which is smaller than the spread within either arm.

Both arms finished with `items = 161` — the workload was identical and fully drained in both. (The
note also cited `maxBacklog = 21` for this; that counter only repeats the fill size, see
Corrections 1.)

### Why the overhead is where it is

Measured 2389 ms against a 1288 ms work floor leaves ~1100 ms of scheduling across 161 yields, about
**7 ms per yield**. That is the emulator's timer cost under a *zero-delay* hand-off, and it is a
function of *how many times* the drain yields, not of *which thread it yields on*. Moving threads
cannot reduce it, which is exactly what the numbers show. The shipped drain also inserts its own
delay (`max(2, min(250, elapsed × 2))`), which this harness does not model — see Corrections 2.

---

## 3. Retraction

The first version of this note (commit `992e281`) reported main 4743 ms versus worker 3941 ms, a
20 % delta in the predicted direction, plus a 2332 ms main-thread frame stall. All three of those
figures are withdrawn:

- The batches were emitted from a timer **while** the drain ran, so a slow drain delayed its own
  arrival stamps and shortened the measured arrival-to-ack interval. The main arm's `maxBatchLatency`
  was *lower* than the worker's (2151 vs 3754 ms) for that reason. Filling the queue up front
  removes the effect.
- The worker arm was carrying its own cold start inside the measured window.
- The frame stall came from window load, not from the drain: with a 5 s settle delay, main-thread
  frame gaps fall to 37–237 ms across runs.

A metric that moves in the predicted direction for the wrong reason is worse than no metric.

---

## 4. What was not measured, and why

**Live TDLib arrivals.** The first design drove the real receive loop. It produced zero responses:
161 `tdlib.send` calls, no batches ever. TDLib does not answer a client that never reaches a ready
authorization state, and `ConfigLocal.ets` carries dummy API credentials by design. Arrival timing is
modelled here, not observed. Measuring the real path needs an authorized client, which is the same
external gate as authenticated delivery.

**Frame behaviour in the worker arm.** The frame counter records 1 tick there, in every run. On an
otherwise idle ArkTS thread this emulator throttles timers, so `maxGap = 0` means the loop never ran.
The metric is unusable in that arm and must not be read as a clean bill of health. Only the main arm
produced usable frame numbers (37–237 ms worst gap) — and the next note, same nominal configuration,
reports 102–630 ms instead. The two are not reconciled; see Corrections 3.

**Admission limits.** `MAX_OUTSTANDING_BATCHES = 4` was never exercised: the queue is filled by the
probe, not by the native admission path, so the 4-batch ceiling and its `failDelivery` branch are
outside this measurement entirely.

---

## 5. A defect in the harness, found and fixed

The first drain implementation re-armed its timer whenever the queue emptied:

```
if (queue.length > 0) { pump(); return; }
if (items >= expected) { finish(true); }
pump();          // ← idle: schedules another slice immediately, forever
```

That spins a zero-delay timer loop on the thread it is supposed to measure, and it starved the app's
own initialization (`TDLib init failed: TDLib receive owner is not retired`). Fixed by returning to
idle and letting the next fill re-arm the pump.

---

## 6. What this means for the project

The direction was reasonable and is now measured rather than assumed. On a pre-loaded backlog with
the current drain, the thread that owns the work does not matter; what matters is the number of
yields, and that number is unchanged by relocating the drain.

This is consistent with the project's own earlier finding that 88–93 % of the request interval sits
in native capacity waiting — not in the consumer. Relocating the consumer cannot move time that was
never spent in the consumer.

**Do not open a production change on the strength of this spike.** If the drain is to be revisited at
all, the next question is not "which thread" but "why 161 responses cost ~1100 ms of scheduling", and
that is a question about the yield path, not about threading.

---

## 7. State

App wiring reverted (`AppScope/app.json5`, `EntryAbility.ets`, `entry/build-profile.json5`), probe
bundle uninstalled, only `com.telegram.harmonyos` remains with `firstInstallTime` unchanged at
`1788721575252`.

Harness kept in `probe/` outside `entry/`: `ProbeRunner.ets` (prefilled queue, per-batch drain and
wait timing), `FrameLoad.ets` (heartbeat-emitting main-thread load), `TdProbeWorker.ets` (ready
handshake), `ProbeEntry.ets` (entry point with the 5 s settle delay), `probe/README.md` (status and
constraints).

To rebuild: set an isolated `com.telegram.harmonyos.nativevalidation<yyyymmdd>` bundle name, copy the
files you need under `entry/src/main/ets/`, declare the worker under
`buildOption.sourceOption.workers`, and call `ProbeEntry.runMainArm(8)` from `EntryAbility.onCreate`.
For the worker arm, `TdProbeWorker.ets` and `ProbeRunner.ets` must be copied into the **same**
directory (`ets/workers/`), because the worker imports `./ProbeRunner` — the earlier version of this
recipe pointed at a path back into `probe/`, which does not exist once the worker is relocated. The
retained worker file also lacked its `budgetMs` argument after the budget became a constructor
parameter; that is fixed. Revert the wiring afterwards; nothing under `entry/` imports `probe/`.
