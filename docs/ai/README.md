# docs/ai — archive (frozen)

This directory is a **historical snapshot** of plans, comparisons and design notes from earlier
phases of the project. It is intentionally **not maintained**.

- Do not execute the roadmaps in this directory.
- Do not update its claims when code changes; a correction is a new dated report in
  [`docs/reviews/`](../reviews/INDEX.md).
- References from `docs/ai/*` to code paths, line numbers or build artifacts may be stale by design.

One exception, scoped by `DECISIONS.md` D25: [`MASTER_PLAN_TELEGRAM_UI.md`](MASTER_PLAN_TELEGRAM_UI.md)
remains the frozen **`tg_ui` visual contract** — visual decisions must not contradict it, but it does
not govern roadmap, process or release rules.

Active sources live one level up: [`STATUS.md`](../../STATUS.md),
[`TASKS/TODO.md`](../../TASKS/TODO.md), [`TASKS/AGENT_EXECUTION_PLAN.md`](../../TASKS/AGENT_EXECUTION_PLAN.md),
[`TASKS/PRODUCTION_PARITY_PLAN.md`](../../TASKS/PRODUCTION_PARITY_PLAN.md), [`DECISIONS.md`](../../DECISIONS.md).

`AI_MEMORY.md`, `UI_MIGRATION_PLAN.md` and `VISUAL_QA_CHECKLIST.md` are still checked for existence by
CI (`.github/workflows/smoke.yml`, `smoke-static`) because earlier instructions linked to them. They
are archive files; the CI check only guards against deleting them silently.
