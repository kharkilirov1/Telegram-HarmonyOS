# TgSearchBar Component Passport

## 1) Scope
- Atom: `TgSearchBar`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `Telegram-iOS-master/submodules/SearchBarNode/Sources/SearchBarNode.swift`
- `Telegram-iOS-master/submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListNavigationBar.swift`
- `Telegram-iOS-master/submodules/SearchUI/Sources/NavigationBarSearchContentNode.swift`

## 3) Props / inputs
- `placeholder: string`
- callbacks:
  - `onTextChange: (text: string) => void`
  - `onSubmit: (text: string) => void`

## 4) State matrix
- empty placeholder
- typed query
- submit callback
- long placeholder

## 5) Layout rules
- Inline search capsule spans full available width inside side insets.
- Search icon is embedded into the native `Search` component.
- Typography, radius, fill, and side insets are tokenized.
- Cancel button stays inside control (`INPUT` style).

## 6) Token mapping
- `SEARCH_BAR_*`
- `ICON_RES_SEARCH`

## 7) Acceptance checklist
- [x] search icon and placeholder styling are tokenized
- [x] change and submit callbacks exposed
- [x] control fills width inside insets
- [x] no hardcoded geometry/colors in atom
