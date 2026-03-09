# STATUS — Telegram-HarmonyOS

Snapshot date: 2026-03-09

## Current snapshot
- **Branch:** `refactor/appcore-reset`
- **Repo state:** working tree is **not clean**
- **Observed changes:** `46` tracked modifications + `68` untracked entries
- **Primary app target:** HarmonyOS NEXT / API 22+
- **Local reference root:** `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\рефенсы`

## What is working conceptually
- `EntryAbility` boots `AppCoreRuntime`
- TDLib bridge exists through NAPI
- Event pipeline is in place: gateway -> dispatcher -> normalizer -> store -> UI
- Auth/login shell exists
- Chat list page exists and uses `tg_ui` shell pieces
- Chat screen page exists and uses `TgChatTopBar`, `TgMessageRouter`, and `TgComposerInput`
- Contacts / Calls / Settings tabs exist
- Calls tab now has a **local real TDLib-backed data path** via `searchCallMessages`, but this Phase 4 pass is still **not device-runtime-verified**

## Current tg_ui inventory
- **26 atoms**
- **2 molecules**
- **30 demos**
- **33 spec files**

## Current active UI path
- Shell/chat runtime currently routes through:
  - `TgTabBar`
  - `TgTopBar`
  - `TgSearchBar`
  - `TgChatRow`
  - `TgChatTopBar`
  - `TgMessageRouter`

## What is clearly in progress right now
- Latest local patch from 2026-03-09: fixed chat-list blank-cell regression by restoring stable `LazyForEach` identity (`chatId` key + per-chat `reuseId`), removing debug render noise from `TgChatRow`/`ChatListPage`, and guarding chat title updates against empty overwrite in normalizer/reducer.
- Latest local UX fallback from 2026-03-09: private chat row title can now fall back to `user.phoneNumber` before `Unknown`, reducing empty/placeholder rows for incomplete contact profiles.
- Runtime stabilization around:
  - `AppCoreRuntime`
  - `AppStore`
  - `loadChats`
  - `loadChatHistory`
  - `openChat`
  - `ChatListPage`
  - `TgChatScreenPage`
- Latest log-driven runtime fix target: prevent `TgChatScreenPage` unread-boundary / saved-index restore from triggering automatic history pagination before the user actually scrolls.
- Latest verified outcome from 2026-03-08 HiLog: restore-triggered and edge-pinned pagination storms are closed in `TgChatScreenPage`; the loudest remaining runtime noise is now incomplete sender hydration during history loads.
- Latest local patch from 2026-03-08: `LoadChatHistoryUseCase` now allows a full default history page worth of missing sender hydrations (`MAX_MISSING_USER_HYDRATION_PER_LOAD = 64`) before dispatching the history batch, to reduce residual `Message references non-existent user` soft invariants.
- Latest log-driven root cause from 2026-03-08 HiLog: direct TDLib `user` payloads could parse nested `profile_photo.id` instead of the real top-level `user.id`, which explains bogus `getMe resolved` values and why repeated `getUser` calls still left sender users missing in store.
- Latest local patch from 2026-03-08: `TdObject` now exposes top-level int64 extraction, and user parsing / `getMe` resolution switched to `getTopLevelNumber('id')` so hydrated users land under the correct store key.
- Latest verified runtime outcome from the 2026-03-08 `[27274]` HiLog: `Message references non-existent user = 0`, `lastMessage is older than newest message in map = 0`, `Loading older/newer messages = 0`.
- New follow-up finding from the 2026-03-08 `[8081]` HiLog: a default `getChatHistory` open can return a **very short non-zero batch** (observed `1 events`) while older history may still plausibly exist, so treating `messageCount < limit` as end-of-history is too aggressive for TDLib.
- Latest local runtime patch from 2026-03-08: `LoadChatHistoryUseCase` now keeps pagination progress-based instead of `messageCount >= limit`-based, and performs one controlled `older` top-up when the first default history batch is suspiciously tiny.
- Latest local UX polish from 2026-03-08: tiny initial history batches are now **deferred from UI dispatch** until the controlled top-up finishes, and `TgChatScreenPage` shows a loading placeholder instead of a misleading temporary `No messages yet` / one-message state while the initial timeline is still settling.
- Latest follow-up from the 2026-03-08 `[21342]` HiLog: one controlled top-up is still not always enough — some chats can progress from `1` to only `2` visible messages before older history is still available.
- Latest local refinement from 2026-03-08: initial history top-up is now **bounded multi-step** (up to 3 older top-ups while progress continues), and the chat screen keeps the loading placeholder until the initial timeline reaches a reasonable size or older history is actually exhausted.
- Immediate operator focus has moved from **Phase 1 runtime bug-hunting** to **Phase 2 batch consolidation**; current patchset boundary is documented in `TASKS/CURRENT_PATCHSET_BOUNDARY.md`.
- Phase 3 verification gate has now been attempted on the current batch:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
  - `./scripts/smoke-build.ps1` ✅ now finds DevEco hvigor automatically and completes successfully
- Latest local Phase 4 patch from 2026-03-08: `CallsPage` no longer renders a hardcoded placeholder; it now loads real recent calls through TDLib `searchCallMessages`, paginates with `next_from_message_id`, and hydrates missing peers via direct `getChat` / `getUser` response normalization.
- Latest local verification from 2026-03-08 for the Phase 4 patch:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
- Latest local build verification from 2026-03-08:
  - `./scripts/smoke-build.ps1` ✅
  - discovered hvigor wrapper: `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`
- Current operator focus has moved beyond the Phase 3 gate into **Phase 4 — Real Calls implementation**, but this new calls path still needs **device HiLog verification**.
- A batch of tg_ui specs/demos/components is present but still untracked in git.
- High-level docs (`README.md`, `docs/ai/AI_MEMORY.md`, `docs/ai/UI_MIGRATION_PLAN.md`) also have local edits.

## Risks / caveats
- This is an active refactor branch, not a clean release snapshot.
- Some older docs contain historical names (`AppTopBar`, `AppTabBarItem`, older feature-flag wording); prefer current runtime path over stale names.
- `scripts/smoke-ui-phase0.ps1` and `scripts/smoke-ui-phase0.sh` were re-run successfully on **2026-03-08** after the latest sender-hydration patch.
- Local HarmonyOS smoke build is now **verified** on **2026-03-08** through the DevEco-installed wrapper at `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`.
- The new short-initial-history fix is only **local-script/build-verified** so far; a fresh device HiLog is still required to confirm that chats with previously tiny first batches now expand correctly on first open.
- The new Phase 4 calls path is only **local-smoke-verified** so far; a fresh device run / HiLog is still required to confirm `searchCallMessages` payload shape and row hydration behavior.
- TDLib prebuilts and local `ConfigLocal.ets` remain external prerequisites.

## Read order for a new contributor/agent
1. `AGENTS.md`
2. `STATUS.md`
3. `DECISIONS.md`
4. `ARCHITECTURE.md`
5. `TASKS/AGENT_EXECUTION_PLAN.md`
6. `TASKS/TODO.md`
7. `TASKS/LESSONS.md`
8. Deep docs under `docs/ai/`
