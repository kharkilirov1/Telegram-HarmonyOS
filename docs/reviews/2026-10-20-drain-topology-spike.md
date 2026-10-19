# Drain topology spike — 2026-10-20

**Question:** does moving the receive drain off the main thread actually change anything on this
target, or is the whole direction an assumption?

**Answer: the apparatus works, one number moves in the predicted direction, and the result is not
yet a measurement you can decide on.** What follows separates what was observed from what was not.

---

## 1. What ran

Isolated bundle `com.telegram.harmonyos.nativevalidation20261020`, installed beside the accepted
`com.telegram.harmonyos` and removed afterwards. API24 x86_64 emulator.

Identical drain code in both arms — the only difference is the thread that owns it:

- batches arrive, each response costs **8 ms** of synchronous consumer work,
- the drain yields once it has spent **8 ms** in a slice, guaranteeing one transfer per turn,
- 161 items in 21 batches, emitted back to back so the queue can build up,
- a main-thread frame load runs throughout: 6 ms of work every 16 ms, never yielding early.

Work floor: 161 × 8 ms = **1288 ms**. Everything above that is scheduling.

Harness source is preserved in `probe/` at the repository root — deliberately outside `entry/`, so it
is version-controlled but not compiled into the app.

---

## 2. Results

### Burst arrival (21 batches × 8 items, back to back)

| Arm | elapsed | max batch latency | max backlog | frame ticks | worst frame gap |
|---|---|---|---|---|---|
| worker | **3941 ms** | 3754 ms | 19 | 1 | 0 ms |
| main | **4743 ms** | 2151 ms | 19 | 85 | **2332 ms** |

### Trickle arrival (1 item per 2 ms, 161 batches)

| Arm | elapsed | max batch latency | max backlog | frame ticks | worst frame gap |
|---|---|---|---|---|---|
| worker | 4580 ms | 546 ms | 1 | 1 | 0 ms |
| main | 8646 ms | 247 ms | 1 | 98 | **5308 ms** |

---

## 3. What the numbers support

**Supported:** on the burst workload the main-thread arm took **20 % longer** (4743 vs 3941 ms) for
identical work, and during that run the main thread stopped for **2.3 s** — the `THREAD_BLOCK_6S`
family the project has already hit five times.

**Not supported:** any claim about the worker arm's frame behaviour. Its frame counter recorded
**1 tick**, so `worst frame gap = 0` means "the loop never ran", not "nothing stalled". The metric is
dead in that arm and must not be read as a clean bill of health.

**Not supported:** `max batch latency` as a comparison. It is *lower* on main (2151 vs 3754 ms) for a
confounded reason: with frames stealing time, batches are stamped later, so the interval from arrival
to ack shrinks even though the whole run takes longer. Latency measured from arrival is only
comparable when arrival timing is independent of the drain — it is not here.

**Not supported:** anything about capacity. Backlog peaked at 19 in both arms, so neither arm
exercised the 4-batch admission limit that the original defect was about.

---

## 4. The native source could not be exercised at all

The first design drove real TDLib through `startReceiveLoop`. It produced **zero responses**:

```
TDLib client created: 1
TDLib send: getOption      (×161)
```

161 sends, no batches, ever. The client is unauthenticated — `ConfigLocal.ets` carries dummy API
credentials by design — and TDLib does not answer a client that never reaches a ready authorization
state. The earlier harness that reported 161 `getOption` responses presumably ran with real
credentials, which are not in this repository and must not be committed.

This is the same external gate as authenticated delivery, showing up where it was not expected:
**the drain cannot be measured against live TDLib without an authorized client.** The synthetic
source was built to route around it, and the price is that arrival timing is now modelled, not real.

---

## 5. A defect in the harness, found and fixed

The first drain implementation re-armed its timer whenever the queue emptied:

```
if (queue.length > 0) { pump(); return; }
if (items >= expected) { finish(true); }
pump();          // ← idle: schedules another slice immediately, forever
```

That spins a zero-delay timer loop on the thread it is supposed to be measuring, and it starved the
app's own `AppCoreRuntime` initialization (`TDLib init failed: TDLib receive owner is not retired`).
Fixed by returning to idle and letting the next `accept()` re-arm the pump. Worth recording because
the same shape is easy to write by accident in production code.

---

## 6. What the next iteration needs

1. **A main-thread load that does not depend on the window.** The frame counter's collapse in the
   worker arm tracks the window state, not the drain. Drive the load from a timer that starts after
   `onWindowStageCreate` settles, and verify it ticks before trusting a gap of 0.
2. **Arrival timing decoupled from the drain.** Stamp each batch at emission and measure drain
   duration per batch, not arrival-to-ack.
3. **Real arrivals, or an explicit statement that this is a model.** Either obtain credentials for an
   authorized client in an isolated bundle, or write "synthetic" on the result and stop calling it a
   TDLib measurement.

Until (1) and (2) are done, the 20 % delta is a lead, not a finding.

---

## 7. State

All wiring reverted: `AppScope/app.json5`, `entry/src/main/ets/entryability/EntryAbility.ets`,
`entry/build-profile.json5`. Probe bundle uninstalled. Only `com.telegram.harmonyos` remains on the
emulator, `firstInstallTime` unchanged at `1788721575252`.

Harness kept in `probe/` — `ProbeRunner.ets`, `FrameLoad.ets`, `TdProbeWorker.ets`. To rebuild it,
declare the worker in `entry/build-profile.json5` under `buildOption.sourceOption.workers`, set the
bundle name to an isolated `com.telegram.harmonyos.nativevalidation<yyyymmdd>`, and call
`runProbe()` from `EntryAbility.onCreate`.
