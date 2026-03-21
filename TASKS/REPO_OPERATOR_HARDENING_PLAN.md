# REPO OPERATOR HARDENING PLAN — 2026-03-21

## Purpose
Make this repo easier and safer for high-autonomy agent work **without** a large refactor.

This plan is intentionally narrow:
- improve patch boundaries,
- improve repeatable diagnostics,
- reduce blind UI/runtime fixes,
- keep docs aligned with the real working tree.

## Current diagnosis
- The working tree is still broad and noisy, so patch ownership is easy to blur.
- Runtime/UI bugs often require **HiLog + screenshot evidence**, but the repo did not have one obvious repeatable log-capture entrypoint.
- The existing `TASKS/CURRENT_PATCHSET_BOUNDARY.md` was useful, but it lagged behind the current reply/auth/UI audit batch.
- Operators can move fast here, but verification becomes slower when boundary + diagnostics are not explicit.

## Order of execution

### 1. Refresh the live patchset boundary
**Why first:** this reduces accidental scope creep immediately.

Concrete outcome:
- `TASKS/CURRENT_PATCHSET_BOUNDARY.md` reflects the **current** active batch, not the older March 8 stabilization snapshot only.

### 2. Add a repeatable HiLog capture helper
**Why second:** most difficult regressions here are runtime/device-visible.

Concrete outcome:
- one PowerShell helper for filtered `hdc shell hilog` capture;
- easy presets for auth / reply / media / runtime investigations;
- optional reset + file output support.

### 3. Document the operator-facing diagnostics workflow
**Why third:** the repo should make the correct debugging path obvious.

Concrete outcome:
- a short, local doc that says:
  - which tags matter,
  - which script to run,
  - how to capture evidence for common bug families.

### 4. Keep the memory pack in sync after each meaningful batch
**Why fourth:** stale root docs create the next round of confusion.

Concrete outcome:
- `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` updated whenever a meaningful operator-quality improvement lands.

## Done in this pass
- [x] Plan written
- [x] Patchset boundary refreshed
- [x] HiLog helper script added
- [x] Root memory pack synced

## Not in scope for this pass
- large architecture cleanup
- broad V1/V2 migration work
- removing legacy UI
- replacing all ad-hoc logging with a new centralized logging framework

## Next recommended follow-up
If this light hardening proves useful, the next low-cost operator improvement should be:
- add one short `diagnostics` section to `README.md` or a dedicated `DEBUG_FLAGS.md`
- then optionally add one more helper script for the most common device-verification flows
  (`reply`, `auth`, `media`).
