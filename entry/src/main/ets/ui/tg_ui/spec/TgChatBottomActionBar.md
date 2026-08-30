# TgChatBottomActionBar

Bottom panel that replaces the composer in chats where composing is unavailable.
iOS dispatcher: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatInterfaceStateInputPanels.swift:13`
(`inputPanelForChatPresentationInterfaceState`).

## iOS source grounding
- `ChatChannelSubscriberInputPanelNode` —
  `submodules\TelegramUI\Components\Chat\ChatChannelSubscriberInputPanelNode\Sources\ChatChannelSubscriberInputPanelNode.swift`
  (glass rail, one centered button, no input field)
- `ChatRestrictedInputPanelNode` — `submodules\TelegramUI\Sources\ChatRestrictedInputPanelNode.swift`
  (text-only panel: restriction reason, no buttons)
- Button labels: `Channel.JoinChannel` = "Join", `Group.JoinGroup` = "Join Group",
  `Conversation.Mute` = "Mute", `Conversation.Unmute` = "Unmute",
  `Conversation.DefaultRestrictedText` = "Writing messages isn't allowed in this group."

## Inputs
- `mode`: `action` | `restricted`
- `actionText`: label of the single centered button (action mode)
- `isActionAccent`: accent text for Join; primary text for Mute/Unmute
- `messageText`: restriction reason (restricted mode)
- `glassMode`, `bottomInset`

## State matrix (production mapping)
| Chat state (our data) | iOS panel | Our surface |
|---|---|---|
| Channel, in main list (`order !== '0'`), unmuted | Subscriber: "Mute" | action, primary |
| Channel, in main list, muted (`muteForSeconds > 0`) | Subscriber: "Unmute" | action, primary |
| Channel, NOT in list (`order === '0'`) | Subscriber: "Join" (accent) | action, accent |
| Supergroup/group with `canSendBasicMessages === false` | Restricted: default text | restricted |
| Private chat / writable group | composer (this atom hidden) | — |

Deferred (needs `getChatMember` status hydration): kicked → red "Delete and Exit"
(`DeleteChatInputPanelNode`), per-user `bannedRights` restricted variants,
bot "Start", blocked "Unblock", slow-mode countdown, Premium-required.

## Layout rules
- Height 48, capsule radius 24, side inset 14 (mirrors the pinned panel lane).
- Content: single centered line; action 16fp medium; restricted text 13fp regular, preview color.
- Same bottom lane as the composer: the panel must reserve identical layout space
  (page renders it in the composer slot; fade backdrop still applies).

## Material contract (LESSON 121)
- API 26 real device (`TgGlassPolicy.supportsNativeMaterial()`): `ImmersiveMaterial` THIN,
  `interactive` only in action mode.
- API 23-25 / emulator: `backdropBlur(GLASS_CAPSULE_BACKDROP_BLUR)` + `chat_top_bar_scroll_capsule_bg`
  tint; opaque fallback token when glass policy is off. No `renderGroup(true)`.

## Acceptance
- [x] iOS source constants recorded.
- [x] State matrix derived from data available in `Chat` (order/muteForSeconds/permissions).
- [x] Glass recipe per lesson 121, token-only geometry/colors.
- [ ] Runtime witness: opened broadcast channel shows Mute/Unmute instead of composer.
