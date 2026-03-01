# TgChatMeta Component Passport

## 1) Scope
- Atom: `TgChatMeta`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/ChatListUI/Sources/Node/ChatListItem.swift`
  - `dateNode` + `statusNode` are part of right meta cluster (lines ~1341, ~1345, ~1634–1638).
  - outgoing send-state mapping (sending / delivered / read / failed) built in layout pass (lines ~3197–3218).
  - right-side placement logic:
    - status anchored relative to date layout (`statusX`) (lines ~4298–4306)
    - bottom-right counters/pin anchored from trailing edge using `nextBadgeX` (lines ~4308–4331)
    - this enforces a stable right edge while content changes.
- `submodules/ChatListUI/Sources/Node/ChatListStatusNode.swift`
  - visual state machine for meta status icon (`none`, `clock`, `delivered`, `read`, `failed`).
- `submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesChatList.swift`
  - status icon resources (`clock`, checks, etc.) and badge/pin visual assets.

## 3) Props / inputs
- `timeText: string` — top-right time.
- `sendStatus: TgChatSendStatus` — outgoing status icon state (`none|sending|sent|read|failed`).
- `unreadCount: number` — unread badge value.
- `isMuted: boolean` — muted badge styling.
- `isPinned: boolean` — pin fallback when unread absent.
- `minWidth/topRowHeight/bottomRowHeight` — geometry controls (tokenized).

## 4) State matrix
- none: only time, no bottom content.
- sending: time + clock.
- sent: time + single check.
- read: time + double check.
- failed: time + warning/error status.
- pinned: bottom pin icon.
- unread active: bottom unread badge.
- unread muted: bottom unread badge in muted style.

## 5) Layout rules
- Right meta cluster is always right-aligned and width-reserved:
  - `constraintSize({ minWidth: tokens.chatMetaMinWidth })`
  - inner rows use `justifyContent(FlexAlign.End)`.
- Top and bottom rows have fixed, tokenized heights.
- **Anti-jump rule #1 (width reserve):**
  - cluster min width prevents title/preview block from “breathing” when `badge ↔ pin ↔ none`.
- **Anti-jump rule #2 (vertical reserve):**
  - bottom row always exists with fixed geometry;
  - if no badge/pin, render invisible placeholder (tokenized size) instead of collapsing row.
  - placeholder width is reserved to badge max visual width (`UNREAD_BADGE_MAX_WIDTH`) so `none ↔ 99+ ↔ pin` does not micro-shift.
- Priority for bottom content:
  - `unreadBadge` (if `unreadCount > 0`) → else `pin` (if pinned) → else placeholder.

## 6) Token mapping
- Source: `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
  - geometry:
    - `CHAT_META_MIN_WIDTH`
    - `CHAT_META_TOP_ROW_HEIGHT`
    - `CHAT_META_BOTTOM_ROW_HEIGHT`
    - `CHAT_META_ROW_GAP`
    - `CHAT_META_STATUS_ICON_SIZE`
    - `CHAT_META_STATUS_GAP`
    - `CHAT_META_BOTTOM_PLACEHOLDER_WIDTH/HEIGHT`
  - colors:
    - `COLOR_TEXT_META`
    - `COLOR_STATUS_PENDING/SENT/READ/FAILED`
    - pin/unread colors via `TgIcon` + `TgUnreadBadge` tokens
  - icons:
    - `ICON_RES_CLOCK`
    - `ICON_RES_CHECK_SINGLE`
    - `ICON_RES_CHECK_DOUBLE`
    - `ICON_RES_FAILED`
    - `ICON_RES_PIN`

## 7) Acceptance checklist
- [x] Right cluster min-width reserved and right aligned
- [x] Bottom row vertical geometry is always reserved (no collapse)
- [x] Placeholder width reserves worst-case bottom content (`99+` / pin)
- [x] `badge ↔ pin ↔ none` does not shift left text block in demo probe
- [x] Time/status top row and bottom badge row are independent and stable
- [x] Failed-state checks included (`failed only` and `failed + unread`)
- [x] All visual constants tokenized
- [x] Demo covers required states (`none/sending/sent/read/pinned/unread/muted`)
- [ ] Final side-by-side polish against iOS screenshot sequence
