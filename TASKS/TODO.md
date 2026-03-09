# TODO — observed current work

Last updated: 2026-03-09

This is a **working snapshot**, not a product roadmap. It is derived from:
- current git status on branch `refactor/appcore-reset`
- current repo docs
- current file layout

Canonical execution order for agents now lives in:
- `TASKS/AGENT_EXECUTION_PLAN.md`

## Active now

### 0. Device-verify chat-list blank-cell regression fix
- **Evidence:** local code updates in:
  - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
  - `entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets`
  - `entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets`
  - `entry/src/main/ets/core/reducers/chatsReducer.ets`
  - `entry/src/main/ets/ui/pages/chatlist/ChatItemVO.ets`
- **What changed locally:** restored stable `LazyForEach` identity (`chatId` key + per-chat `reuseId`), removed debug row instrumentation, blocked empty `updateChatTitle` overwrite path, and added phone-number private-title fallback.
- **Current action:** run device HiLog/UI pass to confirm blank/empty chat cells no longer reproduce under fast scroll + initial hydration.

### 1. Stabilize runtime reset and chat loading flows
- **Evidence:** modified files in:
  - `entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets`
  - `entry/src/main/ets/core/store/AppStore.ets`
  - `entry/src/main/ets/domain/usecases/loadChats.ets`
  - `entry/src/main/ets/domain/usecases/loadChatHistory.ets`
  - `entry/src/main/ets/domain/usecases/openChat.ets`
  - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
  - `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- **Likely focus:** avoid stale caches, duplicate in-flight loads, bad reopen behavior, unread/history restore glitches, and list churn from non-persistent `LazyForEach` keys.
- **Latest evidence from 2026-03-08 HiLog:** reopening into `savedIndex = 0` / unread-boundary restore can immediately trigger repeated `loadOlder`/`loadNewer` bursts in `TgChatScreenPage` before any real user scroll.
- **Latest pagination fix from 2026-03-09:** edge latch replaced with `recheckPaginationEdge()` pattern — after each completed load, if viewport is still near edge, auto-triggers next batch (iOS-like continuous loading). Added `lastVisibleEndIndex` for accurate newer-edge detection.
- **Follow-up after the latest 2026-03-08 HiLog pass:** restore-triggered burst and edge-pinned pagination storm are fixed in `TgChatScreenPage`; next runtime verification should confirm the reduced `loadOlder` / `loadNewer` counts stay at zero.
- **Current runtime cleanup focus:** `loadChatHistory` sender hydration cap was widened to cover a full default history page before dispatch; remaining work is to re-check HiLog and see whether any missing-user warnings are true misses vs transient hydration lag.
- **Newest runtime finding from 2026-03-08 HiLog:** the remaining startup/live missing-user warnings correlate with direct `getUser`/`getMe` responses being parsed with the wrong `id` source, not with chat history pagination anymore.
- **Newest patch target completed locally:** user parsing now uses top-level `user.id` extraction instead of generic nested-key regex matching; next device run should confirm that `getMe resolved` becomes sane and repeated `Message references non-existent user` warnings collapse.
- **Latest verification from 2026-03-08 `[27274]` HiLog:** runtime stabilization target is effectively satisfied — missing-user warnings dropped to `0`, stale-lastMessage warnings dropped to `0`, and `loadOlder` / `loadNewer` stayed at `0`.
- **Newest finding from 2026-03-08 `[8081]` HiLog:** a chat open can still get a **tiny but non-zero** default `getChatHistory` batch (`1 events` observed for `ClawdBot`), after which the old `messageCount >= limit` rule incorrectly froze `canLoadOlder=false`.
- **Newest patch completed locally:** `LoadChatHistoryUseCase` now treats TDLib short batches as ambiguous, keeps pagination progress-based, and performs one controlled older top-up for suspiciously tiny first-open default batches.
- **Newest polish completed locally:** short initial batches are now held back from visible timeline dispatch until the controlled top-up returns, and `TgChatScreenPage` shows a loading placeholder while the initial timeline is still pending.
- **Newest finding from 2026-03-08 `[21342]` HiLog:** the defer-placeholder path worked, but one top-up was not always enough — at least one chat still progressed only `1 -> 2` messages while `canLoadOlder` stayed true.
- **Newest local refinement completed:** initial top-up now retries in a bounded loop while oldest-message progress continues, and the chat screen keeps the loading placeholder until the initial timeline is large enough or older history is genuinely exhausted.
- **Current action:** device-verify that problematic chats now land on a fuller first-open timeline without showing a misleading tiny partial history in between.

### 2. Finish and commit the new tg_ui docs/demo batch
- **Evidence:** untracked files include:
  - `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets`
  - specs for `TgCallRow`, `TgChatTopBar`, `TgContactRow`, `TgSearchBar`, `TgSettingsRow`, `TgSettingsSection`, `TgTabBar`
  - demos for `TgCallRow`, `TgChatTopBar`, `TgContactRow`, `TgMessageBubbleBase`, `TgMessageRouter`, `TgSearchBar`, `TgSettingsRow`, `TgSettingsSection`, `TgTabBar`
- **Goal:** get the repo history aligned with the current tg_ui runtime path and documentation claims.
- **Boundary note:** these untracked tg_ui support files are explicitly classified as part of the current batch in `TASKS/CURRENT_PATCHSET_BOUNDARY.md`.

### 3. Resync human-facing docs with current runtime reality
- **Evidence:** local modifications in:
  - `README.md`
  - `docs/ai/AI_MEMORY.md`
  - `docs/ai/UI_MIGRATION_PLAN.md`
- **Goal:** remove drift between historical notes and the current shell/chat path.

### 4. Replace the Calls placeholder with real TDLib-backed call history
- **Evidence:** modified / added files in:
  - `entry/src/main/ets/core/model/AppCommand.ets`
  - `entry/src/main/ets/infra/td/serialization/CommandSerializer.ets`
  - `entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets`
  - `entry/src/main/ets/domain/usecases/loadCalls.ets`
  - `entry/src/main/ets/ui/pages/calls/CallsPage.ets`
  - `entry/src/main/ets/ui/tg_ui/atoms/TgCallRow.ets`
- **What changed locally:** `CallsPage` now uses TDLib `searchCallMessages` instead of the hardcoded empty state, paginates with `next_from_message_id`, and hydrates missing chat/user metadata via direct `getChat` / `getUser` response normalization.
- **Current limitation:** this pass maps TDLib `messageCall` / `messageGroupCall` into the existing single-peer `TgCallRow`; there is still no dedicated missed-only segmented header or richer group-call row treatment.
- **Next verification:** fresh device run + HiLog to confirm the real payload shape on this repo/runtime and verify that row titles/avatars hydrate correctly on non-trivial histories.

### 5. Stock ArkUI atom replacement (2026-03-09) ✅
- Replaced 3 thin wrapper atoms with stock components inline in pages:
  - `TgSearchBar` → stock `Search` in ChatListPage
  - `TgSettingsSection` → inline `Column` with tokens in SettingsPage
  - `TgContactRow` → inline `TgAvatar` + Row/Column in ContactsPage
- Kept: TgTabBar, TgTopBar, TgCallRow, TgSettingsRow (real custom logic)
- Smoke scripts updated. `bash ./scripts/smoke-ui-phase0.sh` ✅
- Orphaned demos/specs for removed atoms still exist (cleanup later)

---

## Improvement plan — "demo → real app" (derived from iOS comparison 2026-03-09)

Priority order is by **visual/functional impact**, not by architectural purity.

### P0-P5 Improvement plan — ALL COMPLETE (2026-03-09)
- **P0 Avatar download:** ✅ Full pipeline: `photoSmallFileId` in AppState/DTOs/reducers/stateClone, `DownloadFileCommand` + `CommandSerializer`, `FileNormalizer` (updateFile → FileDownloadedEvent), `filesReducer`, `downloadAvatars` usecase in AppCoreRuntime. Fixed two bugs: (1) `getTopLevelNumber('id')` for file IDs (Lesson #28), (2) direct response parsing via TdObject native accessors instead of broken `JSON.stringify(TdObject)` (Lesson #29). Needs device verification.
- **P1 Sender names in groups:** ✅ `buildChatItemVO()` prepends "You: " / "firstName: " for group previews
- **P2 Checkmark order:** ✅ TgChatMeta status icon before time (iOS: ✓✓ 17:47)
- **P3 Date format:** ✅ Same-year dates → `dd.MM` (no year)
- **P4 TgTopBar actions:** ✅ Edit + Compose buttons in ChatListPage
- **P5 Pinned separator:** ✅ `isLastPinned` + 8vp gap after last pinned chat

### Future (beyond current sprint)
- Media download/open (photos, videos, documents)
- Voice message playback
- Push notifications
- User/chat profile screen
- Create new chat/group
- Search within messages

## Next after the current patchset

### Re-run verification
- `scripts/smoke-ui-phase0.ps1` — passed on 2026-03-09
- `scripts/smoke-ui-phase0.sh` — passed on 2026-03-09
- latest runtime HiLog verification — passed on 2026-03-08 via `[27274]` trace
- `scripts/smoke-build.ps1` — passed on 2026-03-08
- next verification actions are:
  1. device run + HiLog for the new Phase 4 calls path
  2. device-verify P0 avatar download flow (fileId → downloadFile → updateFile → photo path in store → TgAvatar renders)

### Clean up stale historical references
- Only after demos/specs/integration are safely committed.
- Orphaned demos/specs for removed atoms (TgSearchBar, TgSettingsSection, TgContactRow) can be deleted.
- Do not remove old docs or fallback paths blindly while the branch is still unstable.

## External blockers / prerequisites
- TDLib prebuilts under `entry/src/main/cpp/third_party/tdlib`
- local credentials in `entry/src/main/ets/services/ConfigLocal.ets`
