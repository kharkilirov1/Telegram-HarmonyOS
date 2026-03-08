# TgContactRow Component Passport

## 1) Scope
- Atom: `TgContactRow`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `Telegram-iOS-master/submodules/ContactListUI/Sources/ContactListNode.swift`
- `Telegram-iOS-master/submodules/ContactListUI/Sources/ContactsControllerNode.swift`
- `Telegram-iOS-master/submodules/ContactsPeerItem/Sources/ContactsPeerItem.swift`

## 3) Props / inputs
- `name: string`
- `statusText: string`
- `initials: string`
- `avatarPath: string`
- `isOnline: boolean`
- `showSeparator: boolean`
- `avatarBgColor: ResourceColor`

## 4) State matrix
- online status
- offline status
- avatar image / initials fallback
- empty status
- long name / status ellipsis
- separator on / off

## 5) Layout rules
- Left cluster: avatar + vertical text stack.
- Name is primary text; status is optional secondary line.
- Online state uses accent/online color for status.
- Separator inset starts after avatar block.
- Row height remains fixed across states.

## 6) Token mapping
- `CONTACT_ROW_*`
- `COLOR_TEXT_TITLE`
- `COLOR_TEXT_PREVIEW`
- `COLOR_ONLINE_DOT`
- `COLOR_SEPARATOR`

## 7) Acceptance checklist
- [x] primary/secondary hierarchy preserved
- [x] online/offline color states supported
- [x] long strings ellipsize cleanly
- [x] separator inset matches avatar block
- [x] tokens only
