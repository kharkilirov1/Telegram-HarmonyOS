# TgChatListNavigationBar Component Passport

## 1) Scope
- Atom: `TgChatListNavigationBar`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `Telegram-iOS-master/submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListNavigationBar.swift`
  - integrated search lane (`searchScrollHeight = 54.0`)
  - title row composition with left `Edit` and right compose action
- `Telegram-iOS-master/submodules/ChatListUI/Sources/ChatListControllerNode.swift`
  - list top inset tied to navigation-bar search/header height
- `Telegram-iOS-master/submodules/Display/Source/NavigationBar.swift`
  - translucent navigation background ownership

## 3) Props / inputs
- `title: string`
- `searchValue: string`
- `searchPlaceholder: string`
- `showEditAction: boolean`
- `editText: string`
- `showComposeAction: boolean`
- `glassMode: string`
- callbacks:
  - `onEditPress`
  - `onComposePress`
  - `onSearchChange`
  - `onSearchSubmit`

## 4) State matrix
- title only
- title + edit
- title + compose
- title + edit + compose
- empty search
- active search text
- long localized title
- blur / fallback glass mode

## 5) Layout rules
- top safe-area inset is included inside the atom.
- title row height stays `44vp`.
- search lane is integrated below title row and reserves `54vp` like iOS `searchScrollHeight`.
- title remains centered independently from left/right action widths.
- search field is part of the header surface, not a scrolling list item.
- header owns blur/tint/bottom separator; page only offsets scroll content under it.

## 6) Token mapping
- `TOP_BAR_*`
- `SEARCH_BAR_*`
- `CHAT_LIST_NAV_SEARCH_AREA_HEIGHT`
- `CHAT_LIST_NAV_TOTAL_HEIGHT`
- `ICON_RES_SEARCH`
- `ICON_RES_EDIT`
- `GLASS_SPECULAR_*`

## 7) Acceptance checklist
- [x] integrated search row replaces separate scrolling search strip
- [x] title stays centered with localized `Edit`
- [x] compose action is right-aligned and tokenized
- [x] chat-list scroll offset can be derived from the header total height
- [x] header blur/fallback is token-driven
