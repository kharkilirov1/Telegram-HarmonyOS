# TgChatRow Component Passport

## 1) Scope
- Atom: `TgChatRow`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/ChatListUI/Sources/Node/ChatListItem.swift`
  - avatar sizing and left inset (lines ~1921, ~2432, ~2444).
  - title/preview max width depends on right cluster budget (`badgeSize`) (lines ~3565, ~3585).
  - right cluster placement:
    - date/status top-right (lines ~4269, ~4298–4306)
    - badge/mention/pin anchored from `nextBadgeX` trailing edge (lines ~4308–4331)
  - separator inset anchored after avatar block (lines ~5028+).
- `submodules/ChatListUI/Sources/Node/ChatListBadgeNode.swift`
  - badge capsule width grows by content while keeping minimum diameter.
- `submodules/ChatListUI/Sources/Node/ChatListStatusNode.swift`
  - send status state machine (`none/sending/sent/read/failed` visual behavior).
- `submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesChatList.swift`
  - mute/pin/check/clock/warning resource style and unread badge visual language.

## 3) Props / inputs
- `data: TgChatRowData`
  - `chatId`
  - `title`
  - `preview`
  - `previewPrefix`
  - `previewPrefixStyle`
  - `timeText`
  - `unreadCount`
  - `isMuted`
  - `isPinned`
  - `sendStatus`
  - `avatarInitials/avatarUseImage/avatarImageSrc/avatarIsOnline`
  - `avatarBackgroundColor/avatarTextColor`
  - `isDraft`
  - `isTyping`
- `showSeparator: boolean`

## 4) State matrix (demo coverage)
- normal (no unread)
- unread `1/99/99+`
- pinned (no unread)
- muted (no unread)
- muted + unread
- draft prefix (`Draft:` accent + normal body text)
- group sender prefix accent (`You:` / sender name)
- typing preview (normal preview tone, dedicated activity state)
- sending / sent / read
- online avatar dot
- long title + long preview (ellipsis torture)
- failed only
- failed + unread
- jump probe: same left content, varying right cluster states

## 5) Layout rules
- Row height fixed via token (`CHAT_ROW_HEIGHT`).
- Composition:
  - left: `TgAvatar` (fixed size)
  - center: title(+mute icon) + preview
  - right: `TgChatMeta` (fixed min width)
- Vertical rhythm is intentionally compact; title and preview sit closer together than a generic `Column(space: 4)` list row.
- Text rules:
  - title and preview are `maxLines(1)` + ellipsis.
  - draft preview keeps the prefix visually separate from the body, matching Telegram's red `Draft:` treatment without letting the prefix collapse into the preview text color.
  - group sender prefix keeps the author part visually separate from the body, matching the iOS author-name accent pattern for group rows.
  - typing preview should not borrow the group sender accent color; current iOS `ChatListInputActivitiesNode` renders the full activity string in the chat-list message text color.
- Right cluster anti-jump:
  - width reserve comes from `TgChatMeta.constraintSize(minWidth)`.
  - bottom geometry reserve handled inside `TgChatMeta` with placeholder.
- Separator policy:
  - for tg_ui path use **internal row separator**;
  - disable `List.divider` in integration branch to avoid double separator.
  - separator inset follows the iOS chat-list lane (`~80pt` with 60pt avatar path), not the full text-start inset.

## 6) Token mapping
- Source: `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
  - `CHAT_ROW_*` metrics (height/sideInset/gaps/separator)
  - `CHAT_ROW_TITLE_FONT_SIZE`, `CHAT_ROW_PREVIEW_FONT_SIZE`
  - colors (`COLOR_TEXT_TITLE`, `COLOR_TEXT_PREVIEW`, `COLOR_CHAT_ROW_PINNED_BG`, separator)
  - mute icon sizing and resources
  - meta/badge tokens consumed transitively via `TgChatMeta` and `TgUnreadBadge`

## 7) Acceptance checklist
- [x] `@Reusable` added and list integration uses `reuseId`
- [x] Avatar + text + meta composition implemented
- [x] Title/preview ellipsis cases covered
- [x] Right meta no-jump preserved via `TgChatMeta`
- [x] Internal separator implemented (single separator strategy)
- [x] Demo has 10+ states + jump probe
- [ ] Final side-by-side polish against iOS screenshots

