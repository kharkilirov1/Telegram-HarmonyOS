# Drain slice budget sweep — 2026-10-21

> **Corrections — 2026-10-23.** The runs are real; three labels and the recommendation were wrong.
> Read this before quoting any number below.
>
> 1. **The "measured hop counts" were derived.** The harness had no slice counter at the time;
>    `161 / 81 / 41 / 21` is `ceil(161 × 8 / b)` evaluated by hand. `probe/ProbeRunner.ets` counts
>    slices now, so a re-run measures the figure this note asserted.
> 2. **The harness yielded with a zero delay; the shipped gateway does not.** `ProbeRunner` used
>    `setTimeout(..., 0)` for every hand-off, while `TdGatewayImpl.drainSlice` schedules the next turn
>    at `max(2, min(250, elapsed × 2))` — the pause grows with the slice. The 37 % / 25 % improvements
>    below belong to the zero-delay model and do not transfer. **Measured on 2026-10-23** (see the
>    [yield-model re-run](2026-10-23-drain-yield-model-rerun.md)): the shipped model is ~2.8–3.1×
>    slower and its budget curve is flatter — 8 → 64 ms is −18 %, not −27 % as here, and the frame
>    ordering is not monotone. Those numbers come from a 2014 Xeon host with a 97 %-full disk, so they
>    are an upper bound rather than phone behaviour. The harness now implements `YIELD_SHIPPED`; the
>    recorded runs used `YIELD_IMMEDIATE`.
> 3. **The 8 ms work quantum is injected, not observed.** It comes from the 2026-10-18 diagnostics,
>    where 8 ms of *artificial* consumer work per response was injected to model a slow consumer (see
>    [receive-latency](2026-10-18-receive-latency.md) and
>    [bounded-timeout diagnostics](2026-10-18-bounded-timeout-diagnostics.md)). A model calibrated on
>    its own injection is only self-consistent.
> 4. **The §5 recommendation is withdrawn**; §5 now says what replaced it.
> 5. The 8 ms-budget frame gaps here (102–630 ms) are a different regime from the 37–237 ms reported
>    for the same nominal configuration in the topology spike. The difference is unexplained; the
>    cross-budget frame comparison rests on exactly this metric.

**Question:** the previous spike showed that relocating the drain changes nothing because the cost
scales with the number of yields, not with the thread. So what does the number of yields cost, and is
the current 8 ms budget the right one?

**Answer: on this model** (zero-delay yield, see Corrections) **the 8 ms budget is the worst setting
on both axes.** Larger budgets drain faster *and* leave smaller main-thread frame gaps. Four levels,
four runs each, monotonic in the mean.

---

## 1. Design

Isolated bundle `com.telegram.harmonyos.nativevalidation20261021`, API24 x86_64 emulator, main thread
only. Same workload as the topology spike: 161 responses × 8 ms of synchronous consumer work (an
injected quantum, see Corrections 3), 21 batches of 8, queue filled before the drain starts.
Measurement opens 5 s after launch.

One variable: the slice budget — how long a drain slice may run before it must yield. A 6 ms/16 ms
frame load runs throughout, and its worst gap is snapshotted per variant.

Because one slice always performs at least one transfer, budget *b* yields `ceil(161 × 8 / b)` slices
in principle, which gives 161 / 81 / 41 / 21 for 8 / 16 / 32 / 64 ms. The first version of this note
called those four numbers *measured*; they were not — no slice counter existed then (see
Corrections 1).

Work floor: **1288 ms**.

---

## 2. Results

| Budget | Runs (ms) | Mean | Overhead over floor | Frame gap mean | Gaps (ms) |
|---|---|---|---|---|---|
| **8 ms** | 2261 · 2653 · 2861 · 3099 | **2719** | +1431 | **301** | 102 · 190 · 281 · 630 |
| **16 ms** | 2553 · 2319 · 2287 · 2373 | **2383** | +1095 | 232 | 365 · 262 · 170 · 130 |
| **32 ms** | 2572 · 1934 · 2008 · 1601 | **2029** | +741 | **123** | 253 · 105 · 83 · 51 |
| **64 ms** | 1835 · 1550 · 1859 · 1575 | **1705** | +417 | 136 | 209 · 79 · 162 · 95 |

**Total time falls monotonically with the budget**: 2719 → 2383 → 2029 → 1705 ms, a 37 % reduction
from 8 ms to 64 ms and 25 % to 32 ms.

