# TgChatTopBar Component Passport

## 1) Scope
- Atom: `TgChatTopBar`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `Telegram-iOS-master/submodules/TelegramUI/Sources/ChatController.swift`
- `Telegram-iOS-master/submodules/TelegramUI/Sources/ChatControllerNode.swift`
- `Telegram-iOS-master/submodules/TelegramUI/Sources/ChatControllerContentData.swift`
- `Telegram-iOS-master/submodules/TelegramUI/Sources/ChatHistoryNavigationButtonNode.swift`

## 3) Props / inputs
- `title: string`
- `subtitle: string`
- `subtitleMode: TgChatTopBarSubtitleMode`
- `avatarInitials: string`
- `avatarColorIndex: number`
- `avatarImageSrc: string`
- `isOnline: boolean`
- `glassMode: string`
- callbacks:
  - `onBackPress`
  - `onTitlePress`
  - `onAvatarPress`

## 4) State matrix
- title only
- title + subtitle
- secondary subtitle
- online subtitle accent
- activity subtitle accent
- group activity subtitle with actor name prefix
- avatar image / initials fallback
- long title / long subtitle ellipsis
- glass blur auto / fallback

## 5) Layout rules
- Top safe-area inset is included inside the atom.
- Shared upper blur/tint/top-edge emphasis is provided by `TgTopChromeBackground`; this atom renders its capsule composition above that shared surface.
- Composition: left back capsule, centered title capsule, right avatar capsule.
- All three capsules share size, radius, border, and blur treatment.
- The centered title capsule is intentionally optically lighter than the earlier V2 pass: reduced horizontal padding, reduced minimum width, tighter inter-capsule gap, and lighter border stroke keep the cluster from reading as one oversized dark mass.
- Title/subtitle stay centered; subtitle is optional and single-line.
- Subtitle semantics are screen-derived: the atom only renders `secondary` / `online` / `activity` modes and does not derive chat business state internally.
- Avatar color is selected from tokenized sender palette by modulo index.

## 6) Token mapping
- `CHAT_TOP_BAR_*`
- `TgTopChromeBackground`
- `TOP_BAR_ACTION_ICON_SIZE`
- `COLOR_TEXT_TITLE`
- `COLOR_TEXT_PREVIEW`
- `CHAT_TOP_BAR_SUBTITLE_ACCENT`
- `COLOR_ICON_PRIMARY`
- `AVATAR_COLOR_1..8`
- `GLASS_SPECULAR_*`

## 7) Acceptance checklist
- [x] safe-area inset applied inside atom
- [x] title capsule stays centered with side capsules present
- [x] long title/subtitle ellipsis works
- [x] avatar/image fallback works
- [x] all geometry and glass styling are tokenized
