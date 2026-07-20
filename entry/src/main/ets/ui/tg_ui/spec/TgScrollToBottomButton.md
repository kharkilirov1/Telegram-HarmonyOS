# TgScrollToBottomButton passport

## iOS reference
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatHistoryNavigationButtons.swift`
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatHistoryNavigationButtonNode.swift`

## Inputs
- `unreadCount`: unread messages retained while the viewport is away from the true bottom.
- `onPress`: jump to the real bottom or the chat's latest message when a mid-history window is active.

## Layout and states
- Button: 40vp circular glass surface with centered down chevron.
- Badge: Telegram accent fill, white 13fp text, 20vp height/minimum width, centered over the button at `y=-7vp` like iOS.
- `0`: no badge; `1...999`: full count; `1000+`: compact `K/M` form.
- The button and badge use asymmetric opacity/scale transitions; the 40vp button remains the hit target.

## Data contract
- Chat entry captures the current unread count before `markChatRead` can reset TDLib state.
- Rebuilds only raise the retained count; reaching the true bottom or pressing the button clears it.
- The badge does not fabricate mention/reaction counters.

## Acceptance
- [x] No badge for a zero count.
- [x] Unread badge remains centered for one-, two- and compact multi-character values.
- [x] Scrolling away from bottom exposes the button; reaching/pressing bottom clears the retained count.
- [x] Runtime geometry stays above the composer and preserves the existing jump behavior.
