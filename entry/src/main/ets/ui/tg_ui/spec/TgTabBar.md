# TgTabBar Component Passport

## 1) Scope
- Atom: `TgTabBar`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `Telegram-iOS-master/submodules/TabBarUI/Sources/TabBarNode.swift`
- `Telegram-iOS-master/submodules/Display/Source/TabBarController.swift`
- `Telegram-iOS-master/submodules/PresentationDataUtils/Sources/SpecialTabBarIcons.swift`

## 3) Props / inputs
- `selectedIndex: number`
- `chatBadgeCount: number`
- `glassMode: string`
- callback:
  - `onTabSelect`

## 4) State matrix
- selected contacts / calls / chats / settings
- unread badge `1 / 99 / 99+`
- realtime blur / fallback blur
- safe-area bottom inset changes

## 5) Layout rules
- Floating island container with max width and rounded capsule radius.
- Four tabs share equal width and identical icon/text vertical alignment.
- Chats tab overlays unread badge above icon.
- Island surface owns blur, border, and shadow; page owns outer bottom margin.
- Tab color reflects selected vs inactive state only through tokens.

## 6) Token mapping
- `TAB_BAR_*`
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
