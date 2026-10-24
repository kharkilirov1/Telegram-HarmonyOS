# probe/ — drain measurement harness

Synthetic harness used by the receive-drain notes
([2026-10-20 topology spike](../docs/reviews/2026-10-20-drain-topology-spike.md),
[2026-10-21 budget sweep](../docs/reviews/2026-10-21-drain-budget-sweep.md)).

## Status

**Not part of the build.** `probe/` sits outside the `entry` module declared in
`build-profile.json5`, and there is no linter or typecheck covering it. Nothing here is compiled by
`hvigor`, so a type error in this directory survives silently. A missing constructor argument did
survive here for two commits. Before trusting these files, compare them against
`entry/src/main/ets/infra/td/gateway/TdGateway.ets`; after editing, run them once on an emulator.

## Files

| File | Role |
|---|---|
| `ProbeRunner.ets` | The drain under test: prefilled queue, per-response synchronous work, slice budget, measured slice/drain/wait/backlog counters |
| `FrameLoad.ets` | Main-thread frame load with a heartbeat, so a stalled loop is visible instead of reading as "no gap" |
| `BudgetSweep.ets` | Sweeps the budget over one workload and records time and worst frame gap per variant |
| `ProbeEntry.ets` | Runnable entry point: settle delay, budget sweep, main arm of the topology comparison |
| `TdProbeWorker.ets` | Worker arm: the same runner on another thread |

## Yield model — read this before quoting any number

`ProbeRunner` takes a yield model:

- `YIELD_IMMEDIATE` — `setTimeout(..., 0)` between slices. **This is what the recorded 2026-10-20
  and 2026-10-21 runs used.**
- `YIELD_SHIPPED` — the delay the gateway actually schedules:
  `max(2, min(250, elapsed * 2))`, i.e. the pause grows with the slice.

The difference is not cosmetic: under `YIELD_IMMEDIATE` a bigger budget makes the whole drain
faster, under `YIELD_SHIPPED` the saved scheduling comes back as a longer mandated pause, so total
time is roughly flat in the budget. A budget sweep run under `YIELD_IMMEDIATE` therefore says
nothing about the shipped constant (`TdGatewayImpl.DRAIN_BUDGET_MS`).

## Recorded runs

| Run | What it measured | Evidence |
|---|---|---|
| 2026-10-21 | Budget sweep under `YIELD_IMMEDIATE` (superseded, see the report's corrections) | none retained |
| 2026-10-23 | Both models back-to-back in one build, n = 3 per budget — the shipped pacing measured | [`run-2026-10-23/`](run-2026-10-23/) |

`run-2026-10-23/probe-rows.txt` holds the 24 `PROBE_ROW` lines; `runner.log` is the host transcript of
that run, `environment.txt` records the host the numbers came from (a 2014 Xeon with a 97 %-full disk —
its absolute timings are an upper bound), and the two `.ps1` files are how it was started and captured.
The report is
[docs/reviews/2026-10-23-drain-yield-model-rerun.md](../docs/reviews/2026-10-23-drain-yield-model-rerun.md).

## How to run

1. Build an isolated bundle (`com.telegram.harmonyos.nativevalidation<yyyymmdd>`), never over the
   accepted app.
2. Copy the files you need under `entry/src/main/ets/` and declare the worker, if used, under
   `buildOption.sourceOption.workers` in `entry/build-profile.json5`. The worker file and
   `ProbeRunner.ets` must share a directory because `TdProbeWorker.ets` imports `./ProbeRunner`.
3. Call the entry point from `EntryAbility.onCreate`:

   ```ts
   const probe = new ProbeEntry((beat: string) => Logger.info(beat));
   probe.runBudgetSweep(DEFAULT_BUDGETS, (row) => { /* log one JSON line per row */ }, () => {
     /* log the frame stats and stop */
   }, YIELD_SHIPPED);
   ```

4. Revert the wiring and uninstall the probe bundle; keep `firstInstallTime` of the accepted app
   unchanged as the receipt.

## Rules for reading a result

- Exclude rows with `completed: false`; they hit the 60 s watchdog and carry `elapsedMs: -1`.
- `maxBacklog` is the deepest queue observed, so a prefilled run reports the fill size — it is not
  evidence that two arms had equal work.
- `maxWaitMs` is fill → first touch, not arrival-to-ack.
- A worker arm cannot carry the frame load; only the main arm produces usable frame gaps.
