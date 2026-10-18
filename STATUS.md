# STATUS — Telegram-HarmonyOS

Current state only. Every superseded dated snapshot, and the pre-compaction version of this file,
lives in `TASKS/ARCHIVE/STATUS-history-2026-10-18.md`. Reports referenced here are immutable
checkpoints — see `docs/reviews/INDEX.md` for all 72 of them.

## Where it stands — 2026-10-18

| Area | State |
|---|---|
| Receive scheduling (drain) | **Accepted.** Bounded correction, 15/15 regressions, independent Astra review. |
| Main reliability (request timeouts) | **PARTIAL.** 2/4 observed timeouts on the exact official package; root cause not established. |
| Source publication | `dev` pushed to `origin/dev`, CI green on `d706143`. |
| Install over authenticated main | **Not done** for the correction. Not released, not signed. |
| Authenticated delivery / providers / shipped-iOS / signing | **Open** since 2026-09-27. |

## Latest checkpoint — 2026-10-18

**Receive scheduling correction.** The drain tested its 8 ms budget before transferring, so a single
clock access or batch parse could consume a quantum with zero progress; an escalating multiplier
`elapsed * (1 + drainHotStreak)` stretched pauses to 250 ms even for a finite already-admitted
backlog. Now one transfer is guaranteed per turn, bounded by 50 transfers / 4 new batches, with the
inter-turn delay at twice the measured work and no backlog-age multiplier. Same-fixture native
comparison: admission→dispatch 31 847 → 5 598 ms, 37 rejected → 0. Four-variant split: baseline
6/15, progress-only 14/15, pacing-only 7/15, combined 15/15. FIFO, deadlines, byte/batch limits,
ownership, ACK ordering and no-uncertain-replay unchanged. [Report](docs/reviews/2026-10-18-receive-latency.md)

**Main acceptance stays PARTIAL.** The exact official package was installed over the existing session
(UID/install identity retained) and getMe, profile, chat list, existing history, Back and same-PID
background/resume were observed across two instances. But 2/4 unique observed request timeouts
(loadChats/getChat/setOption) remained, against historical 87/5 under different windows and workload.
No speedup is claimed. [Report](docs/reviews/2026-10-18-main-receive-acceptance.md)

**Diagnostic main localized, did not explain.** Two cold processes (PIDs 9355/10050) reproduced 4/10
timeout tokens. Selected batches reach Ark admission *after* their deadlines, and native send→copy
intervals overlap four-batch capacity waits by 17.8–36.5 s (88–93%). The second 3 456-record trace
stays PARTIAL at its 120 s cutoff; its initial history failed after an openChat timeout and a later
ordinary reopen displayed messages. Observer cost and TDLib response-ready timing remain unknown, so
**no further production fix is proposed**. [Runtime](docs/reviews/2026-10-18-main-diagnostic-runtime.md) ·
[build/isolated gates](docs/reviews/2026-10-18-bounded-timeout-diagnostics.md)

**Cleanup.** Thirty old Telegram HAPs permanently deleted under explicit authorization after exact
path/size/SHA-256 checks (1 508 061 896 bytes); all ten retained HAPs hash-verified.

## Carried forward — 2026-10-15

Scoped receive/privacy corrections are accepted locally: candidate12 host 95/95 plus static checks,
both official SDK builds inherited from source11, isolated native-postfull-v3 pair install, final
native focus 19/19 and full 1208/1208. Native/ArkTS credits cover active parsing; uncertain delivery
is never replayed. Photo observation remains PARTIAL despite a separate Hypium PASS; the older
unlogged keyboard mismatch and Slowmode title-wait cause remain UNCLASSIFIED.
[Report](docs/reviews/2026-10-15-receive-stabilization.md)

## What is not proven

Source, host and compile checks do not substitute for device, SDK, delivery or visual acceptance.
The unresolved boundary on main is *why consumer progress is too slow*: requested pacing, synchronous
parse/dispatch/store/listener/render work, scheduler contention and synchronous logging are not
partitioned, and TDLib response-ready timing is unobserved. Capacity being full is a symptom, not a
diagnosis; deadlines and memory bounds must not be relaxed to hide an admitted-wait timeout.

The iOS reference was refreshed on 2026-10-18 (`master` @ `f1dd7a2`, 31 572 commits). All 82 source
paths cited from these docs still resolve, but **59 of the 82 files changed upstream**, so their
line-number citations are unverified until re-read. See the refresh log in `REFERENCES.md`.

## Project facts

- **Branch:** `dev` is canonical, tracks `origin/dev`. `main` untouched; dev→main decision deferred.
- **Phase:** production quality against the iOS reference (user mandate 2026-08-31; v0.1.0 tag as a
  goal withdrawn).
- **Tests:** 52+ unit/integration files under `entry/src/ohosTest/ets/test/`; 96 host behavioural
  suites in `scripts/`, run by `node scripts/run-host-tests.cjs` — **Node ≥ 24 required**.
- **Architecture:** solo mode, no `presentation/viewmodels/`; chat-page controllers centralized.

## Key documents

| Document | Purpose |
|---|---|
| `TASKS/TODO.md` | Active checkpoint and open gates |
| `TASKS/LESSONS.md` | Numbered lessons (83–163 plus dated blocks) |
| `docs/reviews/INDEX.md` | All review reports, newest first |
| `REFERENCES.md` | External reference registry and pins |
| `ARCHITECTURE.md`, `DECISIONS.md` | Structure and recorded decisions |
| `AGENTS.md`, `CLAUDE.md` | Instructions for AI assistants |
