# CURRENT PATCHSET BOUNDARY — 2026-03-08

## Purpose
Freeze a reviewable boundary for the current working tree now that the log-driven runtime stabilization pass is materially successful.

## Phase status
- **Phase 1 — Runtime stabilization:** exit condition is effectively met from current local evidence.
- **Phase 2 — Consolidate current working batch:** active now.

## Included in the current stabilization batch

### A. Runtime/core stabilization
Primary scope:
- `entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets`
- `entry/src/main/ets/core/store/AppStore.ets`
- `entry/src/main/ets/domain/usecases/loadChats.ets`
- `entry/src/main/ets/domain/usecases/loadChatHistory.ets`
- `entry/src/main/ets/domain/usecases/openChat.ets`
- `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- related reducer / normalizer / TD wrapper fixes that were required to make those flows truthful

This slice now covers:
- runtime reset / static cache reset
- guarded chat reopen flow
- stable `LazyForEach` keys
- restore-scroll pagination guards
- edge re-entry pagination latches
- history sender hydration widening
- direct TDLib `user.id` top-level parsing fix

### B. tg_ui support artifacts already part of the current runtime path
These files belong to the same review batch because the current shell/chat path already depends on them or claims them in docs:
- `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets`
- `entry/src/main/ets/ui/tg_ui/spec/TgCallRow.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgChatTopBar.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgSearchBar.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgSettingsRow.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgTabBar.md`
- `entry/src/main/ets/ui/tg_ui/demos/TgCallRowDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgChatTopBarDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgMessageBubbleBaseDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgMessageRouterDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgSearchBarDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgSettingsRowDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgTabBarDemo.ets`

### C. Documentation / smoke sync
Also included in the current batch:
- root memory pack (`STATUS.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `TASKS/*`)
- `README.md`
- `docs/ai/AI_MEMORY.md`
- `docs/ai/UI_MIGRATION_PLAN.md`
- `scripts/smoke-ui-phase0.ps1`
- `scripts/smoke-ui-phase0.sh`
- `.github/workflows/smoke.yml`

## Explicitly not included in this batch
These stay for later phases even if the working tree already contains related groundwork:
- **Phase 4:** real Calls data flow
- **Phase 5:** media behavior completion beyond current rendering/runtime fixes
- **Phase 6:** V1 -> V2 modernization / `LazyForEach -> Repeat` / `@ReusableV2`
- any destructive cleanup of legacy fallback paths

### Historical cleanup note (2026-03-22)
- The runtime no longer depends on `TgContactRow` / `TgSettingsSection`, and their orphaned demo/spec artifacts were deleted after verification/doc sync.

## Verification snapshot for this boundary
- `./scripts/smoke-ui-phase0.ps1` — pass
- `bash ./scripts/smoke-ui-phase0.sh` — pass
- `./scripts/smoke-build.ps1` — pass (via discovered DevEco wrapper at `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`)
- Latest confirming HiLog:
  - `HiLog-Mate 80 Pro-All logs of selected app-[27274]com.telegram.harmonyos-DEBUG-1772921231953.txt`
- Latest verified runtime outcomes from that log:
  - `Message references non-existent user` = `0`
  - `lastMessage is older than newest message in map` = `0`
  - `Loading older messages` = `0`
  - `Loading newer messages` = `0`
- Remaining verification blocker:
  - no longer local build-tool discovery; the next real gap for later work is device/runtime verification of newer post-boundary phases such as Calls

## Recommended commit-ready grouping
If/when the user asks to commit, keep the boundary understandable:
1. runtime stabilization core
2. tg_ui support artifacts already used by the active runtime path
3. docs + smoke sync

Do **not** mix future Calls/media/V2-modernization work into this batch.
