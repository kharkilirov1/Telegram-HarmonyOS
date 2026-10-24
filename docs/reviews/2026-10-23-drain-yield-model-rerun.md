# Drain yield-model re-run — 2026-10-23

**Question:** the [budget sweep](2026-10-21-drain-budget-sweep.md) varied the slice budget under a
zero-delay hand-off (`setTimeout(..., 0)`), while the shipped drain schedules its next slice at
`max(2, min(250, elapsed × 2))`. That note was corrected on 2026-10-23 but could only *predict* what
the shipped model does. This run measures it.

**Answer: the shipped model is ~2.8–3.1× slower than the zero-delay model, its budget curve is flatter
(−18 % from 8 ms to 64 ms instead of −27 %), and the frame-gap ordering is not monotone.** The
2026-10-21 headline "8 ms is the worst setting on both axes" is **not reproduced**. No production
change is supported by this run either, but for a different reason than the note assumed: the effect is
real and smaller, not absent. Every millisecond here is from a 2014 Xeon host with a 97 %-full disk
(§6) — the absolute values are an upper bound, the shape is what travels.

---

## 1. Design

Same harness, same workload, same target as the earlier notes, one build running both models
back-to-back so the comparison does not straddle a rebuild:

- Isolated bundle `com.telegram.harmonyos.nativevalidation20261023`, API24 x86_64 emulator
  (`Pura 90 Pro Max`, HarmonyOS 6.1.1(24)), installed beside the accepted `com.telegram.harmonyos`.
- Workload: 161 responses × 8 ms of injected synchronous consumer work, 21 batches of 8, queue filled
  before the drain starts. Work floor **1288 ms**.
- `ProbeEntry.runBudgetSweep` with budgets **8 / 16 / 32 / 64 ms**, budgets and both yield models in
  one process: `immediate`, `shipped`, `immediate`, `shipped`, `immediate`, `shipped` — **n = 3 per
  (model, budget)**, all 24 rows `completed`.
- 5 s settle before every round; a 6 ms/16 ms frame load runs throughout and its worst gap is
  snapshotted per variant.
- `AppCoreRuntime` is deliberately not started, so no account and no TDLib client exist during the
  measurement.
- Host: Intel Xeon E5-2687W v3 (2014), 32 GB RAM with 8.7 GB free, `C:` 96.9 % full, cold boots only —
  see §6, where this is treated as part of the result.

App start 03:12:39 device time, `PROBE_DONE` 03:15:04. HAP 87 456 936 B, unsigned, incremental hvigor
build.

## 2. Results

| Budget | `immediate` runs (ms) | mean | `shipped` runs (ms) | mean | shipped ÷ immediate | slices (measured) |
|---|---|---:|---|---:|---:|---|
| **8 ms** | 1786 · 1938 · 2125 | **1950** | 5318 · 5327 · 5738 | **5461** | 2.80× | 161 |
| **16 ms** | 1768 · 1779 · 1949 | **1832** | 5252 · 5545 · 5546 | **5448** | 2.97× | 81–83 |
| **32 ms** | 1528 · 1545 · 1570 | **1548** | 4357 · 5116 · 5126 | **4866** | 3.14× | 41–43 |
| **64 ms** | 1408 · 1418 · 1455 | **1427** | 4029 · 4394 · 4968 | **4464** | 3.13× | 21–23 |

Worst main-thread frame gap, mean per budget:

| Budget | `immediate` gap | `shipped` gap | shipped maxDrain mean |
|---|---:|---:|---:|
| 8 ms | 49 ms | **207 ms** | 392 ms |
| 16 ms | 49 ms | **285 ms** | 521 ms |
| 32 ms | 47 ms | **216 ms** | 329 ms |
| 64 ms | 76 ms | **130 ms** | 411 ms |

## 3. What this establishes

1. **The zero-delay model understated the shipped drain by a factor of ~3.** Same workload, same
   device, same build: 5461 ms at 8 ms with the gateway's pacing against 1950 ms without it. Every
   absolute number in the 2026-10-21 table describes a system the app does not implement.
2. **The budget curve does not flatten, but it does halve.** 8 → 64 ms is −18.3 % in the shipped
   model against −26.8 % in the zero-delay model; 8 → 32 ms is −10.9 % against −20.6 %. The delay
   term `2 × elapsed` grows with the slice, but per-slice fixed overhead shrinks with the slice count,
   so fewer slices still win — by about half of the claimed margin.
3. **"Bigger budget is kinder to the frame loop" does not survive contact with the shipped model.**
   The shipped gaps are 207 / 285 / 216 / 130 ms — non-monotone, with the 16 ms and 32 ms budgets
   *worse* than 8 ms. Only 64 ms is clearly better on both axes in this run (−18 % time, −37 % gap),
   and that is one of four levels, n = 3, on an emulator.
4. **Measured slice counts confirm the earlier "derived" correction.** 161 / 81–83 / 41–43 / 21–23
   against the derived 161 / 81 / 41 / 21: the arithmetic was right within one slice, as recorded.
5. **Per-batch drain latency grows with the budget.** `maxDrain` means 392 / 521 / 329 / 411 ms — a
   wider slice delays acknowledgement of the batch that is being drained, which is the quantity a
   request deadline sees. This was not visible in the zero-delay note at all.

