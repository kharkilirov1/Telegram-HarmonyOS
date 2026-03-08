# TgSettingsSection Component Passport

## 1) Scope
- Atom: `TgSettingsSection`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `Telegram-iOS-master/submodules/ItemListUI/Sources/ItemListController.swift`
- `Telegram-iOS-master/submodules/SettingsUI/Sources/Notifications/NotificationsAndSoundsController.swift`
- `Telegram-iOS-master/submodules/SettingsUI/Sources/LogoutOptionsController.swift`

## 3) Props / inputs
- `header: string`
- `footer: string`
- `content: @BuilderParam`

## 4) State matrix
- header only
- footer only
- header + footer
- multiple rows inside content slot
- empty header/footer

## 5) Layout rules
- Section header and footer live outside the rounded content card.
- Content card uses inset-grouped background, radius, and clipping.
- The atom is V1 `@Component` to support `@BuilderParam`.
- Parent page controls vertical sequencing of multiple sections.

## 6) Token mapping
- `SETTINGS_SECTION_*`
- `COLOR_TEXT_TITLE`
- `SETTINGS_SECTION_BG`

## 7) Acceptance checklist
- [x] inset-grouped card shape implemented
- [x] header/footer typography tokenized
- [x] slot content renders without page-level wrapper duplication
- [x] section margins stay consistent across pages
