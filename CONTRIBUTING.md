# Contributing Guide

## Scope
This project is moving away from "god files" (large files with mixed responsibilities).  
All new contributions must keep files small, focused, and easy to review.

## File Size Limits
- UI pages/components (`entry/src/main/ets/pages`, `entry/src/main/ets/components`): max `350` lines.
- Controllers/services (`entry/src/main/ets/controllers`, `entry/src/main/ets/services`): max `500` lines.
- Other ETS source files: max `450` lines unless justified.

## Single Responsibility Rule
- One file should have one primary responsibility.
- Separate parsing/mapping/state transitions from orchestration and UI.
- Keep side-effects isolated from pure state logic.

## CI Guardrail for Giant Files
CI runs `scripts/ci/check_giant_files.sh` on each PR and push:
- blocks new files above limits;
- blocks files that cross limits in a change;
- blocks large growth in existing giant files (`>30` lines growth in one change).

## Temporary Exceptions
Use `.github/giant-files.allowlist` only for legacy files and only with:
- a short reason;
- a target PR/issue where decomposition will happen.

Additions to allowlist without a decomposition plan should be rejected.

## Pull Requests
Every PR must include:
- decomposition impact (if any);
- why a file had to grow (if it did);
- follow-up plan when touching allowlisted files.
