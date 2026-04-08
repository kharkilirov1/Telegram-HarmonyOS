# DECISIONS — Telegram-HarmonyOS

Last updated: 2026-03-22

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

## D7. Current UI split is V2-first with selective stock ArkUI simplification
- **Decision:** Treat the active shell/chat runtime as largely `@ComponentV2`, while still using stock ArkUI components directly when a thin wrapper adds no product value.
- **Why:** The migration is effectively complete in the live UI code, and the current priority is post-V2 stability/parity rather than preserving older V1 assumptions.
- **Consequence:** Do not reintroduce V1-only mental models (for example “`TgChatRow` is still a V1 `@Reusable` exception”). Post-migration work should focus on parity cleanup and only later evaluate `Repeat` / `@ReusableV2` as a separate optimization phase.

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

## D11. Decompose iOS reference first, map to Harmony second, assemble third
- **Decision:** Non-trivial UI porting work must follow `Reference Decomposition -> Platform Mapping -> Assembly`, not “pick an ArkUI widget first”.
- **Why:** Telegram iOS upper chrome and similar areas are composed from layered background/effect surfaces, independent title/action geometry, and stateful content contracts. Jumping straight to a HarmonyOS control choice loses the product decisions that actually need to be preserved.
- **Consequence:** For each major UI zone, extract: structural layers, content/state model, layout invariants, visual decisions, and behavior from the iOS reference first. Only after that choose HarmonyOS equivalents/analogs and decide how the repo should assemble them.

## D12. Upper chrome architecture is layered and V2-composed
- **Decision:** The target architecture for the Telegram upper chrome is `shared top background primitive -> V2 composition component -> screen-owned derived state`, not one monolithic top-bar widget.
- **Why:** Local iOS refs show that the top area is built from a shared blur/effect surface, top-edge emphasis, independent left/center/right geometry, and optional secondary lanes such as search/accessory panels.
- **Consequence:** `TgChatListNavigationBar` and `TgChatTopBar` should be treated as content compositions. Shared blur/tint/edge-emphasis belongs in a reusable upper-background primitive, and title/subtitle modes should be derived outside the visual atom and passed in via V2 params.

## D13. Preserve Telegram semantics, but prefer Harmony-native shell/chrome when platform quality is sufficient
- **Decision:** The project should concentrate custom work on Telegram-specific semantics and hierarchy, while shell/chrome surfaces that are not strong Telegram invariants should increasingly move toward Harmony-native or hybrid implementations when platform quality is good enough.
- **Why:** Recent API 23 beta visual direction and repeated video evidence suggest that HarmonyOS shell chrome is becoming much closer to the desired glass/island/navigation language. Continuing to hand-build every shell surface is likely a poor use of time compared with preserving Telegram-specific UX semantics.
- **Consequence:** Keep custom effort focused on `TgChatRow`, message atoms, composer semantics, badges/meta/status, and other Telegram-defining surfaces. Treat tab bars, top chrome hosts, search hosts, and similar shell containers as candidates for platform-native or hybrid paths, while retaining API 22-compatible fallbacks until API 23 is stable and adopted by the repo.
