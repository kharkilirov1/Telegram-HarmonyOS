# TODO — Telegram-HarmonyOS

Last updated: 2026-05-18

Canonical execution order: `TASKS/AGENT_EXECUTION_PLAN.md`

## Active Phase: Phase 2 — Consolidate current working batch

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
- [x] Selector memoization: `selectOrderedChats`, `selectPinnedChats`, `selectUnpinnedChats`, `selectTotalUnreadCount`
- [x] Cleaned stale docs/spec references to removed standalone atoms (`TgUnreadBadge`, `TgMessageTextBodyV2`, custom `TgTabBar` shell)
- [x] Normalized `chatSelectors.ets` line endings / `git diff --check` hygiene
- [x] `TASKS/CURRENT_PATCHSET_BOUNDARY.md` aligned with the actual current follow-up patch and verification boundary
- [x] Build: `scripts/smoke-build.ps1` — BUILD SUCCESSFUL on last run
- [x] Smoke: `scripts/smoke-ui-phase0.ps1` + `.sh` — passed on last run

### Phase 2 remaining work
- [ ] Commit/review current uncommitted follow-up patch when requested by user

### Technical debt (Phase 3+)
- [ ] Tests: `AuthSideEffect`, use cases coverage
- [ ] Migrate any remaining `services/` legacy to Clean Architecture layers
- [ ] Evaluate `LazyForEach` → `Repeat` / `@ReusableV2` migration only as a separate performance phase
- [ ] Signed device/emulator runtime verification

### Known blockers
- Missing signing config for HarmonyOS device/emulator deployment
- `libtdlib_napi.so` — external build, not verified in current CI/smoke boundary
- CodeRabbit CLI is not usable from native Windows Git Bash installer (`Unsupported operating system: mingw64_nt-*`); use WSL/Linux/macOS or another review path if CodeRabbit is required
