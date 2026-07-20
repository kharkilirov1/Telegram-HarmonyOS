# TgChatMeta Component Passport

## 1) Scope
- Atom: `TgChatMeta`
- Target layer: `atoms`
- Status: `done`

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
- `submodules/ChatListUI/Sources/Node/ChatListBadgeNode.swift`
  - unread/mention counters are project-owned stretchable badge backgrounds with measured text width; they are not platform/system badges.

## 3) Props / inputs
- `timeText: string` — top-right time.
- `sendStatus: TgChatSendStatus` — outgoing status icon state (`none|sending|sent|read|failed`).
- `unreadCount: number` — unread badge value.
- `isMuted: boolean` — muted badge styling.
- `isPinned: boolean` — pin fallback when unread absent.
- `TgChatMetaTop`: `timeText/sendStatus/rowHeight` for the title line.
- `TgChatMetaBottom`: `unreadCount/isMuted/isPinned/hasMention/rowHeight` for the preview line.
- `TgChatMeta` remains the composed demo/legacy wrapper with `minWidth/topRowHeight/bottomRowHeight` controls.

## 4) State matrix
- none: only time, no bottom content.
- sending: time + clock.
- sent: time + single check.
- read: time + double check.
- failed: time + warning/error status.
- pinned: bottom pin icon.
- unread active: bottom unread badge.
- unread muted: bottom unread badge in muted style.
- mention + unread: mention dot and unread capsule share the same project-owned background color path.

## 5) Layout rules
- Live `TgChatRow` owns two independent trailing lanes, matching the iOS layout pass:
  - title width is reduced only by measured `date/status` content through intrinsic `TgChatMetaTop` geometry;
  - preview width is reduced only by the current `badge/mention/pin` content through intrinsic `TgChatMetaBottom` geometry;
  - an empty bottom accessory consumes zero width, so a normal preview can reach the trailing inset.
- Both line atoms use `justifyContent(FlexAlign.End)` and keep the same trailing edge.
- The composed `TgChatMeta` wrapper preserves the old fixed-min-width/placeholder probe for its standalone demo and archived-row integrations.
- Top and bottom rows have fixed, tokenized heights.
- **Vertical stability:** top and bottom line heights remain fixed and tokenized, while horizontal width follows the actual accessory on that line.
- **Standalone probe stability:** `TgChatMeta(reservePlaceholder)` still reserves the worst-case bottom width for the demo that compares state changes.
- Priority for bottom content:
  - `unreadBadge` (if `unreadCount > 0`) → else `pin` (if pinned) → else placeholder.
- Unread count formatting follows Telegram iOS `compactNumericCountString`: `1...999` exact, then compact `K` / `M` with one decimal when needed (`1K`, `2.5K`, `1.2M`). It must not clamp at `99+`.
- Unread badge is rendered by the atom as a custom Row/Text capsule. Do not use ArkUI `Badge` here: the stock component can inject platform outline/halo styling that does not match Telegram's chat-list counters.

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
    - pin/unread colors via `TgIcon` + project-owned unread capsule tokens
  - icons:
    - `ICON_RES_CLOCK`
    - `ICON_RES_CHECK_SINGLE`
    - `ICON_RES_CHECK_DOUBLE`
    - `ICON_RES_FAILED`
    - `ICON_RES_PIN`

## 7) Acceptance checklist
- [x] Live row uses independent intrinsic top/bottom trailing clusters and a stable right edge
- [x] Bottom row vertical geometry is always reserved (no collapse)
- [x] Placeholder width reserves worst-case bottom content (`compact K/M` / pin)
- [x] `badge ↔ pin ↔ none` does not shift left text block in demo probe
- [x] Time/status top row and bottom badge row are independent and stable
- [x] Failed-state checks included (`failed only` and `failed + unread`)
- [x] All visual constants tokenized
- [x] Unread badge avoids stock ArkUI `Badge` halo/border and owns capsule geometry locally
- [x] Unread badge uses compact K/M count formatting instead of `99+` clamping
- [x] Demo covers required states (`none/sending/sent/read/pinned/unread/muted`)
- [x] API23 runtime parity: a no-accessory preview reaches the content edge while time remains confined to the independent top lane (`.codex/ui-audit/2026-07-17/chatrow-line-meta/02-after.*`)
