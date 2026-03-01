# TgTokens Component Passport

## Scope
- Stage: `0) tokens`
- Status: `in-progress`

## iOS file references
- `submodules/ChatListUI/Sources/Node/ChatListItem.swift`
  - row metrics and layout contracts (`avatarLeftInset`, `leftInset`, `itemHeight`, `separatorInset`)
- `submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesChatList.swift`
  - icon/badge/status color generation and unread badge visual language

## Inputs / outputs
- Input: design decisions for chat list atom pipeline.
- Output: single token source for atoms (`TgIcon`, `TgAvatar`, `TgUnreadBadge`, `TgChatMeta`, `TgChatRow`).

## Token groups
- Colors: background/text/meta/separator/unread/icon/online
- Typography: title/preview/meta/badge sizes
- Spacing/radius: baseline spacing and capsule radius values
- Icon sizes/resources: all chat row status icons and mute/pin
- Row metrics: stable row height, separator inset, fixed meta width

## Layout rules captured in tokens
- Separator inset starts after avatar block (Telegram-like list rhythm)
- Right meta cluster has fixed-width budget (prevents jump between states)
- Badge minimum size + horizontal padding for capsule behavior

## Acceptance checklist
- [x] Token file exists in `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
- [x] Atom code can consume tokens without hardcoded constants
- [x] ChatRow pipeline critical metrics are tokenized
- [ ] Values fine-tuned after visual comparison on device
