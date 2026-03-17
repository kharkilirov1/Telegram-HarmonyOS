# TgTabBar Component Passport

## 1) Scope
- Atom: `TgTabBar`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `Telegram-iOS-master/submodules/TelegramUI/Components/TabBarComponent/Sources/TabBarComponent.swift`
- `Telegram-iOS-master/submodules/TabBarUI/Sources/TabBarContollerNode.swift`
- `Telegram-iOS-master/submodules/TabBarUI/Sources/TabBarNode.swift`
- `Telegram-iOS-master/submodules/PresentationDataUtils/Sources/SpecialTabBarIcons.swift`

## 3) Props / inputs
- `selectedIndex: number`
- `chatBadgeCount: number`
- `glassMode: string`
- callback:
  - `onTabSelect`
- ownership:
  - page/shell owns `AppStorage` writes and `TabsController`
  - atom is presentational and emits selection only

## 4) State matrix
- selected contacts / calls / chats / settings
- unread badge `1 / 99 / 99+`
- realtime blur / fallback blur
- safe-area bottom inset changes

## 5) Layout rules
- Centered glass capsule aligned above the bottom safe area, not a full-width shelf.
- Four tabs share equal width and identical icon/text vertical alignment.
- Chats tab overlays unread badge above icon when `chatBadgeCount > 0`.
- Capsule surface owns blur, border, and shadow; page owns outer bottom offset above the safe area.
- Selection uses a compact capsule highlight inside the larger glass container and is driven directly by `selectedIndex` (no timer-only visual state).
- The tab bar uses tab-specific glass resources (`tab_bar_glass_bg`, `tab_bar_edge_highlight`) so material tuning can evolve without shifting other glass chrome.

## 6) Token mapping
- `TAB_BAR_*`
- `tab_bar_glass_bg`
- `tab_bar_edge_highlight`
- `COLOR_ICON_PRIMARY`
- `COLOR_ICON_SECONDARY`
- `COLOR_UNREAD_BG`
- `COLOR_UNREAD_TEXT`
- `GLASS_SPECULAR_*`

## 7) Acceptance checklist
- [x] 4-tab layout implemented
- [x] unread badge clamps to `99+`
- [x] blur/fallback modes supported
- [x] tab selection callback exposed
- [x] no hardcoded geometry/colors in atom
- [x] atom does not mutate shell `AppStorage` directly