**Frame gap does not get worse with a bigger budget — it gets better**, bottoming out at 32 ms. This
is the counterintuitive part: every yield carries scheduler overhead during which the frame loop is
also delayed, so fewer, longer slices are kinder to the frame loop than many short ones.

Both statements are properties of the **zero-delay** yield model. In the shipped model the pause
between slices is `max(2, min(250, elapsed × 2))`, so the time column is expected to flatten with the
budget; the frame effect is expected to survive, because it depends on how many timer hand-offs the
frame loop has to share, not on how long the pause is. Re-running this sweep with `YIELD_SHIPPED` is
the open next step.

---

## 3. What this supports

**In the zero-delay model, and only there:** a **32 ms budget** removes about 690 ms of scheduling
(25 %) and halves the worst frame gap relative to 8 ms, on the same workload; a 64 ms budget removes
about 1000 ms but its frame gap is marginally worse than 32 ms. The shipped model amortises the saved
scheduling back into its own pause, so the time half of that sentence is a property of the harness —
see the paragraph above and §5.

**Caveats, all of which matter:**

- Ranges overlap. Budget 8's best run (2261) beats budget 32's worst (2572). The case rests on the
  mean ordering being monotonic across four levels, not on any single pairwise comparison.
- The frame load is synthetic (6 ms of work every 16 ms), not ArkUI rendering. It models contention,
  not a real scroll.
- The emulator's timer cost is likely not the phone's. The *direction* should hold; the magnitudes
  will not transfer.
- One work quantum: 8 ms per response. That figure is **injected, not measured**: the 2026-10-18
  diagnostics added 8 ms of artificial consumer work per response to model a slow consumer, and this
  note inherited it. If the real parse/dispatch cost is smaller, a slice holds many more items and
  the budget matters less; if it is larger, the whole curve shifts.

---

## 4. What this does not support

It does not show that 8 ms is unsafe — 8 ms was chosen to avoid `THREAD_BLOCK_6S`, and 32 ms is three
orders of magnitude away from that. Nor does it show that 64 ms is better than 32; the two are within
noise on frames and 64 wins only on time.

It also does not touch the question that actually dominates the request interval. The earlier finding
stands: 88–93 % of it sits in native capacity waiting, and no slice budget changes that.

---

## 5. Recommendation

**Withdrawn on 2026-10-23.** The first version proposed this patch on the strength of the table
above:

```
- private static readonly DRAIN_BUDGET_MS = 8;
+ private static readonly DRAIN_BUDGET_MS = 32;
```

It does not follow from the experiment. The sweep varied the budget under a zero-delay yield, while
the gateway's inter-slice delay is `max(2, min(250, elapsed × 2))` — it **scales with the budget**, so
larger slices remove scheduling cost and add it straight back as a longer mandated pause. The time
column of this table therefore does not transfer, and what remains is a frame-fluidity argument that
the synthetic load here cannot settle.

What replaces it:

1. ~~Re-run the same sweep with `YIELD_SHIPPED`~~ — **done 2026-10-23**:
   [drain yield-model re-run](2026-10-23-drain-yield-model-rerun.md). The shipped model is ~2.8–3.1×
   slower, 8 → 64 ms buys −18 % (not 37 %), and the frame-gap ordering is non-monotone. The case for a
   larger budget is weaker than the first version of this note claimed, not void.
2. Then measure on a real device with a scroll under load. **Still open.**
3. **Until that exists, `DRAIN_BUDGET_MS` stays 8.** No production change is supported.

---

## 6. State

App wiring reverted (`AppScope/app.json5`, `EntryAbility.ets`). Probe bundle uninstalled; only
`com.telegram.harmonyos` remains, `firstInstallTime` unchanged at `1788721575252`.

Harness in `probe/`: `ProbeRunner.ets` (budget is a constructor parameter, and since 2026-10-23 also
a yield model plus measured `slices` / `maxBacklog` counters), `FrameLoad.ets` (`resetStats`/`peek` so
one window of a long run can be attributed to one variant), `BudgetSweep.ets` (the sweep driver; rows
now carry `slices`, `yieldModel` and `completed`), `TdProbeWorker.ets` (worker arm, unused here),
`ProbeEntry.ets` (runnable entry point with the 5 s settle delay), and `probe/README.md` (status: not
compiled by the build).
