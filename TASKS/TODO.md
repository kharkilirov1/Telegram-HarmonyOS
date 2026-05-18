# TODO — Telegram-HarmonyOS

Last updated: 2026-05-18

Canonical execution order: `TASKS/AGENT_EXECUTION_PLAN.md`

## Active Phase: Phase 2 — Consolidate current working batch

### Phase 2 completed this session (2026-05-18)
- [x] `TdGateway.ets`: replaced `getMethodTimeout()` if/else chain with `Record<string, number>` Map
- [x] Removed 15+ noise files (heartbeat/runtime-sweep scripts, index.html, etc.)
- [x] Trimmed docs: STATUS.md (1220→80 lines), TODO.md (428KB→compact), LESSONS.md (527→43 entries)
- [x] Staged 27 untracked valuable files (10 tests, 5 specs, 5 demos, sendMediaMessage, forward/, TgComposerEmojiPanel)
- [x] Added `TdGateway.test.ets` (timeout mapping, state machine, send validation, subscribeUpdates)
- [x] Added `EventNormalizer.test.ets` (handler dispatch, stats, unknown types, singleton)
- [x] Added `ChatMediaDownloadController.ets` — extracted from TgChatScreenPage (155 lines, -111 from page)
- [x] Selector memoization: `selectOrderedChats`, `selectPinnedChats`, `selectUnpinnedChats`, `selectTotalUnreadCount`
- [x] Build: `scripts/smoke-build.ps1` — BUILD SUCCESSFUL
- [x] Smoke: `scripts/smoke-ui-phase0.ps1` + `.sh` — passed

### Phase 2 remaining work
- [ ] Decompose `TgChatScreenPage.ets` further (2983 → target ~2500 lines):
  - `ChatComposerController` — composer state, emoji panel, attachment picker (~200 lines, high coupling to @Local)
  - `ChatMessageActions` — delete, forward, edit, reply, pin (~150 lines, high coupling to @Local)
- [ ] Decompose `CommandSerializer.ets` (dispatch pattern instead of manual per-type serialization)
- [ ] Define patchset boundary (see `TASKS/CURRENT_PATCHSET_BOUNDARY.md`)

### Technical debt (Phase 3+)
- [ ] Tests: `AuthSideEffect`, use cases (0 coverage)
- [ ] Migrate `services/` legacy to Clean Architecture layers
- [ ] Evaluate `LazyForEach` → `Repeat` migration (Phase 6)

### Known blockers
- `hvigorw` not in PATH (resolved: scripts use full DevEco path)
- Missing signing config for HarmonyOS device/emulator deployment
- `libtdlib_napi.so` — external build, not verified in CI
