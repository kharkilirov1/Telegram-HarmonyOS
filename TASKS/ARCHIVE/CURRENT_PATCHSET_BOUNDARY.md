# CURRENT PATCHSET BOUNDARY — active snapshot

Last updated: 2026-07-02

## Baseline

- Last committed baseline: `eb1fac1 fix: throttle startup media auto-downloads`
- Current follow-up patch: Release Track v2 docs pivot (this snapshot's commit).

## Current follow-up patch scope

### Docs / plan
- `TASKS/AGENT_EXECUTION_PLAN.md` — rewritten as Release Track v2 (R0 → R1 → R2 → R3+; MVP-чеклист как гейт R1)
- `TASKS/ARCHIVE/AGENT_EXECUTION_PLAN_2026-05-18.md` — archived previous phase-based plan
- `STATUS.md` — R0 state, direction line, working-tree snapshot
- `TASKS/TODO.md` — active phase R0, R1 backlog, history sections
- `TASKS/LESSONS.md` — lessons 54 (timer/AppFreeze doc contracts) and 55 (release track pivot)
- `.gitignore` — `hs_err_pid*.log`, `.cpl/`
- `TASKS/CURRENT_PATCHSET_BOUNDARY.md` — this snapshot

## Out of scope for this follow-up

- Any code changes
- Emulator MVP-checklist run (needs a running emulator target)
- Signing/deployment (R2)
- Any destructive git history rewrite or amend

## Verification completed

- `scripts/smoke-build.ps1` — BUILD SUCCESSFUL (2026-07-02, with throttling patch in tree)
- `scripts/smoke-ui-phase0.ps1` — passed (2026-07-02)
- `hdc list targets` — `[Empty]` (2026-07-02): emulator not running; MVP-checklist run pending a live target

Observed warnings only:
- `libtdlib_napi.so` is not verified by current SDK smoke boundary
- no signing config is configured for HAP signing (planned for R2)
