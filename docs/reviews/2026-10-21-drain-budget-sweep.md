# Drain slice budget sweep — 2026-10-21

**Question:** the previous spike showed that relocating the drain changes nothing because the cost
scales with the number of yields, not with the thread. So what does the number of yields cost, and is
the current 8 ms budget the right one?

**Answer: on this model the 8 ms budget is the worst setting on both axes.** Larger budgets drain
faster *and* leave smaller main-thread frame gaps. Four levels, four runs each, monotonic in the mean.

---

## 1. Design

Isolated bundle `com.telegram.harmonyos.nativevalidation20261021`, API24 x86_64 emulator, main thread
only. Same workload as the topology spike: 161 responses × 8 ms of synchronous consumer work, 21
batches of 8, queue filled before the drain starts. Measurement opens 5 s after launch.

One variable: the slice budget — how long a drain slice may run before it must yield. A 6 ms/16 ms
frame load runs throughout, and its worst gap is snapshotted per variant.

Because one slice always performs at least one transfer, budget *b* yields `ceil(161 × 8 / b)` slices
in principle; measured hop counts are 161 / 81 / 41 / 21 for 8 / 16 / 32 / 64 ms.

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

---

## 3. What this supports

A **32 ms budget** removes about 690 ms of scheduling (25 %) and halves the worst frame gap relative
to the shipped 8 ms, on the same workload. A 64 ms budget removes about 1000 ms but its frame gap is
marginally worse than 32 ms.

**Caveats, all of which matter:**

- Ranges overlap. Budget 8's best run (2261) beats budget 32's worst (2572). The case rests on the
  mean ordering being monotonic across four levels, not on any single pairwise comparison.
- The frame load is synthetic (6 ms of work every 16 ms), not ArkUI rendering. It models contention,
  not a real scroll.
- The emulator's timer cost is likely not the phone's. The *direction* should hold; the magnitudes
  will not transfer.
- One work quantum: 8 ms per response, taken from the project's own measurement. If real consumer
  work is smaller, slices will hold many more items and the budget matters less.

---

## 4. What this does not support

It does not show that 8 ms is unsafe — 8 ms was chosen to avoid `THREAD_BLOCK_6S`, and 32 ms is three
orders of magnitude away from that. Nor does it show that 64 ms is better than 32; the two are within
noise on frames and 64 wins only on time.

It also does not touch the question that actually dominates the request interval. The earlier finding
stands: 88–93 % of it sits in native capacity waiting, and no slice budget changes that.

---

## 5. Recommendation

Do not change the shipped constant on this evidence alone. It is a one-line change and cheap to
verify, so the honest next step is a real-app check, not another synthetic sweep:

```
entry/src/main/ets/infra/td/gateway/TdGateway.ets:144
- private static readonly DRAIN_BUDGET_MS = 8;
+ private static readonly DRAIN_BUDGET_MS = 32;
```

Measure with the existing 15/15 host suite plus a scroll-under-load run on a real device. If the
frame gap does not regress there, the change pays for itself; if it does, 16 ms is the fallback and
still beats 8 ms on both axes here.

---

## 6. State

App wiring reverted (`AppScope/app.json5`, `EntryAbility.ets`). Probe bundle uninstalled; only
`com.telegram.harmonyos` remains, `firstInstallTime` unchanged at `1788721575252`.

Harness in `probe/`: `ProbeRunner.ets` (budget is now a constructor parameter), `FrameLoad.ets`
(`resetStats`/`peek` so one window of a long run can be attributed to one variant), `BudgetSweep.ets`
(the sweep driver), `TdProbeWorker.ets` (worker arm, unused here).