## 4. What this does not support

It does **not** justify changing `DRAIN_BUDGET_MS` to 32 or 64. Three reasons, all of which are about
this run rather than about the app:

- **n = 3 on an unstable host.** The 64 ms runs span 4029–4968 ms; 32 ms spans 4357–5126 ms and
  overlaps 64 ms. A single level ordering is not a curve.
- **The emulator is not the phone.** Timer cost on this host produced ~7 ms per yield in the earlier
  note; a real device's cost will be different, and the whole effect is scheduling, not work.
- **The host is a 2014 Xeon with a 96.9 %-full system disk** (§6). Its timer cost inflates every
  measured millisecond; the absolute values, and partly the −18 %, are properties of this machine.
- **The work quantum is still synthetic.** 8 ms per response remains an injected delay; the real
  parse/dispatch/store cost is unmeasured, and the whole curve shifts with it.

Nor does it establish that 8 ms is unsafe: at 8 ms the shipped model is 5461 ms for 1288 ms of work,
which is slow but bounded, and no `THREAD_BLOCK_6S` (6 s) gap occurred — the worst observed gap was
308 ms.

## 5. Effect on the 2026-10-21 note

- Its correction 1 (hop counts were derived) stands; this run measures 161/81–83/41–43/21–23.
- Its correction 2 said the shipped time "would be roughly flat in the budget". **Too strong:** it is
  −18 %, not flat. The direction was right, the magnitude was not.
- Its §5 withdrawal of the 32 ms recommendation stands for a different reason: the measured gain is
  about half the claimed one and the frame ordering is not monotone, so the case is weaker than
  originally argued rather than void.
- Decision [D23](../../DECISIONS.md) (keep the shipped threading and budget) still holds; its basis is
  now "measured, small, non-monotone, emulator-only" instead of "the effect belongs to a different
  model".

## 6. Environment — and how far the numbers travel

This run was taken on a weak, nearly full host. That is part of the result, not a footnote, because
what the probe measures is *scheduling cost*, and scheduling cost is exactly what an old CPU inflates.

| | Value |
|---|---|
| CPU | Intel Xeon E5-2687W v3 (Haswell-EP, 2014), 10 cores / 20 threads |
| RAM | 32 GB total, **8.7 GB free** while the emulator ran (guest configured with 6 GB) |
| Disk | `C:` 930.4 GB, **28.5 GB free — 96.9 % full** |
| Emulator | `Pura 90 Pro Max` HVD, HarmonyOS 6.1.1(24), x86_64; instance 7.02 GB, system images 56 GB |
| OS | Windows 11 Pro for Workstations, build 26200 |

Consequences seen during the run:

- **Cold boot only.** `bootmode "snapshot"` is rejected ("Hot boot is not enable"), so every restart
  re-verifies the images — `system.img` alone took 347 s. A crash costs ~6 minutes.
- **Guest instability under host pressure.** The guest kernel-panicked twice (`sysrq triggered crash`,
  02:39:12 and 02:57:50 device time) while the HVD was being stopped and restarted at 97 % disk and
  ~9 GB free RAM. The measurement boot stayed up for the whole run (423 s and counting).
- **Timer-dominated numbers.** The drain's measured cost is `work + yields × (timer + mandated
  pause)`. On a 2014 single-thread this timer term is inflated, which is why the shipped/immediate
  ratio is 2.8–3.1× here.

What the host therefore bounds:

- **Absolute milliseconds are an upper bound for this host, not app behaviour.** On a phone, the same
  algorithm yields far less per hand-off, so 5461 ms at 8 ms would shrink. Treat every number in §2 as
  "this machine", not "the app".
- **The −18 % gain is also host-shaped.** It is a difference of two timer-dominated curves; on a
  device both curves compress and the difference shrinks with them.
- **What survives the host:** the *shape* — the pause is computed from slice length, so the budget
  curve must be flatter than the zero-delay one; slice counts (161 / 81–83 / 41–43 / 21–23) are
  arithmetic, not timing; and the frame-gap ordering is produced by how many timer hand-offs the frame
  loop shares, not by clock speed.

Anyone repeating this should record host load, free RAM and free disk with the run — they are inputs
to the measurement, the same way the workload is. A host with 28 GB free on `C:` and room to hot-boot
would produce different numbers and way fewer panics. The captured values are in
[`probe/run-2026-10-23/environment.txt`](../../probe/run-2026-10-23/environment.txt).

## 7. State after the run

- Wiring reverted: `AppScope/app.json5` back to `com.telegram.harmonyos`,
  `entry/src/main/ets/entryability/EntryAbility.ets` restored, the copied `entry/src/main/ets/probe/`
  removed. No residue of `nativevalidation` / `ProbeEntry` in `entry/` or `AppScope/`.
- Probe bundle uninstalled; `bm dump -a` lists only `com.telegram.harmonyos`, `firstInstallTime`
  unchanged at `1788721575252`.
- Evidence: [`probe/run-2026-10-23/probe-rows.txt`](../../probe/run-2026-10-23/probe-rows.txt) (all 24
  rows), [`runner.log`](../../probe/run-2026-10-23/runner.log), and the two scripts used to start and
  capture the run.
