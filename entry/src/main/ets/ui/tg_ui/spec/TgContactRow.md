# TgContactRow component passport

## Reference
- iOS row: `C:\Refs\Telegram\Telegram-iOS-current\submodules\ContactsPeerItem\Sources\ContactsPeerItem.swift`.
- iOS grouping: `C:\Refs\Telegram\Telegram-iOS-current\submodules\ContactListUI\Sources\ContactListNode.swift` (`ContactListNameIndexHeader`).
- Harmony pattern: official ArkUI `ListItemGroup` + `AlphabetIndexer`; `C:\Refs\Telegram\HarmonyOSComponentUXExamples\entry\src\main\ets\pages\Index.ets`.

## Inputs
- `name`, `initials`, `statusText`, `avatarPath`.
- `isOnline`, `showSeparator`, `avatarBgColor`.
- Optional density inputs: `rowHeight`, `contentGap`, `statusFontSize`,
  `separatorInset`; defaults preserve the root Contacts tab.
- `onPress` event; navigation remains page-owned.

## State matrix
- avatar image / initials fallback.
- online / recently / offline presence copy.
- short / ellipsized long name.
- final row without separator.

## Layout
- 56vp row, 40vp avatar, 12vp avatar-to-copy gap.
- 17fp name and 14fp presence.
- trailing padding reserves the native alphabet indexer lane.
- separator begins after avatar + gap.
- Compose variant: 50vp row, 9vp gap, 13fp status and 65vp separator
  inset, matching the denser current iOS `ContactsPeerItem` geometry without
  changing the root Contacts surface.

## Acceptance
- [x] Tokens own geometry and colors.
- [x] Presence hierarchy and online accent match the established Telegram rows.
- [x] Long names remain single-line and do not collide with the indexer.
