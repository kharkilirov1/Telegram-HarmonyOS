# TODO — observed current work

Last updated: 2026-03-08

This is a **working snapshot**, not a product roadmap. It is derived from:
- current git status on branch `refactor/appcore-reset`
- current repo docs
- current file layout

Canonical execution order for agents now lives in:
- `TASKS/AGENT_EXECUTION_PLAN.md`

## Active now

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

## Next after the current patchset

### 4. Re-run verification
- `scripts/smoke-ui-phase0.ps1` — passed on 2026-03-08
- `scripts/smoke-ui-phase0.sh` — passed on 2026-03-08
- latest runtime HiLog verification — passed on 2026-03-08 via `[27274]` trace
- `scripts/smoke-build.ps1` — passed on 2026-03-08 after adding fallback discovery of the DevEco wrapper at `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`
- next verification actions are:
  1. device run + HiLog for the new Phase 4 calls path
  2. if needed, keep the fallback hvigor discovery in sync with the actual local DevEco install path

### 5. Clean up stale historical references
- Only after demos/specs/integration are safely committed.
- Do not remove old docs or fallback paths blindly while the branch is still unstable.

## External blockers / prerequisites
- TDLib prebuilts under `entry/src/main/cpp/third_party/tdlib`
- local credentials in `entry/src/main/ets/services/ConfigLocal.ets`
