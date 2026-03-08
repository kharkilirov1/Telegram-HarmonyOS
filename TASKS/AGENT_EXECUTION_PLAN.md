# AGENT EXECUTION PLAN — Telegram-HarmonyOS

Last updated: 2026-03-07

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

---

## Current default starting phase

**Start with Phase 1 unless the repo state clearly shows it is already completed and verified.**

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

### What to do
- audit in-flight request handling
- audit static cache reset behavior
- audit reopen/back/navigation race conditions
- audit unread-boundary/history restore behavior
- audit pagination older/newer logic
- fix duplicate loads, stale state, and obvious navigation regressions

### Verification target
- `scripts/smoke-ui-phase0.ps1` passes
- no obvious reopen/load regressions in inspected flows
- if `hvigorw`/DevEco build is available, build passes
- if build tooling is unavailable, report exact blocker

### Exit condition
Current runtime path is stabilized enough to be treated as a coherent patch instead of a moving pile of local edits.

---

## Phase 2 — Consolidate current working batch

### Goal
Turn the current mixed working tree into a coherent, reviewable, commit-ready batch.

### What to do
- review the current untracked tg_ui atoms/specs/demos
- align docs with actual runtime path
- decide what belongs to the stabilization batch vs. later feature work
- keep git status understandable

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

### What to do
- attachment open/download flows
- progress/error/retry state handling
- image/video interactions
- voice playback behavior
- router/chat-screen integration polish

### Exit condition
Media messages are not just rendered; they behave like product features.

---

## Phase 6 — V1 to V2 modernization

### Goal
Modernize shell/list architecture only after the app is stable enough.

### Why this is late
Official HarmonyOS docs indicate:
- `Repeat` is the modern path for V2 state-management flows
- `@ReusableV2` works only with `@ComponentV2`
- V1 components cannot safely host `@ReusableV2` children

### What to do
- evaluate migration from V1 shell pages to V2
- only then evaluate `LazyForEach -> Repeat`
- only then evaluate `@Reusable -> @ReusableV2`

### Exit condition
Modernization is done as a controlled architectural step, not as a speculative refactor during unstable feature work.

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
