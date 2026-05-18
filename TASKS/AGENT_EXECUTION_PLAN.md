# AGENT EXECUTION PLAN — Telegram-HarmonyOS

Last updated: 2026-04-24

## Purpose
This is the **canonical execution roadmap** for AI agents working on this repository.

If the user says:
- `иди по плану`
- `go by the plan`
- `continue roadmap`
- `продолжай по роадмапу`

interpret that as:

> Read this file and execute the **current phase** in order.

---

## Mandatory preflight

Before executing any phase:
1. Read `AGENTS.md`
2. Read `STATUS.md`
3. Read `DECISIONS.md`
4. Read `ARCHITECTURE.md`
5. Read `TASKS/TODO.md`
6. Read `TASKS/LESSONS.md`
7. For HarmonyOS-specific decisions, query `harmonyos_docs`
8. Inspect relevant local references under `рефенсы/`

Reference priority:
1. `harmonyos_docs` + `рефенсы/HarmonyOSComponentUXExamples`
2. `рефенсы/Telegram-iOS-master`
3. `рефенсы/telegram-android`

Global execution rules:
- Work **phase-by-phase**, not randomly.
- Do not skip verification.
- Do not jump to later phases while the current phase is still unstable.
- Keep changes minimal and architecture-aware.
- Update `STATUS.md`, `TASKS/TODO.md`, and `TASKS/LESSONS.md` after meaningful progress.
- Prepare commit-ready work, but **do not commit/push unless the user explicitly asks**.

UI analysis method for non-trivial porting:
1. **Reference decomposition** — break the iOS source into structural layers, primitives, states, layout rules, and visual decisions.
2. **Platform mapping** — only then choose HarmonyOS/ArkUI equivalents or acceptable analogs.
3. **Assembly** — decide what becomes shared background, atom, molecule, or screen-owned coordination in this repo.

Do **not** start from “which ArkUI component looks similar”. Start from “what problem/decision does the iOS composition solve”.

---

## Status note (2026-03-22)
- Per user confirmation on 2026-03-22, the previously outstanding emulator/device/runtime verification checklists for the current branch should be treated as **passed** unless a new regression is observed.
- Do not reopen old verification work by default just because historical docs still contain old checklists; use `STATUS.md` + `TASKS/TODO.md` current housekeeping items first.

## Strategic UI note (2026-03-22)
- The repo has now accepted a strategic split:
  - keep custom effort on **Telegram semantics**,
  - prefer **Harmony-native or hybrid shell/chrome** where platform quality is already strong enough.
- Do not spend large effort manually polishing shell chrome just to mimic iOS if the platform already offers a strong native direction.
- For future execution:
  1. protect Telegram-defining surfaces (`TgChatRow`, message atoms, composer semantics, meta/badge/status logic),
  2. evaluate shell containers (historical custom `TgTabBar`, upper chrome hosts, search hosts) as native/hybrid candidates first,
  3. keep API 22 fallbacks while the repo target remains API 22 and API 23 remains a beta/staging direction.

## Current default starting phase

**Current active phase: Phase 2 — Consolidate current working batch.**

Phase 1 is locally exited for heartbeat purposes as of 2026-04-30: repeated runtime/navigation audit passes have landed, `scripts/smoke-ui-phase0.ps1` is green, and the remaining `scripts/smoke-build.ps1` failure is the known external user-level Hvigor cache `ENOENT` blocker. That build blocker must be reported, but it is **not** by itself a reason to keep mining Phase 1.

Only return to Phase 1 when a concrete, unaddressed runtime/navigation regression is named or reproduced. Otherwise the next heartbeat run should execute Phase 2 consolidation work.

Phases 1, 2, and 5 do NOT require manual device/emulator verification — they are code audits, refactors, new atoms, and behavior implementation.

**Do NOT loop in observation-only mode. If one task is truly blocked, move to the next unblocked task in the current phase.**

## Forward runtime-sweep note (2026-04-19)
- The forward/cross-chat runtime-sweep packet is now locally well-covered:
  - checklist
  - results template
  - generator
  - reader
  - validator
  - wrapper
  - PASS/FAIL synthetic fixtures
  - baseline smoke
- Do **not** keep expanding this packet by default.
- After the current baseline is green, the next valid move is one of:
  1. a real emulator/device runtime-sweep artifact,
  2. a concrete smoke regression,
  3. a narrow tooling/documentation gap discovered from a real artifact.
- If none of those are true, prefer stopping over adding another helper script.

## Heartbeat tooling note (2026-04-20)
- The heartbeat inspection path is now locally well-covered:
  - latest/latest-completed distinction
  - freshness
  - output-artifact freshness
  - top-level issue markers
  - `-SummaryOnly`
  - `-HealthExitCode`
