# COMMIT GROUP 1 HUNK MAP — 2026-03-21

## Purpose
This is the **exact extraction map** for the first intended commit group:
- reply snippet parity + quote plumbing
- auth timeout UX hardening

Unlike the boundary doc, this file is hunk-oriented.
It says exactly what to keep and what to leave behind in mixed files.

## Clean full-file members
These can stay whole in commit group 1:

- `entry/src/main/ets/infra/td/gateway/TdGateway.ets`
- `entry/src/main/ets/ui/controllers/LoginController.ets`
- `entry/src/main/ets/models/td/messages/index.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgReplySnippet.ets`
- `entry/src/main/ets/ui/tg_ui/spec/TgReplySnippet.md`

## Mixed-file extraction map

### 1. `entry/src/main/ets/core/model/AppState.ets`
**Keep:**
- `Message.replyIsQuote`
- `Message.replyQuoteText`
- `Message.replyQuoteOffset`

**Leave behind:**
- `Chat.unreadMentionCount`
- `MessageContent.audioAlbumCoverPath`
- `MessageContent.audioAlbumCoverFileId`

### 2. `entry/src/main/ets/core/model/dto/MessageDto.ets`
**Keep:**
- import + constants for reply diagnostics logging:
  - `hilog`
  - `DOMAIN = 0x3201`
  - `TAG = 'MessageDto'`
- `MessageDto.replyIsQuote`
- `MessageDto.replyQuoteText`
- `MessageDto.replyQuoteOffset`
- `createMessageDtoFromTd(...)` reply parsing:
  - `const replyTo = tdGetObject(tdMessage, 'reply_to')`
  - parse:
    - `message_id`
    - `quote_text`
    - `quote_offset`
    - `quote`
- reply parse `hilog.info(...)`
- `applyMessageUpdate(...)` preservation of:
  - `replyIsQuote`
  - `replyQuoteText`
  - `replyQuoteOffset`

**Leave behind:**
- `MessageContentDto.audioAlbumCoverPath`
- `MessageContentDto.audioAlbumCoverFileId`
- audio `album_cover_thumbnail` extraction in `parseMessageContent(...)`

### 3. `entry/src/main/ets/core/reducers/filesReducer.ets`
**Keep:**
- `cloneMessageWithContent(...)` preservation of:
  - `replyIsQuote`
  - `replyQuoteText`
  - `replyQuoteOffset`

**Leave behind:**
- `content.audioAlbumCoverFileId === fileId`
- `audioAlbumCoverPath/audioAlbumCoverFileId` propagation
- transfer-completion behavior change (`transfers.delete(fileId)` vs completed transfer object update)

### 4. `entry/src/main/ets/core/reducers/messagesReducer.ets`
**Keep:**
- `messageFromDto(...)`:
  - `replyIsQuote`
  - `replyQuoteText`
  - `replyQuoteOffset`
- `cloneMessage(...)`:
  - `replyIsQuote`
  - `replyQuoteText`
  - `replyQuoteOffset`

**Leave behind:**
- `content.audioAlbumCover*`
- cloned content `audioAlbumCover*`
- `MAX_CACHED_CHATS`
- `evictStaleChatMessages(...)`
- reducer flow rewrites tied to cache eviction

### 5. `entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets`
**Keep:**
- import + constants for reply diagnostics logging:
  - `hilog`
  - `DOMAIN = 0x3202`
  - `TAG = 'ChatTimelineVO'`
- `resolveReplyPreview(..., replyQuoteText = '')`
- reply preview preference for `replyQuoteText`
- `row.replyPreview = resolveReplyPreview(..., message.replyQuoteText)`
- `row.replyIsQuote = message.replyIsQuote`
- reply diagnostics `hilog.info(...)`

**Leave behind:**
- `albumPhotoFileIds`
- `audioAlbumCoverPath`
- `audioAlbumCoverFileId`
- `row.voicePath = toFileUri(content.voicePath)`
- album-building support additions

### 6. `entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets`
**Keep:**
- reply route diagnostics logging (`reply route ...`)
- reply embedding spacing fixes:
  - remove extra reply bottom margin
  - `top: this.showReplySnippet ? 0 : TgUiTokens.BUBBLE_PADDING_V`
  - media reply side inset reduction to `SPACE_8`

**Leave behind:**
- `@Param audioAlbumCoverPath`
- `albumCoverPath: this.audioAlbumCoverPath`
- unrelated text/media body layout edits
- unrelated `.wordBreak(...)` / `.lineBreakStrategy(...)` / width/margin restructuring that is not strictly part of reply embedding

### 7. `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
**Keep:**
- all `REPLY_SNIPPET_*` changes only:
  - compact min heights
  - compact padding
  - compact bar gap
  - compact line heights
  - background resources
  - quote max lines

**Leave behind:**
- `CHAT_TOP_BAR_*`
- `AVATAR_ONLINE_DOT_OFFSET_*`
- `CHAT_ROW_*`
- `COMPOSER_*`
- `SEARCH_BAR_*`
- `OVERLAY_*`
- `ICON_RES_CLOSE`

### 8. `entry/src/main/resources/base/element/color.json`
**Keep:**
- `reply_snippet_bg_incoming`
- `reply_snippet_bg_outgoing`

**Leave behind:**
- glass/tab/shell tint changes

### 9. `entry/src/main/resources/dark/element/color.json`
**Keep:**
- `reply_snippet_bg_incoming`
- `reply_snippet_bg_outgoing`

**Leave behind:**
- glass/tab/shell tint changes

## Resulting practical boundary
If extracted correctly, commit group 1 should contain:

### Reply path
- explicit reply quote plumbing
- compact-vs-quote snippet behavior
- reply-height/spacing/alignment fixes
- reply diagnostics logging

### Auth path
- longer phone-submit timeout
- friendly timeout message
- structured `AppError` mapping in login controller

And it should **not** contain:
- album art support
- media transfer behavior
- shell glass/top-bar/search tuning
- cache eviction behavior

## Next manual extraction target
The hardest mixed files are:
1. `MessageDto.ets`
2. `messagesReducer.ets`
3. `ChatTimelineVO.ets`
4. `TgMessageRouter.ets`
5. `TgUiTokens.ets`

Those five files are the main reason commit group 1 is still not file-ready.
