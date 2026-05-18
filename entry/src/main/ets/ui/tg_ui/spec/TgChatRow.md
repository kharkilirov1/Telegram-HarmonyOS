# TgChatRow Component Passport

## 1) Scope
- Atom: `TgChatRow`
- Target layer: `atoms`
- Status: `done`

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
- Runtime props are passed as **flattened `@Param` values**, not as a single `data` object:
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
  - `avatarInitials`
  - `avatarUseImage`
  - `avatarImageSrc`
  - `avatarIsOnline`
  - `isVerified`
  - `avatarBackgroundColor`
  - `avatarTextColor`
  - `isDraft`
  - `isTyping`
  - `showSeparator`
- `TgChatRowData` remains a **demo/helper model** for `TgChatRowDemo.ets`, not the live runtime prop contract.

## 4) State matrix (demo coverage)
- normal (no unread)
- unread `1/99/207/2.5K`
- pinned (no unread)
- muted (no unread)
- muted + unread
- draft prefix (`Draft:` accent + normal body text)
- group sender prefix accent (`You:` / sender name)
- typing preview (normal preview tone, dedicated activity state)
- verified title badge (private peer)
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
  - verified peers may render a compact title badge between the title text and mute icon; the title must still ellipsize before pushing the fixed right meta cluster.
  - draft preview keeps the prefix visually separate from the body, matching Telegram's red `Draft:` treatment without letting the prefix collapse into the preview text color.
  - group sender prefix keeps the author part visually separate from the body, matching the iOS author-name accent pattern for group rows.
  - typing preview uses activity accent color (`CHAT_TOP_BAR_SUBTITLE_ACCENT` / telegram_blue) — follows Android Telegram pattern for stronger visual distinction. iOS uses chat-list message text color (gray), but we chose accent for better UX signal. Typing should not borrow the group sender prefix color.
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
  - `CHAT_ROW_VERIFIED_*`
  - `CHAT_ROW_TITLE_FONT_SIZE`, `CHAT_ROW_PREVIEW_FONT_SIZE`
  - colors (`COLOR_TEXT_TITLE`, `COLOR_TEXT_PREVIEW`, `COLOR_CHAT_ROW_PINNED_BG`, separator)
  - mute icon sizing and resources
  - meta/badge tokens consumed transitively via `TgChatMeta`; unread/mention capsules are inline in `TgChatMeta` in the active branch

## 7) Acceptance checklist
- [x] `@ComponentV2` row is used in the live chat-list path and `ChatListPage` still applies `reuseId(...)`
- [x] Avatar + text + meta composition implemented
- [x] Title/preview ellipsis cases covered
- [x] Right meta no-jump preserved via `TgChatMeta`
- [x] Internal separator implemented (single separator strategy)
- [x] Demo has 10+ states + jump probe
- [x] `ChatListDataSource` diff watches preview-prefix / draft / pinned-boundary flags so same-order rows still refresh correctly
- [ ] Final side-by-side polish against iOS screenshots

