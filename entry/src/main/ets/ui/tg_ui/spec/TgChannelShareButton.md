# TgChannelShareButton — Component Passport

## Purpose

Telegram-specific free-floating action beside incoming broadcast-channel posts. A tap opens the existing forward-target picker; the atom does not own TDLib or navigation logic.

## References

- Telegram iOS visual/behavior source:
  - `TelegramUI/Components/Chat/ChatMessageShareButton/Sources/ChatMessageShareButton.swift`
  - `TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift`
- `ChatMessageShareButton.swift` returns a **30×30pt** free-background surface.
- `ChatMessageBubbleItemNode.swift` places it at `bubble.maxX + 8pt` and `bubble.maxY - 30pt - 1pt` for incoming posts.
- The tap ultimately enters Telegram's share/forward flow. Harmony reuses the existing `ChatMessageActionsController` -> forward target picker -> typed TDLib `forwardMessages` path.

## Inputs

- `glassMode: string` — shared runtime glass-quality policy.
- `accessibilityLabel: string` — localized Forward label.
- `onPress()` — page-owned navigation callback.

## Layout contract

- Visual surface: `30×30vp`.
- Gap after the bubble: `8vp`.
- Bottom inset: `1vp`.
- Touch target: `40×40vp`, larger than the visual surface.
- API26: native interactive `ImmersiveMaterial(THIN)`.
- API23 fallback: adaptive ultra-thin blur, Telegram tint and edge.

## State matrix

| Context | Visible |
|---|---|
| Incoming broadcast-channel post | yes |
| Outgoing channel post | no |
| Private / secret / group / supergroup | no |
| Service/date/unread rows | no |

## Integration

- `TgMessageRouter` owns visibility and places the atom immediately after the actual bubble, so short intrinsic bubbles do not leave a false fixed gap.
- `TgChatScreenPage` passes the selected `ChatTimelineEntryVO` into `openForwardTargetPickerForEntry`.
- Selecting a destination enters existing forward-composer mode; tapping the share button itself never sends a message.

## Acceptance

- The button is visually present in the reserved broadcast lane.
- Short and long channel posts keep exactly an 8vp bubble-to-button gap.
- Tap opens the real forward picker without sending.
- Non-channel runtime control remains unchanged.
