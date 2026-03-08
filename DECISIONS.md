# DECISIONS — Telegram-HarmonyOS

Last updated: 2026-03-07

This file records decisions that are already effectively accepted in the repo.

## D1. Keep the core runtime architecture stable
- **Decision:** Keep `TDLib -> dispatcher -> normalizer -> AppStore -> UI` as the backbone.
- **Why:** The main active work is UI/product quality and runtime stabilization, not a platform rewrite.
- **Consequence:** UI refactors should not casually rewrite reducers, gateway contracts, or store ownership.

## D2. Use Telegram iOS as the visual source of truth
- **Decision:** UI porting is anchored to the project-local reference set under `рефенсы/`, with Telegram iOS as the primary visual source.
- **Why:** The goal is high-fidelity Telegram feel, not a generic HarmonyOS messenger.
- **Consequence:** Non-trivial UI work starts from local reference inspection (`Telegram-iOS-master`, then other refs as needed), then spec, then atom/demo/integration.

## D3. `docs/ai/MASTER_PLAN_TELEGRAM_UI.md` is the frozen UI contract
- **Decision:** Master plan wins if smaller docs disagree.
- **Why:** It prevents drift between agent sessions.
- **Consequence:** `UI_MIGRATION_PLAN.md`, `AI_MEMORY.md`, or ad-hoc notes are secondary.

## D4. Migrate UI atom-first, not screen-first
- **Decision:** Required flow is `SPEC -> DEMO -> ATOM -> INTEGRATION`.
- **Why:** This reduces visual drift and catches state/geometry issues early.
- **Consequence:** Every reusable visual piece should have a passport and demo coverage before large integrations.

## D5. Keep legacy and `tg_ui` paths in parallel until acceptance gates pass
- **Decision:** Do not delete older UI just because a new atom exists.
- **Why:** The project is still in active migration and the working tree is often dirty.
- **Consequence:** Prefer feature flags or narrow swaps; delete legacy only after demo/spec/integration parity is proven.

## D6. Token-first design system
- **Decision:** Colors, spacing, radius, typography, and geometry belong in `TgUiTokens.ets` / resources, not inline magic numbers.
- **Why:** Token drift already caused inconsistencies in earlier shell/chatlist passes.
- **Consequence:** When a value repeats or represents design intent, promote it to tokens/resources.

## D7. Current UI split is intentional: V1 shell pages + V2 tg_ui components
- **Decision:** Keep shell pages mostly V1 for now, while tg_ui atoms/molecules use V2 where practical.
- **Why:** The existing app shell and list integrations are already wired this way.
- **Consequence:** `TgChatRow` stays a V1 `@Reusable` exception until its parent tree is migrated.

## D8. Use AppStore as domain truth and AppStorage as UI bridge
- **Decision:** Domain state lives in `AppStore`; UI-facing mirrored state lives in `AppStorage` via `AppStoreBridge`.
- **Why:** It keeps reducers/selectors predictable while still fitting ArkUI page binding patterns.
- **Consequence:** UI should not invent a second source of truth outside the bridge/store contract.

## D9. Secrets stay local-only
- **Decision:** Telegram API credentials live in gitignored `ConfigLocal.ets`.
- **Why:** Credentials were previously risky as hardcoded constants.
- **Consequence:** Setup docs and onboarding must always mention local config + TDLib prebuilts.

## D10. Runtime reset must clear cached use-case state
- **Decision:** `LoadChatHistoryUseCase` and `LoadChatsUseCase` static caches are reset during runtime shutdown.
- **Why:** Without reset, reopened runtimes can keep stale “already fetched / in-flight” state.
- **Consequence:** Any future static cache added to runtime flows must define reset semantics too.
