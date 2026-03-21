# WORKING TREE TRIAGE — 2026-03-21

## Purpose
Describe the **current dirty tree** in human terms so the repo can be brought back to coherent patchsets without guessing.

This is not a commit plan yet.
It is a triage map for the next cleanup passes.

## Snapshot
- `git diff --stat`: **64 files changed**, about **2290 insertions / 713 deletions**
- Working tree is not one patch.
- It is a mix of:
  1. active reply/auth fixes,
  2. earlier media/chat-shell/top-bar work,
  3. doc growth,
  4. a few clear noise artifacts.

## Safe findings

### A. Clear generated/noise artifacts
- `build_debug.log`
  - generated build output
  - should not live in git status
  - now added to `.gitignore`

### B. Ambiguous local artifact
- `QWEN.md`
  - currently untracked
  - not a generated build artifact
  - content shape matches tracked assistant-context docs such as `CLAUDE.md` / `GEMINI.md`
  - recommended classification: **intentional repo doc candidate**
  - do **not** auto-delete and do **not** hide it behind `.gitignore` unless the repo explicitly chooses to drop assistant-context docs of this type

## Main patch groups currently mixed together

### Group 1 — Reply snippet parity + quote plumbing
High-confidence coherent slice:
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
- reply-related specs/resources/docs

Why coherent:
- one user-visible topic,
- one runtime data path,
- one visual parity objective.

### Group 2 — Auth/login timeout UX hardening
High-confidence coherent slice:
- `entry/src/main/ets/infra/td/gateway/TdGateway.ets`
- `entry/src/main/ets/ui/controllers/LoginController.ets`

Why coherent:
- one bug family,
- one gateway/controller chain,
- easy to review separately.

### Group 3 — Chat shell / top bar / search / tab bar / list polish
Still mixed, but mostly one UI family:
- `entry/src/main/ets/ui/pages/MainTabsPage.ets`
- `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
- `entry/src/main/ets/ui/pages/chatlist/ChatListDataSource.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgTabBar.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgUnreadBadge.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgSearchBar.ets` (new)
- corresponding demos/specs

Why not clean yet:
- touches several separate visual concerns,
- likely commit-worthy later, but should be reviewed as its own UI shell batch.

### Group 4 — Media / playback / gallery / file-transfer behavior
Still mixed, but broadly coherent:
- `entry/src/main/ets/domain/usecases/downloadAvatars.ets`
- `entry/src/main/ets/domain/usecases/downloadMessageMedia.ets`
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- `entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets`
- media bubble atoms (`TgAudioBubble`, `TgVideoBubble`, `TgVoiceBubble`, `TgPhotoBubble`, `TgAnimationBubble`, `TgInstantVideoBubble`, `TgInlineVideoView`, `TgMediaGalleryPage`, `TgDocumentRow`)
- related resource/token changes

Why not clean yet:
- overlaps behavior and UI,
- should remain one deliberate media patch instead of leaking into reply/auth slices.

### Group 5 — Runtime/core/hydration side effects adjacent to UI work
Potentially related, but needs one more pass before commit grouping:
- `entry/src/main/cpp/tdlib_napi.cpp`
- `entry/src/main/ets/core/model/dto/ChatDto.ets`
- `entry/src/main/ets/core/reducers/chatsReducer.ets`
- `entry/src/main/ets/core/reducers/usersReducer.ets`
- `entry/src/main/ets/domain/selectors/messageSelectors.ets`
- `entry/src/main/ets/domain/usecases/openChat.ets`
- `entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets`
- `entry/src/main/ets/ui/pages/chat/ChatTimelineDataSource.ets`

Why this is the hardest bucket:
- some changes may belong to reply/media/runtime fixes,
- but the group is not yet self-explanatory from file names alone.

## Recommended cleanup order

### Pass 1 — noise removal
- keep generated artifacts out of status
- do not touch ambiguous local docs automatically

### Pass 2 — freeze commit-intent groups
- reply/auth
- shell UI
- media/playback
- runtime/core leftovers

### Pass 3 — document unresolved artifacts
- explicitly decide what `QWEN.md` is:
  - keep and track,
  - or mark local-only and ignore

## Practical rule for next passes
No “cleanup” commit should mix:
- reply/auth fixes
- media behavior work
- shell top-bar/search polish
- runtime/core leftovers

Those are already separable enough to deserve independent commit boundaries.

See also:
- `TASKS/COMMIT_GROUPS_2026_03_21.md`
