# TgPinnedMessagePanel Component Passport

## Scope
- Atom: `TgPinnedMessagePanel`
- Milestone: M4 Timeline Completeness.
- The atom is UI-only. Typed loading, collection state and navigation remain page/domain responsibilities.

## Visual truth and iOS mapping
- Shipped reference: the user-provided iPhone 16 Pro Max `File` capture, where an isolated rounded pinned-message surface sits below the independent chat top-bar capsules.
- Source: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatPinnedMessageTitlePanelNode.swift`.
- iOS source constants: panel height `50.0`, title and preview fonts `15.0`, navigation stripe width `2.0`, thumbnail `36.0` with an 8pt corner radius, content left inset `18.0`, stripe-to-text inset `10.0`, thumbnail gap `9.0`.

## Inputs
- `title`, `preview`
- `index`, `totalCount`
- `hasThumbnail` + optional `thumbnailSrc` (`Resource | string`)
- `glassMode`
- `onPress`, `onClosePress`, `onListPress`

## State matrix
- single pinned text message with close action
- multiple pinned messages: first, middle and last stripe positions with list action
- media thumbnail
- long title/preview ellipsis
- API 26 immersive material
- API 23 realtime-blur and opaque fallback

## Layout contract
- Isolated 48vp rounded rectangle with 14vp screen-side insets and 12vp corners; no full-width chrome panel behind it.
- The 2vp navigation stripe spans the panel height and moves its active segment by `index / totalCount`.
- Title and preview are single-line and 14fp; text yields space before the fixed 38vp trailing action.
- Optional media is 34vp square with 7vp radius.
- Primary tap opens/jumps to the pinned message. Single-message trailing action closes; multi-message action opens the pinned list.
- All action touch targets are at least 40×40vp through `responseRegion`.

## Material contract
- API 26: `uiMaterial.ImmersiveMaterial(REGULAR)`.
- API 23-25: tokenized tint + adaptive blur + border.
- Fallback geometry is identical to native material geometry.

## Live integration
- `searchChatMessages` with `searchMessagesFilterPinned` is wired through `LoadPinnedMessagesUseCase`; its `total_count`, reverse-chronological `messages`, and string-preserved `next_from_message_id` are the only source of multi-pin count and pagination.
- `TgChatScreenPage` owns request lifecycle, exact count/current stripe index, paged pinned collection, list visibility, timeline jump and local close state; the atom remains presentation-only.
- The newest returned message maps to stripe index `totalCount - 1`; older list rows map monotonically toward zero, matching the iOS title-panel convention.
- `getChatPinnedMessage` remains a compatibility fallback only when the filtered collection is unavailable; it must never invent a multi-pin count.
- No fake `lastMessage` fallback is allowed; it can display the wrong message while looking plausible.
