# TgTopBar Component Passport

## 1) Scope
- Atom: `TgTopBar`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/Display/Source/NavigationBar.swift`
- `submodules/Display/Source/Navigation/NavigationController.swift`
- `submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListNavigationBar.swift`

## 3) Props / inputs
- `title: string`
- `showBackAction: boolean`
- `showRightAction: boolean`
- `rightIcon: Resource`
- callbacks:
  - `onBackPress`
  - `onRightPress`

## 4) State matrix
- title only
- title + back
- title + right action
- title + back + right action
- long title ellipsis

## 5) Layout rules
- top inset from system avoid area is included in atom.
- bar content height is fixed (`TOP_BAR_HEIGHT`), title centered.
- left/right slots keep equal touch geometry (`TOP_BAR_ACTION_TOUCH`) to keep title stable.
- system NavDestination title/back UI must stay hidden when this atom is used.

## 6) Token mapping
- `TOP_BAR_HEIGHT`
- `TOP_BAR_SIDE_PADDING`
- `TOP_BAR_ACTION_TOUCH`
- `TOP_BAR_ACTION_ICON_SIZE`
- `TOP_BAR_TITLE_SIZE`
- `TOP_BAR_GLASS_BG`
- `TOP_BAR_SEPARATOR`
- `TOP_BAR_SEPARATOR_STROKE`
- `ICON_RES_BACK`
- `ICON_RES_MORE`

## 7) Acceptance checklist
- [x] Single visible back button (no duplicate system back)
- [x] Title remains centered with/without side actions
- [x] Long title ellipsis works
- [x] Safe area top inset applied inside atom
- [x] All metrics/colors tokenized

