# TgChatTopBar Component Passport

## 1) Scope
- Atom: `TgChatTopBar`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `Telegram-iOS-master/submodules/Display/Source/NavigationBar.swift`
- `Telegram-iOS-master/submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListNavigationBar.swift`
- `Telegram-iOS-master/submodules/TelegramUI/Sources/ChatOverlayNavigationBar.swift`

## 3) Props / inputs
- `title: string`
- `subtitle: string`
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
- online / offline subtitle color
- avatar image / initials fallback
- long title / long subtitle ellipsis
- glass blur auto / fallback

## 5) Layout rules
- Top safe-area inset is included inside the atom.
- Composition: left back capsule, centered title capsule, right avatar capsule.
- All three capsules share size, radius, border, and blur treatment.
- Title/subtitle stay centered; subtitle is optional and single-line.
- Avatar color is selected from tokenized sender palette by modulo index.

## 6) Token mapping
- `CHAT_TOP_BAR_*`
- `TOP_BAR_ACTION_ICON_SIZE`
- `COLOR_TEXT_TITLE`
- `COLOR_TEXT_PREVIEW`
- `COLOR_ICON_PRIMARY`
- `AVATAR_COLOR_1..8`
- `GLASS_SPECULAR_*`

## 7) Acceptance checklist
- [x] safe-area inset applied inside atom
- [x] title capsule stays centered with side capsules present
- [x] long title/subtitle ellipsis works
- [x] avatar/image fallback works
- [x] all geometry and glass styling are tokenized
