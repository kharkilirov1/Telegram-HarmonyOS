# COMMIT GROUP 1 BOUNDARY — reply/auth stabilization

Date: 2026-03-21

## Goal
Prepare the **first truly reviewable slice** from the current dirty tree:
- reply snippet parity + quote plumbing
- login/auth timeout UX hardening

This document answers:
1. which files are already clean members of the group,
2. which files are still mixed and need hunk-splitting,
3. what should stay out of this group.

## Current status
**Not file-ready yet.**

The slice is coherent at the product level, but several files still contain mixed concerns from:
- audio album art work,
- media/runtime cleanup,
- shell/top-bar/search tuning,
- cache/memory changes.

## Clean members (safe full-file members)

These files currently read as belonging to reply/auth stabilization as a whole:

### Auth timeout UX
- `entry/src/main/ets/infra/td/gateway/TdGateway.ets`
- `entry/src/main/ets/ui/controllers/LoginController.ets`

### Reply snippet UI/spec
- `entry/src/main/ets/models/td/messages/index.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgReplySnippet.ets`
- `entry/src/main/ets/ui/tg_ui/spec/TgReplySnippet.md`

Why these are clean:
- the diff intent is single-topic and easy to review,
- no obvious unrelated shell/media batch leakage was found in this pass.

## Mixed members (need hunk split before a commit-ready boundary)

### 1. `entry/src/main/ets/core/model/AppState.ets`
Mixed concerns:
- reply quote fields
- `unreadMentionCount`
- audio album cover fields

Needed for group 1:
- `replyIsQuote`
- `replyQuoteText`
- `replyQuoteOffset`

Not inherently group 1:
- `unreadMentionCount`
- `audioAlbumCoverPath`
- `audioAlbumCoverFileId`

### 2. `entry/src/main/ets/core/model/dto/MessageDto.ets`
Mixed concerns:
- reply parse/plumbing/logging
- audio album cover extraction

Needed for group 1:
- `reply_to` object parse (`message_id`, `quote`, `quote_text`, `quote_offset`)
- `replyIsQuote`, `replyQuoteText`, `replyQuoteOffset`
- reply diagnostics logging

Not inherently group 1:
- `audioAlbumCoverPath`
- `audioAlbumCoverFileId`
- album-cover extraction from audio payload

### 3. `entry/src/main/ets/core/reducers/filesReducer.ets`
Mixed concerns:
- reply field preservation in clones
- album-cover file-id/path handling
- transfer-completion behavior change

Needed for group 1:
- preserve `replyIsQuote`
- preserve `replyQuoteText`
- preserve `replyQuoteOffset`

Not inherently group 1:
- `audioAlbumCover*`
- completed-transfer deletion behavior

### 4. `entry/src/main/ets/core/reducers/messagesReducer.ets`
Mixed concerns:
- reply field mapping/cloning
- album-cover mapping/cloning
- cache eviction (`MAX_CACHED_CHATS`, `evictStaleChatMessages`)

Needed for group 1:
- reply field mapping from DTO/state clone

Not inherently group 1:
- album-cover fields
- cache eviction logic

### 5. `entry/src/main/ets/core/utils/stateClone.ets`
Mixed concerns:
- `unreadMentionCount` clone support

Needed for group 1:
- currently **nothing obvious**

Conclusion:
- do **not** pull this file into group 1 as-is.

### 6. `entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets`
Mixed concerns:
- reply preview/quote semantics/logging
- album photo ids
- audio album cover fields
- voice path normalization

Needed for group 1:
- `resolveReplyPreview(..., replyQuoteText)`
- `row.replyIsQuote = message.replyIsQuote`
- reply diagnostics logging

Not inherently group 1:
- `albumPhotoFileIds`
- `audioAlbumCover*`
- `voicePath = toFileUri(...)`

### 7. `entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets`
Mixed concerns:
- reply route logging
- reply embedding spacing fixes
- audio album art path plumbing
- media/text body layout changes

Needed for group 1:
- reply route logging
- reply snippet embedding spacing/inset fixes

Not inherently group 1:
- `audioAlbumCoverPath`
- unrelated media/text body layout changes

### 8. `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
Mixed concerns:
- reply snippet token tuning
- chat top bar tokens
- search bar tokens
- shell/token audit values

Needed for group 1:
- only `REPLY_SNIPPET_*` additions/changes

Not inherently group 1:
- chat-top-bar/search/composer/shell token changes

### 9. Resource colors
- `entry/src/main/resources/base/element/color.json`
- `entry/src/main/resources/dark/element/color.json`

Mixed concerns:
- reply snippet background colors
- glass/shell color tuning

Needed for group 1:
- `reply_snippet_bg_incoming`
- `reply_snippet_bg_outgoing`

Not inherently group 1:
- glass/tab/shell tint changes

## Explicit exclusions for group 1
Do not include these as part of reply/auth stabilization:
- shell top bar / tab bar / search parity work
- media gallery / playback / album art behavior
- cache eviction / memory trimming
- generated repo hygiene changes

## Practical next move
The next cleanup pass should:
1. keep the clean full-file members above,
2. extract only the reply/auth hunks from the mixed members,
3. leave album-art/media/shell/cache hunks behind for later groups.

Exact extraction notes now live in:
- `TASKS/ARCHIVE/COMMIT_GROUP_1_HUNK_MAP_2026_03_21.md`

## Success condition
Commit group 1 becomes:
- small enough to review,
- explainable in one paragraph,
- verifiable with one reply/auth story instead of multiple unrelated stories.
