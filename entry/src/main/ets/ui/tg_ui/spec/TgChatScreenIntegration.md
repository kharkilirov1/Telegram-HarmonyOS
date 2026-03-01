# TgChatScreen Integration (Phase C / Step 6)

## Goal
Integrate previously completed chat atoms into a real chat screen route:
- `TgDateSeparator` / `TgUnreadMarker`
- `TgMessageBubbleBase`
- `TgMessageMeta`
- `TgReplySnippet`
- `TgComposerInput`

Integration must stay feature-flagged and preserve legacy behavior by default.

## iOS References
- `submodules/TelegramUI/Sources/ChatController.swift`
- `submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift`
- `submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode/Sources/ChatMessageDateAndStatusNode.swift`
- `submodules/TelegramUI/Components/Chat/ChatMessageDateHeader.swift`
- `submodules/TelegramUI/Components/Chat/ChatUnreadItem.swift`
- `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`

## Inputs / Data Contract
- Active chat from `StorageKeys.ACTIVE_CHAT_ID`
- Chat title from `StorageKeys.ACTIVE_CHAT_TITLE` (fallback)
- Messages from store (`selectChatMessagesForChatView`)
- Read markers from chat state:
  - `lastReadInboxMessageId` for unread marker position
  - `lastReadOutboxMessageId` + message flags for outgoing status
- Reply snippet from `replyToMessageId`

## Layout Rules
1) Top bar with back action (navigation stack pop).
2) Timeline list uses one datasource and incremental diff updates.
3) Date separator inserted on day change.
4) Unread marker inserted before first unread incoming message.
5) Message item composition:
   - optional reply snippet
   - bubble
   - meta row (time + checks for outgoing)
6) Composer docked at bottom with tab-bar safe padding.

## Feature Flags
- `USE_TG_CHAT_V2` controls navigation from chat list into tg_ui chat screen.
- Legacy remains default when flag is `false`.

## Acceptance Checklist
- [ ] Chat opens from chat list only when flag is enabled.
- [ ] Timeline updates use incremental datasource diff (no forced full reload path).
- [ ] Date separators and unread marker are deterministic and stable.
- [ ] Long tokens do not overflow bubble bounds.
- [ ] Back navigation works through `NavPathStack.pop()`.
- [ ] Legacy chat list path remains intact when feature flag is disabled.
