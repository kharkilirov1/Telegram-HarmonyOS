# TgRootTabUnreadBadge passport

## References

- Runtime owner: native HarmonyOS `HdsTabs` with `bleedIconStyle`; this atom only supplies Telegram-specific item content and never owns the floating island, material, safe area, or tab motion.
- Telegram iOS aggregate: `C:/Refs/Telegram/Telegram-iOS-current/submodules/ChatListUI/Sources/ChatListController.swift` uses `renderedTotalUnreadCount` and `compactNumericCountString` for `tabBarItem.badgeValue`.
- Telegram iOS geometry: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TabBarUI/Sources/TabBarNode.swift` uses an 18pt capsule, 13pt regular text and 5pt horizontal text inset.
- Telegram iOS formatting: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramPresentationData/Sources/NumericFormat.swift` truncates one decimal into `K` / `M` suffixes.
- TDLib contract: `tdlib/td/generate/scheme/td_api.tl` declares `updateUnreadMessageCount(chat_list, unread_count, unread_unmuted_count)`.

## Inputs

- `count: number` — authoritative total unread-message count for `chatListMain`; negative and fractional input is sanitized.

## State matrix

- `count <= 0`: no badge node.
- `1...999`: exact integer.
- `>= 1K`: one truncated decimal only when non-zero (`1K`, `2.5K`).
- `>= 1M`: one truncated decimal only when non-zero (`1M`, `1.2M`).

## Layout

- 18vp minimum circular capsule; content expands horizontally.
- 13fp regular text, white on Telegram tab-badge red.
- 5vp horizontal inset.
- The `HdsTabs` item builder owns the relative top-right position through tokens; the atom owns only badge content geometry.

## Data contract

- `updateUnreadMessageCount` is normalized into `ChatListUnreadMessageCountChangedEvent`.
- Main/archive aggregates remain independent in `ChatsState`.
- `selectTotalUnreadCount` prefers the complete main-list aggregate and uses loaded main rows only before the first aggregate arrives.
- `AppStoreBridge` projects that value into `chatsUIState.totalUnreadCount`.

## Acceptance

- Native `HdsTabs`, `bleedIconStyle`, floating material and hide geometry remain unchanged.
- No `999+` clamp.
- Archive-only rows are not accidentally counted by fallback projection.
- Source contract, focused ohosTest compile, both shell smokes and clean main build pass.
