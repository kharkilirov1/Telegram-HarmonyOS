# TODO — Telegram-HarmonyOS

Last updated: 2026-05-18

Canonical execution order: `TASKS/AGENT_EXECUTION_PLAN.md`

## Active Phase: Phase 5 — Media behavior completion

### Phase 4 completed this session (2026-05-18)
- [x] Inspected current Calls real-data path (`CallsPage`, `LoadCallsUseCase`, `TgCallRow`) and Telegram references
- [x] Verified TDLib source contract in local `td_api.tl`: `searchCallMessages(offset, limit, only_missed) -> FoundMessages.next_offset`
- [x] Fixed `SearchCallMessagesPayload` / `CommandSerializer` to use opaque `offset:string` instead of chat-history-style `_from_message_id_json`
- [x] Fixed `LoadCallsUseCase` and `CallsPage` pagination state to consume `next_offset`
- [x] Added `CommandSerializer.test.ets` coverage for `searchCallMessages`
- [x] Expanded `LoadCalls.test.ets` to cover foundMessages parsing, missed/outgoing mapping, pagination, and direct `chat`/`user` hydration
- [x] Build: `scripts/smoke-build.ps1` — BUILD SUCCESSFUL on last run
- [x] Smoke: `scripts/smoke-ui-phase0.ps1` + `.sh` — passed on last run

### Phase 2 completed this session (2026-05-18)
- [x] `TdGateway.ets`: replaced `getMethodTimeout()` if/else chain with `Record<string, number>` Map
- [x] Removed 15+ noise files (heartbeat/runtime-sweep scripts, index.html, etc.)
- [x] Trimmed docs: STATUS.md (1220→compact), TODO.md (428KB→compact), LESSONS.md (527→compact)
- [x] Staged/committed valuable files from the broad batch (tests, specs, demos, sendMediaMessage, forward/, TgComposerEmojiPanel)
- [x] Added `TdGateway.test.ets` (timeout mapping, state machine, send validation, subscribeUpdates)
- [x] Added `EventNormalizer.test.ets` (handler dispatch, stats, unknown types, singleton)
- [x] Added `ChatMediaDownloadController.ets` — extracted from TgChatScreenPage
- [x] Fixed `ChatMediaDownloadController.ets` direct TDLib response parsing to use `TdObject` accessors instead of treating responses as plain records
- [x] Extracted `ChatComposerController.ets` from `TgChatScreenPage.ets` (composer send flow, emoji panel, attachment picker, picked-file local copy)
- [x] Extracted `ChatMessageActionsController.ets` from `TgChatScreenPage.ets` (reply/edit/copy/forward/pin/delete menu, forward target flow, action-mode state)
- [x] Added `ChatScreenRouteParams.ets` so chat route params are shared outside the page file
- [x] Refactored `CommandSerializer.ets` from one large `switch` into command-type dispatch handlers
- [x] Extracted `ChatSearchController.ets` from `TgChatScreenPage.ets` (debounced search + first-result navigation)
- [x] Added `CommandSerializer.test.ets` coverage for dispatch handlers and raw nested JSON expansion
- [x] Added `UseCases.test.ets` coverage for send/media/edit/delete/forward validation and dispatch
- [x] Added `AuthSideEffect.test.ets` basic singleton/store seam coverage without native TDLib startup
- [x] Selector memoization: `selectOrderedChats`, `selectPinnedChats`, `selectUnpinnedChats`, `selectTotalUnreadCount`
- [x] Cleaned stale docs/spec references to removed standalone atoms (`TgUnreadBadge`, `TgMessageTextBodyV2`, custom `TgTabBar` shell)
- [x] Normalized `chatSelectors.ets` line endings / `git diff --check` hygiene
- [x] `TASKS/CURRENT_PATCHSET_BOUNDARY.md` aligned with the actual current follow-up patch and verification boundary
- [x] Build: `scripts/smoke-build.ps1` — BUILD SUCCESSFUL on last run
- [x] Smoke: `scripts/smoke-ui-phase0.ps1` + `.sh` — passed on last run

### Phase 2 remaining work
- [x] Current review-fix/decomposition/tests follow-up patch committed locally

### Phase 5 next candidates
- [ ] Media behavior completion: review remaining photo/video/document/voice playback/download gaps against `TASKS/AGENT_EXECUTION_PLAN.md`
- [ ] Decide next narrow media slice after inspecting current `TgMessageRouter` and active bubble controllers

### Technical debt (Phase 3+)
- [ ] Deeper integration tests for `AuthSideEffect` ready/warmup flow once TDLib/app-context test seam exists
- [x] `services/` legacy cleanup check: only `ConfigLocal.ets` + example remain; no removable legacy service layer found
- [x] Evaluated `LazyForEach` → `Repeat` / `@ReusableV2`: current live usages are `ChatListPage` and `TgChatScreenPage` with `reuseId`; keep as-is until a measured perf phase/device target exists
- [ ] Signed device/emulator runtime verification — blocked locally: `hdc list targets` returned `[Empty]` and `build-profile.json5` has empty `signingConfigs`

### Known blockers
- Missing signing config for HarmonyOS device/emulator deployment; no connected hdc target detected in this pass
- `libtdlib_napi.so` — external build, not verified in current CI/smoke boundary
- CodeRabbit CLI is not usable from native Windows Git Bash installer (`Unsupported operating system: mingw64_nt-*`); use WSL/Linux/macOS or another review path if CodeRabbit is required