- Do **not** keep expanding heartbeat helper flags by default.
- 2026-04-24 real-log update: a completed heartbeat with `exit code 1` caused by Codex websocket/DNS errors is now classified as `network/connectivity failure` by `scripts/read-codex-heartbeat.ps1`, with `scripts/smoke-read-codex-heartbeat-network-failure.ps1` covering the fixture.
- Do not open runner-code or scheduler surgery for an isolated classified network/connectivity failure; wait for the next completed run and only act if completed-path failures repeat without that external-failure marker.
- After the current baseline is green enough for routine checks, the next valid move is one of:
  1. a real scheduled-task regression,
  2. a reproducible heartbeat-runner bug,
  3. a narrow observability gap discovered from real heartbeat logs.
- If none of those are true, prefer re-checking or stopping over adding another heartbeat helper mode.

---

## Phase 1 — Runtime stabilization

### Goal
Make the current chat/runtime path predictable, reload-safe, and verification-ready.

### Primary files
- `entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets`
- `entry/src/main/ets/core/store/AppStore.ets`
- `entry/src/main/ets/domain/usecases/loadChats.ets`
- `entry/src/main/ets/domain/usecases/loadChatHistory.ets`
- `entry/src/main/ets/domain/usecases/openChat.ets`
- `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`

### What to do (NO DEVICE NEEDED — pure code work)
1. Audit in-flight request handling: check `AppStore`, usecases for duplicate/missed TDLib requests
2. Audit static cache reset behavior: verify `LoadChatHistoryUseCase`, `LoadChatsUseCase`, and any other static caches are reset on runtime shutdown
3. Audit reopen/back/navigation race conditions: check `TgChatScreenPage`, `ChatListPage` for stale state on re-entry
4. Audit unread-boundary/history restore behavior
5. Audit pagination older/newer logic
6. Audit `MainThreadDispatcher` for dropped/duplicate events
7. Fix found issues — crash guards, null checks, race condition fixes, cache resets
8. Add dev-mode invariant checks for detected issues

### Verification target
- `scripts/smoke-ui-phase0.ps1` passes
- `scripts/smoke-build.ps1` passes (or report exact blocker)
- No obvious reopen/load regressions in code inspection

### Exit condition
Runtime path is audited, fixed, and stabilized. All found issues have fixes or documented follow-ups.

---

## Phase 2 — Consolidate current working batch

### Goal
Turn the current mixed working tree into a coherent, reviewable, commit-ready batch.

### What to do (NO DEVICE NEEDED)
1. Audit current untracked tg_ui atoms/specs/demos — list them, check for missing spec/demo coverage
2. Align docs (`STATUS.md`, `ARCHITECTURE.md`, `README.md`) with actual runtime path
3. Review tg_ui tokens for consistency — remove unused, add missing
4. Clean up dead code and commented-out experiments
5. Ensure every atom has: spec, demo, and is referenced in inventory
6. Decide patchset boundary: what belongs to current stabilization batch vs later feature work

### Important constraint
- local commit/push only if the user explicitly asks

### Exit condition
There is a cleanly described patchset boundary for the current stabilization work.

---

## Phase 3 — Full verification gate

### Goal
Prove that the current integrated state is not only “plausible” but actually verifiable.

### What to do
- run shell smoke checks
- run best available HarmonyOS build verification
- record exact pass/fail status and blockers

### Exit condition
- verification succeeded, or
- verification is blocked by a clearly identified environment/tooling issue

No new major feature work should start before this gate is attempted.

---

## Phase 4 — Real Calls implementation

### Goal
Replace the current calls placeholder/empty-state path with real application behavior.

### What to do
- inspect TDLib/domain support for calls/call history
- add or extend model/store/usecase coverage as needed
- connect real page data to `TgCallRow`
- keep design aligned with tg_ui and Telegram references

### Exit condition
Calls page is backed by real data flow or has a clearly documented backend limitation.

---

## Phase 5 — Media behavior completion

### Goal
Complete runtime behavior for media messages beyond visual atoms.

### What to do (MOSTLY NO DEVICE NEEDED)
1. Implement attachment open/download flow: TDLib `downloadFile` → progress → open
2. Add progress/error/retry state handling for media downloads
3. Implement image viewer open from message bubble
4. Implement voice message playback behavior (play/pause/progress)
5. Connect media atoms to real TDLib data flow (not just visual rendering)
6. Add media-specific usecases if missing
7. Wire media events into AppStore reducers

### Exit condition
Media messages are not just rendered; they behave like product features.

---

## Phase 6 — V1 to V2 modernization

### Goal
Do a post-migration performance/architecture pass only after the app is stable enough.

### Why this is late
Official HarmonyOS docs indicate:
- `Repeat` is the modern path for V2 state-management flows
- `@ReusableV2` works with `@ComponentV2` reuse patterns

### What to do
- evaluate whether the current `LazyForEach` + `.reuseId(...)` chat-list path is sufficient
- only then evaluate `LazyForEach -> Repeat`
- only then evaluate whether explicit `@ReusableV2` adoption is worth the churn

### Exit condition
The post-migration modernization is done as a controlled architectural/performance step, not as a speculative refactor during stable product work.

---

## Agent reporting format after each phase/batch

Always report:
1. what changed
2. which files changed
3. how it was verified
4. what remains
5. which phase is next

If blocked, state:
- exact blocker
- why it blocks the current phase
- the safest next action
