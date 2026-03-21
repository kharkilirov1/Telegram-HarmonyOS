# COMMIT GROUPS — 2026-03-21

## Purpose
Turn the current dirty tree into **reviewable commit-sized slices** without mixing unrelated work.

This file does **not** commit anything.
It only freezes the intended grouping.

## Decision on `QWEN.md`
- **Decision:** treat `QWEN.md` as a **real repo doc candidate**, not as disposable noise.
- **Why:** it matches the same family as tracked root assistant-context files (`CLAUDE.md`, `GEMINI.md`) and is not a generated artifact.
- **Consequence:** do **not** add `QWEN.md` to `.gitignore` in the cleanup flow. If kept, it should be tracked intentionally in a documentation/tooling slice.

## Recommended commit order

### Commit group 1 — reply/auth stabilization
This is the cleanest current product-facing slice.

Files:
- `entry/src/main/ets/core/model/AppState.ets`
- `entry/src/main/ets/core/model/dto/MessageDto.ets`
- `entry/src/main/ets/core/reducers/filesReducer.ets`
- `entry/src/main/ets/core/reducers/messagesReducer.ets`
- `entry/src/main/ets/core/utils/stateClone.ets`
- `entry/src/main/ets/models/td/messages/index.ets`
- `entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgReplySnippet.ets`
- `entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets`
- `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
- `entry/src/main/resources/base/element/color.json`
- `entry/src/main/resources/dark/element/color.json`
- `entry/src/main/ets/ui/tg_ui/spec/TgReplySnippet.md`
- `entry/src/main/ets/infra/td/gateway/TdGateway.ets`
- `entry/src/main/ets/ui/controllers/LoginController.ets`

Why this should go first:
- one visible user story cluster,
- one coherent verification story,
- already partially documented and discussed with real screenshots/logs.

Refinement:
- see `TASKS/COMMIT_GROUP_1_REPLY_AUTH_BOUNDARY.md`
- current status: **coherent but not file-ready yet**
- several files still need hunk-splitting because reply/auth work is mixed with album-art, shell-token, media-layout, or cache changes

### Commit group 2 — shell UI parity batch
Files likely belonging together:
- `entry/src/main/ets/ui/pages/MainTabsPage.ets`
- `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
- `entry/src/main/ets/ui/pages/chatlist/ChatListDataSource.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgTabBar.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgUnreadBadge.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgSearchBar.ets`
- related shell demos/specs

Why separate:
- this is visual shell polish, not reply/media/runtime behavior.

### Commit group 3 — media/playback/gallery batch
Files likely belonging together:
- `entry/src/main/ets/domain/usecases/downloadAvatars.ets`
- `entry/src/main/ets/domain/usecases/downloadMessageMedia.ets`
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- `entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets`
- media bubble atoms
- gallery/inline video atoms
- related resource changes

Why separate:
- this is a product-feature batch with its own runtime risks and device checks.

### Commit group 4 — runtime/core leftovers
Files needing one more sorting pass before commit:
- `entry/src/main/cpp/tdlib_napi.cpp`
- `entry/src/main/ets/core/model/dto/ChatDto.ets`
- `entry/src/main/ets/core/reducers/chatsReducer.ets`
- `entry/src/main/ets/core/reducers/usersReducer.ets`
- `entry/src/main/ets/domain/selectors/messageSelectors.ets`
- `entry/src/main/ets/domain/usecases/openChat.ets`
- `entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets`
- `entry/src/main/ets/ui/pages/chat/ChatTimelineDataSource.ets`

Why last:
- these are the least self-explanatory from file grouping alone,
- they may partially support earlier slices and need a final ownership pass.

### Commit group 5 — repo/docs/operator hygiene
Files:
- `.gitignore`
- `TASKS/REPO_OPERATOR_HARDENING_PLAN.md`
- `TASKS/WORKING_TREE_TRIAGE_2026_03_21.md`
- `TASKS/COMMIT_GROUPS_2026_03_21.md`
- `scripts/hilog-filter.ps1`
- root memory-pack updates (`STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md`, optionally `TASKS/CURRENT_PATCHSET_BOUNDARY.md`)
- `QWEN.md` if intentionally kept

Why separate:
- repo hygiene should stay reviewable and not hide product code.

## Next practical cleanup move
If continuing now, the safest next structural pass is:
1. freeze **Commit group 1** more tightly,
2. confirm whether any files from runtime/core leftovers actually belong there,
3. only then prepare a commit-ready diff boundary for group 1.
