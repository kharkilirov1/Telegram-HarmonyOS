# AI Handoff Template

Use this template when handing work to another AI agent.

## Project
- Path: `C:\Users\Kharki\Desktop\Telegram-HarmonyOS`
- Branch: `refactor/appcore-reset`

## Read first
1. `docs/ai/AI_MEMORY.md`
2. `docs/ai/UI_MIGRATION_PLAN.md`
3. `README.md`

## Current task
<describe exact phase/block from UI_MIGRATION_PLAN.md>

## Constraints
- Do not rewrite domain/core logic unless explicitly requested.
- Preserve auth flow behavior.
- Reuse tokens and shared UI components.
- Keep changes incremental and reviewable.

## iOS reference inputs
- Root: `C:\Users\Kharki\Downloads\референсы\Telegram-iOS-master\Telegram-iOS-master`
- Exact files used:
  - <file1>
  - <file2>

## Expected output
- Files changed:
  - <path>
  - <path>
- Acceptance criteria:
  - <criterion 1>
  - <criterion 2>

## Validation
- Build in DevEco.
- Optional CLI:
  - `hvigorw clean --no-daemon`
  - `hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`

