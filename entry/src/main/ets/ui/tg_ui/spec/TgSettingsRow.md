# TgSettingsRow Component Passport

## 1) Scope
- Atom: `TgSettingsRow`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `Telegram-iOS-master/submodules/SettingsUI/Sources/LogoutOptionsController.swift`
- `Telegram-iOS-master/submodules/SettingsUI/Sources/Notifications/NotificationsAndSoundsController.swift`
- `Telegram-iOS-master/submodules/SettingsUI/Sources/Notifications/NotificationsCategoryItemListItem.swift`

## 3) Props / inputs
- `title: string`
- `iconRes: Resource`
- `iconBgColor: ResourceColor`
- `trailingType: TgSettingsTrailing`
- `trailingText: string`
- `toggleValue: boolean`
- `showSeparator: boolean`
- callbacks:
  - `onToggleChange`
  - `onRowClick`

## 4) State matrix
- arrow trailing
- text + arrow trailing
- switch trailing
- no trailing
- long title ellipsis
- separator on / off

## 5) Layout rules
- Leading colored icon box has fixed square geometry.
- Title consumes remaining width.
- Trailing zone renders arrow/text/toggle depending on `trailingType`.
- Separator inset starts after icon box + title gap.
- Row height is fixed for stable grouped sections.

## 6) Token mapping
- `SETTINGS_ROW_*`
- `SETTINGS_ICON_COLOR_*`
- `COLOR_TEXT_TITLE`
- `COLOR_SEPARATOR`
- `ICON_RES_ARROW_RIGHT`

## 7) Acceptance checklist
- [x] all trailing variants render
- [x] title ellipsis works
- [x] switch callback exposed
- [x] icon geometry and separator inset are tokenized
- [x] row remains stable inside grouped section
